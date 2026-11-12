"""Battlefield sets for every chapter, in the R01 slice style, plus the per-round composition table.

    python tools/art/release_slice/chapters.py
Writes assets/art/release_slice/slice_ch1.png .. slice_ch4.png (+ .json, schema defence.atlas/1) and rounds.json.
The R01 page (slice_atlas.png: bases, bakery yard, mill, clouds, the meadow tiles) is not rebuilt here.

Chapter page frames (same roles in every chapter; chapter 1 takes far / mid / lane from slice_atlas.png):
    far 512x70, mid_a / mid_b 512x96 (b = the land once the enemy has it), mid_edge 120x96,
    lane_a / lane_b 256x60, lane_edge 64x60, enemy_a / enemy_b 320x140 (b = second half of the chapter),
    home_b (chapter 4 only: the forward camp), and the landmarks listed in ROUNDS.
Rules as in docs/art/release_slice/STYLE.md: masses with 5-step ramps, light from the upper left, scenery keeps to
its own dark step, and whatever stands behind the units is flat for the lowest 44 px.
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import (RAMP, Img, grid, grow, hexc, m_curve, m_ellipse, m_line, m_poly, m_rect, mass, paint, put, rim, shift, step,  # noqa: E402
                 t_bricks, t_planks, t_shingles)
from backdrop import _below, _lane, _profile, bare_tree, cap_stalk, tree  # noqa: E402
from backdrop import far as far1, home_set as home1  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "release_slice")
HEAD = 20
MH = 96


def _r(name, cols):
    RAMP[name] = [hexc(c) for c in cols]


_r("ograss", ("6c7a40", "87944e", "a2ac60", "bcc378", "d5d897"))          # dry orchard grass
_r("autumn", ("8a5a2a", "b07a36", "d09b48", "e6bd62", "f3da8c"))          # turning leaves
_r("ohill", ("a0a98c", "b3b99a", "c5c8a8", "d5d5b8", "e4e2c9"))
_r("snow", ("8fa3b8", "adbfd0", "c9d7e2", "e2ebf0", "f6fafb"))
_r("frostfield", ("5f7482", "748a98", "8a9fac", "a3b6c0", "bccbd2"))      # the mid-tone ground behind the units
_r("ice", ("6f93ad", "8fb2c8", "b0cfdf", "d0e6ef", "ecf7fa"))
_r("pine", ("2f4a48", "3f625c", "548070", "6e9c86", "93b9a2"))
_r("peak", ("8296b0", "9aabc2", "b4c2d3", "cdd8e2", "e6edf1"))
_r("froad", ("6d7480", "868d98", "a0a7b0", "b9bfc6", "d0d5da"))
_r("cavewall", ("2f4244", "41595a", "567372", "6f8f8b", "8fada6"))
_r("cavefar", ("3d5354", "4d6665", "5f7b78", "74918c", "8ca7a0"))
_r("nfloor", ("3c4a48", "526260", "6a7c78", "849692", "a0b0aa"))
_r("npath", ("5a6260", "737c78", "8c9590", "a5aea8", "bdc5be"))


def _tile(im: Img) -> Img:
    im.a[:, 0] = im.a[:, 1]
    im.a[:, -1] = im.a[:, -2]
    return im


def _edge(tile: Img, w=120) -> Img:
    """Ragged left edge of a mid tile (the 60 columns either side of the join), as in backdrop.mid_edge."""
    img = Img(w, tile.h)
    img.a[:, 60:] = tile.a[:, :60]
    img.a[:, :60] = tile.a[:, tile.w - 60:tile.w]
    xx, yy = grid(w, tile.h)
    fy = yy - HEAD
    edge = 56 + 20 * np.sin(fy * 0.21) + 9 * np.sin(fy * 0.53 + 1.0) - (fy - 26) * 0.5
    img.a[xx < edge] = (0, 0, 0, 0)
    return img


def _lane_edge(tile: Img) -> Img:
    img = Img(64, tile.h)
    img.a[:, :] = tile.a[:, tile.w - 64:tile.w]
    xx, yy = grid(64, tile.h)
    img.a[xx < 40 - (yy - 6) * 0.9 + 6 * np.sin(yy * 0.6)] = (0, 0, 0, 0)
    return img


def _land(far_ramp, mid_ramp, near_ramp, far_base=3, mid_base=2, near_base=2, rows=True):
    """Rolling land in three strips (far / middle / the calm strip behind the units). Returns img, top, b1, b2."""
    W, H = 512, MH
    img = Img(W, H)
    xx, yy = grid(W, H)
    top = _profile(W, 26 + HEAD, [(1, 4, 0.9), (2, 2.5, 2.2)])
    land = _below(W, H, top)
    b1 = top + 9 + 3 * np.sin(xx[0] * 2 * math.pi / 512 + 0.5)
    b2 = top + 20 + 4 * np.sin(xx[0] * 2 * math.pi / 256 + 2.0)
    far = land & (yy < b1[None, :])
    lvf = paint(img, far, far_ramp, "flat", base=far_base)
    step(img, far & (np.floor((xx + yy * 3) / 40.0) % 2 == 0), far_ramp, lvf, -1)
    mid = land & (yy >= b1[None, :]) & (yy < b2[None, :])
    lvm = paint(img, mid, mid_ramp, "flat", base=mid_base)
    if rows:
        ang = np.arctan2(yy - HEAD + 60.0, xx - 256.0)
        step(img, mid & (np.floor(ang * 46.0) % 2 == 0), mid_ramp, lvm, 1)
    step(img, mid & (yy < b1[None, :] + 2), mid_ramp, lvm, 1)
    near = land & (yy >= b2[None, :])
    lvn = paint(img, near, near_ramp, "flat", base=near_base)
    step(img, near & (np.sin(xx * 2 * math.pi / 512 + 1.0) + (yy - 50 - HEAD) * 0.03 > 0.55), near_ramp, lvn, 1)
    return img, top, b1, b2


# ---------------------------------------------------------------------------------------------------------------
# chapter 2: the tainted orchard
def fruit_tree(img, x, by, hgt, ramp="leaf", apples=True, lean=0):
    tree(img, x, by, hgt, ramp, "wood", lean)
    if apples:
        r = hgt * 0.34
        for dx, dy in ((-0.5, -0.62), (0.35, -0.78), (0.75, -0.52), (-0.1, -0.5)):
            ax, ay = int(x + lean + dx * r * 1.4), int(by + dy * hgt)
            put(img, m_rect(img.w, img.h, ax, ay, 3, 3), RAMP["cloth"][3])
            put(img, m_rect(img.w, img.h, ax, ay, 1, 1), RAMP["cloth"][4])


def far2() -> Img:
    W, H = 512, 70
    img = Img(W, H)
    back = _below(W, H, _profile(W, 24, [(1, 7, 1.4), (3, 4, 0.2)]))
    paint(img, back, [hexc(c) for c in ("b0b5a4", "bfc3b0", "cdcfbc", "dad9c8", "e6e4d4")], "flat", base=2)
    prof = _profile(W, 38, [(1, 6, 0.3), (2, 4, 2.0), (5, 2, 1.0)])
    front = _below(W, H, prof)
    # the old mill on the far ridge (one value)
    mx = 330
    sil = m_poly(W, H, [(mx - 5, 36), (mx - 3, 18), (mx + 4, 18), (mx + 6, 36)]) | m_line(W, H, mx - 10, 10, mx + 11, 26, 1.6) | m_line(W, H, mx + 10, 9, mx - 3, 19, 1.6)
    put(img, sil & ~front, hexc("9aa39a"))
    lv = paint(img, front, "ohill", "flat", base=3)
    xx, yy = grid(W, H)
    # orchard rows on the slope: lines of small crowns, unevenly spaced
    for row, off in enumerate((6, 14, 23)):
        for i in range(26):
            tx = (i * 21 + row * 9 + (i * i * 3) % 11) % W
            if (i + row) % 6 == 5:
                continue
            ty = prof[tx] + off
            put(img, m_ellipse(W, H, tx, ty, 3.5 + row * 0.5, 2.5 + row * 0.3), RAMP["ohill"][1 if (i % 3) else 0])
    return _tile(img)


def mid2(blight: bool) -> Img:
    img, top, b1, b2 = _land("blight" if blight else "ograss", "blight" if blight else "ograss", "blight" if blight else "ograss",
                             3, 2, 2, rows=False)
    W, H = img.w, img.h
    # two staggered rows of small trees in the middle strip
    for i in range(18):
        x = (i * 29 + (i * i * 7) % 13) % W
        y = int((b1[x] + b2[x]) * 0.5) + (2 if i % 2 else -1)
        if blight:
            if i % 3 == 0:
                bare_tree(img, x, y + 3, 13)
            else:
                m = m_ellipse(W, H, x, y - 6, 7, 5)
                mass(img, m, "blight", "round", RAMP["blight"][0], base=1)
                put(img, m_rect(W, H, x - 1, y - 2, 2, 5), RAMP["hypha"][1])
        else:
            m = m_ellipse(W, H, x, y - 6, 7, 5)
            mass(img, m, "leaf" if i % 4 else "autumn", "round", RAMP["leaf"][0], base=2)
            put(img, m_rect(W, H, x - 1, y - 2, 2, 5), RAMP["wood"][1])
            put(img, m_rect(W, H, x + 2, y - 7, 2, 2), RAMP["cloth"][3])
    # the tall trees of the near row rise over the horizon: uneven groups
    if not blight:
        for x, h, ramp, lean in ((36, 34, "leaf", 0), (60, 28, "autumn", 1), (182, 38, "leaf", -1), (300, 30, "autumn", 0), (322, 36, "leaf", 1), (452, 32, "leaf", 0)):
            fruit_tree(img, x, int(top[x]) + 6, h, ramp, True, lean)
        # a split-rail fence along the strip's lower edge, with a gap
        for i in range(36):
            px = i * 14 + (i * 5) % 4
            if px >= W or 150 < px < 200:
                continue
            py = int(b2[px])
            put(img, m_rect(W, H, px, py - 6, 2, 7), RAMP["wood"][1])
            if px + 14 < W:
                put(img, m_rect(W, H, px, py - 4, 14, 1), RAMP["wood"][2])
    else:
        for x, h in ((36, 34), (182, 38), (322, 34), (452, 30)):
            bare_tree(img, x, int(top[x]) + 6, h)
        for x, h, r, d in ((60, 26, 9, 0.5), (300, 32, 11, -0.4), (410, 22, 8, 0.3)):
            cap_stalk(img, x, int(top[x]) + 6, h, r, "cap", d)
        # fog lying in the hollow: two flat slabs above the unit band
        for fx, fy, fw in ((120, 60, 70), (360, 64, 90)):
            fog = m_ellipse(W, H, fx, fy, fw, 4) & m_rect(W, H, 0, 0, W, 68)
            put(img, fog, hexc("c6cfc4"))
    return _tile(img)


def lane2(blight: bool) -> Img:
    RAMP.setdefault("path_grey", [hexc(c) for c in ("7f7a6c", "979282", "afa998", "c4beac", "d6d1bf")])
    img = _lane(256, 60, "path_grey" if blight else "path", "blight" if blight else "ograss", veins=blight)
    if not blight:
        # windfall on the road: a few apples and leaves, bigger than a pixel
        for x, y, c in ((30, 12, "cloth"), (96, 20, "autumn"), (150, 10, "autumn"), (204, 22, "cloth"), (236, 14, "autumn")):
            put(img, m_rect(256, 60, x, y, 3, 2), RAMP[c][3])
            put(img, m_rect(256, 60, x, y + 2, 3, 1), RAMP["path"][0])
    return _tile(img)


def enemy2(taken: bool) -> Img:
    """Chapter 2 enemy side: the abandoned mill among dead trees; `taken` = the mould owns it (R16-R20)."""
    W, H = 320, 140
    img = Img(W, H)
    B = H
    for x, h in ((24, 60), (96, 44), (300, 56)):
        bare_tree(img, x, B - 22, h)
    # the mill tower, leaning, sails broken
    tw = m_poly(W, H, [(176, B - 22), (184, B - 104), (212, B - 106), (226, B - 22)])
    lv = mass(img, tw, "plaster" if not taken else "blight", "wall", RAMP["timber"][0], base=2)
    step(img, tw & t_bricks(W, H, 12, 7, 176, B - 106), "plaster" if not taken else "blight", lv, -1)
    capm = m_poly(W, H, [(180, B - 104), (190, B - 124), (208, B - 126), (216, B - 106)])
    lvc = mass(img, capm, "wood", "flat", RAMP["timber"][0], base=1)
    step(img, capm & t_shingles(W, H, 7, 5, 180, B - 126), "wood", lvc, -1)
    hub = (198, B - 100)
    for ang, ln in ((-30, 44), (60, 30), (150, 40)):          # three arms left, one torn short
        a = math.radians(ang)
        tip = (hub[0] + math.cos(a) * ln, hub[1] + math.sin(a) * ln)
        mass(img, m_line(W, H, hub[0], hub[1], tip[0], tip[1], 2.4), "timber", "flat", RAMP["timber"][0], base=1)
        nx, ny = -math.sin(a), math.cos(a)
        sail = m_poly(W, H, [(hub[0] + math.cos(a) * 10, hub[1] + math.sin(a) * 10), tip, (tip[0] + nx * 8, tip[1] + ny * 8), (hub[0] + math.cos(a) * 12 + nx * 8, hub[1] + math.sin(a) * 12 + ny * 8)])
        mass(img, sail, "sack", "flat", RAMP["timber"][0], base=1 if taken else 2)
    put(img, m_rect(W, H, 194, B - 84, 9, 10), hexc("4b4a55"))
    door = m_rect(W, H, 192, B - 44, 14, 22)
    mass(img, door, "timber", "flat", None, base=0)
    if taken:
        for x, h, r, d in ((170, 96, 16, -0.4), (232, 70, 12, 0.5), (204, 132, 13, 0.2)):
            cap_stalk(img, x, B - 22, h, r, "cap", d)
        put(img, m_rect(W, H, 195, B - 82, 7, 5), RAMP["organ"][3])
    # the flat mass through the unit band: dead grass bank, roots when taken
    bank = m_rect(W, H, 60, B - 24, 260, 24) | m_curve(W, H, [(70, B - 10), (36, B - 6), (8, B - 2)], 12, 3)
    lvb = mass(img, bank, "mould" if taken else "blight", "flat", None, base=2 if taken else 1)
    for hx, hw in ((110, 34), (250, 40)):
        step(img, bank & m_ellipse(W, H, hx, B - 26, hw, 9), "mould" if taken else "blight", lvb, -1)
    return img


def lm_gate() -> Img:
    W, H = 72, 64
    img = Img(W, H)
    for px in (8, 58):
        mass(img, m_rect(W, H, px, 14, 6, 50), "wood", "flat", RAMP["wood"][0], base=2)
    arch = m_poly(W, H, [(4, 16), (14, 4), (58, 4), (68, 16)])
    lv = mass(img, arch, "wood", "flat", RAMP["wood"][0], base=3)
    step(img, arch & t_planks(W, H, 7, 4), "wood", lv, -1)
    mass(img, m_ellipse(W, H, 36, 10, 5, 4.5), "cloth", "round", RAMP["cloth"][0], base=3)       # apple sign
    put(img, m_rect(W, H, 36, 3, 2, 3), RAMP["leaf"][1])
    return img


def lm_press() -> Img:
    """Cider press house: plaster barn, sagging tiled roof, the screw press under a lean-to."""
    W, H = 96, 64
    img = Img(W, H)
    body = m_rect(W, H, 6, 26, 60, 38)
    lv = mass(img, body, "plaster", "wall", RAMP["timber"][0])
    for bx in (6, 34, 62):
        paint(img, m_rect(W, H, bx, 26, 4, 38), "timber", "flat")
    roof = m_poly(W, H, [(0, 28), (12, 6), (40, 9), (58, 5), (72, 28)])
    lvr = mass(img, roof, "brick", "flat", RAMP["timber"][0], base=1)
    step(img, roof & t_shingles(W, H, 8, 5, 0, 5), "brick", lvr, -1)
    put(img, m_rect(W, H, 14, 36, 12, 12), hexc("4b4a55"))
    mass(img, m_rect(W, H, 42, 40, 14, 24), "timber", "flat", None, base=1)
    lean = m_poly(W, H, [(66, 34), (94, 40), (94, 44), (66, 38)])
    mass(img, lean, "wood", "flat", RAMP["wood"][0], base=2)
    paint(img, m_rect(W, H, 90, 42, 3, 22), "timber", "flat")
    mass(img, m_rect(W, H, 72, 50, 14, 14), "wood", "wall", RAMP["wood"][0], base=1)             # the vat
    paint(img, m_rect(W, H, 78, 40, 2, 12), "iron", "flat", base=2)
    return img


def lm_cart(fallen=True) -> Img:
    W, H = 56, 36
    img = Img(W, H)
    if fallen:
        box = m_poly(W, H, [(6, 35), (12, 14), (42, 8), (50, 28), (44, 35)])
    else:
        box = m_rect(W, H, 8, 14, 38, 14)
    lv = mass(img, box, "wood", "flat", RAMP["wood"][0], base=2)
    step(img, box & t_planks(W, H, 6, 2), "wood", lv, -1)
    wheel = m_ellipse(W, H, 28 if fallen else 16, 8 if fallen else 30, 6, 6)
    mass(img, wheel, "timber", "round", RAMP["timber"][0])
    if not fallen:
        mass(img, m_ellipse(W, H, 38, 30, 6, 6), "timber", "round", RAMP["timber"][0])
    for ax, ay in ((46, 32), (52, 33), (3, 33)):
        put(img, m_rect(W, H, ax, ay, 3, 3), RAMP["cloth"][3])
    return img


def lm_crates() -> Img:
    W, H = 44, 34
    img = Img(W, H)
    for x, y, w, h in ((2, 18, 18, 16), (22, 20, 16, 14), (10, 4, 18, 14)):
        m = m_rect(W, H, x, y, w, h)
        lv = mass(img, m, "wood", "flat", RAMP["wood"][0], base=3)
        step(img, m & t_planks(W, H, 5, x), "wood", lv, -1)
    for ax, ay in ((12, 2), (17, 1), (22, 2)):
        mass(img, m_ellipse(W, H, ax + 1.5, ay + 2, 2.5, 2.5), "cloth", "round", RAMP["cloth"][0], base=3)
    return img


# ---------------------------------------------------------------------------------------------------------------
# chapter 3: the frost road
def pine(img, x, by, hgt, snow=True):
    W, H = img.w, img.h
    put(img, m_rect(W, H, x - 1, by - 4, 3, 5), RAMP["wood"][0])
    for i in range(3):
        w = hgt * (0.42 - i * 0.1)
        y0 = by - 3 - i * hgt * 0.27
        tier = m_poly(W, H, [(x - w, y0), (x + 0.5, y0 - hgt * 0.42), (x + 1 + w, y0)])
        mass(img, tier, "pine", "flat", RAMP["pine"][0], base=2)
        if snow:
            put(img, m_poly(W, H, [(x - w * 0.5, y0 - hgt * 0.2), (x + 0.5, y0 - hgt * 0.42), (x + 1 + w * 0.3, y0 - hgt * 0.25)]) & tier, RAMP["snow"][4])


def home_frost() -> Img:
    """The bakery yard of the R01 page under snow: every upward-facing edge carries a 2 px cap, eaves a third row."""
    img = home1()
    solid = img.a[..., 3] > 0
    top = solid & ~shift(solid, 0, 1)
    put(img, top, RAMP["snow"][4])
    put(img, shift(top, 0, 1) & solid, RAMP["snow"][4])
    xx, _ = grid(img.w, img.h)
    put(img, shift(top, 0, 2) & solid & ((xx // 3) % 3 != 1), RAMP["snow"][3])
    return img


def far3() -> Img:
    W, H = 512, 70
    img = Img(W, H)
    xx, yy = grid(W, H)
    for k, (base, col, seed) in enumerate(((30, "peak", 0.0), (44, "peak", 1.7))):
        prof = np.full(W, float(base))
        for px, ph, pw in ((40, 26, 60), (150, 34, 80), (250, 22, 54), (350, 38, 90), (460, 28, 64)):
            cx = (px + k * 70) % W
            d = np.minimum(np.abs(xx[0] - cx), W - np.abs(xx[0] - cx))
            prof = np.minimum(prof, base - np.maximum(0.0, ph * (1 - k * 0.3) * (1 - d / pw)))
        m = _below(W, H, prof)
        paint(img, m, "peak", "flat", base=1 + k)
        # lit left faces carry the snow; right faces stay in blue shade
        slope = np.gradient(prof)
        lit = m & (slope[None, :] < -0.05) & (yy < prof[None, :] + 14)
        put(img, lit, RAMP["snow"][4 - k])
        put(img, m & (slope[None, :] > 0.05) & (yy < prof[None, :] + 10), RAMP["peak"][0 + k])
    return _tile(img)


def mid3(works: bool) -> Img:
    img, top, b1, b2 = _land("snow", "snow", "frostfield", 3, 2, 2, rows=False)
    W, H = img.w, img.h
    xx, yy = grid(W, H)
    # drifts: long soft-edged humps in the middle strip
    for i in range(7):
        dx = (i * 77 + 20) % W
        dy = int((b1[dx] + b2[dx]) * 0.5)
        m = m_ellipse(W, H, dx, dy + 2, 30 + (i % 3) * 8, 4)
        put(img, m & _below(W, H, b1) & ~_below(W, H, b2), RAMP["snow"][4])
    if not works:
        for x, h in ((30, 30), (48, 22), (62, 34), (210, 26), (228, 32), (380, 36), (400, 24), (480, 28)):
            pine(img, x, int(top[x]) + 7, h)
        # snowed-in fence along the strip edge
        for i in range(30):
            px = i * 17 + (i * 7) % 5
            if px >= W or 240 < px < 300:
                continue
            py = int(b2[px])
            put(img, m_rect(W, H, px, py - 6, 2, 7), RAMP["wood"][1])
            put(img, m_rect(W, H, px - 1, py - 8, 4, 2), RAMP["snow"][4])
    else:
        # the ice works: a rampart of upright ice blocks along the horizon, flat tops, uneven heights
        for i in range(13):
            bx = i * 40 + (i * 11) % 9
            bh = 16 + (i * 13) % 14
            by = int(top[min(W - 1, bx + 18)]) + 6
            blk = m_rect(W, H, bx, by - bh, 36, bh)
            lv = mass(img, blk, "ice", "wall", RAMP["ice"][0], base=2)
            put(img, m_rect(W, H, bx, by - bh, 36, 3) & blk, RAMP["ice"][4])
            step(img, blk & m_rect(W, H, bx + 26, by - bh + 3, 8, bh), "ice", lv, -1)
        # cold chimney stacks behind the wall
        for x, h in ((96, 40), (300, 46), (318, 34)):
            st = m_rect(W, H, x, int(top[x]) + 4 - h, 9, h - 14)
            mass(img, st, "stone", "wall", RAMP["stone"][0], base=1)
            put(img, m_rect(W, H, x - 1, int(top[x]) + 2 - h, 11, 3), RAMP["snow"][4])
    return _tile(img)


def lane3(works: bool) -> Img:
    img = _lane(256, 60, "froad", "frostfield", veins=False)
    W, H = 256, 60
    # snow banked on the far verge only; the road itself stays mid-tone so the pale danger band is the lightest thing on it
    for i in range(10):
        sx = (i * 27 + (i * i * 5) % 13) % W
        put(img, m_ellipse(W, H, sx, 4, 9 + i % 4, 2.5) & m_rect(W, H, 0, 0, W, 6), RAMP["snow"][3])
    if works:
        for x in (40, 150, 220):
            put(img, m_rect(W, H, x, 8, 10, 1), RAMP["ice"][1])              # frozen ruts
    return _tile(img)


def enemy3(heart: bool) -> Img:
    """Chapter 3 enemy side: the ice gate (R21-R25) or the Oven Heart (R26-R30)."""
    W, H = 320, 140
    img = Img(W, H)
    B = H
    if not heart:
        for bx, bh in ((70, 70), (112, 86), (154, 74), (240, 92), (282, 78)):
            blk = m_rect(W, H, bx, B - 22 - bh, 40, bh)
            lv = mass(img, blk, "ice", "wall", RAMP["ice"][0], base=2)
            put(img, m_rect(W, H, bx, B - 22 - bh, 40, 4), RAMP["ice"][4])
            step(img, blk & m_rect(W, H, bx + 30, B - 18 - bh, 8, bh), "ice", lv, -1)
        gate = m_rect(W, H, 196, B - 96, 44, 74)
        mass(img, gate, "timber", "wall", RAMP["timber"][0], base=1)
        put(img, m_rect(W, H, 217, B - 96, 2, 74), RAMP["iron"][2])
        lint = m_rect(W, H, 190, B - 104, 56, 9)
        mass(img, lint, "ice", "flat", RAMP["ice"][0], base=3)
        base = m_rect(W, H, 60, B - 24, 260, 24)
        mass(img, base, "frostfield", "flat", None, base=1)
        put(img, m_rect(W, H, 60, B - 26, 260, 3), RAMP["snow"][3])
    else:
        body = m_poly(W, H, [(86, B - 22), (96, B - 78), (130, B - 104), (250, B - 104), (284, B - 78), (294, B - 22)])
        lv = mass(img, body, "brick", "wall", RAMP["timber"][0], base=1)
        step(img, body & t_bricks(W, H, 12, 6, 86, B - 104), "brick", lv, -1)
        for sx, sh in ((122, 128), (186, 138), (244, 122)):
            st = m_rect(W, H, sx, B - sh, 18, sh - 104)
            lvs = mass(img, st, "brick", "wall", RAMP["timber"][0], base=1)
            step(img, st & t_bricks(W, H, 9, 5, sx, B - sh), "brick", lvs, -1)
            mass(img, m_rect(W, H, sx - 3, B - sh - 5, 24, 6), "stone", "flat", RAMP["timber"][0], base=2)
            put(img, m_rect(W, H, sx + 4, B - sh - 9, 10, 4), RAMP["fire"][2])
        mouth = (m_ellipse(W, H, 190, B - 62, 34, 30) & m_rect(W, H, 0, 0, W, B - 44)) | m_rect(W, H, 156, B - 62, 68, 18)
        mass(img, grow(mouth, 3) & body, "stone", "flat", None, base=2)
        put(img, mouth, RAMP["fire"][0])
        put(img, m_ellipse(W, H, 190, B - 50, 26, 16) & mouth, RAMP["fire"][2])
        put(img, m_ellipse(W, H, 190, B - 46, 14, 9) & mouth, RAMP["fire"][4])
        for gx in range(162, 222, 12):
            put(img, m_rect(W, H, gx, B - 92, 2, 48) & mouth, RAMP["iron"][0])
        base = m_rect(W, H, 60, B - 24, 260, 24)
        mass(img, base, "stone", "flat", None, base=1)
        put(img, m_rect(W, H, 150, B - 24, 80, 3), RAMP["fire"][1])            # the glow on the sill, above the unit band's lower part
    return img


def lm_silo(v=0) -> Img:
    W, H = 44, 78
    img = Img(W, H)
    h = 58 + v * 10
    body = m_rect(W, H, 6, H - h, 30, h)
    lv = mass(img, body, "stone", "wall", RAMP["stone"][0], base=2)
    step(img, body & t_planks(W, H, 6, 6), "stone", lv, -1)
    roof = m_poly(W, H, [(3, H - h), (12, H - h - 9), (30, H - h - 9), (39, H - h)])
    mass(img, roof, "snow", "flat", RAMP["snow"][0], base=3)
    paint(img, m_rect(W, H, 5, H - h + 20, 32, 3), "iron", "flat", base=1)
    mass(img, m_rect(W, H, 15, H - 18, 10, 18), "timber", "flat", None, base=1)
    ice = m_poly(W, H, [(4, H), (6, H - 16 - v * 6), (14, H - 6), (24, H - 20 - v * 4), (32, H - 5), (40, H)])
    mass(img, ice, "ice", "flat", RAMP["ice"][0], base=3)
    return img


def lm_millhall() -> Img:
    W, H = 132, 66
    img = Img(W, H)
    body = m_rect(W, H, 6, 26, 92, 40)
    lv = mass(img, body, "stone", "wall", RAMP["stone"][0], base=2)
    step(img, body & t_bricks(W, H, 14, 7, 6, 26) & m_rect(W, H, 0, 44, W, 22), "stone", lv, -1)
    roof = m_poly(W, H, [(0, 28), (16, 8), (88, 8), (104, 28)])
    lvr = mass(img, roof, "snow", "flat", RAMP["snow"][0], base=3)
    step(img, roof & m_rect(W, H, 0, 22, W, 6), "snow", lvr, -1)
    for wx in (18, 42, 66):
        put(img, m_rect(W, H, wx, 36, 10, 12), hexc("52606e"))
        put(img, m_rect(W, H, wx, 34, 10, 2), RAMP["snow"][4])
    # frozen water wheel on the right gable
    wc = (112, 44)
    rimm = m_ellipse(W, H, wc[0], wc[1], 18, 18) & ~m_ellipse(W, H, wc[0], wc[1], 14, 14)
    mass(img, rimm, "timber", "flat", RAMP["timber"][0], base=2)
    for a in range(0, 180, 45):
        r = math.radians(a)
        put(img, m_line(W, H, wc[0] - math.cos(r) * 15, wc[1] - math.sin(r) * 15, wc[0] + math.cos(r) * 15, wc[1] + math.sin(r) * 15, 1.8), RAMP["timber"][1])
    ic = m_poly(W, H, [(98, 66), (102, 50), (108, 60), (114, 46), (120, 62), (128, 54), (130, 66)])
    mass(img, ic, "ice", "flat", RAMP["ice"][0], base=3)
    return img


def lm_hearth(v=0) -> Img:
    """The bakery's field oven: the warm light on the cold road. v = 0 bright .. 2 banked low."""
    W, H = 60, 56
    img = Img(W, H)
    body = m_rect(W, H, 10, 22, 34, 34)
    lv = mass(img, body, "brick", "wall", RAMP["timber"][0], base=2)
    step(img, body & t_bricks(W, H, 8, 4, 10, 22), "brick", lv, -1)
    dome = m_ellipse(W, H, 27, 24, 19, 12) & m_rect(W, H, 0, 0, W, 25)
    mass(img, dome, "brick", "round", RAMP["timber"][0], base=2)
    mass(img, m_rect(W, H, 36, 2, 8, 16), "brick", "wall", RAMP["timber"][0], base=1)
    mouth = (m_ellipse(W, H, 27, 40, 10, 9) & m_rect(W, H, 0, 0, W, 41)) | m_rect(W, H, 17, 40, 20, 12)
    put(img, mouth, RAMP["fire"][0])
    put(img, m_ellipse(W, H, 27, 46, 8, 6) & mouth, RAMP["fire"][3 - v])
    if v < 2:
        put(img, m_ellipse(W, H, 27, 48, 4, 3) & mouth, RAMP["fire"][4])
    for i in range(2 if v < 2 else 1):
        put(img, m_ellipse(W, H, 42 + i * 3, -2 + 6 - i * 5 + 2, 3 + i, 2 + i), hexc("efe8d8"))
    # bread peel leaning on it
    put(img, m_line(W, H, 50, 55, 54, 24, 1.6), RAMP["wood"][2])
    mass(img, m_ellipse(W, H, 54, 21, 4, 5), "wood", "flat", RAMP["wood"][0], base=3)
    return img


