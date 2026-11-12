"""Battlefield set for the slice: one place read left to right as bakery town -> open wheat -> the mould's wood.

Pieces (all 1 art px = 1 world px; scenery contours use the material's own dark step, never the sprite ink):
    far         512x70 tile   two hazy ridges with a far village (steeple, mill) - parallax layer
    mid_home    512x76 tile   wheat and pasture strips divided by hedges, an uneven windbreak, stooks
    mid_blight  512x76 tile   the same land taken: grey fields, bare trees, first caps
    mid_edge    120x76        the ragged front where the blight crosses the fields (drawn over the join)
    lane / lane_blight 128x60 tiles; lane_home 192x60 (cobbled forecourt)
    home_set    320x112       wall, annex, cart and trees around the bakery (world-locked, behind the units)
    enemy_set   320x124       stalks, great roots and hanging hyphae around the nest
    mill        112x112       the flour mill the bakers walk to (bakery_supply draws it)
    cloud_a/b/c
The lower 44 px of every piece that stands behind the units is a calm, flat mass: detail starts above it.
"""
from __future__ import annotations

import math

import numpy as np

from lib import (RAMP, Img, grid, grow, hexc, m_curve, m_ellipse, m_line, m_poly, m_rect, mass, paint, put, rim, shift, step,
                 t_bricks, t_planks, t_rows, t_scores, t_shingles, t_spots)


def _profile(w, base, amps, period=512):
    """Periodic height profile: base + sum(a * sin(2 pi k x / period + phase))."""
    x = np.arange(w)
    y = np.full(w, float(base))
    for k, a, ph in amps:
        y += a * np.sin(2 * math.pi * k * x / period + ph)
    return y


def _below(w, h, prof):
    _, yy = grid(w, h)
    return yy >= np.round(prof)[None, :]


def tree(img, x, by, hgt, ramp="leaf", trunk="wood", lean=0):
    W, H = img.w, img.h
    tr = m_poly(W, H, [(x - 2, by), (x - 1 + lean, by - hgt * 0.55), (x + 2 + lean, by - hgt * 0.55), (x + 3, by)])
    mass(img, tr, trunk, "flat", RAMP[trunk][0], base=1)
    r = hgt * 0.34
    can = (m_ellipse(W, H, x + lean, by - hgt * 0.72, r * 1.25, r) | m_ellipse(W, H, x + lean - r * 0.8, by - hgt * 0.55, r * 0.8, r * 0.7)
           | m_ellipse(W, H, x + lean + r * 0.9, by - hgt * 0.58, r * 0.85, r * 0.75))
    lv = mass(img, can, ramp, "round", RAMP[ramp][0])
    # leaf clusters: a few lighter lumps on the lit side
    lumps = m_ellipse(W, H, x + lean - r * 0.5, by - hgt * 0.82, r * 0.45, r * 0.3) | m_ellipse(W, H, x + lean + r * 0.5, by - hgt * 0.68, r * 0.4, r * 0.25)
    step(img, can & lumps, ramp, lv, 1)


def bare_tree(img, x, by, hgt, ramp="hypha"):
    W, H = img.w, img.h
    m = m_curve(W, H, [(x, by), (x + 1, by - hgt * 0.5), (x - 1, by - hgt)], 4, 1.5)
    m |= m_curve(W, H, [(x + 1, by - hgt * 0.45), (x + hgt * 0.3, by - hgt * 0.75), (x + hgt * 0.34, by - hgt * 0.95)], 2.4, 1.2)
    m |= m_curve(W, H, [(x, by - hgt * 0.6), (x - hgt * 0.28, by - hgt * 0.8), (x - hgt * 0.4, by - hgt * 0.78)], 2.2, 1.2)
    mass(img, m, ramp, "flat", RAMP[ramp][0], base=1)


