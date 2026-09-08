import 'package:chichago/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('environment names map to the expected flavor', () {
    expect(parseEnvironment('dev'), AppEnvironment.dev);
    expect(parseEnvironment('development'), AppEnvironment.dev);
    expect(parseEnvironment('staging'), AppEnvironment.staging);
    expect(parseEnvironment('prod'), AppEnvironment.prod);
    expect(parseEnvironment('production'), AppEnvironment.prod);
  });

  test('unknown environment names are rejected', () {
    expect(() => parseEnvironment('qa'), throwsArgumentError);
  });

  test('each flavor has an explicit API default', () {
    for (final environment in AppEnvironment.values) {
      final config = AppConfig.forEnvironment(environment);
      expect(config.apiBaseUrl, isNotEmpty);
      expect(config.environment, environment);
    }
  });
}
