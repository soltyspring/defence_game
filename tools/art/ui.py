"""UI art: resource/skill/unit icons, card portraits, 9-slice frames, bars,
digits (owner: 03-art). 04 implements layout/behaviour; these are just images.
Sizes are authored for the 640x360 reference view (integer-scaled on device).
"""
from __future__ import annotations

import math

import numpy as np

from pixel import Canvas, Sprite, c


def S(t):
    return Sprite.parse(t)


def _icon(sprite: Sprite, w=16, h=16, outline=True):
    cv = Canvas(w, h)
    cv.stamp(sprite, (w - sprite.w) // 2, (h - sprite.h) // 2)
    if outline:
        cv.outline(c("K"))
    return cv


ICONS16 = {
    "icon_gold": S("""
...yyyy...
..yYYYYy..
.yYZZYYYy.
yYZYYYYYYy
yYZYyyYYYy
yYYYyYYYYy
yYYYyyYYYy
yYYYYYYYyy
.yYYYYYyy.
..yyyyyy..
"""),
    "icon_mana": S("""
....c....
...cCB...
..cCCBb..
.cCCCBBb.
cCCCCBBbb
.CCCBBbb.
..CBBbb..
...Bbb...
....b....
"""),
    "icon_worker": S("""
...YYYY....
..YZZZZY...
.yYYYYYYy..
..LLLLL....
.hSLKLS..M.
.hSSSSs.MN.
..sSSs.Mm..
..oTTo.O...
.oTTTTO....
"""),
    "icon_star": S("""
....Y....
....Z....
...YZY...
YYYZZZYYY
.yYZZZYy.
..yYZYy..
..YYyYY..
.YYy.yYY.
.y.....y.
"""),
    "icon_star_empty": S("""
....A....
....A....
...AaA...
AAAAaAAAA
.AaaaaaA.
..AaaaA..
..AAaAA..
.AA...AA.
.A.....A.
"""),
    "icon_heart": S("""
.RR...RR.
REeR.RERr
REeERREEr
RREEEEERr
.RRRERRr.
..RRRRr..
...RRr...
....r....
"""),
    "icon_lock": S("""
..mmmm..
.m....m.
.m....m.
YYYYYYYY
YZZYYYYy
YZYwwYYy
YYYwwYYy
YYYYYYYy
yyyyyyyy
"""),
    "icon_pause": S("""
WW..WW
WW..WW
WW..WW
WW..WW
WW..WW
WW..WW
WW..WW
"""),
    "icon_play": S("""
W.....
WWW...
WWWWW.
WWWWWW
WWWWW.
WWW...
W.....
"""),
    "icon_speed_1x": S("""
.W.....
WW..W.W
.W..W.W
.W...W.
.W..W.W
WWW.W.W
"""),
    "icon_speed_2x": S("""
WWW......
...W.W.W.
.WW..W.W.
W.....W..
W....W.W.
WWWW.W.W.
"""),
    "icon_settings": S("""
...WW...
.W.WW.W.
..WWWW..
WWW..WWW
WWW..WWW
..WWWW..
.W.WW.W.
...WW...
"""),
    "icon_home": S("""
....W....
...WWW...
..WWWWW..
.WWWWWWW.
WWWWWWWWW
.WWW.WWW.
.WWW.WWW.
.WWW.WWW.
"""),
    "icon_retry": S("""
..WWWW.W
.W....WW
W....WWW
W.......
W.......
W......W
.W....W.
..WWWW..
"""),
    "icon_close": S("""
W.....W
.W...W.
..W.W..
...W...
..W.W..
.W...W.
W.....W
"""),
    "icon_sound": S("""
...W..W.
..WW...W
WWWW.W.W
WWWW.W.W
WWWW.W.W
..WW...W
...W..W.
"""),
    "icon_sound_off": S("""
...W....
..WW.E.E
WWWW..E.
WWWW..E.
WWWW.E.E
..WW....
...W....
"""),
    "icon_skull": S("""
.UUUUU.
UUUUUUU
UKKUKKU
UKKUKKU
UUUKUUU
.UUUUU.
.U.U.U.
"""),
    "icon_crown": S("""
Y..Y..Y
YY.Y.YY
YZYYYZY
YYYYYYY
yYEYEYy
yyyyyyy
"""),
    "icon_army": S("""
..mMMm..
.mMNNWm.
mMMMMMMm
.BBCCCB.
.BBCCCB.
.bBBBBb.
"""),
    "icon_gem": S("""
..vvv..
.vVVVv.
vVvVVPp
VVVVPPp
.VVPPp.
..PPp..
...p...
"""),
}
# aliases (same pixels, deduped in the atlas): 01 names supply/energy, 02 names gold/mana
ALIASES = {"icon_supply": "icon_gold", "icon_energy": "icon_mana"}


def icons16():
    out = {}
    for k, s in ICONS16.items():
        out[k] = _icon(s)
    for a, k in ALIASES.items():
        out[a] = out[k]
    return out


# --- 24x24 framed skill icons --------------------------------------------------
def framed(w, h, bg="b", rim="B", hi="C"):
    cv = Canvas(w, h)
    cv.rect(1, 1, w - 2, h - 2, c(bg))
    cv.hline(1, w - 2, 0, c("K")); cv.hline(1, w - 2, h - 1, c("K"))
    cv.vline(0, 1, h - 2, c("K")); cv.vline(w - 1, 1, h - 2, c("K"))
    cv.hline(2, w - 3, 1, c(hi)); cv.vline(1, 2, h - 3, c(hi))
    cv.hline(2, w - 3, h - 2, c(rim)); cv.vline(w - 2, 2, h - 3, c(rim))
    return cv


def skill_slam():
    cv = framed(24, 24, "p", "P", "V")
    # sword plunging down into ground
    cv.vline(12, 3, 14, c("N")); cv.vline(13, 3, 14, c("M"))
    cv.hline(9, 16, 4, c("Y")); cv.vline(12, 1, 3, c("O")); cv.put(12, 1, c("Y"))
    cv.rect(2, 17, 20, 5, c("O")); cv.hline(2, 21, 17, c("F"))
    for (x, y) in [(12, 16), (10, 18), (9, 19), (14, 18), (16, 19), (17, 20), (7, 20)]:
        cv.put(x, y, c("Z"))
    for dx in (-1, 1):
        for i in range(1, 5):
            cv.put(12 + dx * (3 + i * 2), 15 - i, c("Z" if i < 3 else "e"))
    return cv


def skill_rally():
    cv = framed(24, 24, "r", "R", "E")
    cv.vline(7, 3, 20, c("o"))
    cv.put(7, 2, c("Y"))
    for y in range(4, 13):
        w = 10 - max(0, y - 10) * 3
        cv.hline(8, 8 + w, y, c("B" if y % 4 else "C"))
    for (dx, dy) in [(3, 2), (4, 3), (5, 2), (3, 6), (4, 7), (5, 6)]:
        cv.put(8 + dx, 4 + dy - 1, c("Z"))
    for k in range(3):
        y = 20 - k * 3
        cv.put(17, y - 1, c("Z")); cv.put(16, y, c("Y")); cv.put(18, y, c("Y"))
    return cv


def skill_barrage():
    cv = framed(24, 24, "b", "B", "C")
    for (x0, y0) in [(5, 2), (11, 4), (16, 1)]:
        cv.line(x0, y0, x0 + 3, y0 + 9, c("o"))
        cv.put(x0 + 3, y0 + 10, c("W"))
        cv.put(x0 - 1, y0, c("c")); cv.put(x0 + 1, y0 - 1, c("c"))
    cv.ellipse(12, 19, 8, 3, c("E"))
    cv.ellipse(12, 19, 5, 2, c("e"))
    cv.ellipse(12, 19, 2, 1, c("Z"))
    return cv


# --- 9-slice frames --------------------------------------------------------------
def nine(w, h, m, fill, rim, hi, lo, outline="K"):
    cv = Canvas(w, h)
    cv.rect(1, 1, w - 2, h - 2, c(fill))
    cv.hline(2, w - 3, 0, c(outline)); cv.hline(2, w - 3, h - 1, c(outline))
    cv.vline(0, 2, h - 3, c(outline)); cv.vline(w - 1, 2, h - 3, c(outline))
    for (x, y) in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)]:
        cv.put(x, y, c(outline))
    cv.hline(2, w - 3, 1, c(hi)); cv.vline(1, 2, h - 3, c(hi))
    cv.hline(2, w - 3, h - 2, c(lo)); cv.vline(w - 2, 2, h - 3, c(lo))
    if rim:
        cv.hline(2, w - 3, h - 3, c(rim))
    return cv


