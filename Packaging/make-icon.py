#!/usr/bin/env python3
"""Draw the app icon and write the macOS icon set (needs Pillow and the
Noto Color Emoji font). The PNGs are committed, so a Mac build needs neither.
Run from the repo root: python3 Packaging/make-icon.py"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

EMOJI = "🌍"
TOP = (120, 200, 255)
BOTTOM = (30, 110, 200)
OUT = Path(__file__).resolve().parent / "Assets.xcassets" / "AppIcon.appiconset"
EMOJI_FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"

def draw(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        t = y / (size - 1)
        gd.line([(0, y), (size, y)], fill=tuple(int(TOP[i] * (1 - t) + BOTTOM[i] * t) for i in range(3)) + (255,))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([100, 100, 924, 924], radius=185, fill=255)
    img.paste(grad, (0, 0), mask)
    font = ImageFont.truetype(EMOJI_FONT, 109)
    glyph = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(glyph).text((80, 80), EMOJI, font=font, embedded_color=True, anchor="mm")
    glyph = glyph.crop(glyph.getbbox()).resize((560, 560), Image.LANCZOS) if glyph.getbbox() else glyph
    img.alpha_composite(glyph, ((size - glyph.width) // 2, (size - glyph.height) // 2 + 10))
    return img

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    base = draw()
    images = []
    for pts in [16, 32, 128, 256, 512]:
        for scale in [1, 2]:
            px = pts * scale
            name = f"icon_{pts}x{pts}{'@2x' if scale == 2 else ''}.png"
            base.resize((px, px), Image.LANCZOS).save(OUT / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pts}x{pts}"})
    (OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    (OUT.parent / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

if __name__ == "__main__":
    main()
