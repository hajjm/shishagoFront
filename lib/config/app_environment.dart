enum AppEnvironment { dev, staging, prod }

extension AppEnvironmentValue on AppEnvironment {
  String get name => switch (this) {
    AppEnvironment.dev => 'dev',
    AppEnvironment.staging => 'staging',
    AppEnvironment.prod => 'prod',
  };

  String get displayName => switch (this) {
    AppEnvironment.dev => 'Shisha Go Dev',
    AppEnvironment.staging => 'Shisha Go Staging',
    AppEnvironment.prod => 'Shisha Go',
  };

  String get defaultApiUrl => switch (this) {
    AppEnvironment.dev => 'http://127.0.0.1:8001',
    AppEnvironment.staging => 'https://api-staging.shishago.example',
    AppEnvironment.prod => 'https://api.shishago.example',
  };
}

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  static const development = AppConfig(
    environment: AppEnvironment.dev,
    apiBaseUrl: 'http://127.0.0.1:8001',
  );

  factory AppConfig.forEnvironment(AppEnvironment environment) {
    const apiOverride = String.fromEnvironment(
      'SHISHAGO_API_URL',
      defaultValue: String.fromEnvironment('CHICHAGO_API_URL'),
    );
    return AppConfig(
      environment: environment,
      apiBaseUrl: apiOverride.isEmpty
          ? environment.defaultApiUrl
          : apiOverride.replaceFirst(RegExp(r'/$'), ''),
    );
  }

  factory AppConfig.fromDefines() {
    const value = String.fromEnvironment(
      'SHISHAGO_ENV',
      defaultValue: String.fromEnvironment('CHICHAGO_ENV', defaultValue: 'dev'),
    );
    return AppConfig.forEnvironment(parseEnvironment(value));
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
}

AppEnvironment parseEnvironment(String value) => switch (value.toLowerCase()) {
  'dev' || 'development' => AppEnvironment.dev,
  'staging' => AppEnvironment.staging,
  'prod' || 'production' => AppEnvironment.prod,
  _ => throw ArgumentError.value(
    value,
    'SHISHAGO_ENV',
    'Expected dev, staging, or prod',
  ),
};
