enum AppEnvironment { dev, staging, prod }

extension AppEnvironmentValue on AppEnvironment {
  String get name => switch (this) {
    AppEnvironment.dev => 'dev',
    AppEnvironment.staging => 'staging',
    AppEnvironment.prod => 'prod',
  };

  String get displayName => switch (this) {
    AppEnvironment.dev => 'Chichago Dev',
    AppEnvironment.staging => 'Chichago Staging',
    AppEnvironment.prod => 'Chichago',
  };

  String get defaultApiUrl => switch (this) {
    AppEnvironment.dev => 'http://127.0.0.1:8001',
    AppEnvironment.staging => 'https://api-staging.chichago.example',
    AppEnvironment.prod => 'https://api.chichago.example',
  };
}

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  static const development = AppConfig(
    environment: AppEnvironment.dev,
    apiBaseUrl: 'http://127.0.0.1:8001',
  );

  factory AppConfig.forEnvironment(AppEnvironment environment) {
    const apiOverride = String.fromEnvironment('CHICHAGO_API_URL');
    return AppConfig(
      environment: environment,
      apiBaseUrl: apiOverride.isEmpty
          ? environment.defaultApiUrl
          : apiOverride.replaceFirst(RegExp(r'/$'), ''),
    );
  }

  factory AppConfig.fromDefines() {
    const value = String.fromEnvironment('CHICHAGO_ENV', defaultValue: 'dev');
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
    'CHICHAGO_ENV',
    'Expected dev, staging, or prod',
  ),
};
