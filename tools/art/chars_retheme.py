"""Name-matching redraws for theme A (owner: 03-art, art 0.9.0).

01 fixed the names (14b01e2). Units whose silhouette contradicted the name at 1x are
redrawn here with the SAME frame contract (frame size, pivot, anim names, frame counts,
fps, hit_frame, points) as the art they replace:
  e_swarm   초파리 떼 Fruit Flies   (was a ground beetle)      32x24 pivot (14,23)
  e_bomber  부푼 효모 Yeast Puff    (was a goblin with a keg)  32x32 pivot (13,31)
  e_brute   썩은 멧돼지 Rot Boar     (was a club troll)        48x48 pivot (21,47)
  siege     화덕포 Oven             (was a catapult)           48x40 pivot (22,39), spawn (37,1)
  ranged    롤빵병 Roll thrower     (was a bow archer)         rig-based; spawn (24,17)
Sprites in NATIVE are drawn directly in the final theme palette (theme.apply skips them).
"""
from __future__ import annotations

import math
from dataclasses import replace

import numpy as np

from pixel import Canvas, Sprite, c
from rig import Body, Pose, anchors, _dir
from anim import walk_poses, death_frames, frames_of, ground_fit

NATIVE = {"e_swarm", "e_bomber", "e_brute", "siege"}


class _B:
    def __init__(self, W, H, px):
        self.W, self.H, self.px = W, H, px


def _tail(last: Canvas, levels):
    out = []
    for d in levels:
        f = last.copy()
        f.dissolve(d)
        out.append(f)
    return out


# =============================================================================
# e_swarm — 초파리 떼: three hovering fruit flies (red eyes, spore-white wings),
# tiny ground shadows anchor them to the lane.
# =============================================================================
FLY_BODY = Sprite.parse("""
...ltEE
ltDtlEE
lDlDl..
""")
WING_UP = Sprite.parse("""
.zz.
zxxz
.zx.
""")
WING_DN = Sprite.parse("""
.zx.
zxxz
.zz.
""")


def fly(cv: Canvas, x, y, flap, tilt=0):
    w = WING_UP if flap else WING_DN
    cv.stamp(w, x + 1, y - (3 if flap else 2) + tilt)   # wing behind, over the thorax
    cv.stamp(FLY_BODY, x, y)
    cv.put(x + 2, y + 3, c("D"))           # legs
    cv.put(x + 4, y + 3, c("D"))


# heights put the swarm above infantry shoulders (grunt ~19 px) so it is not buried in melee (A27)
FLY_POS = [(4, 11), (13, 14), (20, 9)]      # (x, height above ground)


