"""Chibi humanoid rig for deterministic pixel animation (owner: 03-art).

A character = ASCII head + ASCII torso + line-drawn limbs + procedural weapon,
posed per frame by a Pose. All characters face RIGHT in source (engine flips
enemy faction with flip_h, INTERFACES.md §5.2).

Frame coordinate convention: frame W x H, pivot = (px, H-1) = ground point
under the feet. The feet outline row is H-1.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field, replace

from pixel import Canvas, Sprite, c, IDX


@dataclass
class Pose:
    bob: int = 0                 # +down whole upper body
    lean: int = 0                # torso/head x offset (+forward)
    head_dy: int = 0
    head_dx: int = 0
    feet: tuple = ((2, 0), (-2, 0))     # (front dx, lift), (back dx, lift) relative to pivot x
    hip_dx: int = 0
    hand_f: tuple = (2, 5)       # front hand offset from front shoulder
    hand_b: tuple = (-1, 5)      # back hand offset from back shoulder
    weapon_ang: float = 60.0     # degrees, 0 = right, 90 = down, -90 = up
    weapon_on: bool = True
    weapon_behind: bool = False
    cape: int = 0                # cape trailing amount
    crouch: int = 0              # legs bend: hip lowered by n, feet spread
    blink: bool = False
    extra: dict = field(default_factory=dict)


@dataclass
class Body:
    W: int
    H: int
    px: int
    head: Sprite
    torso: Sprite
    head_anchor: tuple           # (x in head sprite) that sits over torso x0, overlap rows
    shoulder_f: tuple            # (x, y) in torso sprite coords
    shoulder_b: tuple
    leg_len: int = 5
    leg_t: int = 2
    leg_col: str = "O"
    leg_shade: str = "w"
    boot_col: str = "w"
    arm_t: int = 2
    arm_col: str = "B"
    arm_shade: str = "b"
    hand_col: str = "S"
    hip_w: int = 1
    head_overlap: int = 1
    torso_overlap: int = 1       # torso bottom overlaps hip row
    cape_col: str | None = None
    cape_shade: str | None = None
    cape_len: int = 8
    weapon: callable = None      # fn(cv, hand_xy, pose, body)
    offhand: callable = None     # fn(cv, hand_xy, pose, body)  e.g. shield, drawn last
    back_item: callable = None   # fn(cv, anchors, pose, body)  drawn before everything
    blink_px: list = field(default_factory=list)  # [(x,y,key)] in head coords for blink
    outline: str = "K"
    boot_w: int = 1              # foot extends boot_w px forward of the ankle


def _hip(body: Body, pose: Pose):
    fy = body.H - 2
    hip_y = fy - body.leg_len + pose.bob + pose.crouch
    hip_x = body.px + pose.hip_dx
    return hip_x, hip_y


def anchors(body: Body, pose: Pose):
    hip_x, hip_y = _hip(body, pose)
    tw, th = body.torso.w, body.torso.h
    tx = hip_x - tw // 2 + pose.lean
    ty = hip_y - th + body.torso_overlap
    hx = tx + body.head_anchor[0] + pose.head_dx
    hy = ty - body.head.h + body.head_overlap + pose.head_dy
    sf = (tx + body.shoulder_f[0], ty + body.shoulder_f[1])
    sb = (tx + body.shoulder_b[0], ty + body.shoulder_b[1])
    hf = (sf[0] + pose.hand_f[0], sf[1] + pose.hand_f[1])
    hb = (sb[0] + pose.hand_b[0], sb[1] + pose.hand_b[1])
    return dict(hip=(hip_x, hip_y), torso=(tx, ty), head=(hx, hy), sf=sf, sb=sb, hf=hf, hb=hb,
                fy=body.H - 2)


def draw_leg(cv: Canvas, body: Body, hip, foot, back: bool):
    col = c(body.leg_shade if back else body.leg_col)
    sh = c(body.leg_shade)
    cv.thick_line(hip[0], hip[1], foot[0], foot[1] - 1, col, t=body.leg_t, shade=None if back else sh)
    boot = c(body.boot_col)
    # boot: forward-pointing foot, 2 px tall; boot_w=1 -> classic 3 px foot
    fx, fy = foot
    bw = getattr(body, "boot_w", 1)
    cv.hline(fx - 1, fx + bw, fy, boot)
    cv.hline(fx - 1, fx + bw - 1, fy - 1, boot)


def draw_arm(cv: Canvas, body: Body, sh, hand, back: bool):
    col = c(body.arm_shade if back else body.arm_col)
    cv.thick_line(sh[0], sh[1], hand[0], hand[1], col, t=body.arm_t,
                  shade=None if back else c(body.arm_shade))
    hc = c(body.hand_col)
    cv.put(hand[0], hand[1], hc)
    cv.put(hand[0], hand[1] - 1 if body.arm_t > 1 else hand[1], hc)


def draw_cape(cv: Canvas, body: Body, a, pose: Pose):
    if not body.cape_col:
        return
    col, shd = c(body.cape_col), c(body.cape_shade or body.cape_col)
    sx = a["sb"][0]
    top = a["sb"][1] - 1
    for i in range(body.cape_len):
        y = top + i
        # cape widens and trails backwards as it goes down
        trail = (i * (2 + pose.cape)) // body.cape_len
        x0 = sx - 1 - trail
        x1 = a["sf"][0] - 1 - trail // 2
        if x1 < x0:
            x1 = x0
        cv.hline(x0, x1, y, col)
        cv.put(x0, y, shd)
    # hem shading wave
    y = top + body.cape_len - 1
    trail = ((body.cape_len - 1) * (2 + pose.cape)) // body.cape_len
    for x in range(sx - 1 - trail, a["sf"][0] - trail // 2):
        if (x + pose.cape) % 3 == 0:
            cv.put(x, y, shd)


def render(body: Body, pose: Pose) -> Canvas:
    cv = Canvas(body.W, body.H)
    a = anchors(body, pose)
    hip_x, hip_y = a["hip"]
    fy = a["fy"]
    if body.back_item:
        body.back_item(cv, a, pose, body)
    draw_cape(cv, body, a, pose)
    # back arm + weapon behind
    draw_arm(cv, body, a["sb"], a["hb"], back=True)
    if body.weapon and pose.weapon_on and pose.weapon_behind:
        body.weapon(cv, a["hf"], pose, body)
    # legs
    (ffdx, fl), (bfdx, bl) = pose.feet
    draw_leg(cv, body, (hip_x - body.hip_w, hip_y), (body.px + bfdx, fy - bl), back=True)
    draw_leg(cv, body, (hip_x + body.hip_w, hip_y), (body.px + ffdx, fy - fl), back=False)
    # torso + head
    cv.stamp(body.torso, *a["torso"])
    cv.stamp(body.head, *a["head"])
    if pose.blink:
        for (x, y, k) in body.blink_px:
            cv.put(a["head"][0] + x, a["head"][1] + y, c(k))
    # front arm + weapon
    if body.weapon and pose.weapon_on and not pose.weapon_behind:
        body.weapon(cv, a["hf"], pose, body)
    draw_arm(cv, body, a["sf"], a["hf"], back=False)
    if body.offhand:
        body.offhand(cv, a, pose, body)
    cv.outline(c(body.outline))
    return cv


# ---------------------------------------------------------------------------
# weapon helpers (Bresenham-based so any angle stays crisp)
# ---------------------------------------------------------------------------
def _dir(ang):
    r = math.radians(ang)
    return math.cos(r), math.sin(r)


def blade(cv: Canvas, hand, ang, length, main="N", edge="M", guard="Y", hilt="O", tip="W", width=2, guard_w=1,
          start=1, pommel=True):
    dx, dy = _dir(ang)
    hx, hy = hand
    # hilt behind hand
    if pommel:
        cv.put(round(hx - dx * 2), round(hy - dy * 2), c(guard))
        cv.put(round(hx - dx), round(hy - dy), c(hilt))
    x0, y0 = hx + dx * start, hy + dy * start
    x1, y1 = hx + dx * (start + length), hy + dy * (start + length)
    horiz = abs(dx) >= abs(dy)
    ox, oy = (0, 1) if horiz else (1, 0)
    if width >= 2:
        cv.line(x0 + ox, y0 + oy, x1 + ox, y1 + oy, c(edge))
    cv.line(x0, y0, x1, y1, c(main))
    cv.put(round(x1), round(y1), c(tip))
    # cross guard perpendicular
    if guard_w:
        px_, py_ = -dy, dx
        for s in range(-guard_w, guard_w + 1):
            cv.put(round(x0 + px_ * s), round(y0 + py_ * s), c(guard))


def pole(cv: Canvas, hand, ang, back_len, fwd_len, shaft="o", shaft_dark="O", head=None):
    dx, dy = _dir(ang)
    hx, hy = hand
    x0, y0 = hx - dx * back_len, hy - dy * back_len
    x1, y1 = hx + dx * fwd_len, hy + dy * fwd_len
    cv.line(x0, y0, x1, y1, c(shaft))
    if head:
        head(cv, (x1, y1), ang)
    return (x1, y1)


def spear_head(cv, tip, ang, col="N", hi="W", dark="M"):
    """Leaf blade: dark collar, 2 widened rows, tapering point with highlight."""
    dx, dy = _dir(ang)
    x, y = tip
    px_, py_ = -dy, dx
    cv.put(round(x - dx), round(y - dy), c("y"))                 # brass collar on the shaft
    for i in range(0, 5):
        cx, cy = x + dx * i, y + dy * i
        cv.put(round(cx), round(cy), c(hi if i >= 3 else col))
        if i in (1, 2):
            cv.put(round(cx + px_), round(cy + py_), c(dark))
            cv.put(round(cx - px_), round(cy - py_), c(col))
