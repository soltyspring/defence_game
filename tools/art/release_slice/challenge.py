"""Challenge enemies (R31-R40) and the nest core in the release-slice style. Contract: assets/atlases/char_challenge.json
(sizes, pivots, frame counts, fps, hit / summon frames copied; the build fails on any difference).
Every one of them has a heavy move, so all share two readable signals, as in lane games with telegraphed attacks:
    heavy_prepare  the body tenses and its eyes / organs flare hot (orange-red) - "something big is coming"
    heavy_exposed  it is dazed: eyes go to X, a soft weak spot shows, little stars circle - "hit it now"
Units:
    e_thrall      균사 호위병   42x40 (16,39)  armoured mould guard with a fungus maul (slam)
    e_binder      균사 매듭     32x36 (14,35)  hooded weaver; a glowing knot between its hands (links to the boss)
    e_frostshell  서리 갑각병   40x36 (16,35)  hermit in an ice shell; vents steam, shell lifts to show the body
    e_icerunner   빙결 질주자   50x28 (20,27)  low ice lizard, crouches then dashes with a frost streak
    e_sporesac    발효 포자낭   34x44 (15,43)  walking fermenting sac that swells and lobs a spore ball
    e_burrower    균사 잠입병   42x36 (16,35)  mole with a hyphae drill snout; digs in, pops out dazed
    boss_nestcore 둥지의 핵     76x68 (35,67)  a heart-core caged in root ribs, crawling on root legs; ribs open when exposed
python tools/art/release_slice/challenge.py [--sheet <png>]   writes assets/art/release_slice/slice_challenge.{png,json}
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
from chars import ARC_FOE, _ang  # noqa: E402
import bosses  # noqa: E402  (registers ice / bark / robe ramps, crumble, glow_eye)
import chars2  # noqa: E402,F401  (registers yeast / boar ramps)
from bosses import crumble, glow_eye  # noqa: E402

INK = INK_MOULD
HOT = [hexc(c) for c in ("8a2a1c", "c4462a", "ee7a3a", "ffb45a", "ffe7a8")]
SOFT = [hexc(c) for c in ("8a4a6a", "b4688a", "d890a8", "f2bccb", "ffe2ea")]
STAR = hexc("ffe68a")


def eyes(img, pts, state):
    """state: 'n' normal glow, 'h' hot (prepare), 'x' dazed (exposed), 'c' closed (hit)."""
    for (x, y) in pts:
        if state == "x":
            put(img, m_rect(img.w, img.h, x, y, 1, 1) | m_rect(img.w, img.h, x + 2, y, 1, 1) | m_rect(img.w, img.h, x + 1, y + 1, 1, 1) |
                m_rect(img.w, img.h, x, y + 2, 1, 1) | m_rect(img.w, img.h, x + 2, y + 2, 1, 1), STAR)
        elif state == "h":
            put(img, m_rect(img.w, img.h, x, y, 2, 2), HOT[3])
            put(img, m_rect(img.w, img.h, x, y, 1, 1), HOT[4])
        elif state == "c":
            put(img, m_rect(img.w, img.h, x, y + 1, 3, 1), INK)
        else:
            glow_eye(img, x, y, True)


def stars(img, cx, cy, ph, r=6):
    for k in range(3):
        a = ph + k * 2 * math.pi / 3
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r * 0.4
        put(img, m_rect(img.w, img.h, int(x), int(y) - 1, 1, 3) | m_rect(img.w, img.h, int(x) - 1, int(y), 3, 1), STAR)


def heat(img, mask):
    """Hot rim on a mass during the wind-up."""
    edge = grow(mask) & ~mask & (img.a[..., 3] == 0)
    put(img, edge, HOT[2] + (0,) if False else HOT[2])


def _legs2(img, x0, gap, top, b, legs, ramp, w=4, foot=6, H=None):
    H = H or img.h
    for i, (off, lift) in enumerate(legs):
        lx = int(round(x0 + i * gap + off))
        m = m_rect(img.w, H, lx, top + b, w, H - 2 - top - b - lift) | m_rect(img.w, H, lx - 1, H - 2 - lift, foot, 2)
        mass(img, m, ramp, "flat", INK, base=1 + i)


def _walk(i, n=6, s=3):
    ph = 2 * math.pi * i / n
    return ((round(math.sin(ph) * s), int(max(0, math.cos(ph)) * 2)), (round(-math.sin(ph) * s), int(max(0, -math.cos(ph)) * 2)))


def standard(fn, death_pivot, n_death=5, seed=0, heavy=None):
    """Common frame table: idle4 walk6 attack(n) hit2 death5 + heavy_prepare4 / release1 / exposed4."""
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = fn(b=1 if i >= 2 else 0, ph=i)
    for i in range(6):
        f[f"walk/{i}"] = fn(b=1 if i in (1, 4) else 0, legs=_walk(i), lean=1, ph=i)
    for k, v in heavy.items():
        for i, kw in enumerate(v):
            f[f"{k}/{i}"] = fn(**kw)
    f["hit/0"] = fn(lean=-2, b=1, state="c")
    f["hit/1"] = fn(lean=-1, state="c")
    base = fn(state="c")
    for i in range(n_death):
        f[f"death/{i}"] = crumble(base, i / (n_death - 1), seed + i, sink=6)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# ---------------------------------------------------------------------------------------------- e_thrall 42x40
def thrall(b=0, lean=0, legs=((0, 0), (0, 0)), maul=-70.0, hand=(30, 22), state="n", arc=None, ph=0, open_=False, quake=0):
    W, H = 42, 40
    img = Img(W, H)
    cx = 16 + lean
    _legs2(img, cx - 7, 8, 30, b, legs, "bark", w=5, foot=7)
    body = m_ellipse(W, H, cx, 25 + b, 10, 8)
    lv = mass(img, body, "mould", "round", INK, base=2)
    if open_:                                     # exposed: armour plates lifted, a soft glowing belly
        put(img, m_ellipse(W, H, cx + 1, 27 + b, 5, 4), SOFT[2])
        put(img, m_ellipse(W, H, cx, 26 + b, 2, 1.5), SOFT[4])
    # armour plates (stone shell) over the back and shoulders
    for k, (px, py, r) in enumerate(((-6, 19, 6), (0, 16, 6.5), (6, 18, 5))):
        pl = m_ellipse(W, H, cx + px, py + b - (2 if open_ else 0), r, r * 0.6) & m_rect(W, H, 0, 0, W, int(py + b) + 2)
        mass(img, pl, "stone", "round", INK, base=2 + (k == 1))
    face = m_ellipse(W, H, cx + 6, 21 + b, 4.5, 3.5)
    mass(img, face, "hypha", "round", INK, base=3)
    eyes(img, [(int(cx) + 5, 20 + b), (int(cx) + 8, 20 + b)], state)
    if state == "h":
        heat(img, body)
    if arc:
        put(img, m_curve(W, H, arc, 3.0, 1.0), ARC_FOE)
    # maul: thick stalk handle, a big cap head
    gx, gy = hand[0] + lean, hand[1] + b
    mass(img, m_line(W, H, cx + 7, 24 + b, gx, gy, 3.2), "mould", "flat", INK, base=2)
    e = _ang(gx, gy, maul, 12)
    mass(img, m_line(W, H, *_ang(gx, gy, maul, -3), *e, 2.2), "hypha", "flat", INK, base=2)
    hd = m_ellipse(W, H, e[0], e[1], 5.5, 4)
    lvh = mass(img, hd, "cap", "round", INK, base=3)
    if state == "h":
        put(img, m_ellipse(W, H, e[0], e[1], 2, 1.5) & hd, HOT[3])
    for k in range(quake):
        put(img, m_rect(W, H, 28 + k * 4, 37 - k, 3, 1) & (img.a[..., 3] == 0), RAMP["earth"][3])
    if state == "x":
        stars(img, cx + 6, 13 + b, ph)
    return img


def thrall_frames():
    atk = [dict(hand=(26, 16), maul=-120), dict(hand=(22, 12), maul=-150, lean=-2, b=1), dict(hand=(24, 14), maul=-140, lean=-1),
           dict(hand=(34, 30), maul=20, lean=3, arc=[(28, 4), (38, 12), (41, 26)]), dict(hand=(33, 31), maul=50, lean=2), dict(hand=(30, 24), maul=-40)]
    heavy = {"attack": atk,
             "heavy_prepare": [dict(hand=(20, 10), maul=-155, lean=-3, b=1, state="h"), dict(hand=(20, 9), maul=-158, lean=-3, state="h"),
                               dict(hand=(20, 10), maul=-155, lean=-3, b=1, state="h"), dict(hand=(20, 9), maul=-160, lean=-3, state="h")],
             "heavy_release": [dict(hand=(34, 32), maul=40, lean=4, b=1, quake=3, arc=[(26, 2), (38, 10), (41, 28)])],
             "heavy_exposed": [dict(open_=True, state="x", ph=i * 0.6, hand=(30, 30), maul=60, lean=-1) for i in range(4)]}
    return standard(thrall, (16, 39), seed=101, heavy=heavy)


# ---------------------------------------------------------------------------------------------- e_binder 32x36
def binder(b=0, lean=0, legs=((0, 0), (0, 0)), knot=1.0, hands=(21, 22), state="n", ph=0, thread=0):
    W, H = 32, 36
    img = Img(W, H)
    cx = 13 + lean
    robe = m_poly(W, H, [(cx - 5, 16 + b), (cx + 5, 16 + b), (cx + 8, 34), (cx - 8, 34)])
    lv = mass(img, robe, "robe", "flat", INK, base=2)
    for k, (ox, lift) in enumerate(legs):
        put(img, m_rect(W, H, int(cx) - 4 + k * 5 + ox, 33 - lift, 3, 2), RAMP["robe"][0])
    put(img, m_line(W, H, cx - 6, 30, cx + 7, 30, 1.0) & robe, RAMP["gill"][3])
    hood = m_ellipse(W, H, cx, 12 + b, 7, 7) | m_poly(W, H, [(cx - 6, 12 + b), (cx - 9, 19 + b), (cx - 3, 16 + b)])
    mass(img, hood, "robe", "round", INK, base=3)
    put(img, m_ellipse(W, H, cx + 2, 13 + b, 4, 3.5), RAMP["robe"][0])
    eyes(img, [(int(cx) + 1, 12 + b), (int(cx) + 4, 12 + b)], state)
    # hyphae strands hanging from the hood
    for k in range(3):
        put(img, m_line(W, H, cx - 4 + k * 2, 18 + b, cx - 5 + k * 2, 22 + b + k, 1.0), RAMP["hypha"][3])
    # the knot between the hands: a glowing tangle that the link thread leaves from
    hx, hy = hands[0] + lean, hands[1] + b
    for sx in (-3, 3):
        mass(img, m_line(W, H, cx + 2, 19 + b, hx + sx * 0.5, hy, 2.0), "robe", "flat", INK, base=3)
    r = 2.5 * knot
    kn = m_ellipse(W, H, hx, hy - 3, r + 1, r + 1)
    col = HOT if state == "h" else RAMP["organ"]
    mass(img, kn, col, "round", INK, base=3)
    put(img, m_curve(W, H, [(hx - r, hy - 3), (hx, hy - 3 - r), (hx + r, hy - 3)], 1.0) & kn, col[4])
    for k in range(thread):
        put(img, m_rect(W, H, int(hx) + 4 + k * 3, int(hy) - 4 - (k % 2), 2, 1), col[3])
    if state == "x":
        stars(img, cx, 4 + b, ph, 5)
    return img


def binder_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = binder(b=1 if i >= 2 else 0, knot=1.0 + 0.2 * (i % 2), thread=1)
    for i in range(6):
        f[f"walk/{i}"] = binder(b=1 if i in (1, 4) else 0, lean=1, legs=_walk(i, 6, 1), thread=i % 2)
    for i, (k, hy, th) in enumerate(((1.2, 20, 0), (1.5, 17, 0), (1.8, 16, 3), (1.3, 19, 2), (1.0, 22, 1))):
        f[f"attack/{i}"] = binder(knot=k, hands=(21, hy), thread=th, state="h" if i in (1, 2) else "n")
    f["hit/0"] = binder(lean=-2, b=1, state="c", knot=0.6)
    f["hit/1"] = binder(lean=-1, state="c", knot=0.8)
    base = binder(state="c", knot=0.5)
    for i in range(5):
        f[f"death/{i}"] = crumble(base, i / 4, 121 + i, sink=6)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


# ---------------------------------------------------------------------------------------------- e_frostshell 40x36
def frostshell(b=0, lean=0, legs=((0, 0), (0, 0)), lift=0, claw=(30, 26), state="n", ph=0, steam=0, arc=None):
    W, H = 40, 36
    img = Img(W, H)
    cx = 16 + lean
    for k in range(3):
        ox, lf = (legs[k % 2] if k < 2 else (0, 0))
        put(img, m_line(W, H, cx - 6 + k * 6, 28 + b, cx - 8 + k * 6 + ox, 34 - lf, 1.6), RAMP["gill"][1])
    body = m_ellipse(W, H, cx + 2, 27 + b, 9, 5)
    mass(img, body, SOFT, "round", INK, base=2)
    eyes(img, [(int(cx) + 7, 23 + b), (int(cx) + 10, 23 + b)], state)
    put(img, m_line(W, H, cx + 8, 24 + b, cx + 9, 19 + b, 1.0) | m_line(W, H, cx + 11, 24 + b, cx + 12, 19 + b, 1.0), SOFT[1])   # eye stalks
    # the ice shell: a spiral cone on the back; it lifts when the hermit is exposed
    sx, sy = cx - 3, 20 + b - lift
    shell = m_ellipse(W, H, sx, sy, 11, 9) & m_rect(W, H, 0, 0, W, int(sy) + 7)
    lv = mass(img, shell, "ice", "round", INK, base=2)
    for r in (7, 4):
        put(img, m_ellipse(W, H, sx + 1, sy, r, r * 0.8) & ~m_ellipse(W, H, sx + 1, sy, r - 1, r * 0.8 - 1) & shell, RAMP["ice"][4 if r == 7 else 1])
    for k, dx in enumerate((-8, -3, 3)):
        sp = m_poly(W, H, [(sx + dx - 2, sy - 6), (sx + dx, sy - 11 - k % 2 * 2), (sx + dx + 2, sy - 6)])
        mass(img, sp, "ice", "flat", INK, base=3)
    if state == "h":
        put(img, m_line(W, H, sx - 4, sy - 2, sx + 2, sy + 4, 1.0) & shell, HOT[2])            # cracks glow before the vent
    for k in range(steam):
        put(img, m_ellipse(W, H, sx - 2 + k * 2, sy - 12 - k * 4, 2.5 + k, 2 + k * 0.5) & (img.a[..., 3] == 0), RAMP["white"][4 - min(2, k)])
    if arc:
        put(img, m_curve(W, H, arc, 2.6, 1.0), ARC_FOE)
    # pincer
    gx, gy = claw[0] + lean, claw[1] + b
    mass(img, m_line(W, H, cx + 9, 27 + b, gx, gy, 2.4), SOFT, "flat", INK, base=2)
    pc = m_ellipse(W, H, gx + 2, gy, 3.5, 2.5) & ~m_poly(W, H, [(gx + 2, gy), (gx + 7, gy - 1), (gx + 7, gy + 1)])
    mass(img, pc, "ice", "round", INK, base=3)
    if state == "x":
        stars(img, cx + 9, 15 + b, ph, 5)
    return img


def frostshell_frames():
    atk = [dict(claw=(28, 22)), dict(claw=(26, 18), lean=-2, b=1), dict(claw=(27, 19), lean=-1),
           dict(claw=(34, 26), lean=3, arc=[(30, 14), (37, 20), (38, 28)]), dict(claw=(33, 27), lean=2), dict(claw=(30, 26))]
    heavy = {"attack": atk,
             "heavy_prepare": [dict(state="h", steam=k % 2, b=k % 2) for k in range(4)],
             "heavy_release": [dict(steam=3, lift=2)],
             "heavy_exposed": [dict(lift=5, state="x", ph=i * 0.6, steam=1 if i == 0 else 0) for i in range(4)]}
    return standard(frostshell, (16, 35), seed=131, heavy=heavy)


# ---------------------------------------------------------------------------------------------- e_icerunner 50x28
def icerunner(b=0, lean=0, legs=((0, 0), (0, 0)), crouch=0, stretch=0, state="n", ph=0, streak=0, arc=None, flip=False):
    W, H = 50, 28
    img = Img(W, H)
    cx = 20 + lean
    for k in range(streak):                                    # frost streak behind the dash
        put(img, m_rect(W, H, 2 + k * 3, 14 + k * 2, 10 - k * 2, 1), RAMP["ice"][4 - k])
    y = 18 + b + crouch
    tail = m_curve(W, H, [(cx - 8, y), (cx - 15, y + 2 - stretch), (cx - 19, y - 1)], 3.0, 1.0)
    mass(img, tail, "ice", "flat", INK, base=2)
    for i, (lx, s) in enumerate(((cx - 5, 1), (cx - 1, -1), (cx + 6, -1), (cx + 10, 1))):
        o = legs[i % 2][0] * s
        put(img, m_line(W, H, lx, y + 2, lx + o + stretch * (1 if i >= 2 else -1), 26 - legs[i % 2][1], 2.0), RAMP["ice"][1 + (i in (1, 2))])
    body = m_ellipse(W, H, cx + 2 + stretch * 0.5, y, 10 + stretch, 4.5 - crouch * 0.3)
    lv = mass(img, body, "ice", "round", INK, base=2)
    for k in range(3):                                         # back ridge spikes
        put(img, m_poly(W, H, [(cx - 4 + k * 5, y - 4), (cx - 3 + k * 5, y - 7), (cx - 1 + k * 5, y - 4)]), RAMP["ice"][4])
    hx = cx + 12 + stretch * 1.5
    head = m_ellipse(W, H, hx, y - 2, 5, 3.5) | m_poly(W, H, [(hx + 2, y - 3), (hx + 9, y - 1), (hx + 2, y + 1)])
    mass(img, head, "ice", "round", INK, base=3)
    eyes(img, [(int(hx), y - 4)], state)
    put(img, m_rect(W, H, int(hx) + 3, y, 5, 1), RAMP["mould"][1])
    put(img, m_ellipse(W, H, cx - 2, y + 1, 3, 1.5) & body, RAMP["mould"][2])                # the mould inside the ice
    if arc:
        put(img, m_curve(W, H, arc, 2.4, 1.0), ARC_FOE)
    if state == "x":
        stars(img, hx, y - 9, ph, 5)
    return img


def icerunner_frames():
    atk = [dict(crouch=1), dict(crouch=2, lean=-2), dict(stretch=3, lean=3, arc=[(40, 8), (47, 13), (49, 19)]), dict(stretch=2, lean=2), dict(lean=0)]
    heavy = {"attack": atk,
             "heavy_prepare": [dict(crouch=2 + k % 2, lean=-2, state="h") for k in range(4)],
             "heavy_release": [dict(stretch=4, lean=4, streak=3)],
             "heavy_exposed": [dict(crouch=1, state="x", ph=i * 0.6, lean=-1) for i in range(4)]}
    return standard(icerunner, (20, 27), seed=141, heavy=heavy)


# ---------------------------------------------------------------------------------------------- e_sporesac 34x44
def sporesac(b=0, lean=0, legs=((0, 0), (0, 0)), swell=0.0, state="n", ph=0, ball=None, slack=False):
    W, H = 34, 44
    img = Img(W, H)
    cx = 15 + lean
    for i, (off, lift) in enumerate(legs):
        lx = int(cx - 4 + i * 6 + off)
        mass(img, m_line(W, H, lx + 1, 34 + b, lx, 42 - lift, 1.8) | m_rect(W, H, lx - 1, 41 - lift, 4, 2), "hypha", "flat", INK, base=1 + i)
    r = 9.0 + swell
    sy = 24 + b - swell * 0.6 + (3 if slack else 0)
    sac = m_ellipse(W, H, cx, sy, r * (0.85 if not slack else 1.05), r * (1.0 if not slack else 0.7))
    lv = mass(img, sac, "yeast", "round", INK, base=2)
    for (dx, dy, rr) in ((-4, -4, 2), (3, -6, 1.5), (4, 3, 2.5), (-3, 5, 1.5)):
        put(img, m_ellipse(W, H, cx + dx, sy + dy, rr, rr) & sac, HOT[3] if state == "h" else RAMP["organ"][3])
    put(img, m_ellipse(W, H, cx - 3, sy - r * 0.6, 2, 1) & sac, RAMP["yeast"][4])
    # a cork-like spout on top that the ball leaves from
    sp = m_rect(W, H, int(cx) - 2, int(sy - r) - 3, 5, 4)
    mass(img, sp, "wood", "flat", INK, base=3)
    eyes(img, [(int(cx) + 2, int(sy) - 1), (int(cx) + 5, int(sy) - 1)], state)
    if ball is not None:
        bx, by = ball
        bm = m_ellipse(W, H, bx, by, 3, 3)
        mass(img, bm, "organ", "round", INK, base=3)
    if state == "x":
        stars(img, cx, sy - r - 5, ph, 5)
    return img


def sporesac_frames():
    atk = [dict(swell=1), dict(swell=2, b=1), dict(swell=0, ball=(20, 8)), dict(swell=-0.5), dict(swell=0)]
    heavy = {"attack": atk,
             "heavy_prepare": [dict(swell=1.5 + k * 0.6, state="h", b=k % 2) for k in range(4)],
             "heavy_release": [dict(swell=-1, ball=(24, 4))],
             "heavy_exposed": [dict(slack=True, state="x", ph=i * 0.6) for i in range(4)]}
    return standard(sporesac, (15, 43), seed=151, heavy=heavy)


# ---------------------------------------------------------------------------------------------- e_burrower 42x36
def burrower(b=0, lean=0, legs=((0, 0), (0, 0)), sink=0, drill=0, state="n", ph=0, dirt=0, arc=None, claw=0):
    W, H = 42, 36
    img = Img(W, H)
    cx = 16 + lean
    y = 24 + b + sink
    for i, (off, lift) in enumerate(legs):
        lx = int(cx - 5 + i * 8 + off)
        mass(img, m_rect(W, H, lx, y + 5, 4, max(1, 33 - y - 5 - lift)) | m_rect(W, H, lx - 1, 33 - lift, 6, 2), "boar", "flat", INK, base=1 + i)
    body = m_ellipse(W, H, cx, y, 11, 8)
    lv = mass(img, body, "boar", "round", INK, base=3)
    for k in range(4):                                          # mould fur tufts on the back
        put(img, m_poly(W, H, [(cx - 9 + k * 4, y - 6), (cx - 8 + k * 4, y - 10 + (k % 2)), (cx - 6 + k * 4, y - 6)]) , RAMP["mould"][3])
    put(img, m_ellipse(W, H, cx + 2, y + 3, 6, 3) & body, RAMP["boar"][4])
    eyes(img, [(int(cx) + 6, y - 4)], state)
    # spiral drill snout of hyphae
    nx = cx + 10
    sn = m_poly(W, H, [(nx, y - 4), (nx + 12, y - 1), (nx, y + 3)])
    lvs = mass(img, sn, "hypha", "flat", INK, base=3)
    for k in range(3):
        xx = nx + 2 + k * 3 + (drill % 3)
        put(img, m_line(W, H, xx, y - 3, xx + 1, y + 2, 1.0) & sn, RAMP["hypha"][1])
    # digging claw
    cl = m_ellipse(W, H, cx + 7 + claw, y + 6, 3, 2)
    mass(img, cl, "white", "round", INK, base=2)
    if arc:
        put(img, m_curve(W, H, arc, 2.4, 1.0), ARC_FOE)
    if sink:                                                    # half in the ground: a dirt mound over its lower body
        mound = m_ellipse(W, H, cx + 2, 35, 15, 4 + sink * 0.4) & m_rect(W, H, 0, 0, W, 36)
        mass(img, mound, "earth", "round", INK, base=2)
    for k in range(dirt):
        put(img, m_rect(W, H, int(cx) - 10 - k * 4, 28 - k * 3, 3, 2) & (img.a[..., 3] == 0), RAMP["earth"][2 + (k % 2)])
    if state == "x":
        stars(img, cx + 6, y - 13, ph, 5)
    return img


def burrower_frames():
    atk = [dict(claw=-2), dict(claw=-3, lean=-2, drill=1), dict(claw=4, lean=3, drill=2, arc=[(34, 14), (40, 20), (41, 28)]), dict(claw=3, lean=2), dict(claw=0)]
    heavy = {"attack": atk,
             "heavy_prepare": [dict(sink=3 + k * 2, drill=k, dirt=2, state="h") for k in range(4)],
             "heavy_release": [dict(sink=0, b=-3, dirt=4, drill=1)],
             "heavy_exposed": [dict(state="x", ph=i * 0.6, lean=-1) for i in range(4)]}
    return standard(burrower, (16, 35), seed=161, heavy=heavy)


# ---------------------------------------------------------------------------------------------- boss_nestcore 76x68
def nestcore(b=0, lean=0, legs=0, open_=0.0, pulse=1.0, state="n", ph=0, arc=None, slam=0, spores_=0, raise_=0):
    W, H = 76, 68
    img = Img(W, H)
    cx = 35 + lean
    cy = 37 + b - raise_
    # root legs, six, crawling
    for k in range(6):
        side = -1 if k < 3 else 1
        j = k % 3
        sx = cx + side * (6 + j * 4)
        swing = math.sin(legs * math.pi / 3 + k) * 3
        knee = (cx + side * (19 + j * 5), cy + 2 - j * 2)
        foot = (cx + side * (17 + j * 7) + swing, 66)
        rt = m_curve(W, H, [(sx, cy + 8), knee, foot], 5.0, 2.6)
        mass(img, rt, "bark", "flat", INK, base=1 + (j % 2))
    r = 16 + pulse
    hotcol = HOT if state == "h" else RAMP["organ"]
    # rib cage of roots behind the core; the ribs swing wide when it is exposed
    for k in range(5):
        a0 = -150 + k * 30
        spread = open_ * 30
        a = a0 - spread if a0 < -90 else (a0 + spread if a0 > -90 else a0)
        tip = _ang(cx, cy, a, r + 8)
        midp = _ang(cx, cy, a + (8 if a < -90 else -8), r + 5 + open_ * 3)
        rib = m_curve(W, H, [(cx, cy + 4), midp, tip], 4.2, 2.0)
        mass(img, rib, "bark", "flat", INK, base=2 + (k == 2))
    core = m_ellipse(W, H, cx, cy, r, r * 0.95)
    lvc = mass(img, core, hotcol, "round", INK, base=3 if open_ > 0.5 else 2)
    put(img, m_ellipse(W, H, cx - 4, cy - 5, 3.5, 2.5) & core, hotcol[4])
    for (dx, dy) in ((-6, 4), (5, -1), (1, 7)):
        put(img, m_curve(W, H, [(cx + dx, cy + dy), (cx + dx + 2, cy + dy - 2), (cx + dx + 4, cy + dy)], 1.0) & core, hotcol[1])
    if open_ < 0.5:                                  # two thin bars across the core while it is linked / shut
        for dx in (-5, 5):
            bar = m_curve(W, H, [(cx + dx - 2, cy - r + 1), (cx + dx + 1, cy), (cx + dx - 1, cy + r - 1)], 1.6) & grow(core, 1)
            mass(img, bar, "bark", "flat", None, base=1)
    eyes(img, [(int(cx) - 1, int(cy) - 3), (int(cx) + 3, int(cy) - 3)], state if state != "n" else "n")
    if spores_:
        bosses.spores(img, cx, cy - 18, 8 + spores_ * 6, 10 + spores_ * 4, 5 + spores_)
    if arc:
        put(img, m_curve(W, H, arc, 3.6, 1.2), ARC_FOE)
    for k in range(slam):
        put(img, m_rect(W, H, 50 + k * 6, 64 - k * 2, 4, 2) & (img.a[..., 3] == 0), RAMP["earth"][3])
    if state == "x":
        stars(img, cx, cy - r - 10, ph, 8)
    return img


def nestcore_frames():
    f = {}
    for i in range(4):
        f[f"idle/{i}"] = nestcore(b=1 if i >= 2 else 0, pulse=(0.0, 1.0, 1.5, 0.5)[i])
    for i in range(6):
        f[f"walk/{i}"] = nestcore(b=1 if i in (1, 4) else 0, legs=i, lean=1, pulse=(i % 2) * 0.8)
    for i, kw in enumerate((dict(raise_=2), dict(raise_=4, lean=-2), dict(raise_=5, lean=-3), dict(lean=4, b=2, slam=3, arc=[(50, 10), (66, 22), (72, 40)]),
                            dict(lean=3, b=1, slam=1), dict(lean=1))):
        f[f"attack/{i}"] = nestcore(**kw)
    for i in range(4):
        f[f"heavy_prepare/{i}"] = nestcore(state="h", raise_=4 + (i % 2), pulse=1.5 + (i % 2), lean=-2)
    f["heavy_release/0"] = nestcore(lean=4, b=2, slam=4, pulse=2.5, arc=[(48, 6), (66, 20), (74, 42)])
    for i in range(4):
        f[f"heavy_exposed/{i}"] = nestcore(open_=1.0, state="x", ph=i * 0.6, pulse=2.0 + (i % 2))
    for i, (s, p) in enumerate(((1, 1.5), (2, 2.0), (3, 2.5), (2, 2.0), (1, 1.0))):
        f[f"summon/{i}"] = nestcore(spores_=s, pulse=p, raise_=2, open_=0.3)
    f["hit/0"] = nestcore(lean=-2, b=1, state="c", pulse=0.0)
    f["hit/1"] = nestcore(lean=-1, state="c", pulse=0.5)
    base = nestcore(state="c", pulse=0.0)
    for i in range(5):
        f[f"death/{i}"] = crumble(base, i / 4, 171 + i, sink=10)
        f[f"die/{i}"] = f[f"death/{i}"]
    return f


SETS = {"e_thrall": thrall_frames, "e_binder": binder_frames, "e_frostshell": frostshell_frames, "e_icerunner": icerunner_frames,
        "e_sporesac": sporesac_frames, "e_burrower": burrower_frames, "boss_nestcore": nestcore_frames}
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "release_slice")
PAGE_W, PAD = 1024, 2


def main():
    contract = json.load(open(os.path.join(ROOT, "assets", "atlases", "char_challenge.json"), encoding="utf-8"))
    page = Image.new("RGBA", (PAGE_W, 2048), (0, 0, 0, 0))
    frames, anims, rendered = {}, {}, {}
    x = y = PAD
    shelf = 0
    for sid, fn in SETS.items():
        fr = fn()
        rendered[sid] = fr
        anims[sid] = {}
        for an, d in contract["anims"][sid].items():
            names = []
            for nm in d["frames"]:
                key = nm.split("/", 1)[1]
                assert key in fr, f"{sid}: contract frame {nm} not drawn"
                ref = contract["frames"][nm]
                im = fr[key].pil()
                assert (im.width, im.height) == (ref["w"], ref["h"]), f"{nm}: size {im.size} != {ref['w']}x{ref['h']}"
                new = f"{sid}/{key.replace('die/', 'death/')}"
                names.append(new)
                if new in frames:
                    continue
                if x + im.width + PAD > PAGE_W:
                    x = PAD
                    y += shelf + PAD * 2
                    shelf = 0
                page.paste(im, (x, y))
                frames[new] = {"x": x, "y": y, "w": im.width, "h": im.height, "pivot": list(ref["pivot"])}
                x += im.width + PAD * 2
                shelf = max(shelf, im.height)
            a = dict(d)
            a["frames"] = names
            anims[sid][an] = a
    used = y + shelf + PAD
    h = (used + 63) // 64 * 64
    page.crop((0, 0, PAGE_W, h)).save(os.path.join(OUT, "slice_challenge.png"))
    json.dump({"schema": "defence.atlas/1", "atlas": "release_slice_challenge", "image": "slice_challenge.png", "size": [PAGE_W, h],
               "padding": PAD, "extrude": 0, "group": "release_slice", "filter": "nearest", "mipmaps": False, "repeat": False,
               "gpu_format": "RGBA8", "gpu_bytes": PAGE_W * h * 4, "used_rows": used, "frames": frames, "anims": anims},
              open(os.path.join(OUT, "slice_challenge.json"), "w", encoding="utf-8"), indent=1)
    print("challenge page", PAGE_W, "x", h, "frames", len(frames))
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        keys = ["idle/0", "walk/2", "attack/3", "heavy_prepare/0", "heavy_release/0", "heavy_exposed/1", "death/2"]
        sheet = Image.new("RGBA", (len(keys) * 80 + 4, len(SETS) * 72 + 4), (147, 184, 94, 255))
        for r, sid in enumerate(SETS):
            for i, k in enumerate(keys):
                if k not in rendered[sid]:
                    continue
                im = rendered[sid][k].pil()
                sheet.paste(im, (2 + i * 80, 2 + r * 72 + (70 - im.height)), im)
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(path)
        print("sheet (generator output):", path)


if __name__ == "__main__":
    main()
