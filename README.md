# Türkmen Ses — türkmençe ses maglumat ýygnama ulgamy

Whisper (we beýleki STT modelleri) üçin **arassa, barlanan türkmençe ses + tekst**
datasetini ýygnamak ulgamy. Iki bölekden durýar:

```text
turkmen_voice/
  lib/        Flutter programma (Android/iOS) — offline first, 5 bölümli UI
  backend/    FastAPI + SQLite — API, admin panel, Whisper eksporty (FastAPI Cloud)
  docs/       DEPLOYMENT.md, ARCHITECTURE.md, MASLAHATLAR.md, MVP.md
```

## Häzirki ýagdaý (v0.4)

| Bölüm | Ýagdaý |
|---|---|
| Ses ýazgy (16 kHz mono WAV) | ✅ `AudioEncoder.wav` — Whisper formaty bilen birmeňzeş |
| Offline işlemek | ✅ drift/SQLite + nobat + awtomatik sinhronizasiýa |
| Sözlem paketleri | ✅ 6 paket / 215 sözlem + **programmanyň içindäki nusga** (`assets/sentences_seed.json`) — internet bolmasa-da tekst bar |
| Öz sözlemim | ✅ ulanyjy öz tekstini ýazyp ýazga alýar (elipbiý + uzynlyk barlagy) |
| Bir sözlem — bir ýazgy | ✅ ýazylan sözlem/tekst gaýtadan soralmaýar (programma + serwer 409) |
| Hasap / token | ✅ hasap serwer bazasynda (`users.token`), 401-de awtomatik täzeden döretmek |
| Durnukly birikme | ✅ retry + saglyk barlagy + serwer adresini sazlamalar arkaly üýtgetmek |
| Serwer tarapy barlag | ✅ WAV barlagy, durasiýa ölçegi, sha256, sessizlik süzgüji |
| Jemgyýetçilik reýtingi | ✅ ýyldyz + «gabat gelýär/meýär» + 3+ baha → awtomatik tassyklama |
| Ball / dereje / nyşanlar | ✅ 6 dereje, 8 nyşan, günlük yhlas |
| Admin panel | ✅ filtr, diňlemek, tassyk/ret, hil hasabaty, eksportlar |
| Whisper eksporty | ✅ JSONL / Whisper JSONL / CSV / TSV / ZIP + report.json |
| Fine-tuning skriptleri | ✅ `build_whisper_dataset.py`, `whisper_finetune.py` |
| Deploy | ✅ **FastAPI Cloud** (`docs/DEPLOYMENT.md`) + Docker (ätiýaçlyk) |
| Testler | ✅ 38 backend testi (kontrakt + tekst hili + seed sinhronlygy) |
| Çalt açylyş | ✅ brendlenen splash, fonda bootstrap (baza/sözlemler), tor soraglary yza sürülýär |

## Çalt başlangyç

### 1. Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

python -m pytest tests -q                # 38 test (kontrakt + tekst hili)
python scripts/seed_demo.py --takes 40   # demo maglumat (reýting tablisasy üçin)

DATA_DIR=app/data ADMIN_TOKEN=secret uvicorn app.main:app --host 0.0.0.0 --port 8000
python scripts/smoke_test.py --base-url http://127.0.0.1:8000/api/v1 --admin-token secret
```

- Admin panel: <http://127.0.0.1:8000/admin/>
- Swagger: <http://127.0.0.1:8000/docs>

### 2. Programma (Flutter)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# emulyator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# hakyky telefon (LAN)
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1
```

APK: **Actions → Build Android APK** (repo variable `API_BASE_URL` goýuň) ýa-da
`flutter build apk --release --dart-define=API_BASE_URL=...`.

### 3. Serwere çykarmak (FastAPI Cloud)

```bash
# 1) dashboard → App → Settings → Application Directory = backend
# 2) environment: ADMIN_TOKEN (secret), PUBLIC_BASE_URL, DATA_DIR, CORS_ORIGINS
# 3) main-a push (GitHub integrasiýasy) ýa-da:
cd backend && fastapi deploy
```

Doly ädimme-ädim, barlag we troubleshooting: **`docs/DEPLOYMENT.md`**.

> ⚠️ FastAPI Cloud-yň diski wagtlaýyn (SQLite + audio redeployda gaýtadan
> başlanýar) — beta üçin ýeterlik, hakyky korpus üçin Postgres + S3 meýilleşdiriň
> (`docs/MASLAHATLAR.md`, 3-nji bölüm).

