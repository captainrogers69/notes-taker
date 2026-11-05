import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:weave/core/database/weave_database.dart';
import 'package:weave/core/di/core_di.dart';
import 'package:weave/core/di/sync_di.dart';
import 'package:weave/core/sync/change_merger.dart';
import 'package:weave/core/sync/change_writer.dart';
import 'package:weave/core/sync/device_names.dart';
import 'package:weave/core/sync/hlc_clock.dart';
import 'package:weave/core/sync/in_memory_sync_transport.dart';
import 'package:weave/core/sync/entity_type.dart';
import 'package:weave/core/sync/sync_engine.dart';
import 'package:weave/core/sync/sync_status.dart';

void main() {
  test(
    'registerSync wires the engine, merger names and status cubit',
    () async {
      final sl = GetIt.asNewInstance();
      final db = WeaveDatabase.memory();
      final clock = HlcClock('dev-a');
      sl
        ..registerSingleton<WeaveDatabase>(db)
        ..registerSingleton<DeviceId>(const DeviceId('dev-a'))
        ..registerSingleton<HlcClock>(clock)
        ..registerSingleton<ChangeWriter>(ChangeWriter(db, clock));

      await registerSync(
        sl,
        transport: InMemorySyncTransport.newServer()('dev-a'),
        deviceName: 'Phone',
        connectivity: const Stream<bool>.empty(),
      );

      expect(await sl<DeviceNames>().nameOf('dev-a'), 'Phone');
      expect(await sl<DeviceNames>().nameOf('dev-z'), DeviceNames.fallback);
      expect(sl<ChangeMerger>(), isA<ChangeMerger>());
      expect(identical(sl<SyncEngine>(), sl<SyncEngine>()), isTrue);
      expect(sl<SyncStatusCubit>().state, SyncStatus.localOnly);

      await sl<SyncStatusCubit>().close();
      await sl<SyncEngine>().stop();
      await db.close();
    },
  );

  test('unregister then re-register uses the new device id', () async {
    final sl = GetIt.asNewInstance();
    final server = InMemorySyncTransport.newServer();
    final db = WeaveDatabase.memory();
    addTearDown(db.close);

    void core(String id) {
      final clock = HlcClock(id);
      sl
        ..registerSingleton<DeviceId>(DeviceId(id))
        ..registerSingleton<HlcClock>(clock)
        ..registerSingleton<ChangeWriter>(ChangeWriter(db, clock));
    }

    Future<void> sync(String id) => registerSync(
      sl,
      transport: server(id),
      deviceName: 'Phone',
      connectivity: const Stream<bool>.empty(),
      signedIn: Stream.value(true),
    );

    sl.registerSingleton<WeaveDatabase>(db);
    core('dev-old');
    await sync('dev-old');
    final cubit = sl<SyncStatusCubit>();
    final oldEngine = sl<SyncEngine>();
    await oldEngine.syncNow();

    // Task 13 sign-out: unregister, wipe, new id, register again.
    await unregisterSync(sl);
    await db.wipe();
    await sl.unregister<ChangeWriter>();
    await sl.unregister<HlcClock>();
    await sl.unregister<DeviceId>();
    core('dev-new');
    await sync('dev-new');

    final engine = sl<SyncEngine>();
    expect(identical(engine, oldEngine), isFalse);
    expect(identical(sl<SyncStatusCubit>(), cubit), isTrue);
    expect(sl<DeviceNames>().selfId, 'dev-new');

    await sl<ChangeWriter>().write(EntityType.list, 'l1', {'name': 'n'});
    await engine.syncNow();
    final pushed = await server('dev-other').pull(afterSeq: 0);
    expect(pushed.single.change.deviceId, 'dev-new');
    expect(pushed.single.change.hlc, endsWith('-dev-new'));
    expect(cubit.state, SyncStatus.synced, reason: 'follows the new engine');

    await unregisterSync(sl);
    await cubit.close();
  });
}
