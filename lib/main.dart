import 'bootstrap.dart';
import 'config/app_environment.dart';

Future<void> main() => bootstrap(AppConfig.fromDefines().environment);
