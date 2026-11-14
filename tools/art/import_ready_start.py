"""Battle start signal art (READY / GO! / flour burst) from the supplied ChatGPT sheet.

Input: docs/art/gpt_sources/ready_start/ready_start.png, 1536x1024 on flat magenta, drawn in ~8x8 pixel blocks
(docs/art/release_slice/ready_start_regen/PROMPTS.md). Only the English words are used, in every language
(2026-11-15 user); the Korean row of the sheet stays unused.
Each item is keyed, reduced 8x with a premultiplied box filter, cut to hard alpha and reduced to at most 16 colours.
Output: assets/art/ui/ready_start/{ready,go,burst}.png
  python tools/art/import_ready_start.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs/art/gpt_sources/ready_start/ready_start.png"
OUT = ROOT / "assets/art/ui/ready_start"
SCALE = 8
# search regions (cells of the 2x3 sheet); the art's own bounds inside each are found from the key
ITEMS = {"ready": (0, 341, 768, 682), "go": (768, 341, 1536, 682), "burst": (0, 682, 768, 1024)}


def key(rgb: np.ndarray) -> np.ndarray:
    """Alpha 0..1: magenta and its anti-aliased fringe become transparent."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = np.minimum(r, b) - g
    return np.clip((170.0 - magenta) / 90.0, 0.0, 1.0)


def item(sheet: np.ndarray, box) -> Image.Image:
    x0, y0, x1, y1 = box
    cell = sheet[y0:y1, x0:x1]
    a = key(cell)
    ys, xs = np.nonzero(a > 0.5)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # pad to whole blocks around the art
    h = int(np.ceil((b - t) / SCALE)) * SCALE + 2 * SCALE
    w = int(np.ceil((r - l) / SCALE)) * SCALE + 2 * SCALE
    cy, cx = (t + b) // 2, (l + r) // 2
    sub = np.zeros((h, w, 3)); sa = np.zeros((h, w))
    sy0, sx0 = cy - h // 2, cx - w // 2
    for yy in range(h):
        sy = sy0 + yy
        if 0 <= sy < cell.shape[0]:
            lo, hi = max(0, sx0), min(cell.shape[1], sx0 + w)
            sub[yy, lo - sx0:hi - sx0] = cell[sy, lo:hi]
            sa[yy, lo - sx0:hi - sx0] = a[sy, lo:hi]
    pre = sub * sa[..., None]
    nh, nw = h // SCALE, w // SCALE
    pre = pre.reshape(nh, SCALE, nw, SCALE, 3).mean(axis=(1, 3))
    al = sa.reshape(nh, SCALE, nw, SCALE).mean(axis=(1, 3))
    rgb = np.where(al[..., None] > 0, pre / np.maximum(al[..., None], 1e-6), 0)
    on = al >= 0.5
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    q = img.quantize(colors=16, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = np.dstack([np.asarray(q), np.where(on, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def main():
    sheet = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
    assert sheet.shape[:2] == (1024, 1536), sheet.shape
    OUT.mkdir(parents=True, exist_ok=True)
    for name, box in ITEMS.items():
        im = item(sheet, box)
        im.save(OUT / (name + ".png"), optimize=True)
        print(name, im.size)


if __name__ == "__main__":
    main()
