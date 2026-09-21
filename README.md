# Türkmen Ses — Flutter MVP

Offline-first Türkmençe ses maglumat ýygnama programmasynyň advanced başlangyç gurluşy.

## Arhitektura

```text
lib/
  app/                 App root
  core/
    router/            GoRouter navigasiýasy
    storage/           Drift/SQLite database
    theme/             Material 3 tema
    network/           API we sync üçin ýer
  features/
    home/              Ýazgy başlamak ekrany
    recordings/        Ýerli ýazgylaryň sanawy
    consent/           Razylyk akymy
    settings/          Gizlinlik we sazlamalar
```

## Gurnamak

Flutter SDK gerek. Soňra:

```bash
cd turkmen_ses
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

API adresleri:

- Android emulator: `http://10.0.2.2:8000/api/v1`
- iOS simulator: `http://127.0.0.1:8000/api/v1`
- Real device: `http://YOUR_COMPUTER_LAN_IP:8000/api/v1`

Backend bilen bile işletmek üçin:

```bash
cd ../turkmen_ses_backend
uvicorn app.main:app --host 0.0.0.0 --port 8000

cd ../turkmen_ses
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`app_database.g.dart` Drift tarapyndan awtomatiki döredilýär. Ol source control-a goşulyp bilner, ýöne generated faýl bolany üçin täzeden generasiýa etmek maslahat berilýär.

## Ilkinji implementation ýagdaýy

Taýýar:

- Material 3 UI
- GoRouter navigation
- Riverpod dependency injection
- Drift SQLite schema
- Offline recording metadata modeli
- Recording status lifecycle
- Consent screen
- Home / Recordings / Settings screens
- Dataset üçin gerek bolan text + audio metadata gurluşy

Häzirki implementation:

1. `record` package bilen hakyky mikrofon ýazgysy.
2. `path_provider` arkaly audio bukjasy.
3. WAV 16 kHz mono recording sazlamasy.
4. `just_audio` bilen preview.
5. Drift/SQLite lokal storage.
6. Dio bilen multipart upload.
7. Connectivity-based sync queue.
8. FastAPI backend bilen birleşme.
9. Settings ekranlarynda manual sync düwmesi.

## Mikrofon rugsady

`record` plugin üçin platform project-lary döredilende:

Android `android/app/src/main/AndroidManifest.xml` içine:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

iOS `ios/Runner/Info.plist` içine:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Türkmençe ses ýazgylaryny döretmek üçin mikrofon ulanylýar.</string>
```
