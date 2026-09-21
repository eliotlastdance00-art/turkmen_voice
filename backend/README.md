# Türkmen Ses API

Backend indi domain/layered architecture bilen gurnalýar.

Arhitektura düşündirişi: `ARCHITECTURE.md`

## Run locally

```bash
cd turkmen_ses_backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Swagger: `http://localhost:8000/docs`

Admin panel: `http://localhost:8000/admin/`

Admin panelde ýazgylary filter etmek, audio diňlemek, kabul etmek/ret etmek we approved ýazgylary JSONL görnüşinde eksport etmek bolýar.

## Endpoints

- `GET /api/v1/health`
- `GET /api/v1/sentences`
- `POST /api/v1/recordings`
- `GET /api/v1/admin/recordings`
- `POST /api/v1/admin/recordings/{id}/review`
- `GET /api/v1/admin/export.jsonl`

Bu MVP-de audio local diskde, metadata SQLite-de saklanýar. Production-da S3-compatible storage, PostgreSQL, authentication, rate-limit we admin authorization goşulmaly.
