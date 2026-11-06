import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../core/auth/auth_gateway.dart';
import '../core/auth/supabase_auth_gateway.dart';
import '../core/di/account_di.dart';
import '../core/di/core_di.dart';
import '../core/di/sync_di.dart';
import '../features/account/presentation/session_cubit.dart';
import '../core/sync/supabase_sync_transport.dart';
import '../core/sync/sync_status.dart';
import 'app_config.dart';
import 'app_di.dart';
import 'weave_app.dart';

/// Main app entrypoint wiring. Secondary window entrypoints (the mini bar)
/// must not call this: only the main engine runs sync.
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabase = await _initSupabase(config);
  tz.initializeTimeZones();
  await registerCore(sl, config);
  await _registerSync(supabase);
  registerApp(sl);
  runApp(const WeaveApp());
}

/// The Supabase client, or null when it cannot be set up; the app then runs
/// local-only.
Future<SupabaseClient?> _initSupabase(AppConfig config) async {
  if (config.supabaseUrl.isEmpty || config.supabaseAnonKey.isEmpty) {
    return null;
  }
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    return Supabase.instance.client;
  } on Object catch (e) {
    developer.log('Supabase init failed: ${e.runtimeType}', name: 'Boot');
    return null;
  }
}

/// Registers the session and sync. Without Supabase the app is local-only:
/// a plain `SyncStatusCubit` (`localOnly`) and an auth gateway that always
/// fails. Otherwise sync is registered with the Supabase transport and the
/// signed-in signal comes from the [SessionCubit], which starts sync itself
/// ([SessionCubit.restore] for a restored session, or after sign-in).
Future<void> _registerSync(SupabaseClient? client) async {
  if (client == null) {
    registerAccount(sl, auth: const UnavailableAuthGateway());
    sl.registerLazySingleton<SyncStatusCubit>(
      SyncStatusCubit.new,
      dispose: (c) => c.close(),
    );
    return;
  }
  Future<void> syncFor(GetIt sl) {
    final session = sl<SessionCubit>();
    return registerSync(
      sl,
      transport: SupabaseSyncTransport(client, deviceId: sl<DeviceId>().value),
      signedIn: session.signedIn,
      signedInNow: session.signedInNow,
    );
  }

  registerAccount(
    sl,
    auth: SupabaseAuthGateway(client),
    registerSyncFor: syncFor,
  );
  await syncFor(sl);
  // Local only (no network wait): starts sync when the session is kept.
  unawaited(sl<SessionCubit>().restore());
}
