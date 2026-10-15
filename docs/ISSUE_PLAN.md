# Ýalňyşlyklaryň sanawy we düzediş meýilnamasy (step by step)

Bu faýl ulanyjynyň habar beren kemçiliklerini yzarlamak üçin ýöredilýär.
Her ädim aýratyn commit + test bilen tamamlanýar.

| # | Kemçilik | Ýagdaý | Çözülişi |
|---|----------|--------|----------|
| 1 | Ulanyjy döredilmeýär / token saklanmaýar | ✅ tamamlandy | Serwerde **hakyky token** (`users.token`, `tk_` + 32 harp), köne `tk_<user_id>` hem işleýär. Programmada retry/backoff + 401 bolsa awtomatik täzeden döretmek + profil snapshot |
| 2 | Ses ýazdyranda tekstleriň nireden gelýändigi düşnüksiz | ✅ tamamlandy | Tekstler: serwer seed (6 paket/215 sözlem) → programmanyň içindäki `assets/sentences_seed.json` → drift keşi. UI-da "Çeşme: …" + ℹ düşündiriş dialogy |
| 3 | Ulanyjynyň özi tekst ýazmaly | ✅ tamamlandy | "Öz sözlemim" düzgüni: tekst meýdançasy, türkmen elipbiýi barlagy, uzynlyk duýduryşy, tekst goraghana goşulýar |
| 4 | Bir sözlemi ikinji gezek ýazdyrmaly däl | ✅ tamamlandy | Programma: ýazylan sözlemler/tekstler sanawdan aýrylýar, ýazgydan soň tekst boşadylýar, indiki sözlem awtomatik goýulýar. Serwer: 409 + "öňki ýazgyny poz" (ret edilen ýazgy täzeden mümkin) |
| 5 | Serwer bilen birikme problemalary | ✅ tamamlandy | Dio retry (eksponensial), `ping()` saglyk barlagy, nobat üçin döwürleýin gaýtalamak (2→15 min), serwer adresini sazlamalar arkaly üýtgetmek, 401-de sessiýany täzelemek |
| 6 | Türkmençe sözlemlerde ýalňyşlyklar | ✅ tamamlandy | 34 sözlem düzedildi (`Merv→Merw`, `oturdysdyk→oturtdyk`, `Ýygyrmy→Ýigrimi`, `náhili→nähili`, …) + awtomatik hil barlagy (`tests/test_sentence_quality.py`) |
| 8 | Flutter-iň öz ikonasy görünýär | ✅ tamamlandy | Brend ikonasy (mikrofon, teal) ähli mipmap ölçeglerinde + tegelek + adaptive (Android 8+) + monohrom; açylyş ekrany we "Programma barada" hem şol ikona. `tools/build_app_icons.py` bilen täzeden öndürilýär |
| 7 | Programma agyr açylýar | ✅ tamamlandy | Birinji kadr derrew: `runApp` bloklanmaýar, brendlenen splash (Android tarapy hem), bootstrap fonda (baza + sözlemler), tor soraglary yza sürüldi, profil keşden görkezilýär |

## Barlaglary işletmek

```bash
cd backend
DATA_DIR=/tmp/tkdata .venv/bin/python -m pytest tests -q     # 38 test
python tools/build_sentence_seed.py                          # seed-i täzeden düzmek
python ../tools/sync_seed_asset.py                           # programma nusgasyna geçirmek
```

## Ikon (8-nji ädim)

| Faýl | Maksady |
|---|---|
| `assets/branding/app_icon.png` | Çeşme ikona (1600×1600) — saýlanan mikrofonly teal surat |
| `tools/build_app_icons.py` | Mipmap-lary (48…192 px), tegelek, adaptive, monohrom we 512×512 Store nusgasyny öndürýär |
| `android/.../mipmap-anydpi-v26/ic_launcher*.xml` | Adaptive icon (Android 8+), fon reňki suratdan awtomatik (#05636A) |
| `docs/icon_before_after.png` | Öň (Flutter) ↔ indi deňeşdirme |
| `backend/tests/test_branding_assets.py` | Ölçeg/manifest/adaptive barlaglary (8 test) |

## Goşmaça goşulan zat

- `assets/sentences_seed.json` — ofline sözlem goraghanasy (programmanyň içinde).
- `tools/sync_seed_asset.py` + `backend/tests/test_seed_asset.py` — iki nusgany sinhron saklaýar.
- `backend/tests/test_sentence_quality.py` — elipbiý, uzynlyk, gaýtalanma, sorag belgisi barlaglary.
