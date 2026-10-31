"""Android adaptive-icon candidate (owner: 03-art).  python tools/art/adaptive_icon.py

Spec (developer.android.com, adaptive icons): two 108x108 dp layers; the launcher masks
the inner 72x72 dp; content inside the central 66 dp-diameter circle is never clipped.
We render at xxxhdpi (1 dp = 4 px) -> 432x432 px layers. The foreground reuses the 48 px
icon foreground art (tools/art/branding.py) at 5 px per art pixel (1.25 dp), centred.

Outputs (candidates, NOT wired into export presets; real-launcher result untested):
  docs/art/branding/adaptive/ic_launcher_foreground_432.png  (transparent)
  docs/art/branding/adaptive/ic_launcher_background_432.png  (opaque)
  docs/art/branding/adaptive/mask_previews.png  circle / squircle / teardrop at 72 dp
  docs/art/evidence/branding/adaptive_metrics.json
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import branding  # noqa: E402
from pixel import RGBA, IDX  # noqa: E402

DP = 4                      # xxxhdpi
CANVAS = 108 * DP           # 432
VISIBLE = 72 * DP           # 288
SAFE_R = 33 * DP            # 66 dp diameter
ART_PX = 5                  # device px per art pixel (1.25 dp)


def foreground_art():
    full = branding.icon48()
    bg = branding.icon48(background_only=True)
    fg = np.where((full.a != bg.a) | (bg.a == 0), full.a, 0).astype(np.uint8)
    fg[bg.a == IDX["w"]] = np.where(full.a[bg.a == IDX["w"]] == IDX["w"], 0, full.a[bg.a == IDX["w"]])
    ys, xs = np.nonzero(fg)
    return fg[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def layers():
    art = foreground_art()
    big = np.kron(art, np.ones((ART_PX, ART_PX), np.uint8))
    fg = np.zeros((CANVAS, CANVAS), np.uint8)
    h, w = big.shape
    y0, x0 = (CANVAS - h) // 2, (CANVAS - w) // 2
    fg[y0:y0 + h, x0:x0 + w] = big
    # background: same warm ramp + diagonal stripes as the 48 px icon, full bleed
    bg = np.zeros((CANVAS, CANVAS), np.uint8)
    for y in range(CANVAS):
        t = y / CANVAS
        k = "o" if t < 0.33 else "O" if t < 0.7 else "w"
        bg[y, :] = IDX[k]
    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS]
    stripe = (((xx - yy) // (4 * ART_PX)) % 3 == 0) & (yy < CANVAS * 0.62)
    bg[stripe & (yy < CANVAS * 0.33)] = IDX["T"]
    bg[stripe & (yy >= CANVAS * 0.33)] = IDX["o"]
    return fg, bg


def masks():
    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS] + 0.5
    c = CANVAS / 2
    r = VISIBLE / 2
    dx, dy = (xx - c) / r, (yy - c) / r
    circle = dx * dx + dy * dy <= 1.0
    squircle = np.abs(dx) ** 4 + np.abs(dy) ** 4 <= 1.0           # superellipse n=4
    # teardrop: circle with the lower-right quadrant replaced by a rounded-square corner
    tear = circle | ((dx >= 0) & (dy >= 0) & (np.abs(dx) <= 1) & (np.abs(dy) <= 1)
                     & ((np.maximum(dx, dy) <= 1.0)))
    return {"circle": circle, "squircle": squircle, "teardrop": tear}


def main():
    out = os.path.join(ROOT, "docs", "art", "branding", "adaptive")
    os.makedirs(out, exist_ok=True)
    fg, bg = layers()
    Image.fromarray(RGBA[fg], "RGBA").save(os.path.join(out, "ic_launcher_foreground_432.png"))
    Image.fromarray(RGBA[bg], "RGBA").save(os.path.join(out, "ic_launcher_background_432.png"))
    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS] + 0.5
    safe = (xx - CANVAS / 2) ** 2 + (yy - CANVAS / 2) ** 2 <= SAFE_R ** 2
    opaque = fg > 0
    met = {"canvas_px": CANVAS, "dp_px": DP, "art_px_per_pixel": ART_PX,
           "fg_opaque_px": int(opaque.sum()),
           "fg_outside_safe_circle_px": int((opaque & ~safe).sum()),
           "bg_transparent_px": int((bg == 0).sum()), "masks": {}}
    comp = RGBA[bg].copy()
    a = RGBA[fg][..., 3:4] / 255.0
    comp[..., :3] = (RGBA[fg][..., :3] * a + comp[..., :3] * (1 - a)).astype(np.uint8)
    tiles = []
    for name, m in masks().items():
        met["masks"][name] = {"fg_clipped_px": int((opaque & ~m).sum())}
        t = np.zeros_like(comp)
        t[..., :3] = 40, 44, 58
        t[..., 3] = 255
        t[m] = comp[m]
        lo, hi = (CANVAS - VISIBLE) // 2, (CANVAS + VISIBLE) // 2
        tiles.append(t[lo:hi, lo:hi])
    for s in (48, 96, 192):        # legacy-size check of the circle mask (box-downscaled)
        im = Image.fromarray(tiles[0]).resize((s, s), Image.BOX)
        im.save(os.path.join(out, f"preview_circle_{s}.png"))
    sheet = np.concatenate([np.pad(t, ((8, 8), (8, 8), (0, 0)), constant_values=0) for t in tiles], axis=1)
    sheet[..., 3] = 255
    Image.fromarray(sheet).save(os.path.join(out, "mask_previews.png"))
    ev = os.path.join(ROOT, "docs", "art", "evidence", "branding")
    os.makedirs(ev, exist_ok=True)
    json.dump(met, open(os.path.join(ev, "adaptive_metrics.json"), "w", encoding="utf-8"), indent=1)
    print(json.dumps(met, indent=1))


if __name__ == "__main__":
    main()