def frames9():
    out = {}
    m = 5
    out["btn"] = (nine(16, 16, m, "B", "b", "C", "b"), (m, m, m, m))
    out["btn_pressed"] = (nine(16, 16, m, "b", None, "b", "B"), (m, m, m, m))
    out["btn_disabled"] = (nine(16, 16, m, "A", "a", "X", "a"), (m, m, m, m))
    out["btn_gold"] = (nine(16, 16, m, "Y", "y", "Z", "y"), (m, m, m, m))
    out["panel"] = (nine(24, 24, 8, "U", "T", "U", "o"), (8, 8, 8, 8))
    out["panel_dark"] = (nine(24, 24, 8, "p", None, "P", "K"), (8, 8, 8, 8))
    # card: frame with dark inset for the portrait
    card = nine(20, 24, 6, "b", "b", "C", "b")
    out["card_frame"] = (card, (6, 6, 6, 6))
    out["card_frame_disabled"] = (nine(20, 24, 6, "a", "a", "A", "a"), (6, 6, 6, 6))
    sel = nine(20, 24, 6, "y", "y", "Z", "y")
    out["card_frame_selected"] = (sel, (6, 6, 6, 6))
    # bars
    bar = Canvas(12, 8)
    bar.rect(1, 1, 10, 6, c("a"))
    bar.hline(1, 10, 0, c("K")); bar.hline(1, 10, 7, c("K")); bar.vline(0, 1, 6, c("K")); bar.vline(11, 1, 6, c("K"))
    bar.hline(1, 10, 1, c("K"))
    out["bar_frame"] = (bar, (3, 3, 3, 3))
    return out


