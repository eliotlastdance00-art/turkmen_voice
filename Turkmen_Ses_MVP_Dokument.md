# Türkmen Ses — MVP Dokumenti

## 1. Dokumentiň maksady

Bu dokument Türkmen dili üçin Common Voice görnüşli ses maglumat ýygnama programmasynyň ilkinji işleýän wersiýasyny — MVP-ni kesgitleýär.

Programma Android we iPhone enjamlarynda işlemeli, internetsiz ýagdaýda ses ýazga almaly, ýazgylary lokal saklamaly we ulanyjynyň rugsady bilen soňra servere ibermeli. Ýygnalan audio + tekst maglumatlary Türkmençe speech-to-text modellerini, şol sanda Whisper modelini fine-tuning etmek üçin ulanylar.

## 2. MVP-niň esasy maksady

MVP şu esasy prosesi subut etmeli:

1. Ulanyja Türkmençe sözlem görkezmek.
2. Ulanyjynyň şol sözlemi ses bilen okamagy.
3. Ses ýazgysyny telefonda lokal saklamak.
4. Internet ýok wagty hem ýazgy prosesiniň işlemegi.
5. Internet bar wagty ýazgylary serwere ibermek.
6. Audio we tekst maglumatlaryny dataset görnüşinde eksport etmek.

## 3. MVP-niň çägi

### MVP-de boljak funksiýalar

- Android we iOS üçin mobil programma
- Türkmençe sözlemleriň taýýar toplumy
- Mikrofon rugsadyny almak
- Ses ýazga almak
- Ýazgyny diňläp görmek
- Ýazgyny kabul etmek ýa-da täzeden ýazmak
- Lokal SQLite maglumat bazasy
- Lokal audio faýllary
- Offline işlemek
- Upload nobaty
- Manual ýa-da Wi-Fi arkaly upload
- Upload statusyny görmek
- Ulanyjynyň ýazgylaryny pozmak
- Ýönekeý backend API
- Audio object storage
- Admin üçin ýazgylary görmek
- CSV/JSONL dataset eksporty
- Razylyk we gizlinlik akymy

### MVP-de bolmajak funksiýalar

- Göni wagtda Whisper bilen awtomatiki transcript barlagy
- Sosial ulgam
- Leaderboard we baýrak ulgamy
- Çylşyrymly user profile
- Töleg ulgamy
- Köp derejeli admin rollary
- Awto-dialekt tanamak
- On-device Whisper modeli
- Audio redaktory
- Çylşyrymly awtomatiki moderasiýa

Bu funksiýalar MVP-den soňky tapgyr üçin saklanýar.

## 4. Maksatly ulanyjylar

### Esasy ulanyjylar

- Türkmençe gürleýän adamlar
- Dürli ýaşdaky ses donorlary
- Dürli sebitlerden we dialektlerden gürleýänler
- STT maglumatlaryny meýletin paýlaşmak isleýänler

### Admin ulanyjylar

- Dataset dolandyryjysy
- Audio hil barlaýjy
- Model training topary

## 5. Razylyk we gizlinlik

Programma ses ýazga başlamazdan öň ulanyjydan açyk razylyk almaly.

Ulanyja şu maglumatlar düşündirilmeli:

- Ses ýazgysynyň nähili maksat bilen ýygnalýandygy
- Maglumatlaryň Türkmençe STT modelini ösdürmek üçin ulanyljakdygy
- Ses ýazgylarynyň ýapyk ýa-da açyk dataset hökmünde ulanylyp bilinjekdigi
- Ulanyjynyň ýazgylaryny pozup bilýändigi
- Maglumatlaryň serwere iberilmeginiň meýletin bolmagy
- Maglumatlaryň näçe wagt saklanýandygy

### MVP üçin razylyk görnüşleri

Ulanyjy iki saýlawdan birini saýlap biler:

1. **Ýapyk ulanyş:** ses diňe taslamanyň içerki model taýýarlygy üçin ulanylýar.
2. **Dataset ulanyşy:** ses Türkmençe STT dataset-inde ulanylyp bilner.

Razylyk bolmazdan audio servere iberilmeli däl.

## 6. Mobil programmanyň esasy ekranlary

### 6.1. Başlangyç ekrany

