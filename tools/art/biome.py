"""Layered battlefield backgrounds (owner: 03-art). Every layer is 640 px wide and
horizontally seamless (period 640) so the engine can repeat it with Parallax2D
repeat_size=(640,0) without texture repeat (atlas regions stay repeat=off).
Positions are in the 640x360 reference view (y = top of layer).
"""
from __future__ import annotations

import math

import numpy as np

from pixel import Canvas, c

PERIOD = 640


def wrap_noise(rng, cells, period=PERIOD):
    """Periodic 1-D value noise with smoothstep interpolation."""
    vals = rng.uniform(-1, 1, cells)

    def f(x):
        u = (x % period) / period * cells
        i = int(math.floor(u)) % cells
        j = (i + 1) % cells
        t = u - math.floor(u)
        t = t * t * (3 - 2 * t)
        return vals[i] * (1 - t) + vals[j] * t
    return f


def sky_strip(meta):
    """16 x 360 banded gradient with 2-px-period ordered-dither transitions.
    Draw by REPEATING horizontally (Parallax2D repeat_size=(16,0) or region
    tiling); stretching also works but smears the dither rows."""
    cv = Canvas(16, 360)
    bands = [(0, "i"), (96, "I"), (176, "j"), (226, "J")]
    for y in range(360):
        k = bands[0][1]
        prev = None
        for (y0, kk) in bands:
            if y >= y0:
                prev, k = k, kk
        cv.hline(0, 15, y, c(k))
        # dither 8 rows above each band start: alternate previous colour
        for bi, (y0, kk) in enumerate(bands[1:], 1):
            pk = bands[bi - 1][1]
            if y0 - 8 <= y < y0:
                d = y0 - y      # 8..1
                for x in range(16):
                    if (d > 4 and (x + y) % 4 == 0) or (d <= 4 and (x + y) % 2 == 0):
                        cv.put(x, y, c(kk))
    meta.update(view_y=0, parallax=0.0, repeat_x=16, clear_color="#3b5aa8")
    return cv


def far_layer(meta, seed=11):
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 150
    cv = Canvas(W, H)
    # clouds (sparse, wrap around)
    for k in range(7):
        cx = int(rng.integers(0, W))
        cy = int(rng.integers(8, 50))
        n = int(rng.integers(3, 6))
        for j in range(n):
            ox = int(rng.integers(-14, 15))
            oy = int(rng.integers(-3, 4))
            rx = float(rng.uniform(7, 14))
            ry = rx * 0.45
            for dx in (-W, 0, W):
                cv.ellipse(cx + ox + dx, cy + oy, rx, ry, c("J"))
        for dx in (-W, 0, W):
            cv.hline(cx - 18 + dx, cx + 18 + dx, cy + 4, c("j"))
    # far range (light, snow caps)
    n1 = wrap_noise(rng, 10)
    n2 = wrap_noise(rng, 40)
    for x in range(W):
        h = 70 + 26 * n1(x) + 7 * n2(x)
        top = int(H - h)
        for y in range(max(0, top), H):
            k = "u"
            if y < top + 4 and n1(x) > 0.2:
                k = "J"
            elif (x + y) % 2 == 0 and y < top + 6 and n1(x) > 0.2:
                k = "j"
            cv.put(x, y, c(k))
        # light from left: ridge shading
        if n1(x + 1) > n1(x):
            cv.put(x, top + 6, c("n"))
    # near range (darker)
    n3 = wrap_noise(rng, 7)
    n4 = wrap_noise(rng, 32)
    for x in range(W):
        h = 42 + 18 * n3(x) + 5 * n4(x)
        top = int(H - h)
        for y in range(max(0, top), H):
            k = "n"
            if y == top:
                k = "u"
            cv.put(x, y, c(k))
    # distant forest band at the bottom
    n5 = wrap_noise(rng, 64)
    for x in range(W):
        top = int(H - 14 - 4 * n5(x) - 2 * ((x * 7) % 5 == 0))
        for y in range(top, H):
            cv.put(x, y, c("d"))
    meta.update(view_y=100, parallax=0.15)
    return cv


