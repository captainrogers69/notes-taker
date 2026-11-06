import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show IOException;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_info.dart';
import 'entity_type.dart';
import 'pulled_change.dart';
import 'remote_change.dart';
import 'sync_offline_exception.dart';
import 'sync_transport.dart';

/// Starts a realtime INSERT feed on `public.changes` for [userId] and returns
/// a function that stops it. [onInsert] gets each inserted row; [onStatus]
/// gets the channel's subscribe status (`subscribed` again after a rejoin).
typedef InsertFeed =
    Future<void> Function() Function(
      String userId, {
      required void Function(Map<String, dynamic> row) onInsert,
      required void Function(RealtimeSubscribeStatus status) onStatus,
    });

/// [SyncTransport] over Supabase: PostgREST for `changes` / `devices`,
/// Realtime `postgres_changes` for hints.
///
/// - Network failures (`IOException` incl. `SocketException`, http
///   `ClientException`, or no answer within [timeout]) become
///   [SyncOfflineException]. PostgREST's own GET retries are turned off: the
///   engine retries with its own backoff, and a hidden 1 + 2 + 4 s retry
///   would only delay the `offline` status.
/// - [pull] maps rows with `is` checks and skips malformed rows (logged by
///   seq only).
/// - [pull] returns a [PulledPage] whose `full` / `lastSeq` describe the
///   raw page, so a malformed row never makes a full page look short.
/// - [hints] is a broadcast stream. While it has listeners, one realtime
///   channel is open for the signed-in user (filter `user_id=eq.<uid>`); it
///   is reopened when the auth user changes and after a channel error,
///   timeout or server-side close (5 s, doubling to 60 s). It emits for inserts by other devices and once each
///   time the channel (re)subscribes, so inserts missed while disconnected
///   are pulled.
/// - [dispose] closes the channel, the auth subscription and the stream.
///   `unregisterSync` calls it.
///
/// Logs carry ids, seqs and error types only.
class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport(
    this._client, {
    required this._deviceId,
    this.timeout = const Duration(seconds: 10),
    this.resubscribeBase = const Duration(seconds: 5),
    InsertFeed? insertFeed,
    Stream<String?> Function()? userIds,
    void Function(String message)? log,
  }) : _userIdsOverride = userIds,
       _log = log ?? ((m) => developer.log(m, name: 'SyncTransport')) {
    _insertFeed = insertFeed ?? _realtimeFeed;
    _hints = StreamController<void>.broadcast(
      onListen: _startFeed,
      onCancel: _stopFeed,
    );
  }

  static const changesTable = 'changes';
  static const devicesTable = 'devices';
  static const _changeColumns =
      'seq,change_id,entity_type,entity_id,device_id,hlc,payload';
  static const _deviceColumns = 'id,name,platform,last_seen_at';
  static const _resubscribeMax = Duration(seconds: 60);

  final SupabaseClient _client;
  final String _deviceId;
  final Duration timeout;

  /// First delay before reopening a failed channel; doubles up to 60 s.
  final Duration resubscribeBase;
  final Stream<String?> Function()? _userIdsOverride;
  final void Function(String) _log;
  late final InsertFeed _insertFeed;
  late final StreamController<void> _hints;

  StreamSubscription<String?>? _userSub;
  String? _uid;
  Future<void> Function()? _closeFeed;
  int _generation = 0;
  Future<void> _reopening = Future.value();
  Timer? _resubscribe;
  late Duration _resubscribeDelay = resubscribeBase;
  bool _disposed = false;

  /// Hints sent for other devices' inserts (not for resubscribes). For tests.
  @visibleForTesting
  int foreignInsertHints = 0;

  // ------------------------------------------------------------- REST --

  @override
  Future<void> push(List<RemoteChange> changes) async {
    if (changes.isEmpty) return;
    final rows = [for (final c in changes) changeToRow(c)];
    await _guard(
      _client
          .from(changesTable)
          .upsert(
            rows,
            onConflict: 'change_id',
            ignoreDuplicates: true,
            defaultToNull: false,
          )
          .retry(enabled: false, requestTimeout: timeout),
    );
  }

  @override
  Future<PulledPage> pull({required int afterSeq, int limit = 500}) async {
    final Object? rows = await _guard(
      _client
          .from(changesTable)
          .select(_changeColumns)
          .gt('seq', afterSeq)
          .order('seq', ascending: true)
          .limit(limit)
          .retry(enabled: false, requestTimeout: timeout),
    );
    if (rows is! List) return PulledPage(const [], full: false);
    final out = <PulledChange>[];
    int? lastSeq;
    for (final r in rows) {
      final seq = r is Map ? r['seq'] : null;
      if (seq is int && (lastSeq == null || seq > lastSeq)) lastSeq = seq;
      final p = rowToPulled(r);
      if (p == null) {
        _log('skipped malformed change row (seq ${seq is int ? seq : '?'})');
        continue;
      }
      out.add(p);
    }
    return PulledPage(out, full: rows.length >= limit, lastSeq: lastSeq);
  }

  @override
  Future<void> touchDevice(String id, String name, String platform) async {
    await _guard(
      _client
          .from(devicesTable)
          .upsert({
            'id': id,
            'name': name,
            'platform': platform,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'id')
          .retry(enabled: false, requestTimeout: timeout),
    );
  }

  @override
  Future<List<DeviceInfo>> devices() async {
    final Object? rows = await _guard(
      _client
          .from(devicesTable)
          .select(_deviceColumns)
          .order('last_seen_at', ascending: false)
          .retry(enabled: false, requestTimeout: timeout),
    );
    if (rows is! List) return const [];
    return [for (final r in rows) ?rowToDevice(r)];
  }

  /// Each request carries [timeout] as its own request timeout, which
  /// aborts a stalled request. The outer timeout is a backstop for work the
  /// request timeout does not bound (e.g. a session refresh before sending).
  Future<T> _guard<T>(Future<T> request) async {
    try {
      return await request.timeout(timeout + timeout ~/ 2);
    } on TimeoutException {
      throw const SyncOfflineException();
    } on IOException {
      throw const SyncOfflineException();
    } on ClientException {
      throw const SyncOfflineException();
    } on AuthRetryableFetchException {
      // The session refresh before the request could not reach the server
      // (e.g. waking up offline with an expired token).
      throw const SyncOfflineException();
    }
  }

  /// The `changes` row for [c]; `user_id` comes from the column default
  /// (`auth.uid()`).
  static Map<String, Object> changeToRow(RemoteChange c) => {
    'change_id': c.changeId,
    'entity_type': c.type.apiValue,
    'entity_id': c.entityId,
    'device_id': c.deviceId,
    'hlc': c.hlc,
    'payload': c.payload,
  };

  /// Maps a pulled row, or null when it is malformed.
  static PulledChange? rowToPulled(Object? row) {
    if (row is! Map) return null;
    final seq = row['seq'];
    final changeId = row['change_id'];
    final type = row['entity_type'];
    final entityId = row['entity_id'];
    final deviceId = row['device_id'];
    final hlc = row['hlc'];
    final payload = row['payload'];
    if (seq is! int ||
        changeId is! String ||
        type is! String ||
        entityId is! String ||
        deviceId is! String ||
        hlc is! String ||
        payload is! String) {
      return null;
    }
    final entityType = EntityType.fromApi(type);
    if (entityType == null || changeId.isEmpty || entityId.isEmpty) {
      return null;
    }
    return PulledChange(
      seq: seq,
      change: RemoteChange(
        changeId: changeId,
        type: entityType,
        entityId: entityId,
        deviceId: deviceId,
        hlc: hlc,
        payload: payload,
      ),
    );
  }

  /// Maps a `devices` row, or null when it is malformed.
  static DeviceInfo? rowToDevice(Object? row) {
    if (row is! Map) return null;
    final id = row['id'];
    final name = row['name'];
    final platform = row['platform'];
    final seen = row['last_seen_at'];
    if (id is! String || id.isEmpty || name is! String || platform is! String) {
      return null;
    }
    final lastSeen = seen is String ? DateTime.tryParse(seen) : null;
    return DeviceInfo(
      id: id,
      name: name,
      platform: platform,
      lastSeen: (lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc(),
    );
  }

  /// True when a realtime insert [row] should wake this device: it was
  /// written by another device (or its device is unknown).
  static bool isForeignInsert(Map<String, dynamic> row, String selfId) =>
      row['device_id'] != selfId;

  // ------------------------------------------------------------ hints --

  @override
  Stream<void> hints() => _disposed ? const Stream.empty() : _hints.stream;

  Stream<String?> _userIds() {
    final override = _userIdsOverride;
    if (override != null) return override();
    final auth = _client.auth;
    // Read the current user on each event: the auth stream replays older
    // events to new listeners.
    return Stream<String?>.multi((c) {
      c.add(auth.currentUser?.id);
      final sub = auth.onAuthStateChange.listen(
        (_) => c.add(auth.currentUser?.id),
        onError: (Object _) {},
      );
      c.onCancel = sub.cancel;
    });
  }

  void _startFeed() {
    if (_disposed) return;
    _userSub ??= _userIds().listen(_onUser);
  }

  Future<void> _stopFeed() async {
    final sub = _userSub;
    _userSub = null;
    _uid = null;
    // Queued with the reopens, so a listen right after this cancel opens
    // its channel after this close, never before it.
    final closing = _reopening = _reopening.then((_) => _closeChannel());
    await sub?.cancel();
    await closing;
  }

  void _onUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _resubscribeDelay = resubscribeBase;
    _queueReopen();
  }

  /// Reopens run one after another, so a quick user switch never leaves
  /// two channels open.
  void _queueReopen() {
    _reopening = _reopening.then((_) => _reopen());
  }

  Future<void> _reopen() async {
    await _closeChannel();
    final uid = _uid;
    if (uid == null || _disposed || _userSub == null) return;
    final gen = ++_generation;
    _closeFeed = _insertFeed(
      uid,
      onInsert: (row) {
        if (gen != _generation || _hints.isClosed) return;
        if (!isForeignInsert(row, _deviceId)) return;
        foreignInsertHints++;
        _hints.add(null);
      },
      onStatus: (status) => _onStatus(gen, status),
    );
  }

  void _onStatus(int gen, RealtimeSubscribeStatus status) {
    if (gen != _generation || _disposed) return;
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        _resubscribeDelay = resubscribeBase;
        // Catch up on anything inserted while not subscribed.
        if (!_hints.isClosed) _hints.add(null);
      // `closed` here is the server's doing: our own closes bump the
      // generation first, so their callbacks are ignored above.
      case RealtimeSubscribeStatus.channelError ||
          RealtimeSubscribeStatus.timedOut ||
          RealtimeSubscribeStatus.closed:
        _log('realtime channel ${status.name}; reopening');
        _resubscribe?.cancel();
        final delay = _resubscribeDelay;
        final next = _resubscribeDelay * 2;
        _resubscribeDelay = next > _resubscribeMax ? _resubscribeMax : next;
        _resubscribe = Timer(delay, () {
          if (gen == _generation) _queueReopen();
        });
    }
  }

  Future<void> _closeChannel() async {
    _generation++;
    _resubscribe?.cancel();
    _resubscribe = null;
    final close = _closeFeed;
    _closeFeed = null;
    if (close == null) return;
    try {
      await close();
    } on Object catch (e) {
      _log('closing realtime channel failed: ${e.runtimeType}');
    }
  }

  /// The default [InsertFeed]: a realtime channel on `public.changes`.
  Future<void> Function() _realtimeFeed(
    String userId, {
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function(RealtimeSubscribeStatus status) onStatus,
  }) {
    var closed = false;
    RealtimeChannel? channel;
    Future<void> openChannel() async {
      // The client sets the realtime token from its own auth listener,
      // asynchronously; set it here too so the join is never sent with the
      // anon key (RLS would then filter out every row).
      final token = _client.auth.currentSession?.accessToken;
      if (token != null) {
        try {
          await _client.realtime.setAuth(token);
        } on FormatException {
          // Expired token: the client refreshes it and pushes the new one.
        }
      }
      if (closed) return;
      // A topic per device: two transports on one client must not share a
      // topic, or the client leaves the older channel.
      channel = _client
          .channel('changes:$_deviceId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: changesTable,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (p) => onInsert(p.newRecord),
          )
          .subscribe((status, _) => onStatus(status));
    }

    Future<void> open() async {
      try {
        await openChannel();
      } on Object catch (e) {
        _log('opening realtime channel failed: ${e.runtimeType}');
        onStatus(RealtimeSubscribeStatus.channelError);
      }
    }

    final opening = open();
    return () async {
      closed = true;
      await opening;
      final c = channel;
      if (c != null) await _client.removeChannel(c);
    };
  }

  /// Closes the realtime channel, the auth subscription and [hints].
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopFeed();
    await _hints.close();
  }
}
