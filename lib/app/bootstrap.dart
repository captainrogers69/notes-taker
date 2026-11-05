import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import '../core/di/core_di.dart';
import 'app_config.dart';
import 'weave_app.dart';

Future<void> bootstrap(AppConfig config) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );
  tz.initializeTimeZones();
  await registerCore(sl, config);
  runApp(const WeaveApp());
}
