import 'app/app_config.dart';
import 'app/bootstrap.dart';

Future<void> main() => bootstrap(AppConfig.fromEnvironment(Flavor.prod));
