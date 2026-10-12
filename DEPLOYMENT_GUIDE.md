# Türkmen Ses — serwere çykarmak (backend) we APK gurmak

Bu gollanma: **GitHub → serwer** ýoluny ädimme-ädim görkezýär. Üç wariant bar,
haýsysyny saýlasaňyz hem APK-ny bir zady üýtgetmän ulanmagy dowam edip bilersiňiz —
diňe `API_BASE_URL` çalyşýar.

| Wariant | Bahasy | Hemişelik disk | Haçan maslahat |
|---|---|---|---|
| **A. Fly.io** | mugt däl (takmynan 2–4 $/aý) | bar (3 GB) | iň aňsat, iň ygtybarly |
| **B. Render** | free (disk ýok) / starter (disk bar) | diňe tölegli planda | çalt synag |
| **C. Öz VPS (docker compose + Caddy)** | serweriňize bagly | bar | doly gözegçilik |
| **D. Azure Web App** | bahaly | App Service disk | korporatiw |

> ⚠️ Muhim: SQLite + ses faýllary **hemişelik diskde** (volume) saklanmaly.
> Disksiz (mysal: Render free) her redeployda bütin dataset ýitýär.

---

## 0. Öňünden barlamak (lokal)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# 1) testler
python -m pytest tests -q

# 2) serweri işledip, aragatnaşygy barlamak
DATA_DIR=app/data uvicorn app.main:app --host 0.0.0.0 --port 8000 &
python scripts/smoke_test.py --base-url http://127.0.0.1:8000/api/v1

# 3) demo maglumat (reýting tablisasy boş görünmez ýaly)
python scripts/seed_demo.py --takes 40
```

Admin panel: `http://127.0.0.1:8000/admin/` · Swagger: `/docs`

---

## A. Fly.io (maslahat berilýän)

```bash
# 1) flyctl gurnamak
curl -L https://fly.io/install.sh | sh

# 2) login + app döretmek
cd backend
fly auth login
fly launch --copy-config --name turkmen-ses-api --region fra

# 3) hemişelik disk (audio + sqlite şu ýerde ýaşar)
fly volumes create turkmen_ses_data --size 3 --region fra

# 4) admin tokeni (hökman!)
fly secrets set ADMIN_TOKEN=$(openssl rand -hex 16)

# 5) goýbermek
fly deploy
```

Soň:

```bash
curl https://turkmen-ses-api.fly.dev/api/v1/health
python scripts/smoke_test.py --base-url https://turkmen-ses-api.fly.dev/api/v1 --admin-token TOKEN
```

GitHub-dan awtomatik deploy etmek üçin: `FLY_API_TOKEN` secret goşuň
(`fly tokens create deploy -x 999999h`), soňra **Actions → Deploy backend → Run workflow**
düwmesine basyň.

---

## B. Render

1. Repo GitHub-da bolmaly (şu repo).
2. Render → **New +** → **Blueprint** → repoyňyzy saýlaň. Render `backend/render.yaml`-y okar.
3. `backend/render.yaml` **`plan: starter`** + 5 GB disk ulanýar (disksiz variantly
   `plan: free` edip, `disk:` bölümini pozup bilersiňiz — ýöne maglumat ýitip biler).
4. Blueprint `ADMIN_TOKEN`-i özi generasiýa edýär → Render → Environment bölüminden göçürip alyň.
5. Deploy gutarandan soň: `https://<service>.onrender.com/api/v1/health`

Render deploy hook bilen Actions-dan goýbermek: **Settings → Deploy Hook** URL-ni
`RENDER_DEPLOY_HOOK` secret hökmünde goşuň.

---

## C. Öz VPS-iňiz (Docker Compose + Caddy)

```bash
# serwerde
git clone https://github.com/eliotlastdance00-art/turkmen_voice.git
cd turkmen_voice/backend

cp .env.example .env
nano .env        # ADMIN_TOKEN, API_DOMAIN (mysal: api.turkmen-ses.tm), CORS_ORIGINS

docker compose up -d --build
docker compose logs -f api
```

