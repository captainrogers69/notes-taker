import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../core/di/core_di.dart';
import '../core/di/sync_di.dart';
import '../core/sync/supabase_sync_transport.dart';
import '../core/sync/sync_status.dart';
import 'app_config.dart';
import 'weave_app.dart';

/// Main app entrypoint wiring. Secondary window entrypoints (the mini bar)
/// must not call this: only the main engine runs sync.
Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabase = await _initSupabase(config);
  tz.initializeTimeZones();
  await registerCore(sl, config);
  await _registerSync(supabase);
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

/// Registers sync with the Supabase transport and starts it when a session
/// was restored. Signed out (or no Supabase) the app stays local-only and
/// the status cubit shows `localOnly`; Task 13 calls `startSync` after
/// sign-in.
Future<void> _registerSync(SupabaseClient? client) async {
  if (client == null) {
    sl.registerLazySingleton<SyncStatusCubit>(
      SyncStatusCubit.new,
      dispose: (c) => c.close(),
    );
    return;
  }
  final auth = client.auth;
  final signedInNow = auth.currentUser != null;
  await registerSync(
    sl,
    transport: SupabaseSyncTransport(client, deviceId: sl<DeviceId>().value),
    // Read the current user per event: the auth stream replays old events.
    signedIn: auth.onAuthStateChange
        .map((_) => auth.currentUser != null)
        .distinct(),
    signedInNow: signedInNow,
  );
  if (signedInNow) startSync(sl);
}
