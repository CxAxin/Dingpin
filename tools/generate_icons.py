from PIL import Image
import os

# ---------------------------------------------------------------------------
# Android launcher icon generator for 顶顶 (Pinnit).
# Takes a high-resolution source with a white background (image2) and a
# pre-composed transparent version (image1), then produces:
#   - Legacy mipmap PNGs (mdpi..xxxhdpi) from the pre-composed image1.
#   - Adaptive foreground drawable (108x108 transparent, pin only) from
#     image2 by removing the white background.
# Background stays the app theme purple (#6750A4) already defined in
# drawable/ic_launcher_background.xml.
# ---------------------------------------------------------------------------

ROOT = r"C:\Users\27218\WorkBuddy\2026-07-25-20-57-33\pinnit_flutter"
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

SRC_TRANSPARENT = r"C:\Users\27218\Downloads\微信图片_20260727020341_125_41.png"
SRC_WHITE_BG = r"C:\Users\27218\Downloads\微信图片_20260727020340_124_41.png"

MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def remove_white_bg(im: Image.Image, threshold=245) -> Image.Image:
    """Return RGBA image with near-white pixels made transparent."""
    im = im.convert("RGBA")
    pixels = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 0 and r > threshold and g > threshold and b > threshold:
                pixels[x, y] = (r, g, b, 0)
    return im


def bounding_box(im: Image.Image) -> tuple:
    """Return (left, top, right, bottom) of non-transparent content."""
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    return bbox


def center_fit(src: Image.Image, canvas_size: int, margin_ratio: float = 0.18) -> Image.Image:
    """Place src content onto a transparent square canvas, keeping margin."""
    bbox = bounding_box(src)
    if not bbox:
        return Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    cropped = src.crop(bbox)
    content_size = int(canvas_size * (1 - 2 * margin_ratio))
    cropped.thumbnail((content_size, content_size), Image.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    x = (canvas_size - cropped.width) // 2
    y = (canvas_size - cropped.height) // 2
    canvas.paste(cropped, (x, y), cropped)
    return canvas


def generate_legacy(src: Image.Image, out_dir: str) -> None:
    for folder, size in MIPMAP_SIZES.items():
        path = os.path.join(out_dir, folder, "ic_launcher.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im = src.resize((size, size), Image.LANCZOS)
        im.save(path, "PNG")
        print(f"saved {path}")


def generate_adaptive_foreground(src: Image.Image, out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    fg = center_fit(src, 108, margin_ratio=0.18)
    fg.save(out_path, "PNG")
    print(f"saved {out_path}")


def generate_play_store(src: Image.Image, out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    im = src.resize((512, 512), Image.LANCZOS)
    im.save(out_path, "PNG")
    print(f"saved {out_path}")


def main():
    # image1 already has transparent background and is the final legacy look.
    legacy_src = Image.open(SRC_TRANSPARENT).convert("RGBA")
    # image2 is used to isolate the pin for adaptive foreground.
    adaptive_src = Image.open(SRC_WHITE_BG).convert("RGBA")
    adaptive_src = remove_white_bg(adaptive_src)

    generate_legacy(legacy_src, RES)
    generate_adaptive_foreground(
        adaptive_src,
        os.path.join(RES, "drawable", "ic_launcher_foreground.png"),
    )
    # The adaptive background stays as the existing color resource
    # drawable/ic_launcher_background.xml (theme purple #6750A4).
    generate_play_store(
        legacy_src,
        os.path.join(ROOT, "android", "app", "src", "main", "ic_launcher-playstore.png"),
    )


if __name__ == "__main__":
    main()
