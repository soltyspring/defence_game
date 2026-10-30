"""Enemy faction (owner: 03-art). Theme-neutral default "bramble goblins":
green skin, purple/red rags, crude wood/bone gear. Drawn facing RIGHT; the
engine mirrors enemies with flip_h (INTERFACES.md §5.2).
"""
from __future__ import annotations

import math
from dataclasses import replace

import numpy as np

from pixel import Canvas, Sprite, c
from rig import Body, Pose, render, anchors, pole, _dir
from anim import walk_poses, death_frames, frames_of, ground_fit

# ---------------------------------------------------------------------------
# GRUNT (enemy_grunt) goblin with spiked club
# ---------------------------------------------------------------------------
GOB_HEAD = Sprite.parse("""
....gGGg....
...gGFFFg...
GgGGFFFFFg..
.gGGGFfKFFgF
..GGGFFKKFFg
..gGGGFFFFg.
...gGrRRrg..
....gGGGg...
""")
GOB_TORSO = Sprite.parse("""
..pPPp..
.pPVVPp.
.PPPVVPp
.pPPPPPp
.wOOOOOw
.rRrRrRr
""")


def club(cv, hand, pose, body):
    tip = pole(cv, hand, pose.weapon_ang, 1, 5, shaft="O")
    dx, dy = _dir(pose.weapon_ang)
    for i in range(3):
        cx, cy = tip[0] + dx * i, tip[1] + dy * i
        cv.ellipse(cx + 0.5, cy + 0.5, 1.6, 1.6, c("o"))
    ex, ey = tip[0] + dx * 3, tip[1] + dy * 3
    cv.put(round(ex - dy * 2), round(ey + dx * 2), c("U"))
    cv.put(round(ex + dy * 2), round(ey - dx * 2), c("U"))
    cv.put(round(ex + dx), round(ey + dy), c("U"))


GRUNT = Body(
    W=32, H=32, px=13, head=GOB_HEAD, torso=GOB_TORSO, head_anchor=(-2, 0),
    shoulder_f=(5, 1), shoulder_b=(2, 1), leg_len=4, leg_t=2, leg_col="G", leg_shade="g", boot_col="w",
    arm_t=2, arm_col="G", arm_shade="g", hand_col="F", hip_w=1, weapon=club, head_overlap=1,
    blink_px=[(7, 3, "F"), (7, 4, "F"), (8, 4, "F")],
)
GRUNT_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(2, 3), hand_b=(-1, 4), weapon_ang=-70, lean=1)


def enemy_death(body, base):
    hurt = replace(base, lean=-1, head_dx=-1, feet=((1, 0), (-3, 0)))
    kneel = replace(base, crouch=2, lean=-1, feet=((3, 0), (-3, 0)))
    return death_frames(body, hurt, kneel, dissolve=(6, 11, 14))


def grunt_anims():
    b = GRUNT
    atk = [
        replace(GRUNT_BASE, hand_f=(-1, -2), weapon_ang=-140, lean=-1),
        replace(GRUNT_BASE, hand_f=(-2, -3), weapon_ang=-165, lean=-1, bob=-0),
        replace(GRUNT_BASE, hand_f=(4, 2), weapon_ang=30, lean=2, bob=1, feet=((4, 0), (-2, 0))),
        replace(GRUNT_BASE, hand_f=(3, 3), weapon_ang=40, lean=1),
    ]
    hurt = replace(GRUNT_BASE, lean=-1, head_dx=-1, feet=((1, 0), (-3, 0)))
    idle = [GRUNT_BASE, replace(GRUNT_BASE, bob=1), replace(GRUNT_BASE, bob=1, head_dy=1),
            replace(GRUNT_BASE, blink=True)]
    walk = walk_poses(replace(GRUNT_BASE, weapon_ang=-50), 6, 3, 2, 2)
    return {
        "idle": dict(frames=frames_of(b, idle), fps=5, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=11, loop=True),
        "attack": dict(frames=frames_of(b, atk), fps=10, loop=False, events={"hit": 2}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=enemy_death(b, GRUNT_BASE), fps=8, loop=False),
    }


# ---------------------------------------------------------------------------
# SPITTER (enemy_spitter) hooded goblin with a spore gourd sling
# ---------------------------------------------------------------------------
SPIT_HEAD = Sprite.parse("""
....pPPp....
...pPVVVPp..
..pPPPVVVPp.
.pPPgFFKFFp.
GpPPgFFKKFF.
.pPPgGFFFFg.
.pPpgGGrrg..
..pp.gGGg...
""")
SPIT_TORSO = Sprite.parse("""
..pPPp..
.pPPVPp.
.pPPPVPp
.pPPPPPp
.wOOYOOw
.pPpPpPp
""")


def gourd(cv, hand, pose, body):
    hx, hy = hand
    full = pose.extra.get("loaded", True)
    cv.ellipse(hx + 1.5, hy + 1.5, 2.6, 2.6, c("o"))
    cv.put(hx + 1, hy - 1, c("T"))
    cv.put(hx, hy, c("T"))
    if full:
        cv.put(hx + 2, hy - 2, c("f"))
        cv.put(hx + 3, hy - 2, c("F"))


