"""32 px unit drafts for the unit-size question (04 19:25 request option A, 02 R17 pending). Owner: 03-art.

NOT shipped. Selected only by the environment variable ART_DRAFT32 (build.apply_name_redraws):
  D1  "proportional": the current toast knight / mould mite re-authored at ~1.5x detail
      (more pixels for the toast helmet, face, tabard and weapon), body ~31 px in a 48x48 frame.
  D2  "chunky": the head becomes the identity shape (a whole toast slice with a face for the
      knight, a fuzzy mould blob for the mite), short thick body and legs, body ~31 px in 48x48.
  S15 reference only: the current 32x32 frames scaled x1.5 nearest into 48x48 (04's runtime
      stand-in), to show what a non-integer nearest upscale does to the pixels.
Frame contract for drafts: frame 48x48, pivot (px, 47) at the feet, same anim names, frame counts,
fps, hit/events as the shipped sets. Drawn in pre-theme keys (theme.apply remaps like the shipped art).
"""
from __future__ import annotations

import os
from dataclasses import replace

import numpy as np

from pixel import Canvas, Sprite, c
from rig import Body, Pose, anchors, pole, spear_head, _dir
from anim import walk_poses, death_frames, frames_of

DRAFT = os.environ.get("ART_DRAFT32", "")


def sp(p: Pose, k: float) -> Pose:
    """Scale the length-like fields of a pose (rounded)."""
    r = lambda v: int(round(v * k))
    return replace(p, feet=tuple((r(dx), r(l)) for dx, l in p.feet), hand_f=(r(p.hand_f[0]), r(p.hand_f[1])),
                   hand_b=(r(p.hand_b[0]), r(p.hand_b[1])), lean=r(p.lean), crouch=r(p.crouch), bob=r(p.bob),
                   head_dx=r(p.head_dx), head_dy=r(p.head_dy))


# =============================================================================
# melee_basic 식빵 기사
# =============================================================================
D1_KNIGHT_HEAD = Sprite.parse("""
...mmmm.mmmm...
..mccccmmcccm..
.mcTccccccTccm.
.mcccTcccccTcm.
.mmmmmmmmmmmmm.
..hhLLLLLLLLL..
..hSLLLLKLLLL..
..hSSLLLKLLeL..
..hSSSLLLLLLs..
..hSSSSSSSSs...
...sSSSSSSs....
....sSSSSs.....
""")
D1_KNIGHT_TORSO = Sprite.parse("""
...oUUUUo...
..oUTUUUUo..
.oUUUUTUUUo.
.OUTUUUUUUO.
.OUUUUUTUUO.
.oUUUUUUUUo.
.wOOOYYOOOw.
.byBBBByBBb.
.bBBBBBBBBb.
""")
D2_KNIGHT_HEAD = Sprite.parse("""
..mmmmm..mmmmm..
.mTTTTTmmTTTTTm.
mTWWWWWWWWWWWWTm
mTWWTWWWWWWWTWTm
mTWWWWWWWWWWWWTm
mTWWWWWWWKWWKWTm
mTWTWWWWWKWWKWTm
mTWWWWWWWWWWWWTm
mTWWWWWWeWWWWeTm
mTWWWWWWWWKKWWTm
mTWWWTWWWWWWWWTm
mTWWWWWWWWWWTWTm
.mTWWWWWWWWWWTm.
..mTTTTTTTTTTm..
...mmmmmmmmmm...
""")
D2_KNIGHT_TORSO = Sprite.parse("""
..bBBBBb..
.bBBCCBBb.
.BBBCCBBBB
.bBBBBBBBb
.wOOYYOOw.
.bBBBBBBb.
.bBBBBBBb.
""")


def spear_d(cv, hand, pose, body):
    pole(cv, hand, pose.weapon_ang, 7, 14, shaft="o", head=lambda cv_, t, a: spear_head(cv_, t, a))


