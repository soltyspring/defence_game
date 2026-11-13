"""Extract the three 8x HUD assets from the supplied, aligned ChatGPT sheet."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/art/gpt_sources/hud_skin/bakery_knights_hud_skin_sheet.png"
OUTPUT = ROOT / "assets/art/hud_skin"
CELLS = {
    "base_health": (64, 64, 128, 20),
    "minimap": (64, 352, 96, 40),
    "speed": (896, 352, 40, 40),
}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE) as image:
        if image.size != (1536, 1024):
            raise ValueError(f"Unexpected sheet size: {image.size}")
        for name, (x, y, w, h) in CELLS.items():
            art = image.crop((x, y, x + w * 8, y + h * 8)).convert("RGBA")
            art = art.resize((w, h), Image.Resampling.NEAREST)
            pixels = list(art.getdata())
            art.putdata([(0, 0, 0, 0) if p[:3] == (255, 0, 255) else p for p in pixels])
            art.save(OUTPUT / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