Elementler:

- Programmanyň ady
- Gysga düşündiriş
- Başlamak düwmesi
- Dili saýlamak mümkinçiligi — ilkinji wersiýada Türkmençe

### 6.2. Razylyk ekrany

Elementler:

- Gysga gizlinlik beýany
- Doly şertlere geçiş
- Razylyk checkbox-y
- Dowam etmek düwmesi

### 6.3. Paket saýlamak ekrany

Ulanyjy öňünden ýükläp alnan tekst paketlerinden birini saýlaýar.

MVP üçin:

- Paket 1: 100 sözlem
- Paket 2: 500 sözlem
- Paket statusy: ýüklendi / ýüklän däl

Internet ýok wagty diňe telefonda bar bolan paketler görkezilýär.

### 6.4. Sözlem we ýazgy ekrany

Elementler:

- Türkmençe sözlem
- Ýazgy ýagdaýy
- Wagt görkezijisi
- Ýazga başlamak düwmesi
- Duruzmak düwmesi
- Ýatyr düwmesi

Mysal sözlem:

> Men şu gün täze kitap okadym.

### 6.5. Ýazgyny barlamak ekrany

Elementler:

- Teksti täzeden görkezmek
- Audio diňlemek
- Kabul etmek
- Täzeden ýazmak
- Pozmak

### 6.6. Ýazgylarym ekrany

Ulanyjy şu maglumatlary görýär:

- Jemi ýazgy sany
- Ýüklenen ýazgylar
- Garaşýan ýazgylar
- Ýalňyşlyk bolan ýazgylar
- Her ýazgynyň statusy

### 6.7. Sync ekrany

Elementler:

- Garaşýan ýazgylaryň sany
- Upload başlatmak
- Diňe Wi-Fi ulansyn saýlawy
- Upload progress
- Täzeden synanyşmak

### 6.8. Sazlamalar ekrany

- Razylyk ýagdaýy
- Gizlinlik syýasaty
- Ulanyjy maglumatlaryny eksport etmek
- Ähli lokal ýazgylary pozmak
- Razylygy yzyna almak
- Programma wersiýasy

## 7. Ses ýazgy standartlary

MVP üçin standartlar:

- Format: WAV
- Sample rate: 16,000 Hz
- Channel: mono
- Bit depth: 16-bit PCM
- Bir sözlem: bir audio faýl
- Maksimum dowamlylyk: 15 sekunt
- Minimum dowamlylyk: 0.5 sekunt
- Maksimum faýl ululygy: 10 MB

Audio faýlynyň ady:

```text
{recording_id}.wav
```

## 8. Lokal maglumat modeli

### Sentence

```json
{
  "id": "sentence_000001",
  "text": "Men şu gün täze kitap okadym.",
  "language": "tk",
  "category": "daily",
  "package_id": "package_001"
}
```

### Recording

```json
{
  "id": "recording_000001",
  "sentence_id": "sentence_000001",
  "text": "Men şu gün täze kitap okadym.",
  "audio_path": "recordings/recording_000001.wav",
  "duration_ms": 4200,
  "sample_rate": 16000,
  "status": "pending",
  "consent_type": "dataset",
  "created_at": "2026-09-21T10:30:00Z",
  "uploaded_at": null,
  "error_message": null
}
```

### Recording status-lary

```text
pending       — upload garaşýar
uploading     — upload dowam edýär
uploaded      — servere üstünlikli iberildi
failed        — upload şowsuz boldy
approved      — admin tarapyndan kabul edildi
rejected      — admin tarapyndan ret edildi
```

## 9. Offline iş akymy

1. Ulanyjy programmany açýar.
2. Lokal paketden sözlem saýlaýar.
3. Sesi ýazga alýar.
4. Audio lokal bukjada saklanýar.
5. Metadata SQLite-de ýazylýar.
6. Recording status `pending` bolýar.
7. Internet bolmasa ulanyjy dowam edýär.
8. Internet gelende ulanyjy Sync bölümine girýär.
9. Pending ýazgylar serwere iberilýär.
10. Üstünlikli ýazgylar `uploaded` bolýar.

Internet baglanyşygy bolmasa, ýazgy almaga päsgel berilmeli däl.

