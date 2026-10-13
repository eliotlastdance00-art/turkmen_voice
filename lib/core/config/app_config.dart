/// Global, build-time configuration.
///
/// `API_BASE_URL` is injected with `--dart-define` (the GitHub Actions
/// workflow fills it from the repository variable of the same name).
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const String appName = 'Türkmen Ses';
  static const String appVersion = '0.3.0';

  /// Serwer `audio_url` üçin otnositel ýol gaýtaryp bilýär
  /// (`/api/v1/recordings/<id>/audio`). Şeýle halda ony API-niň öý eýesine
  /// birleşdirýäris — ýoksa pleýer "Invalid URL" berýär.
  static String resolveUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return value;
    }
    final base = Uri.tryParse(apiBaseUrl);
    if (base == null) {
      return value;
    }
    // base: https://host:port/api/v1 → öý eýesi: https://host:port
    return base.replace(path: '', query: '', fragment: '').resolve(value).toString();
  }

  /// Whisper data contract — must stay in sync with the backend settings.
  static const int targetSampleRate = 16000;
  static const int maxRecordingMs = 15000;
  static const int minRecordingMs = 500;
  static const int warningMs = 12000;

  static const int dailyGoalSeconds = 300;

  static String get shortServerLabel {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) {
      return apiBaseUrl;
    }
    return uri.host;
  }
}