def lm_stacks(v=0) -> Img:
    W, H = 70, 96
    img = Img(W, H)
    sets = ([(28, 80)], [(14, 66), (40, 92)], [(6, 58), (28, 94), (50, 72)])[v]
    mass(img, m_rect(W, H, 2, H - 16, 66, 16), "stone", "wall", RAMP["stone"][0], base=1)
    for sx, sh in sets:
        st = m_rect(W, H, sx, H - sh, 14, sh - 14)
        lv = mass(img, st, "brick", "wall", RAMP["timber"][0], base=1)
        step(img, st & t_bricks(W, H, 7, 4, sx, H - sh), "brick", lv, -1)
        mass(img, m_rect(W, H, sx - 2, H - sh - 4, 18, 5), "snow", "flat", RAMP["snow"][0], base=4)
    return img


# ---------------------------------------------------------------------------------------------------------------
# chapter 4: the nest depths (under ground: no sky, no horizon)
def far4() -> Img:
    W, H = 512, 70
    img = Img(W, H)
    paint(img, m_rect(W, H, 0, 0, W, H), "cavefar", "flat", base=1)
    xx, yy = grid(W, H)
    put(img, (yy > 34 + 5 * np.sin(xx * 2 * math.pi / 256)) , RAMP["cavefar"][2])
    # curtains of hanging hyphae, uneven length, in groups
    for i in range(30):
        sx = (i * 17 + (i * i * 7) % 23) % W
        if i % 5 == 4:
            continue
        ln = 14 + (i * 13) % 34
        put(img, m_rect(W, H, sx, 0, 2 + i % 2, ln), RAMP["cavefar"][3])
        put(img, m_rect(W, H, sx - 1, ln, 4 + i % 2, 3), RAMP["cavefar"][4])
    # breathing pores low on the wall: dark slots with one pale lip
    for i in range(9):
        px = (i * 59 + 13) % W
        py = 46 + (i * 7) % 14
        put(img, m_ellipse(W, H, px, py, 7, 3), RAMP["cavefar"][0])
        put(img, m_rect(W, H, px - 4, py - 3, 8, 1), RAMP["cavefar"][4])
    return _tile(img)


