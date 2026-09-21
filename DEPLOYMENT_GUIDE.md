# Türkmen Ses — Free test deployment

## Iň aňsat wariant

- Backend: Render free Docker web service
- Kod: GitHub repository
- APK: GitHub Actions artifact
- Storage: häzirki MVP-de local disk/SQLite, diňe test üçin

> Üns beriň: Render free service sleep bolýar we local disk persistent däl. Restart ýa-da redeploy bolanda SQLite/audio ýitip biler. Real dataset üçin PostgreSQL + S3/Supabase gerek.

## 1. GitHub repository gurluşy

Iki aýratyn repository maslahat berilýär:

```text
turkmen-ses-mobile
turkmen-ses-backend
```

Ýa-da häzirki iki bukjany bir monorepo-da saklap bilersiňiz.

Mobile repo içine:

```text
/home/user/turkmen_ses/*
```

Backend repo içine:

```text
/home/user/turkmen_ses_backend/*
```

## 2. Backend-i GitHub-a ibermek

```bash
cd turkmen_ses_backend
git init
git add .
git commit -m "Initial layered backend"
git branch -M main
git remote add origin https://github.com/YOUR_USER/turkmen-ses-backend.git
git push -u origin main
```

## 3. Render-de deploy

1. render.com-a giriň.
2. New → Web Service saýlaň.
3. GitHub repository-ni birikdiriň.
4. Root directory: `turkmen_ses_backend` — monorepo bolsa.
5. Runtime: Docker.
6. Plan: Free.
7. Health check: `/api/v1/health`.
8. Deploy basyň.

`render.yaml` bar bolsa Blueprint arkaly hem deploy edip bolýar.

Deploy soň URL şuňa meňzeş bolar:

```text
https://turkmen-ses-api.onrender.com
```

Test:

```bash
curl https://YOUR-SERVICE.onrender.com/api/v1/health
```

## 4. Flutter API adresi

Mobile programmada server adresi build wagtynda berilýär.

Android emulator üçin:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Render üçin:

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com/api/v1
```

## 5. GitHub Actions arkaly APK

Mobile repository-de şu workflow bar:

```text
.github/workflows/build-apk.yml
```

GitHub repository Settings → Secrets and variables → Actions → Variables bölüminde şu variable dörediň:

```text
API_BASE_URL=https://YOUR-SERVICE.onrender.com/api/v1
```

Soňra:

1. GitHub → Actions açyň.
2. Build Android APK workflow saýlaň.
3. Run workflow basyň.
4. Workflow tamamlanandan soň Artifacts bölüminden APK ýükläň.

APK ady:

```text
turkmen-ses-debug-apk
```

Bu APK test üçin ýeterlikdir. Play Store üçin release signing gerek.

## 6. Lokal test

Terminal 1:

```bash
cd turkmen_ses_backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Terminal 2:

```bash
cd turkmen_ses
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## 7. Möhüm çäklendirme

Render Free-de şu MVP zatlary diňe test üçin:

- Web service wagtal-wagtal sleep bolýar.
- Ilkinji request haýal bolup biler.
- Local SQLite persistent storage däl.
- Audio faýllary restart/deploy-den soň ýitip biler.
- Production dataset-i bu ýerde saklamaly däl.

Production-a geçmezden öň:

```text
PostgreSQL     → metadata
S3/R2          → audio files
Object storage → backups
JWT/Auth       → admin protection
```
