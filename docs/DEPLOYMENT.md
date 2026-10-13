# Türkmen Ses — backend-i FastAPI Cloud-a çykarmak

Backend (**FastAPI + SQLite + admin panel**) FastAPI Cloud-da işleýär.
Deploy: **GitHub → FastAPI Cloud**, konfigurasiýa: dashboard-daky *Environment
variables* + repodaky `backend/pyproject.toml`.

| Näme | Nirede |
|---|---|
| Cloud konfigurasiýasy | `backend/pyproject.toml` (`[tool.fastapi] entrypoint = "app.main:app"`) |
| Python wersiýasy | `backend/.python-version` (3.12) |
| Gerekli paketler | Cloud: `pyproject.toml` · Docker/CI: `requirements.txt` |
| Awtomatik deploy | `.github/workflows/deploy-fastapi-cloud.yml` |
| Programmanyň URL-i | `https://<app-slug>.fastapicloud.dev` (dashboard → App → Overview) |

> ⚠️ **Maglumat hemişelik saklanmaýar.** FastAPI Cloud-da konteýneriň diski
> wagtlaýyn: SQLite bazasy we `audio/` faýllary täzeden deploy bolanda (ýa-da
> nusga täzelenende) gaýtadan başlanýar. Şonuň üçin häzirki ýagdaý
> **beta/ synag** üçin amatly, hakyky korpus üçin däl — 4-nji bölüme serediň.

---

## 1. Bir gezeklik sazlamalar (dashboard)

`https://dashboard.fastapicloud.com/eliotlastdance00-434301b7/apps/turkmen-voice-09885e66`

1. **App → Settings → Application Directory** — `backend` ýazyň we *Update* basyň.
   (FastAPI programmasy reponyň kökünde däl, `backend/` bukjasynda.)
2. **App → Settings → Environment (Secrets)** — aşakdaky üýtgeýjileri goýuň:

| Üýtgeýji | Möçberi | Düşündiriş |
|---|---|---|
| `ADMIN_TOKEN` | `openssl rand -hex 16` netijesi (**secret**) | Admin panel/API tokini. Boş goýsaňyz admin panel her kime açyk bolýar! |
| `PUBLIC_BASE_URL` | `https://turkmen-voice-09885e66.fastapicloud.dev` | Eksportdaky audio URL-leri üçin. Öz domeniňiz bar bolsa, ony ýazyň. |
| `DATA_DIR` | `/tmp/turkmen-ses-data` | SQLite + ses faýllary (wagtlaýyn disk; ýazmaga elýeterli ýer). |
| `CORS_ORIGINS` | `*` (beta) / öz domeniňiz | Islegler gelýän origin-ler. |
| `AUTO_APPROVE_MIN_RATINGS` | `3` | Şonça baha ýygnan ýazgy awtomatik tassyk edilýär. |
| `AUTO_APPROVE_MIN_SCORE` | `4.0` | Awtomatik tassyklama üçin orta baha. |
| `ALLOWED_HOSTS` | (boş) | Diňe goşmaça domen ulanýan bolsaňyz dolduryň. |

CLI bilen hem goýup bolýar:

```bash
pip install "fastapi[standard]"

fastapi cloud env set DATA_DIR "/tmp/turkmen-ses-data"
fastapi cloud env set PUBLIC_BASE_URL "https://turkmen-voice-09885e66.fastapicloud.dev"
fastapi cloud env set --secret ADMIN_TOKEN "$(openssl rand -hex 16)"   # tokini ýazdyryp saklaň!
```

3. Üýtgeýji üýtgedeniňizden soň dashboard **Save and redeploy** teklip edýär — rebuild-siz
   täze ayarlar bilen goýberilýär.

---

## 2. Deploy etmegiň üç ýoly

### A. GitHub integrasiýasy (iň aňsat, maslahat berilýär)
Dashboard-da **App → Settings → GitHub** bölüminden `eliotlastdance00-art/turkmen_voice`
repozitorisini birikdiriň (branch: `main`). Şondan soň **`main`-a her push awtomatik
deploy** bolýar — CI ýazmak gerek däl.

```bash
git checkout main && git pull
git merge --no-ff arena/451dfb03-turkmen-voice   # üýtgeşmeleri goşuň
git push origin main
# → dashboard → Deployments bölümünde täze deployment peýda bolýar
```

### B. GitHub Actions (deploy token bilen)
Repoda `.github/workflows/deploy-fastapi-cloud.yml` taýýar. Bir gezek:

```bash
pip install "fastapi[standard]"
fastapi login
fastapi cloud setup-ci --secrets-only --app-id <APP_ID>
```

`setup-ci` GitHub-a iki secret goýýar: `FASTAPI_CLOUD_TOKEN` we `FASTAPI_CLOUD_APP_ID`
(Deploy Token-i dashboard → **App → Deploy Tokens → Create Token** bölüminden hem
döredip bilersiňiz; App ID — **App → Settings**).

