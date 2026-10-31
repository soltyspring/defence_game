#!/usr/bin/env python3
"""06-art-ui: render the title-logo frames from the CURRENT tools/art/branding.py on the measured menu sky
(#3d517a) at x2, without running build.py. Owner: 06-art-ui. No Godot.

Usage: python tools/art/ui_art/logo_preview.py --out docs/art/evidence/ui_art/after_logo_x2.png
"""
from __future__ import annotations

import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
sys.path.insert(0, ART)
sys.path.insert(0, HERE)

import branding  # noqa: E402
import pixel  # noqa: E402
import ui_audit as A  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    logos = branding.logos()
    order = ["logo_title_ko", "logo_title_ko_2line", "logo_title_en", "logo_title_en_2line"]
    W = max(logos[k].w for k in order) + 16
    H = sum(logos[k].h + 8 for k in order) + 8
    im = np.zeros((H, W, 3), float)
    im[:] = A.MENU_SKY
    y = 8
    for k in order:
        cv = logos[k]
        px = pixel.RGBA[cv.a].astype(float)
        al = px[..., 3:4] / 255.0
        reg = im[y:y + cv.h, 8:8 + cv.w]
        im[y:y + cv.h, 8:8 + cv.w] = px[..., :3] * al + reg * (1 - al)
        y += cv.h + 8
    out = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8))
    out.resize((W * 2, H * 2), Image.NEAREST).save(a.out, optimize=True)
    print("wrote", a.out, {k: (logos[k].w, logos[k].h) for k in order})
    print(A.audit_logo())


if __name__ == "__main__":
    main()
