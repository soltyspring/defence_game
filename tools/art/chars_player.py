"""Player-faction characters (owner: 03-art). Theme-neutral default ("lantern
kingdom" knights) until docs/design/DECISIONS.md fixes Q1 theme; ids follow
01 data (`sprite` fields) so a re-theme only swaps the drawings.
"""
from __future__ import annotations

from dataclasses import replace

from pixel import Sprite, c
from rig import Body, Pose, render, anchors, blade, pole, spear_head, _dir
from anim import walk_poses, death_frames, frames_of, arc_swoosh

# ---------------------------------------------------------------------------
# HERO  (hero_captain) 48x48, ~33 px tall
# ---------------------------------------------------------------------------
HERO_HEAD = Sprite.parse("""
.....RRe......
....RREe......
...RRMNNNm....
..mMMNNNNWNm..
.mMMMNNNNNNNm.
.mMMMMMMNNNNm.
mMMMmLLLLLLLL.
mMMMmSLLLKLLL.
mMMMmSSLLKLeL.
mMMmmSSSSSSSs.
.mMmmsSSSSSs..
..mm..sSSSs...
""")

HERO_TORSO = Sprite.parse("""
...mNNNNm...
..mMBBCCNm..
.mMBBBCCcNm.
.MBBBYYCCCM.
.MBBBYYCCCM.
.mBBBYYCCCm.
.yYYYYZYYYy.
.bBBBBBCCCb.
.bbBBBBBCCb.
""")


def hero_sword(cv, hand, pose: Pose, body):
    blade(cv, hand, pose.weapon_ang, 12, main="N", edge="M", tip="W", guard="Y", hilt="O", guard_w=1)


HERO = Body(
    W=48, H=48, px=22,
    head=HERO_HEAD, torso=HERO_TORSO, head_anchor=(-1, 0),
    shoulder_f=(9, 2), shoulder_b=(3, 2),
    leg_len=9, leg_t=3, leg_col="M", leg_shade="m", boot_col="w",
    arm_t=3, arm_col="M", arm_shade="m", hand_col="N",
    hip_w=2, head_overlap=1, torso_overlap=1,
    cape_col="R", cape_shade="r", cape_len=14,
    weapon=hero_sword,
    blink_px=[(9, 7, "L"), (9, 8, "S")],
)

HERO_BASE = Pose(feet=((3, 0), (-3, 0)), hand_f=(2, 6), hand_b=(-1, 6), weapon_ang=50)


