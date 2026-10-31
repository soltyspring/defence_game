"""Biome framing metrics (owner: 09-art-world since 2026-11-01; written by 03-art for art 0.11.0, QA-J1 / 09 X10).

    python tools/art/biome_check.py [out_dir]

Composes three versions of biome_01 exactly like biome.compose_preview (02's draw order, 640x360 reference view,
cam 0, ground_y 295 as in readability.py): `meadow` (art <= 0.10), `village_v1` (art 0.11-0.13) and `village`
(what build.py ships now, biome.BIOME_01). For each:
  sky_pct          share of view pixels where only the sky strip (sky / clouds) is visible
  head_band_L35    share of pixels with L* >= 35 in the band behind unit heads (y 255..289)
  lane_band_L35    share of pixels with L* >= 35 in the lane band (y 284..297)
  sky_rows         rows (top-down) whose pixels are >= 90 % sky
Lines: sky_pct <= 35 % (03, QA-J1). The old dark-biome line "head/lane band L* >= 35 on >= 90 %" is printed for
comparison only: art-world 1 puts the street level in warm shadow on purpose and replaces that line with direct
ring-contrast lines for both factions (docs/art/world/WORLD_AUDIT.md P1/P2, tools/art/world/world_metrics.py).
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
KINDS = {"meadow": biome.MEADOW, "village_v1": biome.VILLAGE, "village": biome.BIOME_01}


def layers(kind):
    ls = biome.build_meadow(KINDS[kind])
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
                 "lines": {"sky_pct_max": 35.0, "band_L35_pct_min_info_only": 90.0}}, []
    for kind in KINDS:
        img, m = measure(kind)
        rep[kind] = m
        imgs.append(Image.fromarray(np.rint(img).astype(np.uint8)))
    v = rep["village"]
    rep["pass"] = {"sky": v["sky_pct"] <= 35.0}
    rep["info_old_dark_biome_line"] = {"head_band": v["head_band_L35_pct"] >= 90.0, "lane_band": v["lane_band_L35_pct"] >= 90.0}
    sheet = Image.new("RGB", (640, 360 * 3 + 8), (0, 0, 0))
    for i, im in enumerate(imgs):
        sheet.paste(im, (0, i * 364))
    sheet.save(os.path.join(out, "biome_meadow_v1_v2_1x.png"))
    imgs[-1].resize((1280, 720), Image.NEAREST).save(os.path.join(out, "biome_village_2x.png"))
    with open(os.path.join(out, "biome_metrics.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1)
        f.write("\n")
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "art", "world", "evidence", "biome_check"))
