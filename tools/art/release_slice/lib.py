"""Drawing kit for the release slice (docs/art/release_slice/STYLE.md). True colour, 1 art px = 1 world px.

Everything is built from *masses*: a boolean mask painted with a 5-step material ramp. Light comes from the upper
left for every mass, so the whole sheet is lit the same way:
    paint(img, mask, ramp, form)   form "flat" | "round" | "wall" | "ground"
    rim(img, mask, colour)         1 px contour outside the mask (dark for gameplay sprites, own-hue for scenery)
Textures cut into a mass after it is painted (bricks, planks, shingles, crust scores, spots): they only move a pixel
one step along its ramp, so a texture never changes the silhouette or the value grouping.
"""
from __future__ import annotations

import numpy as np
from PIL import Image


def hexc(h: str, a: int = 255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# Material ramps, dark -> light (5 steps). Hue shifts towards blue-violet in the dark, towards yellow in the light.
RAMP = {
    "crust": ["6b3a24", "96552d", "c27d3e", "e0a55a", "f4cf86"],
    "crumb": ["b58a56", "d9b57c", "f0d9a6", "fbeecb", "fff8e6"],
    "wood": ["4a3024", "6d4630", "8f6240", "b08453", "cfa873"],
    "timber": ["3d2a26", "58392c", "754d36", "936645", "ad8259"],
    "brick": ["6e3b30", "934e39", "b56a48", "cf8a5f", "e3ab7e"],
    "stone": ["5c5a5e", "7c7873", "9c958a", "bbb3a2", "d8d1bd"],
    "plaster": ["a48f72", "c8b28e", "e3d2ad", "f2e6c6", "fdf6e0"],
    "cloth": ["6e2430", "9a3038", "c2453f", "dd6a4e", "ef9670"],
    "fire": ["a8431f", "e0702a", "f7a23a", "ffd067", "fff3b8"],
    "leaf": ["35583a", "4c7a45", "6c9c50", "93bc62", "bcd882"],
    "hedge": ["3f6a4a", "578556", "76a165", "9bbd7a", "c0d898"],
    "grass": ["5b8246", "76a050", "93b85e", "b0cd72", "cfe091"],
    "wheat": ["9a7a36", "c09a45", "dcb95a", "edd47a", "f8e9a4"],
    "earth": ["6a4e38", "8a6848", "a8845c", "c4a276", "dcc199"],
    "path": ["9a7c58", "b6966c", "cfb184", "e0c89e", "eedbb8"],
    "hill": ["7fa09a", "94b4a6", "a9c5b0", "bdd4bb", "d1e1c8"],
    "sack": ["8f7a58", "b39c74", "d2bd93", "e8d8b4", "f7eed6"],
    "iron": ["30333c", "494e59", "6a707a", "9097a0", "bcc3c8"],
    # the mould: wet grey-teal skin, bruised violet underside, sick pale glow kept for organs only
    "mould": ["24383c", "365558", "4d7775", "6d9a92", "98bdb0"],
    "cap": ["2e3f4a", "44606a", "5f8387", "83a8a2", "b0cbbd"],
    "gill": ["3a2f4a", "574466", "7a6088", "a085a6", "c7b1c8"],
    "hypha": ["4a5650", "68776c", "8a9a8a", "adbba6", "d0dac4"],
    "organ": ["2c5a5e", "3f8a86", "5fbfae", "9fe6cf", "e2fff0"],
    "blight": ["5d7068", "74887c", "8ea093", "a9b8aa", "c4cfc0"],
}
RAMP = {k: [hexc(c) for c in v] for k, v in RAMP.items()}
INK = hexc("2a1d24")            # sprite contour: warm near-black
INK_MOULD = hexc("162428")


class Img:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def pil(self) -> Image.Image:
        return Image.fromarray(self.a, "RGBA")

    def blit(self, other: "Img", x: int, y: int):
        """Alpha-key paste (other's opaque pixels replace ours)."""
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + other.w), min(self.h, y + other.h)
        if x1 <= x0 or y1 <= y0:
            return
        src = other.a[y0 - y:y1 - y, x0 - x:x1 - x]
        m = src[..., 3] > 0
        self.a[y0:y1, x0:x1][m] = src[m]


