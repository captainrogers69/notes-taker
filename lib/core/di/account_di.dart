import 'package:get_it/get_it.dart';

import '../../features/account/presentation/session_cubit.dart';
import '../auth/auth_gateway.dart';
import '../database/weave_database.dart';
import '../notifications/notification_canceller.dart';
import '../sync/bulk_uploader.dart';
import '../sync/outbox_gate.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_status.dart';
import 'core_di.dart';
import 'sync_di.dart';

/// Registers sync for the current `DeviceId` (a `registerSync` call with the
/// app's transport and options). Called at start, after sign-out and after
/// a server-side sign-out.
typedef SyncRegistrar = Future<void> Function(GetIt sl);

/// Registers the global [SessionCubit] and what it uses. Needs
/// `registerCore` first. Call before [SyncRegistrar] so `registerSync` can
/// take `signedIn` / `signedInNow` from the session; then call
/// `SessionCubit.restore()` (it starts sync when a session is restored).
///
/// [registerSyncFor] is null when the app runs local-only (no backend):
/// then nothing is started and sign-out only renews the device identity.
void registerAccount(
  GetIt sl, {
  required AuthGateway auth,
  SyncRegistrar? registerSyncFor,
  NotificationCanceller notifications = const NoopNotificationCanceller(),
  void Function(String message)? log,
}) {
  final db = sl<WeaveDatabase>();
  final engine = sl.isRegistered<SyncEngine>;
  sl
    ..registerSingleton<AuthGateway>(auth)
    ..registerSingleton<NotificationCanceller>(notifications)
    ..registerSingleton<BulkUploader>(BulkUploader(db))
    ..registerSingleton<SessionCubit>(
      SessionCubit(
        auth: auth,
        db: db,
        outbox: sl<OutboxGate>(),
        uploader: sl<BulkUploader>(),
        notifications: notifications,
        log: log,
        // Sign-out order (Task 13): stop → wipe → notifications → auth →
        // renewDevice → register (re-attaches the SyncStatusCubit).
        sync: SessionSync(
          start: () {
            if (engine()) startSync(sl);
          },
          stop: () => unregisterSync(sl),
          register: () async {
            if (registerSyncFor == null) return;
            await unregisterSync(sl); // no-op unless a stop step failed
            await registerSyncFor(sl);
          },
          renewDevice: () => renewDeviceIdentity(sl),
          syncNow: () async {
            if (engine()) await sl<SyncEngine>().syncNow();
          },
          status: () =>
              engine() ? sl<SyncEngine>().status : const Stream.empty(),
          current: () =>
              engine() ? sl<SyncEngine>().current : SyncStatus.localOnly,
        ),
      ),
      dispose: (c) => c.close(),
    );
}
