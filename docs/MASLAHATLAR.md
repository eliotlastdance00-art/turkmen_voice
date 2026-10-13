# Maslahatlar we indiki ädimler

Bu faýl häzirki ýagdaýdan (v0.3) soň **haýsy işleriň iň köp peýda berjekdigi** barada
ýazylan maslahatlardyr. Tertip boýunça — ýokarsy has möhüm.

---

## 1. Häzir etmeli (birnäçe sagatlyk iş)

### 1.1. Backend-i FastAPI Cloud-a çykarmak
Repo taýýar (`backend/pyproject.toml`, `.github/workflows/deploy-fastapi-cloud.yml`).
Galan işler dashboard-da:

- **Application Directory** = `backend` (App → Settings)
- `ADMIN_TOKEN` (secret!), `PUBLIC_BASE_URL`, `DATA_DIR`, `CORS_ORIGINS` goýuň
- `main`-a push → awtomatik deploy (GitHub integrasiýasy)

Jikme-jik ädimme-ädim: `DEPLOYMENT.md`.

Soňra:
- APK üçin `API_BASE_URL` repository variable goýuň → APK şol serwere birikdirilip gurulýar.
- ⚠️ FastAPI Cloud-yň diski wagtlaýyn — 4-nji bölümi (Infrastruktura) öňünden meýilleşdiriň.

### 1.2. Demo maglumat bilen synag
```bash
python scripts/seed_demo.py --takes 40     # 6 gürleýji, 40 ýazgy, reýtingler
python scripts/smoke_test.py --base-url https://SIZIŇ-API/api/v1 --admin-token TOKEN
```

### 1.3. Beta synagçylary (10–20 adam)
Häzirki APK debug açary bilen gol çekilýär — synag üçin ýeterlik. Synagçylara:
- «Baha ber» bölümini düşündiriň (ol ýerde jemgyýetçilik hil süzgüji işleýär),
- offline režimde hem işleýändigini aýdyň.

---

## 2. Verileriň hili (Whisper üçin iň möhüm)

### 2.1. Awtomatik barlag + gapdal süzgüç
- **Speaker diarization ýok**: bir hasaptan birnäçe adam ýazsa, olar bir `user_id` bilen
  gidýär. Maslahat: her ulanyja «kim ýazýar?» diýen saýlaw goşmak ýa-da 1 hesap = 1 ses
  düzgünini berk saklamak (beta üçin şeýle hem bolýar).
- **VAD (sessizlik barlagy)**: backendde RMS bar, ýöne gürleýjiniň başy/ahyryndaky
  uzyn sessizligi kesmek üçin `silero-vad` goşulmagy maslahat berilýär.
- **Awto-transkripsiýa bilen barlag**: Whisper `small` modelini serwerde işledip,
  sözlemiň gabat gelşini (WER) ölçäp, `verified` derejesini awtomatik goýmak.
  Bu «comment/ýyldyz» ýerine iň ygtybarly hil süzgüji bolar.
- **Dialekt bellikleri**: sözlemler aşakdaky görnüşde bellense, modeliň netijesi
  has gowy bolar (MVP dokumendäki backlog-da bar).

### 2.2. Dataset ölçegi
Häzir 215 sözlem bar. MVP maksady 1000+:
- paketlere görä bölüp goşuň (`tools/build_sentence_seed.py`),
- her sözlem üçin **iň az 3 dürli gürleýji** (10 sagat ses ≈ 3000–5000 klip).
- Türkmençe sözlemleriň dogry ýazylşyny barlamak hökmany (admin panel + redaksiýa).

### 2.3. Zawod (pipeline) tertibi
```
 telefon → API (16 kHz mono wav, sha256)
        → jemgyýetçilik reýtingi (3+ baha → awtomatik tassyklama)
        → admin barlagy (şübheli ýagdaýda)
        → /admin/export.zip
        → scripts/build_whisper_dataset.py  (train/val/test, speaker bölünişi)
        → scripts/whisper_finetune.py       (whisper-small fine-tune)
        → modeliň WER-i ölçenip, ýene dataset üstüne goşulmagy
```

---

## 3. Infrastruktura

