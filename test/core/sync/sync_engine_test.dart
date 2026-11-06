import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_merger.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/conflict_losers.dart';
import 'package:weave/core/sync/device_info.dart';
import 'package:weave/core/sync/device_names.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/field_value.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/in_memory_sync_transport.dart';
import 'package:weave/core/sync/passthrough_payload_cipher.dart';
import 'package:weave/core/sync/purge_log.dart';
import 'package:weave/core/sync/pulled_change.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/sync_engine.dart';
import 'package:weave/core/sync/sync_status.dart';
import 'package:weave/core/sync/sync_transport.dart';

/// Wraps an [InMemorySyncTransport]: records calls, can fail pushes and can
/// hold a pull until a gate opens.
class _SpyTransport implements SyncTransport {
  _SpyTransport(this.inner);

  final InMemorySyncTransport inner;
  final calls = <String>[];
  final pushedIds = <String>[];
  Object? pushError;

  /// Returns each page reversed with its first row repeated.
  bool scramble = false;
  Completer<void>? pullGate;
  Completer<void>? pullStarted;

  @override
  Future<void> push(List<RemoteChange> changes) async {
    calls.add('push');
    final error = pushError;
    if (error != null) throw error;
    await inner.push(changes);
    pushedIds.addAll(changes.map((c) => c.changeId));
  }

  /// Seqs left out of returned pages, as a transport drops malformed rows
  /// (the page keeps its raw `full` / `lastSeq`).
  Set<int> dropSeqs = {};

  @override
  Future<PulledPage> pull({required int afterSeq, int limit = 500}) async {
    calls.add('pull');
    pullStarted?.complete();
    pullStarted = null;
    final gate = pullGate;
    if (gate != null) await gate.future;
    final page = await inner.pull(afterSeq: afterSeq, limit: limit);
    final rows = [
      for (final r in page.rows)
        if (!dropSeqs.contains(r.seq)) r,
    ];
    if (!scramble || rows.isEmpty) {
      return PulledPage(rows, full: page.full, lastSeq: page.lastSeq);
    }
    return PulledPage(
      [...rows.reversed, rows.first],
      full: page.full,
      lastSeq: page.lastSeq,
    );
  }

  @override
  Stream<void> hints() => inner.hints();

  @override
  Future<void> touchDevice(String id, String name, String platform) =>
      inner.touchDevice(id, name, platform);

  @override
  Future<List<DeviceInfo>> devices() => inner.devices();
}

/// A merger that can fail after applying, to prove the whole row rolls back.
class _FlakyMerger extends ChangeMerger {
  _FlakyMerger(super.db, super.clock, super.writer, super.deviceName);

  bool fail = false;

  /// Fails only for changes to these entity ids.
  Set<String> failFor = {};
  int calls = 0;
  final appliedEntities = <String>[];

  @override
  Future<MergeResult> apply(
    RemoteChange meta,
    Map<String, FieldValue> fields,
  ) async {
    calls++;
    final result = await super.apply(meta, fields);
    if (fail || failFor.contains(meta.entityId)) throw StateError('boom');
    appliedEntities.add(meta.entityId);
    return result;
  }
}

const _names = {'dev-a': 'Phone', 'dev-b': 'Laptop'};

/// One simulated device with a real engine on the shared in-memory server.
class _Device {
  _Device(
    this.id,
    InMemorySyncTransport Function(String) server, {
    int pageSize = 500,
    Stream<bool>? connectivity,
    Future<bool> Function()? checkOnline,
  }) {
    db = WeaveDatabase.memory();
    clock = HlcClock(id, now: () => wall);
    writer = ChangeWriter(db, clock, now: () => wall);
    names = DeviceNames(db, selfId: id, selfName: _names[id] ?? 'Tablet');
    merger = _FlakyMerger(db, clock, writer, names.nameOf);
    transport = _SpyTransport(server(id));
    engine = SyncEngine(
      db: db,
      transport: transport,
      cipher: const PassthroughPayloadCipher(),
      merger: merger,
      deviceId: id,
      connectivity: connectivity,
      checkOnline: checkOnline,
      pageSize: pageSize,
      timing: const SyncTiming(
        debounce: Duration(milliseconds: 20),
        fallback: Duration(seconds: 60),
        backoffBase: Duration(seconds: 2),
        backoffMax: Duration(seconds: 60),
      ),
      now: () => wall,
      log: logs.add,
    );
    events = [];
    engine.events.listen(events.add);
  }