def _rib(img, x, by, lean, ramp="cavewall", top=0):
    W, H = img.w, img.h
    pts = [(x, by), (x + lean * 0.3, by - 30), (x + lean * 0.8, by - 58), (x + lean * 1.6, top)]
    m = m_curve(W, H, pts, 9, 5)
    lv = mass(img, m, ramp, "flat", RAMP[ramp][0], base=2)
    step(img, m & m_curve(W, H, [(p[0] - 2, p[1]) for p in pts], 2.0), ramp, lv, 1)
    put(img, m_ellipse(W, H, x, by, 9, 3), RAMP[ramp][1])


def mid4(chamber: bool) -> Img:
    img, top, b1, b2 = _land("cavewall", "nfloor", "nfloor", 1, 2, 1, rows=False)
    W, H = img.w, img.h
    xx, yy = grid(W, H)
    # the wall behind fills the tile up to its top (no sky in a tunnel)
    wall = ~_below(W, H, top)
    paint(img, wall, "cavewall", "flat", base=1)
    put(img, wall & (yy > top[None, :] - 6), RAMP["cavewall"][0])
    # floor veins in the middle strip
    for pts in ([(0, b1[0] + 5), (120, b1[120] + 8), (260, b1[260] + 4), (400, b1[400] + 9), (512, b1[0] + 5)],):
        put(img, m_curve(W, H, pts, 1.6) & _below(W, H, b1) & ~_below(W, H, b2), RAMP["nfloor"][3])
    if not chamber:
        for x, lean in ((40, 16), (150, -14), (176, 10), (300, 18), (410, -10), (470, 14)):
            _rib(img, x, int(top[x]) + 12, lean)
    else:
        # spore chamber: sacs hanging from above on stalks, bulbs above the unit band, a few pale pores
        for x, drop, r in ((50, 40, 12), (120, 28, 9), (210, 46, 14), (330, 34, 10), (372, 50, 13), (470, 30, 9)):
            put(img, m_rect(W, H, x - 1, 0, 3, drop - r + 2), RAMP["hypha"][1])
            bulb = m_ellipse(W, H, x, drop, r, r * 1.15)
            lv = mass(img, bulb, "gill", "round", RAMP["gill"][0], base=2)
            step(img, bulb & (m_ellipse(W, H, x - r * 0.3, drop - r * 0.4, r * 0.3, r * 0.25)), "gill", lv, 2)
            put(img, m_rect(W, H, x - 1, int(drop + r * 1.1), 3, 3), RAMP["organ"][2])
        for x, lean in ((270, -12), (430, 12)):
            _rib(img, x, int(top[x]) + 12, lean)
    return _tile(img)


