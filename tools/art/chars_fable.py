"""Release-style redraws of the four representative characters (2026-11-10, Fable 5.2 pass).

Same frame contract as the art they replace (frame size, pivot, anim names, frame counts, fps, hit events):
    hero_captain  48x48 pivot (22,47)   제빵 대장: tall chef hat, moustache, jam-red cape, baguette greatsword
    melee_basic   32x32 pivot (13,31)   식빵병: the square toast slice IS the body; bread knife
    e_grunt       32x32 pivot (13,31)   곰팡이 졸개: drooping lopsided mould cap, hyphae claw arm
    boss_warlord  64x64 pivot (28,63)   곰팡이 장군: nest-stalk crown, cap pauldrons, spore mace
All four are drawn directly in the final palette (chars_retheme.NATIVE), no theme remap.
Style rules for the rest of the roster: docs/art/fable52/STYLE_RULES.md.
"""
from __future__ import annotations

import math

import numpy as np

from pixel import Canvas, Sprite, c
from anim import arc_swoosh

SIDS = ("hero_captain", "melee_basic", "e_grunt", "boss_warlord")


class _B:
    def __init__(self, W, H, px):
        self.W, self.H, self.px = W, H, px


def _ang(x, y, deg, ln):
    """Point ln px from (x, y); screen angles: 0 = right (forward), -90 = up, 90 = down."""
    r = math.radians(deg)
    return x + math.cos(r) * ln, y + math.sin(r) * ln


def _blob(cv, cx, cy, rx, ry, base, shade=None, hi=None, rim=False):
    """Filled ellipse, light from the upper left: shade on the lower right, highlight on the upper left."""
    if rim:                                                  # inner contour: keeps overlapping masses separate
        _blob(cv, cx, cy, rx + 1, ry + 1, "K")
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx = (x + 0.5 - cx) / max(rx, 0.01)
            dy = (y + 0.5 - cy) / max(ry, 0.01)
            if dx * dx + dy * dy > 1.0:
                continue
            col = base
            if shade and dx * 0.3 + dy > 0.55:
                col = shade
            elif hi and -dx * 0.6 - dy > 0.62:
                col = hi
            cv.put(x, y, c(col))


def _collapse(cv, k):
    """Squash the frame towards the ground row (death)."""
    h, w = cv.a.shape
    nh = max(3, int(round(h * k)))
    rows = np.minimum(h - 1, (np.arange(nh) * (h / nh)).astype(int))
    out = Canvas(w, h)
    out.a[h - nh:, :] = cv.a[rows, :]
    return out


def _death(hurt, n):
    ks = [0.82, 0.6, 0.42]
    frames = [hurt] + [_collapse(hurt, k) for k in ks]
    low = frames[-1]
    for d in (5, 10, 14)[: max(0, n - len(frames))]:
        f = low.copy()
        f.dissolve(d)
        frames.append(f)
    return frames[:n]


def _legs(cv, px, gy, hip_y, phase, half, col, boot, t=2, stride=3):
    """Two legs; phase None = standing. The front foot leads on phases 0-2, the back foot on 3-5."""
    for k, hx in enumerate((px - half, px + half - t + 1)):
        off, lift = 0, 0
        if phase is not None:
            a = 2 * math.pi * (phase / 6.0) + (math.pi if k else 0)
            off = int(round(stride * math.sin(a)))
            lift = 1 if math.cos(a) > 0.35 else 0
        for y in range(hip_y, gy - lift):
            f = (y - hip_y) / max(1, gy - lift - 1 - hip_y)
            cv.rect(hx + int(round(off * f)), y, t, 1, c(col))
        cv.rect(hx + off, gy - lift, t + 1, 1, c(boot))


# ---------------------------------------------------------------------------------------------
# melee_basic 식빵병
# ---------------------------------------------------------------------------------------------
TOAST = Sprite.parse("""
..ooooooooo..
.oTUUUUUUUTo.
oTUUUUUUUUUTO
oUUUUUUUUUUUO
oUUUUUUUUUUUO
.oUUUUUUUUUO.
.oUUUUUUKUKO.
.oUUUUUUKUKO.
.oUUUUUeUUeO.
.oUUUUUUUUUO.
.EEEEEEEEEER.
.oTUUUUUUUTO.
.oTTTTTTTTTO.
..OOOOOOOOO..
""")