SPITTER = Body(
    W=32, H=32, px=13, head=SPIT_HEAD, torso=SPIT_TORSO, head_anchor=(-2, 0),
    shoulder_f=(5, 1), shoulder_b=(2, 1), leg_len=4, leg_t=2, leg_col="G", leg_shade="g", boot_col="w",
    arm_t=2, arm_col="P", arm_shade="p", hand_col="F", hip_w=1, weapon=gourd,
    blink_px=[(7, 3, "F"), (7, 4, "F"), (8, 4, "F")],
)
SPIT_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(2, 3), hand_b=(-1, 4), lean=1)


def spitter_anims():
    b = SPITTER
    atk = [
        replace(SPIT_BASE, hand_f=(-3, -2), lean=-1),
        replace(SPIT_BASE, hand_f=(-2, -5), lean=-1, head_dy=-1),
        replace(SPIT_BASE, hand_f=(5, -2), lean=2, extra={"loaded": False}),
        replace(SPIT_BASE, hand_f=(3, 2), lean=1, extra={"loaded": False}),
    ]

    def post(cv, i, p):
        if i == 2:  # spore puff leaving the gourd
            a = anchors(b, p)
            x, y = a["hf"][0] + 5, a["hf"][1] - 2
            for (dx, dy, k) in [(0, 0, "f"), (1, 0, "F"), (0, 1, "F"), (2, -1, "f"), (-1, -1, "F")]:
                cv.put(x + dx, y + dy, c(k))

    hurt = replace(SPIT_BASE, lean=-1, head_dx=-1, feet=((1, 0), (-3, 0)))
    idle = [SPIT_BASE, replace(SPIT_BASE, bob=1), replace(SPIT_BASE, bob=1), replace(SPIT_BASE, blink=True)]
    return {
        "idle": dict(frames=frames_of(b, idle), fps=5, loop=True),
        "walk": dict(frames=frames_of(b, walk_poses(SPIT_BASE, 6, 3, 2, 1)), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk, post), fps=10, loop=False, events={"hit": 2},
                       points={"projectile_spawn": [b.px + 11, b.H - 17]}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=enemy_death(b, SPIT_BASE), fps=8, loop=False),
    }


# ---------------------------------------------------------------------------
# SWARM (enemy_swarm) bramble beetle, custom quadruped (24x24)
# ---------------------------------------------------------------------------
BEETLE_SHELL = Sprite.parse("""
.....pPPPPPp......
...pPVVvvVPPPp....
..pPVvVVVPPPPPp...
.pPVVVPPPPPPPPPp..
pPPVVPPPPPPPPPPPpg
pPPPPPPPPPPPPPPpgF
pPPPPPPPPPPPPpppgF
.pppppppppppppggFF
""")
BEETLE_HEAD = Sprite.parse("""
.gGGg.
gFFFFg
GFfKfF
GFFKFF
gFFFFE
.gGGr.
""")


def beetle_frame(phase, open_jaw=False, lunge=0, squash=0):
    """e_swarm: ~16 px tall incl. outline (01 R1 guidance), 32x24 frame."""
    cv = Canvas(32, 24)
    gy = 22
    bx, by = 4 + lunge, gy - 12 + squash
    # 3 legs per visible side, alternating tripod gait
    for k, lx in enumerate((3, 8, 13)):
        up = ((k + phase) % 2) == 0
        x0, y0 = bx + lx, by + 7
        cv.line(x0, y0, x0 + (1 if up else -1), gy - (1 if up else 0), c("g"))
        cv.line(x0 + 1, y0, x0 + (2 if up else 0), gy - (1 if up else 0), c("g"))
    cv.stamp(BEETLE_SHELL, bx, by)
    cv.stamp(BEETLE_HEAD, bx + 16, by + 3 + (1 if open_jaw else 0))
    # mandibles
    hx, hy = bx + 22, by + 6 + (1 if open_jaw else 0)
    cv.put(hx, hy - (2 if open_jaw else 1), c("U"))
    cv.put(hx + 1, hy - (2 if open_jaw else 1), c("U"))
    cv.put(hx, hy + (2 if open_jaw else 1), c("U"))
    cv.put(hx + 1, hy + (2 if open_jaw else 1), c("U"))
    # antenna
    cv.line(bx + 18, by + 3, bx + 21, by - 1 - (phase % 2), c("g"))
    cv.outline(c("K"))
    return cv


def swarm_anims():
    walk = [beetle_frame(i % 2, squash=(i % 2)) for i in range(4)]
    atk = [beetle_frame(0, False, -1), beetle_frame(0, True, 2), beetle_frame(1, True, 1)]
    hit = [beetle_frame(0, False, -1, 1), beetle_frame(0, False, 0, 0)]
    flipped = beetle_frame(0)
    flipped.a = flipped.a[::-1, :].copy()      # on its back
    ground_fit(flipped, 14)
    death = [beetle_frame(1, True, -1), flipped]
    for d in (6, 11, 14):
        f = flipped.copy()
        f.dissolve(d)
        death.append(f)
    idle = [beetle_frame(0), beetle_frame(0, squash=1)]
    return {
        "idle": dict(frames=idle, fps=4, loop=True),
        "walk": dict(frames=walk, fps=14, loop=True),
        "attack": dict(frames=atk, fps=10, loop=False, events={"hit": 1}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=8, loop=False),
    }


class _B:  # minimal Body-like descriptor for non-rig sprites
    def __init__(self, W, H, px):
        self.W, self.H, self.px = W, H, px


ALL = {
    "e_grunt": (GRUNT, grunt_anims),
    "e_spitter": (SPITTER, spitter_anims),
    "e_swarm": (_B(32, 24, 14), swarm_anims),
}
