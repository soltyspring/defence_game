"""Lane set pieces v2 (2026-11-10): bakery town -> open field -> mould blight.

    python tools/art/world/lane_set.py      # writes assets/backgrounds/lane_set_v2.png (+ .json region table)

One 512x256 RGBA sheet, nearest filter, drawn at 1 texel = 1 world px (same grid as the unit atlases).
Regions (also hard-coded in src/gameplay/lane_backdrop.gd, SET_*):
    home    (0,   0, 320, 108)  town right of the player keep; bottom row sits on world y = ground - 12
    blight  (0, 112, 320, 108)  mould thicket behind the nest; same baseline
    mill    (324, 0, 112, 112)  windmill flour mill for bakery_supply.gd (replaces the painted crop); bottom = ground
Rules these pieces follow (docs/art/fable52/STYLE_RULES.md):
    * no colour darker than luminance 0.38 and no dark outline: K-outlined units always win the contrast;
    * the bottom 44 px (the band units stand in front of) carries flat masses only: wall, hedge, fog;
    * windows / awnings / signs / bulbs start above that band; smallest feature 3 px; no dither, no 1 px noise.
"""
from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "backgrounds", "lane_set_v2.png")

REGIONS = {"home": (0, 0, 320, 108), "blight": (0, 112, 320, 108), "mill": (324, 0, 112, 112)}

# warm town
WALL, WALL_S = "#e6d9b9", "#d2c29e"
ROOF, ROOF_S = "#bd7d5e", "#a2674c"
ROOF2, ROOF2_S = "#c79a62", "#ad8250"
TIMBER = "#a08a68"
GLASS = "#9db0a6"
DOOR = "#94795a"
LOWWALL, LOWWALL_CAP, LOWWALL_S = "#d9ccac", "#ece2c6", "#c6b792"
HEDGE, HEDGE_S = "#93a874", "#819a68"
AWN_A, AWN_B = "#e9dfc6", "#cf8a6a"
SMOKE = "#f1f1e4"
MILL_BODY, MILL_S, BLADE = "#ddd2b6", "#c7b998", "#b9a784"
GOLD = "#d9b25e"
# cold blight
FOG, FOG_S = "#a6b6aa", "#93a69b"
STALK, BULB, BULB_H = "#6d857f", "#93ada2", "#c6d6cb"
CAP, CAP_S = "#5f7f7c", "#54726f"
RUIN, RUIN_S = "#b3bcae", "#9ba898"
DEAD = "#6f8580"
TEAL = "#6fa3a6"