def hero_anims(b=None):
    """Poses are body-independent: art 0.11.0 passes the 제빵 대장 body (chars_retheme.HERO_BAKER)."""
    b = b or HERO
    idle_p = [replace(HERO_BASE, bob=0, cape=0),
              replace(HERO_BASE, bob=0, cape=1),
              replace(HERO_BASE, bob=1, cape=1, hand_f=(2, 7)),
              replace(HERO_BASE, bob=1, cape=0, hand_f=(2, 7), blink=True)]
    walk_p = walk_poses(replace(HERO_BASE, weapon_ang=40, lean=1), n=6, stride=4, lift=2, arm_swing=2)
    # attack: wind-up, raise, swing, impact(hit=3), follow, recover
    wide = ((4, 0), (-4, 0))
    atk = [
        replace(HERO_BASE, lean=-1, hand_f=(-1, 1), weapon_ang=-110, feet=wide),
        replace(HERO_BASE, lean=-2, hand_f=(-3, -3), weapon_ang=-145, feet=wide, cape=1),
        replace(HERO_BASE, lean=1, hand_f=(3, -2), weapon_ang=-45, feet=((5, 0), (-4, 0)), cape=2),
        replace(HERO_BASE, lean=2, bob=1, hand_f=(6, 3), weapon_ang=12, feet=((6, 0), (-4, 0)), cape=3),
        replace(HERO_BASE, lean=2, bob=1, hand_f=(5, 6), weapon_ang=55, feet=((6, 0), (-4, 0)), cape=2),
        replace(HERO_BASE, lean=1, hand_f=(3, 6), weapon_ang=55, feet=((4, 0), (-3, 0)), cape=1),
    ]

    def atk_post(cv, i, p):
        a = anchors(b, p)
        sx, sy = a["sf"]
        if i == 3:
            arc_swoosh(cv, sx, sy + 1, 17, -120, 25, "W", "c", thick=3)
        if i == 4:
            arc_swoosh(cv, sx, sy + 1, 17, -10, 45, "c", "C", thick=2)

    cast = [
        replace(HERO_BASE, hand_f=(1, 1), weapon_ang=-70),
        replace(HERO_BASE, hand_f=(0, -4), weapon_ang=-90, cape=1),
        replace(HERO_BASE, hand_f=(0, -5), weapon_ang=-90, cape=2),
        replace(HERO_BASE, hand_f=(0, -5), weapon_ang=-90, cape=1),
        replace(HERO_BASE, hand_f=(4, 1), weapon_ang=-15, lean=1, bob=1, cape=2),
        replace(HERO_BASE, hand_f=(2, 5), weapon_ang=40),
    ]

    def cast_post(cv, i, p):
        a = anchors(b, p)
        hx, hy = a["hf"]
        tip = (hx, hy - 14)
        pts = {1: [(0, -2)], 2: [(0, -3), (-3, 0), (3, 0), (0, 3)],
               3: [(0, -4), (-4, 0), (4, 0), (-2, -2), (2, -2), (-2, 2), (2, 2)]}
        for (dx, dy) in pts.get(i, []):
            cv.put(tip[0] + dx, tip[1] + dy, c("Z"))
        if i in (2, 3):
            cv.put(tip[0], tip[1], c("W"))
        if i == 4:  # release flash travelling forward
            arc_swoosh(cv, a["sf"][0], a["sf"][1], 18, -40, 20, "Z", "Y", thick=2)

    hurt = replace(HERO_BASE, lean=-2, head_dx=-1, hand_f=(1, 4), weapon_ang=80, feet=((2, 0), (-4, 0)), cape=2)
    hit = [hurt, replace(hurt, lean=-1, head_dx=0)]
    kneel = replace(HERO_BASE, crouch=4, lean=-1, hand_f=(3, 7), weapon_ang=90, feet=((4, 0), (-5, 0)))
    anims = {
        "idle": dict(frames=frames_of(b, idle_p), fps=5, loop=True),
        "walk": dict(frames=frames_of(b, walk_p), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk, atk_post), fps=14, loop=False, events={"hit": 3}),
        "cast": dict(frames=frames_of(b, cast, cast_post), fps=12, loop=False, events={"release": 4}),
        "hit": dict(frames=frames_of(b, hit), fps=10, loop=False),
        "death": dict(frames=death_frames(b, hurt, kneel), fps=8, loop=False),
    }
    return anims


ALL = {
    "hero_captain": (HERO, hero_anims),
}


# ---------------------------------------------------------------------------
# shared 32x32 infantry helpers
# ---------------------------------------------------------------------------
def std_death(body, base: Pose):
    hurt = replace(base, lean=-1, head_dx=-1, feet=((1, 0), (-3, 0)))
    kneel = replace(base, crouch=2, lean=-1, feet=((3, 0), (-3, 0)))
    return death_frames(body, hurt, kneel, dissolve=(6, 11, 14))


def std_hit(body, base: Pose):
    hurt = replace(base, lean=-1, head_dx=-1, feet=((1, 0), (-3, 0)))
    return frames_of(body, [hurt, replace(hurt, head_dx=0)])


def std_idle(body, base: Pose, n=4):
    ps = [base, base, replace(base, bob=1), replace(base, bob=1, blink=True)][:n]
    return frames_of(body, ps)


# ---------------------------------------------------------------------------
# WORKER (unit_worker) 32x32 - miner with pickaxe, sack when carrying
# ---------------------------------------------------------------------------
WORKER_HEAD = Sprite.parse("""
...YYYY...
..YZZZZY..
.yYYYYYYYy
..hLLLLL..
.hhSLLKL..
.hhSSLKSe.
..hSSSSs..
...sSSs...
""")
WORKER_TORSO = Sprite.parse("""
..oTTo..
.oTTTTo.
.oTUTTTo
.oTTTTTo
.wOOOOOw
.OOoooO.
""")


def pickaxe(cv, hand, pose, body):
    tip = pole(cv, hand, pose.weapon_ang, 2, 7, shaft="o")
    dx, dy = _dir(pose.weapon_ang)
    px_, py_ = -dy, dx
    x, y = tip
    for s in range(-3, 4):
        cv.put(round(x + px_ * s + dx * (abs(s) == 3) * -1), round(y + py_ * s - dy * 0), c("M" if abs(s) < 3 else "N"))