Caddy awtomatik HTTPS sertifikat alýar (domeniňiz bar bolsa). Gündelik backup
(`backups/` bukjasy) hem `docker-compose.yml` içinde taýýar.

---

## D. Azure Web App

`.github/workflows/azure-container-webapp.yml` taýýar: image `ghcr.io`-a gurlup,
Azure-a goýberilýär. Gerekli:
- Variable: `AZURE_WEBAPP_NAME`
- Secret: `AZURE_WEBAPP_PUBLISH_PROFILE`
- App Settings: `DATA_DIR=/home/data`, `ADMIN_TOKEN=...`, `WEBSITES_PORT=8000`

---

## 2. APK-ny şol serwere birikdirmek

1. GitHub repo → **Settings → Secrets and variables → Actions → Variables → New variable**
   ```
   API_BASE_URL = https://SIZIŇ-API/api/v1
   ```
2. **Actions → Build Android APK → Run workflow** (ora `main` şahasyny saýlaň).
3. Gutarandan soň **Artifacts → turkmen-ses-debug-apk** ýükläň.

Release APK üçin: **Build Android Release APK** iş akymy (`workflow_dispatch`).
Häzir debug açary bilen gol çekilýär — Play Store üçin öz keystore-yňyz gerek
(`android/app/build.gradle.kts` → `signingConfigs`).

Lokal gurmak:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# emulyator üçin
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# hakyky telefondan LAN-daky serwere
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1
```

---

## 3. Deploydan soň barlag sanawy

```bash
API=https://SIZIŇ-API/api/v1
TOKEN=SIZIŇ_ADMIN_TOKEN

curl $API/health                     # {"ok": true, ...}
curl $API/health/ready               # "writable": true, boş disk
curl $API/sentences/packages         # 6 paket
curl -H "X-Admin-Token: $TOKEN" $API/admin/stats
curl -H "X-Admin-Token: $TOKEN" $API/admin/export.whisper.jsonl | head -3
python scripts/smoke_test.py --base-url $API --admin-token $TOKEN
```

Telefondan: programmany açyň → **Profil** bölüminde serwer salgysy görünýär →
**Baş sahypa → Nobaty iber** → bir ýazgy göterip, admin panelde görkezilmeli.

---

## 4. Dataset eksporty we Whisper fine-tuning

```bash
# 1) serwerden eksport
curl -H "X-Admin-Token: $TOKEN" $API/admin/export.zip -o dataset_bundle.zip
unzip dataset_bundle.zip -d dataset

# 2) train/validation/test bölünişi (speaker boýunça, sızma ýok)
python scripts/build_whisper_dataset.py --input dataset --output whisper_dataset

# 3) fine-tune (GPU bar bolsa)
pip install "transformers>=4.44" datasets evaluate jiwer torch librosa soundfile accelerate
python scripts/whisper_finetune.py --dataset whisper_dataset --model openai/whisper-small --output whisper-tk
```

Hil hasabaty (`dataset/report.json`) we `whisper_dataset/validation_report.json`
haýsy klipleriň taşlanandygyny we näme üçin (gysga, sessiz, dublikat, format) görkezýär.

---

## 5. Backup we gorag

```bash
# sqlite + audio-dan gündelik arhiw (VPS-de awtomatik: docker compose içindäki "backup" hyzmaty)
tar czf turkmen-ses-$(date +%F).tar.gz -C backend/app/data .

# serwere göçürmek (S3/R2 üçin)
aws s3 cp turkmen-ses-$(date +%F).tar.gz s3://bucket/backups/
```

Gorag sanawy:
- [ ] `ADMIN_TOKEN` güýçli (16+ simwol) we gizlin
- [ ] HTTPS (Fly/Render/Caddy awtomatik)
- [ ] `CORS_ORIGINS`-y diňe zerur domenlere çäklendirmek
- [ ] Backup bar we barlanan (bir gezek dikeltmegi synag ediň)
- [ ] `RATINGS_DAILY_LIMIT` we `MAX_AUDIO_BYTES` serweriň kuwwatyna laýyk
