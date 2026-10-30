"""r10 final boss (owner: 03-art): boss_overlord, the "Bramble Hive Overlord".
Theme = reversible default (Q1 PENDING). Same palette/outline/rig as the rest of the
enemy faction (green skin, purple, crude wood/bone), never ally blue or hero red.

Hierarchy cues vs boss_warlord (45 px, gold crown, purple cape, cleaver):
  * taller (~58 px incl. staff) and wider; violet beetle-shell crown + pauldrons;
  * glowing lilac eyes and staff orb (the only lilac glow in the game);
  * hive cocoon on the back that births e_swarm beetles -> reads as "summoner".
Frame 88x80, pivot (36, 79). hit_frame 3 (data/units/units.json). summon anim
`spawn` event = frame 3 (no data field yet; requested from 01/02).
"""
from __future__ import annotations

import math
from dataclasses import replace

import numpy as np

from pixel import Canvas, Sprite, c
from rig import Body, Pose, anchors, _dir
from anim import walk_poses, death_frames, frames_of

OVL_HEAD = Sprite.parse("""
...U...U...U...U.
...UU..UU..UU..UU
...pU..pU..pU..pU
...pVU.pVU.pVU.pV
...pPVPPPVPPPVPPp
...yYYZYYYZYYYZYy
...pPVVPVVPVVPVPp
....gGGGGGGGGg...
...gGFFFFFFFFGg..
..gGFFFFFFFFFFGg.
.gGFFvvFFFFvvFFGg
.gGFFvvFFFFvvFFFG
gGGGFFFFFFFFFFFg.
gGGGFFFrrrrFFFFg.
.gGGGrUrUUrUrFg..
..gGGGrrrrrrGg...
...gGGGGGGGGg....
....gGGGGGGg.....
""")
_OVL_TORSO = Sprite.parse("""
..pPPPp....pPPPp...
.pPVVvPp..pPVVvPp..
pPVvVVPPppPPVvVVPp.
pPPVPPPgGGgPPVPPPp.
.ppPPpgGFFGgpPPpp..
...gGGFFFFFFGGg....
...gGFFfFFfFFGg....
...wOOOOYOOOOw.....
...gGGGGGGGGGGg....
..gGGPPPPPPPGGg....
..gPPPVPPPVPPPg....
..pPPVPPPVPPPPp....
..pPVPPPVPPPVPp....
.pPPPPVPPPPVPPPp...
.pPPVPPPPVPPPPPp...
pPPPPPPPPPPPPPPPp..
pppppppppppppppppp.
""")
# lengthen the robe (rows 10-14 repeated) -> 24 rows
OVL_TORSO = Sprite(np.insert(_OVL_TORSO.a, [10, 11, 12, 13, 14, 14, 14], _OVL_TORSO.a[[10, 11, 12, 13, 14, 13, 12]], axis=0))
# Colour-vision fix (ART_AUDIT A16): large purple masses fall within dE 9.7 of ally blue_dark under
# deuteranopia. Robe/pauldrons -> bark brown (dE 79 vs ally blue); purple kept for small accents.
OVL_TORSO = OVL_TORSO.recolored({"P": "O", "V": "o", "p": "w"})


def hive(cv: Canvas, a, pose: Pose, body):
    """Cocoon of woven bramble on the back; pulses + opens during `summon`."""
    x, y = a["sb"]
    pulse = pose.extra.get("pulse", 0)
    cx, cy = x - 5, y + 2
    rx, ry = 9 + pulse * 0.5, 12 + pulse * 0.5
    cv.ellipse(cx, cy, rx, ry, c("g"))                           # dark-green chitin (dE 60 vs ally blue)
    cv.ellipse(cx - 1, cy - 1, rx - 1.5, ry - 1.5, c("G"))
    cv.ellipse(cx - 3, cy - 4, rx * 0.35, ry * 0.3, c("F"))      # shell highlight (top-left light)
    # segmented chitin plates (organic, not barrel staves)
    for k in (-1, 1):
        for yy in range(round(cy - ry) + 2, round(cy + ry) - 1):
            xx = round(cx + k * 3 + math.sin(yy / 3.0))
            if cv.get(xx, yy):
                cv.put(xx, yy, c("g"))
    # thorns along the rim
    for t in range(0, 360, 40):
        tx = round(cx + math.cos(math.radians(t)) * (rx + 1))
        ty = round(cy + math.sin(math.radians(t)) * (ry + 1))
        cv.put(tx, ty, c("U"))
    # brood holes; glow brighter when summoning
    glow = pose.extra.get("glow", 0)
    for (dx, dy) in [(-3, -5), (2, -1), (-2, 4), (3, 6)]:
        cv.put(round(cx + dx), round(cy + dy), c("K"))
        cv.put(round(cx + dx) + 1, round(cy + dy), c("F" if not glow else ("f" if glow == 1 else "Z")))
    if pose.extra.get("open"):
        cv.ellipse(cx + 1, cy - ry + 3, 4, 2.5, c("K"))
        cv.ellipse(cx + 1, cy - ry + 3, 2.5, 1.2, c("f"))


