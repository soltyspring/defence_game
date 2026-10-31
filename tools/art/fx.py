"""Combat FX, projectiles and shadows (owner: 03-art). Pivot = centre unless noted.
Projectiles are drawn pointing RIGHT (engine rotates/flips by velocity)."""
from __future__ import annotations

import math

import numpy as np

from pixel import Canvas, Sprite, c


def _cv(w, h):
    return Canvas(w, h)


def ring(cv, cx, cy, r, th, col, ry_scale=1.0):
    for y in range(cv.h):
        for x in range(cv.w):
            dx = (x + 0.5 - cx)
            dy = (y + 0.5 - cy) / ry_scale
            d = math.hypot(dx, dy)
            if r - th <= d <= r:
                cv.put(x, y, c(col))


def star(cv, cx, cy, r, col, diag_col=None):
    for i in range(-r, r + 1):
        cv.put(cx + i, cy, c(col))
        cv.put(cx, cy + i, c(col))
    if diag_col:
        d = max(1, r // 2)
        for i in range(-d, d + 1):
            cv.put(cx + i, cy + i, c(diag_col))
            cv.put(cx + i, cy - i, c(diag_col))


# --- projectiles -------------------------------------------------------------
# Readability rev (ART_AUDIT A21): shafts/bodies use light ramp values so the projectile
# separates from the dark-green hills it usually crosses (old brown arrow: dL* 0.2-10).
def proj_arrow():
    cv = _cv(14, 5)
    cv.hline(2, 10, 2, c("U"))
    cv.put(11, 2, c("N")); cv.put(12, 2, c("W")); cv.put(10, 1, c("N")); cv.put(10, 3, c("N"))
    cv.put(1, 1, c("W")); cv.put(0, 1, c("J")); cv.put(1, 3, c("W")); cv.put(0, 3, c("J")); cv.put(2, 1, c("W"))
    cv.outline(c("K"))
    return {"fly": dict(frames=[cv], fps=1, loop=True)}


def proj_tower():
    cv = _cv(16, 5)
    cv.hline(1, 12, 2, c("T"))
    cv.hline(2, 11, 1, c("U"))
    cv.put(13, 2, c("N")); cv.put(14, 2, c("W")); cv.put(12, 1, c("N")); cv.put(12, 3, c("N"))
    cv.put(0, 1, c("c")); cv.put(0, 3, c("c")); cv.put(1, 1, c("C")); cv.put(1, 3, c("C"))
    cv.outline(c("K"))
    return {"fly": dict(frames=[cv], fps=1, loop=True)}


def proj_spit():
    frames = []
    for i in range(3):
        cv = _cv(10, 8)
        rx = [3.2, 3.6, 3.0][i]
        ry = [2.6, 2.2, 2.8][i]
        cv.ellipse(5, 4, rx, ry, c("f"))
        cv.ellipse(5.5, 3.5, rx - 1, ry - 0.8, c("Z"))
        cv.put(6, 2, c("W"))
        cv.put(1, 4 + (i % 2), c("Z"))
        cv.outline(c("K"))
        frames.append(cv)
    return {"fly": dict(frames=frames, fps=10, loop=True)}


def proj_boulder():
    base = Sprite.parse("""
..XxxX..
.XxxJxX.
XxxJJxxX
XXxxxxXX
AXXxxXXA
.AXXXXA.
..AAAA..
""")
    frames = []
    for k in range(4):
        cv = _cv(10, 10)
        a = np.rot90(base.a, k=-k)
        cv.stamp(Sprite(a), 1 + (k % 2 == 1 and 0), 1)
        cv.outline(c("K"))
        frames.append(cv)
    return {"fly": dict(frames=frames, fps=12, loop=True)}


# --- impacts -----------------------------------------------------------------
def hit_spark():
    frames = []
    for i in range(5):
        cv = _cv(16, 16)
        if i == 0:
            star(cv, 8, 8, 2, "W")
        elif i == 1:
            star(cv, 8, 8, 5, "W", "Z")
            cv.put(8, 8, c("Z"))
        elif i == 2:
            star(cv, 8, 8, 7, "Z", "W")
            cv.rect(7, 7, 3, 3, c("W"))
        elif i == 3:
            for (dx, dy) in [(-6, 0), (6, 0), (0, -6), (0, 6), (-4, -4), (4, 4), (4, -4), (-4, 4)]:
                cv.put(8 + dx, 8 + dy, c("e"))
                cv.put(8 + dx * 5 // 6, 8 + dy * 5 // 6, c("Z"))
        else:
            for (dx, dy) in [(-7, 0), (7, 0), (0, -7), (0, 7)]:
                cv.put(8 + dx, 8 + dy, c("e"))
        frames.append(cv)
    return {"play": dict(frames=frames, fps=20, loop=False)}


def hit_spit():
    frames = []
    for i in range(4):
        cv = _cv(16, 16)
        r = 2 + i * 2
        for a in range(0, 360, 45):
            x = 8 + round(math.cos(math.radians(a + i * 10)) * r)
            y = 8 + round(math.sin(math.radians(a + i * 10)) * r * 0.8)
            cv.put(x, y, c("F" if i < 2 else "G"))
            if i < 2:
                cv.put(x + 1, y, c("f"))
        if i < 2:
            cv.ellipse(8, 8, 3 - i, 2.5 - i, c("F"))
        frames.append(cv)
    return {"play": dict(frames=frames, fps=16, loop=False)}


def explosion():
    """Readability rev (ART_AUDIT A20): hollow burst. Ring + rays, transparent core after
    frame 0, so the hit target stays visible (opaque-disc version covered 100 %)."""
    frames = []
    for i in range(7):
        cv = _cv(40, 40)
        cx, cy = 20, 22
        if i == 0:
            cv.ellipse(cx, cy, 4, 3.5, c("Z"))
            cv.ellipse(cx, cy, 2, 1.8, c("W"))
        elif i <= 3:
            r = [0, 8, 12, 15][i]
            ring(cv, cx, cy, r, 2, "e" if i < 3 else "E", ry_scale=0.85)
            ring(cv, cx, cy, r - 2, 1, "Z" if i < 3 else "e", ry_scale=0.85)
            for a in range(0, 360, 45):          # short rays outside the ring
                for t in (1, 2):
                    x = cx + round(math.cos(math.radians(a + 20 * i)) * (r + t))
                    y = cy + round(math.sin(math.radians(a + 20 * i)) * (r + t) * 0.85)
                    cv.put(x, y, c("Z" if t == 1 else "e"))
        else:
            # dithered smoke wisps on the rim only
            for (dx, dy) in [(-12, -4), (11, -6), (0, -14), (-8, 8), (12, 6)]:
                cv.ellipse(cx + dx, cy + dy - (i - 4) * 2, 3 - (i - 4) * 0.6, 2.5 - (i - 4) * 0.5, c("X"))
            cv.dissolve(6 + (i - 4) * 4)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=16, loop=False)}