  final String id;
  int wall = 1000;
  final logs = <String>[];
  late final List<MergeEvent> events;
  late final WeaveDatabase db;
  late final HlcClock clock;
  late final ChangeWriter writer;
  late final DeviceNames names;
  late final _FlakyMerger merger;
  late final _SpyTransport transport;
  late final SyncEngine engine;

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;

  Future<String?> kv(String key) async {
    final row = await (db.select(
      db.kv,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<List<String>> kvKeys(String prefix) async {
    final rows = await db
        .customSelect(
          'SELECT key FROM kv WHERE key LIKE ? ORDER BY key',
          variables: [Variable<String>('$prefix%')],
        )
        .get();
    return [for (final r in rows) r.read<String>('key')];
  }

  Future<List<ListRow>> lists() => (db.select(
    db.lists,
  )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

  Future<List<ItemRow>> items() => (db.select(
    db.items,
  )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();

  Future<ItemRow?> item(String itemId) => (db.select(
    db.items,
  )..where((t) => t.id.equals(itemId))).getSingleOrNull();

  /// Synced state of every row, for convergence checks.
  Future<List<Object?>> snapshot() async => [
    for (final r in await lists()) [r.id, r.name, r.deletedAt, r.sortKey],
    for (final r in await items())
      [..._synced(r), (jsonDecode(r.fieldHlcs) as Map)..remove('text.b')],
  ];

  Future<void> close() async {
    await engine.dispose();
    await db.close();
  }
}

/// Polls [check] until true; fails after [timeout].
Future<void> _until(
  FutureOr<bool> Function() check, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final end = DateTime.now().add(timeout);
  while (!await check()) {
    if (DateTime.now().isAfter(end)) fail('condition not met in $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> _rounds(_Device x, _Device y, int n) async {
  for (var i = 0; i < n; i++) {
    await x.engine.syncNow();
    await y.engine.syncNow();
  }
}

/// After convergence one more round pushes nothing and changes nothing.
Future<void> _expectQuiet(_Device x, _Device y) async {
  expect(await x.outboxCount(), 0);
  expect(await y.outboxCount(), 0);
  final before = await x.snapshot();
  final pushes = x.transport.pushedIds.length + y.transport.pushedIds.length;
  await _rounds(x, y, 1);
  expect(x.transport.pushedIds.length + y.transport.pushedIds.length, pushes);
  expect(await x.snapshot(), before);
  expect(await y.snapshot(), before);
}

/// Item rows minus the local-only conflict columns (each device resolves its
/// own; order of losers may differ).
List<Object?> _synced(ItemRow r) => [
  r.id,
  r.listId,
  r.kind,
  r.body,
  r.done,
  r.doneAt,
  r.indent,
  r.sortKey,
  r.dueDate,
  r.dueMinutes,
  r.reminders,
  r.repeat,
  r.deletedAt,
];

Set<ConflictLoser> _loserSet(ItemRow r) =>
    decodeLosers(r.conflictText, r.conflictFrom).toSet();

Future<void> _seedList(_Device d, {int items = 0}) async {
  await d.writer.write(EntityType.list, 'l1', {'name': 'Groceries'});
  for (var i = 1; i <= items; i++) {
    await d.writer.write(EntityType.item, 'i$i', {
      'listId': 'l1',
      'text': 'task $i',
    });
  }
}

void main() {
  late InMemorySyncTransport Function(String) server;
  late _Device a;
  late _Device b;

  setUp(() async {
    server = InMemorySyncTransport.newServer();
    a = _Device('dev-a', server);
    b = _Device('dev-b', server);
    await a.names.upsert(_names);
    await b.names.upsert(_names);
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  group('Task 11 plan tests', () {
    test('two engines converge on lists and items', () async {
      await _seedList(a, items: 3);
      await a.engine.syncNow();
      await b.engine.syncNow();

      expect(await b.lists(), await a.lists());
      expect((await b.items()).map(_synced), (await a.items()).map(_synced));
      expect(await b.items(), hasLength(3));
      expect(await a.outboxCount(), 0);
    });

    test('offline edits converge when back online', () async {
      await _seedList(a, items: 2);
      await a.engine.syncNow();
      await b.engine.syncNow();

      b.transport.inner.offline = true;
      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'done': true});
      b.wall = 2100;
      await b.writer.write(EntityType.item, 'i2', {'text': 'from b'});
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect(b.engine.current, SyncStatus.offline);
      b.transport.inner.offline = false;

      for (var i = 0; i < 2; i++) {
        await a.engine.syncNow();
        await b.engine.syncNow();
      }
      expect((await b.items()).map(_synced), (await a.items()).map(_synced));
      expect((await a.item('i1'))!.done, isTrue);
      expect((await a.item('i2'))!.body, 'from b');
    });

    test('concurrent text edits keep both across devices', () async {
      await _seedList(a, items: 1);
      await a.engine.syncNow();
      await b.engine.syncNow();

      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'a version'});
      b.wall = 3000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b version'});
      for (var i = 0; i < 2; i++) {
        await a.engine.syncNow();
        await b.engine.syncNow();
      }

      final rowA = (await a.item('i1'))!;
      final rowB = (await b.item('i1'))!;
      expect(rowA.body, 'b version');
      expect(rowB.body, 'b version');
      expect(_loserSet(rowA), _loserSet(rowB));
      expect(
        {for (final l in _loserSet(rowA)) (l.text, l.from)},
        {('a version', 'Phone')},
      );
      expect(a.events, contains(const MergeEvent(MergeKind.conflict, 'i1')));
      expect(b.events, contains(const MergeEvent(MergeKind.conflict, 'i1')));
    });

    test('push failure keeps outbox rows', () async {
      await _seedList(a, items: 2);
      a.transport.pushError = StateError('server down');
      await a.engine.syncNow();

      expect(await a.outboxCount(), 3);
      expect(a.engine.current, SyncStatus.error);
      expect(a.engine.retryIn, const Duration(seconds: 2));

      a.transport.pushError = null;
      await a.engine.syncNow();
      expect(await a.outboxCount(), 0);
      expect(a.engine.current, SyncStatus.synced);
      expect(a.engine.retryIn, isNull);
    });

    test('late commit with lower seq is still applied', () async {
      await a.writer.write(EntityType.list, 'l1', {'name': 'First'});
      a.transport.inner.commitOutOfOrder();
      await a.engine.syncNow(); // l1 gets seq 1 but stays invisible.
      await a.writer.write(EntityType.list, 'l2', {'name': 'Second'});
      await a.engine.syncNow(); // l2 gets seq 2, visible.

      await b.engine.syncNow();
      expect((await b.lists()).map((l) => l.id), ['l2']);
      expect(await b.kv('sync.cursor'), '2');

      a.transport.inner.releaseHeld();
      await b.engine.syncNow();
      expect((await b.lists()).map((l) => l.id), ['l1', 'l2']);
    });

    test('delete on A trashes on B', () async {
      await _seedList(a, items: 1);
      await a.engine.syncNow();
      await b.engine.syncNow();

      a.wall = 5000;
      await a.writer.write(EntityType.list, 'l1', {'deletedAt': 5000});
      await a.engine.syncNow();
      await b.engine.syncNow();

      expect((await b.lists()).single.deletedAt, 5000);
    });

    test('status goes syncing then synced', () async {
      expect(a.engine.current, SyncStatus.syncing);
      await a.engine.syncNow();
      expect(a.engine.current, SyncStatus.synced);
      await _seedList(a, items: 1);
      final seen = <SyncStatus>[];
      final sub = a.engine.status.listen(seen.add);
      await a.engine.syncNow();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen, [SyncStatus.syncing, SyncStatus.synced]);
    });

    test('pull runs before push', () async {
      await _seedList(a);
      await a.engine.syncNow();
      expect(a.transport.calls, ['pull', 'push']);
    });
  });

  group('review requirements', () {
    test('applied ids are skipped on re-read: no stale conflict', () async {
      await _seedList(a, items: 1);
      await a.engine.syncNow();
      await b.engine.syncNow();

      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'a1'});
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect((await b.item('i1'))!.body, 'a1');

      // B edits twice on top of a1; its later passes re-read a1 (within the
      // cursor - 100 window). Re-merging it would see a concurrent older
      // edit and keep a stale loser.
      b.wall = 3000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b1'});
      b.wall = 3100;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b2'});
      await b.engine.syncNow();
      await b.engine.syncNow();

      final row = (await b.item('i1'))!;
      expect(row.body, 'b2');
      expect(row.conflictText, isNull);
      expect(b.events, isEmpty);
    });

    test('cursor and applied id roll back with a failed apply', () async {
      await _seedList(a);
      await a.engine.syncNow();

      b.merger.fail = true;
      await b.engine.syncNow();
      expect(b.engine.current, SyncStatus.error);
      expect(await b.lists(), isEmpty);
      expect(await b.kv('sync.cursor'), isNull);
      expect(await b.kvKeys('sync.applied.'), isEmpty);

      b.merger.fail = false;
      await b.engine.syncNow();
      expect((await b.lists()).single.name, 'Groceries');
      expect(await b.kv('sync.cursor'), '1');
      expect(await b.kvKeys('sync.applied.'), hasLength(1));
    });

    test('quarantine blocks later changes to that entity only', () async {
      await _seedList(a, items: 2);
      await a.engine.syncNow();
      await b.engine.syncNow();

      // A third device pushes an unreadable change for i1.
      await server('dev-x').push([
        const RemoteChange(
          changeId: 'bad-1',
          type: EntityType.item,
          entityId: 'i1',
          deviceId: 'dev-x',
          hlc: '000000000001500-00000-dev-x',
          payload: 'not base64 at all!',
        ),
      ]);
      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'secret one'});
      await a.writer.write(EntityType.item, 'i2', {'text': 'secret two'});
      await a.engine.syncNow();
      await b.engine.syncNow();

      expect((await b.item('i1'))!.body, 'task 1');
      expect((await b.item('i2'))!.body, 'secret two');
      final quarantined = await b.kvKeys('sync.quarantine.');
      expect(quarantined, hasLength(2));
      expect(quarantined, contains('sync.quarantine.bad-1'));
      expect(await b.kv('sync.applied.bad-1'), isNull);
      final stored = jsonDecode((await b.kv('sync.quarantine.bad-1'))!);
      expect(stored, containsPair('payload', 'not base64 at all!'));
      expect(stored, containsPair('entityId', 'i1'));
      expect(stored, containsPair('reason', 'unreadable'));
      final blockedKey = quarantined.firstWhere(
        (k) => k != 'sync.quarantine.bad-1',
      );
      expect(
        jsonDecode((await b.kv(blockedKey))!),
        containsPair('reason', 'blocked'),
      );
      expect(b.engine.current, SyncStatus.synced);

      // A later pass still blocks new changes for i1.
      a.wall = 3000;
      await a.writer.write(EntityType.item, 'i1', {'done': true});
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect((await b.item('i1'))!.done, isFalse);
      expect(await b.kvKeys('sync.quarantine.'), hasLength(3));

      expect(b.logs.where((l) => l.contains('bad-1')), isNotEmpty);
      expect(b.logs.where((l) => l.contains('secret')), isEmpty);
    });

    test('own rows are skipped but advance the cursor', () async {
      await _seedList(a, items: 2);
      await a.engine.syncNow();
      final before = a.merger.calls;
      await a.engine.syncNow();
      expect(a.merger.calls, before);
      expect(await a.kv('sync.cursor'), '3');
      expect(await a.kvKeys('sync.applied.'), hasLength(3));
    });

    test('rows apply in ascending seq order across pages', () async {
      final c = _Device('dev-c', server, pageSize: 2);
      addTearDown(c.close);
      await _seedList(a, items: 4);
      await a.engine.syncNow();
      await c.engine.syncNow();
      expect(c.merger.appliedEntities, ['l1', 'i1', 'i2', 'i3', 'i4']);
      expect(await c.items(), hasLength(4));
      expect(await c.kv('sync.cursor'), '5');
      expect(c.transport.calls.where((x) => x == 'pull').length, 3);
    });

    test('a full page with a dropped malformed row keeps paging', () async {
      final c = _Device('dev-c', server, pageSize: 2);
      addTearDown(c.close);
      await _seedList(a, items: 4); // seqs 1..5
      await a.engine.syncNow();
      c.transport.dropSeqs = {2}; // the transport skipped a malformed row
      await c.engine.syncNow();
      expect(c.merger.appliedEntities, ['l1', 'i2', 'i3', 'i4']);
      expect(await c.kv('sync.cursor'), '5');
      expect(c.transport.calls.where((x) => x == 'pull').length, 3);
    });

    test('a full page of only malformed rows still pages on', () async {
      final c = _Device('dev-c', server, pageSize: 2);
      addTearDown(c.close);
      await _seedList(a, items: 4);
      await a.engine.syncNow();
      c.transport.dropSeqs = {1, 2};
      await c.engine.syncNow();
      expect(c.merger.appliedEntities, ['i2', 'i3', 'i4']);
      expect(await c.kv('sync.cursor'), '5');
    });

    test('applied markers are pruned below the re-read window', () async {
      for (var i = 0; i < 110; i++) {
        await a.writer.write(EntityType.list, 'l$i', {'name': 'n'});
      }
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect(await b.kv('sync.cursor'), '110');
      // Seqs 1..9 are below cursor - 100 = 10 and never re-read.
      expect(await b.kvKeys('sync.applied.'), hasLength(101));
    });

    test('concurrent syncNow calls do not double-push', () async {
      await _seedList(a, items: 2);
      await Future.wait([
        a.engine.syncNow(),
        a.engine.syncNow(),
        a.engine.syncNow(),
      ]);
      expect(a.transport.pushedIds, hasLength(3));
      expect(a.transport.pushedIds.toSet(), hasLength(3));
      expect(a.transport.calls.where((x) => x == 'push'), hasLength(1));
    });

    test('stop during a pass waits for it and stays quiet', () async {
      await _seedList(a, items: 1);
      a.engine.start();
      a.transport.pullGate = Completer<void>();
      a.transport.pullStarted = Completer<void>();
      // start() kicks off a pass; it may already be past its first pull.
      unawaited(a.engine.syncNow());
      await a.transport.pullStarted!.future.timeout(
        const Duration(seconds: 1),
        onTimeout: () {},
      );
      var stopped = false;
      final stopping = a.engine.stop().then((_) => stopped = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(stopped, isFalse);
      a.transport.pullGate!.complete();
      await stopping;
      expect(stopped, isTrue);

      final calls = a.transport.calls.length;
      await a.writer.write(EntityType.item, 'i1', {'done': true});
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(a.transport.calls.length, calls);
    });

    test('outbox insert triggers a debounced pass after start', () async {
      a.engine.start();
      await _until(() => a.engine.current == SyncStatus.synced);
      await _seedList(a, items: 2);
      await _until(() async => await a.outboxCount() == 0);
      await _until(() => a.engine.current == SyncStatus.synced);
    });

    test('a hint from another device triggers a pull on B', () async {
      b.engine.start();
      await _until(() => b.engine.current == SyncStatus.synced);
      await _seedList(a, items: 1);
      await a.engine.syncNow();
      await _until(() async => (await b.items()).length == 1);
    });

    test('offline then online: offline status, then synced', () async {
      final net = StreamController<bool>.broadcast();
      addTearDown(net.close);
      final c = _Device('dev-c', server, connectivity: net.stream);
      addTearDown(c.close);
      c.engine.start();
      await _until(() => c.engine.current == SyncStatus.synced);
      net.add(false);
      await _until(() => c.engine.current == SyncStatus.offline);
      await _seedList(c, items: 1);
      await c.engine.syncNow();
      expect(c.engine.current, SyncStatus.offline);
      expect(c.transport.calls.where((x) => x == 'push'), isEmpty);
      expect(await c.outboxCount(), 2);

      net.add(true);
      await _until(() => c.engine.current == SyncStatus.synced);
      expect(await c.outboxCount(), 0);
    });

    test('transport offline maps to offline status', () async {
      a.transport.inner.offline = true;
      await a.engine.syncNow();
      expect(a.engine.current, SyncStatus.offline);
      expect(a.engine.retryIn, const Duration(seconds: 2));
      a.transport.inner.offline = false;
      await a.engine.syncNow();
      expect(a.engine.current, SyncStatus.synced);
    });

    test('backoff doubles from 2 s and caps at 60 s', () {
      expect([
        for (var i = 1; i <= 7; i++)
          SyncEngine.backoffFor(i, const SyncTiming()),
      ], [2, 4, 8, 16, 32, 60, 60].map((s) => Duration(seconds: s)));
    });

    test('logs a remote clock more than 24 h ahead, by id only', () async {
      a.wall = 1000 + const Duration(hours: 25).inMilliseconds;
      await _seedList(a);
      await a.engine.syncNow();
      await b.engine.syncNow();
      expect(b.logs.where((l) => l.contains('ahead')), hasLength(1));
      expect(b.logs.where((l) => l.contains('Groceries')), isEmpty);
    });

    test('a shuffled page with a duplicate applies once, by seq', () async {
      final c = _Device('dev-c', server);
      addTearDown(c.close);
      c.transport.scramble = true;
      await _seedList(a, items: 3);
      await a.engine.syncNow();
      await c.engine.syncNow();
      expect(c.merger.appliedEntities, ['l1', 'i1', 'i2', 'i3']);
      expect(c.merger.calls, 4);
    });

    test(
      'exactly full last page, then a late commit inside the window',
      () async {
        final c = _Device('dev-c', server, pageSize: 3);
        addTearDown(c.close);
        final x = _Device('dev-x', server);
        addTearDown(x.close);
        await a.writer.write(EntityType.list, 'l1', {'name': 'x'});
        await a.writer.write(EntityType.list, 'l2', {'name': 'x'});
        await a.engine.syncNow(); // seq 1, 2
        await x.writer.write(EntityType.list, 'lx', {'name': 'late'});
        x.transport.inner.commitOutOfOrder();
        await x.engine.syncNow(); // seq 3, held
        await a.writer.write(EntityType.list, 'l3', {'name': 'x'});
        await a.writer.write(EntityType.list, 'l4', {'name': 'x'});
        await a.engine.syncNow(); // seq 4, 5
        await a.writer.write(EntityType.list, 'l5', {'name': 'x'});
        await a.engine.syncNow(); // seq 6: pages [1,2,4] [5,6] then
        await c.engine.syncNow();
        expect(await c.lists(), hasLength(5));
        x.transport.inner.releaseHeld();
        await c.engine.syncNow();
        expect(await c.lists(), hasLength(6));
      },
    );

    test('exactly full page ends with an empty pull', () async {
      final c = _Device('dev-c', server, pageSize: 2);
      addTearDown(c.close);
      await _seedList(a, items: 3); // seq 1..4: two full pages
      await a.engine.syncNow();
      await c.engine.syncNow();
      expect(await c.items(), hasLength(3));
      expect(c.transport.calls.where((x) => x == 'pull'), hasLength(3));
      expect(c.engine.current, SyncStatus.synced);
    });

    test('trash on A vs newer edit on B converges, then stays quiet', () async {
      await _seedList(a, items: 2);
      await _rounds(a, b, 1);
      a.wall = 5000;
      await a.writer.write(EntityType.item, 'i1', {'deletedAt': 5000});
      b.wall = 6000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'edited'});
      await _rounds(a, b, 2);
      expect(await a.snapshot(), await b.snapshot());
      expect((await a.item('i1'))!.deletedAt, isNull);
      await _expectQuiet(a, b);
    });

    test(
      'trash on A newer than edit on B converges, then stays quiet',
      () async {
        await _seedList(a, items: 2);
        await _rounds(a, b, 1);
        b.wall = 5000;
        await b.writer.write(EntityType.item, 'i1', {'text': 'edited'});
        a.wall = 6000;
        await a.writer.write(EntityType.item, 'i1', {'deletedAt': 6000});
        await _rounds(b, a, 2);
        expect(await a.snapshot(), await b.snapshot());
        await _expectQuiet(a, b);
      },
    );

    test(
      'delete forever on A vs edit on B converges, then stays quiet',
      () async {
        await _seedList(a, items: 2);
        await _rounds(a, b, 1);
        b.wall = 5000;
        await b.writer.write(EntityType.item, 'i1', {'text': 'edited'});
        await b.engine.syncNow();
        a.wall = 6000;
        await a.db.transaction(() async {
          await dropPending(a.db, ['l1', 'i1', 'i2']);
          await a.writer.write(EntityType.list, 'l1', {'deletedAt': 0});
          await deletePurgedRows(a.db, listId: 'l1');
          await markPurged(a.db, ['l1', 'i1', 'i2']);
        });
        await _rounds(a, b, 2);
        expect(await a.snapshot(), isEmpty);
        expect(await b.snapshot(), isEmpty);
        await _expectQuiet(a, b);
      },
    );

    test(
      'apply error: pull stops at the row, push still runs, retried',
      () async {
        await _seedList(a, items: 2);
        await _rounds(a, b, 1);
        a.wall = 2000;
        await a.writer.write(EntityType.item, 'i1', {'done': true});
        await a.writer.write(EntityType.item, 'i2', {'done': true});
        await a.engine.syncNow();
        final cursor = await b.kv('sync.cursor');
        b.wall = 2100;
        await b.writer.write(EntityType.list, 'l1', {'name': 'mine'});
        b.merger.failFor = {'i1'};

        await b.engine.syncNow();
        expect(b.engine.current, SyncStatus.error);
        expect(await b.outboxCount(), 0, reason: 'push still ran');
        expect(await b.kv('sync.cursor'), cursor);
        expect((await b.item('i1'))!.done, isFalse);
        expect((await b.item('i2'))!.done, isFalse, reason: 'pull stopped');
        expect(await b.kvKeys('sync.quarantine.'), isEmpty);

        b.merger.failFor = {};
        await b.engine.syncNow();
        expect(b.engine.current, SyncStatus.synced);
        expect((await b.item('i1'))!.done, isTrue);
        expect((await b.item('i2'))!.done, isTrue);
      },
    );

    test('no MergeEvent when the row transaction rolls back', () async {
      await _seedList(a, items: 1);
      await _rounds(a, b, 1);
      a.wall = 2000;
      await a.writer.write(EntityType.item, 'i1', {'text': 'a version'});
      b.wall = 3000;
      await b.writer.write(EntityType.item, 'i1', {'text': 'b version'});
      await a.engine.syncNow();
      b.merger.fail = true;
      await b.engine.syncNow();
      expect(b.events, isEmpty);
      expect((await b.item('i1'))!.conflictText, isNull);
      b.merger.fail = false;
      await b.engine.syncNow();
      expect(b.events, [const MergeEvent(MergeKind.conflict, 'i1')]);
    });

    test('start after stop does not keep a stale offline state', () async {
      final net = StreamController<bool>.broadcast();
      addTearDown(net.close);
      final c = _Device('dev-c', server, connectivity: net.stream);
      addTearDown(c.close);
      c.engine.start();
      await _until(() => c.engine.current == SyncStatus.synced);
      net.add(false);
      await _until(() => c.engine.current == SyncStatus.offline);
      await c.engine.stop();
      net.add(true); // Not seen: the engine is stopped.
      c.engine.start();
      await c.writer.write(EntityType.list, 'l9', {'name': 'x'});
      await _until(() => c.engine.current == SyncStatus.synced);
      expect(await c.outboxCount(), 0);
    });

    test('start asks for current connectivity before the first pass', () async {
      final c = _Device('dev-c', server, checkOnline: () async => false);
      addTearDown(c.close);
      await _seedList(c);
      c.engine.start();
      await _until(() => c.engine.current == SyncStatus.offline);
      expect(c.transport.calls, isEmpty);
    });

    test('first connectivity report after start does not add a pass', () async {
      final net = StreamController<bool>.broadcast();
      addTearDown(net.close);
      final c = _Device('dev-c', server, connectivity: net.stream);
      addTearDown(c.close);
      c.engine.start();
      net.add(true);
      await _until(() => c.engine.current == SyncStatus.synced);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.transport.calls.where((x) => x == 'pull'), hasLength(1));
    });

