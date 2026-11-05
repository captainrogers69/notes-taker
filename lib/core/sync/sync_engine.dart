import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

import '../database/weave_database.dart';
import '../helpers/json_map.dart';
import 'change_merger.dart';
import 'entity_type.dart';
import 'field_value.dart';
import 'hlc.dart';
import 'payload_cipher.dart';
import 'pulled_change.dart';
import 'remote_change.dart';
import 'sync_offline_exception.dart';
import 'sync_status.dart';
import 'sync_transport.dart';

/// Kind of merge outcome the UI surfaces (toast).
enum MergeKind { conflict, resurrected }

/// Emitted after the merge transaction for [entityId] has committed.
class MergeEvent extends Equatable {
  const MergeEvent(this.kind, this.entityId);

  final MergeKind kind;
  final String entityId;

  @override
  List<Object?> get props => [kind, entityId];
}

/// Timer settings; injectable so tests run in milliseconds.
class SyncTiming {
  const SyncTiming({
    this.debounce = const Duration(milliseconds: 300),
    this.fallback = const Duration(seconds: 60),
    this.backoffBase = const Duration(seconds: 2),
    this.backoffMax = const Duration(seconds: 60),
  });

  /// Delay that coalesces outbox inserts, hints and the fallback tick.
  final Duration debounce;

  /// Periodic pass, in case a hint was missed.
  final Duration fallback;
  final Duration backoffBase;
  final Duration backoffMax;
}