def death_poof():
    frames = []
    for i in range(5):
        cv = _cv(24, 24)
        for (dx, dy, s) in [(-5, 2, 1.0), (5, 2, 1.0), (0, -3, 1.2), (-2, 5, 0.8), (3, 5, 0.8)]:
            r = (3 + i * 1.4) * s
            cv.ellipse(12 + dx * (1 + i * 0.25), 14 + dy - i, r, r * 0.8, c("x" if i < 3 else "X"))
            cv.ellipse(12 + dx * (1 + i * 0.25) - 1, 13 + dy - i, r * 0.6, r * 0.5, c("J"))
        if i >= 2:
            cv.dissolve((i - 1) * 4)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=14, loop=False)}


def dust_puff():
    frames = []
    for i in range(4):
        cv = _cv(16, 10)
        for dx in (-4, 0, 4):
            cv.ellipse(8 + dx * (1 + i * 0.3), 7 - i * 0.6, 1.8 + i * 0.5, 1.5 + i * 0.4, c("T" if i < 2 else "o"))
        if i >= 2:
            cv.dissolve(i * 4)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=14, loop=False)}


# --- skills ------------------------------------------------------------------
def fx_slam():
    """Ground shockwave: pivot bottom-centre (32, 31)."""
    frames = []
    for i in range(6):
        cv = _cv(64, 32)
        gy = 30
        r = 6 + i * 5
        ring(cv, 32, gy, r, 2, "Z" if i < 2 else ("e" if i < 4 else "T"), ry_scale=0.3)
        ring(cv, 32, gy, max(1, r - 3), 1, "W" if i < 3 else "o", ry_scale=0.3)
        # flying rock chips
        for k, dx in enumerate((-1, 1)):
            for j in range(3):
                x = 32 + dx * (4 + j * 5 + i * 3)
                y = gy - 2 - int(6 * math.sin(math.pi * min(1, (i + j * 0.4) / 5))) - j
                if i < 5:
                    cv.put(x, y, c("X"))
                    cv.put(x, y - 1, c("x"))
        # crack lines in ground
        if i >= 1:
            for dx in (-1, 1):
                x, y = 32, gy
                for s in range(min(14, 4 + i * 3)):
                    cv.put(x, y, c("a"))
                    x += dx * 2
                    y += (s % 3 == 0) * (1 if s % 2 else -1)
        if i == 5:
            cv.dissolve(8)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=14, loop=False)}