def _knife(cv, hx, hy, deg, ln=9):
    x1, y1 = _ang(hx, hy, deg, 2)
    cv.thick_line(hx, hy, x1, y1, c("O"), 2)
    x2, y2 = _ang(hx, hy, deg, ln)
    cv.thick_line(x1, y1, x2, y2, c("N"), 2, c("M"))
    cv.put(int(round(x2)), int(round(y2)), c("W"))


def toast_frame(bob=0, lean=0, phase=None, arm=35, knife=-78, blink=False, tail=0, swoosh=None, dx=0, glint=False):
    cv = Canvas(32, 32)
    px, gy = 13 + dx, 31
    top = gy - 4 - 14 + 1 - bob
    bx = px - 6 + lean
    _legs(cv, px, gy, top + 13, phase, 3, "O", "w")
    # scarf tail trails behind (left): shows the facing even in a crowd
    cv.put(bx - 1, top + 10 + tail, c("E"))
    cv.put(bx - 2, top + 11 + tail, c("E"))
    cv.put(bx - 3, top + 11 + tail * 2, c("R"))
    cv.stamp(TOAST, bx, top)
    if blink:
        for ex in (8, 10):
            cv.put(bx + ex, top + 6, c("U"))
    sx, sy = bx + 10, top + 10
    hx, hy = _ang(sx, sy, arm, 3)
    cv.thick_line(sx, sy, hx, hy, c("T"), 2, c("o"))
    _knife(cv, int(round(hx)), int(round(hy)), knife)
    cv.outline(c("K"))
    if glint:
        gx, gy2 = _ang(hx, hy, knife, 10)
        cv.put(int(round(gx)), int(round(gy2)), c("W"))
        cv.put(int(round(gx)) + 1, int(round(gy2)), c("Z"))
        cv.put(int(round(gx)), int(round(gy2)) - 1, c("Z"))
    if swoosh:
        arc_swoosh(cv, sx + 1, sy, 11, swoosh[0], swoosh[1], "W", "Z", 2)
    return cv


def toast_anims():
    idle = [toast_frame(), toast_frame(tail=1), toast_frame(bob=1, tail=1), toast_frame(bob=1, blink=True)]
    walk = [toast_frame(bob=(1 if i in (1, 4) else 0), lean=1, phase=i, knife=-70 + (4 if i % 2 else 0), tail=i % 2)
            for i in range(6)]
    atk = [
        toast_frame(lean=-1, arm=-150, knife=-150, tail=1),
        toast_frame(lean=-2, bob=1, arm=-120, knife=-115, glint=True),
        toast_frame(lean=3, dx=1, arm=5, knife=22, swoosh=(-95, 30), phase=1),
        toast_frame(lean=2, dx=1, arm=30, knife=50, phase=1),
        toast_frame(lean=0, arm=30, knife=-30),
    ]
    hurt = toast_frame(lean=-2, blink=True, arm=60, knife=-20, tail=1)
    return {
        "idle": dict(frames=idle, fps=4, loop=True),
        "walk": dict(frames=walk, fps=10, loop=True),
        "attack": dict(frames=atk, fps=12, loop=False, events={"hit": 2}),
        "hit": dict(frames=[hurt, toast_frame(lean=-1)], fps=10, loop=False),
        "death": dict(frames=_death(hurt, 6), fps=12, loop=False),
    }


