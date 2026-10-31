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
    if _HI_ON[0]:
        _wraps(cv, hand, pose.weapon_ang, -7, 12)


def _wraps(cv, hand, ang, i0, i1, col="O", step=4):
    """D1Q: leather wraps every few px along a straight shaft (a straight shaft otherwise repeats one column)."""
    dx, dy = _dir(ang)
    for i in range(i0, i1, step):
        cv.put(round(hand[0] + dx * i), round(hand[1] + dy * i), c(col))


def knight_body(draft):
    if draft in ("D1", "D1Q"):
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
    wp = _walk_q if draft == "D1Q" else walk_poses
    base = sp(P.SPEAR_BASE, k)
    walk = wp(replace(base, weapon_ang=-55, hand_f=(3, 4)), 6, 4, 3, 2)
    atk = [sp(replace(P.SPEAR_BASE, hand_f=(0, 3), weapon_ang=-10, lean=-1, feet=((3, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(-2, 3), weapon_ang=-5, lean=-2, feet=((3, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(5, 3), weapon_ang=0, lean=2, feet=((5, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(3, 3), weapon_ang=0, lean=1, feet=((4, 0), (-3, 0))), k),
           sp(replace(P.SPEAR_BASE, hand_f=(2, 4), weapon_ang=-40, feet=((3, 0), (-2, 0))), k)]

    def atk_post(cv, i, p):
        if i == 2:
            a = anchors(b, p)
            x, y = a["hf"][0] + 9, a["hf"][1]
            if draft == "D1Q":          # dashed speed lines, offset phases (solid pairs repeat columns)
                for xx in range(x - 9, x - 2, 2):
                    cv.put(xx, y - 3, c("c"))
                for xx in range(x - 7, x - 1, 2):
                    cv.put(xx, y + 3, c("c"))
                return
            cv.hline(x - 9, x - 3, y - 3, c("c"))
            cv.hline(x - 8, x - 2, y + 3, c("c"))
    hurt = replace(base, lean=-2, head_dx=-1, feet=((2, 0), (-4, 0)))
    kneel = replace(base, crouch=3, lean=-1, feet=((4, 0), (-4, 0)))
    idle = [base, base, replace(base, bob=1), replace(base, bob=1, blink=True)]
    out = {
        "idle": dict(frames=frames_of(b, idle), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk, atk_post), fps=12, loop=False, events={"hit": 2}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel, dissolve=(6, 11, 14)), fps=8, loop=False),
    }
    return b, out


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
    if draft in ("D1", "D1Q"):
        hd, ts = (D1Q_MITE_HEAD, D1Q_MITE_TORSO) if draft == "D1Q" else (D1_MITE_HEAD, D1_MITE_TORSO)
        return Body(W=48, H=48, px=20, head=hd, torso=ts, head_anchor=(-3, 0),
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
    walk = (_walk_q if draft == "D1Q" else walk_poses)(replace(base, weapon_ang=-15 if draft == "D1Q" else -50), 6, 4, 3, 3)
    out = {
        "idle": dict(frames=frames_of(b, idle), fps=5, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=11, loop=True),
        "attack": dict(frames=frames_of(b, atk), fps=10, loop=False, events={"hit": 2}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel, dissolve=(6, 11, 14)), fps=8, loop=False),
    }
    return b, out


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
_HI = {}          # D1Q: id(source sprite) -> (hand-drawn sprite at target size, dx, dy, blink [(x, y, key)])
_HI_ON = [False]


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
        tr = max(1, round(t * self.k))
        if _HI_ON[0] and tr >= 3:
            # D1Q limbs: lit left edge, shaded right edge, so a 3 px limb is light / mid / dark, not a flat band
            from pixel import lighter, darker
            R = self.R
            lo, hi = -(tr // 2), tr - tr // 2
            pix = set()
            for (x, y) in R.line_pts(self._p(x0), self._p(y0), self._p(x1), self._p(y1)):
                for oy in range(lo, hi):
                    for ox in range(lo, hi):
                        pix.add((x + ox, y + oy))
            dk = shade if shade is not None else darker(col)
            lt = lighter(col)
            for (x, y) in pix:
                cc = col
                if (x + 1, y) not in pix:
                    cc = dk
                elif (x - 1, y) not in pix:
                    cc = lt
                R.put(x, y, cc)
            return
        self.R.thick_line(self._p(x0), self._p(y0), self._p(x1), self._p(y1), col, t=tr, shade=shade)

    def ellipse(self, cx, cy, rx, ry, col, fill=True):
        self.R.ellipse(cx * self.k, cy * self.k, rx * self.k, ry * self.k, col, fill)

    def stamp(self, art, x, y, flip=False, only_onto=False, recolor=None):
        hi = _HI.get(id(art)) if _HI_ON[0] else None
        if hi is not None and not flip and not only_onto:
            # D1Q: a hand-drawn part at the target resolution replaces the nearest-scaled source sprite
            spr, dx, dy, _blink = hi
            X0, Y0 = self._f(x) + dx, self._f(y) + dy
            for j, i in zip(*np.nonzero(spr.a)):
                v = int(spr.a[j, i])
                self.R.put(X0 + int(i), Y0 + int(j), recolor.get(v, v) if recolor else v)
            return
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


def _scaled_fn(fn, k, q=False, ex_k=None):
    def run():
        import rig, anim, chars_player, chars_enemy, chars_r04, chars_retheme
        mods = (rig, anim, chars_player, chars_enemy, chars_r04, chars_retheme)
        names = ("Canvas", "ground_fit") + (("render", "walk_poses", "flies_frame", "puff_frame", "boar_frame", "pony", "lance") if q else ())
        saved = [(md, n, md.__dict__[n]) for md in mods for n in names if n in md.__dict__]
        rep = {"Canvas": lambda w, h: ScaledCanvas(w, h, k), "ground_fit": _ground_fit, "render": _render_q,
               "walk_poses": _walk_q, "flies_frame": flies_frame_q, "puff_frame": puff_frame_q, "boar_frame": boar_frame_q,
               "pony": _pony_q, "lance": _lance_q}
        _K[0] = k
        _HI_ON[0] = q
        try:
            for md, n, _ in saved:
                setattr(md, n, rep[n])
            anims = fn()
        finally:
            for md, n, v in saved:
                setattr(md, n, v)
            _K[0] = 1.0
            _HI_ON[0] = False
        if q:
            _exaggerate(anims, ex_k or k)
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
    if draft == "D1Q":
        return apply_q()
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


# =============================================================================
# D1Q (03 round 18): release-quality pass of D1FULL. Still a draft (ART_DRAFT32=D1Q only; the shipped
# default is unchanged until 02 decides R17). Same sizes, anim names, frame counts, fps and events as D1FULL.
#  * faces, torsos, the loaf shield and the pony rider are hand-drawn at the target resolution (no nearest
#    scaling): bread crust grain (dark crust dots), gloss (tan / cream streaks upper-left), crumb pores on the
#    faces; mould spore dots (spore white), slime drips (sage) on the enemies.
#  * silhouettes pulled apart: 제빵사 taller toque, 롤빵병 big round bun hood, 통식빵 wide loaf crown + wider
#    body + bigger shield, 포자 뱉개 tall pointed spore hood with a spout mouth.
#  * 초파리 떼 / 부푼 효모 / 썩은 멧돼지 are redrawn natively at 2x / 1.5x / 1.5x (they were code-drawn before
#    too) with veined wings, striped abdomens, spore speckle, pores, fur strokes, bristles and drool.
#  * motion: walk stride +1, lift +1, arm swing +1, extra body bob on contact; attack anticipation (back) and
#    lunge (forward) around the hit frame; hit and death knock-back.
# =============================================================================
import math

Q_WORKER_HEAD = Sprite.parse("""
....yYYYYy.....
..yYJYYYJYYy...
.yYYYJYYYYYJy..
.yYJYYYYJYYYy..
..yYyYyYyYyy...
..yyyYyYyYyy...
.yyyyyyyyyyyyy.
..hhLLsLLLLL...
.hhSLLLLLKLL...
.hhSsLLsLKLLe..
.hhSSsSSLLLSe..
..hSsSSsSsSs...
..hsSSsssSSs...
...ssSsSSSs....
""")
Q_WORKER_TORSO = Sprite.parse("""
....oUUUUo....
..oooUTUUooo..
.ooTUUUUTTToo.
.oTUTUUUTUUTo.
oTUUUUTUUUUTTo
oTUTUUUUTUUTTo
.wOTTTTTTTTOw.
.OOoOOoOOoOOO.
..OoOOoOOoOO..
""")
Q_ARCHER_HEAD = Sprite.parse("""
....OOOOOo.....
...OoooTToOO...
..OoOTUTooOoO..
.OoOTToOoooOoO.
.OoOooLLLLLLoO.
.OooSLLsLLKLL..
.OOoSSLLLLKLSe.
.OOoSsSsLLLLSe.
.OOOSSSSsSsSs..
..OOsSsSsSSs...
...OOssSsSs....
""")
Q_ARCHER_TORSO = Sprite.parse("""
...OOCCO....
..OBBBCCCb..
.OBBBBCCCcB.
.oBbBBCcCCb.
.oBBBBBCcCb.
.oBBbBBCCcb.
.wOOOOYOOOw.
.bBbBbBBCcb.
.bBBBbBbCCb.
""")
Q_TANK_HEAD = Sprite.parse("""
.....mmmmmmmm.....
...mmMMNNNNMMmm...
..mMMNNWWNNMMMMm..
.mMMNNWNNMMMMmMMm.
.mMMMNNMMMmMMMMMm.
mMMmMMMMMMMMMmMMMm
.mmmmmmmmmmmmmmmm.
..mMmMMMMMmMMMMm..
..mMMKKKKKKWKKMm..
..mMMMmMMMMMMmMm..
..mmMMmMMMMmMMmm..
...mmmmmmmmmmmm...
""")
Q_TANK_TORSO = Sprite.parse("""
..mMMNNNNNMMm..
.mMMBBBCCCCNMm.
mMBBBBBCCCCcNMm
mBBBbBBCCCCCcMm
mBBBBBBCCcCCCMm
mMBBBBbBCCCCMMm
.wOOOOYYYOOOOw.
.bBBBbBBBCCCCb.
.bbBBBBBbBCCbb.
""")
Q_SHIELD = Sprite.parse("""
..oTTTTTTo..
.oTUUUUUUTo.
oTUUUUUUUUTo
oTUUURRUUUTo
OTUURRRRUUTO
OTUURRRRUTTO
OTUUURRUUUTO
OTUTURRUUUTO
OTUUUUUUUTUO
OTUUTUUUUUTO
OTUUUUUTUUTO
OoTUUUUUUToO
.OoTTTTTToO.
..OOOOOOOO..
""")
Q_SPIT_HEAD = Sprite.parse("""
..ppp...............
.pPPPpp.............
..ppPPPpp...........
....pPPvPPpp........
....pPPPPPPVPpp.....
...pPPvPPPPVVPPp....
...pPPPPPPVVvVPPPp..
..pPPPPPvPPPPVVPPpp.
.pPPvPPPPPPvPPPPPPPp
...ppgggGGGGGGGgppp.
....pgGFFFFFKKFFg...
...GpgFFFFFFKKFFrr..
....pgGFFFFFFFFrRrr.
....ppgGGFFfFFFg....
......pgGGgFgg......
""")
Q_SPIT_TORSO = Sprite.parse("""
...pPPPPp...
..pPPvPVPp..
.pPPPPPVVPp.
.pPvPPPPVPp.
.pPPPPvPPPp.
.pPPPPPPPvp.
.wOOOOYOOOw.
.pPpPPpPpPp.
.pPpPpPPpPp.
""")
Q_RIDER_HEAD = Sprite.parse("""
...mMMMm..
..mMNNNWm.
.mMMMNNNNm
mmMMmMMMMm
.hSLLLKLS.
.hSSLLKLe.
.hsSSSSSs.
..ssSSSs..
""")
Q_RIDER_TORSO = Sprite.parse("""
..bBCb..
.bBBCCb.
bBBbCCCc
BBYYCCCc
bBBBCCbb
""")
Q_HERO_HEAD = Sprite.parse("""
....JJJJ..JJJJ...
...JJUJJJJJUJJJ..
..JJJJUJJJJJJUJU.
..JUJJJJJUJJUJJU.
..UJJJUJJJJJJUJU.
...UJJJJJUJJJJU..
....UJJUJJJUJU...
.....JUJUJUJUJ...
.....UJUJUJUJU...
.....JUJUJUJUJ...
.....RRERRRERR...
...hhHLLLLsLLLL..
..hhHHSLLLLKLLLL.
..hhHHSSLLLKLLeL.
..hhHhSSSLLLLLSe.
..hhHhSSShhhhhSs.
...hhhsSSShhhSs..
....hh..sSSSSs...
""")
Q_HERO_TORSO = Sprite.parse("""
....JJJJJJJ...
...JJUJJUJJJU.
..JJJBoooooBJU
..JUJoTUTTToJU
.JJUJoTTUTToUJ
.UJJJoTsTTToJU
.UJUJoTUTsToJU
.UyyyyyZyyyyyU
.bBBBBbBBBCCCb
.bBBbBBBBBBCCb
.bbBBBBBbBBBbb
""")
D1Q_MITE_HEAD = Sprite.parse("""
......gGfGg......
....gGfFFFGGg....
GggGGFFFfFFFGg...
.gGfGFFFFFFFFGg..
..gGGGFfFfKKFFGgF
..gfGGFFFFKKFfFg.
..gGGfGFFFFFFFFg.
...gGGGFfFFFFFg..
...gGfGrRRRRrg...
....gGGGrFrrGg...
.....gGfGGFGg....
.......gggFg.....
""")
D1Q_MITE_TORSO = Sprite.parse("""
...pPPvPp...
..pPvPVVPPp.
.pPPPVVvVPPp
.PPvPPVVPPvp
.pPPPPPPvPPp
.pPvPPPPPPp.
.wOOOOYOOOw.
.rRRrRRrRRr.
.rRrRRrRRrR.
""")
Q_FLY_BODY = Sprite.parse("""
.......ltEEEe.
..ttDtDtlEEEEe
ltDtDtDtlEEEE.
ltDtDtDtl.EE..
.lDlDlDl......
..lllll.......
""")
Q_WING_UP = Sprite.parse("""
..zzzz..
.zxxxxz.
zxxzxxxz
zxzxxxzz
.zxxzxz.
..zxxz..
""")
Q_WING_DN = Sprite.parse("""
..zxxz..
.zxxzxz.
zxzxxxzz
zxxzxxxz
.zxxxxz.
..zzzz..
""")

_ORIG_WALK = _anim.walk_poses


def _walk_q(base, n=6, stride=3, lift=2, arm_swing=2, bob=True):
    """Bigger stride / lift / arm swing and one more px of body bob on the contact frames."""
    out = _ORIG_WALK(base, n, stride + 1, lift + 1, arm_swing + 1, bob)
    if bob:
        out = [replace(p, bob=p.bob + (1 if i % (n // 2) == 0 else 0)) for i, p in enumerate(out)]
    return out


def _shift_x(cv, dx):
    a = cv.a
    xs = np.nonzero(a.any(0))[0]
    if len(xs) and dx:
        dx = max(-int(xs.min()), min(int(dx), a.shape[1] - 1 - int(xs.max())))
        if dx:
            cv.a = np.roll(a, dx, axis=1)
    return cv


def _exaggerate(anims, k):
    """Key-pose push on finished frames (whole-body x offsets, content kept inside the frame):
    attack: frame before the hit event leans back (anticipation), hit frame and the next lunge forward;
    hit and death: knock-back on the first two frames. Feet stay on the ground row."""
    s1, s2 = max(1, int(k + 0.5)), max(2, int(2 * k + 0.5))

    def sh(an, i, d):
        fr = an["frames"]
        if 0 <= i < len(fr):
            fr[i] = _shift_x(fr[i].copy(), d)
    for name in ("attack", "work"):
        at = anims.get(name)
        if at and "hit" in at.get("events", {}):
            h = at["events"]["hit"]
            sh(at, h - 1, -s2)
            sh(at, h, s2)
            sh(at, h + 1, s1)
    for name in ("hit", "death"):
        an = anims.get(name)
        if an and len(an["frames"]) >= 2:
            sh(an, 0, -s2 - (1 if name == "death" else 0))
            sh(an, 1, -s1)


def _render_q(body, pose):
    """rig.render with the blink drawn on the hand-drawn head (D1Q)."""
    import rig
    cv = rig.Canvas(body.W, body.H)
    a = rig.anchors(body, pose)
    hip_x, hip_y = a["hip"]
    fy = a["fy"]
    if body.back_item:
        body.back_item(cv, a, pose, body)
    rig.draw_cape(cv, body, a, pose)
    rig.draw_arm(cv, body, a["sb"], a["hb"], back=True)
    if body.weapon and pose.weapon_on and pose.weapon_behind:
        body.weapon(cv, a["hf"], pose, body)
    (ffdx, fl), (bfdx, bl) = pose.feet
    rig.draw_leg(cv, body, (hip_x - body.hip_w, hip_y), (body.px + bfdx, fy - bl), back=True)
    rig.draw_leg(cv, body, (hip_x + body.hip_w, hip_y), (body.px + ffdx, fy - fl), back=False)
    if isinstance(cv, ScaledCanvas):
        # trouser cuff: one darker row just above each boot (breaks the repeated leg rows)
        from pixel import darker, lighter
        legc = {c(body.leg_col), c(body.leg_shade)}
        for fdx, lift in ((bfdx, bl), (ffdx, fl)):
            fx, fyy = body.px + fdx, fy - lift
            row = cv._f(fyy - 1) - 1
            cx = int(round(cv._p(fx)))
            for x in range(cx - 3, cx + 4):
                v = cv.R.get(x, row)
                if v in legc:
                    dv = darker(v)
                    cv.R.put(x, row, dv if dv != v else lighter(v))
            # knee crease half way up the leg: the mid pixel of the limb goes one step darker (or lighter)
            krow = (row + cv._f(hip_y)) // 2
            for rr, first in ((krow, darker), ((krow + row) // 2, lighter)):
                kx = int(round((cx * (rr - cv._f(hip_y)) + cv._p(hip_x) * (row - rr)) / max(1, row - cv._f(hip_y))))
                for x in range(kx - 1, kx + 2):
                    v = cv.R.get(x, rr)
                    if v == c(body.leg_col):
                        dv = first(v)
                        cv.R.put(x, rr, dv if dv != v else (lighter(v) if first is darker else darker(v)))
                        break
    cv.stamp(body.torso, *a["torso"])
    cv.stamp(body.head, *a["head"])
    if pose.blink:
        hi = _HI.get(id(body.head)) if isinstance(cv, ScaledCanvas) else None
        if hi is not None:
            X0, Y0 = cv._f(a["head"][0]) + hi[1], cv._f(a["head"][1]) + hi[2]
            for (x, y, kk) in hi[3]:
                cv.R.put(X0 + x, Y0 + y, c(kk))
        else:
            for (x, y, kk) in body.blink_px:
                cv.put(a["head"][0] + x, a["head"][1] + y, c(kk))
    if body.weapon and pose.weapon_on and not pose.weapon_behind:
        body.weapon(cv, a["hf"], pose, body)
    rig.draw_arm(cv, body, a["sf"], a["hf"], back=False)
    if body.offhand:
        body.offhand(cv, a, pose, body)
    cv.outline(c(body.outline))
    return cv


def _speckle(cv, on_key, cols, ox, oy, density, seed):
    """Spore / grain speckle on pixels of one colour, anchored to the body (ox, oy) so it moves with it;
    dots never touch each other (they stay 1 px details)."""
    a = cv.a
    on = c(on_key)
    taken = set()
    put = []
    H, W = a.shape
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if a[y, x] != on:
                continue
            hsh = ((x - ox) * 73856093 ^ (y - oy) * 19349663 ^ seed) & 1023
            if hsh < density * 1024 and not any((x + i, y + j) in taken for i in (-1, 0, 1) for j in (-1, 0, 1)):
                taken.add((x, y))
                put.append((x, y, cols[hsh % len(cols)]))
    for x, y, col in put:
        a[y, x] = c(col)


def flies_frame_q(phase, lunge=0, dive=0, scatter=0, fallen=0, n_alive=3):
    import chars_retheme as RT
    k = 2
    sc = ScaledCanvas(32, 24, k)
    cv = sc.R
    g = 23
    for i, (fx, h) in enumerate(RT.FLY_POS[:n_alive]):
        bob = round(1.5 * math.sin((phase + i * 1.3) * math.pi / 2))
        hh = max(0, h - dive - fallen * (h // 2 + 2)) + bob
        x, y = (fx + lunge + (i - 1) * scatter) * k, (g - 4 - hh) * k
        flap = (phase + i) % 2 == 0
        cv.stamp(Q_WING_UP if flap else Q_WING_DN, x + 2, y - (6 if flap else 4))
        cv.stamp(Q_FLY_BODY, x, y)
        for lx in (3, 6, 9):                       # three thin legs
            cv.put(x + lx, y + 6, c("D"))
            cv.put(x + lx - 1, y + 7, c("D"))
    cv.outline(c("K"))
    return sc


def puff_frame_q(phase=0, sx=0.0, sy=0.0, glow=0, burst=False, eye=True):
    k = 1.5
    sx, sy = sx * 1.4, sy * 1.4                       # D1Q: squash / stretch pushed 40 % further
    sc = ScaledCanvas(32, 32, k)
    cv = sc.R
    g = 47
    rx, ry = (8.5 + sx) * k, (7.0 + sy) * k          # D1Q: wider, squatter puffball than the 포자 뱉개 / 졸개
    cx, cy = 19.5, g - 3 - ry
    if burst:
        for i in range(14):
            a = math.radians(i * 360 / 14 + 10)
            r = 13 + (i % 3) * 1.5
            x, y = round(cx + math.cos(a) * r), round(cy + math.sin(a) * r * 0.8)
            cv.put(x, y, c("t"))
            cv.put(x + 1, y, c("l"))
            if i % 2:
                cv.put(x, y + 1, c("l"))
        for i in range(24):
            a = math.radians(i * 15)
            cv.put(round(cx + math.cos(a) * 19), round(cy + math.sin(a) * 15), c("z"))
        cv.ellipse(cx, cy, 4.5, 3.8, c("e"))
        cv.ellipse(cx, cy, 2.2, 1.8, c("Z"))
        cv.put(round(cx) - 1, round(cy) - 1, c("U"))
        cv.outline(c("K"))
        return sc
    for fx in (-4.5, 4.5):                                       # stubby feet
        x = round(cx + fx + (2.5 if (phase % 2 == 0) == (fx > 0) else 0))
        cv.rect(x - 2, g - 3, 4, 3, c("D"))
        cv.put(x - 1, g - 3, c("l"))
    cv.ellipse(cx, cy, rx, ry, c("l"))
    for (dx, dy, r) in [(-5, -4, 2.5), (4, -5, 2.2), (6, 1, 2.0), (-6, 2, 1.8)]:   # dough lumps
        cv.ellipse(cx + dx * rx / 7.5, cy + dy * ry / 7.0, r * k, r * k * 0.9, c("l"))
    cv.ellipse(cx - 3.5, cy - 5, 3.6, 2.6, c("t"))                # upper-left light
    cv.ellipse(cx + 1.5, cy + ry - 2.2, rx - 3, 2.0, c("D"))        # under-shade
    for (dx, dy, r) in [(-5, -4, 2.5), (4, -5, 2.2), (6, 1, 2.0), (-6, 2, 1.8)]:   # dough fold under each lump
        lx, ly = cx + dx * rx / 7.5, cy + dy * ry / 7.0
        for a in range(20, 175, 12):
            cv.put(round(lx + math.cos(math.radians(a)) * r * k), round(ly + math.sin(math.radians(a)) * r * k * 0.9), c("D"))
    for f in (0.55, 0.75):                                           # two long dough folds across the belly
        for a in range(15, 165, 9):
            cv.put(round(cx + math.cos(math.radians(a)) * rx * f), round(cy + math.sin(math.radians(a)) * ry * f * 0.8), c("D"))
    _speckle(cv, "l", ("t", "D", "t", "D", "z"), round(cx), round(cy), 0.26, 11)
    _speckle(cv, "D", ("l",), round(cx), round(cy), 0.20, 13)
    cv.put(round(cx - 4.5), round(cy - 6), c("z"))                  # wet gloss
    cv.put(round(cx - 2.5), round(cy - 6.5), c("z"))
    for i, (dx, dy) in enumerate([(-3, 1), (3, -2), (1, 4), (5, 3), (-1, -5)]):      # glowing pores
        x, y = round(cx + dx * rx / 7.5), round(cy + dy * ry / 7.0)
        kk = ("Z" if i % 2 else "e") if glow >= 1 else ("e" if (i + phase) % 2 else "E")
        cv.put(x, y, c(kk))
        cv.put(x, y + 1, c("D"))
        if glow >= 2:
            cv.put(x - 1, y, c("Z"))
            cv.put(x + 1, y, c("Z"))
    if eye:
        ex, ey = round(cx + rx * 0.5), round(cy - 2)
        for x in (ex, ex + 4):                                        # 2x2 eyes with a spore-white glint
            cv.rect(x, ey, 2, 2, c("K"))
            cv.put(x + 1, ey, c("z"))
        for (x, y) in ((ex - 1, ey - 2), (ex, ey - 2), (ex + 1, ey - 1), (ex + 4, ey - 1), (ex + 5, ey - 2), (ex + 6, ey - 2)):
            cv.put(x, y, c("K"))                                       # angry brows
        for i, x in enumerate(range(ex, ex + 6)):                      # wavy mouth + one tooth
            cv.put(x, ey + 4 + (i % 2), c("K"))
        cv.put(ex + 2, ey + 5, c("z"))
    ybot = int(round(cy + ry))
    for (dx, ln) in ((-5, 2), (2, 3), (7, 1)):                        # slime drips
        for j in range(ln):
            cv.put(round(cx + dx), ybot - 1 + j, c("t"))
    ytop = int(round(cy - ry))
    for (dx, h) in ((-4, 2), (0, 3), (4, 2)):                         # spore stalks on top
        x = round(cx + dx)
        cv.vline(x, ytop - h, ytop, c("l"))
        cv.put(x, ytop - h - 1, c("z"))
    cv.outline(c("K"))
    return sc


def boar_frame_q(phase=0, head_dy=0, lunge=0, gore=0, gait=True, lie=False, trot=False, slump=0):
    k = 1.5
    sc = ScaledCanvas(48, 48, k)
    cv = sc.R
    g = 71
    bob = (3, 2, 0, 3, 2, 0)[phase % 6] if trot else 0
    bx, by = (18 + lunge) * k, 54 + bob + (0, 3, 10)[slump]
    head_dy += (1 if trot and phase % 3 == 0 else 0) + (0, 1, 4)[slump]
    for (lx, ph, col) in [(-7, 0.0, "D"), (-3, 0.5, "l"), (5, 0.5, "D"), (9, 0.0, "l")]:
        if slump >= 2:                                           # folded legs: only the hooves show
            x = round(bx + lx * k)
            cv.hline(x - 2, x + 2, g, c("a"))
            continue
        t = 2 * math.pi * (phase / 6.0 + ph)
        sw = round(5 * math.sin(t)) if gait else 0
        lift = max(0, round(3.5 * math.cos(t))) if gait else 0
        x0, y0 = round(bx + lx * k), round(by + 6)
        x1, y1 = (x0 + (3 if lx > 0 else -3), g) if slump == 1 else (x0 + sw, g - lift)
        cv.thick_line(x0, y0, x1, y1 - 1, c(col), t=4, shade=c("D") if col == "l" else None)
        cv.hline(x1 - 2, x1 + 2, y1, c("a"))
        cv.put(x1 + 1, y1 - 1, c("a"))
    cv.ellipse(bx, by, 16.5, 12.75, c("l"))
    cv.ellipse(bx + 6, by - 4.5, 11.25, 10.5, c("l"))
    cv.ellipse(bx - 3, by - 3, 12.75, 8.25, c("t"))
    cv.ellipse(bx - 3, by + 6, 12, 3.75, c("D"))
    _speckle(cv, "l", ("D", "t", "D"), round(bx), round(by), 0.14, 5)
    _speckle(cv, "t", ("l", "l", "z"), round(bx), round(by), 0.10, 9)
    for (dx, dy) in [(-12, -1), (-9, 3), (-5, -6), (-2, 1), (3, -8), (6, -2), (9, 2), (-7, 6), (1, 6), (12, -5), (-14, 3), (4, 4)]:
        x, y = round(bx + dx), round(by + dy)                    # fur strokes
        col = "D" if cv.get(x, y) == c("l") else "l"
        cv.put(x, y, c(col))
        cv.put(x + 1, y + 1, c(col))
    for i in range(15):                                          # bristle ridge
        x = round(bx - 12 + i * 2)
        top = round(by - 12 - (5 if 4 <= i <= 11 else 2) + (i % 2))
        cv.vline(x, top, top + 3, c("D"))
        cv.put(x, top, c("a"))
    for (dx, dy, r) in [(-9, -1.5, 3.3), (3, 3, 2.7), (7.5, -7.5, 2.4)]:   # teal mould patches with spores
        cv.ellipse(bx + dx, by + dy, r, r * 0.8, c("q"))
        cv.put(round(bx + dx), round(by + dy), c("z"))
        cv.put(round(bx + dx + 1), round(by + dy - 1), c("t"))
    for (dx, dy) in [(-12, -4.5), (-6, 1.5), (1.5, -6), (6, 6), (-3, -9), (10, 0), (-15, 1)]:
        cv.put(round(bx + dx), round(by + dy), c("z"))
    hx, hy = round(bx + 18), round(by - 1.5 + head_dy * k + bob)      # the head dips with the trot (nod)
    cv.ellipse(hx, hy, 11.25, 9, c("l"))
    cv.ellipse(hx - 1.5, hy - 3, 7.5, 5.25, c("t"))
    cv.rect(hx + 7, hy - 1, 8, 7, c("t"))                        # snout
    cv.rect(hx + 13, hy, 3, 5, c("x"))                           # nostril disc
    cv.put(hx + 14, hy + 1, c("D"))
    cv.put(hx + 14, hy + 3, c("D"))
    for (dx, dy) in [(-6, 2), (-3, 5), (2, 4), (-8, -2)]:
        cv.put(hx + dx, hy + dy, c("D"))
    if slump >= 2:
        cv.hline(hx, hx + 3, hy - 2, c("K"))                     # eye shut
    else:
        cv.put(hx + 1, hy - 3, c("K"))                           # eye + angry glint + brow
        cv.put(hx + 1, hy - 2, c("K"))
        cv.put(hx + 2, hy - 3, c("E"))
    for i in range(4):
        cv.put(hx - 1 + i, hy - 6 + i // 2, c("D"))
    cv.put(hx - 5, hy - 8, c("l"))                               # ear
    cv.put(hx - 4, hy - 9, c("D"))
    cv.put(hx - 5, hy - 9, c("D"))
    tx, ty = hx + 10, hy + 6                                     # tusks, raised by gore
    cv.thick_line(tx, ty, tx + 3, ty - 3 - round(gore * k), c("z"), t=2)
    cv.line(tx - 3, ty, tx, ty - 3 - round(gore * k), c("z"))
    if gore or head_dy >= 3:                                     # drool
        cv.vline(hx + 12, hy + 6, hy + 8, c("t"))
        cv.put(hx + 12, hy + 9, c("z"))
    cv.outline(c("K"))
    if lie:
        cv.a = cv.a[::-1, :].copy()
        _ORIG_GF(cv, 31)
    return sc


_PONY0 = [None]
_LANCE0 = [None]


def _lance_q(cv, hx, hy, ang, flag_phase=0):
    """프레첼 lance: the shipped drawing plus shaft wraps (D1Q)."""
    _LANCE0[0](cv, hx, hy, ang, flag_phase=flag_phase)
    _wraps(cv, (hx, hy), ang, -2, 12, col="O", step=3)


def _pony_q(cv, bx, by, phase, gallop=True, rear=0):
    """프레첼 pony: the shipped drawing, then baked-dough crumb pores on the cream body (D1Q)."""
    _PONY0[0](cv, bx, by, phase, gallop=gallop, rear=rear)
    if isinstance(cv, ScaledCanvas):
        _speckle(cv.R, "U", ("T", "o", "T"), cv._f(bx), cv._f(by), 0.30, 3)
        _speckle(cv.R, "x", ("T",), cv._f(bx), cv._f(by), 0.30, 4)            # belly / legs
        _speckle(cv.R, "B", ("b", "C"), cv._f(bx), cv._f(by), 0.30, 7)        # saddle-cloth weave


def _basket_q(cv, a, pose, body):
    """롤빵병 D1Q back item: a wicker bread basket with two rolls (replaces the thin quiver lines)."""
    x, y = a["sb"]
    cv.ellipse(x - 4, y - 0.5, 1.8, 1.4, c("T"))     # rolls peeking out
    cv.ellipse(x - 1.5, y - 1, 1.8, 1.4, c("o"))
    cv.ellipse(x - 3, y + 2.5, 4.2, 3.2, c("O"))
    if isinstance(cv, ScaledCanvas):
        R = cv.R
        x0, y0, x1, y1 = cv._f(x - 7.2), cv._f(y + 0.5), cv._f(x + 1.2), cv._f(y + 5.7)
        for yy in range(y0, y1 + 1):
            for xx in range(x0, x1 + 1):
                if R.get(xx, yy) == c("O") and (xx + yy * 2) % 3 == 0:
                    R.put(xx, yy, c("o"))                 # wicker weave


def _with_attr(fn, mod, name, val):
    """Run fn with mod.name temporarily replaced (D1Q base-pose tweaks without touching the shipped modules)."""
    def run():
        old = getattr(mod, name)
        setattr(mod, name, val)
        try:
            return fn()
        finally:
            setattr(mod, name, old)
    return run


def apply_q():
    import chars_player as P
    import chars_enemy as E
    import chars_r04 as R4
    _PONY0[0] = R4.pony
    _LANCE0[0] = R4.lance
    # 식빵병 / 졸개: the hand-drawn D1 bodies, replayed at k = 1 so the D1Q limbs, cuffs and key-pose push apply
    P.ALL["melee_basic"] = (knight_body("D1Q"), _scaled_fn(lambda: knight_anims("D1Q")[1], 1.0, q=True, ex_k=1.5))
    E.ALL["e_grunt"] = (mite_body("D1Q"), _scaled_fn(lambda: mite_anims("D1Q")[1], 1.0, q=True, ex_k=1.5))
    _HI_ON[0] = False
    if not _HI:          # first build in this process only (validate --determinism builds twice; the registries keep pass 1)
        wk, tk, spb, hb = P.ALL["worker"][0], P.ALL["tank"][0], E.ALL["e_spitter"][0], P.ALL["hero_captain"][0]
        _register_hi(P, R4, wk, tk, spb, hb)
    for rg in (P.ALL, E.ALL, R4.PLAYER, R4.ENEMY):
        for sid in list(rg):
            k = K_SCALE.get(sid)
            if not k:
                continue
            body, fn = rg[sid]
            if id(fn) in _MADE:
                continue
            if sid == "worker":        # pick carried over the shoulder, head pointing back (the spear points forward)
                fn = _with_attr(fn, P, "WORKER_BASE", replace(P.WORKER_BASE, weapon_ang=-125, hand_f=(0, 2)))
            elif sid == "e_spitter":   # hunched forward under the spore hood
                fn = _with_attr(fn, E, "SPIT_BASE", replace(E.SPIT_BASE, lean=2))
            elif sid == "ranged_basic":   # bigger wicker bread basket low on the back (wider mid-back silhouette)
                import chars_retheme as RT
                fn = _with_attr(fn, RT, "basket", _basket_q)
                # walks with the roll cocked at shoulder height, ready to throw (its own outline vs 통식빵 / 제빵사)
                fn = _with_attr(fn, RT, "walk_poses",
                                lambda base, *a, **kw: _walk_q(replace(base, hand_f=RANGED_WALK_HAND, lean=base.lean + RANGED_LEAN),
                                                               *a, **kw))
            sb = _B(round(body.W * k), round(body.H * k), int(_m.floor(body.px * k)))
            rg[sid] = (sb, _scaled_fn(fn, k, q=True))
            _MADE.add(id(rg[sid][1]))


_MADE = set()
RANGED_WALK_HAND = tuple(int(v) for v in os.environ.get("ART_Q_RHAND", "2,-2").split(","))
RANGED_LEAN = int(os.environ.get("ART_Q_RLEAN", "2"))


def _register_hi(P, R4, wk, tk, spb, hb):
    def reg(src, hi, dx=0, dy=0, blink=()):
        _HI[id(src)] = (hi, dx, dy, list(blink))
    reg(wk.head, Q_WORKER_HEAD, 0, -2, [(9, 8, "L"), (9, 9, "L")])
    reg(wk.torso, Q_WORKER_TORSO, -1, 0)
    reg(P.ARCHER.head, Q_ARCHER_HEAD, 0, 0, [(10, 5, "L"), (10, 6, "L")])
    reg(P.ARCHER.torso, Q_ARCHER_TORSO)
    reg(tk.head, Q_TANK_HEAD, -1, 0)
    reg(tk.torso, Q_TANK_TORSO, -1, 0)
    reg(P.SHIELD, Q_SHIELD, -1, 0)
    reg(spb.head, Q_SPIT_HEAD, -2, -3, [(12, 10, "F"), (13, 10, "F"), (12, 11, "F"), (13, 11, "F")])
    reg(spb.torso, Q_SPIT_TORSO)
    reg(R4.RIDER_HEAD, Q_RIDER_HEAD)
    reg(R4.RIDER_TORSO, Q_RIDER_TORSO)
    reg(hb.head, Q_HERO_HEAD, 0, 0, [(11, 12, "L"), (11, 13, "L")])
    reg(hb.torso, Q_HERO_TORSO)
