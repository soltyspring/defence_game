"""The other nine regular units in the release-slice style (same contract as assets/atlases/char_player.json):
    worker       32x32 (14,31)  idle4 walk6 work4(hit 3) carry6 death6     제빵사: apprentice, small toque, flour sack
    ranged_basic 32x32 (13,31)  idle4 walk6 attack4(hit 2) hit2 death6     롤빵병: round dinner roll throwing crumb-balls
    tank         32x32 (13,31)  idle3 walk6 attack4(hit 2) hit2 death6     통식빵: tall whole loaf behind a cutting-board shield
    fast         40x32 (18,31)  idle2 walk6 attack4(hit 1) hit2 death5     프레첼: pretzel lancer on a biscuit pony
    siege        48x40 (22,39)  idle2 walk4 attack6(hit 3) hit2 death5     화덕포: brick oven cannon on a cart
    e_spitter    32x32 (13,31)  idle4 walk6 attack4(hit 2) hit2 death6     포자 뱉개: bulb-headed spore spitter
    e_swarm      32x24 (14,23)  idle2 walk4 attack3(hit 1) hit2 death5     초파리 떼: three fruit flies
    e_brute      48x48 (21,47)  idle4 walk6 attack5(hit 3) hit2 death6     썩은 멧돼지: rotten boar, mould mane, tusks
    e_bomber     32x32 (13,31)  idle2 walk6 attack3(hit 1) hit2 death6     부푼 효모: swollen yeast ball with a fuse-stalk
All face right. Each has one head/silhouette shape nobody else has; weapons leave the body outline.
python tools/art/release_slice/chars2.py [--sheet <png>]  writes assets/art/release_slice/slice_chars2.{png,json}
"""
from __future__ import annotations

import json
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import INK, INK_MOULD, RAMP, Img, hexc, m_curve, m_ellipse, m_line, m_poly, m_rect, mass, put, shift, step  # noqa: E402
from chars import ARC_ALLY, ARC_FOE, _ang, _fall, _walk_legs  # noqa: E402  (also registers skin / white ramps)

RAMP["fly"] = [hexc(c) for c in ("2a2c38", "3e4152", "5a5f72", "7d8496", "a9b0c0")]
RAMP["wing"] = [hexc(c) for c in ("9fb4c4", "bcd0dc", "d6e6ee", "eef6fa", "ffffff")]
RAMP["yeast"] = [hexc(c) for c in ("5e6a4a", "7f8c5e", "a3ab78", "c4c896", "dfe0b8")]
RAMP["boar"] = [hexc(c) for c in ("2e2a30", "48404a", "665a62", "8a7a7c", "ad9e98")]
EYE_FOE = RAMP["organ"][3]


def _legs(img, W, H, x0, gap, top, b, legs, ramp="timber", ink=INK, w=2, foot=4):
    for i, (off, lift) in enumerate(legs):
        lx = int(round(x0 + i * gap + off))
        m = m_rect(W, H, lx, top + b, w, H - 1 - top - b - lift + 1 - 2) | m_rect(W, H, lx, H - 2 - lift, foot, 2)
        mass(img, m, ramp, "flat", ink, base=1 if i == 0 else 2)


# ---------------------------------------------------------------------------------------------- allies
def worker(bob=0, lean=0, legs=((0, 0), (0, 0)), sack=None, tool=None, eyes=True):
    W = H = 32
    img = Img(W, H)
    b = bob
    hx = 14 + lean
    _legs(img, W, H, 11, 4, 25, b, legs)
    body = m_ellipse(W, H, 14 + lean * 0.5, 23 + b, 5, 4.5)
    mass(img, body, "white", "round", INK, base=3)
    put(img, m_rect(W, H, 10 + lean, 24 + b, 9, 4) & body, RAMP["cloth"][3])        # apron... in jam red, the bakery colour
    head = m_ellipse(W, H, hx + 1, 15.5 + b, 4.5, 4)
    mass(img, head, "skin", "round", INK, base=2)
    put(img, m_rect(W, H, hx + 3, 14 + b, 1, 2) if eyes else m_rect(W, H, hx + 2, 15 + b, 2, 1), INK)
    put(img, m_rect(W, H, hx + 1, 17 + b, 2, 1), RAMP["cloth"][4])
    # short toque (half the captain's), flopped back
    tq = m_ellipse(W, H, hx - 0.5, 9.5 + b, 4.5, 3.5) | m_rect(W, H, hx - 3, 10 + b, 7, 2)
    mass(img, tq, "white", "round", INK, base=3)
    if sack is not None:                                  # flour sack carried over the head
        sx, sy = sack
        s = m_ellipse(W, H, sx, sy + b, 6, 4)
        lv = mass(img, s, "sack", "round", INK, base=3)
        put(img, m_rect(W, H, int(sx) - 1, int(sy) - 1 + b, 3, 2) & s, RAMP["cloth"][2])
        put(img, m_line(W, H, hx + 2, 21 + b, sx + 2, sy + 3 + b, 2.0), RAMP["white"][2])
    if tool is not None:                                  # wooden peel / mallet for work
        tx, ty, ang = tool
        e = _ang(tx, ty + b, ang, 10)
        mass(img, m_line(W, H, hx + 3, 21 + b, tx, ty + b, 2.2), "white", "flat", INK, base=2)
        mass(img, m_line(W, H, tx, ty + b, e[0], e[1], 1.6), "wood", "flat", INK, base=3)
        hd = m_ellipse(W, H, e[0], e[1], 2.8, 2.2)
        mass(img, hd, "wood", "round", INK, base=3)
    return img