## 10. Backend API

### POST /api/v1/recordings

Täze audio ýazgyny kabul edýär.

Form-data:

```text
recording_id
sentence_id
text
language
consent_type
duration_ms
audio_file
```

Jogap:

```json
{
  "success": true,
  "recording_id": "recording_000001",
  "status": "uploaded"
}
```

### GET /api/v1/sentences

Täze tekst paketlerini almak üçin ulanylýar.

### GET /api/v1/health

Serveriň işleýşini barlamak üçin ulanylýar.

### DELETE /api/v1/recordings/{id}

Ulanyjynyň degişli ýazgysyny pozmak üçin ulanylýar.

MVP-de authentication hökmany däl bolup biler, ýöne her install üçin anonim `device_id` döredilmeli. Soňky tapgyrda hasaba durmak goşulyp bilner.

## 11. Server arhitekturasy

### Backend

- FastAPI
- Python
- REST API
- Pydantic validation
- PostgreSQL

### Audio storage

- S3-compatible object storage
- Faýllar database içinde binary görnüşde saklanmaly däl

### Metadata

PostgreSQL-de şu maglumatlar saklanar:

- recording_id
- sentence_id
- text
- audio_url
- language
- consent_type
- duration
- status
- created_at
- uploaded_at
- reviewed_at

## 12. Admin panel MVP

Admin paneliň ilkinji wersiýasynda:

- Admin login
- Jemi ýazgylaryň sany
- Garaşýan ýazgylaryň sanawy
- Audio diňlemek
- Teksti görmek
- Approve düwmesi
- Reject düwmesi
- Rejection reason
- Filter: status, date, language, category
- CSV eksport
- JSONL eksport
- WAV faýllaryny ZIP görnüşinde almak

## 13. Dataset eksport formaty

### JSONL

```json
{"audio":"audio/recording_000001.wav","text":"Men şu gün täze kitap okadym."}
{"audio":"audio/recording_000002.wav","text":"Howanyň ýagdaýy örän gowy."}
```

### CSV

```csv
recording_id,audio_path,text,language,duration_ms
recording_000001,audio/recording_000001.wav,"Men şu gün täze kitap okadym.",tk,4200
```

Eksport diňe admin tarapyndan kabul edilen ýazgylardan düzülmeli.

## 14. Tekst dataset-i üçin ilkinji meýilnama

MVP üçin ilkinji paketde 1000 sözlem taýýarlamak maslahat berilýär.

Kategoriýalar:

- Gündelik durmuş: 250
- Howa we tebigat: 100
- Sanlar, wagt we seneler: 150
- Ulag we ýol: 100
- Bilim we iş: 100
- Tehnologiýa: 100
- Sorag we jogap sözlemleri: 100
- Ýer atlary we atlar: 50
- Dürli sözlemler: 50

Sözlemler:

- Grammatik taýdan dogry bolmaly
- Gysga we orta uzynlykda bolmaly
- Bir sözlemde bir esasy pikir bolmaly
- Awtorlyk hukugy bilen goralan çeşmeden rugsatsyz alynmaly däl
- Türkmen elipbiýindäki ýörite harplar dogry saklanmaly

## 15. Hil barlagy

MVP-de hökmany barlaglar:

- Audio faýly açylýarmy
- Audio mono görnüşindemi
- Sample rate 16 kHz-mi
- Audio boş ýa-da sessiz dälmi
- Sözlem boş dälmi
- Faýl ölçegi çäkden geçmeýärmi
- Bir recording_id gaýtalanmaýarmy
- Razylyk maglumatlary bar my

Ilkinji wersiýada tekst bilen audio-nyň awtomatiki gabat gelşini admin el bilen barlar.

## 16. Güvenlik talaplary

- API diňe HTTPS arkaly işleýär
- Audio upload üçin faýl görnüşi we ululygy barlanýar
- Admin panel login bilen goralýar
- Ulanyjy şahsy maglumatlary minimal saklanýar
- Razylyk wersiýasy her ýazgy bilen bile saklanýar
- Ulanyjy öz lokal ýazgylaryny pozup bilýär
- Serverde pozmak talaby ýerine ýetirilende audio we metadata bile pozulýar
- Backup režimi bolmaly

