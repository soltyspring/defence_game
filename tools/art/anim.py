"""Generic animation builders on top of rig.py (owner: 03-art)."""
from __future__ import annotations

import math
from dataclasses import replace

import numpy as np

from pixel import Canvas, c
from rig import Body, Pose, render


def walk_feet(i, n, stride=3, lift=2):
    t = 2 * math.pi * i / n
    fdx = round(stride * math.cos(t))
    fl = max(0, round(lift * math.sin(t)))
    bdx = -fdx
    bl = max(0, round(lift * math.sin(t + math.pi)))
    return (fdx, fl), (bdx, bl)


def walk_poses(base: Pose, n=6, stride=3, lift=2, arm_swing=2, bob=True):
    out = []
    for i in range(n):
        f, b = walk_feet(i, n, stride, lift)
        t = 2 * math.pi * i / n
        sw = round(arm_swing * math.cos(t))
        # body is lowest when feet pass each other (contact) -> bob down on 0/half
        bb = 0
        if bob:
            bb = 1 if (i % (n // 2)) in (0,) else 0
        p = replace(base, feet=(f, b), bob=base.bob + bb,
                    hand_f=(base.hand_f[0] - sw, base.hand_f[1]),
                    hand_b=(base.hand_b[0] + sw, base.hand_b[1]),
                    cape=(i % 3))
        out.append(p)
    return out


def ground_fit(cv: Canvas, px: int):
    """Shift content so its lowest opaque row is H-1 and bbox centred on px."""
    ys, xs = np.nonzero(cv.a)
    if len(ys) == 0:
        return cv
    dy = (cv.h - 1) - ys.max()
    cx = (xs.min() + xs.max()) // 2
    dx = px - cx
    return cv.shift(int(dx), int(dy))


def death_frames(body: Body, hurt: Pose, kneel: Pose, dissolve=(5, 10, 14), fall_dir=-1):
    """hurt -> kneel -> lying (lossless 90deg rotation) -> ordered-dither dissolve."""
    f0 = render(body, hurt)
    f1 = render(body, kneel)
    lying = render(body, kneel)
    k = 3 if fall_dir < 0 else 1    # fall backwards (head to the left for right-facing)
    lying.rot90_about(body.px, body.H - 1, k=k)
    ground_fit(lying, body.px)
    frames = [f0, f1, lying]
    for d in dissolve:
        f = lying.copy()
        f.dissolve(d)
        frames.append(f)
    return frames


def frames_of(body: Body, poses, post=None):
    out = []
    for i, p in enumerate(poses):
        cv = render(body, p)
        if post:
            post(cv, i, p)
        out.append(cv)
    return out


def arc_swoosh(cv: Canvas, cx, cy, r, a0, a1, col_main="W", col_edge="c", thick=2):
    """Solid pixel slash crescent: annulus sector, outer ring col_main, inner col_edge.
    Drawn after outline (it is an effect, no outline). Angles in degrees, screen space."""
    lo, hi = min(a0, a1), max(a0, a1)
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r or d < r - thick - 0.5:
                continue
            a = math.degrees(math.atan2(dy, dx))
            if not (lo <= a <= hi or lo <= a + 360 <= hi or lo <= a - 360 <= hi):
                continue
            # taper: thinner toward the trailing end (a0)
            frac = (a - a0) / (a1 - a0) if a1 != a0 else 1
            if frac < 0:
                frac += 360 / abs(a1 - a0)
            if d < r - 1.0 and frac < 0.35:
                continue
            cv.put(x, y, c(col_main if d >= r - 1.0 else col_edge))
