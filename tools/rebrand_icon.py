"""
Dingpin rebrand: turn the supplied square logo (warm sand card + cartoon
line-art pushpin) into the full Android launcher-icon set.

Run:
  <python> tools/rebrand_icon.py

Outputs (into android/app/src/main/res/):
  mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
  mipmap-{...}/ic_launcher_round.png          (circle-cropped legacy)
  mipmap-anydpi-v26/ic_launcher.xml           (adaptive icon)
  mipmap-anydpi-v26/ic_launcher_round.xml
  drawable-{...}/ic_launcher_foreground.png   (transparent, pin centred+scaled)
  values/ic_launcher_background.xml           (flat warm-sand background COLOUR)
                                              -> must be res/values/, referenced as @color/...
                                                 from the adaptive XML. Putting it under
                                                 res/drawable/ makes aapt2 emit a drawable
                                                 XML that crashes AdaptiveIconDrawable and
                                                 silently falls back to the default icon.
  + master copies under tools/icon_master/
  + android/app/src/main/ic_launcher-playstore.png (512 Play Store master)

Artwork note: the pin's inner highlight/needle core is painted in the *card
colour* (≈254,231,209), i.e. it is negative space. The saturation key below
makes those pixels transparent, which is exactly right — the adaptive
background is the same card colour, so the "holes" read as the original
highlight.
"""
from __future__ import annotations

import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter

SRC = r"C:\Users\27218\.workbuddy\clipboard-images\clipboard-2026-09-30T02-19-57-537Z-18029500.jpg"
HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
RES = os.path.join(APP, "android", "app", "src", "main", "res")
MASTER = os.path.join(HERE, "icon_master")

# The source is a full-bleed 1920px card (no white rim, no visible border).
# Inset a few px so no JPEG edge ringing survives at the icon border.
CROP = (6, 6, 1914, 1914)             # 1908 x 1908

# --- adaptive icon geometry (all values in the 108dp canvas) -------------
CANVAS = 108
# Pin height as a fraction of the 108dp canvas. Only the middle 72dp of the
# canvas is actually visible once the system mask is applied, and 0.48 puts the
# pin at ~72% of the visible icon height — the usual launcher-glyph proportion.
# (0.56 => 84%, noticeably cramped; 0.40 => 60%, a bit small.)
FG_PIN_RATIO = 0.48
PIN_SAT_CUT = 100                     # saturation threshold that isolates the pin
FG_PIN_COVER = 1.0                    # keep the whole pin, needle tip included

DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE_PX = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def die(msg: str) -> None:
    print("ERROR:", msg)
    sys.exit(1)


# ------------------------------------------------------------------ card ---
def load_card() -> Image.Image:
    if not os.path.exists(SRC):
        die(f"source logo not found: {SRC}")
    im = Image.open(SRC).convert("RGB")
    card = im.crop(CROP)
    print(f"card cropped -> {card.size[0]}x{card.size[1]}")
    return card


def card_colour(card: Image.Image) -> tuple[int, int, int]:
    """Average the card's four interior corners -> the flat background tint."""
    w, h = card.size
    pts = [(30, 30), (w - 90, 30), (30, h - 90), (w - 90, h - 90)]
    vals = [card.crop((x, y, x + 60, y + 60)).resize((1, 1), Image.LANCZOS).getpixel((0, 0))
            for x, y in pts]
    px = tuple(int(round(sum(c[i] for c in vals) / len(vals))) for i in range(3))
    print("card colour sampled ->", px)
    return px


def rounded_alpha(size: int, radius_ratio: float) -> Image.Image:
    """Anti-aliased rounded-square alpha mask (supersampled 4x)."""
    ss = 4
    big = Image.new("L", (size * ss, size * ss), 0)
    d = ImageDraw.Draw(big)
    r = int(size * ss * radius_ratio)
    d.rounded_rectangle([0, 0, size * ss - 1, size * ss - 1], radius=r, fill=255)
    return big.resize((size, size), Image.LANCZOS)


def circle_alpha(size: int) -> Image.Image:
    ss = 4
    big = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(big).ellipse([0, 0, size * ss - 1, size * ss - 1], fill=255)
    return big.resize((size, size), Image.LANCZOS)


# ------------------------------------------------------------------- pin ---
def cut_pin(card: Image.Image) -> Image.Image:
    """Extract the gold pin from the ivory card.

    The card is a warm off-white (low saturation) while the pin is a saturated
    gold, so an HSV-saturation key separates them cleanly.  A high threshold is
    used because the card's own tint reaches sat~60.
    """
    import numpy as np

    rgb = card.convert("RGB")
    sat = np.array(card.convert("HSV")).astype(int)[:, :, 1]

    lo, hi = PIN_SAT_CUT, 160                       # soft ramp for anti-aliasing
    mask = np.clip((sat - lo) * (255.0 / (hi - lo)), 0, 255).astype("uint8")
    alpha = Image.fromarray(mask, "L").filter(ImageFilter.GaussianBlur(0.8))

    # keep only the largest blob so stray specks cannot enlarge the bbox
    solid = alpha.point(lambda v: 255 if v > 40 else 0)
    bbox = solid.getbbox()
    if not bbox:
        die("could not isolate the pin (no saturated pixels found)")
    print("pin bbox ->", bbox, "size", (bbox[2] - bbox[0], bbox[3] - bbox[1]))

    pin = rgb.convert("RGBA")
    pin.putalpha(alpha)
    return pin.crop(bbox)