def grid(w: int, h: int):
    yy, xx = np.mgrid[0:h, 0:w]
    return xx, yy


# ---- masks ----
def m_rect(w, h, x, y, rw, rh):
    xx, yy = grid(w, h)
    return (xx >= x) & (xx < x + rw) & (yy >= y) & (yy < y + rh)


def m_ellipse(w, h, cx, cy, rx, ry):
    xx, yy = grid(w, h)
    return ((xx + 0.5 - cx) / max(rx, 0.01)) ** 2 + ((yy + 0.5 - cy) / max(ry, 0.01)) ** 2 <= 1.0


def m_poly(w, h, pts):
    """Even-odd scanline fill of a polygon given as [(x, y), ...]."""
    xx, yy = grid(w, h)
    px = xx + 0.5
    py = yy + 0.5
    inside = np.zeros((h, w), bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if y0 == y1:
            continue
        cond = ((y0 <= py) & (py < y1)) | ((y1 <= py) & (py < y0))
        xi = x0 + (py - y0) * (x1 - x0) / (y1 - y0)
        inside ^= cond & (px < xi)
    return inside


def m_line(w, h, x0, y0, x1, y1, t=1.0):
    xx, yy = grid(w, h)
    px, py = xx + 0.5, yy + 0.5
    dx, dy = x1 - x0, y1 - y0
    l2 = max(dx * dx + dy * dy, 1e-6)
    u = np.clip(((px - x0) * dx + (py - y0) * dy) / l2, 0, 1)
    d2 = (px - (x0 + u * dx)) ** 2 + (py - (y0 + u * dy)) ** 2
    return d2 <= (t * 0.5) ** 2


def m_curve(w, h, pts, t0=2.0, t1=None):
    """Thick polyline through pts, tapering from t0 to t1."""
    t1 = t0 if t1 is None else t1
    out = np.zeros((h, w), bool)
    n = len(pts) - 1
    for i in range(n):
        a = t0 + (t1 - t0) * i / max(1, n)
        out |= m_line(w, h, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], a)
        out |= m_ellipse(w, h, pts[i][0], pts[i][1], a * 0.5, a * 0.5)
    return out


def shift(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(0, dy), min(h, h + dy))
    xs = slice(max(0, dx), min(w, w + dx))
    yo = slice(max(0, -dy), min(h, h - dy))
    xo = slice(max(0, -dx), min(w, w - dx))
    out[ys, xs] = mask[yo, xo]
    return out


def grow(mask, n=1):
    out = mask.copy()
    for _ in range(n):
        out = out | shift(out, 1, 0) | shift(out, -1, 0) | shift(out, 0, 1) | shift(out, 0, -1)
    return out


def bbox(mask):
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return 0, 0, 1, 1
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


# ---- painting ----
def put(img: Img, mask, col):
    img.a[mask] = col


