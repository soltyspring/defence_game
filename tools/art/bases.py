"""Player keep and enemy bramble fort, 96x128, 3 damage states (owner: 03-art).
base_player gate faces RIGHT (toward the lane); base_enemy gate faces LEFT.
Bases are NOT flipped by the engine. Pivot = bottom centre (48, 127).
"""
from __future__ import annotations

import numpy as np

from pixel import Canvas, Sprite, c

W, H = 96, 128
PIVOT = (48, 127)


def bricks(cv: Canvas, x0, y0, x1, y1, rng, base="X", mortar="A", hi="x", dark="A", bw=6, bh=4):
    for y in range(y0, y1):
        row = (y - y0) // bh
        off = (bw // 2) * (row % 2)
        for x in range(x0, x1):
            cv.put(x, y, c(base))
            if (y - y0) % bh == bh - 1:
                cv.put(x, y, c(mortar))
            elif (x - x0 + off) % bw == 0:
                cv.put(x, y, c(mortar))
            elif (y - y0) % bh == 0 and (x - x0 + off) % bw in (1, 2):
                cv.put(x, y, c(hi))
    # random weathered bricks
    for _ in range(((x1 - x0) * (y1 - y0)) // 90):
        bx = int(rng.integers(x0, max(x0 + 1, x1 - 3)))
        by = int(rng.integers(y0, max(y0 + 1, y1 - 2)))
        cv.put(bx, by, c(dark))


def merlons(cv: Canvas, x0, x1, y, h=5, w=5, gap=4, col="X", hi="x", skip=()):
    x = x0
    i = 0
    while x + w <= x1:
        if i not in skip:
            cv.rect(x, y - h, w, h, c(col))
            cv.hline(x, x + w - 1, y - h, c(hi))
        x += w + gap
        i += 1


def roof(cv: Canvas, cx, top, base_y, half_w, col="B", dark="b", hi="C"):
    for y in range(top, base_y + 1):
        t = (y - top) / max(1, base_y - top)
        hw = int(round(1 + t * half_w))
        for x in range(cx - hw, cx + hw + 1):
            k = col
            if x < cx - hw // 3:
                k = hi
            if x > cx + hw // 2:
                k = dark
            if (y - top) % 4 == 3:
                k = dark
            cv.put(x, y, c(k))


def banner(cv: Canvas, x, y, phase, col="B", dark="b", emblem="Y", length=14, w=7):
    cv.vline(x - 1, y - 4, y + length, c("w"))
    cv.put(x - 1, y - 5, c("Y"))
    for j in range(length):
        sway = int(round(np.sin((j / 4.0) + phase * np.pi) * 1.0)) if j > 2 else 0
        for i in range(w):
            k = col if i < w - 1 else dark
            if j == length - 1 and i % 2 == 1:
                continue  # swallow-tail
            cv.put(x + i + sway, y + j, c(k))
    for (dx, dy) in [(3, 3), (2, 4), (3, 4), (4, 4), (3, 5), (3, 6), (2, 7), (4, 7)]:
        sway = int(round(np.sin(((dy) / 4.0) + phase * np.pi) * 1.0)) if dy > 2 else 0
        cv.put(x + dx + sway, y + dy, c(emblem))


def fire(cv: Canvas, x, y, phase, size=1):
    f0 = [(0, 0, "E"), (1, 0, "E"), (-1, 0, "R"), (0, -1, "e"), (1, -1, "E"), (0, -2, "Z"), (0, -3, "e"),
          (-1, -1, "E"), (2, 0, "R")]
    f1 = [(0, 0, "E"), (1, 0, "E"), (-1, 0, "R"), (0, -1, "E"), (-1, -1, "e"), (-1, -2, "Z"), (-1, -3, "e"),
          (1, -1, "e"), (2, 0, "R"), (1, -2, "E")]
    for (dx, dy, k) in (f0 if phase % 2 == 0 else f1):
        for s in range(size):
            cv.put(x + dx * size + s, y + dy * size, c(k))
            cv.put(x + dx * size + s, y + dy * size - s, c(k))


def damage_holes(cv: Canvas, rng, region, n, col="a", inner="K"):
    x0, y0, x1, y1 = region
    for _ in range(n):
        cx = int(rng.integers(x0 + 3, x1 - 3))
        cy = int(rng.integers(y0 + 3, y1 - 3))
        r = float(rng.uniform(1.5, 3.2))
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= r and cv.get(x, y) != 0:
                    cv.put(x, y, c(inner if d < r - 1.2 else col))


def crack(cv: Canvas, rng, x, y, length):
    for _ in range(length):
        if cv.get(x, y) != 0:
            cv.put(x, y, c("a"))
        x += int(rng.integers(-1, 2))
        y += 1


def ruin_cut(cv: Canvas, rng, top_y, jag=6):
    """Remove everything above a jagged line; leave rubble at the foot."""
    y = top_y
    for x in range(cv.w):
        y += int(rng.integers(-2, 3))
        y = max(top_y - jag, min(top_y + jag, y))
        cv.a[:y, x] = 0
        if cv.a[y, x] != 0:
            cv.a[y, x] = c("A")


def rubble(cv: Canvas, rng, x0, x1, y, cols=("X", "A", "x", "a")):
    for _ in range((x1 - x0) * 2):
        x = int(rng.integers(x0, x1))
        h = int(rng.integers(1, 5))
        k = cols[int(rng.integers(0, len(cols)))]
        cv.rect(x, y - h, int(rng.integers(2, 4)), h, c(k))


# ---------------------------------------------------------------------------
def player_keep(state: str, phase: int) -> Canvas:
    rng = np.random.default_rng(1001)
    cv = Canvas(W, H)
    ground = H - 1
    # foundation mound
    cv.ellipse(48, ground + 2, 46, 8, c("O"))
    # back tower (left, tall)
    bricks(cv, 10, 30, 36, ground - 2, rng, base="X", mortar="A", hi="x")
    roof(cv, 23, 6, 30, 16)
    # main keep
    bricks(cv, 30, 52, 80, ground - 2, rng, base="X", mortar="A", hi="x")
    merlons(cv, 30, 82, 52, h=6, w=6, gap=3, skip=(() if state == "intact" else (2, 4)))
    # front gate tower (right)
    bricks(cv, 66, 64, 90, ground - 2, rng, base="x", mortar="X", hi="J")
    merlons(cv, 65, 92, 64, h=5, w=5, gap=3, col="x", hi="J", skip=(() if state == "intact" else (1,)))
    # gate arch facing right
    gx0, gx1, gtop = 70, 86, 98
    for y in range(gtop, ground - 1):
        for x in range(gx0, gx1):
            dy = y - gtop
            cx = (gx0 + gx1) / 2
            if dy < 6 and abs(x + 0.5 - cx) > 1 + dy * 1.4:
                continue
            k = "O" if (x - gx0) % 4 else "w"
            if (y - gtop) in (8, 18):
                k = "m"
            cv.put(x, y, c(k))
    cv.put(78, 110, c("Y"))
    # windows (lit lanterns inside)
    for (wx, wy) in [(20, 44), (20, 64), (44, 70), (56, 70), (44, 92)]:
        cv.rect(wx, wy, 3, 6, c("a"))
        cv.put(wx + 1, wy + 3, c("Y"))
        cv.put(wx + 1, wy + 4, c("Z"))
        cv.hline(wx - 1, wx + 3, wy - 1, c("A"))
    # lane-side gold trim
    cv.hline(30, 80, 57, c("y"))
    cv.hline(66, 90, 69, c("y"))
    # banners
    banner(cv, 24, 0, phase, length=6, w=5)
    banner(cv, 50, 60, phase, length=16, w=8)
    if state in ("damaged", "ruined"):
        damage_holes(cv, rng, (12, 32, 80, 110), 9)
        for _ in range(4):
            crack(cv, rng, int(rng.integers(30, 88)), int(rng.integers(55, 80)), int(rng.integers(6, 14)))
    if state == "ruined":
        ruin_cut(cv, rng, 92)
        rubble(cv, rng, 4, 92, ground)
    cv.outline(c("K"))
    if state == "damaged":
        fire(cv, 14, 33, phase, 1)
        fire(cv, 60, 58, phase + 1, 2)
        fire(cv, 82, 70, phase, 1)
    if state == "ruined":
        fire(cv, 40, 100, phase, 2)
    return cv


def log_wall(cv: Canvas, x0, x1, top, bottom, rng, col="o", dark="O", hi="T", lw=4):
    x = x0
    while x < x1:
        h = int(rng.integers(0, 6))
        t = top + h
        for xx in range(x, min(x + lw, x1)):
            for y in range(t, bottom):
                k = col
                if xx == x:
                    k = hi
                if xx == x + lw - 1:
                    k = dark
                cv.put(xx, y, c(k))
        # sharpened tip
        cx = x + lw // 2
        for i in range(3):
            cv.hline(x + i, min(x + lw - 1 - i, x1), t - 1 - i, c(dark if i else col))
        cv.put(cx, t - 4, c("T"))
        # lashing band
        cv.hline(x, min(x + lw - 1, x1 - 1), bottom - 10, c("w"))
        cv.hline(x, min(x + lw - 1, x1 - 1), t + 6, c("w"))
        x += lw


def skull(cv: Canvas, x, y):
    s = Sprite.parse("""
.UUU.
UKUKU
UUUUU
.UKU.
""")
    cv.stamp(s, x, y)


def enemy_fort(state: str, phase: int) -> Canvas:
    rng = np.random.default_rng(2002)
    cv = Canvas(W, H)
    ground = H - 1
    cv.ellipse(48, ground + 2, 46, 8, c("w"))
    # rear watchtower (right side, behind)
    log_wall(cv, 56, 86, 18, ground - 2, rng, col="O", dark="w", hi="o", lw=5)
    # tower hut roof (thatch purple cloth)
    for y in range(6, 22):
        hw = 4 + (y - 6)
        for x in range(71 - hw, 71 + hw + 1):
            k = "P" if (x + y) % 5 else "p"
            if y == 21:
                k = "p"
            cv.put(x, y, c(k))
    cv.hline(56, 86, 22, c("w"))
    # main palisade
    log_wall(cv, 8, 70, 64, ground - 2, rng, lw=4)
    # crude plank walkway + spikes along the palisade top
    cv.hline(8, 70, 76, c("w"))
    for x in range(10, 70, 9):
        cv.line(x, 80, x - 4, 74, c("U"))
    # gate facing LEFT
    gx0, gx1, gtop = 10, 28, 94
    cv.rect(gx0, gtop, gx1 - gx0, ground - 1 - gtop, c("w"))
    for x in range(gx0 + 1, gx1 - 1, 3):
        cv.vline(x, gtop + 1, ground - 2, c("O"))
    cv.hline(gx0, gx1 - 1, gtop + 8, c("M"))
    cv.hline(gx0, gx1 - 1, gtop + 22, c("M"))
    # brambles: thorny vines crawling up the walls
    for _ in range(14):
        x = int(rng.integers(6, 88))
        y = ground - 2
        for k in range(int(rng.integers(10, 30))):
            if cv.get(x, y) != 0 or k < 3:
                cv.put(x, y, c("g" if k % 3 else "G"))
                if k % 4 == 0:
                    cv.put(x + 1, y, c("F"))
                if k % 5 == 2:
                    cv.put(x - 1, y - 1, c("U"))  # thorn
            x += int(rng.integers(-1, 2))
            y -= 1
    # banner with skull mark
    banner(cv, 72, 26, phase, col="P", dark="p", emblem="U", length=14, w=7)
    skull(cv, 36, 84)
    skull(cv, 72, 50)
    # glowing spore lanterns
    for (x, y) in [(32, 96), (60, 40)]:
        cv.rect(x, y, 3, 4, c("w"))
        cv.put(x + 1, y + 1, c("f"))
        cv.put(x + 1, y + 2, c("F"))
    if state in ("damaged", "ruined"):
        damage_holes(cv, rng, (10, 30, 86, 110), 9, col="w", inner="K")
    if state == "ruined":
        ruin_cut(cv, rng, 96)
        rubble(cv, rng, 4, 92, ground, cols=("o", "O", "w", "T"))
    cv.outline(c("K"))
    if state == "damaged":
        fire(cv, 64, 22, phase, 2)
        fire(cv, 30, 58, phase + 1, 1)
    if state == "ruined":
        fire(cv, 50, 102, phase, 2)
    return cv


# ---------------------------------------------------------------------------
# art 0.12.0 (09 X9): 곰팡이 둥지 / Mold Nest replaces the bramble fort. Same frame contract
# (96x128, pivot (48,127), anims idle/damaged/ruined x2, no_flip, gate side LEFT).
# The identity sits on the LEFT edge, which is what enters the screen first: a tall spore
# stalk with a round sporangium head, a dark cave mouth with mould strands and a fuzzy
# dark mound. Drawn directly in mould keys (D/l/t/z/q/a), which theme.ENEMY leaves alone.
# ---------------------------------------------------------------------------
NEST_BLOBS = [(52, 104, 42, 30), (24, 110, 20, 20), (78, 100, 18, 30), (60, 78, 24, 20),
              (36, 86, 18, 16), (14, 100, 10, 24)]


def _sporangium(cv, x, top, base, r, phase, rng):
    cv.vline(x, top + r, base, c("l"))
    cv.vline(x + 1, top + r, base, c("D"))
    for y in range(top + r, base, 5):
        cv.put(x - 1, y, c("t"))                       # little side hairs
    cy = top + r
    cv.ellipse(x + 0.5, cy, r, r * 0.9, c("D"))
    cv.ellipse(x - 0.2, cy - 0.6, r - 1.2, r * 0.9 - 1.2, c("l"))
    cv.ellipse(x - 1.0, cy - 1.4, r * 0.45, r * 0.4, c("t"))
    for k in range(int(r * 2)):                         # spore dots on the cap
        dx, dy = int(rng.integers(-r + 1, r)), int(rng.integers(-r + 1, 1))
        if (dx * dx + dy * dy) < (r - 1) ** 2:
            cv.put(x + dx, cy + dy, c("z" if (k + phase) % 3 == 0 else "t"))


def mould_nest(state: str, phase: int) -> Canvas:
    rng = np.random.default_rng(2003)
    cv = Canvas(W, H)
    g = H - 1
    cv.ellipse(50, g + 2, 47, 7, c("D"))               # mould stain on the ground
    for (cx, cy, rx, ry) in NEST_BLOBS:                # lumpy mound
        cv.ellipse(cx, cy, rx, ry, c("D"))
    for (cx, cy, rx, ry) in NEST_BLOBS:                # light from the upper left
        cv.ellipse(cx - rx * 0.18, cy - ry * 0.2, rx * 0.72, ry * 0.68, c("l"))
    for (cx, cy, rx, ry) in NEST_BLOBS[:5]:
        cv.ellipse(cx - rx * 0.35, cy - ry * 0.45, rx * 0.3, ry * 0.22, c("t"))
    # fuzzy rim: hairs on every top edge pixel of the mound
    for x in range(W):
        ys = [y for y in range(H) if cv.get(x, y)]
        if not ys:
            continue
        t = ys[0]
        n = 1 + (x * 7 + 3) % 3
        for k in range(1, n + 1):
            if (x + k) % 2 == 0:
                cv.put(x, t - k, c("l" if k < 3 else "t"))
    # mould colonies: rings with a spore-white centre
    for _ in range(16):
        x, y = int(rng.integers(20, 92)), int(rng.integers(74, 120))
        if cv.get(x, y) and cv.get(x + 3, y + 2):
            r = float(rng.uniform(1.6, 3.0))
            for yy in range(int(y - r) - 1, int(y + r) + 2):
                for xx in range(int(x - r) - 1, int(x + r) + 2):
                    d = ((xx - x) ** 2 + (yy - y) ** 2) ** 0.5
                    if abs(d - r) < 0.6 and cv.get(xx, yy):
                        cv.put(xx, yy, c("t"))
            cv.put(x, y, c("z"))
    # cave mouth facing LEFT (the gate units spawn from)
    for y in range(92, g):
        dy = y - 92
        hw = min(11, 3 + dy)
        for x in range(17 - hw, 17 + hw + 1):
            cv.put(x, y, c("K" if abs(x - 17) < hw - 1 else "a"))
    for (x, y0, y1) in [(10, 97, 104), (14, 94, 101), (20, 95, 108), (24, 99, 104)]:   # mould strands
        cv.vline(x, y0, y1, c("l"))
        cv.put(x, y1 + 1, c("t"))
    for (x, y) in [(13, 112), (21, 116)]:                                             # eyes in the dark
        cv.put(x, y, c("Q" if phase == 0 else "q")); cv.put(x + 1, y, c("Q" if phase == 0 else "q"))
    # spore stalks: the tallest on the LEFT edge (first thing on screen), more over the mound
    _sporangium(cv, 6, 6, 104, 5, phase, rng)
    _sporangium(cv, 40, 40, 74, 4, phase + 1, rng)
    _sporangium(cv, 70, 30, 72, 4, phase, rng)
    _sporangium(cv, 86, 52, 76, 3, phase + 1, rng)
    # glowing spore pods (pulse)
    for (x, y) in [(46, 96), (66, 88), (82, 108), (30, 82)]:
        cv.ellipse(x, y, 2.6, 2.2, c("q"))
        cv.put(x, y, c("z" if phase == 0 else "Q"))
        cv.put(x - 1, y - 1, c("Q"))
    # drifting spores
    for k, (x, y) in enumerate([(4, 2), (18, 14), (30, 24), (54, 20), (78, 14), (92, 30)]):
        cv.put(x + (phase if k % 2 else -phase), y + (0 if k % 2 else phase), c("z"))
    if state in ("damaged", "ruined"):
        damage_holes(cv, rng, (24, 70, 92, 118), 8, col="a", inner="K")
        for (x, y) in [(52, 74), (74, 68), (40, 92)]:
            cv.line(x, y, x + 5, y + 9, c("K"))
    if state == "ruined":
        ruin_cut(cv, rng, 100)
        rubble(cv, rng, 4, 92, g, cols=("D", "l", "a", "t"))
    cv.outline(c("K"))
    if state == "damaged":
        fire(cv, 64, 70, phase, 2)
        fire(cv, 30, 80, phase + 1, 1)
    if state == "ruined":
        fire(cv, 50, 104, phase, 2)
    return cv


def base_anims(fn):
    return {
        "idle": dict(frames=[fn("intact", 0), fn("intact", 1)], fps=3, loop=True),
        "damaged": dict(frames=[fn("damaged", 0), fn("damaged", 1)], fps=5, loop=True),
        "ruined": dict(frames=[fn("ruined", 0), fn("ruined", 1)], fps=5, loop=True),
    }


# ---------------------------------------------------------------------------
# prop_mine: worker destination behind the player keep (replaces 02's brown box)
# 48x32, pivot bottom-centre (24, 31). Static; lantern flicker as 2-frame anim.
# ---------------------------------------------------------------------------
MINE_W, MINE_H = 48, 32
MINE_PIVOT = (24, 31)


def mine(phase: int) -> Canvas:
    rng = np.random.default_rng(3003)
    cv = Canvas(MINE_W, MINE_H)
    g = MINE_H - 1
    # rocky mound
    cv.ellipse(24, g + 4, 23, 20, c("A"))
    cv.ellipse(20, g + 2, 18, 15, c("X"))
    cv.ellipse(16, g - 2, 8, 6, c("x"))
    for _ in range(26):
        x, y = int(rng.integers(4, 44)), int(rng.integers(12, g))
        if cv.get(x, y):
            cv.put(x, y, c("A"))
            cv.put(x + 1, y, c("a"))
    # grass on top
    for x in range(6, 40):
        ys = [y for y in range(MINE_H) if cv.get(x, y)]
        if ys and (x * 7) % 3:
            cv.put(x, ys[0], c("F"))
    # timber entrance (dark shaft)
    cv.rect(18, 15, 14, g - 15, c("K"))
    cv.rect(19, 16, 12, g - 16, c("a"))
    cv.vline(17, 14, g, c("o")); cv.vline(18, 14, g, c("O"))
    cv.vline(32, 14, g, c("o")); cv.vline(33, 14, g, c("O"))
    cv.hline(16, 34, 13, c("T")); cv.hline(16, 34, 14, c("O"))
    # gold ore glints inside + ore cart
    for (x, y) in [(22, 22), (27, 19), (25, 25)]:
        cv.put(x, y, c("Y"))
    cv.rect(36, g - 5, 9, 4, c("O"))
    cv.hline(36, 44, g - 6, c("o"))
    for (x, y, k) in [(37, g - 7, "Y"), (39, g - 8, "Z"), (41, g - 7, "Y"), (43, g - 7, "y")]:
        cv.put(x, y, c(k))
    cv.put(38, g, c("m")); cv.put(43, g, c("m"))
    # lantern on the frame
    cv.put(33, 11, c("w"))
    cv.put(34, 12, c("Z" if phase == 0 else "Y"))
    cv.outline(c("K"))
    return cv