def lane4(chamber: bool) -> Img:
    img = _lane(256, 60, "npath", "nfloor", veins=chamber)
    W, H = 256, 60
    # the bank under the road is flesh, not soil
    bank = m_rect(W, H, 0, 30, W, 30)
    lv = paint(img, bank, "mould", "ground", base=1)
    xx, yy = grid(W, H)
    step(img, bank & (np.sin(xx * 2 * math.pi / W * 3 + yy * 0.5) > 0.5) & (yy > 36), "mould", lv, -1)
    return _tile(img)


def enemy4(core: bool) -> Img:
    """Chapter 4 enemy side: a knotted root wall (R31-R35) or the core's cradle (R36-R40)."""
    W, H = 320, 140
    img = Img(W, H)
    B = H
    wall = m_poly(W, H, [(60, B - 22), (70, B - 96), (110, B - 126), (200, B - 138), (290, B - 126), (320, B - 100), (320, B - 22)])
    lv = mass(img, wall, "cavewall", "round", RAMP["cavewall"][0], base=2)
    for pts in ([(80, B - 40), (130, B - 90), (200, B - 110), (280, B - 96)], [(100, B - 30), (170, B - 60), (250, B - 50), (310, B - 70)]):
        step(img, wall & m_curve(W, H, pts, 3.0), "cavewall", lv, 1)
    if not core:
        for kx, ky in ((130, B - 84), (196, B - 104), (262, B - 80)):
            kn = m_ellipse(W, H, kx, ky, 12, 10)
            mass(img, kn, "gill", "round", RAMP["gill"][0], base=2)
            put(img, m_rect(W, H, kx - 2, ky - 2, 5, 4), RAMP["organ"][2])
    else:
        # a ring of ribs around a hollow; the core's light is the only bright teal in the chamber
        hollow = m_ellipse(W, H, 200, B - 76, 46, 44)
        put(img, hollow & wall, RAMP["gill"][0])
        glow = m_ellipse(W, H, 200, B - 74, 30, 30)
        paint(img, glow & wall, "organ", "round", base=1)
        put(img, m_ellipse(W, H, 192, B - 84, 9, 8) & wall, RAMP["organ"][3])
        for a in range(0, 360, 45):
            r = math.radians(a + 10)
            p0 = (200 + math.cos(r) * 52, B - 76 + math.sin(r) * 50)
            p1 = (200 + math.cos(r) * 30, B - 76 + math.sin(r) * 28)
            rib = m_curve(W, H, [p0, p1], 7, 3) & wall
            mass(img, rib, "cavewall", "flat", RAMP["cavewall"][0], base=3)
    base = m_rect(W, H, 50, B - 24, 270, 24) | m_curve(W, H, [(60, B - 10), (30, B - 6), (6, B - 2)], 12, 3)
    lvb = mass(img, base, "mould", "flat", None, base=1)
    for hx, hw in ((120, 34), (250, 40)):
        step(img, base & m_ellipse(W, H, hx, B - 26, hw, 9), "mould", lvb, 1)
    return img


