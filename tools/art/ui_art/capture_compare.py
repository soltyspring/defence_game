#!/usr/bin/env python3
"""06-art-ui: before|after sheets from tools/art/ui_art/ui_capture.ps1 shots. Owner: 06-art-ui.

Usage: python tools/art/ui_art/capture_compare.py [--shots build/ui06/shots] [--out docs/art/evidence/ui_art]
Writes cmp_<loc>_1x.png: rows menu, r01 HUD ~30 s, result; columns before | after. Screen numbers for the final claim
come from 07's fixed set (docs/verification/ART_BASELINE.md, tools/qa/art_metrics.py), not from this sheet.
"""
from __future__ import annotations

import argparse
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ROWS = ["1_menu", "5_r01_t30", "6_result"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default=os.path.join(ROOT, "build", "ui06", "shots"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "art", "evidence", "ui_art"))
    a = ap.parse_args()
    for loc in ("ko", "en"):
        paths = [[os.path.join(a.shots, f"{s}_{loc}_1x_{r}.png") for s in ("before", "after")] for r in ROWS]
        missing = [p for row in paths for p in row if not os.path.exists(p)]
        if missing:
            print("missing", missing)
            continue
        ims = [[Image.open(p).convert("RGB") for p in row] for row in paths]
        w, h = ims[0][0].size
        sheet = Image.new("RGB", (w * 2 + 8, h * len(ROWS) + 8 * (len(ROWS) - 1)), (255, 255, 255))
        for ri, row in enumerate(ims):
            for ci, im in enumerate(row):
                sheet.paste(im, (ci * (w + 8), ri * (h + 8)))
        out = os.path.join(a.out, f"cmp_{loc}_1x.png")
        sheet.save(out, optimize=True)
        print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
