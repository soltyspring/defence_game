"""Menu background from the image-model picture (docs/art/release_slice/menu_regen/source/menu_bg.webp, 1536x1024):
4x4 box-reduced to 384x256 logical pixels and fixed to 64 colours (median cut refined by k-means, so the red roof and teal spores keep their colour), no dither.
  python tools/art/release_slice/menu_bg.py   -> assets/backgrounds/menu_bg.png
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "docs/art/release_slice/menu_regen/source/menu_bg.webp"
OUT = ROOT / "assets/backgrounds/menu_bg.png"

if __name__ == "__main__":
    im = Image.open(SRC).convert("RGB")
    small = im.resize((im.width // 4, im.height // 4), Image.BOX)
    small.quantize(64, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE).convert("RGB").save(OUT)
