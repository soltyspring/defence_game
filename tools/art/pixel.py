"""Core pixel-art primitives for the deterministic art pipeline (owner: 03-art).

All art is authored as palette-indexed numpy arrays (uint8, 0 = transparent).
Nothing here is random unless a seeded RNG is passed in explicitly, so every
build produces byte-identical PNGs.
"""
from __future__ import annotations

import math
import numpy as np
from PIL import Image

# ---------------------------------------------------------------------------
# Palette "Hearth-48" (original, authored for this project).
# key -> (name, hex). Index order is stable: changing it changes PNG bytes.
# ---------------------------------------------------------------------------
PALETTE_DEF = [
    (".", "clear", None),
    ("K", "outline", "1b1325"),
    # skin
    ("s", "skin_shadow", "8a4f3a"), ("S", "skin", "d98b5f"), ("L", "skin_light", "f4c294"),
    # hair / dark brown
    ("h", "hair_dark", "4a2a1c"), ("H", "hair", "7a4628"),
    # steel
    ("m", "steel_dark", "3c4660"), ("M", "steel", "7684a0"), ("N", "steel_light", "b9c6d6"), ("W", "white", "f2f6f8"),
    # ally blue
    ("b", "blue_dark", "1f2f6b"), ("B", "blue", "2f5fb3"), ("C", "blue_light", "5d9be8"), ("c", "blue_pale", "a7d3ff"),
    # gold
    ("y", "gold_dark", "9a5f12"), ("Y", "gold", "e5a826"), ("Z", "gold_light", "ffe27a"),
    # red / orange
    ("r", "red_dark", "5c1631"), ("R", "red", "a52a3a"), ("E", "red_light", "e2533d"), ("e", "orange", "ff9a62"),
    # green
    ("g", "green_dark", "1c3a2e"), ("G", "green", "2f6d3a"), ("F", "green_light", "5fae47"), ("f", "green_pale", "b4e266"),
    # wood / crust
    ("w", "wood_dark", "3d2519"), ("O", "wood", "6e4528"), ("o", "wood_light", "a46c3c"), ("T", "tan", "d9a35e"),
    ("U", "cream", "f6e7c1"),
    # purple
    ("p", "purple_dark", "2e1a47"), ("P", "purple", "5b3488"), ("V", "purple_light", "9762c8"), ("v", "lilac", "d1a6f0"),
    # cyan magic
    ("q", "teal", "2a7f9e"), ("Q", "cyan", "4fe3e0"),
    # sky
    ("i", "sky_dark", "3b5aa8"), ("I", "sky", "6f9ae0"), ("j", "sky_light", "a9d0f2"), ("J", "sky_pale", "e3f3ff"),
    # stone
    ("a", "stone_dark", "2f3140"), ("A", "stone", "555a6e"), ("X", "stone_light", "8b90a3"), ("x", "stone_pale", "c4c7d2"),
    # distance blues / forest teal
    ("n", "mountain", "4a5d8c"), ("u", "mountain_light", "7287b8"), ("d", "forest_far", "23485a"),
    # translucent shadow (the only non-opaque colour)
    ("_", "shadow", "1b1325"),
]
SHADOW_ALPHA = 96

KEYS = [k for k, _, _ in PALETTE_DEF]
IDX = {k: i for i, k in enumerate(KEYS)}
NAME_IDX = {n: i for i, (_, n, _) in enumerate(PALETTE_DEF)}
assert len(set(KEYS)) == len(KEYS), "duplicate palette keys"


def _rgba_table() -> np.ndarray:
    t = np.zeros((256, 4), np.uint8)
    for i, (k, _, hx) in enumerate(PALETTE_DEF):
        if hx is None:
            continue
        t[i, 0] = int(hx[0:2], 16)
        t[i, 1] = int(hx[2:4], 16)
        t[i, 2] = int(hx[4:6], 16)
        t[i, 3] = SHADOW_ALPHA if k == "_" else 255
    return t


RGBA = _rgba_table()
OUTLINE = IDX["K"]


def c(key: str) -> int:
    return IDX[key]


# Ramps used for automatic shading (dark -> light)
RAMPS = {
    "skin": "sSL", "steel": "mMNW", "blue": "bBCc", "gold": "yYZ", "red": "rREe",
    "green": "gGFf", "wood": "wOoT", "purple": "pPVv", "stone": "aAXx", "sky": "iIjJ",
    "crust": "wOoTU",
}


def darker(idx: int, steps: int = 1) -> int:
    k = KEYS[idx]
    for ramp in RAMPS.values():
        if k in ramp:
            j = max(0, ramp.index(k) - steps)
            return IDX[ramp[j]]
    return idx


