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


def build_meadow():
    out = []
    for name, fn in MEADOW:
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