def staff(cv: Canvas, hand, pose: Pose, body):
    dx, dy = _dir(pose.weapon_ang)
    hx, hy = hand
    for i in range(-8, 20):
        x, y = round(hx + dx * i), round(hy + dy * i)
        cv.put(x, y, c("O" if i % 5 else "w"))
        cv.put(x + (1 if abs(dy) > abs(dx) else 0), y + (0 if abs(dy) > abs(dx) else 1), c("w"))
    tx, ty = hx + dx * 22, hy + dy * 22
    # thorn cage around a glowing orb
    orb = pose.extra.get("orb", 0)
    cv.ellipse(tx, ty, 3.2 + orb * 0.4, 3.2 + orb * 0.4, c("V"))
    cv.ellipse(tx - 0.5, ty - 0.5, 2.0, 2.0, c("v"))
    cv.put(round(tx) - 1, round(ty) - 1, c("W"))
    for t in range(0, 360, 60):
        cv.put(round(tx + math.cos(math.radians(t)) * 4.6), round(ty + math.sin(math.radians(t)) * 4.6), c("w"))


OVERLORD = Body(
    W=88, H=80, px=36, head=OVL_HEAD, torso=OVL_TORSO, head_anchor=(0, 0),
    shoulder_f=(15, 3), shoulder_b=(3, 3), leg_len=14, leg_t=5, leg_col="w", leg_shade="w", boot_col="w",
    arm_t=4, arm_col="G", arm_shade="g", hand_col="F", hip_w=3, head_overlap=2, torso_overlap=2,
    weapon=staff, back_item=hive, boot_w=2,
    blink_px=[(5, 10, "F"), (6, 10, "F"), (11, 10, "F"), (12, 10, "F")],
)
OVL_BASE = Pose(feet=((4, 0), (-4, 0)), hand_f=(3, 6), hand_b=(-1, 8), weapon_ang=-100, lean=1)


