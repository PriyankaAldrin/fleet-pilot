/// Build time settings. Pass with --dart-define, for example:
///   flutter run --dart-define=API_BASE_URL=https://fleet.example.com
class AppConfig {
  AppConfig._();

  /// Base URL of the ASP.NET API, without a trailing slash.
  /// Default points the Android emulator at the API running on the host machine.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5080',
  );

  /// Readings with a lower confidence get a warning in the app (the server flags them too).
  static const minOcrConfidence = 0.80;

  static const maxKmPerShift = 1000;
}