def home_camp() -> Img:
    """Chapter 4 home side: the bakers' forward camp instead of the town (same slot as home_set)."""
    W, H = 320, 112
    img = Img(W, H)
    B = H
    # palisade of sharpened planks: flat through the unit band
    for x0, x1 in ((0, 110), (206, 320)):
        wall = m_rect(W, H, x0, B - 30, x1 - x0, 30)
        lv = mass(img, wall, "wood", "wall", None, base=2)
        step(img, wall & t_planks(W, H, 9, x0), "wood", lv, -1)
        for px in range(x0, x1, 9):
            put(img, m_poly(W, H, [(px, B - 30), (px + 4, B - 37), (px + 8, B - 30)]), RAMP["wood"][3])
    # supply tent
    tent = m_poly(W, H, [(30, B - 30), (62, B - 74), (96, B - 30)])
    lvt = mass(img, tent, "sack", "flat", RAMP["timber"][0], base=2)
    step(img, tent & m_poly(W, H, [(62, B - 74), (96, B - 30), (70, B - 30)]), "sack", lvt, -1)
    put(img, m_poly(W, H, [(56, B - 30), (62, B - 52), (68, B - 30)]), RAMP["timber"][0])
    mass(img, m_poly(W, H, [(60, B - 74), (62, B - 84), (74, B - 80), (63, B - 76)]), "cloth", "flat", RAMP["cloth"][0], base=3)
    # lantern posts: the only warm lights down here
    for lx in (128, 236, 290):
        paint(img, m_rect(W, H, lx, B - 70, 3, 40), "timber", "flat")
        lamp = m_rect(W, H, lx - 4, B - 80, 11, 11)
        mass(img, lamp, "iron", "flat", RAMP["iron"][0], base=1)
        put(img, m_rect(W, H, lx - 2, B - 78, 7, 7), RAMP["fire"][3])
    # crates and sacks on the wall
    for sx in (250, 262, 256):
        sy = B - 36 if sx != 256 else B - 44
        mass(img, m_ellipse(W, H, sx, sy, 6, 5), "sack", "round", RAMP["sack"][0])
    return img