def _rune_circle(cv: Canvas, cx, gy, r, phase, col="V", hi="v"):
    for t in range(0, 360, 10):
        x = round(cx + math.cos(math.radians(t + phase * 15)) * r)
        y = round(gy + math.sin(math.radians(t + phase * 15)) * r * 0.25)
        if 0 <= y < cv.h and (t // 10 + phase) % 3:
            cv.put(x, y, c(col if t % 30 else hi))


def _beetle_silhouette(cv: Canvas, x, y, k="P"):
    """small swarm beetle (same shape family as e_swarm) bursting out during summon."""
    shell = Sprite.parse("""
..KKKK...
.KPVVPKK.
KPVPPPPFK
KPPPPPFFK
.KKKKKKK.
.K.K.K...
""")
    cv.stamp(shell, x - 1, y - 2)


def overlord_anims():
    b = OVERLORD
    idle = [replace(OVL_BASE, extra={"orb": 0}), replace(OVL_BASE, bob=1, extra={"orb": 1}),
            replace(OVL_BASE, bob=1, extra={"orb": 1, "pulse": 1}), replace(OVL_BASE, blink=True, extra={"orb": 0})]
    walk = walk_poses(replace(OVL_BASE, weapon_ang=-95), 6, stride=3, lift=1, arm_swing=1)
    walk = [replace(p, extra={"pulse": i % 2}) for i, p in enumerate(walk)]
    # attack: raise staff, slam forward-down (hit 3), shock, recover
    atk = [
        replace(OVL_BASE, hand_f=(1, 0), weapon_ang=-110, lean=-1, extra={"orb": 1}),
        replace(OVL_BASE, hand_f=(-1, -5), weapon_ang=-125, lean=-2, head_dy=-1, extra={"orb": 2}),
        replace(OVL_BASE, hand_f=(5, -3), weapon_ang=-55, lean=1, extra={"orb": 2}),
        replace(OVL_BASE, hand_f=(9, 5), weapon_ang=20, lean=3, bob=2, feet=((6, 0), (-4, 0)), extra={"orb": 2}),
        replace(OVL_BASE, hand_f=(8, 7), weapon_ang=35, lean=2, bob=1, extra={"orb": 1}),
        replace(OVL_BASE, hand_f=(4, 6), weapon_ang=-60, lean=1, extra={"orb": 0}),
    ]

    def atk_post(cv, i, p):
        if i in (3, 4):
            a = anchors(b, p)
            dx, dy = _dir(p.weapon_ang)
            ox = round(a["hf"][0] + dx * 22)
            gy = b.H - 2
            _rune_circle(cv, ox, gy, 10 + (i - 3) * 5, i, "V", "v")
            if i == 3:
                for k in (-6, -3, 3, 6):
                    cv.put(ox + k, gy - 2 - abs(k) // 3, c("v"))

    # summon: staff up, hive pulses, opens, beetles emerge (spawn 3), circle fades
    summ = [
        replace(OVL_BASE, hand_f=(1, -2), weapon_ang=-95, extra={"orb": 1, "pulse": 1, "glow": 1}),
        replace(OVL_BASE, hand_f=(1, -6), weapon_ang=-92, head_dy=-1, extra={"orb": 2, "pulse": 2, "glow": 1}),
        replace(OVL_BASE, hand_f=(1, -7), weapon_ang=-90, head_dy=-1, extra={"orb": 2, "pulse": 2, "glow": 2}),
        replace(OVL_BASE, hand_f=(2, -7), weapon_ang=-90, extra={"orb": 2, "pulse": 1, "glow": 2, "open": True}),
        replace(OVL_BASE, hand_f=(2, -4), weapon_ang=-95, extra={"orb": 1, "pulse": 0, "glow": 1, "open": True}),
        replace(OVL_BASE, hand_f=(3, 4), weapon_ang=-100, extra={"orb": 0}),
    ]

    def summ_post(cv, i, p):
        gy = b.H - 2
        if 1 <= i <= 4:
            _rune_circle(cv, b.px, gy, 14 + i * 2, i)
        a = anchors(b, p)
        hx, hy = a["sb"][0] - 4, a["sb"][1] - 11
        if i == 3:      # spawn: three beetles burst from the hive
            for (dx, dy) in [(-10, -2), (-4, -6), (2, -3)]:
                _beetle_silhouette(cv, hx + dx, hy + dy)
        if i == 4:
            for (dx, dy) in [(-14, 4), (-6, 1), (4, 3)]:
                _beetle_silhouette(cv, hx + dx, hy + dy)
        if i in (1, 2, 3):   # orb sparks
            dx, dy = _dir(p.weapon_ang)
            tx, ty = round(a["hf"][0] + dx * 22), round(a["hf"][1] + dy * 22)
            for (sx, sy) in [(0, -6), (-5, -2), (5, -2), (-3, 4), (3, 4)][: 2 + i]:
                cv.put(tx + sx, ty + sy, c("v"))

    hurt = replace(OVL_BASE, lean=-2, head_dx=-1, feet=((3, 0), (-5, 0)), extra={"orb": 0})
    kneel = replace(OVL_BASE, crouch=4, lean=-1, feet=((5, 0), (-5, 0)), weapon_ang=70, hand_f=(5, 9))
    return {
        "idle": dict(frames=frames_of(b, idle), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=6, loop=True),
        "attack": dict(frames=frames_of(b, atk, atk_post), fps=8, loop=False, events={"hit": 3}),
        "summon": dict(frames=frames_of(b, summ, summ_post), fps=8, loop=False, events={"spawn": 3},
                       points={"spawn_origin": [b.px - 12, b.H - 1]}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel, dissolve=(4, 8, 11, 13, 15)), fps=7, loop=False),
    }


BOSS = {"boss_overlord": (OVERLORD, overlord_anims)}
ALL = dict(BOSS)
