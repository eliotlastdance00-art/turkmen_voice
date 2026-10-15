"""Brend ikonlarynyň barlagy (Android launcher).

Flutter-iň öz ikonasy (`ic_launcher`) APK-nyň içinde galmasyn diýip, şu testler
ähli dykyzlygyň, tegelek ikonyň, adaptive icon beýanynyň we manifestiň
baglanyşygyny barlaýar.  Goşmaça gural gerek däl — PNG ýazgysy şu ýerde
okulýar (Pillow talap edilmeýär).

Ikonlary täzelemek:

    python tools/build_app_icons.py
"""

from __future__ import annotations

import re
import struct
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
MANIFEST = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
PUBSPEC = ROOT / "pubspec.yaml"

# (launcher ikon: 48dp, adaptive foreground: 108dp) × dykyzlyk
DENSITIES: dict[str, tuple[int, int]] = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def png_size(path: Path) -> tuple[int, int, int]:
    """PNG-dan (width, height, color_type) — IHDR bölegi."""
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path.name}: PNG däl"
    assert data[12:16] == b"IHDR", f"{path.name}: IHDR tapylmady"
    width, height, _depth, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, color_type


@pytest.mark.parametrize("density", sorted(DENSITIES))
def test_launcher_icons_have_the_right_size(density: str):
    icon_size, foreground_size = DENSITIES[density]
    square = RES / f"mipmap-{density}" / "ic_launcher.png"
    round_icon = RES / f"mipmap-{density}" / "ic_launcher_round.png"
    foreground = RES / f"mipmap-{density}" / "ic_launcher_foreground.png"

    for path, expected in ((square, icon_size), (round_icon, icon_size), (foreground, foreground_size)):
        assert path.exists(), f"{path} ýok — `python tools/build_app_icons.py` işlediň"
        width, height, color_type = png_size(path)
        assert (width, height) == (expected, expected), f"{path.name}: {width}×{height}, {expected} garaşylýar"
        assert color_type in (2, 6), f"{path.name}: reňk görnüşi aýdyňlyk/aç-açanlyk bolmaly"

    # adaptive icon-yň öňki gatlagy aç-açan fonly bolmaly (RGBA)
    assert png_size(foreground)[2] == 6, f"{foreground.name}: RGBA bolmaly"


def test_adaptive_icon_is_declared_for_android_8_plus():
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        path = RES / "mipmap-anydpi-v26" / name
        assert path.exists(), f"{path} ýok"
        content = path.read_text(encoding="utf-8")
        assert "<adaptive-icon" in content
        assert '@color/ic_launcher_background' in content
        assert '@mipmap/ic_launcher_foreground' in content

    background = (RES / "values" / "ic_launcher_background.xml").read_text(encoding="utf-8")
    match = re.search(r'<color name="ic_launcher_background">(#[0-9A-Fa-f]{6})</color>', background)
    assert match, "ic_launcher_background reňki ýok"


def test_manifest_points_to_the_brand_icons():
    manifest = MANIFEST.read_text(encoding="utf-8")
    assert 'android:icon="@mipmap/ic_launcher"' in manifest
    assert 'android:roundIcon="@mipmap/ic_launcher_round"' in manifest
    assert 'android:label="Türkmen Ses"' in manifest


def test_store_icon_exists_and_is_bundled():
    store = ROOT / "assets" / "branding" / "app_icon_512.png"
    assert store.exists(), "assets/branding/app_icon_512.png ýok"
    width, height, _ = png_size(store)
    assert (width, height) == (512, 512)
    assert "assets/branding/app_icon_512.png" in PUBSPEC.read_text(encoding="utf-8")

    source = ROOT / "assets" / "branding" / "app_icon.png"
    assert source.exists(), "çeşme ikonasy (app_icon.png) ýok — täzeden öndürip bolmaz"
    assert png_size(source)[0] >= 1024, "çeşme ikona iň az 1024 px bolmaly"
