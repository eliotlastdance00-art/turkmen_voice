# Türkmen Ses API (v0.3)

FastAPI + SQLite. Ses maglumatlaryny Whisper fine-tuning üçin taýýar görnüşde
saklaýar we jemgyýetçilik reýtingi arkaly hilini barlaýar.

## Işletmek

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

python -m pytest tests -q                 # 22 kontrakt test
python scripts/seed_demo.py --takes 40    # demo gürleýjiler + ýazgylar
DATA_DIR=app/data ADMIN_TOKEN=secret uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- Admin panel: `/admin/` (token giriziň)
- Swagger: `/docs`
- Saglyk: `/api/v1/health`, `/api/v1/health/ready`

## Deploy

| Faýl | Kim üçin |
|---|---|
| `pyproject.toml` | **FastAPI Cloud** — gerekli paketler + `app.main:app` entrypoint |
| `.python-version` | Python 3.12 (Cloud we lokal) |
| `requirements.txt` / `requirements-dev.txt` | Docker, VPS we CI |
| `Dockerfile`, `docker-compose.yml` | Ätiýaçlyk: öz serwer (hemişelik disk bilen) |
| `../.github/workflows/deploy-fastapi-cloud.yml` | GitHub Actions arkaly deploy |

Ädimme-ädim görkezme: **`../docs/DEPLOYMENT.md`** (Application Directory =
`backend`, environment variables, barlag, troubleshooting).

## Gurluş

```text
pyproject.toml  FastAPI Cloud: paketler + entrypoint (app.main:app)
app/
  core/        config (env) + security (admin token, bearer)
  db/          SQLite shemasy (user_version migrasiýalary) + sözlem seed
  domain/      entity + repository protocol-lary (framework-syz)
  repositories SQLite implementasiýalar
  services/    audio, recording, rating, user, stats, dataset, text
  routers/     health, sentences, recordings, ratings, users, leaderboard, stats, admin
  schemas/     Pydantic API kontraktlary
  seed/        sentences_seed.json (6 paket / 215 sözlem)
  static/admin admin panel (bir faýl, token bilen)
  data/        RUNTIME: sqlite + audio (goýulmaýar; DATA_DIR bilen üýtgedilýär)
scripts/       smoke_test, seed_demo, build_whisper_dataset, whisper_finetune
tools/         sentences_seed generator
tests/         API kontrakt + deploy konfigurasiýa testleri
```

## Möhüm gurallary

| Zat | Nirede |
|---|---|
| Ses normalizasiýasy (16 kHz mono PCM16, sha256, sessizlik) | `services/audio_service.py` |
| Sözlem barlagy (türkmen elipbiýi) | `services/text_service.py` |
| Reýting + awtomatik tassyklama | `services/rating_service.py` |
| Ball / dereje / nyşan | `services/user_service.py`, `services/points.py` |
| Whisper eksporty + hil hasabat | `services/dataset_service.py` |

## Konfigurasiýa (environment)

`DATA_DIR` (boş bolsa `backend/app/data`), `ADMIN_TOKEN`, `CORS_ORIGINS`,
`PUBLIC_BASE_URL`, `ALLOWED_HOSTS`, `TARGET_SAMPLE_RATE`, `MIN/MAX_DURATION_MS`,
`MAX_AUDIO_BYTES`, `MIN_RMS_DBFS`, `AUTO_APPROVE_MIN_RATINGS`,
`AUTO_APPROVE_MIN_SCORE`, `RATINGS_DAILY_LIMIT`.
Doly sanaw: `.env.example`.

> Production üçin: PostgreSQL, S3/R2, JWT + rollar, rate-limit, backup.
> Häzirki SQLite + lokal disk MVP we beta synag üçin niýetlenen.