def advance_pin(pin: Image.Image, cover: float) -> Image.Image:
    """Foreground layer crop. With cover=1.0 the whole pin is kept."""
    w, h = pin.size
    keep = max(1, int(round(h * cover)))
    return pin.crop((0, 0, w, keep))


# ------------------------------------------------------------------ build ---
def build() -> None:
    card = load_card()
    bg_rgb = card_colour(card)
    pin = cut_pin(card)
    print(f"pin source -> {pin.size[0]}x{pin.size[1]}")

    os.makedirs(MASTER, exist_ok=True)
    card.save(os.path.join(MASTER, "master_card_1024.png"))
    card.resize((1024, 1024), Image.LANCZOS).save(os.path.join(MASTER, "master_card_1024_r.png"))
    pin.save(os.path.join(MASTER, "master_pin.png"))

    for name in ("mipmap-anydpi-v26", "values"):
        os.makedirs(os.path.join(RES, name), exist_ok=True)
    # a leftover colour resource under res/drawable/ compiles into a drawable XML
    # that AdaptiveIconDrawable cannot parse -> whole icon falls back to default.
    stale = os.path.join(RES, "drawable", "ic_launcher_background.xml")
    if os.path.exists(stale):
        os.remove(stale)
        print("removed stale drawable/ic_launcher_background.xml")

    for dens, px in DENSITIES.items():
        out = os.path.join(RES, f"mipmap-{dens}")
        os.makedirs(out, exist_ok=True)
        print(f"  {dens}: legacy squared {px}x{px}")
        sq = card.resize((px, px), Image.LANCZOS)
        sq.putalpha(rounded_alpha(px, 0.175))
        sq.save(os.path.join(out, "ic_launcher.png"))

        circ = card.resize((px, px), Image.LANCZOS)
        circ.putalpha(circle_alpha(px))
        circ.save(os.path.join(out, "ic_launcher_round.png"))
        print(f"  {dens}: round {px}x{px}")

        apx = ADAPTIVE_PX[dens]
        # foreground layer only; the background is a colour resource
        ap_dir = os.path.join(RES, f"drawable-{dens}")
        os.makedirs(ap_dir, exist_ok=True)

        fg = Image.new("RGBA", (apx, apx), (0, 0, 0, 0))
        target_h = int(round(FG_PIN_RATIO * apx))
        adv = advance_pin(pin, FG_PIN_COVER)
        scale = target_h / adv.size[1]
        fw, fh = max(1, int(round(adv.size[0] * scale))), max(1, int(round(adv.size[1] * scale)))
        fg.alpha_composite(adv.resize((fw, fh), Image.LANCZOS),
                           ((apx - fw) // 2, (apx - fh) // 2))
        fg.save(os.path.join(ap_dir, "ic_launcher_foreground.png"))
        print(f"  {dens}: adaptive fg {apx}x{apx}  (pin {fw}x{fh} = {FG_PIN_RATIO:.0%} of canvas)")

    # background layer = flat colour resource. It MUST live in res/values/ so aapt2
    # compiles it into the `color` table; referenced as @color/... from the adaptive XML.
    hex_bg = "#%02X%02X%02X" % bg_rgb
    with open(os.path.join(RES, "values", "ic_launcher_background.xml"), "w", encoding="utf-8") as fh:
        fh.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            "    <!-- Brand refresh 2026-09: warm sand card (cartoon line-art pin),\n"
            "         replaced the legacy purple #6750A4. -->\n"
            f'    <color name="ic_launcher_background">{hex_bg}</color>\n'
            "</resources>\n"
        )
    print("background colour ->", hex_bg, "(res/values/)")

    # adaptive XML
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    for fname in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(RES, "mipmap-anydpi-v26", fname), "w", encoding="utf-8") as fh:
            fh.write(xml)
    print("adaptive icon xml written")

    # Play Store master: full-bleed 512 square (Play applies its own corners)
    play = os.path.join(MASTER, "play_store_512.png")
    card.resize((512, 512), Image.LANCZOS).save(play)
    print("play store 512 ->", play)

    # also refresh the copy shipped in the app module (was the legacy red pin)
    shipped = os.path.join(APP, "android", "app", "src", "main", "ic_launcher-playstore.png")
    card.resize((512, 512), Image.LANCZOS).save(shipped)
    print("play store master (app module) ->", shipped)


if __name__ == "__main__":
    build()
    print("\nDone.")