Şondan soň workflow: testler → `fastapi deploy` → Deployments sahypasynda görünýär.
Token goýulmadyk bolsa workflow diňe testleri işledýär (ýalňyşlyk bermeýär).

### C. Lokal kompýuterden

```bash
cd backend
pip install "fastapi[standard]"
fastapi dev            # lokal barlag (entrypoint pyproject.toml-dan alynýar)
fastapi deploy         # göni buluda goýbermek
```

---

## 3. Deploy-dan soň barlag

```bash
BASE=https://turkmen-voice-09885e66.fastapicloud.dev

curl -s $BASE/api/v1/health          # {"ok": true, ...}
curl -s $BASE/api/v1/health/ready    # {"ok": true, "writable": true, ...}
```

| Salgy | Näme görkezýär |
|---|---|
| `$BASE/docs` | Swagger (API-ni şol ýerde synlap bolýar) |
| `$BASE/admin/` | Admin panel (`ADMIN_TOKEN` giriziň) |
| `$BASE/api/v1/sentences/packages` | Sözlem paketleri (seed göçürildi = DB işleýär) |

Doly funksional barlag (20 barlag: ýazgy ýükleme, reýting, eksport):

```bash
python scripts/smoke_test.py --base-url $BASE/api/v1 --admin-token $ADMIN_TOKEN
```

APK üçin: GitHub → **Settings → Secrets and variables → Actions → Variables** →
`API_BASE_URL = https://turkmen-voice-09885e66.fastapicloud.dev/api/v1`.
Soňra *Actions → Build Android APK*.

### 3.1. APK-y täzeden gurmak (deploy-dan soň hökman)

Backend adresi APK-nyň **içine gurulýar** (`--dart-define=API_BASE_URL=...`,
`lib/core/config/app_config.dart`). Şonuň üçin deploy-dan soň APK täzeden
gurulmaly — köne APK-da köne salgy galýar.

| Ädim | Nirede | Näme etmeli |
|---|---|---|
| 1 | Backend saglygy | `curl -s $BASE/api/v1/health` → `{"ok": true, ...}` |
| 2 | GitHub → Settings → Secrets and variables → Actions → **Variables** | `API_BASE_URL` = `https://turkmen-voice-09885e66.fastapicloud.dev/api/v1` (`/api/v1` bilen, ahyrky `/` bolmasa hem bolýar) |
| 3 | GitHub → **Actions → Build Android APK → Run workflow** | branch: `main` |
| 4 | Workflow logy → «APK şu salga birikdirilýär: …» | salgynyň dogrudygyny barlaň (ýalňyş bolsa `::warning` çykýar) |
| 5 | Actions → şol run → **Artifacts** | `turkmen-ses-debug-apk` (debug) ýa-da *Build Android Release APK* (`turkmen-ses-release-apk`) |
| 6 | Telefonda synag | Admin panelde ýazgy peýda bolmaly: `$BASE/admin/` |

Bellikler:

- `API_BASE_URL` goýulmadyk bolsa debug APK emulyator salgysyna
  (`http://10.0.2.2:8000/api/v1`) birikdirilýär we logda `::warning` görünýär;
  **release** APK bolsa ýalňyşlyk bilen saklanýar (boş salgy bilen ýaýratmazlyk üçin).
- **Ätiýaçlyk (programmada)**: `lib/core/config/app_config.dart` — `--dart-define`
  berilmedik/boş bolsa release gurluşygy awtomatik `AppConfig.cloudApiBaseUrl`
  (şu serwer) salgysyna düşýär, debug bolsa emulyatora. Şeýlelikde ýalňyş gurlan
  APK-da telefon «Serwer elýeterli däl» diýip galman, dogry serwere baglanýar.
- `workflow_dispatch` diňe iş tertibi (`workflow` faýly) `main`-da bar bolsa işleýär —
  täze workflow üýtgeşmesi `main`-a merge bolmanka «Run workflow» düwmesi görünmez.
- Wersiýa belgisi: `pubspec.yaml` (`version: 0.3.0+3`) — täze APK her gezek
  `versionCode`-ny ýokarlandyryň, ýogsa Android köne APK-ny täzelemez
  (`MASLAHATLAR.md`, 4.6).
- Debug/release APK-lar **debug açary** bilen gol çekilýär — beta üçin ýeterlik,
  Play Store üçin aýratyn keystore gerek (`android/app/build.gradle.kts`).

---

## 4. ⚠️ Maglumat saklanyşy (hakyky korpus üçin hökman okalyň)

| Zat | Häzir | Netije |
|---|---|---|
| SQLite bazasy | `/tmp/…` wagtlaýyn diskde | Redeploy/restart → ýazgylar ýitýär |
| Ses faýllary (`audio/`) | şol ýerde | Şeýle hem ýitýär |
| Awraskalýasiýa (birnäçe nusga) | her nusganyň öz bazasy | Bir nusgada ýüklenen ýazgy beýlekisinde görünmez |