def sack(cv, a, pose, body):
    if not pose.extra.get("sack"):
        return
    x, y = a["sb"]
    cv.ellipse(x - 1, y - 2, 4, 3.5, c("T"))
    cv.ellipse(x - 2, y - 3, 2, 1.5, c("U"))
    cv.put(x + 1, y - 6, c("o"))


WORKER = Body(
    W=32, H=32, px=14, head=WORKER_HEAD, torso=WORKER_TORSO, head_anchor=(-1, 0),
    shoulder_f=(5, 1), shoulder_b=(2, 1), leg_len=5, leg_t=2, leg_col="O", leg_shade="w", boot_col="w",
    arm_t=2, arm_col="T", arm_shade="o", hand_col="S", hip_w=1, weapon=pickaxe, back_item=sack,
    blink_px=[(6, 4, "L"), (6, 5, "S")],
)
WORKER_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(2, 4), hand_b=(-1, 4), weapon_ang=-60)


def worker_anims():
    b = WORKER
    work = [
        replace(WORKER_BASE, hand_f=(0, -2), weapon_ang=-150, lean=-1),
        replace(WORKER_BASE, hand_f=(-1, -3), weapon_ang=-175, lean=-1),
        replace(WORKER_BASE, hand_f=(3, 1), weapon_ang=-40, lean=1),
        replace(WORKER_BASE, hand_f=(4, 4), weapon_ang=20, lean=1, bob=1),
    ]

    def work_post(cv, i, p):
        if i == 3:  # sparks at pick impact
            a = anchors(b, p)
            x, y = a["hf"][0] + 8, a["hf"][1] + 3
            for (dx, dy) in [(0, -2), (2, -1), (-1, -3), (3, -3)]:
                cv.put(x + dx, y + dy, c("Z"))

    carry_base = replace(WORKER_BASE, weapon_on=False, hand_b=(1, -1), extra={"sack": True})
    return {
        "idle": dict(frames=std_idle(b, WORKER_BASE), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk_poses(WORKER_BASE, 6, 2, 1, 1)), fps=10, loop=True),
        "work": dict(frames=frames_of(b, work, work_post), fps=8, loop=True, events={"hit": 3}),
        "carry": dict(frames=frames_of(b, walk_poses(carry_base, 6, 2, 1, 0)), fps=9, loop=True),
        "death": dict(frames=std_death(b, WORKER_BASE), fps=8, loop=False),
    }


# ---------------------------------------------------------------------------
# MELEE (unit_melee_basic) - spearman
# ---------------------------------------------------------------------------
# A28: helmet = a toast slice (two rounded top bumps, crust rim, crumb face) -> "식빵 기사"
# A26 (art 0.12.1): crumb pores (T) in the toast helmet, toast-slice cuirass with a crust rim
SPEAR_HEAD = Sprite.parse("""
..mmm.mmm.
.mcTcmcTcm
.mmmmmmmmm
..hLLLLLL.
..hSLLKLL.
..hSSLKSe.
..hSSSSSs.
...sSSSs..
""")
SPEAR_TORSO = Sprite.parse("""
..oUUo..
.oUTUUo.
.OUUUTUO
.oUTUUUo
.wOOYOOw
.byBByBb
""")


def spear(cv, hand, pose, body):
    pole(cv, hand, pose.weapon_ang, 5, 9, shaft="o", head=lambda cv_, t, a: spear_head(cv_, t, a))


SPEARMAN = Body(
    W=32, H=32, px=13, head=SPEAR_HEAD, torso=SPEAR_TORSO, head_anchor=(-1, 0),
    shoulder_f=(5, 1), shoulder_b=(2, 1), leg_len=5, leg_t=2, leg_col="b", leg_shade="b", boot_col="w",
    arm_t=2, arm_col="B", arm_shade="b", hand_col="S", hip_w=1, weapon=spear,
    blink_px=[(6, 4, "L"), (6, 5, "S")],
)
SPEAR_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(2, 4), hand_b=(-1, 4), weapon_ang=-80)


