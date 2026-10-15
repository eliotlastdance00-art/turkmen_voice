#!/usr/bin/env python3
"""Brend ikonasyndan Android launcher ikonlaryny öndürýär.

Çeşme:  ``assets/branding/app_icon.png`` (1024+ px, kwadrat, doly doldurylan)
Çykyş:  ``android/app/src/main/res/…`` — her dykyzlyk üçin

* ``ic_launcher.png``            — köne (pre-26) enjamlar üçin kwadrat ikon
* ``ic_launcher_round.png``      — köne enjamlar üçin tegelek ikon
* ``ic_launcher_foreground.png`` — adaptive icon (Android 8+) öňki gatlagy
* ``mipmap-anydpi-v26/*.xml``    — adaptive icon beýany
* ``assets/branding/app_icon_512.png`` — Play Store üçin

Işletmek (Pillow gerek):

    python -m pip install pillow
    python tools/build_app_icons.py
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("Pillow gerek: python -m pip install pillow", file=sys.stderr)
    raise SystemExit(1)

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "app_icon.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
BRAND_COLOR = "#0B6E69"

# (papka, ölçeg koeffisiýenti) — launcher ikon 48dp × koeffisiýent
SCALES: tuple[tuple[str, float], ...] = (
    ("mdpi", 1.0),
    ("hdpi", 1.5),
    ("xhdpi", 2.0),
    ("xxhdpi", 3.0),
    ("xxxhdpi", 4.0),
)

# Adaptive icon: 108dp kanwa, görünýän ýer 72dp, howpsuz zolak 66dp.
SAFE_LOGO_RATIO = 0.60  # logotip kanwanyň 60%-i (howpsuz zolagyň içinde)
FOREGROUND_DP = 108


def load_source() -> Image.Image:
    if not SOURCE.exists():
        raise SystemExit(f"çeşme ikona ýok: {SOURCE}")
    image = Image.open(SOURCE).convert("RGBA")
    if image.width != image.height:
        raise SystemExit("çeşme ikona kwadrat bolmaly")
    return image


def white_on_transparent(source: Image.Image) -> Image.Image:
    """Ak çyzgylary teal fondan aýryp, aç-açan gatlak döredýär.

    Adaptive icon-yň öňki gatlagy diňe çyzgyny saklamaly — fon aýratyn
    (``ic_launcher_background``) berilýär. Aç-açanlyk aýdynlyk boýunça
    hasaplanýar: fon (teal) → 0, çyzgy (ak) → 1, gyralar ýarym aç-açan.
    """
    pixels = source.convert("RGB").load()
    size = source.size
    foreground = Image.new("RGBA", size, (255, 255, 255, 0))
    target = foreground.load()

    background_luma = 80.0  # #0B6E69 aýdynlygy
    white_luma = 255.0
    for y in range(size[1]):
        for x in range(size[0]):
            red, green, blue = pixels[x, y]
            luma = 0.299 * red + 0.587 * green + 0.114 * blue
            alpha = (luma - background_luma) / (white_luma - background_luma)
            alpha = 0.0 if alpha < 0 else 1.0 if alpha > 1 else alpha
            if alpha > 0.004:
                target[x, y] = (255, 255, 255, int(round(alpha * 255)))
    return foreground


def square(source: Image.Image, size: int) -> Image.Image:
    return source.resize((size, size), Image.LANCZOS)


def circle(source: Image.Image, size: int) -> Image.Image:
    base = source.resize((size, size), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    base.putalpha(mask.resize((size, size), Image.LANCZOS))
    return base


def adaptive_foreground(source: Image.Image, canvas: int) -> Image.Image:
    """Logotipi 60% ölçegde merkeze goýýar (howpsuz zolak)."""
    art = white_on_transparent(source)
    logo_size = max(1, int(canvas * SAFE_LOGO_RATIO))
    art = art.resize((logo_size, logo_size), Image.LANCZOS)
    layer = Image.new("RGBA", (canvas, canvas), (255, 255, 255, 0))
    offset = ((canvas - logo_size) // 2, (canvas - logo_size) // 2)
    layer.paste(art, offset, art)
    return layer


def adaptive_background_color(source: Image.Image) -> str:
    """Çyzgynyň fon reňkini çeşme suratyň gyralaryndan alyp, #RRGGBB görnüşinde.

    Adaptive icon-yň fony şu reňk bolmaly — ýogsam tegelek maskada suratyň
    fony bilen aýrylyp, göze ilýän gyra emele gelýär.
    """
    size = source.size
    samples: list[tuple[int, int, int]] = []
    step = max(1, size[0] // 64)
    for x in range(0, size[0], step):
        samples.append(source.getpixel((x, 2))[:3])
        samples.append(source.getpixel((x, size[1] - 3))[:3])
    for y in range(0, size[1], step):
        samples.append(source.getpixel((2, y))[:3])
        samples.append(source.getpixel((size[0] - 3, y))[:3])
    if not samples:
        return BRAND_COLOR
    red = sorted(item[0] for item in samples)[len(samples) // 2]
    green = sorted(item[1] for item in samples)[len(samples) // 2]
    blue = sorted(item[2] for item in samples)[len(samples) // 2]
    return f"#{red:02X}{green:02X}{blue:02X}"


ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Adaptive icon (Android 8+): fon + öňki gatlak.
     Dörediji: tools/build_app_icons.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

BACKGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Adaptive icon fony: brend ikonasynyň fon reňki (awtomatik alynýar).
         Dörediji: tools/build_app_icons.py -->
    <color name="ic_launcher_background">%s</color>
</resources>
"""


def main() -> int:
    source = load_source()
    written: list[Path] = []

    for folder, scale in SCALES:
        size = int(48 * scale)
        directory = RES / f"mipmap-{folder}"
        directory.mkdir(parents=True, exist_ok=True)

        square(source, size).save(directory / "ic_launcher.png")
        circle(source, size).save(directory / "ic_launcher_round.png")
        adaptive_foreground(source, int(FOREGROUND_DP * scale)).save(
            directory / "ic_launcher_foreground.png"
        )
        written += [
            directory / "ic_launcher.png",
            directory / "ic_launcher_round.png",
            directory / "ic_launcher_foreground.png",
        ]

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(ADAPTIVE_XML, encoding="utf-8")
    written += [anydpi / "ic_launcher.xml", anydpi / "ic_launcher_round.xml"]

    background_color = adaptive_background_color(source)
    values = RES / "values" / "ic_launcher_background.xml"
    values.write_text(BACKGROUND_XML % background_color, encoding="utf-8")
    written.append(values)

    store = ROOT / "assets" / "branding" / "app_icon_512.png"
    square(source, 512).save(store)
    written.append(store)

    for path in written:
        print(f"  {path.relative_to(ROOT)}")
    print(f"{len(written)} faýl ýazyldy (çeşme: {SOURCE.relative_to(ROOT)}, fon {background_color})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