Şonuň üçin:

1. **Beta (10–20 adam, az maglumat):** häzirki FastAPI Cloud deployy ýeterlik —
   ýöne `ADMIN_TOKEN`-i aýda bir gezek `python scripts/build_whisper_dataset.py` üçin
   eksport (`/api/v1/admin/export.zip`) alyp durmaklygy endik ediniň.
2. **Hakyky korpus (müňlerçe ýazgy):** maglumatlaryň daşky saklanyşyna geçmeli:
   - **Postgres** (FastAPI Cloud-da Neon/Supabase integrasiýasy taýýar) — logika üçin
     `backend/app/db/sqlite.py` + `repositories/` gatlagyny Postgres-e geçirmek gerek;
   - **S3 / Cloudflare R2** — ses faýllary üçin (häzir lokal disk ulanylýar);
   - ýa-da öz serwer (VPS) + hemişelik disk (7-nji bölüm).

Bu işleriň meýilnamasy `MASLAHATLAR.md`-de (2-nji bölüm: öndürmek üçin infrastruktura).

---

## 5. Troubleshooting

| Nyşan | Sebäbi we çäresi |
|---|---|
| Build: “Could not find app / no FastAPI app found” | **Application Directory** `backend` goýulmadyk ýa-da `pyproject.toml` görülmeýär. Settings-den `backend` ýazyň. |
| Build: paket gurulmaýar / “No module named app” | `pyproject.toml`-da `[tool.fastapi] entrypoint = "app.main:app"` bolmaly (bar). |
| `400 Invalid host header` | `PUBLIC_BASE_URL` ýa-da `ALLOWED_HOSTS` aslynda ulanýan domeniňizden başga. Dogry URL-i goýuň (localhost/127.0.0.1 elmydama rugsat berilýär). |
| Admin panel açyk / token soramaýar | `ADMIN_TOKEN` goýulmadyk. Secret goýuň we redeploy ediň. |
| Ýazgylar birnäçe sagatdan ýitdi | Wagtlaýyn disk (4-nji bölüm). |
| APK serwere birikmeýär («Serwer elýeterli däl» / sinhronizasiýa düşýär) | `API_BASE_URL` variable ýalňyş (käwagt `https://example.com` ýaly ýer goýujy salgy galýar). Workflow logynda **«APK şu salga birikdirilýär: …»** setirini barlaň; dogry baha — `https://turkmen-voice-09885e66.fastapicloud.dev/api/v1`. |
| `PUBLIC_BASE_URL` ýalňyş → audio linkler 404 | Eksportda/`audio_url`-da ulanylýar; App → Overview-daky doly URL-i goýuň. |
| Deploy “failed” bolsa | Dashboard → **Deployments → şol deployment → Logs**; iň soňky işleýän wersiýa awtomatik saklanýar. |

---

## 6. Lokal işletmek (deploy-dan öň barlamak)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate      # ýa-da: pip install "fastapi[standard]"
pip install -r requirements-dev.txt

python -m pytest tests -q                 # 22 kontrakt test
DATA_DIR=app/data ADMIN_TOKEN=secret fastapi dev    # http://127.0.0.1:8000
# ýa-da: uvicorn app.main:app --host 0.0.0.0 --port 8000

python scripts/seed_demo.py --takes 40    # reýting tablisasy boş görünmez ýaly
python scripts/smoke_test.py --base-url http://127.0.0.1:8000/api/v1 --admin-token secret
```

`DATA_DIR` goýulmasa, maglumat `backend/app/data/` bukjasynda saklanýar
(işleýän bukja nirededigine garamazdan — ýol kodda kesgitlenýär).

---

## 7. Ätiýaçlyk: öz serweriňizde (VPS, docker compose)

Bulutda maglumat saklamak zerur bolsa, `backend/Dockerfile` + `docker-compose.yml`
hemişelik disk bilen işleýär:

```bash
cd backend
export ADMIN_TOKEN=$(openssl rand -hex 16)
export PUBLIC_BASE_URL=https://api.sizin-domen.tm
docker compose up -d --build
docker compose logs -f api
```

`docker-compose.yml` `turkmen_ses_data` atly hemişelik diski `/data` ýerine
birikdirýär (SQLite + audio + gündelik `backups/` arhiwi). HTTPS üçin öňünde
reverse proxy (nginx/Caddy) goýuň — API 8000-nji portda diňleýär.

Backend maglumatlarynyň ätiýaç nusgasyny almak:

```bash
curl -H "X-Admin-Token: $ADMIN_TOKEN" $BASE/api/v1/admin/export.zip -o backup.zip
```

---

## Goşmaça

- `ARCHITECTURE.md` — backend gatlaklary
- `MASLAHATLAR.md` — indiki ädimler (Postgres/S3, VAD, diarizasiýa)
- `MVP.md` — başdaky MVP kesgitlemesi (taryhy dokument)
- Cloud resminamalary: <https://fastapicloud.com/docs/>
