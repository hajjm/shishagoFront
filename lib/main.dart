import 'bootstrap.dart';
import 'config/app_environment.dart';

void main() {
  bootstrap(AppConfig.fromDefines().environment);
}
