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
...WWWW....
..WWWWWW...
.xWWWWWWx..
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
....X....
....X....
...XaX...
XXXXaXXXX
.XaaaaaX.
..XaaaX..
..XXaXX..
.XX...XX.
.X.....X.
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
ALIASES = {"icon_energy": "icon_mana"}
# in-round supply = 밀가루/Flour (01 R4, D25): a tied flour sack with a wheat mark and a puff
ICONS16["icon_supply"] = S("""
...oOo.W..
..oUUUoWW.
...OoO..W.
..oUUUUo..
.oUUUUUUo.
oUUWyUUUUo
oUWyYyUUUo
oUUUyUUUTo
oUUUUUUTTo
.ooooooOo.
""")
# art 0.12.1: mould nest for an optional right-edge indicator (04 A11); same shapes as base_enemy
ICONS16["icon_nest"] = S("""
.tz...........
.ll...........
.Dl.....t.....
..D....lD.....
..D..DDlDD....
..DDDllllDD...
.DDlltlllllD..
DDllllltllllD.
DKKKlllllllDD.
DKQKDlltlllDD.
DKKKDllllllDD.
.DDDDDDDDDDD..
""")
# allied army icon: toast-helmet soldier in egg-wash gold (was steel + blue tabard)
ICONS16["icon_army"] = S("""
..oo.oo..
.oTToTTo.
.oTTTTTo.
.oUUUUUo.
.YYZZZYY.
.YYZZZYY.
.yYYYYYy.
""")


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
    """밀대 내려찍기: rolling pin coming down on the ground, flour puff (art 0.11.0).
    ui-art 1.0: plate O -> dark crust h (glyph 1.88:1 -> >= 4.5:1), ground lit with a T top edge."""
    cv = framed(24, 24, "h", "w", "O")
    cv.rect(2, 18, 20, 4, c("w")); cv.hline(2, 21, 18, c("T"))
    # rolling pin, diagonal, barrel 3 px thick, handles at both ends
    for t in range(0, 15):
        x, y = 4 + t, 3 + t * 0.85
        for s_, k in ((-1, "U"), (0, "T"), (1, "o")):
            if 2 <= t <= 12:
                cv.put(round(x + s_ * 0.6), round(y - s_), c(k))
            elif s_ == 0:
                cv.put(round(x), round(y), c("w"))
    for (x, y, k) in [(17, 17, "W"), (19, 16, "W"), (21, 17, "U"), (14, 17, "U"), (12, 16, "W"), (20, 14, "U"),
                      (15, 15, "U"), (9, 17, "U")]:
        cv.put(x, y, c(k))
    return cv


def skill_rally():
    """갓 구운 함성: cream banner with egg-wash stripes and rising steam."""
    cv = framed(24, 24, "r", "R", "E")
    cv.vline(7, 3, 20, c("o"))
    cv.put(7, 2, c("Y"))
    for y in range(4, 13):
        w = 10 - max(0, y - 10) * 3
        cv.hline(8, 8 + w, y, c("U" if y % 4 else "Y"))
    for (dx, dy) in [(3, 2), (4, 3), (5, 2), (3, 6), (4, 7), (5, 6)]:
        cv.put(8 + dx, 4 + dy - 1, c("o"))
    for k in range(3):
        y = 20 - k * 3
        cv.put(17, y - 1, c("W")); cv.put(16, y, c("U")); cv.put(18, y, c("U"))
    return cv


