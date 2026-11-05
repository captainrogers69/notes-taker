import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get_it/get_it.dart';

import '../database/weave_database.dart';
import '../sync/change_merger.dart';
import '../sync/change_writer.dart';
import '../sync/device_names.dart';
import '../sync/hlc_clock.dart';
import '../sync/passthrough_payload_cipher.dart';
import '../sync/payload_cipher.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_status.dart';
import '../sync/sync_transport.dart';
import 'core_di.dart';

/// Registers sync. Call from the main app engine only (bootstrap), never
/// from a secondary window entrypoint such as `entrypoints/mini_bar_main.dart`:
/// only one engine may run `SyncEngine`.
///
/// Needs `registerCore` first. [signedIn] / [signedInNow] come from the
/// session (Task 13); without them the status stays `localOnly`.
/// [deviceName], [connectivity] and [checkOnline] default to the platform
/// plugins; tests pass their own.
///
/// The device id is captured by the engine, [DeviceNames] and (through the
/// clock and writer) the merger. To change it (sign-out, Task 13): call
/// [unregisterSync], wipe, re-register `DeviceId`, `HlcClock` and
/// `ChangeWriter`, then call [registerSync] again. The [SyncStatusCubit]
/// survives and is re-attached to the new engine.
Future<void> registerSync(
  GetIt sl, {
  required SyncTransport transport,
  PayloadCipher cipher = const PassthroughPayloadCipher(),
  String? deviceName,
  Stream<bool>? connectivity,
  Future<bool> Function()? checkOnline,
  Stream<bool>? signedIn,
  bool signedInNow = false,
}) async {
  final db = sl<WeaveDatabase>();
  final deviceId = sl<DeviceId>().value;
  final selfName = deviceName ?? await localDeviceName();
  sl.registerSingleton<SyncTransport>(transport);
  sl.registerSingleton<PayloadCipher>(cipher);
  sl.registerSingleton<DeviceNames>(
    DeviceNames(db, selfId: deviceId, selfName: selfName),
  );
  sl.registerLazySingleton<ChangeMerger>(
    () => ChangeMerger(
      db,
      sl<HlcClock>(),
      sl<ChangeWriter>(),
      sl<DeviceNames>().nameOf,
    ),
  );
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      db: db,
      transport: sl<SyncTransport>(),
      cipher: sl<PayloadCipher>(),
      merger: sl<ChangeMerger>(),
      deviceId: deviceId,
      connectivity: connectivity ?? connectivityOnline(),
      checkOnline: checkOnline ?? isOnlineNow,
    ),
  );
  if (sl.isRegistered<SyncStatusCubit>()) {
    // Never created yet: its factory will read the new engine when needed.
    if (!sl.checkLazySingletonInstanceExists<SyncStatusCubit>()) return;
    final engine = sl<SyncEngine>();
    sl<SyncStatusCubit>().attach(engine.status, initial: engine.current);
    return;
  }
  sl.registerLazySingleton<SyncStatusCubit>(() {
    final engine = sl<SyncEngine>();
    return SyncStatusCubit(
      status: engine.status,
      initial: engine.current,
      signedIn: signedIn,
      signedInNow: signedInNow,
    );
  }, dispose: (c) => c.close());
}

/// Disposes the engine and unregisters everything [registerSync] made except
/// the [SyncStatusCubit], which is detached and re-attached by the next
/// [registerSync].
Future<void> unregisterSync(GetIt sl) async {
  if (sl.isRegistered<SyncStatusCubit>() &&
      sl.checkLazySingletonInstanceExists<SyncStatusCubit>()) {
    await sl<SyncStatusCubit>().detach();
  }
  if (sl.isRegistered<SyncEngine>()) {
    await sl.unregister<SyncEngine>(disposingFunction: (e) => e.dispose());
  }
  await _drop<ChangeMerger>(sl);
  await _drop<DeviceNames>(sl);
  await _drop<PayloadCipher>(sl);
  await _drop<SyncTransport>(sl);
}

Future<void> _drop<T extends Object>(GetIt sl) async {
  if (sl.isRegistered<T>()) await sl.unregister<T>();
}

/// True while any network interface is up (not proof the server is
/// reachable; the transport's `SyncOfflineException` covers that).
Stream<bool> connectivityOnline() => Connectivity().onConnectivityChanged
    .map((r) => r.any((c) => c != ConnectivityResult.none))
    .distinct();

Future<bool> isOnlineNow() async {
  final r = await Connectivity().checkConnectivity();
  return r.any((c) => c != ConnectivityResult.none);
}

/// This device's user-visible name, for conflict labels. Local only.
Future<String> localDeviceName() async {
  const fallback = 'This device';
  try {
    final info = DeviceInfoPlugin();
    final String name;
    if (Platform.isIOS) {
      name = (await info.iosInfo).name;
    } else if (Platform.isAndroid) {
      final a = await info.androidInfo;
      name = a.name.isNotEmpty ? a.name : a.model;
    } else if (Platform.isMacOS) {
      name = (await info.macOsInfo).computerName;
    } else if (Platform.isWindows) {
      name = (await info.windowsInfo).computerName;
    } else if (Platform.isLinux) {
      name = (await info.linuxInfo).name;
    } else {
      return fallback;
    }
    return name.isEmpty ? fallback : name;
  } on Object {
    return fallback;
  }
}
