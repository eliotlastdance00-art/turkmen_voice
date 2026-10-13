# Türkmen Ses Backend Architecture

## Gatlaklar

```text
routers       HTTP transport, validation, response models
schemas       Pydantic API contracts (mobile app bilen şertnama)
services      Use-case/business rules (audio, rating, user, dataset, stats)
repositories  Persistence (SQLite)
domain        Entities + repository protocols (framework-syz)
db            SQLite schema, migrasiýa, seed
core          Config (env-driven) we security
```

## Baglylyk ugry

```text
router -> service -> domain repository protocol
                     ^
                     |
              sqlite repository
```

## Esasy kararlar

1. **Ses konweýeri**: her ýükleme 16 kHz mono PCM16 WAV görnüşine getirilýär.
   Köne APK header-siz pcm16 ýazýardy — `audio_service.normalize_audio()` muny
   hem kabul edip, dogry RIFF header goşýar. Durasiýa, sha256 we ses derejesi
   serwerde ölçelýär (müşderiniň berýän `duration_ms`-ine ynanmaýarys).
2. **Idempotent ýükleme**: `recording_id` boýunça gaýtalanma saklanmaýar —
   offline nobat tora gaýdanda goşa ýazgy döretmeýär.
3. **Jemgyýetçilik reýtingi**: 3+ baha we orta baha ≥ 4.0 bolsa ýazgy awtomatik
   tassyklanýar; 3 şikaýat bolsa ret edilýär. Bu adam güýjüni azaldýar.
4. **Diňe `approved` eksport edilýär** — model tassiklanmadyk ýazgyny görmez.
5. **Migrasiýa**: SQLite `PRAGMA user_version` + sütün barlagy (köne bazalar
   üçin `ALTER TABLE`), şeýle hem `seed_library()` idempotent.

## Täze endpoint goşmak tertibi

1. `domain/entities` — entity (gerek bolsa).
2. `domain/repositories` — Protocol.
3. `schemas` — request/response.
4. `repositories` — SQLite implementasiýa.
5. `services` — use-case.
6. `routers` — HTTP endpoint (`Depends` bilen).
7. `api_dependencies.py` — wiring.
8. `tests/test_api_contract.py` — app-niň ulanjak ýoluny test et.
