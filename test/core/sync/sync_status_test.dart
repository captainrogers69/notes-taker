import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/sync_status.dart';

void main() {
  late StreamController<SyncStatus> engine;
  late StreamController<bool> auth;

  setUp(() {
    engine = StreamController<SyncStatus>.broadcast();
    auth = StreamController<bool>.broadcast();
  });
  tearDown(() async {
    await engine.close();
    await auth.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('localOnly while signed out, whatever the engine says', () async {
    final cubit = SyncStatusCubit(status: engine.stream, signedIn: auth.stream);
    expect(cubit.state, SyncStatus.localOnly);
    engine.add(SyncStatus.syncing);
    await settle();
    expect(cubit.state, SyncStatus.localOnly);
    await cubit.close();
  });

  test(
    'mirrors the engine while signed in, back to localOnly on sign-out',
    () async {
      final cubit = SyncStatusCubit(
        status: engine.stream,
        signedIn: auth.stream,
      );
      engine.add(SyncStatus.offline);
      await settle();
      auth.add(true);
      await settle();
      expect(cubit.state, SyncStatus.offline);
      engine.add(SyncStatus.synced);
      await settle();
      expect(cubit.state, SyncStatus.synced);
      auth.add(false);
      await settle();
      expect(cubit.state, SyncStatus.localOnly);
      await cubit.close();
    },
  );

  test('without an auth stream it stays localOnly (no auth yet)', () async {
    final cubit = SyncStatusCubit(status: engine.stream);
    engine.add(SyncStatus.error);
    await settle();
    expect(cubit.state, SyncStatus.localOnly);
    await cubit.close();
  });

  test('signedInNow starts from the engine status', () async {
    final cubit = SyncStatusCubit(
      status: engine.stream,
      initial: SyncStatus.syncing,
      signedInNow: true,
    );
    expect(cubit.state, SyncStatus.syncing);
    await cubit.close();
  });
}