def cap_stalk(img, x, by, hgt, r, ramp="cap", droop=0.0, ink=None):
    W, H = img.w, img.h
    ink = RAMP[ramp][0] if ink is None else ink
    st = m_curve(W, H, [(x, by), (x + droop * 3, by - hgt * 0.5), (x + droop * 6, by - hgt + 2)], max(2.5, r * 0.34), max(2.0, r * 0.22))
    mass(img, st, "hypha", "flat", RAMP["hypha"][0], base=2)
    cx, cy = x + droop * 6, by - hgt
    cap = m_ellipse(W, H, cx, cy + 1, r, r * 0.62) & m_rect(W, H, 0, 0, W, int(cy + 2))
    cap |= m_poly(W, H, [(cx - r, cy + 1), (cx - r * 0.5, cy + 1), (cx - r * 0.8, cy + 1 + r * 0.4 * (1 + droop))])     # one drooping lip
    gl = shift(cap, 0, 2) & ~cap
    put(img, gl, RAMP["gill"][1])
    lv = mass(img, cap, ramp, "round", ink)
    step(img, cap & m_ellipse(W, H, cx - r * 0.3, cy - r * 0.3, r * 0.3, r * 0.14), ramp, lv, 1)


# ---------------------------------------------------------------------------------------------------------------
def far() -> Img:
    W, H = 512, 70
    img = Img(W, H)
    back = _below(W, H, _profile(W, 26, [(1, 9, 0.4), (2, 5, 1.9), (5, 2, 0.3)]))
    lv = paint(img, back, [hexc(c) for c in ("9db8bf", "aec7c6", "bfd4cb", "cfdfd2", "deebdc")], "flat", base=2)
    front = _below(W, H, _profile(W, 40, [(1, 7, 2.4), (3, 4, 0.2), (4, 2, 1.1)]))
    # far village on the saddle of the back ridge: steeple, mill, a few roofs (one value, no detail)
    vil = np.zeros((H, W), bool)
    vx, vy = 150, 30
    vil |= m_rect(W, H, vx, vy - 14, 5, 16) | m_poly(W, H, [(vx - 1, vy - 14), (vx + 2.5, vy - 22), (vx + 6, vy - 14)])
    for i, (dx, w, h) in enumerate(((-22, 12, 7), (-8, 10, 6), (10, 13, 8), (26, 9, 6))):
        vil |= m_rect(W, H, vx + dx, vy - h, w, h + 3) | m_poly(W, H, [(vx + dx - 2, vy - h), (vx + dx + w / 2, vy - h - 5), (vx + dx + w + 2, vy - h)])
    mx = 372
    vil |= m_poly(W, H, [(mx - 4, 34), (mx - 2, 20), (mx + 3, 20), (mx + 5, 34)])
    vil |= m_line(W, H, mx - 9, 12, mx + 10, 26, 1.6) | m_line(W, H, mx + 9, 12, mx - 8, 26, 1.6)
    put(img, vil & ~front, hexc("8fa9b2"))
    lv2 = paint(img, front, "hill", "flat", base=3)
    # field patches on the near ridge: three broad lighter strips that follow the slope
    prof = _profile(W, 40, [(1, 7, 2.4), (3, 4, 0.2), (4, 2, 1.1)])
    xx, yy = grid(W, H)
    for off, wid, ph in ((8, 5, 0.0), (19, 6, 1.3)):
        band = (yy >= prof[None, :] + off) & (yy < prof[None, :] + off + wid) & (np.sin(xx * 2 * math.pi / 256 + ph) > -0.2)
        step(img, front & band, "hill", lv2, 1)
    # hedge dots along the crest, unevenly spaced
    for i in range(22):
        hx = (i * 23 + (i * i * 7) % 17) % W
        hy = prof[hx] - 1
        put(img, m_ellipse(W, H, hx, hy, 3 + i % 3, 2 + i % 2), RAMP["hill"][1])
    return img


