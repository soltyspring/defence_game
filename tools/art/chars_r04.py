"""r04-r07 roster (owner: 03-art): fast (lancer on pony), siege (catapult), e_brute,
e_bomber, boss_warlord. Theme = reversible default (Q1 PENDING). All original,
drawn with the same palette/rig/outline rules as the r01-r03 pack. Facing RIGHT.
hit frames match data/units/units.json: fast 1, siege 3, e_brute 3, e_bomber 1, warlord 3.
"""
from __future__ import annotations

import math
from dataclasses import replace

import numpy as np

from pixel import Canvas, Sprite, c
from rig import Body, Pose, render, anchors, pole, _dir
from anim import walk_poses, death_frames, frames_of, ground_fit, arc_swoosh


class _B:
    def __init__(self, W, H, px):
        self.W, self.H, self.px = W, H, px


def _dissolve_tail(last: Canvas, levels=(6, 11, 14)):
    out = []
    for d in levels:
        f = last.copy()
        f.dissolve(d)
        out.append(f)
    return out


# =============================================================================
# FAST — light lancer on a cream pony. Role cue: horse silhouette + blue pennant.
# 40x32, pivot (18, 31)
# =============================================================================
RIDER_HEAD = Sprite.parse("""
..mMMm..
.mMNNWm.
mMMMNNNm
.hSLKLS.
.hSSLKe.
..sSSs..
""")
RIDER_TORSO = Sprite.parse("""
.bBCb.
bBBCCb
BBYCCc
bBBCCb
""")