def lighter(idx: int, steps: int = 1) -> int:
    k = KEYS[idx]
    for ramp in RAMPS.values():
        if k in ramp:
            j = min(len(ramp) - 1, ramp.index(k) + steps)
            return IDX[ramp[j]]
    return idx


# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.a = np.zeros((h, w), np.uint8)

    def copy(self) -> "Canvas":
        n = Canvas(self.w, self.h)
        n.a = self.a.copy()
        return n

    # --- basic --------------------------------------------------------------
    def put(self, x: int, y: int, col: int):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = col

    def get(self, x: int, y: int) -> int:
        if 0 <= x < self.w and 0 <= y < self.h:
            return int(self.a[y, x])
        return 0

    def rect(self, x: int, y: int, w: int, h: int, col: int):
        x0, y0, x1, y1 = max(0, x), max(0, y), min(self.w, x + w), min(self.h, y + h)
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = col

    def hline(self, x0: int, x1: int, y: int, col: int):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, col)

    def vline(self, x: int, y0: int, y1: int, col: int):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, col)

    def line(self, x0: int, y0: int, x1: int, y1: int, col: int):
        """Bresenham line (pixel-perfect, no anti-aliasing)."""
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def line_pts(self, x0, y0, x1, y1):
        pts = []
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            pts.append((x0, y0))
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        return pts

    def thick_line(self, x0, y0, x1, y1, col, t=2, shade=None):
        """Limb-style line: t px thick. If shade given, the lower/right edge uses it."""
        lo, hi = -(t // 2), t - t // 2
        pix = set()
        for (x, y) in self.line_pts(x0, y0, x1, y1):
            for oy in range(lo, hi):
                for ox in range(lo, hi):
                    pix.add((x + ox, y + oy))
        for (x, y) in pix:
            cc = col
            if shade is not None and t > 1 and ((x + 1, y) not in pix):
                cc = shade
            self.put(x, y, cc)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col: int, fill=True):
        for y in range(int(math.floor(cy - ry)) - 1, int(math.ceil(cy + ry)) + 2):
            for x in range(int(math.floor(cx - rx)) - 1, int(math.ceil(cx + rx)) + 2):
                dx = (x + 0.5 - cx) / max(rx, 0.01)
                dy = (y + 0.5 - cy) / max(ry, 0.01)
                d = dx * dx + dy * dy
                if fill and d <= 1.0:
                    self.put(x, y, col)
                elif not fill and 0.62 <= d <= 1.0:
                    self.put(x, y, col)

    def disc_mask(self, cx, cy, rx, ry):
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        dx = (xs + 0.5 - cx) / max(rx, 0.01)
        dy = (ys + 0.5 - cy) / max(ry, 0.01)
        return dx * dx + dy * dy <= 1.0

    # --- stamping ASCII pixel maps -----------------------------------------
    def stamp(self, art: "Sprite", x: int, y: int, flip=False, only_onto=False, recolor=None):
        g = art.a[:, ::-1] if flip else art.a
        h, w = g.shape
        for j in range(h):
            yy = y + j
            if not (0 <= yy < self.h):
                continue
            for i in range(w):
                v = int(g[j, i])
                if v == 0:
                    continue
                xx = x + i
                if not (0 <= xx < self.w):
                    continue
                if only_onto and self.a[yy, xx] == 0:
                    continue
                if recolor:
                    v = recolor.get(v, v)
                self.a[yy, xx] = v

    def blit(self, other: "Canvas", x: int, y: int):
        self.stamp(Sprite(other.a), x, y)

    # --- post processing ----------------------------------------------------
    def outline(self, col: int = OUTLINE, diagonal=False, skip=(None,)):
        """1 px exterior outline around all opaque (non-shadow) pixels."""
        solid = (self.a != 0) & (self.a != IDX["_"])
        grow = np.zeros_like(solid)
        grow[1:, :] |= solid[:-1, :]
        grow[:-1, :] |= solid[1:, :]
        grow[:, 1:] |= solid[:, :-1]
        grow[:, :-1] |= solid[:, 1:]
        if diagonal:
            grow[1:, 1:] |= solid[:-1, :-1]
            grow[:-1, :-1] |= solid[1:, 1:]
            grow[1:, :-1] |= solid[:-1, 1:]
            grow[:-1, 1:] |= solid[1:, :-1]
        m = grow & ~solid
        self.a[m] = col
        return self

    def flip_h(self):
        self.a = self.a[:, ::-1].copy()
        return self

    def shift(self, dx: int, dy: int):
        n = np.zeros_like(self.a)
        h, w = self.a.shape
        sx0, sx1 = max(0, -dx), min(w, w - dx)
        sy0, sy1 = max(0, -dy), min(h, h - dy)
        n[sy0 + dy:sy1 + dy, sx0 + dx:sx1 + dx] = self.a[sy0:sy1, sx0:sx1]
        self.a = n
        return self

    def rot90_about(self, px: int, py: int, k: int = 1):
        """Lossless 90deg rotation of the whole canvas content about (px,py)."""
        n = np.zeros_like(self.a)
        ys, xs = np.nonzero(self.a)
        for y, x in zip(ys, xs):
            dx, dy = x - px, y - py
            for _ in range(k % 4):
                dx, dy = -dy, dx  # clockwise in screen space
            nx, ny = px + dx, py + dy
            if 0 <= nx < self.w and 0 <= ny < self.h:
                n[ny, nx] = self.a[y, x]
        self.a = n
        return self

    def dissolve(self, level: int):
        """Ordered (Bayer 4x4) dither dissolve. level 0..16 pixels removed per 16."""
        bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
        h, w = self.a.shape
        th = np.tile(bayer, (h // 4 + 1, w // 4 + 1))[:h, :w]
        self.a[th < level] = 0
        return self

    def recolor(self, mapping: dict):
        out = self.a.copy()
        for s, d in mapping.items():
            out[self.a == s] = d
        self.a = out
        return self

    def to_image(self) -> Image.Image:
        return Image.fromarray(RGBA[self.a], "RGBA")


class Sprite:
    """Immutable small pixel map, typically parsed from ASCII art."""

    def __init__(self, a: np.ndarray):
        self.a = a

    @property
    def w(self):
        return self.a.shape[1]

    @property
    def h(self):
        return self.a.shape[0]

    @staticmethod
    def parse(text: str, remap: dict | None = None) -> "Sprite":
        rows = [r for r in text.strip("\n").split("\n")]
        rows = [r.rstrip() for r in rows]
        # strip common leading indentation
        ind = min((len(r) - len(r.lstrip(" ")) for r in rows if r.strip()), default=0)
        rows = [r[ind:] for r in rows]
        w = max(len(r) for r in rows)
        a = np.zeros((len(rows), w), np.uint8)
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in (" ", "."):
                    continue
                if remap and ch in remap:
                    ch = remap[ch]
                if ch not in IDX:
                    raise ValueError(f"unknown palette key {ch!r} in row {j}: {r}")
                a[j, i] = IDX[ch]
        return Sprite(a)

    def flipped(self) -> "Sprite":
        return Sprite(self.a[:, ::-1].copy())

    def recolored(self, mapping: dict) -> "Sprite":
        """mapping: key->key"""
        out = self.a.copy()
        for s, d in mapping.items():
            out[self.a == IDX[s]] = IDX[d]
        return Sprite(out)


def img_from_index(a: np.ndarray) -> Image.Image:
    return Image.fromarray(RGBA[a], "RGBA")


def save_indexed_png(a: np.ndarray, path: str):
    """Save a palette-index array as an 8-bit indexed PNG with tRNS alpha.
    Smaller on disk than RGBA; decodes to identical RGBA. Deterministic."""
    img = Image.fromarray(a.astype(np.uint8), "P")
    pal = []
    for i in range(256):
        pal += list(RGBA[i, :3])
    img.putpalette(pal)
    alpha = bytes(int(RGBA[i, 3]) for i in range(len(PALETTE_DEF)))
    img.save(path, optimize=True, transparency=alpha)


def write_palette_files(out_dir):
    """Exports palette as .gpl (GIMP/Aseprite), .hex and a swatch PNG."""
    import os
    os.makedirs(out_dir, exist_ok=True)
    lines = ["GIMP Palette", "Name: Hearth-48 (defence, 03-art)", "Columns: 8", "#"]
    hexes = []
    for k, n, hx in PALETTE_DEF:
        if hx is None:
            continue
        r, g, b = int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{n} ({k})")
        hexes.append(hx)
    with open(os.path.join(out_dir, "hearth48.gpl"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(out_dir, "hearth48.hex"), "w", newline="\n") as f:
        f.write("\n".join(hexes) + "\n")
    cols = 8
    n = len(PALETTE_DEF) - 1
    rows = (n + cols - 1) // cols
    sw = np.zeros((rows * 8, cols * 8), np.uint8)
    for i in range(1, len(PALETTE_DEF)):
        j = i - 1
        sw[(j // cols) * 8:(j // cols) * 8 + 8, (j % cols) * 8:(j % cols) * 8 + 8] = i
    img_from_index(sw).save(os.path.join(out_dir, "hearth48_swatch.png"))
