"""Analyse Godot font renders (owner: 03-art): per device, crop 1:1 device pixels of each
row and measure 'pixel regularity' = whether every font pixel became an equal-size square.

    python tools/art/font_contact.py docs/art/evidence/fonts

For a pixel font rendered at k x native size on an integer device scale s, every source
pixel should become a solid (k*s) x (k*s) block. Non-integer scales / non-native sizes
produce mixed run lengths -> uneven stems (visible as shimmer/blur when moving).
Metric: distribution of horizontal run lengths of text pixels; 'irregular' = fraction of
runs whose length is not a multiple of the expected block size.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw


def runs(mask_row):
    out = []
    n = 0
    for v in mask_row:
        if v:
            n += 1
        elif n:
            out.append(n)
            n = 0
    if n:
        out.append(n)
    return out


def analyse(path, rep_dev, rows_spec):
    im = np.array(Image.open(path).convert("RGB")).astype(int)
    bg = np.array([31, 47, 107])
    text = (np.abs(im - bg).sum(axis=2) > 60)
    scale = rep_dev["scale"]
    res = []
    y = 4.0
    for (font, px) in rows_spec:
        y0 = int(round(y * scale))
        y1 = int(round((y + px + 2) * scale))
        band = text[y0:y1]
        rl = []
        for r in band:
            rl += runs(r)
        rl = np.array(rl) if rl else np.array([1])
        native = {"Galmuri11.ttf": 12, "Galmuri11-Bold.ttf": 12, "Galmuri9.ttf": 10}[font]
        block = px / native * scale        # expected device px per font pixel
        if abs(block - round(block)) < 1e-6:
            irregular = float(np.mean(rl % round(block) != 0))
        else:
            irregular = 1.0                # non-integer block: equal squares impossible
        uniq = sorted(set(int(v) for v in rl))[:8]
        res.append({"font": font, "px": px, "device_block": round(block, 3), "irregular_runs": round(irregular, 3),
                    "run_lengths_sample": uniq, "band": [y0, y1]})
        y += px + 3
    return res


def main(d):
    rep = json.load(open(os.path.join(d, "font_report.json"), encoding="utf-8-sig"))
    rows = [("Galmuri11.ttf", 12), ("Galmuri11.ttf", 24), ("Galmuri11-Bold.ttf", 12), ("Galmuri11-Bold.ttf", 24),
            ("Galmuri9.ttf", 10), ("Galmuri9.ttf", 20),
            ("Galmuri11.ttf", 9), ("Galmuri11.ttf", 18), ("Galmuri11.ttf", 28)]
    summary = {}
    crops = []
    for dev in rep["devices"]:
        p = os.path.join(d, dev["id"] + ".png")
        a = analyse(p, dev, rows)
        summary[dev["id"]] = {"scale": dev["scale"], "rows": a}
        im = Image.open(p).convert("RGB")
        # 1:1 crop of the first 520 device px width for each band, stacked
        for r in a:
            y0, y1 = r["band"]
            crops.append((dev["id"], r, im.crop((0, y0, min(im.width, 900), y1))))
    with open(os.path.join(d, "font_regularity.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(summary, f, indent=1)
    # contact sheet of 1:1 crops (device pixels, no resampling)
    W = 900 + 300
    H = sum(c[2].height + 4 for c in crops) + 10
    sheet = Image.new("RGB", (W, H), (20, 20, 28))
    dr = ImageDraw.Draw(sheet)
    y = 5
    for dev, r, cimg in crops:
        sheet.paste(cimg, (300, y))
        ok = "OK" if r["irregular_runs"] == 0 else ("NON-INT" if r["irregular_runs"] == 1.0 else f"irr {r['irregular_runs']:.2f}")
        dr.text((4, y + 2), f"{dev} {r['font'][:-4]} {r['px']}px blk={r['device_block']} {ok}",
                fill=(120, 230, 120) if ok == "OK" else (255, 120, 100))
        y += cimg.height + 4
    sheet.save(os.path.join(d, "font_contact_1to1.png"))
    for dev, s in summary.items():
        print(dev, "scale", round(s["scale"], 3))
        for r in s["rows"]:
            print(f"   {r['font']:20s} {r['px']:3d}px block={r['device_block']:<6} irregular={r['irregular_runs']}")


if __name__ == "__main__":
    main(sys.argv[1])
