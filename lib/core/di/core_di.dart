import 'package:get_it/get_it.dart';

import '../../app/app_config.dart';

final GetIt sl = GetIt.instance;

void registerCore(GetIt sl, AppConfig config) {
  sl.registerSingleton<AppConfig>(config);
}