def flies_frame(phase, lunge=0, dive=0, scatter=0, fallen=0, n_alive=3):
    cv = Canvas(32, 24)
    g = 23
    for i, (fx, h) in enumerate(FLY_POS[:n_alive]):
        bob = round(1.5 * math.sin((phase + i * 1.3) * math.pi / 2))
        hh = max(0, h - dive - fallen * (h // 2 + 2)) + bob
        x = fx + lunge + (i - 1) * scatter
        y = g - 4 - hh
        fly(cv, x, y, flap=(phase + i) % 2 == 0)
    cv.outline(c("K"))
    # no baked ground dots: they fail the dark-background silhouette test (A27); the engine
    # shadow_s / faction marker under the unit anchors the swarm to the lane instead.
    return cv


def swarm_anims():
    idle = [flies_frame(0), flies_frame(1)]
    walk = [flies_frame(i) for i in range(4)]
    atk = [flies_frame(0, lunge=-1), flies_frame(1, lunge=3, dive=5), flies_frame(2, lunge=2, dive=2)]
    hit = [flies_frame(0, lunge=-2, scatter=2), flies_frame(1, lunge=-1, scatter=1)]
    death = [flies_frame(0, scatter=2), flies_frame(1, fallen=1, scatter=2)]
    last = flies_frame(0, fallen=3, scatter=2)
    death += [last] + _tail(last, (7, 13))
    return {
        "idle": dict(frames=idle, fps=4, loop=True),
        "walk": dict(frames=walk, fps=14, loop=True),
        "attack": dict(frames=atk, fps=10, loop=False, events={"hit": 1}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=8, loop=False),
    }


# =============================================================================
# e_bomber — 부푼 효모: swollen sage puffball with glowing orange pores (the one
# hazard accent), stubby feet; swells and bursts on attack.
# =============================================================================
def puff_frame(phase=0, sx=0.0, sy=0.0, glow=0, burst=False, eye=True):
    cv = Canvas(32, 32)
    g = 31
    rx, ry = 7.5 + sx, 7.0 + sy
    cx, cy = 13.0, g - 2 - ry
    if burst:
        # fragments + spore cloud ring
        for k in range(10):
            a = math.radians(k * 36 + 10)
            r = 9 + (k % 3)
            x, y = round(cx + math.cos(a) * r), round(cy + math.sin(a) * r * 0.8)
            cv.put(x, y, c("t")); cv.put(x + 1, y, c("l"))
        for k in range(16):
            a = math.radians(k * 22.5)
            cv.put(round(cx + math.cos(a) * 13), round(cy + math.sin(a) * 10), c("z"))
        cv.ellipse(cx, cy, 3, 2.5, c("e"))
        cv.ellipse(cx, cy, 1.5, 1.2, c("Z"))
        cv.outline(c("K"))
        return cv
    # feet
    for fx in (-3, 3):
        x = round(cx + fx + (1 if (phase % 2 == 0) == (fx > 0) else 0))
        cv.rect(x - 1, g - 2, 3, 2, c("D"))
    # body + lumps (dough-like bulges)
    # darker body than the first draft (A25 protan luminance step fell to 9.9 L*)
    cv.ellipse(cx, cy, rx, ry, c("l"))              # rim pixels l -> rim light t keeps the dark-bg silhouette
    for (dx, dy, r) in [(-5, -4, 2.5), (4, -5, 2.2), (6, 1, 2.0), (-6, 2, 1.8)]:
        cv.ellipse(cx + dx * (rx / 7.5), cy + dy * (ry / 7.0), r, r * 0.9, c("l"))
    cv.ellipse(cx - 2.5, cy - 3.5, 2.4, 1.8, c("t"))          # highlight (upper-left light)
    cv.put(round(cx - 3), round(cy - 4), c("z"))
    cv.ellipse(cx + 1, cy + ry - 1.5, rx - 2, 1.4, c("D"))      # under-shade
    # glowing pores
    pores = [(-3, 1), (3, -2), (1, 4), (5, 3), (-1, -5)]
    for i, (dx, dy) in enumerate(pores):
        x, y = round(cx + dx * (rx / 7.5)), round(cy + dy * (ry / 7.0))
        k = "e" if (i + phase) % 2 else "E"
        if glow >= 1:
            k = "Z" if i % 2 else "e"
        cv.put(x, y, c(k))
        if glow >= 2:
            cv.put(x + 1, y, c("Z"))
    if eye:
        cv.put(round(cx + rx * 0.45), round(cy - 1), c("K"))
        cv.put(round(cx + rx * 0.45) + 2, round(cy - 1), c("K"))
        cv.hline(round(cx + rx * 0.45), round(cx + rx * 0.45) + 2, round(cy + 2), c("D"))
    cv.outline(c("K"))
    return cv


def yeast_anims():
    idle = [puff_frame(0), puff_frame(1, sx=0.4, sy=-0.4)]
    squash = [(0, 0), (0.8, -0.8), (0.2, 0.3), (-0.4, 0.8), (0.3, 0.2), (0.8, -0.8)]
    walk = [puff_frame(i, sx=s[0], sy=s[1]) for i, s in enumerate(squash)]
    atk = [puff_frame(0, sx=1.5, sy=1.5, glow=1), puff_frame(1, sx=3.0, sy=3.0, glow=2), puff_frame(0, burst=True)]
    hit = [puff_frame(0, sx=1.2, sy=-1.4), puff_frame(1)]
    defl = puff_frame(0, sx=1.5, sy=-3.0, eye=False)
    ground_fit(defl, 13)
    death = [puff_frame(0, sx=1.0, sy=-1.0), puff_frame(1, sx=1.5, sy=-2.0, eye=False), defl] + _tail(defl, (5, 10, 14))
    return {
        "idle": dict(frames=idle, fps=6, loop=True),
        "walk": dict(frames=walk, fps=14, loop=True),
        "attack": dict(frames=atk, fps=10, loop=False, events={"hit": 1}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=8, loop=False),
    }


# =============================================================================
# e_brute — 썩은 멧돼지: hunched mouldy boar, spore-white tusks, bristle ridge,
# teal mould patches; trots, lowers head and gores on attack.
# =============================================================================
import os as _bob_os
BOAR_TROT_BOB = tuple(int(v) for v in _bob_os.environ.get("ART_BOAR_BOB", "1,2,0,1,2,0").split(","))   # px down, walk frames 0-5


def boar_frame(phase=0, head_dy=0, lunge=0, gore=0, gait=True, lie=False, trot=False, slump=0):
    """trot (walk only, QA-B024): heavy trot with 2 px body bob, head nod and a wider leg swing.
    slump (death only, QA-B024 A5): 1 = knees buckle, 2 = belly on the ground, legs folded, eye shut."""
    cv = Canvas(48, 48)
    g = 47
    bob = BOAR_TROT_BOB[phase % 6] if trot else 0
    bx, by = 18 + lunge, g - 11 + bob + (2, 7)[slump - 1] * (slump > 0)
    head_dy += (1 if trot and phase % 3 == 0 else 0) + (0, 1, 5)[slump]
    amp, lamp = 2, 1.5            # leg swing as before: wider swings put more dark leg edge on dark ground (readability)
    # compact boar (A27): 32 px long instead of 38, so it covers fewer neighbours in melee
    # legs (back pair darker), trot gait
    legs = [(-7, 0.0, "D"), (-3, 0.5, "l"), (5, 0.5, "D"), (9, 0.0, "l")]
    for (lx, ph, col) in legs:
        if slump >= 2:
            cv.hline(bx + lx - 1, bx + lx + 2, g, c("a"))         # folded legs: only the hooves show
            continue
        t = 2 * math.pi * (phase / 6.0 + ph)
        sw = round(amp * math.sin(t)) if gait else 0
        lift = max(0, round(lamp * math.cos(t))) if gait else 0
        x0, y0 = bx + lx, by + 4
        if slump == 1:                                           # knees buckle: shorter, splayed legs
            x1, y1 = x0 + (2 if lx > 0 else -2), g
        else:
            x1, y1 = x0 + sw, g - lift
        cv.thick_line(x0, y0, x1, y1 - 1, c(col), t=3)
        cv.hline(x1 - 1, x1 + 1, y1, c("a"))                   # hoof
    # body: big hunched barrel, higher at the shoulders
    cv.ellipse(bx, by, 11, 8.5, c("l"))
    cv.ellipse(bx + 4, by - 3, 7.5, 7, c("l"))                  # shoulder hump
    cv.ellipse(bx - 2, by - 2, 8.5, 5.5, c("t"))
    cv.ellipse(bx - 2, by + 4, 8, 2.5, c("D"))                  # belly shade
    # bristle ridge along the back
    for i in range(10):
        x = bx - 8 + i * 2
        top = by - 8 - (3 if 3 <= i <= 7 else 1)
        cv.vline(x, top, top + 2, c("D"))
        cv.put(x, top, c("a"))
    # mould patches (teal) + spore dots
    for (dx, dy, r) in [(-6, -1, 2.2), (2, 2, 1.8), (5, -5, 1.6)]:
        cv.ellipse(bx + dx, by + dy, r, r * 0.8, c("q"))
    for (dx, dy) in [(-8, -3), (-4, 1), (1, -4), (4, 4)]:
        cv.put(bx + dx, by + dy, c("z"))
    # head: wedge with snout, lowered by head_dy
    hx, hy = bx + 12, by - 1 + head_dy
    cv.ellipse(hx, hy, 7.5, 6, c("l"))
    cv.ellipse(hx - 1, hy - 2, 5, 3.5, c("t"))
    cv.rect(hx + 5, hy - 1, 5, 5, c("t"))                       # big snout
    cv.rect(hx + 9, hy, 2, 3, c("x"))                           # nostril disc
    cv.put(hx + 10, hy + 1, c("D"))
    if slump >= 2:
        cv.hline(hx, hx + 2, hy - 2, c("K"))                       # eye shut
    else:
        cv.put(hx + 1, hy - 2, c("K")); cv.put(hx + 2, hy - 2, c("E"))   # angry eye glint
    cv.put(hx - 3, hy - 5, c("l")); cv.put(hx - 2, hy - 6, c("D"))   # ear
    # tusks, raised by gore
    tx, ty = hx + 7, hy + 4
    cv.line(tx, ty, tx + 2, ty - 2 - gore, c("z"))
    cv.line(tx - 2, ty, tx, ty - 2 - gore, c("z"))
    cv.outline(c("K"))
    if lie:
        cv.a = cv.a[::-1, :].copy()
        ground_fit(cv, 21)
    return cv


def boar_anims():
    idle = [boar_frame(0, gait=False), boar_frame(0, head_dy=1, gait=False),
            boar_frame(0, head_dy=1, gait=False), boar_frame(0, gait=False)]
    walk = [boar_frame(i, trot=True) for i in range(6)]          # QA-B024: was a 0 px slide
    atk = [boar_frame(0, head_dy=-1, lunge=-1, gait=False), boar_frame(0, head_dy=3, lunge=-2, gait=False),
           boar_frame(1, head_dy=4, lunge=1), boar_frame(2, head_dy=0, lunge=4, gore=3),
           boar_frame(3, head_dy=1, lunge=2, gore=1)]

    def dust(cv, x):
        for dx in (-3, -1, 2, 4):
            cv.put(x + dx, 46 - abs(dx) // 2, c("x"))
    dust(atk[3], 40)
    hit = [boar_frame(0, head_dy=-2, lunge=-2, gait=False), boar_frame(0, head_dy=-1, lunge=-1, gait=False)]
    # QA-B024 (A5): recoil -> knees buckle -> belly on the ground (the old legs-up flip kept the same outline, 21.5 %)
    down = boar_frame(0, gait=False, slump=2)
    death = [boar_frame(0, head_dy=-3, lunge=-3, gait=False), boar_frame(0, head_dy=2, gait=False, slump=1), down] \
        + _tail(down, (6, 11, 14))
    return {
        "idle": dict(frames=idle, fps=4, loop=True),
        "walk": dict(frames=walk, fps=7, loop=True),
        "attack": dict(frames=atk, fps=8, loop=False, events={"hit": 3}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=7, loop=False),
    }


# =============================================================================
# siege — 화덕포: wheeled dough-brick oven with an iron mortar barrel (chimney)
# pointing up-right; muzzle at (37,1); fire glow in the mouth.
# =============================================================================
def oven_frame(phase=0, glow=0, recoil=0, smoke=0, bounce=0, broken=False):
    cv = Canvas(48, 40)
    g = 39
    by = g - 6 + bounce
    # cart bed
    cv.rect(5, by - 2, 34, 3, c("O"))
    cv.hline(5, 38, by - 2, c("o"))
    # oven dome (dough bricks)
    cx, cy = 21 - recoil, by - 9
    if not broken:
        cv.ellipse(cx, cy, 13, 10, c("T"))
        cv.rect(cx - 13, cy, 27, 8, c("T"))
        for row in range(4):
            y = cy - 6 + row * 4
            for x in range(cx - 12, cx + 13):
                if cv.get(x, y):
                    cv.put(x, y, c("o"))
            for x in range(cx - 12 + (row % 2) * 3, cx + 13, 6):
                for yy in range(y + 1, y + 4):
                    if cv.get(x, yy):
                        cv.put(x, yy, c("o"))
        cv.ellipse(cx - 4, cy - 5, 4, 2.5, c("U"))           # flour-dusted highlight
        # fire mouth
        cv.ellipse(cx + 1, cy + 4, 5, 3.5, c("w"))
        cv.ellipse(cx + 1, cy + 4.5, 3.8, 2.4, c("E" if glow < 2 else "e"))
        cv.ellipse(cx + 1, cy + 5, 2.0, 1.2, c("Z" if glow >= 1 else "e"))
        # iron mortar barrel (chimney) up-right to the muzzle (37,1)
        x0, y0 = cx + 6, cy - 6
        x1, y1 = 37 - recoil, 1 + recoil
        cv.thick_line(x0, y0, x1, y1 + 1, c("w"), t=4)
        cv.line(x0 - 1, y0 - 1, x1 - 1, y1, c("O"))
        for k in (0.35, 0.7):                                # crust-coloured bands
            bx_, by_ = round(x0 + (x1 - x0) * k), round(y0 + (y1 - y0) * k)
            cv.line(bx_ - 2, by_ - 1, bx_ + 1, by_ + 2, c("o"))
        cv.put(x1, y1, c("K"))
    else:
        cv.ellipse(cx, cy + 3, 13, 5, c("T"))
        cv.ellipse(cx + 1, cy + 4, 3, 1.5, c("w"))
        cv.line(cx + 4, cy - 1, cx + 13, cy - 7, c("w"))
    # banner (egg-wash gold) on a short mast at the back
    cv.vline(6, by - 20, by - 3, c("w"))
    sway = [0, 1, 0, -1][phase % 4]
    for j in range(6):
        for i in range(5):
            if j == 5 and i % 2:
                continue
            cv.put(7 + i + (sway if j > 2 else 0), by - 20 + j, c("Y" if i < 4 else "y"))
    cv.put(9 + sway, by - 18, c("R")); cv.put(9 + sway, by - 17, c("R"))
    # wheels
    for wx in (12, 31):
        wy = g - 4
        cv.ellipse(wx + 0.5, wy + 0.5, 4.5, 4.5, c("w"))
        cv.ellipse(wx + 0.5, wy + 0.5, 3.3, 3.3, c("O"))
        for k in range(4):
            a = math.radians(phase * 22.5 + k * 45)
            cv.line(wx, wy, round(wx + math.cos(a) * 3.5), round(wy + math.sin(a) * 3.5), c("o"))
        cv.put(wx, wy, c("Y"))
    cv.outline(c("K"))
    if smoke:
        for (dx, dy, r) in [(0, 0, 2.5), (3, -2, 2.0), (-2, -3, 1.6)]:
            cv.ellipse(38 + dx, 3 + dy, r, r * 0.8, c("U"))
    return cv


def oven_anims():
    walk = [oven_frame(i, bounce=i % 2) for i in range(4)]
    idle = [oven_frame(0), oven_frame(1, glow=1)]
    atk = [oven_frame(0, glow=1), oven_frame(0, glow=2), oven_frame(0, glow=2),
           oven_frame(0, glow=0, recoil=2, smoke=1), oven_frame(0, recoil=1, smoke=1), oven_frame(0)]
    hit = [oven_frame(0, bounce=1), oven_frame(0)]
    br = oven_frame(0, broken=True)
    death = [oven_frame(0, bounce=1), br] + _tail(br, (6, 11, 14))
    return {
        "idle": dict(frames=idle, fps=2, loop=True),
        "walk": dict(frames=walk, fps=8, loop=True),
        "attack": dict(frames=atk, fps=10, loop=False, events={"hit": 3}, points={"projectile_spawn": [37, 1]}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=8, loop=False),
    }


# =============================================================================
# ranged_basic — 롤빵병: rig archer body, bow replaced by a held bread roll and a
# bread basket on the back. Drawn in pre-theme keys (theme remap applies).
# =============================================================================
def roll_in_hand(cv, hand, pose, body):
    if not pose.extra.get("roll", True):
        return
    hx, hy = hand
    cv.ellipse(hx + 1.5, hy - 0.5, 2.6, 2.0, c("o"))
    cv.put(hx + 1, hy - 2, c("T")); cv.put(hx + 2, hy - 2, c("T"))
    cv.put(hx + 3, hy - 1, c("O"))


def basket(cv, a, pose, body):
    x, y = a["sb"]
    cv.rect(x - 4, y + 1, 5, 5, c("O"))
    cv.hline(x - 4, x, y + 3, c("o"))
    for i, dx in enumerate((-4, -2, 0)):
        cv.ellipse(x + dx + 0.5, y + 0.5, 1.4, 1.2, c("T" if i % 2 else "o"))


def roll_anims(archer_body: Body, base: Pose):
    from chars_player import std_idle, std_hit, std_death
    b = replace(archer_body, weapon=roll_in_hand, back_item=basket)
    rest = replace(base, hand_f=(3, 4), hand_b=(-1, 4), extra={"roll": True})
    atk = [
        replace(rest, hand_f=(-3, -2), lean=-1, extra={"roll": True}),        # wind up behind the head
        replace(rest, hand_f=(-2, -5), lean=-2, extra={"roll": True}),
        replace(rest, hand_f=(6, 2), lean=2, extra={"roll": False}),           # release (hit 2)
        replace(rest, hand_f=(5, 3), lean=1, extra={"roll": False}),
    ]

    def streak(cv, i, p):
        if i == 2:
            a = anchors(b, p)
            x, y = a["hf"]
            cv.hline(x - 5, x - 2, y - 1, c("c"))
    return {
        "idle": dict(frames=std_idle(b, rest), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk_poses(rest, 6, 3, 2, 1)), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk, streak), fps=10, loop=False, events={"hit": 2},
                       points={"projectile_spawn": [b.px + 11, b.H - 15]}),
        "hit": dict(frames=std_hit(b, rest), fps=10, loop=False),
        "death": dict(frames=std_death(b, rest), fps=8, loop=False),
    }


def proj_roll():
    """'arrow' projectile id (data) drawn as a thrown bread roll with a motion streak."""
    cv = Canvas(14, 5)
    cv.ellipse(10, 2.5, 3.4, 2.3, c("T"))       # light crust so it separates from dark hills (A21)
    cv.hline(8, 11, 1, c("U"))
    cv.put(12, 2, c("o")); cv.put(9, 3, c("o"))
    cv.outline(c("K"))
    for x in range(0, 6, 2):
        cv.put(x, 2, c("W"))
    cv.put(3, 1, c("W"))
    return {"fly": dict(frames=[cv], fps=1, loop=True)}


# tank: loaf-slice shield (same 7x9 footprint as the tower shield)
LOAF_SHIELD = Sprite.parse("""
.oTTTo.
oTUUUTo
OUURUUO
OURRRUO
OUURUUO
OUUUUUO
OUUUUUO
OoUUUoO
.OOOOO.
""")


# =============================================================================
# hero_captain — 제빵 대장 Head Baker (art 0.11.0, 01 WORLD.md): tall white chef hat
# with a jam-red band, crust-brown hair and moustache, white chef jacket with an
# egg-wash apron, rolling pin instead of the sword (Slam weapon). Same rig, same
# poses, same frame contract as the knight it replaces. Pre-theme keys: theme.ALLY
# applies, and theme.OVERRIDE["hero_captain"] maps J -> pure white for the hat/jacket.
# =============================================================================
BAKER_HEAD = Sprite.parse("""
....JJ.JJJ....
...JJJJJJJJU..
..JJJJJJJJJJU.
..UJJJJJJJJJU.
...UJJJJJJJU..
....JJJJJJJ...
....RRRRRRR...
..hhHLLLLLLLL.
.hhHHSLLLKLLL.
.hhHHSSLLKLeL.
.hhHhSSShhhSs.
..hhhsSSSSSs..
...hh.sSSSs...
""")
BAKER_TORSO = Sprite.parse("""
...JJJJJJ...
..JJJJJJJJU.
.JJBooooBJU.
.JJoTUTToJJ.
.UJoTTTToJU.
.UyyyyZyyyU.
.bBBBBBBCCb.
.bBBBBBBBCb.
.bbBBBBBBbb.
""")


# A26 silhouette variants (art 0.12.3). Real-game A/B (lineup_cam.gd, ART_AUDIT round 13): A ADOPTED
# (hero silhouette in the attack pose 74.3 -> 77.3 %), B rejected (no silhouette gain, dE vs enemies -0.3..-1.7).
# ART_VARIANT env selects for re-measurement: "A" (default, shipped), "B" (rejected trial), "0" (0.12.2 art).
#   A = taller chef hat (+2 rows, wider puff) + rolling pin 2 px longer (hero)
#   B = bigger loaf-slice shield (tank, 9x12) + full-width toast-slice helmet (melee_basic)
import os as _os
VARIANT = _os.environ.get("ART_VARIANT", "A")
BAKER_HEAD_TALL = Sprite.parse("""
...JJJ.JJJ....
..JJJJJJJJJJ..
..JJJJJJJJJJU.
..UJJJJJJJJJU.
...UJJJJJJJU..
....JJJJJJJ...
....JJJJJJJ...
....UJJJJJJ...
....RRRRRRR...
..hhHLLLLLLLL.
.hhHHSLLLKLLL.
.hhHHSSLLKLeL.
.hhHhSSShhhSs.
..hhhsSSSSSs..
...hh.sSSSs...
""")
LOAF_SHIELD_BIG = Sprite.parse("""
.oTTo.oTTo.
oTUUUoUUUTo
OUUUUUUUUUO
OUUTUUUTUUO
OUUUURUUUUO
OUUURRRUUUO
OUUUURUUUUO
OUTUUUUUTUO
OUUUUUUUUUO
OUUUUUUUUUO
OoUUUUUUUoO
.OOOOOOOOO.
""")
SPEAR_HEAD_TOAST = Sprite.parse("""
.mmm..mmm.
mcTcmmcTcm
mccccTcccm
.mmmmmmmmm
..hLLLLLL.
..hSLLKLL.
..hSSLKSe.
..hSSSSSs.
...sSSSs..
""")


def rolling_pin(cv, hand, pose, body):
    """Held by one handle like a club: handle in the fist, 9 px barrel, end handle."""
    hx, hy = hand
    dx, dy = _dir(pose.weapon_ang)
    px_, py_ = -dy, dx
    if py_ > 0 or (py_ == 0 and px_ > 0):      # highlight on the upper side
        px_, py_ = -px_, -py_

    def put(t, s, k):
        cv.put(round(hx + dx * t + px_ * s), round(hy + dy * t + py_ * s), c(k))
    for t in (-1.5, -1, -0.5, 0, 0.5, 1, 1.5):
        put(t, 0, "O")
    end = 27 if VARIANT == "A" else 23                # variant A: barrel 2 px longer
    for i in range(4, end):
        t = i * 0.5
        for s in (1.5, 1.0, 0.5, 0.0, -0.5, -1.0, -1.5):
            put(t, s, "U" if s >= 1.0 else ("o" if s <= -1.0 else "T"))
    for t in ((13.5, 14, 14.5, 15) if VARIANT == "A" else (11.5, 12, 12.5, 13)):
        put(t, 0, "O")
    for t in (4, 7.5):                                # A26: flour dust on the barrel
        put(t, 0.5, "J")


def hero_baker_body():
    import chars_player
    if VARIANT == "A":
        return replace(chars_player.HERO, head=BAKER_HEAD_TALL, torso=BAKER_TORSO, weapon=rolling_pin,
                       arm_col="J", arm_shade="U", hand_col="N",
                       blink_px=[(9, 10, "L"), (9, 11, "S")])
    return replace(chars_player.HERO, head=BAKER_HEAD, torso=BAKER_TORSO, weapon=rolling_pin,
                   arm_col="J", arm_shade="U", hand_col="N",
                   blink_px=[(9, 8, "L"), (9, 9, "S")])


def build_overrides():
    import chars_player
    ar = chars_player.ARCHER
    hb = hero_baker_body()
    return {
        "hero_captain": (hb, lambda: chars_player.hero_anims(hb)),
        "e_swarm": (_B(32, 24, 14), swarm_anims),
        "e_bomber": (_B(32, 32, 13), yeast_anims),
        "e_brute": (_B(48, 48, 21), boar_anims),
        "siege": (_B(48, 40, 22), oven_anims),
        "ranged_basic": (ar, lambda: roll_anims(ar, chars_player.ARCHER_BASE)),
    }
