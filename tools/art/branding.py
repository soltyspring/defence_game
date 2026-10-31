"""Title logo + app icon candidate (owner: 03-art, art 0.10.0).

Working title (user Q3, 2026-10-31 16:19 KST): "빵집 기사단: 곰팡이 디펜스" /
"Bakery Knights: Mold Defense". The final store name waits for the human KIPRIS check
(classes 9/41), so these files are WORKING-TITLE art.

Letters: glyph masks rendered from the shipped Galmuri11-Bold (SIL OFL 1.1) at its native
12 px grid with antialiasing off (binary), then integer-upscaled (x2 for the main words)
and painted pixel by pixel (crust/mould fills, outline, drop shadow). The OFL permits using
the font in images. No other font or image source is used.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from pixel import Canvas, c, IDX

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "Galmuri11-Bold.ttf")

KO_FULL = "빵집 기사단: 곰팡이 디펜스"
KO_A, KO_B = "빵집 기사단", "곰팡이 디펜스"
EN_FULL = "Bakery Knights: Mold Defense"
EN_A, EN_B = "Bakery Knights", "Mold Defense"


def glyph_mask(text: str, scale: int) -> np.ndarray:
    f = ImageFont.truetype(FONT, 12)
    im = Image.new("L", (12 * len(text) + 8, 20), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"                       # no antialiasing: native pixel glyphs
    d.text((2, 2), text, fill=255, font=f)
    a = np.array(im) > 0
    ys, xs = np.nonzero(a)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return np.kron(a, np.ones((scale, scale), bool))


CRUST = {"top": "U", "hi": "Z", "mid": "Y", "low": "T", "base": "o", "edge": "w", "shadow": "O"}
MOULD = {"top": "z", "hi": "t", "mid": "t", "low": "l", "base": "l", "edge": "D", "shadow": "D"}


def paint(mask: np.ndarray, scheme: dict, spores=False) -> Canvas:
    """Fill a glyph mask with a vertical ramp, 1 px top highlight, edge, outline, shadow."""
    h, w = mask.shape
    pad = 3
    cv = Canvas(w + 2 * pad, h + 2 * pad + 2)
    ox, oy = pad, pad
    rows = h
    for y in range(h):
        t = y / max(1, rows - 1)
        k = scheme["hi"] if t < 0.2 else scheme["mid"] if t < 0.55 else scheme["low"] if t < 0.85 else scheme["base"]
        for x in range(w):
            if mask[y, x]:
                cv.a[oy + y, ox + x] = IDX[k]
    # top highlight: mask pixels whose upper neighbour is empty
    up = np.zeros_like(mask)
    up[1:, :] = mask[:-1, :]
    ys, xs = np.nonzero(mask & ~up)
    for y, x in zip(ys, xs):
        cv.a[oy + y, ox + x] = IDX[scheme["top"]]
    # inner edge on the right/bottom side
    rt = np.zeros_like(mask)
    rt[:, :-1] = mask[:, 1:]
    dn = np.zeros_like(mask)
    dn[:-1, :] = mask[1:, :]
    ys, xs = np.nonzero(mask & (~rt | ~dn) & up)
    for y, x in zip(ys, xs):
        cv.a[oy + y, ox + x] = IDX[scheme["edge"]]
    if spores:   # spore dots dripping from the lower edge of the mould letters
        bottoms = [x for x in range(w) if mask[h - 1, x]]
        for i, x in enumerate(bottoms[::7]):
            cv.put(ox + x, oy + h + 1 + (i % 2), c("t"))
    cv.outline(c("K"))
    # drop shadow: outline shifted down 2 px, under everything
    sh = Canvas(cv.w, cv.h)
    sh.a = np.where(cv.a > 0, IDX[scheme["shadow"]], 0).astype(np.uint8)
    sh.shift(0, 2)
    out = Canvas(cv.w, cv.h)
    out.a = np.where(cv.a > 0, cv.a, sh.a).astype(np.uint8)
    return out


def hstack(parts, gap=2, align="bottom") -> Canvas:
    W = sum(p.w for p in parts) + gap * (len(parts) - 1)
    H = max(p.h for p in parts)
    cv = Canvas(W, H)
    x = 0
    for p in parts:
        y = H - p.h if align == "bottom" else (H - p.h) // 2
        cv.stamp(__import__("pixel").Sprite(p.a), x, y)
        x += p.w + gap
    return cv


def vstack(parts, gap=0) -> Canvas:
    W = max(p.w for p in parts)
    H = sum(p.h for p in parts) + gap * (len(parts) - 1)
    cv = Canvas(W, H)
    y = 0
    for p in parts:
        cv.stamp(__import__("pixel").Sprite(p.a), (W - p.w) // 2, y)
        y += p.h + gap
    return cv


def logos():
    """Returns {frame_name: Canvas}."""
    out = {}
    # KO one line: "빵집 기사단:" crust x2 + "곰팡이 디펜스" mould x2
    a = paint(glyph_mask("빵집 기사단:", 2), CRUST)
    b = paint(glyph_mask(KO_B, 2), MOULD, spores=True)
    out["logo_title_ko"] = hstack([a, b], gap=4)
    # KO two lines (colon becomes the line break)
    out["logo_title_ko_2line"] = vstack([paint(glyph_mask(KO_A, 2), CRUST), paint(glyph_mask(KO_B, 2), MOULD, spores=True)], gap=-2)
    # EN: x2 one-line would be 390+ px (> 360) -> one-line EN at x1, two-line EN at x2/x1
    out["logo_title_en"] = hstack([paint(glyph_mask("Bakery Knights:", 1), CRUST), paint(glyph_mask(EN_B, 1), MOULD)], gap=3)
    out["logo_title_en_2line"] = vstack([paint(glyph_mask(EN_A, 2), CRUST), paint(glyph_mask(EN_B, 2), MOULD, spores=True)], gap=-2)
    return out


# ---------------------------------------------------------------------------------------
# App icon candidate: 48 px native pixel art; 96/192 are exact x2/x4 (nearest).
# Content inside the central 66 % (Android adaptive-icon safe zone ~ 32/48 px).
# Hero = 제빵 대장: chef hat under a crust helmet band, toast face, gold tabard, rolling pin
# raised; a mould blob peeks from the lower right. No gingerbread silhouette, no crown+shield.
# ---------------------------------------------------------------------------------------
def icon48(background_only=False) -> Canvas:
    cv = Canvas(48, 48)
    # background rounded square with warm vertical ramp
    for y in range(48):
        k = "o" if y < 16 else "O" if y < 34 else "w"     # dark warm ramp: light hero + mould both pop (dL)
        for x in range(48):
            r = 9
            dx = max(r - x, x - (47 - r), 0)
            dy = max(r - y, y - (47 - r), 0)
            if dx * dx + dy * dy <= r * r:
                cv.a[y, x] = IDX[k]
    # sun-burst stripes behind the hero (subtle)
    for x in range(48):
        for y in range(48):
            if cv.a[y, x] and ((x - y) // 4) % 3 == 0 and y < 30:
                cv.a[y, x] = IDX["T" if y < 16 else "o"]
    if background_only:
        return _border(cv)
    fg = Canvas(48, 48)
    # chef hat (puffy) + crust helmet band
    fg.ellipse(19, 10.5, 7, 4.0, c("W"))
    fg.ellipse(14, 12, 3.5, 3, c("W"))
    fg.ellipse(24, 12, 3.5, 3, c("W"))
    fg.ellipse(17, 9, 3, 1.8, c("x"))
    fg.rect(12, 14, 15, 4, c("o"))
    fg.hline(12, 26, 14, c("T"))
    fg.hline(12, 26, 17, c("O"))
    # toast face
    fg.rect(13, 18, 13, 9, c("U"))
    fg.vline(13, 18, 26, c("T")); fg.vline(25, 18, 26, c("T"))
    fg.hline(13, 25, 26, c("T"))
    fg.rect(21, 20, 2, 3, c("K"))                     # eye (facing right)
    fg.put(24, 23, c("e"))                            # cheek
    fg.hline(20, 23, 24, c("w"))                      # determined mouth
    # body: gold tabard with jam cross
    fg.rect(12, 27, 15, 11, c("Y"))
    fg.rect(12, 27, 15, 2, c("Z"))
    fg.vline(19, 29, 36, c("R")); fg.hline(16, 22, 31, c("R"))
    fg.rect(12, 36, 15, 2, c("o"))
    # crust pauldron (armour cue, 09 R09-03) + arm reaching to the pin
    fg.ellipse(14, 28, 4, 3, c("o")); fg.ellipse(13.5, 27, 2.5, 1.5, c("T"))
    fg.thick_line(23, 29, 26, 31, c("Y"), t=3)
    # rolling pin raised (diagonal), handles crust-dark
    for i in range(9):                                # barrel 4 px thick, tip inside the safe zone
        x, y = 27 + i, 28 - i
        fg.rect(x, y - 2, 4, 4, c("T"))
        fg.put(x, y - 2, c("U")); fg.put(x + 1, y - 2, c("U"))
    for (hx, hy) in ((24, 31), (36, 18)):             # dark handles at both ends
        fg.rect(hx, hy - 1, 3, 3, c("O")); fg.put(hx + 1, hy - 1, c("o"))
    fg.rect(26, 30, 3, 2, c("U"))                     # hand
    # mould blob peeking lower right
    fg.ellipse(34, 34, 6, 5.5, c("t"))               # light mould body (dL vs the dark warm bg)
    fg.ellipse(33, 32.5, 3.5, 2.6, c("z"))
    fg.hline(30, 38, 38, c("l"))
    fg.put(31, 31, c("z")); fg.put(36, 37, c("z")); fg.put(38, 32, c("z"))
    fg.rect(30, 34, 2, 2, c("K")); fg.rect(33, 34, 2, 2, c("K"))   # eyes looking at the hero
    fg.put(30, 33, c("E"))
    fg.shift(0, 1)                                    # keep content inside the 32x32 safe zone
    fg.outline(c("K"))
    cv.stamp(__import__("pixel").Sprite(fg.a), 0, 0)
    return _border(cv)


def _border(cv):
    ring = (cv.a > 0)
    inner = np.zeros_like(ring)
    inner[1:-1, 1:-1] = ring[1:-1, 1:-1] & ring[:-2, 1:-1] & ring[2:, 1:-1] & ring[1:-1, :-2] & ring[1:-1, 2:]
    cv.a[ring & ~inner] = IDX["w"]
    return cv


def write_icons(out_dir):
    from pixel import RGBA
    os.makedirs(out_dir, exist_ok=True)
    base = icon48()
    paths = {}
    for s in (48, 96, 192):
        k = s // 48
        a = np.kron(base.a, np.ones((k, k), np.uint8))
        p = os.path.join(out_dir, f"app_icon_candidate_{s}.png")
        Image.fromarray(RGBA[a], "RGBA").save(p)
        paths[s] = p
    return base, paths