def bar_fills():
    out = {}
    for name, (lo, mid, hi) in {"bar_fill_ally": ("G", "F", "f"), "bar_fill_enemy": ("r", "R", "E"),
                                "bar_fill_mana": ("b", "C", "c"), "bar_fill_gold": ("y", "Y", "Z"),
                                "bar_fill_cooldown": ("a", "A", "X")}.items():
        cv = Canvas(4, 6)
        cv.rect(0, 0, 4, 6, c(mid))
        cv.hline(0, 3, 0, c(hi))
        cv.hline(0, 3, 5, c(lo))
        cv.hline(0, 3, 4, c(lo))
        out[name] = cv
    return out


# --- hero move buttons (32x32) ---------------------------------------------------
def move_button(direction):
    cv = Canvas(32, 32)
    cv.ellipse(16, 16, 15, 15, c("K"))
    cv.ellipse(16, 16, 14, 14, c("b"))
    cv.ellipse(15.5, 15, 13, 12.5, c("B"))
    cv.ellipse(13, 11, 6, 4, c("C"))
    # right-pointing arrow head + shaft
    for y in range(8, 25):
        d = abs(y - 16)
        cv.hline(14, 22 - d, y, c("W"))
    cv.rect(8, 13, 7, 7, c("W"))
    cv.hline(8, 14, 19, c("j"))
    for y in range(17, 25):
        d = abs(y - 16)
        cv.put(22 - d, y, c("j"))
    if direction < 0:
        cv.flip_h()
    return cv


# --- digits 5x7 with outline -> 7x9 cells -----------------------------------------
DIGITS = {
    "0": ["WWW", "W.W", "W.W", "W.W", "WWW"], "1": [".W.", "WW.", ".W.", ".W.", "WWW"],
    "2": ["WWW", "..W", "WWW", "W..", "WWW"], "3": ["WWW", "..W", ".WW", "..W", "WWW"],
    "4": ["W.W", "W.W", "WWW", "..W", "..W"], "5": ["WWW", "W..", "WWW", "..W", "WWW"],
    "6": ["WWW", "W..", "WWW", "W.W", "WWW"], "7": ["WWW", "..W", ".W.", ".W.", ".W."],
    "8": ["WWW", "W.W", "WWW", "W.W", "WWW"], "9": ["WWW", "W.W", "WWW", "..W", "WWW"],
    "plus": ["...", ".W.", "WWW", ".W.", "..."], "minus": ["...", "...", "WWW", "...", "..."],
    "slash": ["..W", "..W", ".W.", "W..", "W.."], "x": ["...", "W.W", ".W.", "W.W", "..."],
}


def digits(col="W", name_prefix="digit_"):
    out = {}
    for k, rows in DIGITS.items():
        cv = Canvas(5, 7)
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch == "W":
                    cv.put(i + 1, j + 1, c(col))
        cv.outline(c("K"))
        out[name_prefix + k] = cv
    return out


# --- portraits cropped from character idle frames -------------------------------
def portrait(frame: np.ndarray, bg="b", rim="B", hi="C", size=24, head_rows=20):
    ys, xs = np.nonzero(frame)
    top = ys.min()
    cx = int(np.median(xs[ys < top + 12]))
    crop = Canvas(size - 4, size - 4)
    sub = frame[top:top + size - 4, :]
    x0 = cx - (size - 4) // 2
    for j in range(sub.shape[0]):
        for i in range(size - 4):
            xx = x0 + i
            if 0 <= xx < frame.shape[1] and sub[j, xx]:
                crop.put(i, j + 1, int(sub[j, xx]))
    cv = framed(size, size, bg, rim, hi)
    inner = Canvas(size - 4, size - 4)
    inner.a = crop.a
    cv.stamp(__import__("pixel").Sprite(inner.a), 2, 2)
    # re-draw frame edges over overflowing pixels
    f = framed(size, size, bg, rim, hi)
    for (x, y) in [(x, y) for x in range(size) for y in range(size) if x in (0, 1, size - 2, size - 1) or y in (0, 1, size - 2, size - 1)]:
        cv.put(x, y, int(f.a[y, x]))
    return cv