## API gysgaça

| Metod | Ýol | Bellik |
|---|---|---|
| GET | `/api/v1/health`, `/health/ready` | saglyk barlagy (ready: disk ýazylýarmy) |
| GET | `/api/v1/sentences`, `/sentences/packages`, `/sentences/random` | sözlemler |
| POST | `/api/v1/recordings` | multipart: `recording_id, sentence_id, text, consent_type, duration_ms, audio_file` (+ islege görä `category, package_id, sample_rate, channels, bit_depth`). **409** — bu sözlem eýýäm ýazylan bolsa |
| POST | `/api/v1/users/register` | anonim hasap; jogap: `{user, token, created}` — hasap we token **bazada saklanýar** |
| GET | `/api/v1/recordings/{id}`, `/{id}/audio`, `/{id}/ratings` | ýazgy, ses, baha |
| DELETE | `/api/v1/recordings/{id}` | öz ýazgyňy pozmak (razylygy yzyna almak) |
| POST | `/api/v1/users/register` | anonim hasap (`device_id` → bazada saklanýan `tk_…` token) |
| GET | `/api/v1/users/me`, `/leaderboard`, `/stats/overview`, `/stats/me` | profil we reýting |
| GET | `/api/v1/ratings/queue` | başgalaryň barlamaly ýazgylary |
| POST | `/api/v1/recordings/{id}/ratings`, `/{id}/report` | baha bermek / şikaýat |
| GET | `/api/v1/admin/*` | `X-Admin-Token` gerek (statistika, tassyk, eksport) |

## Maglumat ölçegi (Whisper taýýarlygy)

- Format: **16 kHz · mono · 16 bit PCM WAV**, 0.5–15 sekunt
- Her ýazgy üçin: `duration_ms` (serwer ölçeýär), `sha256`, `community_score`,
  `rating_count`, `verified`, `speaker_id`, `category`, `package_id`
- Ýazgyda header bolmasa hem (köne APK) serwer dogry WAV-a öwürýär
- Diňe **tassiklanan** ýazgylar eksport edilýär (`approved`)

```bash
curl -H "X-Admin-Token: $TOKEN" $API/admin/export.zip -o bundle.zip   # audio + metadata
python backend/scripts/build_whisper_dataset.py --input dataset --output whisper_dataset
python backend/scripts/whisper_finetune.py --dataset whisper_dataset --model openai/whisper-small
```

## Dokumentler (`docs/`)

| Faýl | Maksady |
|---|---|
| `DEPLOYMENT.md` | FastAPI Cloud-a çykarmak, barlag, troubleshooting, VPS ätiýaçlygy |
| `ARCHITECTURE.md` | Backend gatlaklary we esasy kararlar |
| `MASLAHATLAR.md` | Indiki ädimler (hil, infrastruktura, model) |
| `MVP.md` | Başdaky MVP kesgitlemesi (taryhy) |

## Ikon we brend

| Faýl | Maksady |
|---|---|
| `assets/branding/app_icon.png` | **Çeşme** brend ikonasy (1600×1600, mikrofonly teal kwadrat) |
| `android/app/src/main/res/mipmap-*/` | Her dykyzlyk üçin `ic_launcher`, `ic_launcher_round`, `ic_launcher_foreground` |
| `android/.../mipmap-anydpi-v26/` | Adaptive icon (Android 8+) — fon + öňki gatlak + monohrom görnüş |
| `assets/branding/app_icon_512.png` | Play Store / paýlaşmak üçin 512×512 |
| `tools/build_app_icons.py` | Ählisini çeşme suratdan öndürýär (Pillow gerek) |

Ikonany çalyşmak: `assets/branding/app_icon.png`-i täze kwadrat surat bilen
çalyşyň we

```bash
python tools/build_app_icons.py     # mipmap-lary we 512 nusgasyny täzeleýär
cd backend && python -m pytest tests/test_branding_assets.py -q   # barlag
```

Testler ikonlaryň ölçegini, adaptive icon beýanyny we manifestiň
`android:roundIcon` baglanyşygyny barlaýar — Flutter-iň öz ikonasy APK-da
galmaýar.

## Android rugsatlar

`android/app/src/main/AndroidManifest.xml`:

- `android.permission.INTERNET` — ýazgylary serwere ibermek
- `android.permission.RECORD_AUDIO` — mikrofon
- `@xml/network_security_config` — beta wagtynda lokal HTTP serwere baglanmak üçin
  (production-da HTTPS-e geçiriň)
