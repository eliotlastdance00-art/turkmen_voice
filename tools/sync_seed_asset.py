#!/usr/bin/env python3
"""Sözlem goraghanasyny programma tarapa göçürýär.

Çeşme:  backend/app/seed/sentences_seed.json   (serweriň kanonik faýly)
Nusga:  assets/sentences_seed.json             (programmanyň içindäki goraghana)

Programma internet ýok wagty hem tekst tapýar, şonuň üçin ikisi birmeňzeş
bolmaly.  Munuň barlagy `backend/tests/test_seed_asset.py` -de awtomatik
edilýär (testler şu faýly sinhron saklaýar).

    python tools/sync_seed_asset.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "backend" / "app" / "seed" / "sentences_seed.json"
TARGET = ROOT / "assets" / "sentences_seed.json"


def main() -> int:
    payload = json.loads(SOURCE.read_text(encoding="utf-8"))
    if not payload.get("sentences"):
        print("seed faýlynda sözlem ýok", file=sys.stderr)
        return 1

    # Tertipli, yzygiderli JSON — git diff arassa bolsun.
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if TARGET.exists() and TARGET.read_text(encoding="utf-8") == text:
        print(f"{TARGET.relative_to(ROOT)} eýýäm sinhron")
        return 0

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text, encoding="utf-8")
    print(
        f"{TARGET.relative_to(ROOT)} täzelendi: "
        f"{len(payload['sentences'])} sözlem / {len(payload.get('packages', []))} paket"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