# ---------------------------------------------------------------------------------------------
# hero_captain 제빵 대장
# ---------------------------------------------------------------------------------------------
HERO_HEAD = Sprite.parse("""
..WWWWWWWWW..
.WWWWWWWWWWx.
WWWWWWWWWWWxx
WWWWWWWWWWWxx
WWWWWWWWWWxxx
.WWWWWWWWWxx.
..WWWWWWWxx..
..WWWWWWWxx..
..xxxxxxxxx..
..oUUUUUUUU..
..oUUUUUKUU..
..oUUUUUKUUT.
..OUUUOOOOOO.
...UUUUOOOO..
...TUUUUU....
""")
HERO_TORSO = Sprite.parse("""
.EEEEEEEEE..
WWWWEEEEWWx.
WWWWWEEWWWxx
WWWYWWWYWWxx
WWWWWWWWWWxx
WWWYWWWYWWxx
WWWWWWWWWWxx
RRRRRRRRRRRr
UUUUUUUUUUTT
UUUUUUUUUUT.
.UUUUUUUUT..
""")


def _baguette(cv, hx, hy, deg, ln=17, glow=False):
    bx, by = _ang(hx, hy, deg, -2)
    cv.thick_line(bx, by, hx, hy, c("y"), 2)                          # pommel/grip
    gx0, gy0 = _ang(hx, hy, deg - 90, 3)
    gx1, gy1 = _ang(hx, hy, deg + 90, 3)
    x1, y1 = _ang(hx, hy, deg, 2)
    x2, y2 = _ang(hx, hy, deg, ln)
    cv.thick_line(x1, y1, x2, y2, c("T"), 3, c("o"))
    for d in range(5, ln - 1, 4):                                      # score marks = it is a baguette
        mx, my = _ang(hx, hy, deg, d)
        cv.put(int(round(mx)), int(round(my)), c("O"))
    cv.thick_line(gx0, gy0, gx1, gy1, c("Y"), 2, c("y"))               # cross-guard
    if glow:
        tx, ty = int(round(x2)), int(round(y2))
        for ox, oy in ((0, -2), (2, 0), (-2, 0), (0, 2)):
            cv.put(tx + ox, ty + oy, c("Z"))
        cv.put(tx, ty, c("W"))


def hero_frame(bob=0, lean=0, phase=None, arm=40, sword=-62, cape=0, blink=False, swoosh=None, dx=0, glow=False,
               head_dx=0):
    cv = Canvas(48, 48)
    px, gy = 22 + dx, 47
    ty = gy - 6 - 11 + 1 - bob
    tx = px - 6 + lean
    # cape first (behind): jam red, the only large red mass on the ally side = "this is the leader"
    for j in range(13):
        w = 3 + j // 3
        x0 = tx - 1 - j // 3 - int(round(cape * j / 12.0))
        cv.rect(x0, ty + 1 + j, w + 1, 1, c("R"))
        cv.put(x0, ty + 1 + j, c("r"))
    _legs(cv, px, gy, ty + 10, phase, 4, "O", "w", t=3, stride=4)
    cv.stamp(HERO_TORSO, tx, ty)
    hx0 = tx + lean + head_dx
    cv.stamp(HERO_HEAD, hx0, ty - 14)
    if blink:
        cv.put(hx0 + 8, ty - 14 + 10, c("U"))
    sx, sy = tx + 9, ty + 3
    hx, hy = _ang(sx, sy, arm, 5)
    cv.thick_line(sx, sy, hx, hy, c("W"), 3, c("x"))
    cv.rect(int(round(hx)) - 1, int(round(hy)) - 1, 2, 2, c("U"))
    _baguette(cv, int(round(hx)), int(round(hy)), sword, glow=glow)
    cv.outline(c("K"))
    if swoosh:
        arc_swoosh(cv, sx + 2, sy, 19, swoosh[0], swoosh[1], "W", "Z", 3)
    return cv