def lm_pillar(v=0) -> Img:
    W, H = 64, 112
    img = Img(W, H)
    w = 15 + v * 4
    m = m_poly(W, H, [(32 - w, H), (32 - w * 0.55, H - 46), (32 - w * 0.8, 0), (32 + w * 0.8, 0), (32 + w * 0.55, H - 46), (32 + w, H)])
    lv = mass(img, m, "cavewall", "round", RAMP["cavewall"][0], base=2)
    for dx in (-4, 3):
        step(img, m & m_curve(W, H, [(32 + dx, 0), (32 + dx * 0.6, H - 50), (32 + dx * 2, H)], 1.6), "cavewall", lv, -1)
    for kx, ky in ((26, 40), (38, 72)):
        mass(img, m_ellipse(W, H, kx, ky, 4, 3), "gill", "round", RAMP["gill"][0], base=3)
    return img


def lm_burrow() -> Img:
    """A raiders' burrow in the wall: pale lip, dark hollow, scraped spoil in front."""
    W, H = 80, 56
    img = Img(W, H)
    lip = m_ellipse(W, H, 40, 34, 34, 30) & m_rect(W, H, 0, 0, W, 50)
    mass(img, lip, "hypha", "round", RAMP["hypha"][0], base=2)
    hole = m_ellipse(W, H, 40, 36, 24, 22) & m_rect(W, H, 0, 0, W, 50)
    put(img, hole, RAMP["gill"][0])
    put(img, m_ellipse(W, H, 44, 40, 14, 12) & hole, hexc("1d2a2c"))
    spoil = m_ellipse(W, H, 30, 52, 26, 5)
    mass(img, spoil, "nfloor", "flat", None, base=3)
    return img


def lm_corelight() -> Img:
    """The core's light at the end of the chamber (far layer): two soft flat bands."""
    W, H = 220, 60
    img = Img(W, H)
    put(img, m_ellipse(W, H, 110, 62, 108, 56), hexc("5d8f8a"))
    put(img, m_ellipse(W, H, 110, 64, 70, 36), hexc("7cb8ab"))
    put(img, m_ellipse(W, H, 110, 66, 34, 18), hexc("a8dcc8"))
    return img


# chapter 1 additions --------------------------------------------------------------------------------------------
def lm_shop(v=0) -> Img:
    """Village shop: 0 open and lit, 1 shut (dark windows), 2 boarded, roof sagging."""
    W, H = 64, 64
    img = Img(W, H)
    body = m_rect(W, H, 8, 28, 48, 36)
    lv = mass(img, body, "plaster", "wall", RAMP["timber"][0], base=2 if v == 0 else 1)
    for bx in (8, 30, 52):
        paint(img, m_rect(W, H, bx, 28, 4, 36), "timber", "flat")
    roof = m_poly(W, H, [(2, 30), (14, 8), (50, 8), (62, 30)]) if v < 2 else m_poly(W, H, [(2, 30), (14, 8), (30, 14), (50, 6), (62, 30)])
    lvr = mass(img, roof, "brick", "flat", RAMP["timber"][0], base=2 if v == 0 else 1)
    step(img, roof & t_shingles(W, H, 8, 5, 2, 8), "brick", lvr, -1)
    for wx in (14, 38):
        put(img, m_rect(W, H, wx, 36, 10, 11), RAMP["fire"][3] if v == 0 else hexc("4b4a55"))
        put(img, m_rect(W, H, wx + 4, 36, 1, 11), RAMP["timber"][1])
        if v == 2:
            put(img, m_line(W, H, wx - 1, 38, wx + 11, 45, 2.0), RAMP["wood"][1])
    if v == 0:
        aw = m_poly(W, H, [(10, 50), (54, 50), (58, 56), (6, 56)])
        mass(img, aw, "cloth", "flat", RAMP["cloth"][0], base=2)
        for i in range(4):
            put(img, m_rect(W, H, 14 + i * 11, 50, 5, 6) & aw, RAMP["crumb"][3])
    return img


def lm_palisade(v=0) -> Img:
    """Village palisade: 0 whole, 1 one gap with fallen stakes, 2 stumps. Flat mass below, points above."""
    W, H = 120, 44
    img = Img(W, H)
    for i in range(12):
        px = 2 + i * 10
        hgt = 34 + (i * 7) % 5
        if v == 1 and 5 <= i <= 6:
            hgt = 10
        if v == 2:
            hgt = 8 + (i * 5) % 14
        st = m_poly(W, H, [(px, H), (px, H - hgt), (px + 4, H - hgt - 6 if hgt > 20 else H - hgt), (px + 8, H - hgt), (px + 8, H)])
        lv = mass(img, st, "wood", "flat", RAMP["wood"][0], base=2)
    if v != 2:
        put(img, m_rect(W, H, 2, H - 20, 46 if v == 1 else 118, 3), RAMP["wood"][1])
    if v >= 1:
        mass(img, m_poly(W, H, [(52, H), (78, H - 8), (80, H - 4), (56, H)]), "wood", "flat", RAMP["wood"][0], base=1)
    return img


def lm_smoke(v=0) -> Img:
    W, H = 44, 84
    img = Img(W, H)
    c = hexc("d9d6cc") if v == 0 else hexc("a9a79f")
    for i in range(5):
        r = 5 + i * (1.5 if v == 0 else 2.5)
        put(img, m_ellipse(W, H, 10 + i * 6, H - 8 - i * 16, r, r * 0.7), c)
    return img