def _fields(W, H, blight: bool) -> Img:
    img = Img(W, H)
    xx, yy = grid(W, H)
    top = _profile(W, 26, [(1, 4, 0.9), (2, 2.5, 2.2)])                 # field horizon (trees rise above it)
    land = _below(W, H, top)
    RAMP.setdefault("deadwheat", [hexc(c) for c in ("6c6a52", "878463", "a39f7a", "bcb893", "d1cdab")])
    r_a = "deadwheat" if blight else "wheat"
    r_b = "blight" if blight else "grass"
    paint(img, land, r_b, "flat", base=2)
    # strips: boundaries are slanted curves, so the land reads as rolling, not as stacked bands
    b1 = top + 9 + 3 * np.sin(xx[0] * 2 * math.pi / 512 + 0.5)
    b2 = top + 20 + 4 * np.sin(xx[0] * 2 * math.pi / 256 + 2.0)
    wheat = land & (yy >= b1[None, :]) & (yy < b2[None, :])
    lvw = paint(img, wheat, r_a, "flat", base=2)
    # furrows fan out from a vanishing point above the tile
    vx = 256.0
    ang = np.arctan2(yy + 60.0, xx - vx)
    rows = (np.floor(ang * 46.0) % 2 == 0)
    step(img, wheat & rows, r_a, lvw, 1 if not blight else -1)
    step(img, wheat & (yy < b1[None, :] + 2), r_a, lvw, 1)
    far_strip = land & (yy < b1[None, :])
    lvf = paint(img, far_strip, r_b, "flat", base=3)
    step(img, far_strip & (np.floor((xx + yy * 3) / 40.0) % 2 == 0), r_b, lvf, -1)
    # the near field, right behind the units: one calm mass with two very broad value patches
    near = land & (yy >= b2[None, :])
    lvn = paint(img, near, r_b, "flat", base=2)
    step(img, near & (np.sin(xx * 2 * math.pi / 512 + 1.0) + (yy - 50) * 0.03 > 0.55), r_b, lvn, 1)
    # hedge along the wheat's lower boundary: lumps of uneven size with gaps
    for i in range(30):
        hx = (i * 19 + (i * i * 5) % 13) % W
        if (i % 7) in (3, 4):
            continue
        hy = b2[hx]
        hm = m_ellipse(W, H, hx, hy, 5 + i % 4, 3 + i % 2)
        mass(img, hm, "hedge" if not blight else "mould", "round", None, base=1 if not blight else 3)
    return img, top, b1, b2


def mid_home() -> Img:
    img, top, b1, b2 = _fields(512, 76, False)
    # an uneven windbreak: a cluster of three, a pair, a single tall one
    for x, h, lean in ((52, 30, 0), (70, 24, 1), (84, 34, -1), (238, 28, 0), (256, 22, 1), (398, 36, 0), (470, 20, 0)):
        tree(img, x, int(top[x]) + 4, h, "leaf", "wood", lean)
    # wheat stooks standing in the strip
    for x in (150, 176, 320, 344, 366):
        y = int((b1[x] + b2[x]) * 0.5) + 3
        st = m_poly(512, 76, [(x - 4, y), (x - 1, y - 9), (x + 2, y - 9), (x + 5, y)])
        mass(img, st, "wheat", "flat", RAMP["wheat"][0], base=3)
    # a field barn with a red roof far in the strip
    bx, by = 300, int(top[300]) + 3
    barn = m_rect(512, 76, bx, by - 10, 18, 11)
    mass(img, barn, "plaster", "wall", RAMP["plaster"][0], base=2)
    roof = m_poly(512, 76, [(bx - 2, by - 10), (bx + 4, by - 18), (bx + 14, by - 18), (bx + 20, by - 10)])
    mass(img, roof, "brick", "flat", RAMP["brick"][0], base=2)
    return img


def mid_blight() -> Img:
    img, top, b1, b2 = _fields(512, 76, True)
    for x, h in ((40, 28), (120, 22), (300, 30), (452, 24)):
        bare_tree(img, x, int(top[x]) + 4, h)
    for x, h, r, d in ((84, 26, 9, 0.6), (190, 34, 12, -0.4), (212, 20, 7, 0.3), (364, 30, 10, 0.5), (486, 22, 8, -0.3)):
        cap_stalk(img, x, int(top[x]) + 5, h, r, "cap", d)
    return img


def mid_edge() -> Img:
    """The front of the blight. The piece is the blighted field itself (the 60 columns either side of the tile
    join), cut along a ragged line, so it continues the tile to its right exactly; pale fingers reach further left."""
    W, H = 120, 76
    tile = mid_blight()
    tile.a[:, 0] = tile.a[:, 1]             # same border fix as the tile in the atlas (_tile)
    tile.a[:, -1] = tile.a[:, -2]
    img = Img(W, H)
    img.a[:, 60:] = tile.a[:, :60]
    img.a[:, :60] = tile.a[:, 452:512]
    xx, yy = grid(W, H)
    edge = 56 + 20 * np.sin(yy * 0.21) + 9 * np.sin(yy * 0.53 + 1.0) - (yy - 26) * 0.5
    img.a[xx < edge] = (0, 0, 0, 0)
    for y0, ln in ((36, 30), (47, 44), (58, 26), (68, 36)):
        finger = m_curve(W, H, [(edge[y0, 0] + 4, y0), (edge[y0, 0] - ln * 0.5, y0 + 2), (edge[y0, 0] - ln, y0 - 1)], 3.4, 1.2)
        paint(img, finger, "hypha", "flat", base=3)
    return img