def knight_body(draft):
    if draft == "D1":
        return Body(W=48, H=48, px=21, head=D1_KNIGHT_HEAD, torso=D1_KNIGHT_TORSO, head_anchor=(-2, 0),
                    shoulder_f=(8, 2), shoulder_b=(3, 2), leg_len=9, leg_t=3, leg_col="b", leg_shade="b",
                    boot_col="w", boot_w=2, arm_t=3, arm_col="B", arm_shade="b", hand_col="S", hip_w=2,
                    weapon=spear_d, blink_px=[(8, 6, "L"), (8, 7, "S")])
    return Body(W=48, H=48, px=21, head=D2_KNIGHT_HEAD, torso=D2_KNIGHT_TORSO, head_anchor=(-3, 0),
                shoulder_f=(7, 1), shoulder_b=(2, 1), leg_len=7, leg_t=4, leg_col="b", leg_shade="b",
                boot_col="w", boot_w=2, arm_t=3, arm_col="B", arm_shade="b", hand_col="W", hip_w=2, head_overlap=2,
                weapon=spear_d, blink_px=[(9, 5, "W"), (9, 6, "W"), (12, 5, "W"), (12, 6, "W")])


def knight_anims(draft):
    import chars_player as P
    b = knight_body(draft)
    k = 1.5
    base = sp(P.SPEAR_BASE, k)
    walk = walk_poses(replace(base, weapon_ang=-55, hand_f=(3, 4)), 6, 4, 3, 2)
    atk = [sp(replace(P.SPEAR_BASE, hand_f=(0, 3), weapon_ang=-10, lean=-1, feet=((3, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(-2, 3), weapon_ang=-5, lean=-2, feet=((3, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(5, 3), weapon_ang=0, lean=2, feet=((5, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(3, 3), weapon_ang=0, lean=1, feet=((4, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(2, 4), weapon_ang=-40, feet=((3, 0), (-2, 0))), k)]

    def atk_post(cv, i, p):
        if i == 2:
            a = anchors(b, p)
            x, y = a["hf"][0] + 9, a["hf"][1]
            cv.hline(x - 9, x - 3, y - 3, c("c"))
            cv.hline(x - 8, x - 2, y + 3, c("c"))
    hurt = replace(base, lean=-2, head_dx=-1, feet=((2, 0), (-4, 0)))
    kneel = replace(base, crouch=3, lean=-1, feet=((4, 0), (-4, 0)))
    idle = [base, base, replace(base, bob=1), replace(base, bob=1, blink=True)]
    return b, {
        "idle": dict(frames=frames_of(b, idle), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk, atk_post), fps=12, loop=False, events={"hit": 2}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel, dissolve=(6, 11, 14)), fps=8, loop=False),
    }


# =============================================================================
# e_grunt 곰팡이 졸개
# =============================================================================
D1_MITE_HEAD = Sprite.parse("""
......gGGGg......
....gGGFFFGGg....
GggGGFFFFFFFGg...
.gGGGFFFFFFFFGg..
..gGGGFFFfKKFFGgF
..gGGGFFFFKKFFFg.
..gGGGGFFFFFFFFg.
...gGGGFFFFFFFg..
...gGGGrRRRRrg...
....gGGGrrrrGg...
.....gGGGGGGg....
.......ggggg.....
""")
D1_MITE_TORSO = Sprite.parse("""
...pPPPPp...
..pPPVVVPPp.
.pPPPVVVVPPp
.PPPPPVVPPPp
.pPPPPPPPPPp
.pPPPPPPPPp.
.wOOOOOOOOw.
.rRRrRRrRRr.
.rRrRRrRRrR.
""")
D2_MITE_HEAD = Sprite.parse("""
...f.g..f..g....
..gGgGGgGGgGg...
.gGGFFGGFFGGGg..
gGGFFFFFFFFFGGg.
gGFFFFFFFFFFFGg.
gGFFFFFKKFFKKFGg
gGFFFFFKfFFKfFGg
gGFFFfFFFFFFFFGg
gGFFFFFFFFFFFFGg
gGGFFFFrRRRrFFGg
.gGFFFFFrrrFFFg.
.gGGFFFFFFFFGGg.
..gGGGFFFFGGGg..
...gggGGGGggg...
.....gggggg.....
""")
D2_MITE_TORSO = Sprite.parse("""
..pPPPPp..
.pPPVVPPp.
.PPPVVPPPp
.pPPPPPPPp
.wOOOOOOw.
.rRrRRrRr.
""")


def club_d(cv, hand, pose, body):
    tip = pole(cv, hand, pose.weapon_ang, 2, 8, shaft="O")
    dx, dy = _dir(pose.weapon_ang)
    for i in range(4):
        cv.ellipse(tip[0] + dx * i + 0.5, tip[1] + dy * i + 0.5, 2.4, 2.4, c("o"))
    ex, ey = tip[0] + dx * 4, tip[1] + dy * 4
    for s in (-3, 3):
        cv.put(round(ex - dy * s), round(ey + dx * s), c("U"))
    cv.put(round(ex + dx * 2), round(ey + dy * 2), c("U"))


def mite_body(draft):
    if draft == "D1":
        return Body(W=48, H=48, px=20, head=D1_MITE_HEAD, torso=D1_MITE_TORSO, head_anchor=(-3, 0),
                    shoulder_f=(8, 2), shoulder_b=(3, 2), leg_len=6, leg_t=3, leg_col="G", leg_shade="g",
                    boot_col="w", boot_w=2, arm_t=3, arm_col="G", arm_shade="g", hand_col="F", hip_w=2,
                    weapon=club_d, head_overlap=1, blink_px=[(10, 4, "F"), (11, 4, "F"), (10, 5, "F"), (11, 5, "F")])
    return Body(W=48, H=48, px=20, head=D2_MITE_HEAD, torso=D2_MITE_TORSO, head_anchor=(-3, 0),
                shoulder_f=(7, 1), shoulder_b=(2, 1), leg_len=6, leg_t=4, leg_col="G", leg_shade="g",
                boot_col="w", boot_w=2, arm_t=3, arm_col="G", arm_shade="g", hand_col="F", hip_w=2,
                weapon=club_d, head_overlap=2, blink_px=[(7, 5, "F"), (8, 5, "F"), (11, 5, "F"), (12, 5, "F")])


def mite_anims(draft):
    import chars_enemy as E
    b = mite_body(draft)
    k = 1.5
    base = sp(E.GRUNT_BASE, k)
    atk = [sp(replace(E.GRUNT_BASE, hand_f=(-1, -2), weapon_ang=-140, lean=-1), k),
           sp(replace(E.GRUNT_BASE, hand_f=(-2, -3), weapon_ang=-165, lean=-1), k),
           sp(replace(E.GRUNT_BASE, hand_f=(4, 2), weapon_ang=30, lean=2, bob=1, feet=((4, 0), (-2, 0))), k),
           sp(replace(E.GRUNT_BASE, hand_f=(3, 3), weapon_ang=40, lean=1), k)]
    hurt = replace(base, lean=-2, head_dx=-1, feet=((2, 0), (-4, 0)))
    kneel = replace(base, crouch=3, lean=-1, feet=((4, 0), (-4, 0)))
    idle = [base, replace(base, bob=1), replace(base, bob=1, head_dy=1), replace(base, blink=True)]
    walk = walk_poses(replace(base, weapon_ang=-50), 6, 4, 3, 3)
    return b, {
        "idle": dict(frames=frames_of(b, idle), fps=5, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=11, loop=True),
        "attack": dict(frames=frames_of(b, atk), fps=10, loop=False, events={"hit": 2}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel, dissolve=(6, 11, 14)), fps=8, loop=False),
    }


# =============================================================================
# S15 reference: nearest x1.5 of the shipped 32x32 frames into 48x48 (non-integer nearest)
# =============================================================================
class _B:
    def __init__(self, W, H, px):
        self.W, self.H, self.px = W, H, px


def s15(fn, body):
    src = fn()
    out = {}
    idx = (np.arange(48) / 1.5).astype(int)
    for name, an in src.items():
        frs = []
        for f in an["frames"]:
            cv = Canvas(48, 48)
            cv.a = f.a[np.ix_(idx, idx)].copy()
            frs.append(cv)
        out[name] = dict(an, frames=frs)
    return _B(48, 48, int(body.px * 1.5)), out


def apply(draft):
    """Swap melee_basic and e_grunt in the registries for a draft build."""
    import chars_player as P
    import chars_enemy as E
    if draft in ("D1", "D2"):
        kb, ka = knight_anims(draft)
        mb, ma = mite_anims(draft)
        P.ALL["melee_basic"] = (kb, lambda ka=ka: ka)
        E.ALL["e_grunt"] = (mb, lambda ma=ma: ma)
    elif draft == "S15":
        kb, ka = s15(P.spearman_anims, P.ALL["melee_basic"][0])
        mb, ma = s15(E.grunt_anims, E.GRUNT)
        P.ALL["melee_basic"] = (kb, lambda ka=ka: ka)
        E.ALL["e_grunt"] = (mb, lambda ma=ma: ma)