def pony(cv: Canvas, bx, by, phase, gallop=True, rear=0):
    """bx,by = body centre. phase 0..5 gallop cycle. rear>0 lifts the front."""
    g = cv.h - 1
    # legs (drawn first, behind body); front pair x+5/+3, back pair x-5/-7
    legs = [(5, 0.0, "x"), (3, 0.5, "X"), (-5, 0.25, "x"), (-7, 0.75, "X")]
    for (lx, ph, col) in legs:
        t = 2 * math.pi * (phase / 6.0 + ph)
        swing = round(3 * math.sin(t)) if gallop else 0
        lift = max(0, round(2 * math.cos(t))) if gallop else 0
        hx, hy = bx + lx, by + 2
        if lx > 0:
            hy -= rear
        fx, fy = hx + swing, g - lift - (rear if lx > 0 else 0)
        kx = (hx + fx) // 2 + (1 if lx > 0 else -1)
        ky = (hy + fy) // 2
        cv.line(hx, hy, kx, ky, c(col))
        cv.line(hx + 1, hy, kx + 1, ky, c(col))
        cv.line(kx, ky, fx, fy - 1, c(col))
        cv.put(fx, fy, c("w")); cv.put(fx + 1, fy, c("w"))
    # body
    cv.ellipse(bx, by - rear * 0.4, 9, 4.2, c("U"))
    cv.ellipse(bx - 1, by + 1.5 - rear * 0.4, 7, 2, c("x"))       # belly shade
    # neck + head
    nx, ny = bx + 7, by - 2 - rear
    cv.thick_line(nx, ny, nx + 4, ny - 6, c("U"), t=3)
    cv.ellipse(nx + 6, ny - 6, 3.2, 2.2, c("U"))
    cv.rect(nx + 8, ny - 6, 2, 2, c("x"))                           # muzzle
    cv.put(nx + 9, ny - 6, c("w"))                                   # nostril
    cv.put(nx + 6, ny - 7, c("K"))                                   # eye
    cv.put(nx + 4, ny - 9, c("U")); cv.put(nx + 4, ny - 10, c("x"))  # ear
    # mane + tail
    for i in range(5):
        cv.put(nx + 3 + i // 2 - 1, ny - 7 + i + (phase + i) % 2 * 0, c("o"))
        cv.put(nx + 2 + i // 2 - 1, ny - 6 + i, c("O"))
    tsw = [0, 1, 2, 1, 0, -1][phase % 6]
    cv.line(bx - 9, by - 2 - rear * 0.4, bx - 12, by + 1 + tsw, c("o"))
    cv.line(bx - 10, by - 2 - rear * 0.4, bx - 13, by + 2 + tsw, c("O"))
    # barding / saddle cloth (faction colour)
    cv.rect(bx - 4, by - 4 - round(rear * 0.4), 8, 4, c("B"))
    cv.hline(bx - 4, bx + 3, by - 1 - round(rear * 0.4), c("Y"))
    cv.vline(bx - 4, by - 4 - round(rear * 0.4), by - 1 - round(rear * 0.4), c("b"))


def lance(cv: Canvas, hx, hy, ang, flag_phase=0):
    dx, dy = _dir(ang)
    for i in range(-3, 15):
        cv.put(round(hx + dx * i), round(hy + dy * i), c("o" if i < 13 else "N"))
    tx, ty = hx + dx * 15, hy + dy * 15
    cv.put(round(tx), round(ty), c("W"))
    # pennant just behind the tip, trailing back
    px_, py_ = -dy, dx
    bx_, by_ = hx + dx * 11, hy + dy * 11
    for k in range(4):
        for j in range(3 - k // 2):
            cv.put(round(bx_ - dx * k + px_ * (j + 1) * (-1 if dy < 0.3 else 1) * 0 + (-px_ if py_ < 0 else px_) * 0),
                   round(by_ - dy * k + j + (flag_phase if k == 3 else 0)), c("C" if j == 0 else "B"))


def fast_frame(phase, pose="walk", gallop=True):
    cv = Canvas(40, 32)
    g = 31
    bob = [0, -1, -1, 0, 1, 0][phase % 6] if gallop else 0
    rear = 0
    if pose == "hurt":
        rear = 2
    bx, by = 17, g - 9 + bob
    pony(cv, bx, by, phase, gallop=gallop, rear=rear)
    # rider (seated on the saddle)
    sx, sy = bx - 3, by - 8 - round(rear * 0.4)
    lean = {"walk": 0, "wind": -1, "thrust": 2, "recover": 1, "hurt": -1}.get(pose, 0)
    # leg hanging down the flank
    cv.thick_line(sx + 3, sy + 4, sx + 4, sy + 7, c("b"), t=2)
    cv.put(sx + 5, sy + 8, c("w"))
    cv.stamp(RIDER_TORSO, sx + lean, sy)
    cv.stamp(RIDER_HEAD, sx - 1 + lean, sy - 6)
    hand = (sx + 5 + lean, sy + 2)
    ang = {"walk": -35, "wind": -60, "thrust": 0, "recover": -15, "hurt": -70}.get(pose, -35)
    if pose == "thrust":
        hand = (hand[0] + 3, hand[1])
    elif pose == "wind":
        hand = (hand[0] - 2, hand[1] + 1)
    cv.thick_line(sx + 3 + lean, sy + 1, hand[0], hand[1], c("B"), t=2)
    lance(cv, hand[0], hand[1], ang, flag_phase=phase % 2)
    cv.outline(c("K"))
    if pose == "thrust":   # speed streaks
        for (y, x0, x1) in ((hand[1] - 2, hand[0] - 8, hand[0] - 3), (hand[1] + 2, hand[0] - 6, hand[0] - 2)):
            cv.hline(x0, x1, y, c("c"))
    return cv


def fast_anims():
    walk = [fast_frame(i) for i in range(6)]
    idle = [fast_frame(0, gallop=False), fast_frame(1, gallop=False)]
    attack = [fast_frame(0, "wind", False), fast_frame(1, "thrust", False),
              fast_frame(2, "thrust", False), fast_frame(3, "recover", False)]
    hurt = fast_frame(0, "hurt", False)
    hit = [hurt, fast_frame(1, "walk", False)]
    lying = fast_frame(0, "hurt", False)
    lying.rot90_about(18, 31, k=3)
    ground_fit(lying, 18)
    death = [hurt, lying] + _dissolve_tail(lying)
    return {
        "idle": dict(frames=idle, fps=4, loop=True),
        "walk": dict(frames=walk, fps=14, loop=True),
        "attack": dict(frames=attack, fps=10, loop=False, events={"hit": 1}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=8, loop=False),
    }


# =============================================================================
# SIEGE — wheeled catapult with blue banner. 48x40, pivot (22, 39).
# Role cue: big wooden frame + throwing arm (no other unit has it).
# =============================================================================
def wheel(cv: Canvas, cx, cy, r, phase):
    cv.ellipse(cx + 0.5, cy + 0.5, r, r, c("w"))
    cv.ellipse(cx + 0.5, cy + 0.5, r - 1.2, r - 1.2, c("O"))
    for k in range(4):
        a = math.radians(phase * 22.5 + k * 45)
        cv.line(cx, cy, round(cx + math.cos(a) * (r - 1)), round(cy + math.sin(a) * (r - 1)), c("o"))
    cv.put(cx, cy, c("Y"))


def catapult(phase=0, arm=155.0, loaded=True, bounce=0, broken=False):
    cv = Canvas(48, 40)
    g = 39
    by = g - 5 + bounce
    # chassis beam
    cv.rect(6, by - 4, 32, 3, c("O"))
    cv.hline(6, 37, by - 4, c("o"))
    # A-frame uprights
    ax, ay = 24, by - 18
    if not broken:
        cv.thick_line(16, by - 3, ax, ay, c("o"), t=2)
        cv.thick_line(32, by - 3, ax + 1, ay, c("O"), t=2)
        cv.hline(19, 29, by - 10, c("O"))                     # cross brace
    # counter-rope / winch drum at the rear
    cv.ellipse(10, by - 6, 2.5, 2.5, c("O")); cv.put(10, by - 6, c("Y"))
    # throwing arm (pivot at ax, ay); arm angle in screen degrees
    if not broken:
        dx, dy = _dir(arm)
        L = 20
        for i in range(-4, L):
            x, y = round(ax + dx * i), round(ay + dy * i)
            cv.put(x, y, c("o")); cv.put(x, y + 1, c("O"))
        tx, ty = ax + dx * L, ay + dy * L
        cv.ellipse(tx, ty, 3, 2.2, c("w"))                      # bucket
        cv.ellipse(tx, ty - 0.5, 2, 1.4, c("O"))
        if loaded:
            cv.ellipse(tx, ty - 2, 2.2, 2.2, c("X"))
            cv.put(round(tx) - 1, round(ty) - 3, c("x"))
        cv.put(ax, ay, c("Y"))
    else:
        cv.line(12, by - 6, 30, by - 2, c("o"))
        cv.line(20, by - 14, 26, by - 4, c("O"))
    # faction banner on a short mast at the front
    cv.vline(38, by - 20, by - 5, c("w"))
    sway = [0, 1, 0, -1][phase % 4]
    for j in range(6):
        for i in range(5):
            if j == 5 and i % 2:
                continue
            cv.put(39 + i + (sway if j > 2 else 0), by - 20 + j, c("B" if i < 4 else "b"))
    cv.put(41 + sway, by - 18, c("Y")); cv.put(41 + sway, by - 17, c("Y"))
    # wheels
    wheel(cv, 13, g - 4, 4.5, phase)
    wheel(cv, 33, g - 4, 4.5, phase)
    cv.outline(c("K"))
    return cv


def siege_anims():
    walk = [catapult(i, bounce=(i % 2)) for i in range(4)]   # arm resting at the rear, loaded
    idle = [catapult(0), catapult(1)]
    # wind back (arm down/back), hold, release (hit 3, rock leaves), follow-through, reset
    # tension, crank, swing up, RELEASE (hit 3, empty bucket forward-up), overshoot, fall back
    arms = [(155, True), (160, True), (110, True), (-50, False), (-70, False), (-120, False)]
    attack = [catapult(0, a, l) for (a, l) in arms]
    hit = [catapult(0, 150, True, bounce=1), catapult(0)]
    broken = catapult(0, broken=True)
    death = [catapult(0, 150, False, bounce=1), broken] + _dissolve_tail(broken)
    # projectile spawn = bucket position on release frame (arm -50 deg)
    dx, dy = _dir(-50)
    spawn = [round(24 + dx * 20), round(39 - 5 - 18 + dy * 20)]
    return {
        "idle": dict(frames=idle, fps=2, loop=True),
        "walk": dict(frames=walk, fps=8, loop=True),
        "attack": dict(frames=attack, fps=10, loop=False, events={"hit": 3}, points={"projectile_spawn": spawn}),
        "hit": dict(frames=hit, fps=10, loop=False),
        "death": dict(frames=death, fps=8, loop=False),
    }


# =============================================================================
# E_BRUTE — hulking bramble troll with a log club. 48x48, ~36 px tall.
# Role cue: twice the bulk of a grunt, bark shoulder plates, grey-green skin.
# =============================================================================
BRUTE_HEAD = Sprite.parse("""
....gGGGg....
..gGFFFFFGg..
.gGFFFFFFFGg.
gGGFFFFKKFFg.
GGGGFFFFKKFFg
gGGGGFFFFFFFg
.gGGrRRRRrFg.
.gGGrUrUrrg..
..gGGGGGGg...
""")
BRUTE_TORSO = Sprite.parse("""
...wOOOOw.....
.wOoooooOOw...
wOoTGGGGoOOw..
OoGGFFFFGGoOw.
.GGFFFFFFGGG..
.GGGFFFFFGGG..
.gGGGFFFGGGg..
.gGGGGGGGGGg..
.pPPVVVPPPPp..
.pPPPPPPPPPp..
""")


def log_club(cv, hand, pose, body):
    dx, dy = _dir(pose.weapon_ang)
    hx, hy = hand
    px_, py_ = -dy, dx
    for i in range(-2, 14):
        w = 1 if i < 5 else 2
        for s in range(-w, w + 1):
            cv.put(round(hx + dx * i + px_ * s * 0.5), round(hy + dy * i + py_ * s * 0.5),
                   c("O" if s < 0 else ("o" if s == 0 else "w")))
    # knots and thorns
    for i in (7, 11):
        cv.put(round(hx + dx * i + px_ * 2), round(hy + dy * i + py_ * 2), c("U"))
        cv.put(round(hx + dx * i - px_ * 2), round(hy + dy * i - py_ * 2), c("U"))
    cv.put(round(hx + dx * 14), round(hy + dy * 14), c("T"))


BRUTE_HEAD = BRUTE_HEAD.recolored({"F": "G", "G": "g", "g": "a"})
BRUTE_TORSO = Sprite(np.insert(BRUTE_TORSO.a, [4, 5, 6], BRUTE_TORSO.a[[4, 5, 6]], axis=0)).recolored({"F": "G", "G": "g", "g": "a"})

BRUTE = Body(
    W=48, H=48, px=21, head=BRUTE_HEAD, torso=BRUTE_TORSO, head_anchor=(1, 0),
    shoulder_f=(11, 3), shoulder_b=(2, 3), leg_len=10, leg_t=4, leg_col="g", leg_shade="a", boot_col="w",
    arm_t=4, arm_col="G", arm_shade="g", hand_col="F", hip_w=2, head_overlap=2, torso_overlap=1,
    weapon=log_club, boot_w=2,
    blink_px=[(8, 3, "G"), (9, 3, "G"), (8, 4, "G")],
)
BRUTE_BASE = Pose(feet=((3, 0), (-4, 0)), hand_f=(3, 6), hand_b=(-1, 7), weapon_ang=-75, lean=1)


def brute_anims():
    b = BRUTE
    idle = [BRUTE_BASE, replace(BRUTE_BASE, bob=1), replace(BRUTE_BASE, bob=1, hand_f=(3, 7)),
            replace(BRUTE_BASE, blink=True)]
    walk = walk_poses(replace(BRUTE_BASE, weapon_ang=-60), 6, stride=3, lift=1, arm_swing=1)
    atk = [
        replace(BRUTE_BASE, hand_f=(0, -2), weapon_ang=-120, lean=-1),
        replace(BRUTE_BASE, hand_f=(-2, -6), weapon_ang=-160, lean=-2, head_dy=-1),
        replace(BRUTE_BASE, hand_f=(4, -3), weapon_ang=-60, lean=1),
        replace(BRUTE_BASE, hand_f=(7, 5), weapon_ang=30, lean=3, bob=2, feet=((5, 0), (-4, 0))),
        replace(BRUTE_BASE, hand_f=(6, 7), weapon_ang=45, lean=2, bob=1),
    ]

    def post(cv, i, p):
        if i == 3:      # ground impact cracks + dust at the club head
            a = anchors(b, p)
            x, y = a["hf"][0] + 9, b.H - 2
            for dx in (-5, -3, 3, 5):
                cv.put(x + dx, y - abs(dx) // 2, c("T"))
            cv.hline(x - 2, x + 2, y, c("a"))

    hurt = replace(BRUTE_BASE, lean=-2, head_dx=-1, feet=((2, 0), (-5, 0)))
    kneel = replace(BRUTE_BASE, crouch=3, lean=-1, feet=((4, 0), (-5, 0)), weapon_ang=80, hand_f=(4, 8))
    return {
        "idle": dict(frames=frames_of(b, idle), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=7, loop=True),
        "attack": dict(frames=frames_of(b, atk, post), fps=8, loop=False, events={"hit": 3}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel), fps=7, loop=False),
    }


# =============================================================================
# E_BOMBER — goggled sapper sprinting with a glowing spore keg. 32x32.
# Role cue: big keg + flickering fuse (danger), orange accent unique to it.
# =============================================================================
BOMB_HEAD = Sprite.parse("""
...eEEEe...
..eEEEEEe..
.gGFFFFFFg.
gGFQqFQqFFF
.GFqqFqqFg.
.gGFFFFFg..
..gGrrGg...
""")
BOMB_TORSO = Sprite.parse("""
..pPPp..
.pPVPPp.
.wOOOOOw
.pPPPPPp
.rRrRrRr
""")


def keg(cv: Canvas, x, y, fuse_phase, held_high=False):
    """x,y = keg centre."""
    cv.ellipse(x, y, 4.2, 4.6, c("O"))
    cv.ellipse(x - 1, y - 1, 2.5, 3.2, c("o"))
    cv.hline(x - 4, x + 3, y - 2, c("w"))
    cv.hline(x - 4, x + 3, y + 2, c("w"))
    cv.put(x - 1, y, c("f")); cv.put(x, y, c("F")); cv.put(x - 1, y + 1, c("F"))   # spore glow
    # fuse
    fx, fy = x + 2, y - 5
    cv.put(fx, fy, c("w")); cv.put(fx + 1, fy - 1, c("w"))
    spark = [(fx + 2, fy - 2, "Z"), (fx + 3, fy - 3, "e"), (fx + 1, fy - 3, "Z")]
    for k, (sx, sy, col) in enumerate(spark):
        if (k + fuse_phase) % 2 == 0:
            cv.put(sx, sy, c(col))


def keg_back(cv, a, pose, body):
    if pose.extra.get("keg_up"):
        return
    x, y = a["sb"]
    keg(cv, x - 2, y + 1, pose.extra.get("fuse", 0))


def keg_overhead(cv, a, pose, body):
    if not pose.extra.get("keg_up"):
        return
    hx, hy = a["hf"]
    keg(cv, hx - 1, hy - 5, pose.extra.get("fuse", 0), held_high=True)


BOMBER = Body(
    W=32, H=32, px=13, head=BOMB_HEAD, torso=BOMB_TORSO, head_anchor=(-1, 0),
    shoulder_f=(5, 1), shoulder_b=(2, 1), leg_len=4, leg_t=2, leg_col="G", leg_shade="g", boot_col="w",
    arm_t=2, arm_col="G", arm_shade="g", hand_col="F", hip_w=1,
    back_item=keg_back, offhand=keg_overhead,
)
BOMB_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(3, 3), hand_b=(-2, 2), lean=2)


def bomber_anims():
    b = BOMBER
    walk = walk_poses(BOMB_BASE, 6, stride=4, lift=2, arm_swing=2)
    walk = [replace(p, extra={"fuse": i % 2}) for i, p in enumerate(walk)]
    idle = [replace(BOMB_BASE, lean=1, extra={"fuse": 0}), replace(BOMB_BASE, lean=1, bob=1, extra={"fuse": 1})]
    atk = [
        replace(BOMB_BASE, hand_f=(1, -4), hand_b=(0, -4), lean=0, extra={"keg_up": True, "fuse": 0}),
        replace(BOMB_BASE, hand_f=(3, -2), hand_b=(1, -2), lean=2, extra={"keg_up": True, "fuse": 1}),
        replace(BOMB_BASE, hand_f=(4, 0), hand_b=(2, 0), lean=3, bob=1, extra={"keg_up": True, "fuse": 0}),
    ]

    def flash(cv, i, p):
        if i == 2:   # pre-detonation flash ring (engine plays `explosion` fx on hit)
            a = anchors(b, p)
            x, y = a["hf"][0] - 1, a["hf"][1] - 5
            for k in range(0, 360, 45):
                cv.put(round(x + math.cos(math.radians(k)) * 7), round(y + math.sin(math.radians(k)) * 7), c("Z"))

    hurt = replace(BOMB_BASE, lean=-1, head_dx=-1, feet=((1, 0), (-3, 0)), extra={"fuse": 1})
    kneel = replace(BOMB_BASE, crouch=2, lean=-1, feet=((3, 0), (-3, 0)), extra={"fuse": 0})
    return {
        "idle": dict(frames=frames_of(b, idle), fps=6, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=14, loop=True),
        "attack": dict(frames=frames_of(b, atk, flash), fps=10, loop=False, events={"hit": 1}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel), fps=8, loop=False),
    }


# =============================================================================
# BOSS_WARLORD — thorn-crowned goblin warlord, bark armour, purple cape,
# serrated cleaver. 64x64, ~52 px tall. Own page (char_boss_warlord).
# =============================================================================
WAR_HEAD = Sprite.parse("""
..U...U...U...U..
..yY.yYY.yYY.yY..
...YYYYYYYYYYY...
....gGGGGGGGg....
...gGFFFFFFFFGg..
..gGFFFFFFFFFFFg.
.gGGFFFFFEEFFFFGF
gGGGGFFFFEEEFFFFg
GGGGGGFFFFFFFFFg.
gGGGGrRRRRRRrFFg.
.gGGrUrUrUrUrFg..
..gGGrrrrrrrGg...
...gGGGGGGGGg....
""")
WAR_TORSO = Sprite.parse("""
..UwOOOOOOOwU....
.wOoTTTTTTToOw...
wOoTwOOOOOwToOw..
OoTwOoYYYoOwToO..
.wOOoYZZZYoOOOw..
.pPwOoYYYoOwPPp..
.pPPwOOOOOwPPPp..
.pPVPwOOOwPPPPp..
.yYYYYYZYYYYYYy..
.rRRRRRRRRRRRRr..
.rRrRRrRRRrRRRr..
""")


def cleaver(cv, hand, pose, body):
    dx, dy = _dir(pose.weapon_ang)
    hx, hy = hand
    px_, py_ = -dy, dx
    # haft
    for i in range(-3, 6):
        cv.put(round(hx + dx * i), round(hy + dy * i), c("w" if i < 0 else "O"))
    # broad blade on the "outer" side, serrated back edge
    for i in range(5, 18):
        w = 3 if i < 15 else 2 if i < 17 else 1
        for s in range(0, w + 1):
            k = "N" if s == 0 else ("M" if s < w else "m")
            if s == w and i % 2:
                continue  # serration
            cv.put(round(hx + dx * i - px_ * s), round(hy + dy * i - py_ * s), c(k))
        cv.put(round(hx + dx * i + px_), round(hy + dy * i + py_), c("W"))   # bright edge
    cv.put(round(hx + dx * 7 - px_ * 1), round(hy + dy * 7 - py_ * 1), c("R"))  # rune


WAR_HEAD = Sprite(np.insert(WAR_HEAD.a, [6], WAR_HEAD.a[[6]], axis=0))
WAR_TORSO = Sprite(np.insert(WAR_TORSO.a, [5, 6, 7, 9], WAR_TORSO.a[[5, 6, 7, 9]], axis=0))

WARLORD = Body(
    W=64, H=64, px=28, head=WAR_HEAD, torso=WAR_TORSO, head_anchor=(0, 0),
    shoulder_f=(13, 3), shoulder_b=(3, 3), leg_len=16, leg_t=5, leg_col="P", leg_shade="p", boot_col="w",
    arm_t=4, arm_col="G", arm_shade="g", hand_col="F", hip_w=3, head_overlap=2, torso_overlap=1,
    cape_col="P", cape_shade="p", cape_len=28, weapon=cleaver, boot_w=2,
    blink_px=[(9, 6, "F"), (10, 6, "F"), (9, 7, "F"), (10, 7, "F")],
)
WAR_BASE = Pose(feet=((4, 0), (-5, 0)), hand_f=(4, 8), hand_b=(-1, 9), weapon_ang=-80, lean=1)


def warlord_anims():
    b = WARLORD
    idle = [WAR_BASE, replace(WAR_BASE, cape=1), replace(WAR_BASE, bob=1, cape=1, hand_f=(4, 9)),
            replace(WAR_BASE, bob=1, cape=0, blink=True)]
    walk = walk_poses(replace(WAR_BASE, weapon_ang=-70), 6, stride=4, lift=2, arm_swing=1)
    atk = [
        replace(WAR_BASE, hand_f=(0, -2), weapon_ang=-130, lean=-1, cape=1),
        replace(WAR_BASE, hand_f=(-3, -8), weapon_ang=-165, lean=-2, cape=2, head_dy=-1),
        replace(WAR_BASE, hand_f=(5, -5), weapon_ang=-70, lean=1, cape=3),
        replace(WAR_BASE, hand_f=(10, 6), weapon_ang=35, lean=3, bob=2, cape=3, feet=((7, 0), (-5, 0))),
        replace(WAR_BASE, hand_f=(9, 9), weapon_ang=55, lean=2, bob=1, cape=2, feet=((7, 0), (-5, 0))),
        replace(WAR_BASE, hand_f=(5, 8), weapon_ang=-30, lean=1, cape=1),
    ]

    def post(cv, i, p):
        a = anchors(b, p)
        if i == 2:
            arc_swoosh(cv, a["sf"][0], a["sf"][1] + 2, 22, -150, -40, "v", "V", thick=2)
        if i == 3:
            arc_swoosh(cv, a["sf"][0], a["sf"][1] + 2, 24, -120, 40, "W", "v", thick=3)
            gx, gy = a["hf"][0] + 14, b.H - 2      # ground shockwave cue
            for dx in (-8, -5, 5, 8):
                cv.put(gx + dx, gy - abs(dx) // 3, c("e"))
            cv.hline(gx - 3, gx + 3, gy, c("Z"))

    hurt = replace(WAR_BASE, lean=-2, head_dx=-1, feet=((3, 0), (-6, 0)), cape=2)
    kneel = replace(WAR_BASE, crouch=4, lean=-1, feet=((5, 0), (-6, 0)), weapon_ang=85, hand_f=(5, 10))
    return {
        "idle": dict(frames=frames_of(b, idle), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=7, loop=True),
        "attack": dict(frames=frames_of(b, atk, post), fps=9, loop=False, events={"hit": 3}),
        "hit": dict(frames=frames_of(b, [hurt, replace(hurt, head_dx=0)]), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel, dissolve=(5, 9, 12, 15)), fps=7, loop=False),
    }


PLAYER = {"fast": (_B(40, 32, 18), fast_anims), "siege": (_B(48, 40, 22), siege_anims)}
ENEMY = {"e_brute": (BRUTE, brute_anims), "e_bomber": (BOMBER, bomber_anims)}
BOSS = {"boss_warlord": (WARLORD, warlord_anims)}
ALL = {**PLAYER, **ENEMY, **BOSS}
