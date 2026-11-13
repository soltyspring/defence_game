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
            if name == "speed":
                # Recolor the supplied face for x2 without changing its outline or pixel grid.
                amber = {
                    (61, 43, 39): (133, 76, 25),
                    (106, 85, 77): (180, 115, 48),
                    (106, 61, 41): (150, 82, 30),
                    (132, 80, 50): (183, 105, 40),
                    (170, 102, 54): (216, 143, 56),
                }
                art.putdata([(*amber.get(p[:3], p[:3]), p[3]) for p in art.getdata()])
                art.save(OUTPUT / "speed_active.png", optimize=True)


if __name__ == "__main__":
    main()