def hero_anims():
    idle = [hero_frame(), hero_frame(cape=1), hero_frame(bob=1, cape=2), hero_frame(bob=1, cape=1, blink=True)]
    walk = [hero_frame(bob=(1 if i in (1, 4) else 0), lean=1, phase=i, sword=-55 + (4 if i % 2 else 0),
                       cape=2 + i % 2) for i in range(6)]
    atk = [
        hero_frame(lean=-1, arm=-20, sword=-95, cape=1),
        hero_frame(lean=-2, arm=-60, sword=-110, cape=0),
        hero_frame(lean=-2, bob=1, arm=-70, sword=-100, cape=0, glow=True),          # held high = telegraph
        hero_frame(lean=3, dx=2, arm=10, sword=28, cape=3, swoosh=(-100, 35), phase=1),
        hero_frame(lean=2, dx=2, arm=35, sword=55, cape=2, phase=1),
        hero_frame(lean=0, arm=45, sword=-20, cape=1),
    ]
    cast = [
        hero_frame(arm=-30, sword=-80),
        hero_frame(bob=1, arm=-70, sword=-90),
        hero_frame(bob=1, arm=-90, sword=-90, glow=True),
        hero_frame(bob=2, arm=-90, sword=-90, glow=True, cape=2),
        hero_frame(bob=1, arm=-90, sword=-90, glow=True, cape=3),
        hero_frame(arm=10, sword=-70, cape=1),
    ]
    hurt = hero_frame(lean=-2, head_dx=-1, blink=True, arm=70, sword=-10, cape=-1)
    return {
        "idle": dict(frames=idle, fps=5, loop=True),
        "walk": dict(frames=walk, fps=10, loop=True),
        "attack": dict(frames=atk, fps=14, loop=False, events={"hit": 3}),
        "cast": dict(frames=cast, fps=12, loop=False, events={"release": 4}),
        "hit": dict(frames=[hurt, hero_frame(lean=-1)], fps=10, loop=False),
        "death": dict(frames=_death(hurt, 6), fps=12, loop=False),
    }


# ---------------------------------------------------------------------------------------------
# e_grunt 곰팡이 졸개
# ---------------------------------------------------------------------------------------------
GRUNT_CAP = Sprite.parse("""
....lllll......
..llttttlll....
.ltztttllzlll..
lltttlllllllll.
llllllzlllllDll
DllllllllllDDDl
.DDDDDDDDDDDDDD
""")
GRUNT_STALK = Sprite.parse("""
DDDDDDDD
DllQQlQQ
tttttttt
tttKzKzK
ltttttt.
lltttt..
.llttt..
""")


def grunt_frame(bob=0, lean=0, phase=None, claw=15, reach=6, dx=0, cap_dy=0, glare=False, swoosh=None, shut=False):
    cv = Canvas(32, 32)
    px, gy = 13 + dx, 31
    top = gy - 4 - 7 - 7 + 1 - bob          # legs 4, stalk 7, cap 7 (cap overlaps the stalk's shadow row)
    bx = px - 7 + lean
    _legs(cv, px, gy, top + 13, phase, 3, "l", "D", stride=2)
    cv.stamp(GRUNT_STALK, bx + 3, top + 6)
    for ex in (3, 4, 6, 7):
        if shut:
            cv.put(bx + 3 + ex, top + 7, c("D"))
        elif glare:
            cv.put(bx + 3 + ex, top + 7, c("W"))
    sx, sy = bx + 9, top + 10
    ex_, ey_ = _ang(sx, sy, claw, reach)
    cv.thick_line(sx, sy, ex_, ey_, c("l"), 2, c("D"))
    for d in (-40, 0, 40):                                  # three hyphae claws
        cx_, cy_ = _ang(ex_, ey_, claw + d, 4)
        cv.line(ex_, ey_, cx_, cy_, c("z"))
    cv.stamp(GRUNT_CAP, bx, top + cap_dy)                   # cap last: it overhangs the face and the shoulder
    cv.outline(c("K"))
    if swoosh:
        arc_swoosh(cv, sx, sy, 10, swoosh[0], swoosh[1], "z", "t", 2)
    return cv