def _house(d, x, base, w, wall_h, roof_h, roof=(ROOF, ROOF_S), windows=1, chimney=True, timber=True):
    top = base - wall_h
    d.rectangle([x, top, x + w - 1, base], fill=WALL)
    d.rectangle([x + w - 5, top, x + w - 1, base], fill=WALL_S)                    # shaded right side
    d.polygon([(x - 4, top), (x + w // 2, top - roof_h), (x + w + 3, top)], fill=roof[0])
    d.polygon([(x + w // 2, top - roof_h), (x + w + 3, top), (x + w // 2 + 3, top)], fill=roof[1])
    if chimney:
        cx = x + w - 14
        d.rectangle([cx, top - roof_h + 2, cx + 6, top - roof_h // 2 + 6], fill=WALL_S)
        d.rectangle([cx - 1, top - roof_h, cx + 7, top - roof_h + 2], fill=TIMBER)
    if timber:
        d.rectangle([x, top + 16, x + w - 1, top + 18], fill=TIMBER)                # one beam; no lattice
    n = windows
    for i in range(n):                                                             # windows only in the top storey
        wx = x + (i + 1) * w // (n + 1) - 5
        d.rectangle([wx, top + 4, wx + 9, top + 13], fill=TIMBER)
        d.rectangle([wx + 1, top + 5, wx + 8, top + 12], fill=GLASS)


def _smoke(d, x, y):
    for i, (dx, dy, r) in enumerate(((0, 0, 3), (3, -7, 4), (-1, -15, 5))):
        d.ellipse([x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=SMOKE)


def _windmill(d, x, base, h=74, blades=True):
    d.polygon([(x - 13, base), (x - 8, base - h), (x + 8, base - h), (x + 13, base)], fill=MILL_BODY)
    d.polygon([(x + 4, base - h), (x + 8, base - h), (x + 13, base), (x + 7, base)], fill=MILL_S)
    d.polygon([(x - 11, base - h), (x, base - h - 12), (x + 11, base - h)], fill=ROOF)
    d.polygon([(x, base - h - 12), (x + 11, base - h), (x + 3, base - h)], fill=ROOF_S)
    d.rectangle([x - 4, base - h + 30, x + 3, base - h + 39], fill=GLASS)
    if blades:
        hx, hy = x, base - h + 6
        for (ax, ay) in ((1, -1), (1, 1), (-1, 1), (-1, -1)):                      # fixed X cross: a landmark, not motion
            d.line([(hx, hy), (hx + ax * 26, hy + ay * 26)], fill=TIMBER, width=2)
            d.polygon([(hx + ax * 9, hy + ay * 9), (hx + ax * 26, hy + ay * 26),
                       (hx + ax * 26 - ay * 7, hy + ay * 26 + ax * 7), (hx + ax * 9 - ay * 7, hy + ay * 9 + ax * 7)],
                      fill=BLADE)
        d.rectangle([hx - 2, hy - 2, hx + 2, hy + 2], fill=ROOF_S)


def _tree(d, x, base, h=44, col=(HEDGE, HEDGE_S)):
    d.rectangle([x - 2, base - h + 16, x + 2, base], fill=TIMBER)
    d.ellipse([x - 16, base - h - 4, x + 16, base - h + 26], fill=col[0])
    d.ellipse([x - 4, base - h + 6, x + 16, base - h + 26], fill=col[1])


def home(w=320, h=108):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = h - 1
    # Placed right of the keep (lane_backdrop.gd: x = player_base.x + 52): the bakery is the first thing the army passes.
    # Uneven widths, heights and gaps (alley, tree) instead of a row of copies.
    _house(d, 6, base, 78, 70, 30, roof=(ROOF2, ROOF2_S), windows=2)               # bakery: awning + bread sign
    _smoke(d, 71, base - 104 + 6)
    for i in range(8):                                                             # awning: 9 px stripes, above the band
        d.rectangle([10 + i * 9, base - 52, 10 + i * 9 + 8, base - 46], fill=AWN_A if i % 2 == 0 else AWN_B)
    d.ellipse([37, base - 68, 53, base - 57], fill=GOLD)                           # bread sign
    d.rectangle([41, base - 65, 49, base - 61], fill=ROOF2_S)
    _house(d, 106, base, 50, 58, 24, windows=1)
    _tree(d, 182, base, 48)
    _house(d, 206, base, 44, 50, 20, windows=1, chimney=False)
    # low garden wall: the flat band units stand in front of (bottom 44 px stays calm)
    d.rectangle([0, base - 30, w - 40, base], fill=LOWWALL)
    d.rectangle([0, base - 30, w - 40, base - 28], fill=LOWWALL_CAP)
    d.rectangle([0, base - 6, w - 40, base], fill=LOWWALL_S)
    for gx in (92, 166, 258):                                                      # gateposts break the run into bays
        d.rectangle([gx, base - 36, gx + 6, base], fill=LOWWALL_S)
        d.rectangle([gx - 1, base - 38, gx + 7, base - 35], fill=LOWWALL_CAP)
    d.ellipse([w - 62, base - 26, w - 8, base + 22], fill=HEDGE)                   # hedge closes the town edge
    d.ellipse([w - 44, base - 14, w - 4, base + 22], fill=HEDGE_S)
    return im


def _stalk(d, x, base, h, r=5):
    d.rectangle([x - 1, base - h, x + 1, base], fill=STALK)
    d.ellipse([x - r, base - h - r * 2 + 2, x + r, base - h + 2], fill=BULB)
    d.rectangle([x - r + 2, base - h - r * 2 + 4, x - r + 3, base - h - r * 2 + 5], fill=BULB_H)


def _shroom(d, x, base, h, cw):
    d.rectangle([x - 3, base - h, x + 3, base], fill=STALK)
    d.pieslice([x - cw, base - h - cw // 2, x + cw, base - h + cw // 2 + 6], 180, 360, fill=CAP)
    d.pieslice([x + 2, base - h - cw // 2, x + cw, base - h + cw // 2 + 6], 270, 360, fill=CAP_S)
    for (sx, sy) in ((-cw // 2, -6), (cw // 3, -9), (0, -12)):
        d.rectangle([x + sx, base - h + sy + 4, x + sx + 2, base - h + sy + 6], fill=BULB_H)


def blight(w=320, h=108):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = h - 1
    # last ruined house at the town-side (left) edge, already taken by the mould
    d.rectangle([14, base - 56, 62, base], fill=RUIN)
    d.rectangle([54, base - 56, 62, base], fill=RUIN_S)
    d.polygon([(10, base - 56), (30, base - 76), (44, base - 62), (52, base - 70), (66, base - 56)], fill=CAP)
    d.rectangle([24, base - 50, 34, base - 40], fill=CAP_S)
    # dead tree
    d.rectangle([92, base - 58, 96, base], fill=DEAD)
    d.line([(94, base - 44), (108, base - 60)], fill=DEAD, width=2)
    d.line([(94, base - 50), (82, base - 66)], fill=DEAD, width=2)
    d.line([(94, base - 58), (98, base - 74)], fill=DEAD, width=2)
    # irregular thicket: big caps and nest stalks, uneven heights and gaps, taller towards the nest (right)
    _shroom(d, 132, base, 46, 20)
    _stalk(d, 164, base, 74, 5)
    _shroom(d, 196, base, 64, 26)
    _stalk(d, 226, base, 92, 6)
    _stalk(d, 240, base, 60, 4)
    _shroom(d, 276, base, 80, 30)
    _stalk(d, 306, base, 98, 6)
    for (mx, my) in ((150, 80), (214, 96), (254, 86), (292, 100)):                 # a few large spore motes
        d.rectangle([mx, base - my, mx + 2, base - my + 2], fill=BULB_H)
    # creeping fog bank: the flat band behind the units; rounded lumps, rising towards the nest
    for i, t in enumerate((14, 18, 16, 24, 22, 30, 27, 34, 38, 35, 42, 40, 44)):
        x = i * 26 - 8
        d.ellipse([x, base - t - 8, x + 40, base - t + 30], fill=FOG)
    d.rectangle([0, base - 12, w - 1, base], fill=FOG)
    d.rectangle([0, base - 7, w - 1, base], fill=FOG_S)
    d.rectangle([250, base - 22, 262, base - 19], fill=TEAL)                       # two cold glints, nothing more
    d.rectangle([170, base - 14, 178, base - 12], fill=TEAL)
    return im


def mill(w=112, h=112):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = h - 1
    # The flour mill of the worker loop is the home landmark: a windmill on a stone store. It is a gameplay prop,
    # so it may use darker accents than the set pieces.
    d.rectangle([22, base - 26, 90, base], fill=LOWWALL)
    d.rectangle([22, base - 26, 90, base - 24], fill=LOWWALL_CAP)
    d.rectangle([82, base - 26, 90, base], fill=LOWWALL_S)
    _windmill(d, 56, base - 20, 58)
    d.rectangle([49, base - 18, 63, base], fill="#6f5a43")
    d.rectangle([51, base - 16, 61, base], fill=DOOR)
    d.rectangle([24, base - 11, 40, base], fill=TIMBER)                            # hopper crate
    return im


def build():
    sheet = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    for name, fn in (("home", home), ("blight", blight), ("mill", mill)):
        x, y, w, h = REGIONS[name]
        sheet.alpha_composite(fn(w, h), (x, y))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT)
    with open(OUT[:-4] + ".json", "w", encoding="utf-8") as f:
        json.dump({"image": "lane_set_v2.png", "filter": "nearest", "baseline": "bottom row = world ground_y - 12",
                   "regions": {k: list(v) for k, v in REGIONS.items()}}, f, indent=1)
    return sheet


if __name__ == "__main__":
    build()
    print("wrote", OUT)
