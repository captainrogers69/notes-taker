import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/sync/change_merger.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/device_directory.dart';
import 'package:weave/core/sync/device_info.dart';
import 'package:weave/core/sync/device_names.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/in_memory_sync_transport.dart';
import 'package:weave/core/sync/passthrough_payload_cipher.dart';
import 'package:weave/core/sync/pulled_change.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/sync_engine.dart';
import 'package:weave/core/sync/sync_transport.dart';

/// Counts `devices()` calls.
class _Counting implements SyncTransport {
  _Counting(this.inner);

  final InMemorySyncTransport inner;
  int deviceCalls = 0;

  /// When set, `devices()` waits for it.
  Completer<void>? devicesGate;
  final touched = <String>[];

  @override
  Future<void> push(List<RemoteChange> changes) => inner.push(changes);

  @override
  Future<PulledPage> pull({required int afterSeq, int limit = 500}) =>
      inner.pull(afterSeq: afterSeq, limit: limit);

  @override
  Stream<void> hints() => inner.hints();

  @override
  Future<void> touchDevice(String id, String name, String platform) {
    touched.add('$id/$name/$platform');
    return inner.touchDevice(id, name, platform);
  }

  @override
  Future<List<DeviceInfo>> devices() async {
    deviceCalls++;
    final gate = devicesGate;
    if (gate != null) await gate.future;
    return inner.devices();
  }
}

class _Device {
  _Device(this.id, this.name, InMemorySyncTransport Function(String) server) {
    db = WeaveDatabase.memory();
    clock = HlcClock(id);
    writer = ChangeWriter(db, clock);
    names = DeviceNames(db, selfId: id, selfName: name);
    transport = _Counting(server(id));
    directory = DeviceDirectory(
      transport: transport,
      names: names,
      platform: 'macos',
      now: () => wall,
    );
    engine = SyncEngine(
      db: db,
      transport: transport,
      cipher: const PassthroughPayloadCipher(),
      merger: ChangeMerger(db, clock, writer, names.nameOf),
      deviceId: id,
      onForeignDevices: directory.ensureKnown,
      log: (_) {},
    );
  }

  final String id;
  final String name;
  DateTime wall = DateTime.utc(2026, 11, 6);
  late final WeaveDatabase db;
  late final HlcClock clock;
  late final ChangeWriter writer;
  late final DeviceNames names;
  late final _Counting transport;
  late final DeviceDirectory directory;
  late final SyncEngine engine;

  Future<void> close() async {
    await engine.dispose();
    await db.close();
  }
}

void main() {
  test('start touches this device and caches every name', () async {
    final server = InMemorySyncTransport.newServer();
    final a = _Device('dev-a', 'Phone', server);
    final b = _Device('dev-b', 'Laptop', server);
    addTearDown(a.close);
    addTearDown(b.close);

    await a.directory.start();
    await b.directory.start();

    expect(b.transport.touched, ['dev-b/Laptop/macos']);
    expect(await b.names.nameOf('dev-a'), 'Phone');
    expect(await a.names.nameOf('dev-b'), DeviceNames.fallback);
  });

  test('a pull from an unknown device refreshes names before merging, '
      'at most once per interval', () async {
    final server = InMemorySyncTransport.newServer();
    final a = _Device('dev-a', 'Phone', server);
    final b = _Device('dev-b', 'Laptop', server);
    addTearDown(a.close);
    addTearDown(b.close);

    await b.directory.start(); // dev-a not registered yet
    expect(b.transport.deviceCalls, 1);

    await a.directory.start();
    await a.writer.write(EntityType.list, 'l1', {'name': 'n'});
    await a.engine.syncNow();

    // The refresh at start was just now: throttled.
    await b.engine.syncNow();
    expect(b.transport.deviceCalls, 1);
    expect(await b.names.nameOf('dev-a'), DeviceNames.fallback);

    b.wall = b.wall.add(const Duration(seconds: 31));
    await b.engine.syncNow();
    expect(b.transport.deviceCalls, 2);
    expect(await b.names.nameOf('dev-a'), 'Phone');

    // Known now: no more requests.
    b.wall = b.wall.add(const Duration(minutes: 5));
    await b.engine.syncNow();
    expect(b.transport.deviceCalls, 2);
  });

  test('a failing refresh never fails the sync pass', () async {
    final server = InMemorySyncTransport.newServer();
    final a = _Device('dev-a', 'Phone', server);
    final b = _Device('dev-b', 'Laptop', server);
    addTearDown(a.close);
    addTearDown(b.close);

    await a.writer.write(EntityType.list, 'l1', {'name': 'n'});
    await a.engine.syncNow();

    final failing = SyncEngine(
      db: b.db,
      transport: b.transport,
      cipher: const PassthroughPayloadCipher(),
      merger: ChangeMerger(b.db, b.clock, b.writer, b.names.nameOf),
      deviceId: b.id,
      onForeignDevices: (_) async => throw StateError('boom'),
      log: (_) {},
    );
    addTearDown(failing.dispose);
    await failing.syncNow();
    expect(failing.current.name, 'synced');
    expect(await b.db.select(b.db.lists).get(), hasLength(1));
  });

  test('dispose during start writes no names', () async {
    final server = InMemorySyncTransport.newServer();
    final a = _Device('dev-a', 'Phone', server);
    final b = _Device('dev-b', 'Laptop', server);
    addTearDown(a.close);
    addTearDown(b.close);
    await a.directory.start();

    final gate = b.transport.devicesGate = Completer<void>();
    final starting = b.directory.start();
    await pumpEventQueue();
    b.directory.dispose(); // sign-out while the devices read is in flight
    gate.complete();
    await starting;

    expect(await b.names.nameOf('dev-a'), DeviceNames.fallback);
    final cached = await b.db.select(b.db.kv).get();
    expect(cached.where((r) => r.key.startsWith('device.name.')), isEmpty);

    await b.directory.ensureKnown({'dev-a'});
    expect(b.transport.deviceCalls, 1, reason: 'disposed: no more reads');
  });

  test('ensureKnown waits for a refresh already in flight', () async {
    final server = InMemorySyncTransport.newServer();
    final a = _Device('dev-a', 'Phone', server);
    final b = _Device('dev-b', 'Laptop', server);
    addTearDown(a.close);
    addTearDown(b.close);
    await a.directory.start();

    final gate = b.transport.devicesGate = Completer<void>();
    final starting = b.directory.start();
    await pumpEventQueue();
    var known = false;
    final ensuring = b.directory
        .ensureKnown({'dev-a'})
        .then((_) => known = true);
    await pumpEventQueue();
    expect(known, isFalse, reason: 'waits for the running read');
    gate.complete();
    await Future.wait([starting, ensuring]);
    expect(await b.names.nameOf('dev-a'), 'Phone');
    expect(b.transport.deviceCalls, 1, reason: 'shared, not a second read');
  });

  test('watchCount counts cached device names', () async {
    final db = WeaveDatabase.memory();
    addTearDown(db.close);
    final names = DeviceNames(db, selfId: 'a', selfName: 'Mac');
    final seen = <int>[];
    final sub = DeviceNames.watchCount(db).listen(seen.add);
    await pumpEventQueue();
    await names.upsert({'a': 'Mac', 'b': 'Pixel 8', 'c': ''});
    await db
        .into(db.kv)
        .insert(KvCompanion.insert(key: 'device.id', value: 'a'));
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 2, reason: 'empty names skipped, other keys ignored');
  });
}