def enemy1_front() -> Img:
    """R10: the nest's wood has come all the way to the road: bigger caps, more roots than enemy_set."""
    W, H = 320, 140
    img = Img(W, H)
    B = H
    for x, h, r in ((40, 84, 20), (120, 108, 26), (210, 92, 22), (290, 112, 26)):
        put(img, m_rect(W, H, x - 3, B - h, 6, h - 20) | (m_ellipse(W, H, x, B - h, r, r * 0.6) & m_rect(W, H, 0, 0, W, B - h + 2)), hexc("93a8a2"))
    for x, h, r, d in ((70, 92, 20, 0.5), (156, 116, 26, -0.5), (240, 84, 18, 0.2), (300, 100, 20, -0.3), (22, 56, 12, 0.6), (196, 60, 11, 0.4)):
        cap_stalk(img, x, B - 22, h, r, "cap", d)
    root = m_rect(W, H, 40, B - 26, 280, 26) | m_curve(W, H, [(60, B - 12), (26, B - 8), (0, B - 2)], 14, 4)
    lv = mass(img, root, "mould", "flat", None, base=2)
    for hx, hw in ((100, 36), (200, 44), (290, 30)):
        step(img, root & m_ellipse(W, H, hx, B - 28, hw, 10), "mould", lv, -1)
    for px, py in ((150, B - 60), (236, B - 50), (76, B - 46)):
        put(img, m_rect(W, H, px, py, 4, 3), RAMP["organ"][3])
    return img


# ---------------------------------------------------------------------------------------------------------------
PAGES = {
    1: {"shop_lit": lambda: lm_shop(0), "shop_dark": lambda: lm_shop(1), "shop_boarded": lambda: lm_shop(2),
        "palisade": lambda: lm_palisade(0), "palisade_gap": lambda: lm_palisade(1), "palisade_ruin": lambda: lm_palisade(2),
        "cart": lambda: lm_cart(False), "smoke": lambda: lm_smoke(0), "smoke_dark": lambda: lm_smoke(1), "enemy_b": enemy1_front},
    2: {"far": far2, "mid_a": lambda: mid2(False), "mid_b": lambda: mid2(True), "lane_a": lambda: lane2(False), "lane_b": lambda: lane2(True),
        "enemy_a": lambda: enemy2(False), "enemy_b": lambda: enemy2(True), "gate": lm_gate, "press": lm_press,
        "cart_fallen": lambda: lm_cart(True), "cart": lambda: lm_cart(False), "crates": lm_crates},
    3: {"far": far3, "mid_a": lambda: mid3(False), "mid_b": lambda: mid3(True), "lane_a": lambda: lane3(False), "lane_b": lambda: lane3(True),
        "enemy_a": lambda: enemy3(False), "enemy_b": lambda: enemy3(True), "home_b": home_frost, "silo": lambda: lm_silo(0), "silo_tall": lambda: lm_silo(1),
        "millhall": lm_millhall, "hearth": lambda: lm_hearth(0), "hearth_low": lambda: lm_hearth(2),
        "stacks1": lambda: lm_stacks(0), "stacks2": lambda: lm_stacks(1), "stacks3": lambda: lm_stacks(2)},
    4: {"far": far4, "mid_a": lambda: mid4(False), "mid_b": lambda: mid4(True), "lane_a": lambda: lane4(False), "lane_b": lambda: lane4(True),
        "enemy_a": lambda: enemy4(False), "enemy_b": lambda: enemy4(True), "home_b": home_camp, "pillar": lambda: lm_pillar(0),
        "pillar_wide": lambda: lm_pillar(1), "burrow": lm_burrow, "corelight": lm_corelight},
}

# Sky bands per chapter: [stage, [colour x 6]] from the top band down to the horizon band (y offsets in rounds.json).
SKY_Y = [-1000, -190, -160, -134, -112, -96]
SKY = {
    1: [[0.0, ["6fa9d8", "8cc0e2", "aad3e8", "c9e2ea", "e6eedc", "f3ecd2"]], [0.5, ["79aad0", "98bfd8", "b9d2dc", "d8e0d4", "eee6c8", "f6e4b8"]],
        [0.8, ["7d8fbf", "a59fbf", "cfaeb0", "e8c29c", "f3d49a", "f6dca4"]], [1.0, ["6f8794", "8a9ea6", "a3b3b4", "b9c4bc", "cbd0c0", "d5d6c2"]]],
    2: [[0.0, ["9fb7b8", "b7c6b8", "cfd2b4", "e2dab0", "eedfae", "f3e2b0"]], [0.5, ["a2aaa4", "b6b8a8", "c9c5a8", "d8cfa8", "e2d5aa", "e8d8ae"]],
        [1.0, ["8f909a", "a69f9c", "bdab98", "cdb894", "d6c098", "dcc69e"]]],
    3: [[0.0, ["8fb0d6", "a8c3de", "c0d4e6", "d6e2ec", "e6edf0", "eef2f2"]], [0.5, ["879fc2", "9fb2cc", "b8c6d6", "ced7e0", "dde3e6", "e6eaea"]],
        [0.85, ["6f80b0", "8c90b4", "ae9fb0", "cbb0a4", "e0c09a", "ecca9c"]], [1.0, ["596a9c", "7a7ca6", "a58c9c", "cf9f86", "eab374", "f6c47a"]]],
    4: [[0.0, ["223234", "2a3c3e", "324648", "3a5052", "41595a", "465f60"]], [0.55, ["262f3a", "2f3a44", "38454e", "414f56", "49595e", "4f6064"]],
        [1.0, ["2c2a3e", "353348", "3f3d52", "49475b", "525164", "59586a"]]],
}

