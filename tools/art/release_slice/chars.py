"""Hero, toast soldier and mould grunt in the release-slice style. Same contract as assets/atlases/char_player.json:
    hero_captain 48x48 pivot (22,47)  idle4 walk6 attack6(hit 3) cast6 hit2 death6 die6
    melee_basic  32x32 pivot (13,31)  idle4 walk6 attack5(hit 2) hit2 death6 die6
    e_grunt      32x32 pivot (13,31)  idle4 walk6 attack4(hit 2) hit2 death6 die6
All face right (the engine flips the enemy). fps / loop / hit_frame are copied from char_player.json at build time.

Readability rules used here:
  - one big head shape per unit that nobody else has: tall white toque / square crust-rimmed slice / lopsided dark cap;
  - the weapon leaves the body outline in every pose: rolling pin over the shoulder, bread knife held upright in
    front of the face, claw arm hanging forward; in a crowd the pins / blades / caps stay visible above the bodies;
  - attack = prepare (weapon up and back, body leans back) -> contact on the hit frame (weapon fully forward, body
    leans in, a short arc in the faction colour) -> recover (weapon low in front).
python tools/art/release_slice/chars.py [--sheet <png>]   writes assets/art/release_slice/slice_chars.{png,json}
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import (INK, INK_MOULD, RAMP, Img, grow, hexc, m_curve, m_ellipse, m_line, m_poly, m_rect, mass, paint, put, rim,  # noqa: E402
                 shift, step)

RAMP["skin"] = [hexc(c) for c in ("a8674a", "cf8f66", "eab58a", "f7d3ad", "ffe9cf")]
RAMP["white"] = [hexc(c) for c in ("a79c8e", "cfc6b6", "ece5d6", "faf5ea", "ffffff")]
ARC_ALLY = hexc("fff0a8")
ARC_FOE = hexc("9fe6cf")


HILITE = hexc("ffffff")
BLUSH = hexc("f2a08a")


def eye(img, x, y, ink=INK, h=3, hi=HILITE):
    """The shared cute eye: 2 px wide, h tall, a white catch-light in the upper-left pixel."""
    put(img, m_rect(img.w, img.h, int(x), int(y), 2, h), ink)
    put(img, m_rect(img.w, img.h, int(x), int(y), 1, 1), hi)


def blush(img, x, y, w=2):
    put(img, m_rect(img.w, img.h, int(x), int(y), w, 1), BLUSH)


def _ang(x, y, deg, ln):
    r = math.radians(deg)
    return x + math.cos(r) * ln, y + math.sin(r) * ln


def _fall(img: Img, px: int, py: int, deg: float, squash: float = 1.0) -> Img:
    """Rotate the figure backwards about its feet (death) on a padded canvas, then slide it back into the frame so
    the lying body is never cut by the frame edge. The lowest opaque row stays on the ground line."""
    pad = img.w
    big = Image.new("RGBA", (img.w + pad * 2, img.h + pad), (0, 0, 0, 0))
    big.paste(img.pil(), (pad, pad))
    big = big.rotate(deg, resample=Image.NEAREST, center=(px + pad, py + pad))
    a = np.array(big)
    ys, xs = np.where(a[..., 3] > 0)
    out = Img(img.w, img.h)
    if len(ys) == 0:
        return out
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    crop = a[y0:y1, x0:x1]
    if squash < 1.0:
        nh = max(3, int(round(crop.shape[0] * squash)))
        crop = crop[np.minimum(crop.shape[0] - 1, (np.arange(nh) * (crop.shape[0] / nh)).astype(int))]
    ch, cw = crop.shape[:2]
    cw = min(cw, img.w)
    ch = min(ch, img.h)
    crop = crop[-ch:, :cw]
    # keep the feet side near the pivot, but inside the frame
    left = int(np.clip((x0 - pad), 0, img.w - cw))
    out.a[py + 1 - ch:py + 1, left:left + cw] = crop
    return out


# ------------------------------------------------------------------------------------------------------------
# hero_captain: stout baker captain. Tall toque, moustache, jam-red cape, a rolling pin as long as his body.
def hero(bob=0, lean=0, legs=((0, 0), (0, 0)), hand=(29, 36), pin=-48.0, cape=0, tilt=0, arc=None, eyes=True, glow=False) -> Img:
    W = H = 48
    img = Img(W, H)
    cx = 22 + lean * 0.5
    hx = 22 + lean                      # head / shoulders shift further than the hips
    b = bob
    # cape (behind everything)
    cp = m_poly(W, H, [(hx - 5, 26 + b), (hx - 1, 26 + b), (cx - 2, 44 + b), (cx - 11 - cape, 44 + b - abs(cape) * 0.5), (cx - 9 - cape * 0.5, 36 + b)])
    mass(img, cp, "cloth", "flat", INK, base=2)
    put(img, cp & m_rect(W, H, 0, 42 + b, W, 3), RAMP["cloth"][1])
    # legs: back leg darker
    for i, (off, lift) in enumerate(legs):
        lx = 18 + i * 5 + off
        leg = m_rect(W, H, int(round(lx)), 37 + b, 3, 11 - b - lift)
        boot = m_rect(W, H, int(round(lx)), 45 - lift, 5, 3)
        mass(img, leg | boot, "timber", "flat", INK, base=1 if i == 0 else 2)
    # body: white double-breasted jacket, round
    body = m_ellipse(W, H, cx, 32.5 + b, 7, 8)
    lv = mass(img, body, "white", "round", INK, base=3)
    for by in (29, 33):
        for bx in (0, 4):
            put(img, m_rect(W, H, int(cx) + bx, by + b, 2, 2), RAMP["wheat"][2])
    put(img, m_rect(W, H, int(cx) - 7, 38 + b, 15, 2) & body, RAMP["timber"][2])       # belt
    # neckerchief
    nk = m_poly(W, H, [(hx - 3, 25 + b), (hx + 4, 25 + b), (hx + 1, 28 + b)])
    mass(img, nk, "cloth", "flat", INK, base=3)
    # head
    head = m_ellipse(W, H, hx + 1, 20.5 + b, 6.0, 4.8)
    mass(img, head, "skin", "round", INK, base=2)
    if eyes:
        eye(img, int(hx) + 3, 18 + b)
    else:
        put(img, m_rect(W, H, int(hx) + 3, 19 + b, 3, 1), INK)
    put(img, m_rect(W, H, int(hx) + 5, 20 + b, 2, 2), RAMP["skin"][1])                 # nose
    blush(img, int(hx) + 1, 21 + b)                                                       # cheek
    mo = m_rect(W, H, int(hx) + 1, 22 + b, 7, 1) | m_rect(W, H, int(hx), 23 + b, 2, 1) | m_rect(W, H, int(hx) + 6, 23 + b, 2, 1)
    put(img, mo, RAMP["wood"][0])
    put(img, m_rect(W, H, int(hx) + 2, 22 + b, 4, 1), RAMP["wood"][2])
    # toque: band + one tall puff, leaning with the motion
    band = m_rect(W, H, int(hx) - 3, 14 + b, 9, 3)
    puff = m_ellipse(W, H, hx + 1 + tilt, 9.5 + b, 6.0, 5.0) | m_rect(W, H, int(hx) - 2 + int(tilt * 0.5), 10 + b, 8, 5)
    lvh = mass(img, puff, "white", "round", INK, base=3)
    step(img, puff & (m_line(W, H, hx - 1 + tilt, 6 + b, hx - 2, 13 + b, 1.2) | m_line(W, H, hx + 4 + tilt, 6 + b, hx + 4, 13 + b, 1.2)), "white", lvh, -1)
    mass(img, band, "white", "flat", INK, base=2)
    # arc of the swing (behind the pin, in front of the body)
    if arc:
        am = m_curve(W, H, arc, 3.2, 1.0)
        put(img, am, ARC_ALLY)
    # arm + rolling pin
    sx, sy = hx + 3, 28 + b
    gx, gy = hand[0] + lean, hand[1] + b
    arm = m_line(W, H, sx, sy, gx, gy, 3.4)
    mass(img, arm, "white", "flat", INK, base=2)
    h0 = _ang(gx, gy, pin, -3)
    r0 = _ang(gx, gy, pin, 2)
    r1 = _ang(gx, gy, pin, 17)
    h1 = _ang(gx, gy, pin, 21)
    handles = m_line(W, H, h0[0], h0[1], h1[0], h1[1], 2.0)
    mass(img, handles, "timber", "flat", INK, base=2)
    roller = m_line(W, H, r0[0], r0[1], r1[0], r1[1], 5.2)
    lvp = mass(img, roller, "wood", "flat", INK, base=3)
    step(img, roller & m_line(W, H, r0[0], r0[1] - 1, r1[0], r1[1] - 1, 1.2), "wood", lvp, 1)
    put(img, m_ellipse(W, H, gx, gy, 2, 2), RAMP["skin"][2])
    rim(img, m_ellipse(W, H, gx, gy, 2, 2), INK, only_empty=True)
    if glow:
        tip = _ang(gx, gy, pin, 21)
        g = m_ellipse(W, H, tip[0], tip[1], 4, 4)
        put(img, g & (img.a[..., 3] == 0), RAMP["fire"][4])
        put(img, grow(g, 1) & ~g & (img.a[..., 3] == 0), RAMP["fire"][3])
    return img


def _walk_legs(i, n=6, stride=3.0):
    ph = 2 * math.pi * i / n
    a = (math.sin(ph) * stride, max(0.0, math.cos(ph)) * 2)
    b = (-math.sin(ph) * stride, max(0.0, -math.cos(ph)) * 2)
    return ((round(a[0]), int(round(a[1]))), (round(b[0]), int(round(b[1]))))


def hero_frames():
    f = {}
    for i, (bob, cape, tilt) in enumerate(((0, 0, 0), (0, 1, 0), (1, 1, -1), (1, 0, 0))):
        f[f"idle/{i}"] = hero(bob=bob, cape=cape, tilt=tilt)
    for i in range(6):
        legs = _walk_legs(i)
        bob = 1 if i in (1, 4) else 0
        f[f"walk/{i}"] = hero(bob=bob, lean=1, legs=legs, cape=2 + (i % 2), tilt=-1, hand=(29, 36), pin=-44 - (i % 2) * 5)
    # attack: 0-2 prepare (pin up and back), 3 contact, 4-5 recover
    atk = [
        dict(lean=-1, hand=(20, 22), pin=-118, cape=-1, tilt=-1),
        dict(lean=-2, bob=1, hand=(18, 20), pin=-150, cape=-2, tilt=-2),
        dict(lean=1, hand=(27, 19), pin=-62, cape=1, tilt=0, legs=((-1, 0), (1, 0))),
        dict(lean=4, bob=1, hand=(31, 31), pin=6, cape=4, tilt=1, legs=((-2, 0), (3, 0)), arc=[(30, 8), (39, 12), (45, 22), (46, 32)]),
        dict(lean=3, bob=1, hand=(30, 36), pin=42, cape=3, tilt=1, legs=((-2, 0), (3, 0)), arc=[(44, 24), (46, 34), (43, 42)]),
        dict(lean=1, hand=(28, 34), pin=-20, cape=1, tilt=0, legs=((-1, 0), (1, 0))),
    ]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = hero(**k)
    cast = [dict(hand=(26, 30), pin=-80), dict(lean=-1, bob=1, hand=(25, 26), pin=-88, tilt=-1), dict(lean=-1, hand=(25, 22), pin=-90, tilt=-1),
            dict(hand=(25, 19), pin=-90, cape=1), dict(hand=(25, 18), pin=-90, cape=2, glow=True), dict(hand=(26, 24), pin=-84, cape=1)]
    for i, k in enumerate(cast):
        f[f"cast/{i}"] = hero(**k)
    f["hit/0"] = hero(lean=-3, bob=1, hand=(25, 34), pin=-40, cape=-2, tilt=-2, eyes=False)
    f["hit/1"] = hero(lean=-2, hand=(26, 33), pin=-55, cape=-1, tilt=-1, eyes=False)
    base = hero(lean=-2, bob=1, hand=(25, 34), pin=-30, cape=-2, tilt=-2, eyes=False)
    for i, (deg, sq) in enumerate(((12, 1.0), (30, 1.0), (55, 1.0), (80, 1.0), (90, 0.9), (90, 0.8))):
        f[f"death/{i}"] = _fall(base, 22, 47, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# ------------------------------------------------------------------------------------------------------------
# melee_basic: the slice of toast IS the body. Crust rim, crumb face, red headband, bread knife.
def toast(bob=0, lean=0, legs=((0, 0), (0, 0)), hand=(21, 21), knife=-88.0, arc=None, eyes=True, band=0) -> Img:
    W = H = 32
    img = Img(W, H)
    b = bob
    x0 = 6 + lean
    for i, (off, lift) in enumerate(legs):
        lx = int(round(9 + i * 6 + off + lean * 0.3))
        leg = m_rect(W, H, lx, 26 + b, 2, 6 - b - lift) | m_rect(W, H, lx, 30 - lift, 4, 2)
        mass(img, leg, "timber", "flat", INK, base=1 if i == 0 else 2)
    # the slice: square with two bumps on top
    sl = m_rect(W, H, x0 + 1, 13 + b, 13, 14) | m_rect(W, H, x0, 14 + b, 15, 12) | m_ellipse(W, H, x0 + 4.5, 13 + b, 4.5, 3.5) | m_ellipse(W, H, x0 + 10.5, 13 + b, 4.5, 3.5)
    lvc = mass(img, sl, "crust", "flat", INK, base=2)
    inner = sl & shift(sl, 2, 0) & shift(sl, -2, 0) & shift(sl, 0, 2) & shift(sl, 0, -2)
    lvi = paint(img, inner, "crumb", "flat", base=3)
    # face on the right half (it looks where it walks)
    ey = 18 + b
    if eyes:
        eye(img, x0 + 7, ey - 1)
        eye(img, x0 + 11, ey - 1)
    else:
        put(img, m_rect(W, H, x0 + 7, ey + 1, 2, 1) | m_rect(W, H, x0 + 10, ey + 1, 2, 1), INK)
    put(img, m_rect(W, H, x0 + 9, ey + 4, 2, 1), RAMP["crust"][0])
    blush(img, x0 + 5, ey + 3)
    blush(img, x0 + 12, ey + 3)
    # red headband with a knot tail behind
    hb = m_rect(W, H, x0, 15 + b, 15, 2) & sl
    put(img, hb, RAMP["cloth"][2])
    tail = m_rect(W, H, x0 - 2, 15 + b + (1 if band > 1 else 0), 2, 3)          # a short knot, not a streamer
    mass(img, tail, "cloth", "flat", INK, base=3)
    if arc:
        put(img, m_curve(W, H, arc, 2.6, 1.0), ARC_ALLY)
    # arm stub + bread knife (long pale blade, dark handle)
    sx, sy = x0 + 13, 21 + b
    gx, gy = hand[0] + lean, hand[1] + b
    mass(img, m_line(W, H, sx, sy, gx, gy, 2.4), "crust", "flat", INK, base=3)
    k0 = _ang(gx, gy, knife, 2)
    k1 = _ang(gx, gy, knife, 13)
    blade = m_line(W, H, k0[0], k0[1], k1[0], k1[1], 2.6)
    mass(img, blade, "iron", "flat", INK, base=4)
    hd = m_line(W, H, gx, gy, k0[0], k0[1], 2.6)
    mass(img, hd, "timber", "flat", INK, base=2)
    return img


def toast_frames():
    f = {}
    for i, (bob, band) in enumerate(((0, 0), (0, 1), (1, 1), (1, 0))):
        f[f"idle/{i}"] = toast(bob=bob, band=band)
    for i in range(6):
        f[f"walk/{i}"] = toast(bob=1 if i in (1, 4) else 0, lean=1, legs=_walk_legs(i, 6, 2.0), band=1 + i % 2, hand=(21, 21), knife=-80 - (i % 2) * 6)
    atk = [
        dict(lean=-1, hand=(18, 14), knife=-112, band=-1),
        dict(lean=-2, bob=1, hand=(16, 12), knife=-142, band=-2),
        dict(lean=3, bob=1, hand=(22, 20), knife=4, band=3, legs=((-1, 0), (2, 0)), arc=[(20, 6), (26, 9), (30, 15), (31, 21)]),
        dict(lean=2, bob=1, hand=(22, 24), knife=44, band=2, legs=((-1, 0), (2, 0))),
        dict(lean=0, hand=(21, 22), knife=-50, band=1),
    ]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = toast(**k)
    f["hit/0"] = toast(lean=-2, bob=1, hand=(19, 23), knife=-40, eyes=False, band=-1)
    f["hit/1"] = toast(lean=-1, hand=(20, 22), knife=-60, eyes=False)
    base = toast(lean=-1, bob=1, hand=(19, 23), knife=-30, eyes=False)
    for i, (deg, sq) in enumerate(((14, 1.0), (34, 1.0), (60, 1.0), (84, 1.0), (90, 0.85), (90, 0.7))):
        f[f"death/{i}"] = _fall(base, 13, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# ------------------------------------------------------------------------------------------------------------
# e_grunt: mould minion. Lopsided torn cap that droops behind it, wet belly, one long hooked claw arm.
def grunt(bob=0, lean=0, legs=((0, 0), (0, 0)), arm=((21, 24), (23, 28)), cap=0, arc=None, eye=True) -> Img:
    W = H = 32
    img = Img(W, H)
    b = bob
    cx = 13 + lean * 0.5
    hx = 13 + lean
    for i, (off, lift) in enumerate(legs):
        lx = int(round(9 + i * 6 + off))
        foot = m_poly(W, H, [(lx, 31 - lift), (lx + 1, 27 + b), (lx + 3, 27 + b), (lx + 5, 31 - lift)])
        mass(img, foot, "hypha", "flat", INK_MOULD, base=1 if i == 0 else 2)
    belly = m_ellipse(W, H, cx + 0.5, 24.5 + b, 5.5, 5)
    lv = mass(img, belly, "mould", "round", INK_MOULD, base=2)
    step(img, belly & m_curve(W, H, [(cx - 3, 26 + b), (cx + 1, 28 + b), (cx + 4, 25 + b)], 1.2), "mould", lv, -1)
    # a pale face under the cap: the stalk's head, with a dark band and two bright eyes (the only bright thing on it)
    face = m_ellipse(W, H, hx + 1.5, 17.5 + b, 5, 4)
    mass(img, face, "hypha", "round", INK_MOULD, base=3)
    put(img, m_rect(W, H, int(hx) - 1, 17 + b, 8, 3) & face, INK_MOULD)
    if eye:
        for ex0 in (int(hx) + 0, int(hx) + 4):
            put(img, m_rect(W, H, ex0, 17 + b, 2, 2), RAMP["organ"][3])
            put(img, m_rect(W, H, ex0 + 1, 17 + b, 1, 1), RAMP["organ"][4])
    else:
        put(img, m_rect(W, H, int(hx), 18 + b, 6, 1) & face, RAMP["gill"][2])
    # cap: big overhang behind (left), short torn brim in front; it sits above the eyes
    cpx = hx - 1 + cap
    capm = (m_ellipse(W, H, cpx, 14 + b, 10.5, 7.5) & m_rect(W, H, 0, 0, W, 15 + b)) | m_poly(W, H, [(cpx - 10.5, 14 + b), (cpx - 4, 14 + b), (cpx - 9, 20 + b)])
    capm &= ~m_poly(W, H, [(cpx + 5, 15 + b), (cpx + 9, 15 + b), (cpx + 7, 11 + b)])            # the tear
    gl = shift(capm, 0, 1) & ~capm & m_rect(W, H, int(cpx) - 9, 0, 12, H)
    put(img, gl, RAMP["gill"][2])
    lvc = mass(img, capm, "cap", "round", INK_MOULD, base=2)
    step(img, capm & (m_ellipse(W, H, cpx - 3, 9.5 + b, 3, 1.5) | m_ellipse(W, H, cpx + 4, 11 + b, 1.5, 1) | m_ellipse(W, H, cpx - 7, 13 + b, 1.5, 1)), "cap", lvc, 2)
    if arc:
        put(img, m_curve(W, H, arc, 2.6, 1.0), ARC_FOE)
    # claw arm: shoulder -> elbow -> wrist, two pale hooks
    sx, sy = hx + 3, 21 + b
    (ex, ey), (wx, wy) = arm
    ex += lean
    wx += lean
    armm = m_curve(W, H, [(sx, sy), (ex, ey + b), (wx, wy + b)], 2.8, 2.2)
    mass(img, armm, "hypha", "flat", INK_MOULD, base=2)
    dx, dy = wx - ex, wy - ey
    ln = max(1.0, math.hypot(dx, dy))
    ux, uy = dx / ln, dy / ln
    for s in (-1, 1):
        hook = m_curve(W, H, [(wx, wy + b), (wx + ux * 2 - uy * s * 1.5, wy + b + uy * 2 + ux * s * 1.5), (wx + ux * 4 - uy * s * 0.5, wy + b + uy * 4 + ux * s * 0.5)], 1.8, 1.2)
        mass(img, hook, "hypha", "flat", INK_MOULD, base=4)
    return img


def grunt_frames():
    f = {}
    for i, (bob, cap) in enumerate(((0, 0), (0, 0), (1, -1), (1, 0))):
        f[f"idle/{i}"] = grunt(bob=bob, cap=cap)
    for i in range(6):
        f[f"walk/{i}"] = grunt(bob=1 if i in (1, 4) else 0, lean=2, legs=_walk_legs(i, 6, 2.0), cap=-1 - (i % 2), arm=((21, 23), (24, 26 + (i % 2))))
    atk = [
        dict(lean=-2, arm=((15, 13), (11, 9)), cap=-1),
        dict(lean=-3, bob=1, arm=((13, 12), (8, 10)), cap=-2),
        dict(lean=3, bob=1, arm=((21, 18), (27, 21)), cap=2, legs=((-1, 0), (2, 0)), arc=[(16, 6), (24, 8), (29, 13), (31, 19)]),
        dict(lean=2, arm=((20, 24), (23, 28)), cap=1, legs=((-1, 0), (1, 0))),
    ]
    for i, k in enumerate(atk):
        f[f"attack/{i}"] = grunt(**k)
    f["hit/0"] = grunt(lean=-3, bob=1, arm=((19, 25), (20, 29)), cap=-2, eye=False)
    f["hit/1"] = grunt(lean=-2, arm=((20, 24), (22, 28)), cap=-1, eye=False)
    base = grunt(lean=-2, bob=1, arm=((19, 25), (20, 29)), cap=-2, eye=False)
    for i, (deg, sq) in enumerate(((14, 1.0), (34, 1.0), (60, 1.0), (84, 1.0), (90, 0.8), (90, 0.6))):
        f[f"death/{i}"] = _fall(base, 13, 31, deg, sq)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


SETS = {"hero_captain": (hero_frames, (22, 47)), "melee_basic": (toast_frames, (13, 31)), "e_grunt": (grunt_frames, (13, 31))}
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "release_slice")
PAGE_W, PAGE_H, PAD = 512, 512, 2


def main():
    contract = json.load(open(os.path.join(ROOT, "assets", "atlases", "char_player.json"), encoding="utf-8"))
    page = Image.new("RGBA", (PAGE_W, PAGE_H), (0, 0, 0, 0))
    frames, anims = {}, {}
    x = y = PAD
    shelf = 0
    rendered = {}
    for sid, (fn, pivot) in SETS.items():
        fr = fn()
        rendered[sid] = fr
        anims[sid] = {}
        for an, d in contract["anims"][sid].items():
            names = d["frames"]
            for nm in names:
                key = nm.split("/", 1)[1]                    # "idle/0"
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
            anims[sid][an] = dict(d)                          # fps / loop / hit_frame / events exactly as the contract
        assert len(fr) == len({n.split("/", 1)[1] for a in contract["anims"][sid].values() for n in a["frames"]}), f"{sid}: frame count differs"
    page.save(os.path.join(OUT, "slice_chars.png"))
    meta = {"schema": "defence.atlas/1", "atlas": "release_slice_chars", "image": "slice_chars.png",
            "image_res": "res://assets/art/release_slice/slice_chars.png", "size": [PAGE_W, PAGE_H], "padding": PAD, "extrude": 0,
            "group": "release_slice", "filter": "nearest", "mipmaps": False, "repeat": False, "gpu_format": "RGBA8",
            "gpu_bytes": PAGE_W * PAGE_H * 4, "used_rows": y + shelf + PAD, "frames": frames, "anims": anims}
    json.dump(meta, open(os.path.join(OUT, "slice_chars.json"), "w", encoding="utf-8"), indent=1)
    print("chars page", PAGE_W, "x", PAGE_H, "used rows", y + shelf + PAD, "frames", len(frames))
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        rows = []
        for sid in SETS:
            for an in ("idle", "walk", "attack", "cast", "hit", "death"):
                if an in contract["anims"][sid]:
                    rows.append((sid, an, [n.split("/", 1)[1] for n in contract["anims"][sid][an]["frames"]]))
        sheet = Image.new("RGBA", (6 * 50 + 4, len(rows) * 50 + 4), (147, 184, 94, 255))
        for r, (sid, an, keys) in enumerate(rows):
            for i, k in enumerate(keys):
                im = rendered[sid][k].pil()
                sheet.paste(im, (2 + i * 50, 2 + r * 50 + (48 - im.height)), im)
        sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
        sheet.save(path)
        print("sheet (generator output, not a game screen):", path)


if __name__ == "__main__":
    main()
