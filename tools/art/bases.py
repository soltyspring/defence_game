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


# =============================================================================
# art-world 1 (09-art-world, 2026-11-01, docs/art/world/WORLD_AUDIT.md C3): both bases redrawn for a value that
# separates from the new street (warm shadow at the bottom, lit plaster and pale haze above) and for damage states
# that change the SILHOUETTE, not only a few pixels. Same contract: 96x128, pivot (48,127), idle/damaged/ruined x2,
# keep gate faces RIGHT, nest cave faces LEFT, no_flip. build.py still applies theme.BAKERY_KEEP / theme.MOULD_FORT,
# so the keep is drawn only in keys those remaps leave alone (o O w T U R r E e Z K h H) and the nest only in mould
# keys (D l t z q Q a A X x K), which theme.ENEMY does not touch.
# =============================================================================
def _brick_wall(cv, x0, y0, x1, y1, rng, base="T", mortar="U", hi="U", bw=6, bh=4, edge="o"):
    for y in range(y0, y1):
        row = (y - y0) // bh
        off = (bw // 2) * (row % 2)
        for x in range(x0, x1):
            k = base
            if (y - y0) % bh == bh - 1 or (x - x0 + off) % bw == 0:
                k = mortar
            elif (y - y0) % bh == 0 and (x - x0 + off) % bw in (1, 2):
                k = hi
            cv.put(x, y, c(k))
    cv.vline(x0, y0, y1 - 1, c(hi))
    cv.vline(x1 - 1, y0, y1 - 1, c(edge))


def _crenels(cv, x0, x1, y, h, w, gap, skip=()):
    x, i = x0, 0
    while x + w <= x1:
        if i not in skip:
            cv.rect(x, y - h, w, h, c("T"))
            cv.hline(x, x + w - 1, y - h, c("U"))
            cv.vline(x + w - 1, y - h, y - 1, c("o"))
        x += w + gap
        i += 1


def _cone_roof(cv, cx, top, base_y, half_w):
    for y in range(top, base_y + 1):
        t = (y - top) / max(1, base_y - top)
        hw = int(round(1 + t * half_w))
        for x in range(cx - hw, cx + hw + 1):
            k = "R"
            if x < cx - hw // 3:
                k = "E"
            if x > cx + hw // 2:
                k = "r"
            if (y - top) % 4 == 3:
                k = "r"
            cv.put(x, y, c(k))


def _loaf_sign(cv, cx, cy):
    """Big round loaf with three score marks: the bakery identity at a glance."""
    cv.ellipse(cx, cy, 9, 5.5, c("O"))
    cv.ellipse(cx - 0.5, cy - 0.5, 8, 4.5, c("o"))
    cv.ellipse(cx - 2.5, cy - 2, 4, 2, c("T"))
    for dx in (-4, 0, 4):
        cv.line(cx + dx - 1, cy + 2, cx + dx + 1, cy - 2, c("U"))


def _flag(cv, x, y, phase, length=8, w=6):
    cv.vline(x - 1, y - 3, y + length + 2, c("w"))
    cv.put(x - 1, y - 4, c("Z"))
    for j in range(length):
        sway = int(round(np.sin((j / 3.0) + phase * np.pi))) if j > 1 else 0
        for i in range(w):
            if j == length - 1 and i % 2 == 1:
                continue
            cv.put(x + i + sway, y + j, c("R" if i < w - 1 else "r"))
    cv.put(x + 2, y + 3, c("Z")); cv.put(x + 3, y + 3, c("Z")); cv.put(x + 2, y + 4, c("Z")); cv.put(x + 3, y + 4, c("U"))


def _smoke(cv, x, y, phase, n=3):
    for k in range(n):
        r = 2.2 + k * 0.9
        cv.ellipse(x + (k if phase % 2 else -k), y - k * 5, r, r * 0.8, c("h" if k else "w"))
        cv.put(x - 1 + (k if phase % 2 else -k), y - k * 5 - 1, c("H"))


KEEP_PLINTH = dict(base="O", mortar="w", hi="o", edge="w")   # dark crust course behind the units (WORLD_AUDIT §6, keep_plinth_ab.py)


def keep_v2(state: str, phase: int) -> Canvas:
    rng = np.random.default_rng(1101)
    cv = Canvas(W, H)
    g = H - 1
    cv.ellipse(48, g + 2, 46, 6, c("O"))                                    # foundation mound
    hurt = state in ("damaged", "ruined")
    # left tower: tall, red cone roof (the silhouette landmark)
    PL = 88                                                                 # plinth row (screen y ~250): units walk in
    _brick_wall(cv, 8, 34, 34, PL, rng)                                     # front of the rows below it, so they are a
    _brick_wall(cv, 8, PL, 34, g - 1, rng, **KEEP_PLINTH)          # dark course (cream units stay visible)
    if not hurt:
        # flag on a pole above the cone tip; everything from the gold knob (row 0) down stays inside the frame
        _cone_roof(cv, 21, 11, 34, 15)
        _flag(cv, 22, 4, phase, length=5)
    # main keep block
    _brick_wall(cv, 30, 54, 80, PL, rng)
    _brick_wall(cv, 30, PL, 80, g - 1, rng, **KEEP_PLINTH)
    _crenels(cv, 30, 82, 54, 6, 6, 3, skip=(() if not hurt else (1, 3, 4)))
    # front gate tower (right)
    _brick_wall(cv, 64, 66, 92, PL, rng, base="U", mortar="T", hi="W", edge="T")
    _brick_wall(cv, 64, PL, 92, g - 1, rng, **KEEP_PLINTH)
    for x in range(8, 92):                                                  # cream string course on top of the plinth
        if cv.get(x, PL):
            cv.put(x, PL, c("U"))
    _crenels(cv, 64, 93, 66, 5, 5, 3, skip=(() if not hurt else (0, 2)))
    for x in range(64, 92):                                                 # flour-white string course
        cv.put(x, 72, c("U"))
    # gate (faces right): cream stone arch around a lit plank door (it sits in the dark lower course)
    gx0, gx1, gtop = 70, 86, 96
    cx = (gx0 + gx1) / 2
    for y in range(gtop - 2, g - 1):                                        # arch frame, 2 px wider than the door
        for x in range(gx0 - 2, gx1 + 2):
            dy = y - (gtop - 2)
            if dy < 7 and abs(x + 0.5 - cx) > 3 + dy * 1.4:
                continue
            cv.put(x, y, c("U" if (x + y) % 5 else "T"))
    for y in range(gtop, g - 1):
        for x in range(gx0, gx1):
            dy = y - gtop
            if dy < 6 and abs(x + 0.5 - cx) > 1 + dy * 1.4:
                continue
            k = "o" if (x - gx0) % 4 else "O"
            if dy in (9, 19):
                k = "w"
            cv.put(x, y, c(k))
    # windows: dark with a warm oven glow
    for (wx, wy) in [(18, 46), (18, 66), (40, 70), (54, 70), (40, 90)]:
        cv.rect(wx, wy, 4, 6, c("K"))
        cv.put(wx + 1, wy + 3, c("e")); cv.put(wx + 2, wy + 3, c("Z")); cv.put(wx + 1, wy + 4, c("E")); cv.put(wx + 2, wy + 4, c("e"))
        cv.hline(wx - 1, wx + 4, wy - 1, c("U"))
    _loaf_sign(cv, 52, 62)
    if hurt:
        # broken tower top (jagged), holes, cracks: the outline changes, not only the colours
        top = 30 if state == "damaged" else 0
        for x in range(6, 37):
            jag = top + int(rng.integers(0, 7)) + (6 if x > 22 else 0)
            cv.a[:jag, x] = 0
        damage_holes(cv, rng, (10, 40, 80, 112), 10, col="w", inner="K")
        for _ in range(5):
            crack(cv, rng, int(rng.integers(30, 90)), int(rng.integers(58, 84)), int(rng.integers(8, 16)))
        for x in range(30, 82):                                             # scorched band under the crenels
            if cv.get(x, 60) and (x * 3) % 5:
                cv.put(x, 60, c("w")); cv.put(x, 61, c("h"))
    if state == "ruined":
        ruin_cut(cv, rng, 88, jag=7)
        rubble(cv, rng, 2, 94, g, cols=("o", "O", "T", "w"))
    cv.outline(c("K"))
    if state == "damaged":
        fire(cv, 20, 40, phase, 2)
        fire(cv, 60, 58, phase + 1, 2)
        fire(cv, 84, 70, phase, 1)
        _smoke(cv, 20, 30, phase)
        _smoke(cv, 61, 48, phase + 1)
    if state == "ruined":
        fire(cv, 36, 96, phase, 2)
        fire(cv, 70, 98, phase + 1, 2)
        _smoke(cv, 37, 86, phase)
    return cv


NEST2_BLOBS = [(52, 104, 42, 28), (22, 110, 20, 20), (80, 98, 16, 30), (60, 78, 24, 20), (36, 84, 18, 16), (12, 102, 10, 22)]


def nest_v2(state: str, phase: int) -> Canvas:
    rng = np.random.default_rng(2103)
    cv = Canvas(W, H)
    g = H - 1
    hurt = state in ("damaged", "ruined")
    blobs = NEST2_BLOBS if not hurt else [(cx, cy + (6 if i in (3, 4) else 0), rx, ry - (6 if i in (3, 4) else 0))
                                          for i, (cx, cy, rx, ry) in enumerate(NEST2_BLOBS)]
    cv.ellipse(50, g + 2, 47, 6, c("D"))                                   # mould stain on the street
    for (cx, cy, rx, ry) in blobs:                                          # dark mould mass (reads against the lit
        cv.ellipse(cx, cy, rx, ry, c("D"))                                  # plaster/haze above and, by hue and the
    for (cx, cy, rx, ry) in blobs:                                          # light rim, against the street below)
        cv.ellipse(cx - rx * 0.16, cy - ry * 0.2, rx * 0.72, ry * 0.64, c("l"))
        cv.ellipse(cx - rx * 0.36, cy - ry * 0.46, rx * 0.2, ry * 0.14, c("t"))
        cv.ellipse(cx - rx * 0.42, cy - ry * 0.56, rx * 0.12, ry * 0.08, c("z"))
    for x in range(W):                                                      # fuzzy light rim on every top edge
        ys = [y for y in range(H) if cv.get(x, y)]
        if not ys:
            continue
        t = ys[0]
        cv.put(x, t, c("t"))
        for k in range(1, 1 + (x * 7 + 3) % 3):
            if (x + k) % 2 == 0:
                cv.put(x, t - k, c("t" if k < 2 else "z"))
    for _ in range(8):                                                      # mould colonies (light rings, spore centre)
        x, y = int(rng.integers(26, 90)), int(rng.integers(74, 116))
        if cv.get(x, y) and cv.get(x + 3, y + 2):
            r = float(rng.uniform(1.6, 2.8))
            for yy in range(int(y - r) - 1, int(y + r) + 2):
                for xx in range(int(x - r) - 1, int(x + r) + 2):
                    d = ((xx - x) ** 2 + (yy - y) ** 2) ** 0.5
                    if abs(d - r) < 0.6 and cv.get(xx, yy):
                        cv.put(xx, yy, c("t"))
            cv.put(x, y, c("z"))
    for y in range(90, g):                                                  # cave mouth facing LEFT
        hw = min(11, 3 + (y - 90))
        for x in range(16 - hw, 16 + hw + 1):
            cv.put(x, y, c("K" if abs(x - 16) < hw - 1 else "D"))
    for (x, y0, y1) in [(9, 95, 103), (13, 92, 100), (19, 93, 106), (23, 97, 103)]:
        cv.vline(x, y0, y1, c("t")); cv.put(x, y1 + 1, c("z"))
    for (x, y) in [(12, 110), (20, 114)]:                                   # eyes in the dark
        cv.put(x, y, c("Q" if phase == 0 else "q")); cv.put(x + 1, y, c("Q" if phase == 0 else "q"))
    stalks = [(6, 6, 104, 5), (40, 38, 74, 4), (70, 28, 72, 4), (86, 50, 76, 3)]
    if hurt:
        stalks = [(6, 40, 104, 0), (40, 56, 74, 0), (70, 28, 72, 4)] if state == "damaged" else [(6, 84, 104, 0), (70, 74, 90, 0)]
    for (x, top, base, r) in stalks:
        if r > 0:
            _sporangium(cv, x, top, base, r, phase, rng)
        else:                                                               # broken stump with a torn tip
            cv.vline(x, top, base, c("l")); cv.vline(x + 1, top, base, c("D"))
            cv.put(x - 1, top, c("z")); cv.put(x + 2, top + 1, c("t"))
    pods = [(46, 96), (66, 88), (82, 108), (30, 82)]
    for i, (x, y) in enumerate(pods):                                       # glowing pods (burst when damaged)
        if hurt and i % 2 == 0:
            cv.ellipse(x, y, 3.0, 2.4, c("K"))
            for (dx, dy) in [(-3, -3), (3, -3), (0, -4), (-4, 0), (4, 0)]:
                cv.put(x + dx, y + dy, c("z"))
            continue
        cv.ellipse(x, y, 2.8, 2.3, c("q"))
        cv.put(x, y, c("z" if phase == 0 else "Q"))
        cv.put(x - 1, y - 1, c("Q"))
    for k, (x, y) in enumerate([(4, 2), (18, 14), (30, 24), (54, 20), (78, 14), (92, 30)]):
        if not hurt:
            cv.put(x + (phase if k % 2 else -phase), y + (0 if k % 2 else phase), c("z"))
    if hurt:
        # a black split through the mound + dried grey crust patches
        x, y = 58, 72
        for s in range(40):
            for w2 in range(-1, 2):
                if cv.get(x + w2, y):
                    cv.put(x + w2, y, c("K"))
            x += int(rng.integers(-1, 2))
            y += 1
        for _ in range(9):
            px, py = int(rng.integers(30, 92)), int(rng.integers(76, 118))
            if cv.get(px, py):
                cv.ellipse(px, py, float(rng.uniform(2, 4)), float(rng.uniform(1.5, 3)), c("X"))
                cv.put(px - 1, py - 1, c("x"))
        for (x, y) in [(34, 66), (62, 60), (84, 70), (50, 54)]:             # spore puffs escaping
            r = 2.6 + (phase + x) % 2
            cv.ellipse(x, y, r, r * 0.8, c("z"))
            cv.put(x + 1, y + 1, c("x"))
    if state == "ruined":
        ruin_cut(cv, rng, 100, jag=5)
        rubble(cv, rng, 4, 92, g, cols=("D", "l", "X", "a"))
    cv.outline(c("K"))
    return cv


# What build.py ships (it calls bases.player_keep / bases.mould_nest). The art 0.12/0.13 versions stay for comparison.
player_keep_v1, mould_nest_v1 = player_keep, mould_nest
player_keep, mould_nest = keep_v2, nest_v2
