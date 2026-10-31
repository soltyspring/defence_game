"""Biome framing metrics (owner: 03-art, art 0.11.0, QA-J1 / 09 X10).

    python tools/art/biome_check.py [out_dir]

Composes the shipped biome_01 layers and the old meadow layers exactly like
biome.compose_preview (02's draw order, 640x360 reference view, cam 0, ground_y 295
as in readability.py) and measures, for each:
  sky_pct          share of view pixels where only the sky strip (sky / clouds) is visible
  head_band_L35    share of pixels with L* >= 35 in the band behind unit heads (y 255..289)
  lane_band_L35    share of pixels with L* >= 35 in the lane band (y 284..297)
  sky_rows         rows (top-down) whose pixels are >= 90 % sky
Lines (ART_AUDIT dark-biome rule, fixed before measuring): head/lane band L* >= 35 on >= 90 % of pixels.
sky_pct target for QA-J1 (03 internal): <= 35 % at the 640x360 reference view.
Writes biome_metrics.json and side-by-side previews (1x and 2x).
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

import biome  # noqa: E402
import theme  # noqa: E402
from pixel import RGBA  # noqa: E402
from readability import lab_L  # noqa: E402

GY = 295
HEAD = (255, 290)
LANE = (284, 298)


def layers(kind):
    ls = biome.build_meadow(biome.MEADOW if kind == "meadow" else biome.VILLAGE)
    for name, cv, meta in ls:
        if name == "front":
            theme.remap_keys(cv, theme.WHEAT_FRONT)
    return ls


def sky_mask(ls, width=640):
    """True where no non-sky layer covers the pixel (sky strip or the clear colour shows).
    Clouds (J/j pixels of the far layer; the far hills and houses never use J/j) count as sky."""
    cover = np.zeros((360, width), bool)
    for name, cv, meta in ls:
        if name == "sky":
            continue
        a = cv.a > 0
        if name == "far":
            a &= ~np.isin(cv.a, [biome.c("J"), biome.c("j")])
        y0 = meta["view_y"]
        h = min(360, y0 + cv.h) - y0
        for x in range(0, width, cv.w):
            w = min(width, x + cv.w) - x
            cover[y0:y0 + h, x:x + w] |= a[:h, :w]
    return ~cover


def measure(kind):
    ls = layers(kind)
    img = np.array(biome.compose_preview(ls, 640, cam=0).convert("RGB")).astype(float)
    L = lab_L(img)
    sky = sky_mask(ls)
    head = L[HEAD[0]:HEAD[1]]
    lane = L[LANE[0]:LANE[1]]
    rows = int(np.argmax(sky.mean(1) < 0.9))
    return img, {"sky_pct": round(float(sky.mean() * 100), 1), "sky_rows_top": rows,
                 "head_band_L35_pct": round(float((head >= 35).mean() * 100), 1),
                 "head_band_L_min": round(float(head.min()), 1),
                 "lane_band_L35_pct": round(float((lane >= 35).mean() * 100), 1),
                 "lane_band_L_min": round(float(lane.min()), 1)}


def main(out):
    os.makedirs(out, exist_ok=True)
    rep, imgs = {"ground_y": GY, "head_band_y": HEAD, "lane_band_y": LANE,
                 "lines": {"band_L35_pct_min": 90.0, "sky_pct_max": 35.0}}, []
    for kind in ("meadow", "village"):
        img, m = measure(kind)
        rep[kind] = m
        imgs.append(Image.fromarray(np.rint(img).astype(np.uint8)))
    v = rep["village"]
    rep["pass"] = {"sky": v["sky_pct"] <= 35.0, "head_band": v["head_band_L35_pct"] >= 90.0,
                   "lane_band": v["lane_band_L35_pct"] >= 90.0}
    sheet = Image.new("RGB", (640, 720 + 4), (0, 0, 0))
    sheet.paste(imgs[0], (0, 0)); sheet.paste(imgs[1], (0, 364))
    sheet.save(os.path.join(out, "biome_meadow_vs_village_1x.png"))
    imgs[1].resize((1280, 720), Image.NEAREST).save(os.path.join(out, "biome_village_2x.png"))
    with open(os.path.join(out, "biome_metrics.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1)
        f.write("\n")
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "art", "evidence", "biome_village"))