def paint(img: Img, mask, ramp, form="flat", base=2):
    """Fill `mask` with the material. Steps: 0 deep shadow .. 4 highlight; `base` is the local colour."""
    r = RAMP[ramp] if isinstance(ramp, str) else ramp
    if not mask.any():
        return np.zeros(mask.shape, np.int8)
    h, w = mask.shape
    xx, yy = grid(w, h)
    x0, y0, x1, y1 = bbox(mask)
    lvl = np.full((h, w), base, np.int8)
    if form == "round":
        dx = (xx + 0.5 - (x0 + x1) * 0.5) / max(1.0, (x1 - x0) * 0.5)
        dy = (yy + 0.5 - (y0 + y1) * 0.5) / max(1.0, (y1 - y0) * 0.5)
        s = dx * 0.45 + dy * 0.8
        lvl[s < -0.62] = base + 2
        lvl[(s >= -0.62) & (s < -0.2)] = base + 1
        lvl[(s >= 0.38) & (s < 0.8)] = base - 1
        lvl[s >= 0.8] = base - 2
    elif form == "wall":
        # upright surface: lighter band under the top edge, darker foot
        t = (yy - y0) / max(1.0, (y1 - y0))
        lvl[t > 0.82] = base - 1
    elif form == "ground":
        t = (yy - y0) / max(1.0, (y1 - y0))
        lvl[t < 0.12] = base + 1
    # edges: lit on top/left, shaded on bottom/right (2 px at the bottom for weight)
    up = ~shift(mask, 0, 1)
    left = ~shift(mask, 1, 0)
    down = ~shift(mask, 0, -1)
    right = ~shift(mask, -1, 0)
    down2 = ~shift(mask, 0, -2)
    lvl[mask & (up | left)] += 1
    lvl[mask & (down | right)] -= 1
    if form != "ground":
        lvl[mask & down2 & ~down & ~(up | left)] -= 1
    lvl = np.clip(lvl, 0, len(r) - 1)
    for i, col in enumerate(r):
        img.a[mask & (lvl == i)] = col
    return np.where(mask, lvl, -1).astype(np.int8)


def step(img: Img, mask, ramp, lvl, d):
    """Move the pixels of `mask` d steps along the ramp (texture). lvl is the level map returned by paint()."""
    r = RAMP[ramp] if isinstance(ramp, str) else ramp
    sel = mask & (lvl >= 0)
    nl = np.clip(lvl + d, 0, len(r) - 1)
    for i, col in enumerate(r):
        img.a[sel & (nl == i)] = col
    lvl[sel] = nl[sel]


def rim(img: Img, mask, col=INK, only_empty=False):
    edge = grow(mask) & ~mask
    if only_empty:
        edge &= img.a[..., 3] == 0
    img.a[edge] = col


def mass(img: Img, mask, ramp, form="flat", ink=None, base=2):
    """Paint a mass and (optionally) its contour. Returns the level map for textures."""
    lvl = paint(img, mask, ramp, form, base)
    if ink is not None:
        rim(img, mask, ink)
    return lvl


def shadow(img: Img, mask, a=70, col=(40, 30, 40)):
    """Soft-edged contact shadow (flat alpha) on empty pixels only."""
    sel = mask & (img.a[..., 3] == 0)
    img.a[sel] = (col[0], col[1], col[2], a)


# ---- textures (masks to feed step()) ----
def t_bricks(w, h, bw=8, bh=4, ox=0, oy=0):
    xx, yy = grid(w, h)
    row = (yy - oy) // bh
    mortar_h = (yy - oy) % bh == bh - 1
    mortar_v = (xx - ox + (row % 2) * (bw // 2)) % bw == bw - 1
    return mortar_h | mortar_v


def t_planks(w, h, pw=6, ox=0, vertical=True):
    xx, yy = grid(w, h)
    return ((xx - ox) % pw == pw - 1) if vertical else ((yy - ox) % pw == pw - 1)


def t_shingles(w, h, sw=8, sh=5, ox=0, oy=0):
    xx, yy = grid(w, h)
    row = (yy - oy) // sh
    lx = (xx - ox + (row % 2) * (sw // 2)) % sw
    ly = (yy - oy) % sh
    # scalloped lower edge of each tile
    return (ly == sh - 1) & (lx != 0) | (lx == 0) & (ly >= 1)


def t_scores(w, h, gap=9, ox=0, slope=1.0):
    xx, yy = grid(w, h)
    return ((xx - ox + (yy * slope).astype(int)) % gap) < 2


def t_spots(w, h, seed, density=0.03, size=1):
    rng = np.random.default_rng(seed)
    pts = rng.random((h, w)) < density
    out = pts.copy()
    for _ in range(size - 1):
        out |= shift(out, 1, 0) | shift(out, 0, 1)
    return out


def t_rows(w, h, gap=5, oy=0):
    _, yy = grid(w, h)
    return (yy - oy) % gap == 0
