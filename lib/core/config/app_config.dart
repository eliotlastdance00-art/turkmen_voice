import 'package:flutter/foundation.dart' show kReleaseMode;

/// Global, build-time configuration.
///
/// `API_BASE_URL` is injected with `--dart-define` (the GitHub Actions
/// workflow fills it from the repository variable of the same name).
class AppConfig {
  const AppConfig._();

  /// `--dart-define=API_BASE_URL=...` bilen berilýän salgy.
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Ýerli işlediş (emulyator/desktop) üçin serwer.
  static const String emulatorApiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  /// Çykarylan (deployed) serwer — beta we täjirçilik üçin.
  static const String cloudApiBaseUrl =
      'https://turkmen-voice-09885e66.fastapicloud.dev/api/v1';

  /// Işleýän API salgysy.
  ///
  /// `--dart-define=API_BASE_URL=...` berlen bolsa — şol ulanylýar. Berilmedik
  /// ýa-da **boş** bolsa: release gurluşyklary çykarylan serwere, debug/profile
  /// emulyatora düşýär. Şeýlelikde variable ýalňyş goýulyp gurlan release APK
  /// hem boş salgy bilen işlemezden galmaýar.
  static String get apiBaseUrl {
    final String defined = _envApiBaseUrl.trim();
    if (defined.isNotEmpty) {
      return defined;
    }
    return kReleaseMode ? cloudApiBaseUrl : emulatorApiBaseUrl;
  }

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