/// Moves changes between the local database and the server.
///
/// A pass pulls first, then pushes:
/// - **Pull** re-reads from `cursor - 100` (rows can commit out of `seq`
///   order) and applies rows strictly in ascending `seq`, across pages. Each
///   row is handled in one transaction that also records the change id as
///   applied (`sync.applied.<changeId>` = seq) and advances `sync.cursor`;
///   the merger's own transaction nests inside it as a savepoint, so the
///   row, the applied marker and the cursor commit or roll back together.
///   Already-applied ids are skipped on re-read, so a redelivered old change
///   can never raise a stale conflict. Own rows are marked applied without
///   merging. Markers below the re-read window are pruned after the pull,
///   which bounds them to about 100 plus one page.
/// - An unreadable payload (`FormatException` from the cipher) is
///   quarantined in `sync.quarantine.<changeId>` with the raw row, not marked
///   applied, and later changes to the same entity are quarantined too
///   (apply order matters per entity). Replay is out of scope for now: a
///   future fixed cipher reads these keys in `seq` order, applies them and
///   deletes them.
/// - **Push** sends the outbox oldest first in batches of [pushBatchSize] and
///   deletes only the acknowledged batch.
///
/// - An error from the cipher other than `FormatException`, or any error from
///   the merger, is treated as transient: the pull stops at that row (the
///   cursor is not advanced past it), push still runs, and the pass ends as
///   `error` with backoff; the next pass retries the row.
///
/// Passes never overlap: a [syncNow] during a pass makes that pass run once
/// more and returns its future. Logs carry ids and counts only.
class SyncEngine {
  SyncEngine({
    required this._db,
    required this._transport,
    required this._cipher,
    required this._merger,
    required this._deviceId,
    this._connectivity,
    this._checkOnline,
    this._timing = const SyncTiming(),
    int Function()? now,
    void Function(String message)? log,
    this.pageSize = 500,
    this.pushBatchSize = 200,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       _log = log ?? ((m) => developer.log(m, name: 'Sync'));

  static const cursorKey = 'sync.cursor';

  /// Each pull re-reads this many sequence numbers below the cursor.
  static const reReadWindow = 100;

  static String appliedKey(String changeId) => 'sync.applied.$changeId';
  static String quarantineKey(String changeId) => 'sync.quarantine.$changeId';

  static const _aheadLimit = Duration(hours: 24);

  final WeaveDatabase _db;
  final SyncTransport _transport;
  final PayloadCipher _cipher;
  final ChangeMerger _merger;
  final String _deviceId;
  final Stream<bool>? _connectivity;
  final Future<bool> Function()? _checkOnline;
  final SyncTiming _timing;
  final int Function() _now;
  final void Function(String) _log;
  final int pageSize;
  final int pushBatchSize;

  final _status = StreamController<SyncStatus>.broadcast();
  final _events = StreamController<MergeEvent>.broadcast();
  SyncStatus _current = SyncStatus.syncing;

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _debounce;
  Timer? _fallback;
  Timer? _retry;
  Duration? _retryIn;
  int _failures = 0;
  bool? _online;
  bool _started = false;
  bool _stopped = false;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;

  Stream<SyncStatus> get status => _status.stream;
  SyncStatus get current => _current;
  Stream<MergeEvent> get events => _events.stream;

  /// Delay before the automatic retry after a failed pass; null when the
  /// last pass did not fail.
  Duration? get retryIn => _retryIn;

  /// 2, 4, 8 … seconds, capped at 60 (with the default timing).
  static Duration backoffFor(int failures, SyncTiming timing) {
    var d = timing.backoffBase;
    for (var i = 1; i < failures && d < timing.backoffMax; i++) {
      d *= 2;
    }
    return d > timing.backoffMax ? timing.backoffMax : d;
  }

  /// Subscribes to outbox inserts, hints, connectivity and a fallback timer,
  /// asks for the current connectivity once (plugin streams need not replay
  /// it), and runs a first pass.
  void start() {
    if (_disposed) throw StateError('SyncEngine is disposed');
    if (_started) return;
    _started = true;
    _stopped = false;
    _subs
      ..add(
        _db
            .tableUpdates(
              TableUpdateQuery.onTable(
                _db.outbox,
                limitUpdateKind: UpdateKind.insert,
              ),
            )
            .listen((_) => _schedule()),
      )
      ..add(_transport.hints().listen((_) => _schedule()));
    final connectivity = _connectivity;
    if (connectivity != null) {
      _subs.add(connectivity.listen(_onConnectivity));
    }
    _fallback = Timer.periodic(_timing.fallback, (_) => _schedule());
    unawaited(_firstPass());
  }

  Future<void> _firstPass() async {
    final check = _checkOnline;
    if (check != null) {
      try {
        final online = await check();
        // A connectivity event may have arrived meanwhile; it wins.
        _online ??= online;
      } on Object {
        // Unknown: the transport decides.
      }
    }
    if (_started) await syncNow();
  }

  /// Cancels every trigger and waits for an in-flight pass, which stops at
  /// the next row or batch boundary. Forgets connectivity and backoff, so a
  /// later [start] begins fresh.
  ///
  /// The status is left as it was: a pass cut short stays `syncing`. A
  /// stopped engine's status means nothing; the status cubit shows
  /// `localOnly` once signed out (stop is only used for sign-out / dispose).
  Future<void> stop() async {
    _stopped = true;
    _started = false;
    _again = false;
    _online = null;
    _failures = 0;
    _retryIn = null;
    _debounce?.cancel();
    _fallback?.cancel();
    _retry?.cancel();
    final subs = [..._subs];
    _subs.clear();
    for (final s in subs) {
      await s.cancel();
    }
    final running = _running;
    if (running != null) await running;
  }

  /// Stops and closes the streams. The engine cannot be started again.
  Future<void> dispose() async {
    await stop();
    _disposed = true;
    await _status.close();
    await _events.close();
  }

  /// Runs a pass now, or once more after the one in flight.
  Future<void> syncNow() {
    if (_stopped) return Future.value();
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop();
  }

  Future<void> _loop() async {
    try {
      do {
        _again = false;
        await _pass();
      } while (_again && !_stopped);
    } finally {
      _running = null;
    }
  }

  /// Automatic trigger: debounced, and held back while a retry is pending.
  void _schedule() {
    if (!_started || _stopped) return;
    if (_retry?.isActive ?? false) return;
    _debounce?.cancel();
    _debounce = Timer(_timing.debounce, () => unawaited(syncNow()));
  }

  void _onConnectivity(bool online) {
    final was = _online;
    _online = online;
    if (!online) {
      _setStatus(SyncStatus.offline);
      return;
    }
    // Only a real regain triggers; the first report after start does not
    // (start already runs a pass).
    if (was == false) {
      _retry?.cancel();
      unawaited(syncNow());
    }
  }

  void _setStatus(SyncStatus s) {
    if (s == _current || _disposed) return;
    _current = s;
    _status.add(s);
  }

  Future<void> _pass() async {
    if (_online == false) {
      _setStatus(SyncStatus.offline);
      return;
    }
    _setStatus(SyncStatus.syncing);
    try {
      final pullError = await _pull();
      if (_stopped) return;
      final drained = await _push();
      if (pullError != null) throw pullError;
      if (!drained) return;
      _failures = 0;
      _retryIn = null;
      _retry?.cancel();
      _setStatus(SyncStatus.synced);
    } on SyncOfflineException {
      _backoff();
      _setStatus(SyncStatus.offline);
    } catch (e) {
      // The error's message could quote data; log its type only.
      _log('sync pass failed: ${e.runtimeType}');
      _backoff();
      _setStatus(SyncStatus.error);
    }
  }

  void _backoff() {
    _failures++;
    final delay = backoffFor(_failures, _timing);
    _retryIn = delay;
    _retry?.cancel();
    if (_started && !_stopped) {
      _retry = Timer(delay, () => unawaited(syncNow()));
    }
  }

  // ---------------------------------------------------------------- pull --

  /// Returns the error that stopped the pull at a row (transient: retried
  /// next pass), or null. Transport errors propagate.
  Future<Object?> _pull() async {
    final blocked = await _quarantinedEntities();
    var after = math.max(0, await _cursor() - reReadWindow);
    var last = after;
    while (true) {
      final page = await _transport.pull(afterSeq: after, limit: pageSize);
      final rows = [...page]..sort((x, y) => x.seq.compareTo(y.seq));
      for (final row in rows) {
        if (_stopped) return null;
        if (row.seq <= last) continue;
        last = row.seq;
        try {
          await _handle(row, blocked);
        } catch (e) {
          await _prune();
          return e;
        }
      }
      if (page.length < pageSize || _stopped) break;
      after = last;
    }
    await _prune();
    return null;
  }

  Future<void> _handle(PulledChange row, Map<String, int> blocked) async {
    final c = row.change;
    if (await _seen(c.changeId)) return;

    if (c.deviceId == _deviceId) {
      await _db.transaction(() => _markApplied(row));
      return;
    }

    final firstBad = blocked[c.entityId];
    if (firstBad != null && row.seq > firstBad) {
      _log('quarantined change ${c.changeId}: entity ${c.entityId} blocked');
      await _db.transaction(() => _quarantine(row, 'blocked'));
      return;
    }

    final Map<String, FieldValue> fields;
    try {
      fields = await _cipher.open(c.type, c.entityId, c.payload);
    } on FormatException {
      _log('quarantined change ${c.changeId}: unreadable payload');
      await _db.transaction(() => _quarantine(row, 'unreadable'));
      blocked[c.entityId] = math.min(firstBad ?? row.seq, row.seq);
      return;
    }

    _checkClock(c);
    final result = await _db.transaction(() async {
      final r = await _merger.apply(c, fields);
      await _markApplied(row);
      return r;
    });
    // After commit, never inside the transaction.
    switch (result) {
      case MergeResult.conflict:
        _events.add(MergeEvent(MergeKind.conflict, c.entityId));
      case MergeResult.resurrected:
        _events.add(MergeEvent(MergeKind.resurrected, c.entityId));
      case MergeResult.applied || MergeResult.ignored:
        break;
    }
  }

  void _checkClock(RemoteChange c) {
    final Hlc h;
    try {
      h = Hlc.parse(c.hlc);
    } on FormatException {
      return; // Malformed: the merger ignores it.
    }
    if (h.millis - _now() > _aheadLimit.inMilliseconds) {
      _log('remote clock more than 24 h ahead: change ${c.changeId}');
    }
  }

  Future<bool> _seen(String changeId) async {
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM kv WHERE key IN (?, ?) LIMIT 1',
          variables: [
            Variable<String>(appliedKey(changeId)),
            Variable<String>(quarantineKey(changeId)),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Must run inside the row's transaction.
  Future<void> _markApplied(PulledChange row) async {
    await _putKv(appliedKey(row.change.changeId), '${row.seq}');
    await _advanceCursor(row.seq);
  }

  /// Stores the raw row for a later replay. Must run inside the row's
  /// transaction.
  Future<void> _quarantine(PulledChange row, String reason) async {
    final c = row.change;
    await _putKv(
      quarantineKey(c.changeId),
      jsonEncode({
        'seq': row.seq,
        'changeId': c.changeId,
        'type': c.type.apiValue,
        'entityId': c.entityId,
        'deviceId': c.deviceId,
        'hlc': c.hlc,
        'payload': c.payload,
        'reason': reason,
      }),
    );
    await _advanceCursor(row.seq);
  }

  Future<void> _putKv(String key, String value) => _db
      .into(_db.kv)
      .insertOnConflictUpdate(KvCompanion.insert(key: key, value: value));

  Future<void> _advanceCursor(int seq) => _db.customStatement(
    'INSERT INTO kv (key, value) VALUES (?, ?) '
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value '
    'WHERE CAST(kv.value AS INTEGER) < CAST(excluded.value AS INTEGER)',
    [cursorKey, '$seq'],
  );

  Future<int> _cursor() async {
    final row = await (_db.select(
      _db.kv,
    )..where((t) => t.key.equals(cursorKey))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  /// Entity id → lowest quarantined seq for it.
  Future<Map<String, int>> _quarantinedEntities() async {
    final rows = await _db
        .customSelect("SELECT value FROM kv WHERE key LIKE 'sync.quarantine.%'")
        .get();
    final out = <String, int>{};
    for (final r in rows) {
      final m = decodeJsonMap(r.read<String>('value'));
      final id = m['entityId'];
      final seq = m['seq'];
      if (id is! String || seq is! int) continue;
      final prev = out[id];
      out[id] = prev == null ? seq : math.min(prev, seq);
    }
    return out;
  }

  /// Markers below the re-read window can never be read again.
  Future<void> _prune() async {
    final floor = await _cursor() - reReadWindow;
    if (floor <= 0) return;
    await _db.customStatement(
      "DELETE FROM kv WHERE key LIKE 'sync.applied.%' "
      'AND CAST(value AS INTEGER) < ?',
      [floor],
    );
  }

  // ---------------------------------------------------------------- push --

  /// Returns true when the outbox was empty at the end.
  Future<bool> _push() async {
    while (!_stopped) {
      final rows = await _db
          .customSelect(
            'SELECT change_id, entity_type, entity_id, fields FROM outbox '
            'ORDER BY rowid LIMIT ?',
            variables: [Variable<int>(pushBatchSize)],
          )
          .get();
      if (rows.isEmpty) return true;
      final batch = <RemoteChange>[];
      for (final r in rows) {
        batch.add(await _seal(r));
      }
      await _transport.push(batch);
      final ids = [for (final c in batch) c.changeId];
      await (_db.delete(_db.outbox)..where((t) => t.changeId.isIn(ids))).go();
    }
    return false;
  }

  Future<RemoteChange> _seal(QueryRow r) async {
    final changeId = r.read<String>('change_id');
    final type = EntityType.fromApi(r.read<String>('entity_type'));
    if (type == null) {
      throw FormatException('unknown entity type in outbox row $changeId');
    }
    final entityId = r.read<String>('entity_id');
    final fields = <String, FieldValue>{};
    var top = '';
    for (final e in decodeJsonMap(r.read<String>('fields')).entries) {
      final entry = e.value;
      if (entry is! Map) continue;
      final h = entry['h'];
      if (h is! String) continue;
      final b = entry['b'];
      fields[e.key] = FieldValue(entry['v'], h, b: b is String ? b : null);
      if (h.compareTo(top) > 0) top = h;
    }
    return RemoteChange(
      changeId: changeId,
      type: type,
      entityId: entityId,
      deviceId: _deviceId,
      hlc: top,
      payload: await _cipher.seal(type, entityId, fields),
    );
  }
}
