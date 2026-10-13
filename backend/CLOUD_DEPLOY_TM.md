# FastAPI Cloud Deploy Gollanmasy (Türkmençe)

Bu proýekti bulut serwerine deploy etmek üçin ähli zerur sazlamalar taýýar.

## 📋 Zerur zatlar
1. GitHub akkaunty
2. Bulut platformasyndan birini saýla: **Render**, **Fly.io** ýa-da öz VPS-iň

---

## ⚙️ Esasy Environment Variables (Hemmesi üçin zerur)
Bulut platformasynyň Environment Variables bölümüne aşakdakylary hökman goý:

| Üýtgeýji (Variable) | Möçberi | Düşündiriş |
|----------------------|---------|------------|
| `ADMIN_TOKEN` | Hökman goý | Uzyn, howpsuz parol (meselem: `openssl rand -hex 16` ýasa). Boş goýsaň admin panel her kime açyk bolýar! |
| `DATA_DIR` | `/data` | Databaza we ses faýllaryny saklaýan ýer (hemişelik diskde goýulmaly) |
| `CORS_ORIGINS` | Öz domeniň | Diňe öz frontendiňiziň domenini goý (meselem: `https://turkmen-ses.fly.dev`). `*` diňe test üçin! |
| `PUBLIC_BASE_URL` | Öz domeniň | Deploy edilenden soňky doly URL (meselem: `https://turkmen-ses-api.onrender.com`). Audio linkleri we eksportlar üçin zerur |
| `PORT` | `8000` | Platforma özü kesgitleýär, köplenç awtomatik |

---

## 🚀 1. Render bilen deploy et (Iň aňsat)
Render da özü Docker konfigurýasiýany okaýar, hemişelik disk goldaýar.

### Ädimler:
1. Kody GitHub-a ýükle
2. Render-a gir → `New +` → `Blueprint`
3. Öz repozitoryňy saýla, **Root directory** edip `backend`-i saýla
4. `Apply` düwmesine bas
5. Awtomatik:
   - Docker build ediler
   - 5GB hemişelik disk `/data`-a mount ediler
   - `ADMIN_TOKEN` awtomatik ýasalar, ony **Environment** bölümünden göçürip al
6. Deploy gutarandan soň `PUBLIC_BASE_URL`-i öz Render URL-iň bilen doldur we täzeden deploy et

✅ Taýýar! API `https://senin-adin.onrender.com/api/v1/health` salgyda işlär.

---

## ✈️ 2. Fly.io bilen deploy et (Arzan, çalt)
Fly.io da 3GB hemişelik disk we aýda ~$0-$3 töleg bilen işledip bolýar.

### Öňünden:
- Fly CLI-ny gurna: `curl -L https://fly.io/install.sh | sh`
- Fly-a gir: `fly auth login`

### Ädimler:
```bash
cd backend
# Ilkinji gezek:
fly launch --copy-config --name senin-proyekt-adin --region fra
# Hemişelik disk ýasa:
fly volumes create turkmen_ses_data --size 3 --region fra
# Howpsuz admin token goý:
fly secrets set ADMIN_TOKEN=$(openssl rand -hex 16)
# Deploy et:
fly deploy
```

Soňra `fly.toml` faýlynda `public_base_url` üçin secret goý:
```bash
fly secrets set PUBLIC_BASE_URL=https://senin-proyekt-adin.fly.dev
```

✅ Taýýar! Saglyk barlagy awtomatik işlär.

---

## 🖥️ 3. Öz VPS / Ubuntu serwerine deploy et (Docker bilen)
Eger öz VPS-iň bar (DigitalOcean, Hetzner, AWS EC2 we ş.m.):

### Öňünden:
- Docker we Docker Compose gurnalan bolmaly

### Ädimler:
1. Kody serwere çek:
```bash
git clone https://github.com/adin/turkmen_voice.git
cd turkmen_voice/backend
```

2. `.env` faýly ýasa:
```bash
cp .env.example .env
nano .env
```
Içinde:
- `ADMIN_TOKEN`-y güýçli parol bilen doldur
- `PUBLIC_BASE_URL`-y öz serweriň domeni ýa-da IP-si bilen doldur
- `CORS_ORIGINS`-y öz frontendiň domeni bilen çäklendir

3. Docker Compose bilen işlet:
```bash
docker compose up -d --build
```

4. (Islege gör) Nginx ýa-da Caddy bilen SSL we reverse proxy gurna:
Proýektde `Caddyfile` taýýar! Caddy işletseň awtomatik HTTPS alar:
```bash
caddy start --config Caddyfile
```

---

## ⚠️ Esasy ýatda saklamaly zatlar
1. **Hemişelik disk hökman gerek!** `/data` ýerini mount etmeseňiz, redeploy/deploy eden wagtyňyz ähli ses ýazgylary we databaza ýitýär!
2. **ADMIN_TOKEN hökman goý!** Boş goýsaňyz islendik adam admin panela girip, ähli maglumatlary alyp ýa-da pozup biler.
3. **CORS-y `*` goýmagy produksiyonda ulanma!** Diňe siziň öz domeniňize rugsat ber.
4. Söwda üçin ulanjak bolsaňyz `gunicorn` bilen işlediň (konfigurýasiýa Docker-da taýýar), bir işçi proses ýetmezçilik etmez.
5. `PUBLIC_BASE_URL`-y hökman doldurmasaňyz, audio faýllarynyň linkleri dogry işlemeýär.

---

## ✅ Barlamak üçin
Deploy gutarandan soň aşakdaky salga gir:
`https://sizin-url/api/v1/health`

Eger `{"status":"ok"}` jogap gelse, hemmesi dogry işledi!
Admin panela `https://sizin-url/admin/` salgysyndan girip bilersiňiz.