| Zat | Häzir | Maslahat |
|---|---|---|
| Metadata | SQLite (FastAPI Cloud-da wagtlaýyn disk!) | **PostgreSQL** (Neon/Supabase + SQLAlchemy/Alembic) — hakyky korpus üçin iň birinji iş |
| Audio | lokal disk | **S3/R2/B2** (`boto3`), faýl ady `tk/<speaker>/<sha>.wav` |
| Admin auth | statik token | JWT + rollar (barlaýjy / admin) |
| Backup | `export.zip` + VPS-de gündelik tar.gz | Awtomatik eksport → S3; beta wagtynda elimiz bilen alyp durmak |
| Monitoring | ýok | `/api/v1/health/ready` + Sentry/UptimeRobot |
| Maglumat pozmak | bar (ulanyjy) | GDPR: «ähli maglumatymy poz» → serwerde hem poz |
| Rate limit | ýok | `slowapi` ýa-da reverse proxy-de (`nginx`/Caddy) `rate_limit` |

> Diqqat: FastAPI Cloud-da hemme maglumat bir nusganyň wagtlaýyn diskinde ýaşaýar —
> redeploy bolanda ýitýär. Şonuň üçin 1-nji setir (Postgres) we 2-nji setir (S3)
> beta gutarmanka meýilleşdirilmelidir.

---

## 4. Programma (frontend) üçin indiki funksiýalar

1. **Sesiň awtomatik barlagy**: ýazgydan soň ses derejesiniň gistogrammasyny görkezmek
   («juda ýuwaş / juda gaty»), duş gelýän ýalňyşlary maslahat bermek.
2. **Push bildirişleri** (günlük maksat, reýting tablisasyndaky üýtgeşme).
3. **Dialekt/ýaş/ jyns saýlawy** (profile goşulýar, dataset meta-maglumaty üçin gymmatly).
4. **Sözlem boýunça sesiň taryhy**: bir sözlem üçin birnäçe gezek ýazyp, iň gowusyny saýlamak.
5. **Web admin panelini React-e geçirmek** — häzirki ýönekeý HTML ýeterlik, ýöne
   100k+ ýazgy üçin filtrleme/pagination gerek.
6. **Köne APK-laryň üpjünçiligi**: syýasaty üýtgedende `versionCode`-y ýokarlandyryň we
   app-iň içinde «täze wersiýa bar» diýen duýduryş goşuň.

---

## 5. Guramacylyk we hukuk

- **Razylyk wersiýasy**: razylyk teksti üýtgese, `consent_version` meýdanyny goşup,
  täzeden razylyk almak (audit üçin möhüm).
- **Açyk lisenziýa**: dataseti çap etjek bolsaňyz (Hugging Face `turkmen_ses`),
  lisenziýany we `README`-daky attribution-y öňünden taýýarlaň (mysal: CC-BY-4.0 + Türkmençe).
- **Şahsy maglumat**: häzir hiç zat soralmaýar — bu gowy. Munuň özi «hasap dikeltmek»
  mümkinçiliginiň ýokdugyny aňladýar (telefon çalyşsaň, hasap ýitýär). Maslahat: islege görä
  e-poçta baglamak (hasaby dikeltmek üçin) ýa-da eksport/import «hasap açary».
- **Zähmet hakydasy**: kämil däl ýazgylary «ret etmek» däl-de, ulanyja düşündirmek
  (näme üçin ret edildi) — bu ulanyjynyň hyzmatynyň dowamlylygyny ýokarlandyrýar
  (`rejection_reason` eýýäm bar).

---

## 6. Modeliň özi barada maslahatlar

- **whisper-small** bilen başlaň (türkmençe üçin az maglumat ýeterlik: 10–30 sagat).
- Türkmen dili üçin `language='turkmen'`; Whisper-da `tk` ýok bolsa, `Turkish` (`tr`)
  bilen deňeşdirip görüň — türkmen diliniň fonetikasy türkçä golaý.
- Harplaryň dogry ýazylşy (`ň`, `ä`, `ž`, `ý`, `ü`, `ö`, `ş`, `ç`) modeliň sözünde
  sık ýalňyşýan ýeri; datasetde **hemme ýerde birmeňzeş** bolmaly (backend `normalize_text`
  edýär: NFC + ýörite kesgitlemeler).
- Fine-tune soň `wer`, `cer` ölçäp, 20–50 klipden ybarat «hil depginini» elde saklaň.