def fx_rally():
    """Gold aura with rising chevrons around an ally, pivot bottom-centre (16, 39). Loops."""
    frames = []
    for i in range(6):
        cv = _cv(32, 40)
        ring(cv, 16, 38, 12 + (i % 3), 1, "Y", ry_scale=0.3)
        for k, x in enumerate((6, 16, 26)):
            y = 34 - ((i * 5 + k * 9) % 30)
            cv.put(x, y, c("Z"))
            cv.put(x - 1, y + 1, c("Y"))
            cv.put(x + 1, y + 1, c("Y"))
            cv.put(x - 2, y + 2, c("y"))
            cv.put(x + 2, y + 2, c("y"))
        frames.append(cv)
    return {"loop": dict(frames=frames, fps=10, loop=True)}


def fx_barrage():
    """Volley of falling bolts that converge on the target, pivot bottom-centre (24, 63)."""
    frames = []
    for i in range(6):
        cv = _cv(48, 64)
        for k, x0 in enumerate((8, 18, 26, 34, 42)):
            y = -10 + i * 12 + (k % 2) * 6
            x = x0 - i * 2
            if y < 56:
                cv.line(x, y, x + 2, y + 8, c("o"))
                cv.put(x + 3, y + 9, c("W"))
                cv.put(x - 1, y, c("C"))
        if i >= 4:
            ring(cv, 24, 62, 8 + (i - 4) * 8, 2, "e", ry_scale=0.3)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=12, loop=False)}


def fx_spawn():
    """Blue light pillar for deploy, pivot bottom-centre (12, 39)."""
    frames = []
    for i in range(5):
        cv = _cv(24, 40)
        w = [2, 6, 8, 6, 3][i]
        for y in range(0, 39):
            for x in range(12 - w // 2, 12 + (w + 1) // 2):
                if (y + i) % 3 or w < 4:
                    cv.put(x, y, c("c" if abs(x - 11.5) < w / 4 else "C"))
        ring(cv, 12, 38, 4 + i * 2, 1, "C", ry_scale=0.35)
        if i == 4:
            cv.dissolve(8)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=14, loop=False)}


def fx_heal():
    frames = []
    for i in range(6):
        cv = _cv(16, 24)
        for k, x in enumerate((3, 8, 12)):
            y = 20 - ((i * 4 + k * 7) % 20)
            cv.put(x, y, c("f"))
            cv.put(x - 1, y, c("F")); cv.put(x + 1, y, c("F")); cv.put(x, y - 1, c("F")); cv.put(x, y + 1, c("F"))
        frames.append(cv)
    return {"loop": dict(frames=frames, fps=10, loop=True)}


def fx_fire():
    """Small looping flame for damaged bases, pivot bottom-centre (6, 15)."""
    frames = []
    for i in range(4):
        cv = _cv(12, 16)
        h = [10, 12, 11, 13][i]
        sway = [0, 1, 0, -1][i]
        for y in range(16 - h, 16):
            t = (y - (16 - h)) / h
            w = 1 + int(t * 4)
            cx = 6 + round(sway * (1 - t))
            for x in range(cx - w, cx + w):
                k = "Z" if t > 0.55 and abs(x - cx + 0.5) < w * 0.4 else ("e" if t > 0.3 else "E")
                if t < 0.15:
                    k = "R"
                cv.put(x, y, c(k))
        frames.append(cv)
    return {"loop": dict(frames=frames, fps=10, loop=True)}


def coin():
    widths = [5, 4, 2, 1, 2, 4]
    frames = []
    for w in widths:
        cv = _cv(12, 12)
        cv.ellipse(6, 6, w + 0.2, 5, c("Y"))
        if w >= 2:
            cv.ellipse(6 - 0.5, 5.5, max(0.6, w - 1.5), 3.5, c("Z"))
            cv.vline(6, 4, 7, c("y"))
        cv.outline(c("y"))
        frames.append(cv)
    return {"loop": dict(frames=frames, fps=12, loop=True)}


