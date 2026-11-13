"""R01-R40 chapter tiles without the stretched side bands.

The 69f6fc3 tiles (meadow, orchard, frost, nest) were exported by widening each 3:1 picture with its outer 4 % columns
stretched over ~27 % of the tile on each side: long smeared streaks that the faster scenery (0.55) now shows often.
This keeps only the real picture in the middle and joins its two ends with the same least-difference seam as
bg_tiles.py, so the tile repeats without flips and without streaks. It is narrower (about 440 logical px instead of
1024) and repeats more often. The bottom 36 quiet rows stay (TRIM_GROUND_ROWS 20 for these chapters).
Reads the 69f6fc3 versions from git, so it can be rerun.
  python tools/art/release_slice/early_tiles.py
"""
import io
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
DIR = "assets/backgrounds/chapter_tile_layers/"
BASE = "69f6fc3"
NAMES = ["meadow", "orchard", "frost", "nest"]
LAP = 32
STREAK = 0.85      # share of rows equal to the next column: above this the column is a stretched copy
## The cave's smeared band is a soft gradient, not equal columns: its picture start is set by eye.
SPAN_OVERRIDE = {"nest": (262, None)}


def original(name: str) -> np.ndarray:
    raw = subprocess.run(["git", "show", f"{BASE}:{DIR}{name}.png"], cwd=ROOT, capture_output=True, check=True).stdout
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB"))[::4, ::4].astype(np.int32)


def content_span(a: np.ndarray) -> tuple:
    scenery = a[:140]
    eq = (np.abs(scenery[:, 1:] - scenery[:, :-1]).sum(axis=2) == 0).mean(axis=0)
    smooth = np.convolve(eq, np.ones(16) / 16, "same")
    real = np.where(smooth < STREAK)[0]
    real = real[(real > 16) & (real < a.shape[1] - 16)]
    return int(real.min()) + 4, int(real.max()) - 4


def seam(left: np.ndarray, right: np.ndarray) -> np.ndarray:
    cost = np.abs(left - right).sum(axis=2).astype(np.float64)
    acc = cost.copy()
    for y in range(1, acc.shape[0]):
        prev = acc[y - 1]
        acc[y] += np.minimum(prev, np.minimum(np.r_[prev[1:], np.inf], np.r_[np.inf, prev[:-1]]))
    cut = np.zeros(acc.shape[0], int)
    cut[-1] = int(np.argmin(acc[-1]))
    for y in range(acc.shape[0] - 2, -1, -1):
        x = cut[y + 1]
        lo, hi = max(0, x - 1), min(acc.shape[1], x + 2)
        cut[y] = lo + int(np.argmin(acc[y, lo:hi]))
    return cut


def tile(name: str) -> Image.Image:
    a = original(name)
    l, r = content_span(a)
    o = SPAN_OVERRIDE.get(name, (None, None))
    l, r = o[0] if o[0] is not None else l, o[1] if o[1] is not None else r
    body = a[:, l:r]
    w = body.shape[1] - LAP
    out = body[:, :w].copy()
    cut = seam(body[:, w:], body[:, :LAP])         # the picture's right end flowing into its left end
    for y in range(out.shape[0]):
        out[y, :LAP] = np.concatenate([body[y, w:w + cut[y]], body[y, cut[y]:LAP]])
    w4 = w - w % 4 if w % 4 else w
    print(f"{name}: real picture {l}..{r}, tile width {w4}")
    return Image.fromarray(out[:, :w4].astype(np.uint8))


def main() -> None:
    for name in NAMES:
        t = tile(name)
        t.resize((t.width * 4, t.height * 4), Image.NEAREST).save(ROOT / DIR / f"{name}.png")


if __name__ == "__main__":
    main()