def spearman_anims():
    b = SPEARMAN
    walk = walk_poses(replace(SPEAR_BASE, weapon_ang=-55, hand_f=(2, 3)), 6, 3, 2, 1)
    atk = [
        replace(SPEAR_BASE, hand_f=(0, 3), weapon_ang=-10, lean=-1, feet=((3, 0), (-3, 0))),
        replace(SPEAR_BASE, hand_f=(-2, 3), weapon_ang=-5, lean=-2, feet=((3, 0), (-3, 0))),
        replace(SPEAR_BASE, hand_f=(5, 3), weapon_ang=0, lean=2, feet=((5, 0), (-3, 0))),
        replace(SPEAR_BASE, hand_f=(3, 3), weapon_ang=0, lean=1, feet=((4, 0), (-3, 0))),
        replace(SPEAR_BASE, hand_f=(2, 4), weapon_ang=-40, feet=((3, 0), (-2, 0))),
    ]

    def atk_post(cv, i, p):
        if i == 2:  # thrust streaks
            a = anchors(b, p)
            x, y = a["hf"][0] + 6, a["hf"][1]
            cv.hline(x - 6, x - 2, y - 2, c("c"))
            cv.hline(x - 5, x - 1, y + 2, c("c"))

    return {
        "idle": dict(frames=std_idle(b, SPEAR_BASE), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk, atk_post), fps=12, loop=False, events={"hit": 2}),
        "hit": dict(frames=std_hit(b, SPEAR_BASE), fps=10, loop=False),
        "death": dict(frames=std_death(b, SPEAR_BASE), fps=8, loop=False),
    }


# ---------------------------------------------------------------------------
# RANGED (unit_ranged_basic) - archer
# ---------------------------------------------------------------------------
ARCHER_HEAD = Sprite.parse("""
...OOOo...
..OooooTO.
.OooLLLLo.
.OoSLLKLL.
.OOSSLKSe.
.OOSSSSSs.
..OsSSSs..
""")
ARCHER_TORSO = Sprite.parse("""
..OCCO..
.OBBCCb.
.oBBCCcB
.oBBCCCb
.wOOYOOw
.bBBBCCb
""")


def bow(cv, hand, pose, body):
    hx, hy = hand
    draw = pose.extra.get("draw", 0)   # 0 rest, 1..3 pulled
    # bow limb: vertical arc bulging forward, 11 px tall
    pts = [(-5, -1), (-4, 0), (-3, 1), (-2, 1), (-1, 2), (0, 2), (1, 2), (2, 1), (3, 1), (4, 0), (5, -1)]
    for (dy, dx) in pts:
        cv.put(hx + dx, hy + dy, c("o" if abs(dy) < 4 else "O"))
    top, bot = (hx - 1, hy - 5), (hx - 1, hy + 5)
    sx = hx - 1 - draw
    cv.line(top[0], top[1], sx, hy, c("U"))
    cv.line(sx, hy, bot[0], bot[1], c("U"))
    if pose.extra.get("arrow"):
        cv.hline(sx, hx + 5, hy, c("o"))
        cv.put(hx + 6, hy, c("N"))
        cv.put(sx - 1, hy - 1, c("W"))
        cv.put(sx - 1, hy + 1, c("W"))


def quiver(cv, a, pose, body):
    x, y = a["sb"]
    cv.line(x - 2, y + 5, x + 1, y - 2, c("O"))
    cv.line(x - 1, y + 5, x + 2, y - 2, c("w"))
    cv.put(x + 1, y - 3, c("W"))
    cv.put(x + 3, y - 3, c("W"))


ARCHER = Body(
    W=32, H=32, px=13, head=ARCHER_HEAD, torso=ARCHER_TORSO, head_anchor=(-1, 0),
    shoulder_f=(5, 1), shoulder_b=(2, 1), leg_len=5, leg_t=2, leg_col="O", leg_shade="w", boot_col="w",
    arm_t=2, arm_col="B", arm_shade="b", hand_col="S", hip_w=1, weapon=bow, back_item=quiver,
    blink_px=[(6, 3, "L"), (6, 4, "S")],
)
ARCHER_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(3, 3), hand_b=(-1, 4), weapon_ang=0)