def tree(cv: Canvas, x, base_y, size, dark="g", mid="G", hi="F", trunk="w"):
    cv.rect(x - 1, base_y - size, 2, size, c(trunk))
    r = size * 0.75
    cy = base_y - size - r * 0.4
    cv.ellipse(x, cy, r, r * 0.85, c(dark))
    cv.ellipse(x - r * 0.15, cy - r * 0.15, r * 0.8, r * 0.7, c(mid))
    cv.ellipse(x - r * 0.35, cy - r * 0.35, r * 0.4, r * 0.35, c(hi))


def mid_layer(meta, seed=22):
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 120
    cv = Canvas(W, H)
    n1 = wrap_noise(rng, 6)
    n2 = wrap_noise(rng, 24)
    tops = []
    for x in range(W):
        top = int(52 - 16 * n1(x) - 4 * n2(x))
        tops.append(top)
        for y in range(top, H):
            k = "G"
            if y < top + 2:
                k = "F"
            cv.put(x, y, c(k))
    # dithered darker band low on the hills for depth
    for x in range(W):
        for y in range(tops[x] + 18, H):
            if (x + y) % 2 == 0 or y > tops[x] + 26:
                cv.put(x, y, c("g") if y > tops[x] + 26 else c("G"))
    # tree clusters (wrap-aware)
    for k in range(16):
        x = int(rng.integers(0, W))
        size = int(rng.integers(5, 10))
        for dx in (-W, 0, W):
            xx = x + dx
            if -20 < xx < W + 20:
                tree(cv, xx, tops[x % W] + 6, size)
    # fences / posts low
    for x in range(0, W, 32):   # 640/32 = 20 posts -> periodic
        y = tops[x] + 30
        cv.rect(x, y - 5, 1, 6, c("w"))
    meta.update(view_y=180, parallax=0.45)
    return cv