# Per round: front = where the land turns (fraction of the lane), enemy = which enemy-side set, landmarks =
# [frame, lane fraction, plane]; planes: "mid" stands on the field behind the units (base 40 px above the ground),
# "far" on the ridge layer, "home" beside the keep (x offset in px instead of a fraction).
ROUNDS = {
    1: (0.62, "enemy_a", []),
    2: (0.66, "enemy_a", [["shop_lit", 0.34, "mid"]]),
    3: (0.64, "enemy_a", [["shop_lit", 0.28, "mid"], ["shop_lit", 0.5, "mid"]]),
    4: (0.6, "enemy_a", [["shop_lit", 0.3, "mid"], ["shop_dark", 0.52, "mid"], ["palisade", 0.4, "mid"]]),
    5: (0.56, "enemy_a", [["shop_dark", 0.36, "mid"], ["palisade_gap", 0.48, "mid"], ["smoke", 0.54, "mid"]]),
    6: (0.52, "enemy_a", [["shop_dark", 0.26, "mid"], ["shop_dark", 0.44, "mid"], ["cart", 0.36, "mid"]]),
    7: (0.48, "enemy_a", [["palisade_gap", 0.3, "mid"], ["cart", 0.4, "mid"], ["shop_boarded", 0.44, "mid"]]),
    8: (0.44, "enemy_a", [["shop_boarded", 0.28, "mid"], ["palisade_ruin", 0.38, "mid"], ["smoke_dark", 0.4, "mid"]]),
    9: (0.38, "enemy_a", [["palisade_ruin", 0.24, "mid"], ["shop_boarded", 0.32, "mid"], ["smoke_dark", 0.34, "mid"], ["smoke_dark", 0.2, "mid"]]),
    10: (0.3, "enemy_b", [["shop_boarded", 0.2, "mid"], ["palisade_ruin", 0.27, "mid"], ["smoke_dark", 0.24, "mid"]]),
    11: (0.78, "enemy_a", [["gate", 0.22, "mid"], ["crates", 0.4, "mid"]]),
    12: (0.74, "enemy_a", [["crates", 0.28, "mid"], ["cart", 0.46, "mid"], ["crates", 0.6, "mid"]]),
    13: (0.7, "enemy_a", [["cart_fallen", 0.44, "mid"], ["crates", 0.3, "mid"]]),
    14: (0.64, "enemy_a", [["press", 0.5, "mid"], ["cart", 0.3, "mid"]]),
    15: (0.58, "enemy_a", [["press", 0.4, "mid"], ["cart_fallen", 0.52, "mid"], ["cart_fallen", 0.28, "mid"]]),
    16: (0.52, "enemy_b", [["cart_fallen", 0.3, "mid"], ["crates", 0.42, "mid"]]),
    17: (0.46, "enemy_b", [["cart_fallen", 0.3, "mid"], ["cart_fallen", 0.36, "mid"], ["gate", 0.2, "mid"]]),
    18: (0.4, "enemy_b", [["press", 0.3, "mid"], ["cart_fallen", 0.2, "mid"]]),
    19: (0.34, "enemy_b", [["cart_fallen", 0.22, "mid"], ["crates", 0.3, "mid"]]),
    20: (0.26, "enemy_b", [["cart_fallen", 0.18, "mid"]]),
    21: (0.82, "enemy_a", [["hearth", 150, "home"]]),
    22: (0.78, "enemy_a", [["hearth", 150, "home"], ["silo", 0.46, "mid"]]),
    23: (0.74, "enemy_a", [["hearth", 150, "home"], ["silo", 0.3, "mid"], ["silo_tall", 0.44, "mid"], ["silo", 0.56, "mid"]]),
    24: (0.7, "enemy_a", [["hearth", 150, "home"], ["silo_tall", 0.26, "mid"], ["millhall", 0.52, "mid"]]),
    25: (0.64, "enemy_a", [["hearth", 150, "home"], ["millhall", 0.34, "mid"], ["silo", 0.54, "mid"]]),
    26: (0.58, "enemy_b", [["hearth_low", 150, "home"], ["millhall", 0.26, "mid"], ["stacks1", 0.46, "mid"]]),
    27: (0.5, "enemy_b", [["hearth_low", 150, "home"], ["stacks2", 0.36, "mid"], ["silo_tall", 0.24, "mid"]]),
    28: (0.42, "enemy_b", [["hearth_low", 150, "home"], ["stacks2", 0.28, "mid"], ["stacks1", 0.4, "mid"]]),
    29: (0.34, "enemy_b", [["hearth_low", 150, "home"], ["stacks3", 0.26, "mid"], ["stacks1", 0.36, "mid"]]),
    30: (0.26, "enemy_b", [["hearth_low", 150, "home"], ["stacks3", 0.22, "mid"]]),
    31: (0.86, "enemy_a", []),
    32: (0.8, "enemy_a", [["pillar", 0.46, "mid"]]),
    33: (0.74, "enemy_a", [["pillar", 0.3, "mid"], ["pillar_wide", 0.56, "mid"]]),
    34: (0.66, "enemy_a", [["pillar_wide", 0.36, "mid"], ["pillar", 0.5, "mid"]]),
    35: (0.58, "enemy_a", [["pillar", 0.28, "mid"], ["pillar_wide", 0.44, "mid"], ["pillar", 0.6, "mid"]]),
    36: (0.5, "enemy_b", [["pillar", 0.3, "mid"]]),
    37: (0.42, "enemy_b", [["pillar_wide", 0.26, "mid"], ["pillar", 0.36, "mid"]]),
    38: (0.36, "enemy_b", [["burrow", 0.3, "mid"], ["burrow", 0.52, "mid"]]),
    39: (0.28, "enemy_b", [["burrow", 0.24, "mid"], ["pillar", 0.34, "mid"], ["corelight", 0.9, "far"]]),
    40: (0.18, "enemy_b", [["pillar_wide", 0.2, "mid"], ["pillar", 0.3, "mid"], ["corelight", 0.8, "far"]]),
}


def sky_of(n):
    ch = (n - 1) // 10 + 1
    st = ((n - 1) % 10) / 9.0
    keys = SKY[ch]
    for i in range(len(keys) - 1):
        if st <= keys[i + 1][0]:
            a, b = keys[i], keys[i + 1]
            t = (st - a[0]) / max(1e-6, b[0] - a[0])
            out = []
            for ca, cb in zip(a[1], b[1]):
                out.append("%02x%02x%02x" % tuple(int(round(int(ca[k:k + 2], 16) * (1 - t) + int(cb[k:k + 2], 16) * t)) for k in (0, 2, 4)))
            return out
    return keys[-1][1]


def pack(frames_im, path_png, path_json, atlas_id, w=1024):
    order = sorted(frames_im.items(), key=lambda it: (-it[1].height, -it[1].width))
    PAD = 2
    x = y = PAD
    shelf = 0
    pos = {}
    for name, im in order:
        if x + im.width + PAD > w:
            x = PAD
            y += shelf + PAD * 2
            shelf = 0
        pos[name] = (x, y)
        x += im.width + PAD * 2
        shelf = max(shelf, im.height)
    h = 1
    while h < y + shelf + PAD:
        h *= 2
    page = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    frames = {}
    for name, im in order:
        px, py = pos[name]
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            page.paste(im, (px + dx, py + dy))
        page.paste(im, (px, py))
        frames[name] = {"x": px, "y": py, "w": im.width, "h": im.height, "pivot": [im.width // 2, im.height - 1]}
    page.save(path_png)
    json.dump({"schema": "defence.atlas/1", "atlas": atlas_id, "image": os.path.basename(path_png), "size": [w, h], "padding": PAD, "extrude": 1,
               "group": "release_slice", "filter": "nearest", "mipmaps": False, "repeat": False, "gpu_format": "RGBA8", "gpu_bytes": w * h * 4,
               "frames": frames, "anims": {}}, open(path_json, "w", encoding="utf-8"), indent=1)
    return w, h


def main():
    os.makedirs(OUT, exist_ok=True)
    for ch, pieces in PAGES.items():
        ims = {name: fn().pil() for name, fn in pieces.items()}
        if "mid_b" in pieces:
            ims["mid_edge"] = _edge(pieces["mid_b"]()).pil()
            ims["lane_edge"] = _lane_edge(pieces["lane_b"]()).pil()
        w, h = pack(ims, os.path.join(OUT, f"slice_ch{ch}.png"), os.path.join(OUT, f"slice_ch{ch}.json"), f"release_slice_ch{ch}")
        print(f"chapter {ch}: {w}x{h}, {len(ims)} frames")
    far_fill = {}
    for ch, fn in ((1, far1), (2, far2), (3, far3), (4, far4)):
        row = fn().a[-1]
        cols, counts = np.unique(row[row[:, 3] > 0][:, :3], axis=0, return_counts=True)
        far_fill[str(ch)] = "%02x%02x%02x" % tuple(int(v) for v in cols[counts.argmax()])
    rounds = {}
    for n, (front, enemy, lms) in ROUNDS.items():
        ch = (n - 1) // 10 + 1
        for lm in lms:
            assert lm[0] in PAGES[ch], f"r{n:02d}: landmark {lm[0]} is not on page {ch}"
        rounds[f"{n}"] = {"chapter": ch, "sky": [[c, y] for c, y in zip(sky_of(n), SKY_Y)], "front": front, "enemy": enemy,
                          "home": "home_b" if ch >= 3 else "home_set", "clouds": ch < 4, "forecourt": ch < 4, "landmarks": lms}
    json.dump({"note": "per-round composition for src/art_preview/slice_backdrop.gd; generated by tools/art/release_slice/chapters.py",
               "soil": {"1": "6a4e38", "2": "6a4e38", "3": "5c5448", "4": "24383c"}, "far_fill": far_fill, "rounds": rounds},
              open(os.path.join(OUT, "rounds.json"), "w", encoding="utf-8"), indent=1)
    print("rounds.json:", len(rounds), "rounds")


if __name__ == "__main__":
    main()