    test('dispose closes the streams', () async {
      final c = _Device('dev-c', server);
      var done = 0;
      c.engine.status.listen(null, onDone: () => done++);
      c.engine.events.listen(null, onDone: () => done++);
      await c.close();
      expect(done, 2);
      expect(c.engine.start, throwsStateError);
    });

    test('device names come from the local cache with a fallback', () async {
      expect(await b.names.nameOf('dev-b'), 'Laptop');
      expect(await b.names.nameOf('dev-z'), DeviceNames.fallback);
      await b.names.upsert({'dev-z': 'Tablet', 'dev-y': ''});
      expect(await b.names.nameOf('dev-z'), 'Tablet');
      expect(await b.names.nameOf('dev-y'), DeviceNames.fallback);
    });

    test('malformed remote HLC is ignored, not an error', () async {
      await _seedList(a);
      await a.engine.syncNow();
      await b.engine.syncNow();
      await server('dev-x').push([
        RemoteChange(
          changeId: 'odd-1',
          type: EntityType.list,
          entityId: 'l1',
          deviceId: 'dev-x',
          hlc: 'garbage',
          payload: await const PassthroughPayloadCipher().seal(
            EntityType.list,
            'l1',
            {'name': const FieldValue('x', 'garbage')},
          ),
        ),
      ]);
      await b.engine.syncNow();
      expect(b.engine.current, SyncStatus.synced);
      expect((await b.lists()).single.name, 'Groceries');
      expect(await b.kv('sync.applied.odd-1'), isNotNull);
    });
  });
}