def _lane(W, H, path_ramp, grass_ramp, veins=False) -> Img:
    img = Img(W, H)
    xx, yy = grid(W, H)
    # soil bank under the road
    bank = m_rect(W, H, 0, 28, W, H - 28)
    lvb = paint(img, bank, "earth", "ground", base=1)
    step(img, bank & (np.sin(xx * 2 * math.pi / W * 2 + yy * 0.4) > 0.6) & (yy > 34), "earth", lvb, -1)
    # the road: lit lip at the far edge, a dark cut at the near edge, two shallow ruts, a few flat stones
    road = m_rect(W, H, 0, 6, W, 23)
    lvr = paint(img, road, path_ramp, "ground", base=2)
    step(img, road & (yy >= 26), path_ramp, lvr, -2)
    for ry in (14, 21):
        rut = road & (yy == ry) & (((xx + ry * 5) % 37) < 24)
        step(img, rut, path_ramp, lvr, -1)
    for sx, sy, sw in ((14, 10, 6), (58, 18, 8), (92, 9, 5), (110, 23, 6), (36, 24, 5), (150, 12, 7), (188, 22, 5), (214, 9, 6), (240, 19, 8), (170, 25, 4)):
        if sx >= W:
            continue
        st = m_ellipse(W, H, sx, sy, sw / 2, 1.6)
        step(img, st & road, path_ramp, lvr, 1)
        step(img, shift(st, 0, 1) & ~st & road, path_ramp, lvr, -1)
    if veins:
        for pts in ([(0, 12), (30, 9), (64, 13), (100, 10), (140, 12), (200, 9), (256, 12)], [(20, 22), (50, 19), (84, 23), (128, 20), (190, 24), (236, 20)], [(64, 13), (70, 18), (84, 23)], [(200, 9), (208, 16), (190, 24)]):
            put(img, m_curve(W, H, pts, 1.6, 1.2) & road, RAMP["hypha"][3])
    # verge: tufts of uneven height along the far edge of the road
    verge = m_rect(W, H, 0, 4, W, 4)
    for i in range(W // 8):
        tx = (i * 9 + (i * i * 3) % 7) % W
        th = 2 + (i * 5) % 4
        verge |= m_poly(W, H, [(tx - 3, 6), (tx, 6 - th - 2), (tx + 3, 6)])
    mass(img, verge, grass_ramp, "flat", None, base=1 if grass_ramp == "grass" else 0)
    put(img, verge & shift(verge, 0, 1) & ~shift(verge, 0, -1), RAMP[grass_ramp][0])
    # grass creeping over the bank's top edge
    for i in range(W // 14):
        gx = (i * 15 + (i * i * 4) % 11) % W
        clump = m_ellipse(W, H, gx, 30, 5 + i % 3, 2.5)
        paint(img, clump, grass_ramp, "flat", base=1 if grass_ramp == "grass" else 0)
    return img


def lane() -> Img:
    return _lane(256, 60, "path", "grass")


def lane_blight() -> Img:
    grey = [hexc(c) for c in ("7f7a6c", "979282", "afa998", "c4beac", "d6d1bf")]
    RAMP["path_grey"] = grey
    return _lane(256, 60, "path_grey", "blight", veins=True)


def lane_edge() -> Img:
    """Where the grey road starts: the last 64 columns before a lane_blight tile, cut along a ragged diagonal."""
    W, H = 64, 60
    tile = lane_blight()
    tile.a[:, -1] = tile.a[:, -2]
    img = Img(W, H)
    img.a[:, :] = tile.a[:, 192:256]
    xx, yy = grid(W, H)
    edge = 40 - (yy - 6) * 0.9 + 6 * np.sin(yy * 0.6)
    img.a[xx < edge] = (0, 0, 0, 0)
    return img


def lane_home() -> Img:
    """Cobbled forecourt of the bakery: same road profile, stone setts instead of packed earth."""
    W, H = 192, 60
    img = _lane(W, H, "path", "grass")
    xx, yy = grid(W, H)
    setts = m_rect(W, H, 0, 6, W, 21) & (xx < 168 - (yy - 6) * 0.8)
    lv = paint(img, setts, "stone", "ground", base=3)
    step(img, setts & t_bricks(W, H, 10, 5, 0, 6), "stone", lv, -1)
    step(img, setts & (yy >= 24), "stone", lv, -1)
    # flour dusted by the door
    put(img, m_ellipse(W, H, 96, 15, 16, 3) & setts, RAMP["crumb"][3])
    return img


def home_set() -> Img:
    """Around the bakery. Bottom row sits on the far edge of the road (world y = ground - 10)."""
    W, H = 320, 112
    img = Img(W, H)
    B = H                         # base line
    # back trees, uneven
    for x, h, lean in ((18, 46, 0), (40, 34, 1), (232, 40, -1), (300, 30, 0)):
        tree(img, x, B - 30, h, "hedge", "wood", lean)
    # the annex: a low bake house with a tiled roof and a lit window, left of the keep
    ann = m_rect(W, H, 52, B - 62, 60, 40)
    lv = mass(img, ann, "plaster", "wall", RAMP["timber"][0])
    for bx in (52, 80, 108):
        paint(img, m_rect(W, H, bx, B - 62, 4, 40), "timber", "flat")
    roof = m_poly(W, H, [(46, B - 62), (58, B - 86), (106, B - 86), (118, B - 62)])
    lvr = mass(img, roof, "brick", "flat", RAMP["timber"][0], base=2)
    step(img, roof & t_shingles(W, H, 8, 5, 46, B - 86), "brick", lvr, -1)
    win = m_rect(W, H, 62, B - 54, 12, 12)
    paint(img, win, "timber", "flat", base=1)
    put(img, m_rect(W, H, 64, B - 52, 8, 8), RAMP["fire"][3])
    put(img, m_rect(W, H, 67, B - 52, 1, 8), RAMP["timber"][1])
    # bread rack under the eaves: three loaves on a shelf
    paint(img, m_rect(W, H, 86, B - 46, 20, 2), "wood", "flat")
    for lx in (88, 95, 102):
        mass(img, m_ellipse(W, H, lx + 1.5, B - 49, 3, 2.5), "crust", "round", RAMP["crust"][0], base=3)
    # the yard wall: one flat stone mass through the unit band, capped; a gate gap by the keep
    for x0, x1 in ((0, 118), (206, 320)):
        wall = m_rect(W, H, x0, B - 26, x1 - x0, 26)
        lvw = mass(img, wall, "stone", "wall", None, base=3)
        step(img, wall & t_bricks(W, H, 14, 7, x0, B - 26) & m_rect(W, H, 0, B - 26, W, 12), "stone", lvw, -1)
        capm = m_rect(W, H, x0, B - 29, x1 - x0, 4)
        mass(img, capm, "stone", "flat", None, base=4)
        put(img, m_rect(W, H, x0, B - 25, x1 - x0, 1), RAMP["stone"][1])
    # market cart with bread by the gate (above the unit band)
    cart = m_rect(W, H, 226, B - 44, 34, 12)
    lvc = mass(img, cart, "wood", "flat", RAMP["wood"][0], base=2)
    step(img, cart & t_planks(W, H, 6, 226), "wood", lvc, -1)
    for wx in (232, 252):
        wheel = m_ellipse(W, H, wx, B - 30, 5, 5)
        mass(img, wheel, "timber", "round", RAMP["timber"][0], base=2)
        put(img, m_ellipse(W, H, wx, B - 30, 1.5, 1.5), RAMP["iron"][3])
    for lx, ly in ((231, 47), (239, 48), (247, 47), (254, 48), (235, 51), (244, 52)):
        mass(img, m_ellipse(W, H, lx, B - ly, 4, 3), "crust", "round", RAMP["crust"][0], base=3)
    aw = m_poly(W, H, [(222, B - 62), (264, B - 62), (268, B - 55), (218, B - 55)])
    mass(img, aw, "cloth", "flat", RAMP["cloth"][0], base=2)
    for i in range(4):
        put(img, m_rect(W, H, 226 + i * 11, B - 62, 5, 7) & aw, RAMP["crumb"][3])
    for px in (224, 262):
        paint(img, m_rect(W, H, px, B - 56, 2, 14), "timber", "flat")
    # lamp post at the far right: the last warm light before the open field
    paint(img, m_rect(W, H, 292, B - 58, 3, 32), "iron", "flat", base=1)
    lamp = m_rect(W, H, 288, B - 68, 11, 11)
    mass(img, lamp, "iron", "flat", RAMP["iron"][0], base=1)
    put(img, m_rect(W, H, 290, B - 66, 7, 7), RAMP["fire"][3])
    # flour sacks stacked on the wall cap
    for sx in (130, 139, 134):
        sy = B - 33 if sx != 134 else B - 40
        mass(img, m_ellipse(W, H, sx, sy, 5, 4), "sack", "round", RAMP["sack"][0])
    return img


def enemy_set() -> Img:
    """Around the nest: the wood the mould grew, and the roots it sends down the road."""
    W, H = 320, 124
    img = Img(W, H)
    B = H
    # hazy back row of caps (one value)
    for x, h, r in ((30, 60, 14), (96, 84, 20), (170, 70, 16), (250, 96, 24), (300, 58, 12)):
        st = m_rect(W, H, x - 2, B - h, 5, h - 20)
        capm = m_ellipse(W, H, x, B - h, r, r * 0.6) & m_rect(W, H, 0, 0, W, B - h + 2)
        put(img, st | capm, hexc("9fb3ac"))
    # the nest's own stalks, uneven heights, two drooping
    for x, h, r, d in ((58, 70, 15, 0.5), (132, 96, 20, -0.5), (206, 64, 13, 0.2), (282, 86, 18, -0.3), (20, 44, 9, 0.6)):
        cap_stalk(img, x, B - 22, h, r, "cap", d)
    # hanging hyphae from the big caps
    for x, y, ln in ((120, B - 110, 22), (146, B - 108, 14), (270, B - 100, 18), (294, B - 98, 12)):
        put(img, m_rect(W, H, x, y, 2, ln), RAMP["hypha"][2])
        put(img, m_rect(W, H, x - 1, y + ln, 4, 3), RAMP["hypha"][3])
    # root mass through the unit band: flat, mid value; its fingers run left along the road edge
    root = m_rect(W, H, 70, B - 24, 250, 24)
    xx, yy = grid(W, H)
    root |= (yy >= B - 30 - 6 * np.sin(xx * 0.05)) & (xx >= 96)
    root |= m_curve(W, H, [(80, B - 10), (40, B - 8), (14, B - 3), (0, B - 1)], 12, 3)
    root |= m_curve(W, H, [(90, B - 22), (56, B - 18), (30, B - 12)], 8, 2.5)
    lv = mass(img, root, "mould", "flat", None, base=2)
    for hx, hw in ((120, 30), (190, 40), (268, 34)):
        step(img, root & m_ellipse(W, H, hx, B - 26, hw, 9), "mould", lv, -1)
    for pts in ([(100, B - 18), (150, B - 14), (210, B - 20), (300, B - 12)], [(60, B - 8), (120, B - 6), (200, B - 9), (320, B - 5)]):
        step(img, root & m_curve(W, H, pts, 2.0), "mould", lv, 1)
    # great roots arching over the mass (above the band)
    def _arc(x0, x1, top, n=9):
        return [(x0 + (x1 - x0) * i / n, B - 22 - (top - 22) * math.sin(math.pi * i / n) ** 0.8) for i in range(n + 1)]
    for pts, t0 in ((_arc(112, 186, 58), 7), (_arc(214, 278, 46), 6)):
        arch = m_curve(W, H, pts, t0, t0 * 0.7)
        mass(img, arch, "hypha", "round", RAMP["hypha"][0], base=2)
    # pale pores: a few, on the arches only
    for px, py in ((140, B - 52), (166, B - 50), (244, B - 44)):
        put(img, m_rect(W, H, px, py, 3, 3), RAMP["organ"][3])
    return img


def mill() -> Img:
    """Flour mill, 112x112, base centre (56, 111): the same slot bakery_supply used for the old mill."""
    W, H = 112, 112
    img = Img(W, H)
    tower = m_poly(W, H, [(38, 111), (44, 44), (68, 44), (74, 111)])
    lv = mass(img, tower, "plaster", "wall", hexc("4a3a34"))
    step(img, tower & t_bricks(W, H, 12, 7, 38, 44) & m_rect(W, H, 0, 84, W, 28), "plaster", lv, -1)
    paint(img, m_rect(W, H, 40, 72, 32, 3) & tower, "timber", "flat")
    capm = m_poly(W, H, [(40, 46), (46, 26), (66, 26), (72, 46)])
    lvc = mass(img, capm, "wood", "flat", hexc("4a3a34"), base=2)
    step(img, capm & t_shingles(W, H, 7, 5, 40, 26), "wood", lvc, -1)
    door = m_rect(W, H, 50, 92, 12, 19) | m_ellipse(W, H, 56, 92, 6, 5)
    mass(img, door & tower, "wood", "flat", None, base=1)
    win = m_rect(W, H, 52, 54, 8, 9)
    put(img, win, hexc("5a6a78"))
    rim(img, win, RAMP["timber"][1])
    # sails: four lattice arms from the hub
    hub = (56, 42)
    for k in range(4):
        a = math.radians(24 + k * 90)
        dx, dy = math.cos(a), math.sin(a)
        tip = (hub[0] + dx * 40, hub[1] + dy * 40)
        arm = m_line(W, H, hub[0], hub[1], tip[0], tip[1], 2.2)
        nx, ny = -dy, dx
        sail = m_poly(W, H, [(hub[0] + dx * 10, hub[1] + dy * 10), (tip[0], tip[1]), (tip[0] + nx * 9, tip[1] + ny * 9), (hub[0] + dx * 12 + nx * 9, hub[1] + dy * 12 + ny * 9)])
        lvs = mass(img, sail, "crumb", "flat", hexc("4a3a34"), base=2)
        xx, yy = grid(W, H)
        lat = (np.floor(((xx - hub[0]) * dx + (yy - hub[1]) * dy) / 6.0) % 2 == 0)
        step(img, sail & lat, "crumb", lvs, -1)
        mass(img, arm, "timber", "flat", hexc("4a3a34"), base=1)
    mass(img, m_ellipse(W, H, hub[0], hub[1], 3.5, 3.5), "iron", "round", hexc("4a3a34"))
    return img


def cloud(w, h, seed) -> Img:
    img = Img(w, h)
    rng = np.random.default_rng(seed)
    m = m_rect(w, h, 4, h - 6, w - 8, 4)
    n = max(3, w // 14)
    for i in range(n):
        cx = 8 + (w - 16) * (i + 0.5) / n + rng.integers(-2, 3)
        r = h * (0.32 + 0.22 * math.sin(i * 1.7 + seed)) + 2
        m |= m_ellipse(w, h, cx, h - 6 - r * 0.45, r * 1.25, r)
    m &= m_rect(w, h, 0, 0, w, h - 2)
    put(img, m, hexc("fbf7ea"))
    put(img, m & ~shift(m, 0, -2), hexc("dfe7e6"))          # flat grey belly
    put(img, m & ~shift(m, 1, 1) & shift(m, 0, -2), hexc("ffffff"))
    return img


def _tile(fn):
    def make():
        im = fn()
        im.a[:, 0] = im.a[:, 1]
        im.a[:, -1] = im.a[:, -2]
        return im
    return make


PIECES = {
    "far": _tile(far), "mid_home": _tile(mid_home), "mid_blight": _tile(mid_blight), "mid_edge": mid_edge, "lane": _tile(lane), "lane_blight": _tile(lane_blight),
    "lane_home": lane_home, "lane_edge": lane_edge, "home_set": home_set, "enemy_set": enemy_set, "mill": mill,
    "cloud_a": lambda: cloud(72, 24, 1), "cloud_b": lambda: cloud(48, 18, 2), "cloud_c": lambda: cloud(96, 28, 3),
}
