# Türkmen Ses — Türkmençe ses maglumat ýygnama ulgamy

Whisper (we beýleki STT modelleri) üçin **arassa, barlanan türkmençe ses + tekst**
datasetini ýygnamak ulgamy. Üç bölekden durýar:

```text
turkmen_voice/
  lib/        Flutter programma (Android/iOS) — offline first, 5 bölümli UI
  backend/    FastAPI + SQLite — API, admin panel, Whisper eksporty
  docs        DEPLOYMENT_GUIDE.md, MASLAHATLAR.md, Turkmen_Ses_MVP_Dokument.md
```

## Häzirki ýagdaý (v0.2 / API v0.3)

| Bölüm | Ýagdaý |
|---|---|
| Ses ýazgy (16 kHz mono WAV) | ✅ `AudioEncoder.wav` — Whisper formaty bilen birmeňzeş |
| Offline işlemek | ✅ drift/SQLite + nobat + awtomatik sinhronizasiýa |
| Sözlem paketleri | ✅ 6 paket / 215 sözlem (`backend/app/seed/sentences_seed.json`) |
| Serwer tarapy barlag | ✅ WAV barlagy, durasiýa ölçegi, sha256, sessizlik süzgüji |
| Jemgyýetçilik reýtingi | ✅ ýyldyz + «gabat gelýär/meýär» + 3+ baha → awtomatik tassyklama |
| Ball / dereje / nyşanlar | ✅ 6 dereje, 8 nyşan, günlük yhlas |
| Admin panel | ✅ filtr, diňlemek, tassyk/ret, hil hasabaty, eksportlar |
| Whisper eksporty | ✅ JSONL / Whisper JSONL / CSV / TSV / ZIP + report.json |
| Fine-tuning skriptleri | ✅ `build_whisper_dataset.py`, `whisper_finetune.py` |
| Deploy | ✅ Docker, Render, Fly.io, VPS (compose + Caddy), Azure |

## Çalt başlangyç

### 1. Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

python -m pytest tests -q            # 14 contract test
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

### 3. Serwere çykarmak

`DEPLOYMENT_GUIDE.md` — Fly.io / Render / VPS / Azure ädimme-ädim. Iň gysgasy:

```bash
cd backend
fly launch --copy-config --name turkmen-ses-api
fly volumes create turkmen_ses_data --size 3
fly secrets set ADMIN_TOKEN=$(openssl rand -hex 16)
fly deploy
```

## API gysgaça

| Metod | Ýol | Bellik |
|---|---|---|
| GET | `/api/v1/health`, `/health/ready` | saglyk barlagy |
| GET | `/api/v1/sentences`, `/sentences/packages`, `/sentences/random` | sözlemler |
| POST | `/api/v1/recordings` | multipart: `recording_id, sentence_id, text, consent_type, duration_ms, audio_file` (+ islege görä `category, package_id, sample_rate, channels, bit_depth`) |
| GET | `/api/v1/recordings/{id}`, `/{id}/audio`, `/{id}/ratings` | ýazgy, ses, baha |
| DELETE | `/api/v1/recordings/{id}` | öz ýazgyňy pozmak (razylygy yzyna almak) |
| POST | `/api/v1/users/register` | anonim hasap (`device_id` → `tk_<user_id>` token) |
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

## Goşmaça dokumentler

- `DEPLOYMENT_GUIDE.md` — serwere çykarmak, backup, barlag sanawy
- `MASLAHATLAR.md` — indiki ädimler we gowulandyrmak boýunça maslahatlar
- `Turkmen_Ses_MVP_Dokument.md` — başdaky MVP kesgitlemesi
- `backend/ARCHITECTURE.md` — backend arhitekturasy (gatlaklar)

## Android rugsatlar

`android/app/src/main/AndroidManifest.xml`:

- `android.permission.INTERNET` — ýazgylary serwere ibermek
- `android.permission.RECORD_AUDIO` — mikrofon
- `@xml/network_security_config` — beta wagtynda lokal HTTP serwere baglanmak üçin
  (production-da HTTPS-e geçiriň)