def grunt_anims():
    idle = [grunt_frame(), grunt_frame(cap_dy=1), grunt_frame(bob=1, cap_dy=1), grunt_frame(bob=1)]
    walk = [grunt_frame(bob=(1 if i in (1, 4) else 0), lean=1, phase=i, claw=20 - (10 if i % 2 else 0),
                        cap_dy=(1 if i in (2, 5) else 0)) for i in range(6)]
    atk = [
        grunt_frame(lean=-2, claw=-140, reach=6, cap_dy=-1),
        grunt_frame(lean=-2, bob=1, claw=-75, reach=7, cap_dy=-1, glare=True),     # eyes flare = telegraph
        grunt_frame(lean=3, dx=1, claw=25, reach=8, cap_dy=1, swoosh=(-80, 40), phase=1),
        grunt_frame(lean=1, claw=60, reach=6),
    ]
    hurt = grunt_frame(lean=-2, cap_dy=-1, claw=80, shut=True)
    return {
        "idle": dict(frames=idle, fps=5, loop=True),
        "walk": dict(frames=walk, fps=11, loop=True),
        "attack": dict(frames=atk, fps=10, loop=False, events={"hit": 2}),
        "hit": dict(frames=[hurt, grunt_frame(lean=-1)], fps=10, loop=False),
        "death": dict(frames=_death(hurt, 6), fps=12, loop=False),
    }


# ---------------------------------------------------------------------------------------------
# boss_warlord 곰팡이 장군
# ---------------------------------------------------------------------------------------------
def _mace(cv, hx, hy, deg, ln=15, glow=0):
    bx, by = _ang(hx, hy, deg, -4)
    ex, ey = _ang(hx, hy, deg, ln)
    cv.thick_line(bx, by, ex, ey, c("A"), 2, c("a"))
    _blob(cv, ex, ey, 5.2, 5.2, "D", None, "l")
    for d in range(0, 360, 45):                              # spore spikes
        sx, sy = _ang(ex, ey, d + 22, 6)
        cv.put(int(round(sx)), int(round(sy)), c("z"))
    cv.rect(int(round(ex)) - 1, int(round(ey)) - 1, 2, 2, c("Q") if glow else c("t"))
    return ex, ey


def warlord_frame(bob=0, lean=0, phase=None, arm=-30, mace=-80, glow=0, cape=0, jaw=0, dx=0, shock=False,
                  shut=False):
    cv = Canvas(64, 64)
    px, gy = 28 + dx, 63
    cx = px + lean
    by = gy - 9 - 12 - bob                                  # body centre
    # tattered teal cape behind
    for j in range(22):
        x0 = cx - 13 - j // 4 - int(round(cape * j / 21.0))
        w = 6 + j // 5
        if j > 17 and (x0 + j) % 3 == 0:
            w -= 2
        cv.rect(x0, by - 8 + j, w, 1, c("q"))
        cv.put(x0, by - 8 + j, c("D"))
    _legs(cv, px, gy, gy - 10, phase, 7, "D", "a", t=5, stride=3)
    _blob(cv, cx - 9, by - 7, 7, 5, "l", "D", "t")           # back pauldron cap
    _blob(cv, cx, by, 13, 12, "l", "D", "t")                 # hunched body
    # stale-crust breastplate (rotten grey): the only hard-edged shape on him
    for y in range(by - 5, by + 7):
        for x in range(cx - 1, cx + 11):
            if cv.get(x, y) and (x - cx) + (y - by) * 0.3 < 10:
                cv.put(x, y, c("X" if y < by - 2 else ("A" if y < by + 4 else "a")))
    cv.rect(cx - 9, by + 7, 20, 2, c("a"))                   # belt
    cv.rect(cx + 3, by + 6, 3, 4, c("z"))                    # buckle
    for (sxp, syp) in ((-7, -2), (-4, 5), (-10, 3), (6, 10)):
        cv.put(cx + sxp, by + syp, c("z"))                   # spore dots
    # head sunk between the shoulders
    hx0, hy0 = cx + 3, by - 14
    _blob(cv, hx0, hy0, 7, 6, "t", "l", "z", rim=True)
    eye = c("l") if shut else c("Q")
    cv.rect(hx0 + 1, hy0 - 1, 2, 2, eye)
    cv.rect(hx0 + 4, hy0 - 1, 2, 2, eye)
    cv.rect(hx0, hy0 + 2 + jaw, 6, 1, c("K"))
    for x in (hx0 + 1, hx0 + 3, hx0 + 5):
        cv.put(x, hy0 + 2 + jaw, c("z"))
    if jaw:
        cv.rect(hx0, hy0 + 2, 6, jaw, c("D"))
    # crown: three nest stalks with bulbs (same motif as the mould nest)
    for (ox, ln) in ((-3, 8), (1, 12), (5, 7)):
        x = hx0 + ox
        cv.rect(x, hy0 - 6 - ln, 1, ln + 1, c("D"))
        cv.rect(x - 1, hy0 - 8 - ln, 3, 3, c("t"))
        cv.put(x - 1, hy0 - 8 - ln, c("z"))
    _blob(cv, cx + 10, by - 5, 6, 5, "l", "D", "t", rim=True)  # front pauldron cap
    cv.put(cx + 8, by - 7, c("z"))
    cv.put(cx + 12, by - 4, c("z"))
    sx, sy = cx + 11, by - 2
    hx, hy = _ang(sx, sy, arm, 8)
    cv.thick_line(sx, sy, hx, hy, c("l"), 4, c("D"))
    ex, ey = _mace(cv, int(round(hx)), int(round(hy)), mace, glow=glow)
    cv.outline(c("K"))
    if glow >= 2:                                            # charge ring: wide, bright, before the hit frame
        for d in range(0, 360, 30):
            rx_, ry_ = _ang(ex, ey, d, 9)
            cv.rect(int(round(rx_)), int(round(ry_)), 2 if d % 60 == 0 else 1, 2 if d % 60 == 0 else 1,
                    c("Q" if d % 60 == 0 else "z"))
    if shock:
        for i in range(-9, 10):
            cv.put(int(round(ex)) + i, gy - (1 if abs(i) % 3 == 0 else 0), c("z"))
        arc_swoosh(cv, sx, sy, 22, -70, 55, "z", "Q", 3)
    return cv