## 17. Tehnologiýa saýlawy

### Mobil

- Flutter
- Dart
- SQLite
- Drift ýa-da sqflite
- Audio recorder plugin
- Connectivity monitor

### Backend

- Python
- FastAPI
- PostgreSQL
- S3-compatible storage
- Docker

### Admin

- Ilkinji wersiýa: ýönekeý web panel
- React ýa-da server-side HTML
- Soňky wersiýa: doly React admin paneli

## 18. MVP üçin kabul ediş kriteriýalary

MVP taýýar hasaplanar, eger:

1. Android-de programma gurulyp işleýän bolsa.
2. iPhone-da programma gurulyp işleýän bolsa.
3. Internet ýok wagty sözlem paketinden ses ýazyp bolýan bolsa.
4. Ses ýazgysy lokal saklanýan bolsa.
5. Programma ýapylyp açylandan soň ýazgy ýitmeýän bolsa.
6. Ýazgyny diňläp we täzeden ýazyp bolýan bolsa.
7. Internet gelen wagty pending ýazgylar upload edilýän bolsa.
8. Upload ýalňyşlygynda ýazgy ýitmeýän bolsa.
9. Admin audio we tekst maglumatlaryny görüp bilýän bolsa.
10. Admin kabul edilen ýazgylary JSONL we CSV görnüşinde eksport edip bilýän bolsa.
11. Ulanyjy öz lokal maglumatlaryny pozup bilýän bolsa.
12. Razylyksyz ýazgy serwere iberilmese.

## 19. Iş tapgyrlary

### Tapgyr 1: Taslama taýýarlygy

- Git repository
- Flutter project
- Backend project
- Maglumat bazasynyň shemasy
- UI wireframe
- Privacy we consent tekstleri

### Tapgyr 2: Mobil MVP

- Başlangyç ekranlary
- Razylyk akymy
- Sentence paketleri
- Audio recording
- Replay we rerecord
- Lokal database
- Offline list

### Tapgyr 3: Backend

- API
- PostgreSQL
- Object storage
- Audio upload
- Status tracking

### Tapgyr 4: Admin panel

- Login
- Recording list
- Review
- Approve/reject
- Dataset export

### Tapgyr 5: Test

- Android test
- iPhone test
- Offline test
- Weak internet test
- Audio quality test
- Data deletion test

### Tapgyr 6: Beta release

- 10–20 synag ulanyjysy
- Ilkinji 5000–10000 audio ýazgysy
- Ýalňyşlyklary düzetmek
- Public release üçin taýýarlyk

## 20. Soňky tapgyrlar üçin backlog

- Ulanyjy hasaby
- Email ýa-da telefon arkaly login
- Awtomatiki sync
- Speech recognition bilen tekst barlagy
- Dialekt maglumatlary
- Gamification
- Audio quality score
- Duplicate detection
- Web admin paneliniň giňeldilmegi
- Hugging Face Dataset eksporty
- Whisper fine-tuning pipeline
- Modeliň programma içinde synagy
- Açyk dataset lisenziýasy

## 21. Ilkinji tehniki netije

Ilkinji döredilmeli wersiýa şu görnüşde kesgitlenýär:

```text
Flutter Mobile App
  - Offline sentence package
  - WAV recorder
  - SQLite local database
  - Upload queue

FastAPI Backend
  - Recording upload API
  - Sentence API
  - PostgreSQL metadata
  - S3-compatible audio storage

Admin Panel
  - Review recordings
  - Approve/reject
  - Export JSONL/CSV/WAV
```

Bu MVP tamamlanandan soň ýygnalan maglumatlaryň hili ölçenilip, Whisper fine-tuning üçin aýratyn dataset pipeline dörediler.

## 22. Indiki ädim

Indiki iş hökmünde şu tertip maslahat berilýär:

1. Taslamanyň iş adyny we domenini kesgitlemek.
2. Flutter project-i döretmek.
3. Mobil programmanyň ekranlaryny gurmak.
4. Lokal database we audio recording-i amala aşyrmak.
5. Backend API-ni döretmek.
6. Upload queue-ni birleşdirmek.
7. Admin panel we eksport funksiýasyny gurmak.
8. Ilkinji beta test geçirmek.