def skill_barrage():
    """빵가루 포격: three crumb shells falling into a crumb burst.
    ui-art 1.0: plate y -> night purple p (glyph 2.33:1 -> >= 4.5:1), so the gold shells read on the blue button."""
    cv = framed(24, 24, "p", "K", "P")
    for (x0, y0) in [(4, 2), (10, 4), (15, 1)]:
        cv.put(x0, y0, c("Z")); cv.put(x0 + 1, y0 + 2, c("Z"))
        cv.ellipse(x0 + 2.5, y0 + 6.5, 2.0, 2.0, c("T"))
        cv.put(x0 + 2, y0 + 6, c("U")); cv.put(x0 + 3, y0 + 7, c("o"))
    cv.ellipse(12, 19, 8, 3, c("o"))
    cv.ellipse(12, 19, 5, 2, c("T"))
    cv.ellipse(12, 19, 2, 1, c("W"))
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
    out["btn"] = (nine(16, 16, m, "O", "w", "o", "w"), (m, m, m, m))            # crust (art 0.11.0; was blue)
    out["btn_pressed"] = (nine(16, 16, m, "w", None, "w", "O"), (m, m, m, m))
    out["btn_disabled"] = (nine(16, 16, m, "a", "a", "A", "K"), (m, m, m, m))   # dark slate: text 5.8:1, dL* 12.7 vs btn
    out["btn_gold"] = (nine(16, 16, m, "Y", "y", "Z", "y"), (m, m, m, m))
    out["panel"] = (nine(24, 24, 8, "U", "T", "U", "o"), (8, 8, 8, 8))
    out["panel_dark"] = (nine(24, 24, 8, "w", None, "O", "K"), (8, 8, 8, 8))   # dark crust (was purple)
    # card: frame with dark inset for the portrait
    card = nine(20, 24, 6, "O", "w", "o", "w")
    out["card_frame"] = (card, (6, 6, 6, 6))
    out["card_frame_disabled"] = (nine(20, 24, 6, "a", "a", "A", "a"), (6, 6, 6, 6))
    sel = nine(20, 24, 6, "Y", "y", "Z", "y")          # butter fill: dark text 8.5:1 (was 3.5:1 on y)
    out["card_frame_selected"] = (sel, (6, 6, 6, 6))
    # bars
    bar = Canvas(12, 8)
    bar.rect(1, 1, 10, 6, c("a"))
    bar.hline(1, 10, 0, c("K")); bar.hline(1, 10, 7, c("K")); bar.vline(0, 1, 6, c("K")); bar.vline(11, 1, 6, c("K"))
    bar.hline(1, 10, 1, c("K"))
    out["bar_frame"] = (bar, (3, 3, 3, 3))
    # result ribbons (victory/defeat banners), 9-slice horizontally
    for name, (mid, lo, hi) in {"ribbon_victory": ("Y", "y", "Z"), "ribbon_defeat": ("R", "r", "E")}.items():
        rb = Canvas(32, 16)
        rb.rect(4, 2, 24, 11, c(mid))
        rb.hline(4, 27, 2, c(hi)); rb.hline(4, 27, 12, c(lo))
        for x0, d in ((0, 1), (31, -1)):     # swallow-tail ends
            for i in range(4):
                xx = x0 + d * i
                rb.vline(xx, 4 + (i == 0), 14 - (i == 0), c(lo))
            rb.put(x0, 9, 0); rb.put(x0 + d, 9, 0)
        rb.outline(c("K"))
        out[name] = (rb, (8, 4, 8, 4))
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
    """ui-art 1.0: light baked bun (T, U gloss, o crust ring) with a dark w arrow. Before: dark crust bun
    (w/O) with a white arrow, the same value as 04's button box (#694226) and the dirt (#9f6d42)."""
    cv = Canvas(32, 32)
    cv.ellipse(16, 16, 15, 15, c("K"))
    cv.ellipse(16, 16, 14, 14, c("o"))
    cv.ellipse(15.5, 15, 13, 12.5, c("T"))
    cv.ellipse(12, 10, 6, 3.5, c("U"))
    # right-pointing arrow head + shaft
    for y in range(8, 25):
        d = abs(y - 16)
        cv.hline(14, 22 - d, y, c("w"))
    cv.rect(8, 13, 7, 7, c("w"))
    cv.hline(8, 14, 19, c("K"))
    for y in range(17, 25):
        d = abs(y - 16)
        cv.put(22 - d, y, c("K"))
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
def portrait(frame: np.ndarray, bg="O", rim="w", hi="o", size=24, head_rows=20):   # ally = crust (art 0.11.0)
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


# --- deploy-card badges (06-art-ui, ui-art 1.0; criteria docs/art/ui/UI_ART_CRITERIA.md) -----------
# Before: every card_<unit> was the same brown square (#6e4528) on a card body of nearly the same brown
# (#694226 measured), so the row differed only by the small figure. Now each unit has its own badge
# silhouette AND its own light plate colour: the row reads by shape alone (colour-blind safe) and by
# colour alone. Plates are >= 3:1 against the card body; figures keep their K outline, so the figure edge
# is >= 6:1 on every plate. Size 24x24 and the frame names are unchanged (ATLAS_CONTRACT).
CARD_STYLE = {
    # uid:          (shape,    plate, highlight, shadow)   theme cue
    "worker":       ("circle", "U", "W", "T"),   # flour-cream round bun (economy)
    "melee_basic":  ("toast",  "S", "L", "s"),   # toast-slice silhouette, crust terracotta
    "ranged_basic": ("ticket", "f", "z", "F"),   # bread-roll ticket with side bites, field green
    "tank":         ("shield", "N", "W", "M"),   # loaf shield, steel
    "fast":         ("banner", "v", "J", "V"),   # pretzel charge pennant, lavender
    "siege":        ("arch",   "Y", "Z", "y"),   # brick-oven mouth, fire gold
    "hero_captain": ("octagon", "Z", "W", "Y"),  # head baker, butter gold (not in the deploy row)
}
# crop window (default: top-aligned on the head, like portrait()). The oven cannon is 40 px wide with the
# rolling-pin barrel on top, so its card shows the oven front (fire door) instead of the barrel tip.
CARD_CROP = {"siege": ("bbox", 17, 2)}   # (window mode, rows below the sprite top, extra plate rings)


