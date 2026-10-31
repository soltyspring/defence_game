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


# =============================================================================
# D1FULL (03 round 17): every regular unit at the D1 scale, plus brute / hero / siege resized for the
# size hierarchy. melee_basic and e_grunt use the hand-authored D1 bodies above; the other units are
# re-rendered by replaying their own drawing code on a ScaledCanvas: shapes (ellipses), limbs, weapons
# and lines are drawn at the new resolution, the 1 px outline is drawn at the new resolution, and ASCII
# parts (faces, torsos, small sprites) are nearest-scaled (draft quality: their pixel widths alternate).
# =============================================================================
import math as _m
from pixel import Canvas as _RealCanvas

# scale per unit (measured body heights in ART_AUDIT round 17): infantry ~1.5x (27-31 px); swarm 2x
# (04 asked >= 30 px; integer scale); pony rider 1.25x (already 27 px); brute 1.5x so it stays clearly larger
# than infantry; hero 1.2x (41 px: above infantry, below the warlord's 45); siege unchanged (40 px).
K_SCALE = {"worker": 1.5, "ranged_basic": 1.5, "tank": 1.5, "fast": 1.25,
           "e_spitter": 1.5, "e_swarm": 2.0, "e_bomber": 1.5, "e_brute": 1.5, "hero_captain": 1.2}
_K = [1.0]


class ScaledCanvas:
    """Source-space drawing API (same as pixel.Canvas) rendered into a real canvas k times larger."""

    def __init__(self, w, h, k=None, real=None):
        self.k = k if k is not None else _K[0]
        self.w, self.h = w, h                       # SOURCE size: drawing code reads cv.w / cv.h
        self.R = real if real is not None else _RealCanvas(round(w * self.k), round(h * self.k))

    a = property(lambda s: s.R.a, lambda s, v: setattr(s.R, "a", v))

    def _f(self, v):
        return int(_m.floor(v * self.k + 1e-9))

    def copy(self):
        return ScaledCanvas(self.w, self.h, self.k, self.R.copy())

    def put(self, x, y, col):
        x0, y0 = self._f(x), self._f(y)
        self.R.rect(x0, y0, max(1, self._f(x + 1) - x0), max(1, self._f(y + 1) - y0), col)

    def get(self, x, y):
        return self.R.get(self._f(x + 0.5), self._f(y + 0.5))

    def rect(self, x, y, w, h, col):
        x0, y0 = self._f(x), self._f(y)
        self.R.rect(x0, y0, self._f(x + w) - x0, self._f(y + h) - y0, col)

    def hline(self, x0, x1, y, col):
        self.rect(min(x0, x1), y, abs(x1 - x0) + 1, 1, col)

    def vline(self, x, y0, y1, col):
        self.rect(x, min(y0, y1), 1, abs(y1 - y0) + 1, col)

    def _p(self, v):
        return v * self.k + self.k / 2 - 0.5

    def line(self, x0, y0, x1, y1, col):
        self.R.thick_line(self._p(x0), self._p(y0), self._p(x1), self._p(y1), col, t=max(1, round(self.k)))

    def thick_line(self, x0, y0, x1, y1, col, t=2, shade=None):
        self.R.thick_line(self._p(x0), self._p(y0), self._p(x1), self._p(y1), col, t=max(1, round(t * self.k)), shade=shade)

    def ellipse(self, cx, cy, rx, ry, col, fill=True):
        self.R.ellipse(cx * self.k, cy * self.k, rx * self.k, ry * self.k, col, fill)

    def stamp(self, art, x, y, flip=False, only_onto=False, recolor=None):
        g = art.a[:, ::-1] if flip else art.a
        for j in range(g.shape[0]):
            for i in range(g.shape[1]):
                v = int(g[j, i])
                if v == 0:
                    continue
                if recolor:
                    v = recolor.get(v, v)
                if only_onto:
                    x0, y0 = self._f(x + i), self._f(y + j)
                    blk = self.R.a[y0:self._f(y + j + 1), x0:self._f(x + i + 1)]
                    blk[blk != 0] = v
                else:
                    self.put(x + i, y + j, v)

    def blit(self, other, x, y):
        from pixel import Sprite
        self.stamp(Sprite(other.a), x, y)

    def outline(self, col=None, diagonal=False, skip=(None,)):
        if col is None:
            self.R.outline(diagonal=diagonal)
        else:
            self.R.outline(col, diagonal=diagonal)
        return self

    def flip_h(self):
        self.R.flip_h()
        return self

    def shift(self, dx, dy):
        self.R.shift(round(dx * self.k), round(dy * self.k))
        return self

    def rot90_about(self, px, py, k=1):
        self.R.rot90_about(self._f(px), self._f(py + 1) - 1, k)
        return self

    def dissolve(self, level):
        self.R.dissolve(level)
        return self

    def recolor(self, mapping):
        self.R.recolor(mapping)
        return self

    def to_image(self):
        return self.R.to_image()


def _ground_fit(cv, px):
    import numpy as np
    a = cv.a
    ys, xs = np.nonzero(a)
    if len(ys) == 0:
        return cv
    if isinstance(cv, ScaledCanvas):
        H, pxr = a.shape[0], cv._f(px)
        dy = (H - 1) - ys.max()
        dx = pxr - (xs.min() + xs.max()) // 2
        cv.R.shift(int(dx), int(dy))
        return cv
    return _ORIG_GF(cv, px)


import anim as _anim
_ORIG_GF = _anim.ground_fit


def _scaled_fn(fn, k):
    def run():
        import rig, anim, chars_player, chars_enemy, chars_r04, chars_retheme
        mods = (rig, anim, chars_player, chars_enemy, chars_r04, chars_retheme)
        saved = [(md, md.__dict__.get("Canvas"), md.__dict__.get("ground_fit")) for md in mods]
        _K[0] = k
        try:
            for md in mods:
                if "Canvas" in md.__dict__:
                    md.Canvas = lambda w, h: ScaledCanvas(w, h, k)
                if "ground_fit" in md.__dict__:
                    md.ground_fit = _ground_fit
            anims = fn()
        finally:
            for md, cvs, gf in saved:
                if cvs is not None:
                    md.Canvas = cvs
                if gf is not None:
                    md.ground_fit = gf
            _K[0] = 1.0
        for an in anims.values():
            if an.get("points"):
                an["points"] = {n: [int(_m.floor(v[0] * k)), int(_m.floor(v[1] * k))] for n, v in an["points"].items()}
        return anims
    return run


def apply_full():
    import chars_player as P
    import chars_enemy as E
    import chars_r04 as R4
    apply("D1")
    for reg in (P.ALL, E.ALL, R4.PLAYER, R4.ENEMY):
        for sid in list(reg):
            k = K_SCALE.get(sid)
            if not k:
                continue
            body, fn = reg[sid]
            sb = _B(round(body.W * k), round(body.H * k), int(_m.floor(body.px * k)))
            reg[sid] = (sb, _scaled_fn(fn, k))


def apply(draft):
    """Swap melee_basic and e_grunt in the registries for a draft build."""
    import chars_player as P
    import chars_enemy as E
    if draft == "D1FULL":
        return apply_full()
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
