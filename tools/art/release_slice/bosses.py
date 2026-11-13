"""Six bosses, each its own creature (before: two drawings, recoloured for four of them).
Contracts copied from assets/atlases/char_boss_warlord.json / char_boss_overlord.json:
    64x64 pivot (28,63)  idle4 walk6 attack6(hit 3) hit2 death7            boss_warlord, boss_millward, boss_frostguard
    88x80 pivot (36,79)  idle4 walk6 attack6(hit 3) summon6(spawn 3) hit2 death8   boss_overlord, boss_rootking, boss_ovenheart
Design rules taken from lane / tower-defence bosses that read well on a phone (big, simple silhouette; one glowing
weak point; a wind-up you can see a beat before the hit; a personality gag), applied to this game's mould-vs-bakery world:
    boss_warlord    곰팡이 장군      R05/R10  mushroom general: plumed cap, epaulettes, rusty cleaver, overhead chop
    boss_millward   제분장 파수꾼    R15      millstone golem: its face is the stone's eye-hole, mill sails spin on its back
    boss_frostguard 서리 방벽        R25      mould frozen inside an ice suit, icicle crown, tower shield bash
    boss_overlord   부패 대군주      R10      mushroom king: robe, tarnished crown on the cap, spore-orb staff
    boss_rootking   뿌리 왕          R20      rotten apple tree: carved face, root legs, branch arm, roots burst on summon
    boss_ovenheart  화덕 심장        R30      oven golem: chimney head, chest door opens on a corrupted heart, bread-peel arm
python tools/art/release_slice/bosses.py [--sheet <png>]   writes assets/art/release_slice/slice_bosses.{png,json}
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import INK_MOULD, RAMP, Img, grow, hexc, m_curve, m_ellipse, m_line, m_poly, m_rect, mass, put, shift, step  # noqa: E402
from chars import ARC_FOE, _ang, eye  # noqa: E402

RAMP["ice"] = [hexc(c) for c in ("4f7ea6", "6fa3c8", "97c6e2", "c4e2f2", "eef9ff")]
RAMP["bark"] = [hexc(c) for c in ("2f2a2a", "463b36", "5f4e44", "7a6656", "988270")]
RAMP["apple"] = [hexc(c) for c in ("4a1f24", "702b2c", "94403a", "b45f4a", "d08968")]
RAMP["gold"] = [hexc(c) for c in ("6a5228", "8f7236", "b4964a", "d2b867", "ecd99a")]
RAMP["robe"] = [hexc(c) for c in ("2a1f36", "3d2c4e", "554068", "70588a", "9076aa")]
INK = INK_MOULD
GLOW = RAMP["organ"]


def glow_eye(img, x, y, on=True, w=2, h=2):
    if on:
        put(img, m_rect(img.w, img.h, x, y, w, h), GLOW[3])
        put(img, m_rect(img.w, img.h, x, y, 1, 1), GLOW[4])
    else:
        put(img, m_rect(img.w, img.h, x, y + h - 1, w + 1, 1), INK)


def spores(img, cx, cy, n, r, seed, col=None):
    rng = np.random.default_rng(seed)
    for _ in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(r * 0.4, r)
        x, y = cx + math.cos(a) * d, cy + math.sin(a) * d * 0.8
        m = m_ellipse(img.w, img.h, x, y, 1.2, 1.2) & (img.a[..., 3] == 0)
        put(img, m, col or GLOW[3])


def crumble(img: Img, t: float, seed: int, sink: int = 10) -> Img:
    """Boss death: the body sags, loses pixels from the top down and puffs into spores."""
    out = Img(img.w, img.h)
    a = img.a.copy()
    h = img.h
    rng = np.random.default_rng(seed)
    ys = np.arange(h)[:, None]
    top = np.where(a[..., 3].any(axis=1))[0]
    y0 = top.min() if len(top) else 0
    frac = (ys - y0) / max(1, h - y0)                  # 0 at the top of the figure, 1 at the feet
    gone = rng.random(a.shape[:2]) < np.clip(t * 1.6 - frac * 0.9, 0, 1)
    a[gone] = 0
    dy = int(round(t * sink))
    if dy:
        a = np.concatenate([np.zeros((dy, img.w, 4), np.uint8), a[:-dy]])
        a[-1] = np.where(img.a[-1][..., 3:4] > 0, img.a[-1], a[-1])
    out.a = a
    if 0.1 < t < 0.95:
        spores(out, img.w * 0.45, h - 18 - t * 10, int(6 + t * 14), 10 + t * 16, seed + 7, GLOW[2])
    return out


# ------------------------------------------------------------------------------------------------ 64 x 64
def general(b=0, lean=0, legs=((0, 0), (0, 0)), hand=(44, 44), blade=-72.0, eyes=True, arc=None, cape=0):
    W = H = 64
    img = Img(W, H)
    cx = 28 + lean * 0.5
    hx = 28 + lean
    cp = m_poly(W, H, [(hx - 8, 34 + b), (hx - 2, 34 + b), (cx - 4, 60), (cx - 17 - cape, 60), (cx - 14 - cape, 46 + b)])
    mass(img, cp, "robe", "flat", INK, base=2)
    for i, (off, lift) in enumerate(legs):
        lx = int(round(22 + i * 9 + off))
        m = m_rect(W, H, lx, 52 + b, 5, 12 - b - lift - 2) | m_rect(W, H, lx - 1, 60 - lift, 8, 3)
        mass(img, m, "bark", "flat", INK, base=1 + i)
    body = m_ellipse(W, H, cx, 46 + b, 11, 10)
    lv = mass(img, body, "mould", "round", INK, base=2)
    put(img, m_line(W, H, cx - 9, 39 + b, cx + 8, 53 + b, 2.4) & body, RAMP["cloth"][2])          # sash
    for k in range(3):
        put(img, m_rect(W, H, int(cx) - 6 + k * 3, 45 + b, 2, 2), RAMP["gold"][3 + (k == 1)])      # medals
    for ex in (cx - 10, cx + 9):
        ep = m_ellipse(W, H, ex, 38 + b, 4.5, 2.5)
        mass(img, ep, "gold", "round", INK, base=2)
        put(img, m_rect(W, H, int(ex) - 3, 40 + b, 7, 1) & grow(ep), RAMP["gold"][1])
    face = m_ellipse(W, H, hx + 2, 31 + b, 7.5, 5.5)
    mass(img, face, "hypha", "round", INK, base=3)
    glow_eye(img, int(hx) + 1, 29 + b, eyes)
    glow_eye(img, int(hx) + 6, 29 + b, eyes)
    put(img, m_line(W, H, hx - 1, 27 + b, hx + 3, 28 + b, 1) | m_line(W, H, hx + 9, 27 + b, hx + 5, 28 + b, 1), INK)   # scowl
    mo = m_curve(W, H, [(hx - 2, 35 + b), (hx + 3, 33 + b), (hx + 9, 35 + b)], 2.0, 1.2)
    mass(img, mo, "gill", "flat", INK, base=1)
    capm = (m_ellipse(W, H, hx, 21 + b, 19, 11) & m_rect(W, H, 0, 0, W, 27 + b))
    lvc = mass(img, capm, "cap", "round", INK, base=2)
    for (sx, sy, r) in ((-10, -3, 2.5), (-2, -7, 2), (7, -4, 2.5), (13, 1, 1.5), (-15, 2, 1.5)):
        step(img, capm & m_ellipse(W, H, hx + sx, 21 + b + sy, r, r * 0.7), "cap", lvc, 2)
    put(img, shift(capm, 0, 1) & ~capm & m_rect(W, H, int(hx) - 17, 0, 34, H) & (img.a[..., 3] > 0), RAMP["gill"][2])
    pl = m_curve(W, H, [(hx - 2, 11 + b), (hx - 7, 4 + b), (hx - 15, 3 + b), (hx - 20, 7 + b)], 3.0, 1.0)
    mass(img, pl, "cloth", "flat", INK, base=3)
    if arc:
        put(img, m_curve(W, H, arc, 3.6, 1.2), ARC_FOE)
    sx, sy = hx + 8, 40 + b
    gx, gy = hand[0] + lean, hand[1] + b
    mass(img, m_line(W, H, sx, sy, gx, gy, 4.0), "mould", "flat", INK, base=2)
    h1 = _ang(gx, gy, blade, 5)
    mass(img, m_line(W, H, *_ang(gx, gy, blade, -3), *h1, 2.4), "bark", "flat", INK, base=2)
    t0, t1 = _ang(gx, gy, blade, 5), _ang(gx, gy, blade, 25)
    nx, ny = -math.sin(math.radians(blade)), math.cos(math.radians(blade))
    bl = m_poly(W, H, [t0, t1, (t1[0] + nx * 7, t1[1] + ny * 7), (t0[0] + nx * 5, t0[1] + ny * 5)])
    lvb = mass(img, bl, "iron", "flat", INK, base=3)
    step(img, bl & m_line(W, H, t0[0], t0[1], t1[0], t1[1], 1.2), "iron", lvb, 1)
    for k in (0.4, 0.7):
        rx, ry = t0[0] + (t1[0] - t0[0]) * k + nx * 4, t0[1] + (t1[1] - t0[1]) * k + ny * 4
        put(img, m_ellipse(W, H, rx, ry, 1.2, 1.2) & bl, RAMP["crust"][1])                    # rust
    put(img, m_ellipse(W, H, gx, gy, 2.5, 2.5), RAMP["hypha"][3])
    return img


def general_frames():
    f = {}
    for i, (b, c) in enumerate(((0, 0), (0, 1), (1, 1), (1, 0))):
        f[f"idle/{i}"] = general(b=b, cape=c)
    for i in range(6):
        ph = 2 * math.pi * i / 6
        legs = ((round(math.sin(ph) * 3), int(max(0, math.cos(ph)) * 2)), (round(-math.sin(ph) * 3), int(max(0, -math.cos(ph)) * 2)))
        f[f"walk/{i}"] = general(b=1 if i in (1, 4) else 0, lean=1, legs=legs, cape=2 + i % 2, blade=-66 - (i % 2) * 4)
    atk = [dict(lean=-1, hand=(38, 34), blade=-120, cape=-1), dict(lean=-3, b=1, hand=(34, 28), blade=-150, cape=-2),
           dict(lean=-3, b=1, hand=(33, 26), blade=-160, cape=-2),
           dict(lean=5, b=1, hand=(50, 46), blade=24, cape=4, legs=((-2, 0), (3, 0)), arc=[(38, 8), (52, 14), (60, 28), (60, 44)]),
           dict(lean=4, b=1, hand=(49, 48), blade=50, cape=3, legs=((-2, 0), (3, 0))), dict(lean=1, hand=(46, 46), blade=-30, cape=1)]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = general(**k)
    f["hit/0"] = general(lean=-4, b=1, hand=(42, 46), blade=-40, eyes=False, cape=-3)
    f["hit/1"] = general(lean=-2, hand=(43, 45), blade=-55, eyes=False, cape=-1)
    base = general(lean=-2, b=1, hand=(42, 48), blade=-20, eyes=False)
    for i in range(7):
        f[f"death/{i}"] = crumble(base, i / 6, 11 + i)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def millstone(b=0, spin=0.0, step_=0, fists=((14, 50), (42, 50)), eyes=True, arc=None, lean=0, dust=0):
    W = H = 64
    img = Img(W, H)
    cx, cy = 28 + lean, 36 + b
    # mill sails on the back, turning
    hub = (cx - 6, cy - 10)
    for k in range(4):
        a = spin + k * math.pi / 2
        e = (hub[0] + math.cos(a) * 22, hub[1] + math.sin(a) * 22)
        sp = m_line(W, H, hub[0], hub[1], e[0], e[1], 1.8)
        mass(img, sp, "wood", "flat", INK, base=2)
        n = (-math.sin(a), math.cos(a))
        q = [(hub[0] + math.cos(a) * 8, hub[1] + math.sin(a) * 8), e, (e[0] + n[0] * 5, e[1] + n[1] * 5),
             (hub[0] + math.cos(a) * 8 + n[0] * 5, hub[1] + math.sin(a) * 8 + n[1] * 5)]
        sail = m_poly(W, H, q) & ~sp
        put(img, sail & (img.a[..., 3] == 0), RAMP["sack"][3 - (k % 2)])
    put(img, m_ellipse(W, H, hub[0], hub[1], 2, 2), RAMP["iron"][2])
    # post legs
    for i, (lx, lift) in enumerate(((cx - 9 + step_, 0), (cx + 4 - step_, 0))):
        m = m_rect(W, H, int(lx), 48 + b, 6, 14 - b) | m_rect(W, H, int(lx) - 1, 61, 8, 2)
        mass(img, m, "wood", "wall", INK, base=1 + i)
    # the millstone body: grooves turn with the walk; the eye-hole is its face
    disc = m_ellipse(W, H, cx, cy, 15, 15)
    lv = mass(img, disc, "stone", "round", INK, base=2)
    for k in range(8):
        a = spin * 0.5 + k * math.pi / 4
        g = m_line(W, H, cx + math.cos(a) * 6, cy + math.sin(a) * 6, cx + math.cos(a) * 14, cy + math.sin(a) * 14, 1.0)
        step(img, g & disc, "stone", lv, -1)
    hole = m_ellipse(W, H, cx + 2, cy - 1, 6, 5)
    put(img, hole, RAMP["robe"][0])
    glow_eye(img, int(cx) - 1, int(cy) - 2, eyes, 2, 3)
    glow_eye(img, int(cx) + 4, int(cy) - 2, eyes, 2, 3)
    # mould taking it over: a cap cluster on the top-left, drips down the face
    for (sx, sy, r) in ((-10, -12, 5), (-4, -15, 3.5), (-13, -6, 3)):
        c = m_ellipse(W, H, cx + sx, cy + sy, r, r * 0.6) & m_rect(W, H, 0, 0, W, int(cy + sy) + 1)
        mass(img, c, "cap", "round", INK, base=2)
    for dx in (-8, -3, 9):
        put(img, m_rect(W, H, int(cx) + dx, int(cy) - 13 + abs(dx) // 3, 1, 4 + (dx % 3)) & disc, RAMP["mould"][3])
    put(img, m_ellipse(W, H, cx + 8, cy + 9, 3, 2) & disc, RAMP["mould"][2])
    # flour-sack fists on rope arms
    for (fx, fy), sx in zip(fists, (cx - 12, cx + 12)):
        fx += lean
        fy += b
        mass(img, m_line(W, H, sx, cy + 2, fx, fy - 3, 1.6), "timber", "flat", INK, base=2)
        s = m_ellipse(W, H, fx, fy, 5, 4.5)
        mass(img, s, "sack", "round", INK, base=3)
        put(img, m_rect(W, H, int(fx) - 1, int(fy) - 4, 3, 1), RAMP["timber"][1])
    if arc:
        put(img, m_curve(W, H, arc, 3.4, 1.2), ARC_FOE)
    for k in range(dust):                                   # flour puff on impact
        put(img, m_ellipse(W, H, 46 + k * 5, 58 - k * 2, 3 + k, 2 + k * 0.5) & (img.a[..., 3] == 0), RAMP["white"][4 - k])
    return img


def millstone_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = millstone(b=1 if i >= 2 else 0, spin=i * 0.2)
    for i in range(6):
        f[f"walk/{i}"] = millstone(b=1 if i in (1, 4) else 0, spin=i * 0.4, step_=(1 if i < 3 else -1), lean=1,
                                   fists=((14, 50 - (i % 2)), (42, 49 + (i % 2))))
    seq = [dict(fists=((16, 40), (40, 40)), lean=-1), dict(fists=((18, 26), (38, 24)), lean=-2, b=-1),
           dict(fists=((20, 18), (38, 16)), lean=-3, b=-1),
           dict(fists=((44, 58), (54, 58)), lean=4, b=1, dust=2, arc=[(40, 12), (54, 20), (60, 34), (58, 52)]),
           dict(fists=((44, 58), (54, 58)), lean=3, b=1, dust=3), dict(fists=((18, 50), (42, 50)), lean=1)]
    for i, k in enumerate(seq):
        f[f"attack/{i}"] = millstone(spin=0.6 + i * 0.5, **k)
    f["hit/0"] = millstone(lean=-3, b=1, eyes=False)
    f["hit/1"] = millstone(lean=-2, eyes=False)
    base = millstone(eyes=False)
    for i in range(7):
        f[f"death/{i}"] = crumble(base, i / 6, 21 + i)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def iceknight(b=0, lean=0, legs=((0, 0), (0, 0)), shield=0, eyes=True, arc=None, breath=0):
    W = H = 64
    img = Img(W, H)
    cx = 26 + lean
    for i, (off, lift) in enumerate(legs):
        lx = int(round(20 + i * 9 + off))
        m = m_rect(W, H, lx, 50 + b, 6, 12 - b - lift) | m_rect(W, H, lx - 1, 60 - lift, 9, 3)
        mass(img, m, "ice", "flat", INK, base=1 + i)
    # the ice suit: faceted block with a mould figure frozen inside
    suit = m_poly(W, H, [(cx - 12, 26 + b), (cx + 10, 24 + b), (cx + 13, 36 + b), (cx + 11, 52 + b), (cx - 11, 53 + b), (cx - 14, 38 + b)])
    lv = mass(img, suit, "ice", "flat", INK, base=2)
    inner = m_ellipse(W, H, cx, 40 + b, 7, 9) | m_ellipse(W, H, cx + 1, 30 + b, 5, 4)
    put(img, inner & suit, RAMP["mould"][1])
    put(img, m_ellipse(W, H, cx, 42 + b, 4, 5) & suit, RAMP["mould"][2])
    glow_eye(img, int(cx), 29 + b, eyes)
    glow_eye(img, int(cx) + 4, 29 + b, eyes)
    for (x0, y0, x1, y1) in ((cx - 10, 28, cx - 4, 50), (cx + 4, 26, cx + 9, 48)):          # facet light
        put(img, m_line(W, H, x0, y0 + b, x1, y1 + b, 1.0) & suit, RAMP["ice"][4])
    put(img, m_line(W, H, cx - 12, 27 + b, cx + 9, 25 + b, 1.0) & suit, RAMP["ice"][4])
    # icicle crown
    for k, (dx, hgt) in enumerate(((-10, 6), (-5, 10), (0, 13), (5, 9), (9, 6))):
        sp = m_poly(W, H, [(cx + dx - 2, 26 + b), (cx + dx + 0.5, 26 + b - hgt), (cx + dx + 3, 26 + b)])
        mass(img, sp, "ice", "flat", INK, base=3)
    # frost breath
    for k in range(breath):
        put(img, m_ellipse(W, H, cx + 15 + k * 4, 30 + b - k, 2 + k * 0.6, 1.5 + k * 0.3) & (img.a[..., 3] == 0), RAMP["ice"][4 - k])
    if arc:
        put(img, m_curve(W, H, arc, 3.4, 1.2), ARC_FOE)
    # tower shield: tall ice slab, frosted rim, a crack
    sx = cx + 12 + shield
    sh = m_rect(W, H, sx, 22 + b, 11, 36) | m_ellipse(W, H, sx + 5.5, 22 + b, 5.5, 3)
    lvs = mass(img, sh, "ice", "wall", INK, base=3)
    step(img, sh & ~(sh & shift(sh, 2, 0) & shift(sh, -2, 0) & shift(sh, 0, 2) & shift(sh, 0, -2)), "ice", lvs, 1)
    put(img, m_curve(W, H, [(sx + 3, 30 + b), (sx + 6, 36 + b), (sx + 4, 41 + b), (sx + 7, 46 + b)], 1.0) & sh, RAMP["ice"][0])
    put(img, m_ellipse(W, H, sx + 5.5, 34 + b, 2.5, 2.5) & sh, RAMP["mould"][2])            # mould emblem
    return img


def iceknight_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = iceknight(b=1 if i >= 2 else 0, breath=(0, 1, 2, 1)[i])
    for i in range(6):
        ph = 2 * math.pi * i / 6
        legs = ((round(math.sin(ph) * 3), int(max(0, math.cos(ph)) * 2)), (round(-math.sin(ph) * 3), int(max(0, -math.cos(ph)) * 2)))
        f[f"walk/{i}"] = iceknight(b=1 if i in (1, 4) else 0, lean=1, legs=legs)
    seq = [dict(lean=-1, shield=-2), dict(lean=-3, b=1, shield=-4), dict(lean=-4, b=1, shield=-5, breath=1),
           dict(lean=4, shield=8, legs=((-2, 0), (3, 0)), arc=[(52, 18), (61, 30), (61, 46)], breath=3),
           dict(lean=3, shield=7, legs=((-2, 0), (3, 0)), breath=2), dict(lean=1, shield=2)]
    for i, k in enumerate(seq):
        f[f"attack/{i}"] = iceknight(**k)
    f["hit/0"] = iceknight(lean=-3, b=1, shield=-2, eyes=False)
    f["hit/1"] = iceknight(lean=-2, shield=-1, eyes=False)
    base = iceknight(eyes=False)
    for i in range(7):
        f[f"death/{i}"] = crumble(base, i / 6, 31 + i, sink=6)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# ------------------------------------------------------------------------------------------------ 88 x 80
def king(b=0, lean=0, staff=(58, 40), orb=1.0, eyes=True, arc=None, step_=0, aura=0):
    W, H = 88, 80
    img = Img(W, H)
    cx = 36 + lean
    # robe: wide bell, fur hem, a spore pattern
    robe = m_poly(W, H, [(cx - 11, 38 + b), (cx + 11, 38 + b), (cx + 21 - step_, 78), (cx - 21 + step_, 78)])
    lv = mass(img, robe, "robe", "flat", INK, base=2)
    put(img, m_line(W, H, cx, 40 + b, cx + 2, 77, 2.0) & robe, RAMP["robe"][3])
    for (sx, sy) in ((-10, 60), (8, 66), (-4, 70), (12, 54), (-14, 72)):
        put(img, m_ellipse(W, H, cx + sx, sy, 1.5, 1.2) & robe, RAMP["gill"][3])
    hem = m_rect(W, H, int(cx) - 22 + step_, 74, 44 - step_ * 2, 4) & grow(robe, 1)
    mass(img, hem, "hypha", "flat", INK, base=3)
    # beard of hyphae over the robe's chest
    for k in range(5):
        x = cx - 5 + k * 3
        put(img, m_line(W, H, x, 36 + b, x + (k - 2) * 0.6, 46 + b + (k % 2) * 3, 1.4), RAMP["hypha"][3 + (k % 2)])
    face = m_ellipse(W, H, cx + 2, 31 + b, 9, 6.5)
    mass(img, face, "hypha", "round", INK, base=2)
    glow_eye(img, int(cx), 29 + b, eyes, 3, 2)
    glow_eye(img, int(cx) + 6, 29 + b, eyes, 3, 2)
    # the cap: enormous, with a tarnished crown riding on it
    capm = m_ellipse(W, H, cx, 22 + b, 26, 13) & m_rect(W, H, 0, 0, W, 28 + b)
    lvc = mass(img, capm, "cap", "round", INK, base=2)
    for (sx, sy, r) in ((-16, 0, 3), (-6, -6, 3.5), (8, -5, 3), (18, 0, 2.5), (-2, 2, 2)):
        step(img, capm & m_ellipse(W, H, cx + sx, 22 + b + sy, r, r * 0.7), "cap", lvc, 2)
    put(img, shift(capm, 0, 1) & ~capm & m_rect(W, H, int(cx) - 24, 0, 48, H) & (img.a[..., 3] > 0), RAMP["gill"][2])
    cr = m_rect(W, H, int(cx) - 8, 6 + b, 17, 5)
    for k in range(4):
        cr |= m_poly(W, H, [(cx - 8 + k * 5, 7 + b), (cx - 6 + k * 5, 1 + b), (cx - 4 + k * 5, 7 + b)])
    mass(img, cr, "gold", "flat", INK, base=2)
    for k in range(3):
        put(img, m_rect(W, H, int(cx) - 5 + k * 5, 8 + b, 2, 2), GLOW[3])
    # staff + spore orb
    if aura:
        spores(img, staff[0] + lean, staff[1] - 24 + b, 10 + aura * 6, 8 + aura * 5, 3 + aura)
    if arc:
        put(img, m_curve(W, H, arc, 3.6, 1.2), ARC_FOE)
    sx, sy = cx + 10, 44 + b
    gx, gy = staff[0] + lean, staff[1] + b
    mass(img, m_line(W, H, sx, sy, gx, gy, 4.0), "robe", "flat", INK, base=3)
    top = (gx + 2, gy - 22)
    mass(img, m_line(W, H, gx - 1, gy + 14, top[0], top[1], 2.2), "bark", "flat", INK, base=3)
    r = 3.5 * orb + 1
    o = m_ellipse(W, H, top[0], top[1] - r, r, r)
    mass(img, o, "organ", "round", INK, base=3)
    put(img, m_ellipse(W, H, gx, gy, 2.6, 2.6), RAMP["hypha"][3])
    return img


def king_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = king(b=1 if i >= 2 else 0, orb=1.0 + 0.15 * (i % 2))
    for i in range(6):
        f[f"walk/{i}"] = king(b=1 if i in (1, 4) else 0, lean=1, step_=(2 if i < 3 else -2))
    atk = [dict(lean=-1, staff=(52, 30)), dict(lean=-3, b=1, staff=(46, 22), orb=1.3), dict(lean=-3, b=1, staff=(44, 18), orb=1.5),
           dict(lean=5, b=1, staff=(66, 50), orb=1.2, arc=[(52, 6), (70, 14), (80, 30), (80, 50)]), dict(lean=4, b=1, staff=(64, 52)),
           dict(lean=1, staff=(58, 42))]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = king(**k)
    for i, (sy, orb, aura) in enumerate(((36, 1.2, 0), (28, 1.5, 0), (22, 1.9, 1), (18, 2.2, 3), (24, 1.6, 2), (34, 1.2, 1))):
        f[f"summon/{i}"] = king(staff=(56, sy), orb=orb, aura=aura, b=1 if i == 3 else 0)
    f["hit/0"] = king(lean=-3, b=1, eyes=False)
    f["hit/1"] = king(lean=-2, eyes=False)
    base = king(eyes=False)
    for i in range(8):
        f[f"death/{i}"] = crumble(base, i / 7, 41 + i, sink=14)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def treeking(b=0, lean=0, arm=(-30.0, 0.0), eyes=True, arc=None, roots=0, sway=0, step_=0):
    W, H = 88, 80
    img = Img(W, H)
    cx = 38 + lean
    # bursting roots in front (summon)
    for k in range(roots):
        x = 58 + k * 9
        rt = m_poly(W, H, [(x - 3, 79), (x + 0.5, 79 - 6 - k * 3), (x + 4, 79)])
        mass(img, rt, "bark", "flat", INK, base=2)
    # root legs
    for k, (dx, ex) in enumerate(((-12, -22), (-4, -8), (6, 8), (13, 22))):
        rt = m_curve(W, H, [(cx + dx, 62 + b), (cx + dx + (ex - dx) * 0.5 + (step_ if k % 2 else -step_), 72), (cx + ex, 79)], 4.5, 2.0)
        mass(img, rt, "bark", "flat", INK, base=1 + (k % 2))
    # trunk
    tr = m_poly(W, H, [(cx - 13, 64 + b), (cx - 10, 28 + b), (cx + 10, 26 + b), (cx + 14, 64 + b)])
    lv = mass(img, tr, "bark", "flat", INK, base=2)
    for k in range(5):
        x = cx - 9 + k * 4.5
        step(img, tr & m_curve(W, H, [(x, 30 + b), (x + 1, 46 + b), (x - 1, 62 + b)], 1.0), "bark", lv, -1)
    put(img, m_ellipse(W, H, cx - 6, 54 + b, 2, 3) & tr, RAMP["bark"][0])                    # knot
    # carved face: deep sockets with glow, jagged mouth
    for ex in (cx - 4, cx + 5):
        put(img, m_ellipse(W, H, ex, 38 + b, 3, 2.5), RAMP["bark"][0])
        glow_eye(img, int(ex) - 1, 37 + b, eyes)
    mouth = m_poly(W, H, [(cx - 6, 46 + b), (cx + 8, 46 + b), (cx + 6, 51 + b), (cx + 3, 48 + b), (cx, 52 + b), (cx - 3, 48 + b)])
    put(img, mouth, RAMP["bark"][0])
    put(img, m_rect(W, H, int(cx) - 2, 47 + b, 2, 1), GLOW[2])
    # canopy: grey-rotten leaves, rotten apples, one with a worm
    can = m_ellipse(W, H, cx - 2 + sway, 18 + b, 22, 12) | m_ellipse(W, H, cx - 16 + sway, 22 + b, 10, 8) | m_ellipse(W, H, cx + 14 + sway, 22 + b, 10, 8)
    lvl = mass(img, can, "blight", "round", INK, base=2)
    for (sx, sy) in ((-14, 0), (-4, -6), (6, -2), (14, 2), (-10, 8), (2, 6)):
        step(img, can & m_ellipse(W, H, cx + sx + sway, 18 + b + sy, 3, 2), "blight", lvl, -1)
    for k, (sx, sy) in enumerate(((-12, 4), (2, -4), (12, 6), (-2, 8))):
        ap = m_ellipse(W, H, cx + sx + sway, 18 + b + sy, 3, 3)
        mass(img, ap, "apple", "round", INK, base=2)
        put(img, m_rect(W, H, int(cx + sx + sway) - 1, int(18 + b + sy) - 1, 1, 1), RAMP["mould"][3])
        if k == 1:
            put(img, m_curve(W, H, [(cx + sx + sway + 2, 18 + b + sy - 2), (cx + sx + sway + 4, 18 + b + sy - 5), (cx + sx + sway + 6, 18 + b + sy - 4)], 1.4), RAMP["cloth"][4])
    # branch arm: long, three twig claws
    sh = (cx + 10, 36 + b)
    a, bend = arm
    e = _ang(sh[0], sh[1], a, 26)
    mid = ((sh[0] + e[0]) / 2 + bend, (sh[1] + e[1]) / 2 - 4)
    br = m_curve(W, H, [sh, mid, e], 4.5, 2.0)
    if arc:
        put(img, m_curve(W, H, arc, 3.6, 1.2), ARC_FOE)
    mass(img, br, "bark", "flat", INK, base=3)
    for k in (-35, 0, 35):
        t = _ang(e[0], e[1], a + k, 6)
        mass(img, m_line(W, H, e[0], e[1], t[0], t[1], 1.6), "bark", "flat", INK, base=3)
    return img


def treeking_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = treeking(b=1 if i >= 2 else 0, sway=(0, 1, 1, 0)[i])
    for i in range(6):
        f[f"walk/{i}"] = treeking(b=1 if i in (1, 4) else 0, lean=1, step_=(3 if i < 3 else -3), sway=(i % 2))
    atk = [dict(arm=(-70, 0), lean=-1), dict(arm=(-110, -4), lean=-3, b=1, sway=-1), dict(arm=(-130, -6), lean=-3, b=1, sway=-2),
           dict(arm=(20, 6), lean=5, b=1, sway=2, arc=[(56, 8), (74, 18), (84, 36), (82, 56)]), dict(arm=(40, 6), lean=4, b=1, sway=1),
           dict(arm=(-20, 2), lean=1)]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = treeking(**k)
    for i, (rt, a) in enumerate(((0, -60), (0, -80), (1, -90), (3, -95), (2, -70), (1, -40))):
        f[f"summon/{i}"] = treeking(arm=(a, -3), roots=rt, b=1 if i == 3 else 0)
    f["hit/0"] = treeking(lean=-3, b=1, eyes=False, sway=-2)
    f["hit/1"] = treeking(lean=-2, eyes=False, sway=-1)
    base = treeking(eyes=False)
    for i in range(8):
        f[f"death/{i}"] = crumble(base, i / 7, 51 + i, sink=12)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def ovengolem(b=0, lean=0, door=0.0, heart=1.0, peel=-60.0, eyes=True, arc=None, smoke=1, step_=0, flame=0):
    W, H = 88, 80
    img = Img(W, H)
    cx = 34 + lean
    for i, dx in enumerate((-12, 6)):
        lx = int(cx + dx + (step_ if i else -step_))
        m = m_rect(W, H, lx, 62 + b, 9, 16 - b) | m_rect(W, H, lx - 1, 76, 11, 3)
        mass(img, m, "brick", "wall", INK, base=1 + i)
    # dome body of bricks, mould creeping up from the left
    body = (m_ellipse(W, H, cx, 46 + b, 20, 20) & m_rect(W, H, 0, 0, W, 64 + b)) | m_rect(W, H, int(cx) - 20, 46 + b, 41, 18)
    lv = mass(img, body, "brick", "round", INK, base=2)
    for yy in range(28, 64, 4):
        for xx in range(int(cx) - 20 + (yy // 4 % 2) * 4, int(cx) + 21, 8):
            put(img, m_rect(W, H, xx, yy + b, 1, 3) & body, RAMP["brick"][0])
        put(img, m_rect(W, H, int(cx) - 20, yy + b + 3, 41, 1) & body, RAMP["brick"][1])
    # v2: wider mould (left flank, shoulder, right hip) so the boss reads as a mould-eaten oven, not as our oven cannon
    # (protan mean-colour check against `siege` was 1.67 < 2.3)
    mould = body & (m_ellipse(W, H, cx - 14, 56 + b, 16, 13) | m_ellipse(W, H, cx - 10, 34 + b, 9, 7) | m_ellipse(W, H, cx + 15, 58 + b, 8, 6))
    lvm = mass(img, mould, "mould", "round", None, base=2)
    for (sx, sy) in ((-20, 50), (-14, 30), (-22, 60)):
        c = m_ellipse(W, H, cx + sx, sy + b, 3.5, 2) & m_rect(W, H, 0, 0, W, sy + b + 1)
        mass(img, c, "cap", "round", INK, base=3)
    # chest door with the heart behind it
    dx0, dy0 = int(cx) - 4, 40 + b
    hole = m_rect(W, H, dx0, dy0, 15, 14) | m_ellipse(W, H, dx0 + 7.5, dy0, 7.5, 4)
    put(img, hole, RAMP["robe"][0])
    hr = 3.5 + heart
    hm = m_ellipse(W, H, dx0 + 5.5, dy0 + 6, hr * 0.7, hr * 0.7) | m_ellipse(W, H, dx0 + 9.5, dy0 + 6, hr * 0.7, hr * 0.7) | \
        m_poly(W, H, [(dx0 + 2.5, dy0 + 7), (dx0 + 12.5, dy0 + 7), (dx0 + 7.5, dy0 + 7 + hr * 1.3)])
    mass(img, hm & hole, "fire", "round", None, base=2 + (heart > 1.2))
    put(img, m_ellipse(W, H, dx0 + 5, dy0 + 5, 1.2, 1.2) & hole, GLOW[3])
    if door < 1.0:
        dw = int(round(15 * (1 - door)))
        dm = (m_rect(W, H, dx0, dy0 - 3, dw, 17)) & grow(hole, 1)
        lvd = mass(img, dm, "iron", "flat", INK, base=2)
        for k in range(0, dw, 4):
            put(img, m_rect(W, H, dx0 + k + 1, dy0 + 1, 2, 10) & dm, RAMP["fire"][1 + int(heart)])
    else:
        dm = m_rect(W, H, dx0 - 5, dy0 - 3, 4, 17)
        mass(img, dm, "iron", "flat", INK, base=1)
    if flame:
        for k in range(flame):
            fl = m_ellipse(W, H, dx0 + 20 + k * 8, dy0 + 7 + k * 0.5, 5 + k * 1.5, 3 + k * 0.6)
            put(img, fl & (img.a[..., 3] == 0), RAMP["fire"][3 - min(2, k)])
        put(img, m_ellipse(W, H, dx0 + 20, dy0 + 7, 3, 2), RAMP["fire"][4])
    # chimney head with eye slits
    ch = m_rect(W, H, int(cx) - 6, 14 + b, 13, 16)
    mass(img, ch, "brick", "wall", INK, base=2)
    put(img, m_rect(W, H, int(cx) - 7, 13 + b, 15, 3), RAMP["iron"][2])
    glow_eye(img, int(cx) - 3, 21 + b, eyes, 3, 2)
    glow_eye(img, int(cx) + 3, 21 + b, eyes, 3, 2)
    for k in range(smoke):
        put(img, m_ellipse(W, H, cx - 2 - k * 3, 9 + b - k * 4, 3 + k, 2.5 + k * 0.5) & (img.a[..., 3] == 0), RAMP["stone"][3 - min(2, k)])
    if arc:
        put(img, m_curve(W, H, arc, 3.6, 1.2), ARC_FOE)
    # the bread-peel arm
    sx, sy = cx + 16, 42 + b
    e = _ang(sx, sy, peel, 22)
    mass(img, m_line(W, H, sx, sy, e[0], e[1], 2.6), "wood", "flat", INK, base=3)
    blade = m_ellipse(W, H, *_ang(sx, sy, peel, 28), 7, 7) & ~m_ellipse(W, H, sx, sy, 22, 22)
    lvb = mass(img, blade, "wood", "round", INK, base=3)
    put(img, m_ellipse(W, H, *_ang(sx, sy, peel, 29), 2, 2) & blade, RAMP["mould"][2])
    return img


def ovengolem_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = ovengolem(b=1 if i >= 2 else 0, heart=(1.0, 1.3, 1.0, 0.8)[i], smoke=1 + (i % 2))
    for i in range(6):
        f[f"walk/{i}"] = ovengolem(b=1 if i in (1, 4) else 0, lean=1, step_=(2 if i < 3 else -2), smoke=1 + (i % 3 == 0))
    atk = [dict(lean=-1, peel=-100), dict(lean=-3, b=1, peel=-135, heart=1.4), dict(lean=-3, b=1, peel=-150, heart=1.6),
           dict(lean=5, b=1, peel=10, heart=1.3, arc=[(56, 8), (74, 18), (84, 34), (84, 52)]), dict(lean=4, b=1, peel=40),
           dict(lean=1, peel=-40)]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = ovengolem(**k)
    for i, (d, ht, fl) in enumerate(((0.3, 1.4, 0), (0.7, 1.8, 0), (1.0, 2.2, 1), (1.0, 2.4, 3), (0.6, 1.8, 1), (0.2, 1.2, 0))):
        f[f"summon/{i}"] = ovengolem(door=d, heart=ht, flame=fl, smoke=2)
    f["hit/0"] = ovengolem(lean=-3, b=1, eyes=False, heart=0.6)
    f["hit/1"] = ovengolem(lean=-2, eyes=False, heart=0.8)
    base = ovengolem(eyes=False, heart=0.5, smoke=0)
    for i in range(8):
        f[f"death/{i}"] = crumble(base, i / 7, 61 + i, sink=10)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# set id -> (frames, contract file, contract set, pivot). New ids are art sets; the adapter points each boss at its own.
SETS = {
    "boss_warlord": (general_frames, "char_boss_warlord", "boss_warlord", (28, 63)),
    "slice_boss_millward": (millstone_frames, "char_boss_warlord", "boss_warlord", (28, 63)),
    "slice_boss_frostguard": (iceknight_frames, "char_boss_warlord", "boss_warlord", (28, 63)),
    "boss_overlord": (king_frames, "char_boss_overlord", "boss_overlord", (36, 79)),
    "slice_boss_rootking": (treeking_frames, "char_boss_overlord", "boss_overlord", (36, 79)),
    "slice_boss_ovenheart": (ovengolem_frames, "char_boss_overlord", "boss_overlord", (36, 79)),
}
BOSS_SET = {"boss_millward": "slice_boss_millward", "boss_frostguard": "slice_boss_frostguard",
            "boss_rootking": "slice_boss_rootking", "boss_ovenheart": "slice_boss_ovenheart"}
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "release_slice")
PAGE_W, PAGE_H, PAD = 1024, 2048, 2


def main():
    page = Image.new("RGBA", (PAGE_W, PAGE_H), (0, 0, 0, 0))
    frames, anims, rendered = {}, {}, {}
    x = y = PAD
    shelf = 0
    for sid, (fn, cfile, cset, pivot) in SETS.items():
        contract = json.load(open(os.path.join(ROOT, "assets", "atlases", cfile + ".json"), encoding="utf-8"))
        fr = fn()
        rendered[sid] = fr
        anims[sid] = {}
        for an, d in contract["anims"][cset].items():
            names = []
            for nm in d["frames"]:
                key = nm.split("/", 1)[1]
                assert key in fr, f"{sid}: contract frame {nm} not drawn"
                ref = contract["frames"][nm]
                im = fr[key].pil()
                assert (im.width, im.height) == (ref["w"], ref["h"]) and list(pivot) == ref["pivot"], f"{sid} {nm}: size/pivot differ"
                new = f"{sid}/{key.replace('die/', 'death/')}"     # die = death: one copy on the page
                names.append(new)
                if new in frames:
                    continue
                if x + im.width + PAD > PAGE_W:
                    x = PAD
                    y += shelf + PAD * 2
                    shelf = 0
                assert y + im.height + PAD <= PAGE_H, "boss page full"
                page.paste(im, (x, y))
                frames[new] = {"x": x, "y": y, "w": im.width, "h": im.height, "pivot": list(pivot)}
                x += im.width + PAD * 2
                shelf = max(shelf, im.height)
            a = dict(d)
            a["frames"] = names
            anims[sid][an] = a
    used = y + shelf + PAD
    h = (used + 63) // 64 * 64                      # cropped to the used rows (NPOT is fine for a nearest, non-mipmapped page)
    page = page.crop((0, 0, PAGE_W, h))
    page.save(os.path.join(OUT, "slice_bosses.png"))
    json.dump({"schema": "defence.atlas/1", "atlas": "release_slice_bosses", "image": "slice_bosses.png", "size": [PAGE_W, h],
               "padding": PAD, "extrude": 0, "group": "release_slice", "filter": "nearest", "mipmaps": False, "repeat": False,
               "gpu_format": "RGBA8", "gpu_bytes": PAGE_W * h * 4, "used_rows": used, "boss_sets": BOSS_SET,
               "frames": frames, "anims": anims}, open(os.path.join(OUT, "slice_bosses.json"), "w", encoding="utf-8"), indent=1)
    print("bosses page", PAGE_W, "x", h, "frames", len(frames))
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        keys = ["idle/0", "walk/2", "attack/1", "attack/3", "hit/0", "death/3"]
        sheet = Image.new("RGBA", (len(keys) * 92 + 4, len(SETS) * 84 + 4), (147, 184, 94, 255))
        for r, sid in enumerate(SETS):
            ks = keys + (["summon/3"] if "summon/3" in rendered[sid] else [])
            for i, k in enumerate(ks[:len(keys)] if "summon/3" not in rendered[sid] else ks[:3] + ["summon/3"] + ks[4:]):
                im = rendered[sid][k].pil()
                sheet.paste(im, (2 + i * 92, 2 + r * 84 + (80 - im.height)), im)
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)
        print("sheet (generator output):", path)


if __name__ == "__main__":
    main()