def badge_mask(shape: str, n: int = 24) -> np.ndarray:
    """Filled silhouette (bool n x n) of a card badge. Pixel-centre geometry, deterministic.
    Pairwise IoU of the six deploy shapes <= 0.78 (tools/art/ui_art/card_preview.py)."""
    yy, xx = np.mgrid[0:n, 0:n]
    u = xx + 0.5 - n / 2
    v = yy + 0.5 - n / 2
    h = n / 2 - 0.5                                     # 11.5 = outermost pixel centre
    au, av = np.abs(u), np.abs(v)
    if shape == "circle":
        m = u * u + v * v <= (h - 0.4) ** 2
    elif shape == "toast":                              # toast slice: crown wider than the body
        m = ((au <= h - 3) & (v >= -4)) | ((u / (h + 0.4)) ** 2 + ((v + 6.0) / 6.0) ** 2 <= 1)
    elif shape == "ticket":                             # rounded tile with a round bite on each side
        m = (av <= h - 2) & (u * u + v * v <= 400) & ~(((au - h) ** 2 + v * v) <= 9)
    elif shape == "shield":                             # flat top, sides taper to a point at the bottom
        t = np.clip((v + 4.0) / (h + 4.0), 0, 1)
        m = au <= h * (1 - t ** 1.2) + 0.3
    elif shape == "banner":                             # pennant with a swallow-tail notch at the bottom
        m = (au <= h - 1) & ~(v > (h - 8) + au * 0.75)
    elif shape == "arch":                               # oven mouth: semicircular top, flat bottom
        m = (v >= 1.5) | (u * u + (v - 1.5) ** 2 <= (h + 0.4) ** 2)
    elif shape == "octagon":
        m = au + av <= 1.45 * h
    else:
        raise ValueError(shape)
    return m


def _erode(m: np.ndarray) -> np.ndarray:
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def card(uid: str, frame: np.ndarray, size: int = 24) -> Canvas:
    """card_<uid>: the unit's own badge (shape + plate colour) with the idle-frame head/torso crop.

    Unknown ids fall back to portrait() so the atlas never loses a frame."""
    st = CARD_STYLE.get(uid)
    if st is None:
        return portrait(frame, size=size)
    shape, plate, hi, lo = st
    m = badge_mask(shape, size)
    inner = _erode(m)
    edge = m & ~inner
    cv = Canvas(size, size)
    cv.a[inner] = c(plate)
    # 1-px bevel on the plate: light where the outline is above/left, dark where it is below/right
    pe = np.pad(edge, 1, constant_values=True)
    cv.a[inner & (pe[:-2, 1:-1] | pe[1:-1, :-2])] = c(hi)
    cv.a[inner & (pe[2:, 1:-1] | pe[1:-1, 2:])] = c(lo)
    # figure: same crop as portrait() (top-aligned, centred on the head), shifted 1 px down and clipped so the
    # bevel and one plate ring stay visible all round; then a 1-px K "sticker" outline wherever a figure pixel
    # that is not already outline touches the plate (cut edges of the crop included).
    allowed = _erode(_erode(inner))
    ys, xs = np.nonzero(frame)
    top = ys.min()
    cx = int(np.median(xs[ys < top + 12]))
    if uid in CARD_CROP:                        # ("bbox", rows below the sprite top, extra plate rings)
        _mode, dy, extra = CARD_CROP[uid]
        cx = (int(xs.min()) + int(xs.max())) // 2
        top = int(ys.min()) + dy
        for _ in range(extra):
            allowed = _erode(allowed)
    w = size - 4
    x0 = cx - w // 2
    fig = np.zeros_like(m)
    for j in range(w):
        sy = top + j
        if sy >= frame.shape[0]:
            break
        for i in range(w):
            sx = x0 + i
            if 0 <= sx < frame.shape[1] and frame[sy, sx]:
                X, Y = i + 2, j + 4
                if 0 <= X < size and 0 <= Y < size and allowed[Y, X]:
                    cv.a[Y, X] = int(frame[sy, sx])
                    fig[Y, X] = True
    k = c("K")
    soft = fig & (cv.a != k)
    sp = np.pad(soft, 1, constant_values=False)
    near = sp[:-2, 1:-1] | sp[2:, 1:-1] | sp[1:-1, :-2] | sp[1:-1, 2:]
    cv.a[near & inner & ~fig] = k
    cv.a[edge] = k
    return cv