def shadows():
    out = {}
    for name, (w, h) in {"shadow_s": (14, 5), "shadow_m": (20, 6), "shadow_l": (34, 8), "shadow_xl": (90, 12)}.items():
        cv = _cv(w, h)
        cv.ellipse(w / 2, h / 2, w / 2, h / 2, c("_"))
        out[name] = cv
    # faction ground markers (opaque 1 px ring arcs, front half only) so allies and enemies
    # stay separable when they overlap in melee; drawn under the unit, over the shadow.
    for faction, (col, hi) in {"ally": ("C", "c"), "enemy": ("E", "e")}.items():
        for size, (w, h) in {"s": (14, 5), "m": (20, 6), "l": (34, 8)}.items():
            cv = _cv(w, h)
            ring(cv, w / 2, h / 2, w / 2, 1.2, col, ry_scale=h / w)
            cv.a[: h // 2, :] = 0                 # keep only the front (lower) half
            cv.put(w // 2, h - 1, c(hi))
            out[f"marker_{faction}_{size}"] = cv
    return out


SETS = {
    # id: (fn, frame_w, frame_h, pivot)
    "arrow": (proj_arrow, 14, 5, (7, 2)),
    "tower_bolt": (proj_tower, 16, 5, (8, 2)),
    "spit": (proj_spit, 10, 8, (5, 4)),
    "rock": (proj_boulder, 10, 10, (5, 5)),
    "hit_spark": (hit_spark, 16, 16, (8, 8)),
    "hit_spit": (hit_spit, 16, 16, (8, 8)),
    "explosion": (explosion, 40, 40, (20, 22)),
    "death_poof": (death_poof, 24, 24, (12, 20)),
    "dust": (dust_puff, 16, 10, (8, 9)),
    "skill_slam": (fx_slam, 64, 32, (32, 31)),
    "skill_rally": (fx_rally, 32, 40, (16, 39)),
    "skill_barrage": (fx_barrage, 48, 64, (24, 63)),
    "spawn": (fx_spawn, 24, 40, (12, 39)),
    "heal": (fx_heal, 16, 24, (8, 23)),
    "fire": (fx_fire, 12, 16, (6, 15)),
    "coin": (coin, 12, 12, (6, 6)),
}


# =============================================================================
# art-world 1 (09-art-world, 2026-11-01, docs/art/world/WORLD_AUDIT.md P5): impacts that do not hide the unit.
# Same frame sizes, pivots, frame counts and fps as before. hit_spark: hollow burst (no filled centre, no rays straight
# up/down where they would lie on the body), thin rays from radius 3 outward, orange inner end + pale-gold tip so it
# reads on cream bread AND on grey mould. explosion: one dashed 1 px ring with short rays outside it, a 3 px flash only
# in frame 0, rim-only smoke.
# =============================================================================
_DIRS8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]


def hit_spark_v2():
    frames = []
    H6 = [(1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)]       # no straight up/down: those rays lie on the body
    D4 = [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    spec = [  # (directions, inner radius, outer radius, inner key, outer key)
        (D4, 2, 2, "Z", "Z"),
        (H6, 3, 4, "e", "Z"),
        (H6, 5, 6, "e", "Z"),
        (D4, 6, 6, "e", "e"),
        ([(1, 0), (-1, 0)], 7, 7, "e", "e"),
    ]
    for dirs, r0, r1, k0, k1 in spec:
        cv = _cv(16, 16)
        for (dx, dy) in dirs:
            diag = dx != 0 and dy != 0
            for r in range(r0, r1 + 1):
                rr = r - 1 if diag else r            # diagonals one step shorter (same visual length)
                if rr < 1:
                    continue
                cv.put(8 + dx * rr, 8 + dy * rr, c(k1 if r == r1 else k0))
        frames.append(cv)
    return {"play": dict(frames=frames, fps=20, loop=False)}


def explosion_v2():
    frames = []
    for i in range(7):
        cv = _cv(40, 40)
        cx, cy = 20, 22
        if i == 0:
            cv.ellipse(cx, cy, 3, 2.6, c("Z"))
            cv.put(cx, cy, c("W"))
        elif i <= 3:
            r = [0, 8, 12, 15][i]
            for a in range(0, 360, 4):                # dashed ring: 2 of every 3 steps
                if (a // 4) % 3 == 2:
                    continue
                x = cx + round(math.cos(math.radians(a)) * r)
                y = cy + round(math.sin(math.radians(a)) * r * 0.85)
                cv.put(x, y, c("E" if i < 3 else "e"))
            for a in range(0, 360, 45):               # short rays outside the ring
                for t in (1, 2):
                    x = cx + round(math.cos(math.radians(a + 20 * i)) * (r + t))
                    y = cy + round(math.sin(math.radians(a + 20 * i)) * (r + t) * 0.85)
                    cv.put(x, y, c("Z" if t == 1 else "e"))
        else:
            for (dx, dy) in [(-13, -4), (12, -7), (1, -15)]:
                cv.ellipse(cx + dx, cy + dy - (i - 4) * 2, 2.6 - (i - 4) * 0.5, 2.0 - (i - 4) * 0.4, c("X"))
            cv.dissolve(6 + (i - 4) * 4)
        frames.append(cv)
    return {"play": dict(frames=frames, fps=16, loop=False)}


hit_spark_v1, explosion_v1 = hit_spark, explosion
SETS["hit_spark"] = (hit_spark_v2, 16, 16, (8, 8))
SETS["explosion"] = (explosion_v2, 40, 40, (20, 22))