def archer_anims():
    b = ARCHER
    atk = [
        replace(ARCHER_BASE, hand_f=(5, 1), hand_b=(2, 1), extra={"arrow": True, "draw": 1}),
        replace(ARCHER_BASE, hand_f=(5, 1), hand_b=(0, 1), lean=-1, extra={"arrow": True, "draw": 3}),
        replace(ARCHER_BASE, hand_f=(5, 1), hand_b=(-1, 1), lean=-1, extra={"draw": 0}),
        replace(ARCHER_BASE, hand_f=(4, 2), hand_b=(-1, 3), extra={"draw": 0}),
    ]
    return {
        "idle": dict(frames=std_idle(b, ARCHER_BASE), fps=4, loop=True),
        "walk": dict(frames=frames_of(b, walk_poses(ARCHER_BASE, 6, 3, 2, 1)), fps=10, loop=True),
        "attack": dict(frames=frames_of(b, atk), fps=10, loop=False, events={"hit": 2},
                       points={"projectile_spawn": [b.px + 11, b.H - 15]}),
        "hit": dict(frames=std_hit(b, ARCHER_BASE), fps=10, loop=False),
        "death": dict(frames=std_death(b, ARCHER_BASE), fps=8, loop=False),
    }


# ---------------------------------------------------------------------------
# TANK (unit_tank) - shieldbearer with tower shield + mace
# ---------------------------------------------------------------------------
TANK_HEAD = Sprite.parse("""
...mMMMm...
..mMNNNWm..
.mMMMNNNNm.
.mMMMMMMNm.
.mMMKKKKKm.
.mMMMMMMMm.
.mmMMMMMmm.
..mmmmmmm..
""")
TANK_TORSO = Sprite.parse("""
.mMNNNMm.
mMBBCCCNm
mBBBCCCcM
mBBBCCCCM
.wOOYYOw.
.bBBBCCb.
""")
SHIELD = Sprite.parse("""
.mNNNm.
mBCCCcN
mBCZCcN
mBYZYcN
mBCYCcN
mBCYCCN
mBBCCCM
.mBBCm.
..mmm..
""")


def mace(cv, hand, pose, body):
    tip = pole(cv, hand, pose.weapon_ang, 1, 6, shaft="O")
    cv.ellipse(tip[0] + 0.5, tip[1] + 0.5, 1.8, 1.8, c("M"))
    cv.put(round(tip[0]) - 1, round(tip[1]) - 1, c("N"))


def shield_front(cv, a, pose, body):
    x, y = a["hb"]
    dx = pose.extra.get("shield_dx", 0)
    cv.stamp(SHIELD, x + 3 + dx - (SHIELD.w - 7) // 2, y - 6 - (SHIELD.h - 9) // 2)   # 7x9 -> same as before


TANK = Body(
    W=32, H=32, px=13, head=TANK_HEAD, torso=TANK_TORSO, head_anchor=(-1, 0),
    shoulder_f=(6, 1), shoulder_b=(2, 1), leg_len=5, leg_t=3, leg_col="M", leg_shade="m", boot_col="w",
    arm_t=2, arm_col="M", arm_shade="m", hand_col="N", hip_w=1, weapon=mace,
    offhand=shield_front,
)
TANK_BASE = Pose(feet=((2, 0), (-2, 0)), hand_f=(1, 3), hand_b=(2, 4), weapon_ang=-100, weapon_behind=True)


def tank_anims():
    b = TANK
    atk = [
        replace(TANK_BASE, hand_f=(-1, -2), weapon_ang=-150, lean=-1),
        replace(TANK_BASE, hand_f=(3, 0), weapon_ang=-40, lean=1, extra={"shield_dx": 1}),
        replace(TANK_BASE, hand_f=(4, 3), weapon_ang=10, lean=1, bob=1, extra={"shield_dx": 1}),
        replace(TANK_BASE, hand_f=(2, 3), weapon_ang=-60),
    ]
    # QA-B024 (A1): heavier step, the body dips 2 px on each contact (bob 2,1,0) and the stride is 1 px longer
    walk = walk_poses(TANK_BASE, 6, 3, 1, 0)
    walk = [replace(p, bob=p.bob + (1, 1, 0, 1, 1, 0)[i]) for i, p in enumerate(walk)]
    return {
        "idle": dict(frames=std_idle(b, TANK_BASE, n=3), fps=3, loop=True),
        "walk": dict(frames=frames_of(b, walk), fps=8, loop=True),
        "attack": dict(frames=frames_of(b, atk), fps=9, loop=False, events={"hit": 2}),
        "hit": dict(frames=std_hit(b, TANK_BASE), fps=10, loop=False),
        "death": dict(frames=std_death(b, TANK_BASE), fps=8, loop=False),
    }


ALL.update({
    "worker": (WORKER, worker_anims),
    "melee_basic": (SPEARMAN, spearman_anims),
    "ranged_basic": (ARCHER, archer_anims),
    "tank": (TANK, tank_anims),
})
