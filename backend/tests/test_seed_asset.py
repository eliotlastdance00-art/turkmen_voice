"""Programmanyň içindäki sözlem goraghanasy serweriň faýly bilen deň bolmaly.

`assets/sentences_seed.json` — programmanyň offline goraghanasy.
`app/seed/sentences_seed.json` — serweriň kanonik nusgasy.
Biri üýtgäp, beýlekisi ýatda galan bolsa, ulanyjylar dürli tekstleri görüp
başlar.  Şu test munuň öňüni alýar.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SERVER_SEED = ROOT / "backend" / "app" / "seed" / "sentences_seed.json"
APP_ASSET = ROOT / "assets" / "sentences_seed.json"


def test_app_asset_matches_server_seed():
    assert APP_ASSET.exists(), (
        "assets/sentences_seed.json ýok — `python tools/sync_seed_asset.py` işlediň"
    )
    server = json.loads(SERVER_SEED.read_text(encoding="utf-8"))
    app = json.loads(APP_ASSET.read_text(encoding="utf-8"))

    server_sentences = {item["id"]: item["text"] for item in server["sentences"]}
    app_sentences = {item["id"]: item["text"] for item in app["sentences"]}
    assert app_sentences == server_sentences, (
        "programmadaky sözlemler serwerdäki bilen deň däl: "
        "`python tools/sync_seed_asset.py` işlediň"
    )
    assert [item["id"] for item in app["packages"]] == [item["id"] for item in server["packages"]]
