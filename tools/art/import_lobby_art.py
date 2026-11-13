"""Crop the two supplied ChatGPT sheets; preserve the art and exclude key-color borders."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/art/gpt_sources/lobby"
OUTPUT = ROOT / "assets/art/lobby"

def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE / "lobby_cards.png") as cards:
        assert cards.size == (1536, 1024), cards.size
        for name, box in [
            ("round_select", (409, 22, 1127, 497)),
            ("upgrades", (409, 527, 1127, 1002)),
        ]:
            cards.crop(box).convert("RGB").resize((224, 148), Image.Resampling.LANCZOS).save(OUTPUT / (name + ".png"), optimize=True)
    with Image.open(SOURCE / "upgrade_training.png") as training:
        assert training.size == (2172, 724), training.size
        # Keep wall and floor proportional; the renderer anchors their seam separately.
        training.crop((0, 140, 2172, 585)).convert("RGB").resize((576, 118), Image.Resampling.LANCZOS).save(OUTPUT / "training.png", optimize=True)

if __name__ == "__main__":
    main()