def ground_layer(meta, seed=33):
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 80
    cv = Canvas(W, H)
    ng = wrap_noise(rng, 80)
    LANE = 15   # feet line inside the layer (middle of the dirt lane rows 9..22)
    for x in range(W):
        gtop = int(2 + 2 * ng(x))
        for y in range(gtop, H):
            if y < 7:
                k = "F" if y > gtop else "f"
            elif y < 9:
                k = "G"
            elif y < 22:
                k = "o"          # packed-dirt lane
            elif y < 24:
                k = "O"
            elif y < 46:
                k = "O"
            else:
                k = "w"
            cv.put(x, y, c(k))
        # grass blades poking up
        if (x * 13 + 5) % 7 == 0:
            cv.put(x, gtop - 1, c("F"))
        if (x * 29 + 3) % 11 == 0:
            cv.put(x, gtop - 2, c("f"))
    # lane texture: wheel ruts + pebbles (wrap-aware)
    for x in range(W):
        if (x // 3) % 5 != 0:
            cv.put(x, 15, c("O") if (x % 9) else c("T"))
        if (x // 4) % 7 != 0:
            cv.put(x, 19, c("O"))
    for _ in range(140):
        x = int(rng.integers(0, W))
        y = int(rng.integers(10, 21))
        cv.put(x, y, c("T"))
        cv.put((x + 1) % W, y, c("O"))
    # soil strata and stones
    for _ in range(70):
        x = int(rng.integers(0, W))
        y = int(rng.integers(26, 76))
        w = int(rng.integers(2, 6))
        for i in range(w):
            cv.put((x + i) % W, y, c("A" if y < 46 else "O"))
            cv.put((x + i) % W, y - 1, c("X" if y < 46 else "o"))
    # grass to dirt dithered edge
    for x in range(W):
        if x % 2 == 0:
            cv.put(x, 9, c("o"))
        if x % 4 == 1:
            cv.put(x, 22, c("O"))
            cv.put(x, 23, c("o"))
    meta.update(view_y=280, parallax=1.0, tile=True, lane_line=LANE,
                note="layer row 15 is the feet line: place layer at view_y = ground_y - 15")
    return cv


def front_layer(meta, seed=44):
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 18
    cv = Canvas(W, H)
    for _ in range(90):
        x = int(rng.integers(0, W))
        h = int(rng.integers(3, 9))
        for i in range(h):
            for dx in (0, W, -W):
                cv.put(x + dx + (1 if i > h - 3 else 0), H - 1 - i, c("G" if i < h - 2 else "F"))
                cv.put(x + dx - 1, H - 1 - i // 2, c("g"))
    for _ in range(18):
        x = int(rng.integers(2, W - 2))
        y = int(rng.integers(H - 9, H - 4))
        col = ["Z", "e", "v", "J"][int(rng.integers(0, 4))]
        cv.put(x, y, c(col))
        cv.put(x - 1, y + 1, c(col))
        cv.put(x + 1, y + 1, c(col))
        cv.put(x, y + 1, c("Y"))
    meta.update(view_y=342, parallax=1.15, tile=True, z="front")
    return cv


MEADOW = [
    ("sky", sky_strip),
    ("far", far_layer),
    ("mid", mid_layer),
    ("ground", ground_layer),
    ("front", front_layer),
]


# =============================================================================
# art 0.11.0: biome_01 "밀밭 빵집 마을 / Wheatfield Village" (01 WORLD.md), QA-J1 / 09 X10.
# Same 5 layer frames and sizes as the meadow (sky 16x360, far 640x150, mid 640x120,
# ground 640x80 lane_line 15, front 640x18), so the atlas page and 02's draw code are
# unchanged. The far layer moves up (view_y 100 -> 50) and the street fills the band
# above the lane, so the visible sky drops from ~half of the view to ~a quarter.
# Lane band and the band behind unit heads stay at L* >= 35 (ART_AUDIT dark-biome rule).
# =============================================================================
class WrapCanvas(Canvas):
    """Canvas whose x coordinate wraps (period = width): every layer stays seamless."""
    def put(self, x, y, col):
        if 0 <= y < self.h:
            self.a[y, int(x) % self.w] = col

    def rect(self, x, y, w, h, col):
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(x, x + w):
                self.a[yy, xx % self.w] = col

    def get(self, x, y):
        if 0 <= y < self.h:
            return int(self.a[y, int(x) % self.w])
        return 0


def village_sky(meta):
    """Morning sky, warmer and shorter than the meadow sky (most of it is hidden by the village)."""
    cv = Canvas(16, 360)
    bands = [(0, "i"), (40, "I"), (80, "j"), (112, "J")]
    for y in range(360):
        k = [kk for (y0, kk) in bands if y >= y0][-1]
        cv.hline(0, 15, y, c(k))
        for bi, (y0, kk) in enumerate(bands[1:], 1):
            if y0 - 6 <= y < y0:
                d = y0 - y
                for x in range(16):
                    if (d > 3 and (x + y) % 4 == 0) or (d <= 3 and (x + y) % 2 == 0):
                        cv.put(x, y, c(kk))
    meta.update(view_y=0, parallax=0.0, repeat_x=16, clear_color="#3b5aa8")
    return cv


def _windmill(cv, x, base, h):
    cv.rect(x - 3, base - h, 7, h, c("U"))
    cv.vline(x + 3, base - h, base - 1, c("x"))
    for yy in range(base - h - 4, base - h):
        w = (yy - (base - h - 4)) + 1
        cv.hline(x - w, x + w, yy, c("R"))
    cv.put(x, base - 4, c("o")); cv.put(x, base - 5, c("o"))
    hy = base - h - 1
    for (dx, dy) in [(1, -1), (-1, 1), (1, 1), (-1, -1)]:
        for t in range(1, 9):
            cv.put(x + dx * t, hy + dy * t, c("O" if t < 8 else "T"))
            if t > 3:
                cv.put(x + dx * t + (1 if dy == dx else 0), hy + dy * t + (0 if dy == dx else 1), c("U"))
    cv.put(x, hy, c("w"))


def village_far(meta, seed=111):
    """Wheat-field hills with a distant village row and a windmill (parallax 0.15)."""
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 150
    cv = WrapCanvas(W, H)
    for k in range(5):                              # a few clouds in the remaining sky
        cx, cy = int(rng.integers(0, W)), int(rng.integers(6, 24))
        for j in range(int(rng.integers(3, 5))):
            rx = float(rng.uniform(6, 11))
            cv.ellipse(cx + int(rng.integers(-10, 11)), cy + int(rng.integers(-2, 3)), rx, rx * 0.42, c("J"))
        cv.hline(cx - 14, cx + 14, cy + 3, c("j"))
    n1, n2 = wrap_noise(rng, 5), wrap_noise(rng, 23)
    tops = []
    n3 = wrap_noise(rng, 9)
    for x in range(W):
        top = int(44 - 10 * n1(x) - 3 * n2(x))
        tops.append(top)
        for y in range(top, H):
            d = y - top
            k = "U" if d < 2 else "T"
            if d >= 2 and (x * 7 + y * 13) % 29 == 0:
                k = "Z"
            cv.put(x, y, c(k))
    # field strips separated by hedgerows that follow the hills (wider strips nearer the viewer)
    for x in range(W):
        y = tops[x]
        for gap in (12, 18, 26, 36):
            y += gap
            yy = int(y + 3 * n3(x + gap * 11))
            if yy < H:
                cv.put(x, yy, c("G" if (x // 2) % 5 else "F"))
                if gap >= 26:
                    cv.put(x, yy - 1, c("F") if (x % 3 == 0) else c("G"))
            for f in (4, 8):
                if (x + f) % 4 == 0 and yy - f > tops[x] + 2:
                    cv.put(x, yy - f, c("Y"))
    for _ in range(26):                                 # haystacks and round trees in the fields
        x = int(rng.integers(0, W))
        y = tops[x] + int(rng.integers(14, 90))
        if y + 3 >= H:
            continue
        if rng.uniform() < 0.55:
            cv.ellipse(x, y, 3.2, 2.4, c("Y")); cv.hline(x - 2, x + 1, y - 2, c("Z")); cv.hline(x - 3, x + 3, y + 2, c("y"))
        else:
            cv.rect(x, y - 1, 1, 4, c("w"))
            cv.ellipse(x, y - 4, 3.4, 3.0, c("G")); cv.ellipse(x - 1, y - 5, 1.8, 1.4, c("F"))
    # distant village row on the hill line
    x = 0
    while x < W:
        w = int(rng.integers(7, 13))
        if rng.uniform() < 0.8:
            t = min(tops[(x + i) % W] for i in range(w)) + 1
            hh = int(rng.integers(5, 9))
            cv.rect(x, t - hh, w, hh + 3, c("U"))
            for yy in range(4):
                cv.hline(x - 1 + yy, x + w - yy, t - hh - 1 - yy, c("R" if yy else "r"))
            if rng.uniform() < 0.5:
                cv.put(x + 2, t - hh + 2, c("y")); cv.put(x + w - 3, t - hh + 2, c("y"))
        x += w + int(rng.integers(1, 9))
    for wx in (150, 470):
        _windmill(cv, wx, tops[wx] + 2, 18)
    meta.update(view_y=50, parallax=0.15)
    return cv


def _house(cv, rng, x0, w, wall_top, shop):
    H = cv.h
    wall = ["U", "x", "U", "J"][int(rng.integers(0, 4))]
    cv.rect(x0, wall_top, w, H - wall_top, c(wall))
    cv.vline(x0, wall_top, H - 1, c("X" if wall != "U" else "T"))         # left edge shade
    if rng.uniform() < 0.45:                                               # half-timber beams (upper floor only)
        cv.hline(x0, x0 + w - 1, wall_top + 1, c("o"))
        for bx in range(x0 + 4, x0 + w - 2, 9):
            cv.vline(bx, wall_top + 1, wall_top + 26, c("o"))
        cv.hline(x0, x0 + w - 1, wall_top + 26, c("o"))
    # gable roof (light from the left)
    rh = int(rng.integers(9, 15))
    roof, dark, hi = [("R", "r", "E"), ("o", "O", "T"), ("R", "r", "E")][int(rng.integers(0, 3))]
    for i in range(rh + 1):
        y = wall_top - 1 - i
        a, b = x0 - 2 + i, x0 + w + 1 - i
        if a > b:
            break
        cv.hline(a, b, y, c(roof))
        cv.put(a, y, c(hi))
        cv.put(b, y, c(dark))
    cv.hline(x0 - 2, x0 + w + 1, wall_top - 1, c(dark))
    if rng.uniform() < 0.7:                                                # chimney + morning oven smoke
        cx = x0 + int(rng.integers(3, max(4, w - 6)))
        cy = wall_top - rh + 2
        cv.rect(cx, cy - 6, 4, 8, c("X")); cv.hline(cx - 1, cx + 4, cy - 7, c("A"))
        for k in range(3):
            cv.ellipse(cx + 2 - k * 3, cy - 11 - k * 4, 2.2 + k * 0.6, 1.6 + k * 0.4, c("J" if k else "x"))
    # upper windows: warm lit panes (ovens are on at dawn)
    for wx in range(x0 + 4, x0 + w - 6, 11):
        wy = wall_top + 8
        cv.rect(wx, wy, 6, 7, c("O"))
        cv.rect(wx + 1, wy + 1, 4, 5, c("Z"))
        cv.vline(wx + 3, wy + 1, wy + 5, c("O")); cv.hline(wx + 1, wx + 4, wy + 3, c("O"))
        cv.hline(wx, wx + 5, wy + 7, c("F")); cv.put(wx + 1, wy + 6, c("E")); cv.put(wx + 4, wy + 6, c("e"))
    if shop:
        # awning (jam/cream stripes) over the shop window, bread on display
        ay = wall_top + 36
        for xx in range(x0 + 1, x0 + w - 1):
            k = "R" if ((xx - x0) // 3) % 2 == 0 else "U"
            cv.vline(xx, ay, ay + 4, c(k))
            if (xx - x0) % 3 == 1:
                cv.put(xx, ay + 5, c(k))
        sw = w - 16
        cv.rect(x0 + 3, ay + 7, sw, 17, c("O"))
        cv.rect(x0 + 4, ay + 8, sw - 2, 14, c("Z"))
        for bx in range(x0 + 6, x0 + 3 + sw - 5, 6):
            cv.ellipse(bx + 2, ay + 19, 2.6, 1.6, c("T")); cv.hline(bx + 1, bx + 3, ay + 18, c("U"))
        cv.hline(x0 + 3, x0 + 2 + sw, ay + 24, c("T"))
        # hanging bread sign
        sx = x0 + w - 6
        cv.hline(sx - 4, sx + 1, ay - 6, c("O")); cv.vline(sx - 3, ay - 5, ay - 4, c("O"))
        cv.ellipse(sx - 3, ay - 1, 3.4, 2.2, c("T")); cv.hline(sx - 5, sx - 1, ay - 2, c("U"))
        door_x = x0 + w - 10
    else:
        door_x = x0 + w // 2 - 3
    dy = wall_top + 44 if shop else wall_top + 40
    # stone plinth: light enough for the head band rule (L* >= 35)
    cv.rect(x0, H - 30, w, 30, c("X"))
    for yy in range(H - 30, H, 5):
        cv.hline(x0, x0 + w - 1, yy, c("x"))
        for xx in range(x0 + ((yy // 5) % 2) * 4, x0 + w, 8):
            cv.put(xx, yy + 1, c("x")); cv.put(xx, yy + 2, c("x"))
    cv.rect(door_x, dy, 7, H - dy, c("O"))
    cv.rect(door_x + 1, dy + 1, 5, H - dy - 1, c("o"))
    cv.rect(door_x + 2, dy + 3, 3, 4, c("Z"))                            # lit door pane
    cv.put(door_x + 5, dy + 16, c("Z"))                                   # knob


def village_mid(meta, seed=122):
    """Bakery street: a back row of roofs and a front row of houses and shops (parallax 0.45)."""
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 120
    cv = WrapCanvas(W, H)
    # back row: continuous pale roofs/walls so the layer is opaque from row 12 down
    x = 0
    while x < W:
        w = int(rng.integers(18, 34))
        t = int(rng.integers(10, 20))
        cv.rect(x, t, w, H - t, c("x"))
        for i in range(5):
            cv.hline(x - 1 + i, x + w - i, t - 1 - i, c("o" if i else "O"))
        cv.put(x + w // 2, t + 4, c("y")); cv.put(x + w // 2 + 1, t + 4, c("y"))
        x += w
    # front row of houses (widths sum to exactly one period)
    widths, x = [], 0
    while W - x > 80:
        w = int(rng.integers(44, 70))
        widths.append(w)
        x += w
    widths.append(W - x)
    x = 0
    for i, w in enumerate(widths):
        _house(cv, rng, x, w, int(rng.integers(26, 34)), shop=(i % 2 == 0))
        x += w
    meta.update(view_y=180, parallax=0.45)
    return cv


def village_ground(meta, seed=133):
    """Cobbled pavement + packed-flour lane (feet line row 15 unchanged)."""
    rng = np.random.default_rng(seed)
    W, H = PERIOD, 80
    cv = WrapCanvas(W, H)
    LANE = 15
    for x in range(W):
        for y in range(0, H):
            if y < 7:
                k = "X" if ((x + (y // 3) * 3) % 6 == 0 or y % 3 == 0) else "x"   # cobbles + mortar
            elif y < 9:
                k = "T" if y == 7 else "o"                                         # kerb
            elif y < 22:
                k = "o"                                                            # lane
            elif y < 24:
                k = "O"
            elif y < 46:
                k = "O"
            else:
                k = "w"
            cv.put(x, y, c(k))
    for x in range(W):
        if (x // 3) % 5 != 0:
            cv.put(x, 15, c("O") if (x % 9) else c("T"))
        if (x // 4) % 7 != 0:
            cv.put(x, 19, c("O"))
    for _ in range(160):                                                           # flour dust + crumbs
        x, y = int(rng.integers(0, W)), int(rng.integers(10, 21))
        cv.put(x, y, c("T")); cv.put(x + 1, y, c("U" if rng.uniform() < 0.3 else "O"))
    for _ in range(70):
        x, y, w = int(rng.integers(0, W)), int(rng.integers(26, 76)), int(rng.integers(2, 6))
        for i in range(w):
            cv.put(x + i, y, c("A" if y < 46 else "O"))
            cv.put(x + i, y - 1, c("X" if y < 46 else "o"))
    for x in range(W):
        if x % 4 == 1:
            cv.put(x, 22, c("O")); cv.put(x, 23, c("o"))
    meta.update(view_y=280, parallax=1.0, tile=True, lane_line=LANE,
                note="layer row 15 is the feet line: place layer at view_y = ground_y - 15")
    return cv


VILLAGE = [
    ("sky", village_sky),
    ("far", village_far),
    ("mid", village_mid),
    ("ground", village_ground),
    ("front", front_layer),
]
BIOME_01 = VILLAGE      # what build.py ships as biome_01 (atlas id biome_meadow kept: contract)


def build_meadow(layers=None):
    out = []
    for name, fn in (layers or BIOME_01):
        meta = {}
        cv = fn(meta)
        out.append((name, cv, meta))
    return out


def compose_preview(layers, width=800, cam=0):
    """Compose layers as the engine would (for contact sheets)."""
    from pixel import RGBA
    from PIL import Image
    img = Image.new("RGBA", (width, 360), (0, 0, 0, 255))
    for name, cv, meta in layers:
        tex = Image.fromarray(RGBA[cv.a], "RGBA")
        if meta.get("repeat_x"):
            rx = meta["repeat_x"]
            for x in range(0, width, rx):
                img.alpha_composite(tex, (x, meta["view_y"]))
            continue
        off = int(-cam * meta.get("parallax", 1.0)) % PERIOD
        x = -off
        while x < width:
            img.alpha_composite(tex, (x, meta["view_y"])) if x >= 0 else img.alpha_composite(tex.crop((-x, 0, cv.w, cv.h)), (0, meta["view_y"]))
            x += PERIOD
    return img