def warlord_anims():
    idle = [warlord_frame(), warlord_frame(cape=1), warlord_frame(bob=1, cape=1), warlord_frame(bob=1)]
    walk = [warlord_frame(bob=(1 if i in (1, 4) else 0), lean=1, phase=i, cape=1 + i % 2,
                          mace=-78 + (3 if i % 2 else 0)) for i in range(6)]
    atk = [
        warlord_frame(lean=-1, arm=-60, mace=-95, cape=0),
        warlord_frame(lean=-2, arm=-80, mace=-88, glow=1, jaw=1),
        warlord_frame(lean=-3, bob=1, arm=-85, mace=-75, glow=2, jaw=2),             # telegraph: longest read
        warlord_frame(lean=3, dx=2, arm=25, mace=62, glow=1, jaw=2, cape=3, shock=True, phase=1),
        warlord_frame(lean=2, dx=2, arm=30, mace=65, jaw=1, cape=2, phase=1),
        warlord_frame(lean=0, arm=-10, mace=-40, cape=1),
    ]
    hurt = warlord_frame(lean=-2, shut=True, arm=40, mace=-30, cape=-1, jaw=1)
    return {
        "idle": dict(frames=idle, fps=4, loop=True),
        "walk": dict(frames=walk, fps=7, loop=True),
        "attack": dict(frames=atk, fps=9, loop=False, events={"hit": 3}),
        "hit": dict(frames=[hurt, warlord_frame(lean=-1)], fps=10, loop=False),
        "death": dict(frames=_death(hurt, 7), fps=14, loop=False),
    }


def apply():
    """Swap the four entries in the build registries (called from build.apply_name_redraws)."""
    import chars_player, chars_enemy, chars_r04, chars_retheme
    chars_player.ALL["hero_captain"] = (_B(48, 48, 22), hero_anims)
    chars_player.ALL["melee_basic"] = (_B(32, 32, 13), toast_anims)
    chars_enemy.ALL["e_grunt"] = (_B(32, 32, 13), grunt_anims)
    chars_r04.BOSS["boss_warlord"] = (_B(64, 64, 28), warlord_anims)
    chars_retheme.NATIVE.update(SIDS)
