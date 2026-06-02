class ApiConfig {
  /// Android emulator: 10.0.2.2 | iOS simulator: localhost | Windows desktop: localhost
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  static String get apiBase => '$baseUrl/api';
  static String get hubUrl => '$baseUrl/hubs/telemetry';
}