def worker_frames():
    f = {}
    for i, bob in enumerate((0, 0, 1, 1)):
        f[f"idle/{i}"] = worker(bob=bob, tool=(19, 24, -70))
    for i in range(6):
        f[f"walk/{i}"] = worker(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 2.0), tool=(19, 24, -60))
    for i, (tx, ty, a, lean) in enumerate(((18, 16, -120, -1), (17, 13, -150, -2), (20, 18, -40, 1), (21, 24, 20, 2))):
        f[f"work/{i}"] = worker(lean=lean, bob=1 if i == 3 else 0, tool=(tx, ty, a))
    for i in range(6):
        f[f"carry/{i}"] = worker(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 2.0), sack=(15, 5 + (i % 2)))
    base = worker(lean=-1, bob=1, eyes=False)
    for i, (deg, sq) in enumerate(((14, 1.0), (34, 1.0), (60, 1.0), (84, 1.0), (90, 0.85), (90, 0.7))):
        f[f"death/{i}"] = _fall(base, 14, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def roll(bob=0, lean=0, legs=((0, 0), (0, 0)), hand=(21, 16), ball=None, eyes=True, arc=None):
    W = H = 32
    img = Img(W, H)
    b = bob
    cx = 13 + lean
    _legs(img, W, H, 9, 6, 26, b, legs)
    # satchel behind
    mass(img, m_ellipse(W, H, cx - 6, 22 + b, 3, 3.5), "sack", "round", INK, base=2)
    # the roll: wide dome, glossy top, a score across
    body = m_ellipse(W, H, cx, 19 + b, 8, 8) & m_rect(W, H, 0, 0, W, 27 + b)
    lv = mass(img, body, "crust", "round", INK, base=3)
    step(img, body & m_curve(W, H, [(cx - 6, 15 + b), (cx, 12 + b), (cx + 6, 15 + b)], 1.2), "crust", lv, -1)
    put(img, m_ellipse(W, H, cx - 3, 14 + b, 2, 1) & body, RAMP["crust"][4])
    put(img, m_rect(W, H, cx - 6, 24 + b, 13, 2) & body, RAMP["crumb"][2])
    # face: goggles band (a slinger), two eyes
    put(img, m_rect(W, H, cx - 7, 17 + b, 15, 2) & body, RAMP["timber"][1])
    if eyes:
        put(img, m_rect(W, H, cx + 2, 17 + b, 2, 2) | m_rect(W, H, cx + 6, 17 + b, 2, 2), RAMP["wheat"][4])
        put(img, m_rect(W, H, cx + 3, 18 + b, 1, 1) | m_rect(W, H, cx + 7, 18 + b, 1, 1), INK)
    else:
        put(img, m_rect(W, H, cx + 2, 18 + b, 6, 1), INK)
    put(img, m_rect(W, H, cx + 4, 22 + b, 2, 1), RAMP["crust"][0])
    if arc:
        put(img, m_curve(W, H, arc, 2.2, 1.0), ARC_ALLY)
    gx, gy = hand[0] + lean, hand[1] + b
    mass(img, m_line(W, H, cx + 6, 21 + b, gx, gy, 2.4), "crust", "flat", INK, base=2)
    if ball is not None:
        bx, by = ball
        bm = m_ellipse(W, H, bx + lean, by + b, 2.5, 2.5)
        mass(img, bm, "crumb", "round", INK, base=3)
    return img


def roll_frames():
    f = {}
    for i, bob in enumerate((0, 0, 1, 1)):
        f[f"idle/{i}"] = roll(bob=bob, hand=(20, 24), ball=(21, 25))
    for i in range(6):
        f[f"walk/{i}"] = roll(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 2.0), hand=(20, 24), ball=(21, 25))
    f["attack/0"] = roll(lean=-1, hand=(10, 10), ball=(9, 9))
    f["attack/1"] = roll(lean=-2, bob=1, hand=(9, 8), ball=(8, 7))
    f["attack/2"] = roll(lean=2, hand=(26, 12), arc=[(10, 6), (18, 4), (26, 7), (30, 11)])
    f["attack/3"] = roll(lean=1, hand=(24, 20))
    f["hit/0"] = roll(lean=-2, bob=1, hand=(18, 24), eyes=False)
    f["hit/1"] = roll(lean=-1, hand=(19, 24), eyes=False)
    base = roll(lean=-1, bob=1, hand=(18, 24), eyes=False)
    for i, (deg, sq) in enumerate(((14, 1.0), (34, 1.0), (60, 1.0), (84, 1.0), (90, 0.85), (90, 0.7))):
        f[f"death/{i}"] = _fall(base, 13, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def loaf(bob=0, lean=0, legs=((0, 0), (0, 0)), shield=(20, 0), eyes=True, arc=None):
    W = H = 32
    img = Img(W, H)
    b = bob
    x0 = 5 + lean
    _legs(img, W, H, 8, 6, 27, b, legs, w=3)
    # tall loaf: rounded top, deep scores
    body = m_rect(W, H, x0, 9 + b, 14, 19) | m_ellipse(W, H, x0 + 7, 9 + b, 7, 5)
    lv = mass(img, body, "crust", "wall", INK, base=2)
    for k in range(3):
        step(img, body & m_line(W, H, x0 + 3, 12 + k * 5 + b, x0 + 11, 9 + k * 5 + b, 1.2), "crust", lv, -1)
    put(img, m_ellipse(W, H, x0 + 4, 7 + b, 2, 1) & body, RAMP["crust"][4])
    ey = 15 + b
    put(img, m_rect(W, H, x0, 11 + b, 14, 2) & body, RAMP["cloth"][2])
    if eyes:
        put(img, m_rect(W, H, x0 + 7, ey - 1, 4, 1) | m_rect(W, H, x0 + 11, ey - 1, 3, 1), RAMP["crust"][0])
        put(img, m_rect(W, H, x0 + 8, ey, 2, 2) | m_rect(W, H, x0 + 12, ey, 2, 2), INK)
    else:
        put(img, m_rect(W, H, x0 + 8, ey + 1, 6, 1), INK)
    put(img, m_rect(W, H, x0 + 10, ey + 4, 3, 1), RAMP["crust"][0])
    if arc:
        put(img, m_curve(W, H, arc, 2.4, 1.0), ARC_ALLY)
    # the cutting-board shield: thick plank with a handle hole, held in front
    sx, dy = shield
    sx += lean
    sh = m_rect(W, H, sx, 12 + b + dy, 7, 16) | m_ellipse(W, H, sx + 3.5, 12 + b + dy, 3.5, 2)
    lv2 = mass(img, sh, "wood", "wall", INK, base=3)
    step(img, sh & m_rect(W, H, sx + 2, 14 + b + dy, 3, 2), "wood", lv2, -2)
    put(img, m_rect(W, H, sx + 1, 20 + b + dy, 5, 1) & sh, RAMP["wood"][1])
    put(img, m_rect(W, H, sx + 1, 24 + b + dy, 5, 1) & sh, RAMP["wood"][1])
    return img


def loaf_frames():
    f = {}
    for i, bob in enumerate((0, 0, 1)):
        f[f"idle/{i}"] = loaf(bob=bob)
    for i in range(6):
        f[f"walk/{i}"] = loaf(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 1.5))
    f["attack/0"] = loaf(lean=-1, shield=(17, -1))
    f["attack/1"] = loaf(lean=-2, bob=1, shield=(15, -2))
    f["attack/2"] = loaf(lean=3, shield=(23, 0), legs=((-1, 0), (2, 0)), arc=[(29, 8), (31, 16), (30, 26)])
    f["attack/3"] = loaf(lean=1, shield=(21, 0))
    f["hit/0"] = loaf(lean=-2, bob=1, shield=(18, 1), eyes=False)
    f["hit/1"] = loaf(lean=-1, shield=(19, 0), eyes=False)
    base = loaf(lean=-1, bob=1, eyes=False)
    for i, (deg, sq) in enumerate(((10, 1.0), (28, 1.0), (55, 1.0), (82, 1.0), (90, 0.85), (90, 0.75))):
        f[f"death/{i}"] = _fall(base, 13, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def pretzel(gait=0.0, bob=0, lance=-8.0, reach=0, eyes=True, arc=None, rear=0):
    W, H = 40, 32
    img = Img(W, H)
    b = bob
    # biscuit pony: long body, four legs, short mane
    ph = gait * 2 * math.pi
    for i, (lx, s) in enumerate(((8, 1), (12, -1), (22, -1), (26, 1))):
        sw = math.sin(ph) * 2.5 * s if gait >= 0 else 0
        top = 23 + b - rear * (1 if i >= 2 else 0)
        foot = (int(round(lx + sw)), 30 - (1 if math.cos(ph) * s > 0.5 else 0) - rear * (2 if i >= 2 else 0))
        m = m_line(W, H, lx, top, foot[0], foot[1], 2.2)
        mass(img, m, "crust", "flat", INK, base=1 if i in (1, 2) else 2)
    body = m_ellipse(W, H, 17, 21 + b - rear, 11, 5)
    lv = mass(img, body, "crust", "round", INK, base=3)
    for k in range(4):                                   # biscuit docking holes
        put(img, m_rect(W, H, 10 + k * 4, 21 + b - rear, 1, 1), RAMP["crust"][1])
    neck = m_poly(W, H, [(24, 19 + b - rear), (29, 10 + b - rear * 2), (33, 12 + b - rear * 2), (29, 21 + b - rear)])
    mass(img, neck, "crust", "flat", INK, base=3)
    head = m_ellipse(W, H, 33, 13 + b - rear * 2, 4.5, 3)
    mass(img, head, "crust", "round", INK, base=3)
    put(img, m_rect(W, H, 33, 12 + b - rear * 2, 1, 1), INK)
    mane = m_line(W, H, 25, 16 + b - rear, 28, 9 + b - rear * 2, 2.0)
    mass(img, mane, "cloth", "flat", INK, base=2)
    put(img, m_line(W, H, 6, 19 + b, 3, 24 + b, 2), RAMP["cloth"][2])        # tail ribbon
    # rider: a pretzel knot - two loops for a body, round head with a salt-crystal helmet
    rx, ry = 16, 11 + b - rear
    knot = m_ellipse(W, H, rx - 2, ry + 3, 3.5, 3) | m_ellipse(W, H, rx + 2, ry + 3, 3.5, 3) | m_line(W, H, rx - 3, ry + 7, rx + 3, ry + 4, 2.4)
    holes = m_ellipse(W, H, rx - 2, ry + 3, 1.2, 1) | m_ellipse(W, H, rx + 2, ry + 3, 1.2, 1)
    lvk = mass(img, knot & ~holes, "crust", "round", INK, base=2)
    for sx in (-3, 1, 3):
        put(img, m_rect(W, H, rx + sx, ry + 2, 1, 1), RAMP["white"][4])
    hd = m_ellipse(W, H, rx + 1, ry - 3, 3, 3)
    mass(img, hd, "crust", "round", INK, base=3)
    helm = m_ellipse(W, H, rx + 1, ry - 5, 3.2, 2) & m_rect(W, H, 0, 0, W, ry - 4)
    mass(img, helm, "iron", "round", INK, base=3)
    put(img, m_rect(W, H, rx, ry - 8, 2, 2), RAMP["cloth"][3])
    put(img, m_rect(W, H, rx + 2, ry - 3, 1, 1) if eyes else m_rect(W, H, rx + 1, ry - 3, 2, 1), INK)
    if arc:
        put(img, m_curve(W, H, arc, 2.0, 1.0), ARC_ALLY)
    # lance, couched under the arm, pennant near the grip
    gx, gy = rx + 3 + reach, ry + 3
    t0 = _ang(gx, gy, lance, -6)
    t1 = _ang(gx, gy, lance, 18 + reach)
    mass(img, m_line(W, H, t0[0], t0[1], t1[0], t1[1], 1.6), "wood", "flat", INK, base=3)
    tip = m_line(W, H, *_ang(gx, gy, lance, 14 + reach), t1[0], t1[1], 2.0)
    mass(img, tip, "iron", "flat", INK, base=4)
    pn = m_poly(W, H, [_ang(gx, gy, lance, 3), _ang(gx, gy, lance, 8), (gx + 3, gy + 4)])
    put(img, pn, RAMP["cloth"][3])
    return img


def pretzel_frames():
    f = {"idle/0": pretzel(gait=-1), "idle/1": pretzel(gait=-1, bob=1)}
    for i in range(6):
        f[f"walk/{i}"] = pretzel(gait=i / 6, bob=1 if i % 3 == 1 else 0, lance=-6)
    f["attack/0"] = pretzel(gait=-1, rear=1, lance=-20, reach=-2)
    f["attack/1"] = pretzel(gait=0.25, lance=2, reach=4, arc=[(30, 10), (37, 14), (39, 19)])
    f["attack/2"] = pretzel(gait=0.5, bob=1, lance=6, reach=3)
    f["attack/3"] = pretzel(gait=-1, lance=-4)
    f["hit/0"] = pretzel(gait=-1, rear=1, lance=-30, eyes=False)
    f["hit/1"] = pretzel(gait=-1, lance=-16, eyes=False)
    base = pretzel(gait=-1, lance=-20, eyes=False)
    for i, (deg, sq) in enumerate(((10, 1.0), (24, 1.0), (40, 0.95), (60, 0.85), (70, 0.75))):
        f[f"death/{i}"] = _fall(base, 18, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def oven(roll_ph=0.0, recoil=0, aim=-18.0, fire=0, smoke=0, broken=False, bob=0):
    W, H = 48, 40
    img = Img(W, H)
    b = bob
    x0 = 6 - recoil
    # cart bed + two spoked wheels
    bed = m_rect(W, H, x0, 29 + b, 30, 3)
    mass(img, bed, "wood", "flat", INK, base=2)
    for wx in (x0 + 6, x0 + 25):
        wh = m_ellipse(W, H, wx, 34, 5, 5)
        lv = mass(img, wh, "wood", "round", INK, base=2)
        hub = m_ellipse(W, H, wx, 34, 1.5, 1.5)
        put(img, hub, RAMP["iron"][3])
        for k in range(3):
            a = roll_ph * 2 * math.pi / 3 + k * math.pi / 3
            put(img, m_line(W, H, wx - math.cos(a) * 3.5, 34 - math.sin(a) * 3.5, wx + math.cos(a) * 3.5, 34 + math.sin(a) * 3.5, 1.0) & wh, RAMP["wood"][1])
    # brick dome oven, fire mouth facing the enemy
    dome = (m_ellipse(W, H, x0 + 15, 22 + b, 12, 10) & m_rect(W, H, 0, 0, W, 29 + b)) | m_rect(W, H, x0 + 3, 22 + b, 25, 7)
    lv = mass(img, dome, "brick", "round", INK, base=2)
    for yy in range(14, 29, 3):
        for xx in range(x0 + 2 + (yy % 2) * 2, x0 + 29, 5):
            put(img, m_rect(W, H, xx, yy + b, 1, 1) & dome, RAMP["brick"][0])
    if broken:
        put(img, m_poly(W, H, [(x0 + 10, 13 + b), (x0 + 14, 20 + b), (x0 + 11, 22 + b), (x0 + 16, 27 + b)]) & dome, INK)
    mouth = m_ellipse(W, H, x0 + 21, 24 + b, 4, 3) & m_rect(W, H, 0, 0, W, 27 + b)
    put(img, mouth, RAMP["fire"][1 + min(3, fire)])
    put(img, m_ellipse(W, H, x0 + 21, 25 + b, 2, 1) & mouth, RAMP["fire"][min(4, 2 + fire)])
    # barrel: an iron chimney pipe swung forward
    px, py = x0 + 20, 14 + b
    e = _ang(px, py, aim, 14)
    br = m_line(W, H, px, py, e[0], e[1], 4.0)
    lvb = mass(img, br, "iron", "flat", INK, base=2)
    put(img, m_ellipse(W, H, e[0], e[1], 2.4, 2.4), RAMP["iron"][0])
    rim_ = m_ellipse(W, H, e[0], e[1], 2.6, 2.6) & ~m_ellipse(W, H, e[0], e[1], 1.4, 1.4)
    put(img, rim_, RAMP["iron"][3])
    if fire >= 2:
        m = _ang(px, py, aim, 18)
        fl = m_ellipse(W, H, m[0], m[1], 3 + fire * 0.5, 2.5 + fire * 0.4)
        put(img, fl & (img.a[..., 3] == 0), RAMP["fire"][3])
        put(img, m_ellipse(W, H, m[0], m[1], 1.5, 1.5), RAMP["fire"][4])
    for k in range(smoke):
        put(img, m_ellipse(W, H, px - 3 - k * 3, py - 5 - k * 3, 2 + k * 0.5, 2) & (img.a[..., 3] == 0), RAMP["stone"][3 - min(2, k)])
    # little baker gunner behind, only head and toque
    hx = x0 + 3
    put(img, m_ellipse(W, H, hx, 18 + b, 3, 3), RAMP["skin"][2])
    mass(img, m_ellipse(W, H, hx, 18 + b, 3, 3), "skin", "round", INK, base=2)
    mass(img, m_ellipse(W, H, hx - 0.5, 13.5 + b, 3, 2.5), "white", "round", INK, base=3)
    put(img, m_rect(W, H, hx + 1, 17 + b, 1, 1), INK)
    return img


def oven_frames():
    f = {"idle/0": oven(fire=0), "idle/1": oven(fire=1, smoke=1)}
    for i in range(4):
        f[f"walk/{i}"] = oven(roll_ph=i / 4, bob=1 if i % 2 else 0, fire=i % 2)
    seq = [dict(aim=-24, fire=1), dict(aim=-28, fire=2), dict(aim=-30, fire=3, smoke=1),
           dict(aim=-14, recoil=3, fire=3, smoke=2), dict(aim=-18, recoil=2, fire=1, smoke=3), dict(aim=-20, recoil=1, fire=0, smoke=2)]
    for i, k in enumerate(seq):
        f[f"attack/{i}"] = oven(**k)
    f["hit/0"] = oven(recoil=2, bob=1, broken=True)
    f["hit/1"] = oven(recoil=1, broken=True)
    base = oven(broken=True, aim=10)
    for i, (deg, sq) in enumerate(((0, 1.0), (6, 0.92), (12, 0.8), (16, 0.66), (18, 0.52))):
        f[f"death/{i}"] = _fall(base, 22, 39, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# ---------------------------------------------------------------------------------------------- enemies
def spitter(bob=0, lean=0, legs=((0, 0), (0, 0)), swell=0.0, mouth=0, eyes=True, glob=None):
    W = H = 32
    img = Img(W, H)
    b = bob
    hx = 13 + lean
    for i, (off, lift) in enumerate(legs):
        lx = int(round(9 + i * 6 + off))
        mass(img, m_poly(W, H, [(lx, 31 - lift), (lx + 1, 26 + b), (lx + 3, 26 + b), (lx + 4, 31 - lift)]), "hypha", "flat", INK_MOULD, base=1 + i)
    stalk = m_rect(W, H, 11 + lean // 2, 17 + b, 6, 10)
    mass(img, stalk, "hypha", "wall", INK_MOULD, base=2)
    # a gill frill collar, then the swollen bulb: the spitter's own shape (tall + round, no cap)
    frill = m_poly(W, H, [(hx - 6, 19 + b), (hx + 7, 19 + b), (hx + 5, 22 + b), (hx - 4, 22 + b)])
    mass(img, frill, "gill", "flat", INK_MOULD, base=2)
    r = 6.5 + swell
    bulb = m_ellipse(W, H, hx + 0.5, 12 + b - swell * 0.5, r, r * 0.95)
    lv = mass(img, bulb, "gill", "round", INK_MOULD, base=2)
    for (sx, sy) in ((-3, -3), (2, -5), (-1, 2), (4, 0)):
        put(img, m_ellipse(W, H, hx + sx, 12 + b + sy, 1, 1) & bulb, RAMP["gill"][4])
    if eyes:
        put(img, m_rect(W, H, hx + 2, 10 + b, 2, 2) | m_rect(W, H, hx + 5, 10 + b, 2, 2), EYE_FOE)
    else:
        put(img, m_rect(W, H, hx + 2, 11 + b, 5, 1), INK_MOULD)
    # mouth: an organ-green pucker on the front of the bulb, wider when it spits
    mm = m_ellipse(W, H, hx + 6, 15 + b, 1.5 + mouth, 1 + mouth * 0.7)
    put(img, mm, RAMP["organ"][2 + min(2, mouth)])
    put(img, m_ellipse(W, H, hx + 6, 15 + b, 0.6 + mouth * 0.6, 0.6), INK_MOULD)
    if glob is not None:
        gx, gy = glob
        g = m_ellipse(W, H, gx, gy + b, 2.2, 2)
        mass(img, g, "organ", "round", INK_MOULD, base=3)
    return img


def spitter_frames():
    f = {}
    for i, (bob, sw) in enumerate(((0, 0), (0, 0.5), (1, 1), (1, 0.5))):
        f[f"idle/{i}"] = spitter(bob=bob, swell=sw)
    for i in range(6):
        f[f"walk/{i}"] = spitter(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 2.0), swell=0.5 * (i % 2))
    f["attack/0"] = spitter(lean=-1, swell=1.5, mouth=0)
    f["attack/1"] = spitter(lean=-2, bob=1, swell=2.5, mouth=1)
    f["attack/2"] = spitter(lean=2, swell=0, mouth=2, glob=(27, 14))
    f["attack/3"] = spitter(lean=1, swell=0, mouth=1)
    f["hit/0"] = spitter(lean=-2, bob=1, swell=-0.5, eyes=False)
    f["hit/1"] = spitter(lean=-1, eyes=False)
    base = spitter(lean=-1, bob=1, eyes=False)
    for i, (deg, sq) in enumerate(((14, 1.0), (34, 1.0), (60, 1.0), (84, 1.0), (90, 0.8), (90, 0.6))):
        f[f"death/{i}"] = _fall(base, 13, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def _fly(img, x, y, wing, eyes=True, dive=0):
    W, H = img.w, img.h
    up = wing % 2 == 0
    wm = m_ellipse(W, H, x - 1, y - (4 if up else 0), 4, 2.5 if up else 2)
    put(img, wm, RAMP["wing"][3])
    put(img, m_ellipse(W, H, x - 1, y - (3 if up else 0), 1.5, 0.8) & wm, RAMP["wing"][4])
    body = m_ellipse(W, H, x, y + 1 + dive, 4, 3)
    mass(img, body, "fly", "round", INK_MOULD, base=2)
    put(img, m_rect(W, H, x - 3, y + 1 + dive, 2, 1) & body, RAMP["cloth"][1])      # rotten-fruit stripe
    put(img, m_rect(W, H, x + 2, y - 1 + dive, 3, 3), RAMP["cloth"][3] if eyes else RAMP["fly"][0])
    put(img, m_rect(W, H, x + 3, y - 1 + dive, 1, 1), RAMP["cloth"][4] if eyes else RAMP["fly"][0])


def swarm(ph=0, dy=(0, 0, 0), dive=0, eyes=True, arc=None):
    W, H = 32, 24
    img = Img(W, H)
    if arc:
        put(img, m_curve(W, H, arc, 1.8, 1.0), ARC_FOE)
    pos = ((8, 9), (19, 6), (14, 16))
    for k, (x, y) in enumerate(pos):
        _fly(img, x + (dive if k == 2 else 0), y + dy[k], ph + k, eyes, dive if k == 2 else 0)
    return img


def swarm_frames():
    f = {"idle/0": swarm(0, (0, 1, 0)), "idle/1": swarm(1, (1, 0, 1))}
    for i in range(4):
        f[f"walk/{i}"] = swarm(i, ((i % 2), ((i + 1) % 2), (i // 2)))
    f["attack/0"] = swarm(0, (-1, -1, -2))
    f["attack/1"] = swarm(1, (0, 0, 2), dive=4, arc=[(18, 13), (24, 17), (28, 21)])
    f["attack/2"] = swarm(0, (0, 1, 1), dive=2)
    f["hit/0"] = swarm(1, (2, 2, 1), eyes=False)
    f["hit/1"] = swarm(0, (1, 1, 0), eyes=False)
    for i in range(5):                                     # flies drop one by one, then the last falls
        img = Img(32, 24)
        for k, (x, y) in enumerate(((8, 9), (19, 6), (14, 16))):
            if k >= 3 - i // 2 and i >= 1:
                continue
            _fly(img, x, min(20, y + i * 3), 1, False)
        f[f"death/{i}"] = img
        f[f"die/{i}"] = img
    return f


def boar(bob=0, lean=0, gait=0.0, head=0, mouth=0, eyes=True, arc=None):
    W = H = 48
    img = Img(W, H)
    b = bob
    ph = gait * 2 * math.pi
    for i, (lx, s) in enumerate(((12, 1), (17, -1), (28, -1), (33, 1))):
        sw = math.sin(ph) * 3 * s if gait >= 0 else 0
        m = m_rect(W, H, int(round(lx + sw * 0.5)) + lean, 36 + b, 4, 11 - b) | m_rect(W, H, int(round(lx + sw)) + lean - 1, 45, 6, 2)
        mass(img, m, "boar", "flat", INK_MOULD, base=1 if i in (1, 2) else 2)
    # hunched barrel body, highest at the shoulders
    body = m_ellipse(W, H, 23 + lean, 31 + b, 15, 10) | m_ellipse(W, H, 30 + lean, 26 + b, 9, 8)
    lv = mass(img, body, "boar", "round", INK_MOULD, base=2)
    belly = body & m_rect(W, H, 0, 36 + b, W, 6)
    step(img, belly, "boar", lv, -1)
    # mould mane / back growth: caps and fuzz along the spine (the brute's silhouette)
    for k, (mx, my, r) in enumerate(((14, 21, 4), (20, 18, 5), (27, 16, 5.5), (33, 18, 4))):
        cp = m_ellipse(W, H, mx + lean, my + b, r, r * 0.6) & m_rect(W, H, 0, 0, W, my + b + 1)
        mass(img, cp, "cap", "round", INK_MOULD, base=2 + (k % 2))
        put(img, m_rect(W, H, mx + lean - 1, my + b + 1, 2, 3), RAMP["hypha"][3])
    put(img, m_ellipse(W, H, 18 + lean, 30 + b, 3, 2) & body, RAMP["organ"][2])          # rot patch glow
    # head: low, heavy, snout forward, two pale tusks
    hx, hy = 38 + lean + head, 30 + b + abs(head) // 2
    hd = m_ellipse(W, H, hx, hy, 7, 6) | m_rect(W, H, hx + 2, hy - 1, 7, 6)
    lvh = mass(img, hd, "boar", "round", INK_MOULD, base=3)
    snout = m_rect(W, H, hx + 7, hy, 3, 5)
    mass(img, snout, "gill", "flat", INK_MOULD, base=3)
    put(img, m_rect(W, H, hx + 8, hy + 1, 1, 1) | m_rect(W, H, hx + 8, hy + 3, 1, 1), INK_MOULD)
    for tx in (hx + 4, hx + 7):
        tusk = m_curve(W, H, [(tx, hy + 4 + mouth), (tx + 2, hy + 3 + mouth), (tx + 3, hy - 1)], 1.8, 1.0)
        mass(img, tusk, "white", "flat", INK_MOULD, base=3)
    ear = m_poly(W, H, [(hx - 4, hy - 4), (hx - 1, hy - 10), (hx + 1, hy - 4)])
    mass(img, ear, "boar", "flat", INK_MOULD, base=2)
    if eyes:
        put(img, m_rect(W, H, hx + 2, hy - 2, 2, 2), EYE_FOE)
        put(img, m_rect(W, H, hx + 3, hy - 2, 1, 1), RAMP["organ"][4])
    else:
        put(img, m_rect(W, H, hx + 1, hy - 1, 3, 1), INK_MOULD)
    if arc:
        put(img, m_curve(W, H, arc, 3.0, 1.0), ARC_FOE)
    return img


def boar_frames():
    f = {}
    for i, bob in enumerate((0, 0, 1, 1)):
        f[f"idle/{i}"] = boar(bob=bob, gait=-1)
    for i in range(6):
        f[f"walk/{i}"] = boar(bob=1 if i % 3 == 1 else 0, gait=i / 6)
    seq = [dict(lean=-2, head=-2, gait=-1), dict(lean=-3, head=-3, bob=1, gait=-1), dict(lean=-1, head=-4, gait=-1, mouth=1),
           dict(lean=3, head=2, gait=-1, mouth=1, arc=[(36, 18), (44, 22), (47, 30)]), dict(lean=1, head=1, gait=-1)]
    for i, k in enumerate(seq):
        f[f"attack/{i}"] = boar(**k)
    f["hit/0"] = boar(lean=-2, bob=1, gait=-1, eyes=False)
    f["hit/1"] = boar(lean=-1, gait=-1, eyes=False)
    base = boar(gait=-1, eyes=False)
    for i, (deg, sq) in enumerate(((0, 1.0), (-6, 0.95), (-12, 0.85), (-16, 0.75), (-18, 0.65), (-18, 0.55))):
        f[f"death/{i}"] = _fall(base, 21, 47, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


def yeast(bob=0, lean=0, legs=((0, 0), (0, 0)), r=8.0, spark=0, eyes=True, burst=0):
    W = H = 32
    img = Img(W, H)
    b = bob
    cx = 14 + lean
    if burst:
        for k in range(8):
            a = k * math.pi / 4
            d = 4 + burst * 4
            put(img, m_ellipse(W, H, cx + math.cos(a) * d, 18 + math.sin(a) * d * 0.8, 2.5 - burst * 0.3, 2), RAMP["yeast"][3 - min(2, burst)])
        put(img, m_ellipse(W, H, cx, 18, 6 - burst, 5 - burst), RAMP["fire"][3])
        return img
    for i, (off, lift) in enumerate(legs):
        lx = int(round(10 + i * 6 + off))
        mass(img, m_rect(W, H, lx, 27 + b, 2, 4 - lift) | m_rect(W, H, lx, 30 - lift, 3, 1), "hypha", "flat", INK_MOULD, base=1 + i)
    ball = m_ellipse(W, H, cx, 27 + b - r, r, r * 0.92)
    lv = mass(img, ball, "yeast", "round", INK_MOULD, base=2)
    for (sx, sy, sr) in ((-4, -2, 1.5), (3, -5, 1.2), (4, 2, 1.8), (-2, 4, 1.0), (-6, 3, 1.0)):
        bub = m_ellipse(W, H, cx + sx, 27 + b - r + sy, sr, sr)
        step(img, bub & ball, "yeast", lv, 1)
    put(img, m_ellipse(W, H, cx - 3, 27 + b - r * 1.5, 2, 1) & ball, RAMP["yeast"][4])
    if eyes:
        put(img, m_line(W, H, cx + 1, 23 + b - r, cx + 4, 25 + b - r, 1.2) | m_line(W, H, cx + 8, 23 + b - r, cx + 5, 25 + b - r, 1.2), INK_MOULD)
        put(img, m_rect(W, H, cx + 2, 25 + b - r, 2, 2) | m_rect(W, H, cx + 5, 25 + b - r, 2, 2), EYE_FOE)
        put(img, m_rect(W, H, cx + 2, 29 + b - r, 5, 1) | m_rect(W, H, cx + 3, 30 + b - r, 1, 1) | m_rect(W, H, cx + 5, 30 + b - r, 1, 1), INK_MOULD)
        for (sx, sy) in ((-5, -4), (-3, 3)):
            put(img, m_ellipse(W, H, cx + sx, 27 + b - r + sy, 1.6, 1.2) & ball, RAMP["mould"][2])
    else:
        put(img, m_rect(W, H, cx + 2, 26 + b - r, 5, 1), INK_MOULD)
    # fuse: a mould stalk on top with a fizzing spark (the bomber's tell)
    top = 27 + b - 2 * r
    fz = m_curve(W, H, [(cx, top + 1), (cx - 1, top - 2), (cx + 1, top - 4)], 1.6, 1.2)
    mass(img, fz, "hypha", "flat", INK_MOULD, base=2)
    sp = m_ellipse(W, H, cx + 1, top - 5, 1.5 + spark, 1.5 + spark)
    put(img, sp & (img.a[..., 3] == 0), RAMP["fire"][2 + min(2, spark)])
    put(img, m_rect(W, H, cx + 1, top - 5, 1, 1), RAMP["fire"][4])
    return img


def yeast_frames():
    f = {"idle/0": yeast(spark=0), "idle/1": yeast(bob=1, r=8.4, spark=1)}
    for i in range(6):
        f[f"walk/{i}"] = yeast(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 2.0), r=8 + 0.4 * (i % 2), spark=i % 2)
    f["attack/0"] = yeast(r=9.5, spark=2)
    f["attack/1"] = yeast(burst=1)
    f["attack/2"] = yeast(burst=2)
    f["hit/0"] = yeast(lean=-2, bob=1, r=7.5, eyes=False)
    f["hit/1"] = yeast(lean=-1, r=7.8, eyes=False)
    for i, k in enumerate((dict(r=9.0, spark=2, eyes=False), dict(r=10.0, spark=2, eyes=False), dict(burst=1), dict(burst=2), dict(burst=3), dict(burst=4))):
        f[f"death/{i}"] = yeast(**k)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


SETS = {"worker": (worker_frames, (14, 31)), "ranged_basic": (roll_frames, (13, 31)), "tank": (loaf_frames, (13, 31)),
        "fast": (pretzel_frames, (18, 31)), "siege": (oven_frames, (22, 39)), "e_spitter": (spitter_frames, (13, 31)),
        "e_swarm": (swarm_frames, (14, 23)), "e_brute": (boar_frames, (21, 47)), "e_bomber": (yeast_frames, (13, 31))}
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "release_slice")
PAGE_W, PAGE_H, PAD = 1024, 512, 2


def main():
    contract = json.load(open(os.path.join(ROOT, "assets", "atlases", "char_player.json"), encoding="utf-8"))
    page = Image.new("RGBA", (PAGE_W, PAGE_H), (0, 0, 0, 0))
    frames, anims, rendered = {}, {}, {}
    x = y = PAD
    shelf = 0
    for sid, (fn, pivot) in SETS.items():
        fr = fn()
        rendered[sid] = fr
        anims[sid] = {}
        for an, d in contract["anims"][sid].items():
            for nm in d["frames"]:
                key = nm.split("/", 1)[1]
                assert key in fr, f"{sid}: contract frame {nm} not drawn"
                ref = contract["frames"][nm]
                im = fr[key].pil()
                assert (im.width, im.height) == (ref["w"], ref["h"]) and list(pivot) == ref["pivot"], f"{nm}: size/pivot differ"
                if nm in frames:
                    continue
                if x + im.width + PAD > PAGE_W:
                    x = PAD
                    y += shelf + PAD * 2
                    shelf = 0
                assert y + im.height + PAD <= PAGE_H, "character page full"
                page.paste(im, (x, y))
                frames[nm] = {"x": x, "y": y, "w": im.width, "h": im.height, "pivot": list(pivot)}
                x += im.width + PAD * 2
                shelf = max(shelf, im.height)
            anims[sid][an] = dict(d)
    page.save(os.path.join(OUT, "slice_chars2.png"))
    json.dump({"schema": "defence.atlas/1", "atlas": "release_slice_chars2", "image": "slice_chars2.png", "size": [PAGE_W, PAGE_H],
               "padding": PAD, "extrude": 0, "group": "release_slice", "filter": "nearest", "mipmaps": False, "repeat": False,
               "gpu_format": "RGBA8", "gpu_bytes": PAGE_W * PAGE_H * 4, "used_rows": y + shelf + PAD, "frames": frames, "anims": anims},
              open(os.path.join(OUT, "slice_chars2.json"), "w", encoding="utf-8"), indent=1)
    print("chars2 page", PAGE_W, "x", PAGE_H, "used rows", y + shelf + PAD, "frames", len(frames))
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        rows = []
        for sid in SETS:
            for an, d in contract["anims"][sid].items():
                if an != "die":
                    rows.append((sid, [n.split("/", 1)[1] for n in d["frames"]]))
        sheet = Image.new("RGBA", (6 * 50 + 4, len(rows) * 50 + 4), (147, 184, 94, 255))
        for r, (sid, keys) in enumerate(rows):
            for i, k in enumerate(keys):
                im = rendered[sid][k].pil()
                sheet.paste(im, (2 + i * 50, 2 + r * 50 + (48 - im.height)), im)
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)
        print("sheet (generator output):", path)


if __name__ == "__main__":
    main()
