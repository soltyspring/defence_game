"""Contact-sheet / strip previews (owner: 03-art). Output goes to docs/art/previews
(never shipped in the game build)."""
from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw

from pixel import RGBA

BG_A = (58, 62, 78, 255)
BG_B = (66, 70, 88, 255)


def checker(w, h, cell=8):
    img = Image.new("RGBA", (w, h), BG_A)
    d = ImageDraw.Draw(img)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if ((x // cell) + (y // cell)) % 2:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=BG_B)
    return img


def to_rgba(a):
    return Image.fromarray(RGBA[a], "RGBA")


def anim_sheet(title, anims: dict, frame_w, frame_h, pivot, scale=4, path=None, bg=None):
    """anims: name -> list of index arrays. One row per anim, pivot marked."""
    label_w = 70
    cols = max(len(f) for f in anims.values())
    cw, ch = frame_w * scale + 6, frame_h * scale + 6
    W = label_w + cols * cw + 6
    H = 22 + len(anims) * ch + 6
    sheet = checker(W, H, 8) if bg is None else Image.new("RGBA", (W, H), bg)
    d = ImageDraw.Draw(sheet)
    d.text((6, 4), title, fill=(255, 255, 255, 255))
    for r, (name, frames) in enumerate(anims.items()):
        y = 22 + r * ch
        d.text((6, y + ch // 2 - 6), f"{name} ({len(frames)})", fill=(230, 230, 200, 255))
        for i, f in enumerate(frames):
            x = label_w + i * cw
            d.rectangle([x, y, x + frame_w * scale + 1, y + frame_h * scale + 1], outline=(90, 96, 120, 255))
            im = to_rgba(f).resize((frame_w * scale, frame_h * scale), Image.NEAREST)
            sheet.alpha_composite(im, (x + 1, y + 1))
            # pivot marker
            px, py = x + 1 + pivot[0] * scale, y + 1 + pivot[1] * scale
            d.line([px - 3, py + scale, px + 3, py + scale], fill=(255, 80, 200, 255))
    if path:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sheet.save(path)
    return sheet
