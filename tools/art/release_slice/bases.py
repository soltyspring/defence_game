"""The two bases, 96x128 frames, pivot (48, 127) = the contract of assets/atlases/bases.json.

    base_player  the bakery turned into a fort: stone oven floor with a lit arch, timber-and-plaster shop floor,
                 one huge crusty loaf for a roof, brick chimney, red awning and pennant. Faces right.
    base_enemy   the nest: root skirt, lumpy wet skin torn open over a breathing organ, a lopsided torn cap on a
                 thick neck, small caps behind. Faces left (the engine does not flip it).
States idle / damaged / ruined change the silhouette (roof bitten -> fallen, cap torn -> dropped), not the tint.
Two frames each: chimney smoke + oven flicker, and the organ's breath.
"""
from __future__ import annotations

import numpy as np

from lib import (INK, INK_MOULD, RAMP, Img, grow, hexc, m_curve, m_ellipse, m_line, m_poly, m_rect, mass, paint, put, rim,
                 shift, step, t_bricks, t_planks, t_scores, t_spots)

W, H = 96, 128
G = 127      # ground row


def _smoke(img, x, y, f, n=3):
    for i in range(n):
        r = 3 + i
        cx = x + i * 3 + (1 if f else 0)
        cy = y - i * 7 - (2 if f else 0)
        m = m_ellipse(W, H, cx, cy, r, r - 1)
        put(img, m, hexc("efe8d8"))
        put(img, m & shift(m, -1, -1) & ~shift(m, 1, 1), hexc("d5cdbd"))


def bakery(state: str, f: int) -> Img:
    img = Img(W, H)
    ruined = state == "ruined"
    hurt = state != "idle"

    # --- chimney (behind the roof) ---
    ch_top = 30 if state == "idle" else (44 if state == "damaged" else 78)
    ch = m_rect(W, H, 13, ch_top, 14, 104 - ch_top)
    lv = mass(img, ch, "brick", "wall", INK)
    step(img, ch & t_bricks(W, H, 7, 4, 13, ch_top), "brick", lv, -1)
    if state == "idle":
        cap = m_rect(W, H, 11, 26, 18, 5)
        mass(img, cap, "stone", "flat", INK, base=3)
        _smoke(img, 22, 20, f)
    elif state == "damaged":
        # broken lip: jagged top, a thin dark trail instead of the white puff
        put(img, m_poly(W, H, [(13, 44), (17, 48), (21, 43), (24, 49), (27, 44), (27, 40), (13, 40)]), (0, 0, 0, 0))
        for i in range(3):
            put(img, m_ellipse(W, H, 21 + i * 2 + f, 36 - i * 7, 2 + i, 2), hexc("8d8478"))

    # --- shop floor: plaster with timber frame ---
    if not ruined:
        body = m_rect(W, H, 14, 58, 70, 44)
    else:
        body = m_poly(W, H, [(14, 102), (14, 80), (22, 74), (30, 82), (40, 70), (50, 84), (62, 76), (70, 88), (84, 84), (84, 102)])
    lv = mass(img, body, "plaster", "wall", INK)
    for bx in (14, 36, 60, 80):
        beam = m_rect(W, H, bx, 58, 4, 44) & body
        paint(img, beam, "timber", "flat")
    paint(img, m_rect(W, H, 14, 76, 70, 3) & body, "timber", "flat")
    brace = (m_line(W, H, 19, 77, 35, 60, 2.2) | m_line(W, H, 65, 60, 79, 77, 2.2)) & body
    paint(img, brace, "timber", "flat")
    if not ruined:
        # two small windows upstairs: warm when the bakery works, dark when hit
        for wx in (22, 44):
            win = m_rect(W, H, wx, 62, 10, 11)
            paint(img, win, "timber", "flat", base=1)
            glass = m_rect(W, H, wx + 2, 64, 6, 7)
            put(img, glass, RAMP["fire"][3] if state == "idle" else hexc("4b4a55"))
            put(img, m_rect(W, H, wx + 4, 64, 1, 7), RAMP["timber"][1])
            if hurt and wx == 44:
                put(img, m_line(W, H, wx - 1, 60, wx + 9, 74, 1.6), RAMP["timber"][0])   # shutter hanging across
    step(img, body & t_spots(W, H, 5, 0.02), "plaster", lv, -1)

    # --- stone oven floor with the arch ---
    if not ruined:
        plinth = m_rect(W, H, 8, 98, 82, 30)
    else:
        plinth = m_poly(W, H, [(8, 128), (8, 104), (20, 98), (40, 100), (58, 98), (90, 106), (90, 128)])
    lv = mass(img, plinth, "stone", "wall", INK)
    step(img, plinth & t_bricks(W, H, 12, 6, 8, 98), "stone", lv, -1)
    ledge = m_rect(W, H, 6, 96, 86, 4)
    if not ruined:
        mass(img, ledge, "stone", "flat", INK, base=3)
    arch = (m_ellipse(W, H, 64, 112, 14, 14) | m_rect(W, H, 50, 112, 28, 16)) & m_rect(W, H, 0, 0, W, 128)
    mass(img, grow(arch, 2) & plinth, "brick", "flat", None, base=3)
    if not ruined:
        put(img, arch, RAMP["fire"][0])
        glow = m_ellipse(W, H, 64, 120, 11, 9 + f) & arch
        put(img, glow, RAMP["fire"][1] if hurt else RAMP["fire"][2])
        core = m_ellipse(W, H, 64 - f, 123, 6, 5) & arch
        put(img, core, RAMP["fire"][2] if hurt else RAMP["fire"][4])
        for gx in (56, 64, 72):                                          # iron grate bars
            put(img, m_rect(W, H, gx, 100, 1, 28) & arch, RAMP["iron"][1])
    else:
        put(img, arch, hexc("2b2327"))
        for i in range(3):
            put(img, m_ellipse(W, H, 62 + i * 3 + f, 96 - i * 8, 3 + i, 2 + i // 2), hexc("7d756c"))
    # service door on the keep side, flour sacks on the ledge
    door = m_rect(W, H, 20, 108, 14, 20) & plinth
    lvd = mass(img, door, "wood", "flat", None, base=2)
    step(img, door & t_planks(W, H, 5, 20), "wood", lvd, -1)
    put(img, m_rect(W, H, 30, 117, 2, 2) & door, RAMP["iron"][3])
    if not ruined:
        for sx, sw in ((9, 9), (17, 8), (38, 9)):
            sack = m_ellipse(W, H, sx + sw / 2, 93, sw / 2 + 0.5, 4)
            mass(img, sack, "sack", "round", INK)
            put(img, m_rect(W, H, int(sx + sw / 2) - 1, 88, 2, 2), RAMP["sack"][1])

    # --- awning over the arch ---
    if state == "idle":
        aw = m_poly(W, H, [(46, 92), (84, 92), (90, 101), (42, 101)])
        mass(img, aw, "cloth", "flat", INK, base=2)
        for i in range(4):
            stripe = m_poly(W, H, [(51 + i * 10, 92), (56 + i * 10, 92), (58 + i * 11, 101), (52 + i * 11, 101)]) & aw
            put(img, stripe, RAMP["crumb"][3])
    elif state == "damaged":
        aw = m_poly(W, H, [(46, 92), (66, 92), (64, 99), (58, 103), (52, 98), (42, 101)])
        mass(img, aw, "cloth", "flat", INK, base=1)

    # --- the loaf roof ---
    if state == "idle":
        roof = m_ellipse(W, H, 49, 60, 45, 34) & m_rect(W, H, 0, 0, W, 61)
    elif state == "damaged":
        roof = m_ellipse(W, H, 49, 60, 45, 34) & m_rect(W, H, 0, 0, W, 61)
        bite = m_ellipse(W, H, 74, 32, 15, 13) | m_poly(W, H, [(60, 26), (70, 40), (64, 46), (56, 36)])
        inner = roof & bite
        roof = roof & ~bite
    else:
        # what is left: one slab leaning on the walls, crust pieces on the ground
        roof = m_poly(W, H, [(6, 86), (10, 74), (24, 66), (42, 70), (36, 84), (20, 90)])
    lv = mass(img, roof, "crust", "round", INK, base=2)
    step(img, roof & t_scores(W, H, 13, 3, -0.8) & m_rect(W, H, 0, 0, W, 54), "crust", lv, 1)
    step(img, roof & t_spots(W, H, 11, 0.035), "crust", lv, 1)
    if state != "ruined":
        eave = m_rect(W, H, 4, 57, 90, 4) & grow(roof | m_rect(W, H, 4, 57, 90, 4), 0)
        if state == "damaged":
            eave &= ~m_rect(W, H, 68, 50, 30, 12)
        mass(img, eave, "crust", "flat", INK, base=1)
    if state == "damaged":
        put(img, inner & m_rect(W, H, 0, 0, W, 57), RAMP["timber"][0])
        put(img, inner & m_rect(W, H, 0, 0, W, 57) & t_planks(W, H, 6, 2), RAMP["timber"][2])
        crumbs = grow(roof, 2) & inner
        put(img, crumbs, RAMP["crumb"][2])
        rim(img, roof, INK)
    if ruined:
        for cx, cy, r in ((54, 123, 7), (72, 124, 5), (40, 125, 4), (84, 125, 4)):
            chunk = m_ellipse(W, H, cx, cy, r, r * 0.6)
            mass(img, chunk, "crust", "round", INK)
        for cx, cy in ((62, 118), (30, 122), (78, 119)):
            mass(img, m_rect(W, H, cx, cy, 6, 4), "stone", "flat", INK)

    # --- pennant and shop sign ---
    if state == "idle":
        put(img, m_rect(W, H, 58, 8, 2, 20), RAMP["timber"][1])
        rim(img, m_rect(W, H, 58, 8, 2, 20), INK, only_empty=True)
        flag = m_poly(W, H, [(60, 9), (76 - f, 12), (60, 18)])
        mass(img, flag, "cloth", "flat", INK, base=3)
        # pretzel sign on an iron arm
        put(img, m_rect(W, H, 84, 64, 10, 1), RAMP["iron"][1])
        sign = m_ellipse(W, H, 90, 71, 5, 5)
        mass(img, sign, "crust", "round", INK, base=3)
        put(img, m_rect(W, H, 88, 69, 2, 2) | m_rect(W, H, 91, 69, 2, 2) | m_rect(W, H, 89, 73, 3, 1), RAMP["crust"][0])
    elif state == "damaged":
        put(img, m_line(W, H, 56, 30, 50, 14, 2), RAMP["timber"][1])
        rim(img, m_line(W, H, 56, 30, 50, 14, 2), INK, only_empty=True)
    return img


def _ragged(mask, pts):
    """Tear triangles out of a mask's lower edge."""
    out = mask.copy()
    for (x, y, w, h) in pts:
        out &= ~m_poly(W, H, [(x, y), (x + w, y), (x + w / 2, y - h)])
    return out


def nest(state: str, f: int) -> Img:
    img = Img(W, H)
    ruined = state == "ruined"
    hurt = state != "idle"

    # --- small caps at the back (right) ---
    for cx, top, r in ((80, 58, 9), (88, 78, 6)):
        if ruined and cx == 80:
            continue
        stalk = m_curve(W, H, [(cx, 112), (cx + 1, (112 + top) // 2), (cx - 1, top + 3)], 4, 3)
        mass(img, stalk, "hypha", "flat", INK_MOULD, base=1)
        capm = m_ellipse(W, H, cx - 1, top + 2, r, r * 0.6) & m_rect(W, H, 0, 0, W, top + 3)
        mass(img, capm, "cap", "round", INK_MOULD, base=2)

    # --- root skirt on the floor (longer towards the player, left) ---
    roots = np.zeros((H, W), bool)
    for pts, t0 in (([(40, 116), (22, 119), (8, 123), (0, 126)], 8), ([(46, 120), (30, 124), (14, 127)], 6),
                    ([(60, 118), (78, 122), (95, 126)], 7), ([(50, 122), (60, 127)], 5), ([(34, 112), (14, 112), (3, 118)], 5)):
        roots |= m_curve(W, H, pts, t0, 1.5)
    roots &= m_rect(W, H, 0, 0, W, 128)
    mass(img, roots, "hypha", "flat", INK_MOULD, base=2)

    # --- skin: a lumpy mound, lower when ruined ---
    sag = 12 if ruined else (3 if hurt else 0)
    skin = (m_ellipse(W, H, 52, 96 + sag * 0.6, 35, 32 - sag) | m_ellipse(W, H, 25, 110 + sag * 0.3, 18, 17 - sag * 0.5)
            | m_ellipse(W, H, 77, 107 + sag * 0.3, 16, 20 - sag * 0.6)) & m_rect(W, H, 0, 0, W, 127)
    lv = mass(img, skin, "mould", "round", INK_MOULD, base=2)
    # a few pale blotches, clustered on the lit side (no speckle)
    blot = np.zeros((H, W), bool)
    for bx, by, br in ((58, 78, 5), (68, 86, 3), (48, 72, 3), (80, 100, 4), (18, 104, 3), (62, 96, 2.5)):
        blot |= m_ellipse(W, H, bx, by + sag * 0.6, br, br * 0.6)
    step(img, skin & blot, "mould", lv, 1)
    # wet folds: three dark creases following the mound
    for pts in ([(26, 100), (38, 84), (56, 76)], [(60, 124), (72, 108), (80, 94)], [(14, 118), (26, 124), (40, 126)]):
        step(img, skin & m_curve(W, H, [(x, y + sag * 0.5) for x, y in pts], 1.6), "mould", lv, -1)

    # --- the torn window and the organ behind it (faces the player) ---
    oy = 98 + sag * 0.7
    window = m_ellipse(W, H, 36, oy, 15, 17 - sag * 0.4) & skin
    put(img, window, RAMP["gill"][0])
    if not ruined:
        breath = 1 if f else 0
        organ = m_ellipse(W, H, 36, oy + 1, 10 + breath, 12 + breath) & window
        olv = paint(img, organ, "organ", "round", base=2 if not hurt else 1)
        put(img, m_ellipse(W, H, 33 - breath, oy - 4, 3, 3) & organ, RAMP["organ"][4 if not hurt else 3])
        # veins on the sac
        step(img, organ & (m_curve(W, H, [(30, oy + 8), (36, oy), (42, oy - 8)], 1.2) | m_curve(W, H, [(36, oy), (44, oy + 6)], 1.2)), "organ", olv, -1)
    else:
        put(img, m_ellipse(W, H, 36, oy + 3, 8, 5) & window, RAMP["organ"][0])
    # ribs of skin across the window: whole, one snapped, all snapped
    ribs = [[(27, oy - 14), (25, oy - 5), (25, oy + 5), (27, oy + 15)], [(37, oy - 18), (36, oy - 6), (36, oy + 6), (37, oy + 18)],
            [(46, oy - 14), (48, oy - 5), (48, oy + 5), (46, oy + 15)]]
    for i, pts in enumerate(ribs):
        if ruined or (hurt and i == 1):
            pts = pts[:2]
        rib = m_curve(W, H, pts, 3.0, 3.0) & grow(window, 2)
        mass(img, rib, "mould", "flat", INK_MOULD, base=3)
    if hurt and not ruined:
        for dx in (30, 39):                                              # the sac leaks
            put(img, m_rect(W, H, dx, int(oy) + 12, 2, 6 + f), RAMP["organ"][2])
    # breathing holes on the right flank
    for hx, hy in ((66, 100), (74, 112), (58, 114)):
        hole = m_ellipse(W, H, hx, hy + sag * 0.5, 3.5, 2.5) & skin
        put(img, hole, RAMP["gill"][0])
        put(img, shift(hole, 0, 1) & hole, RAMP["gill"][1])

    # --- neck and the great cap ---
    if not ruined:
        neck = m_poly(W, H, [(40, 80 + sag), (45, 66), (43, 50), (67, 50), (64, 66), (70, 80 + sag)])
        lvn = mass(img, neck, "hypha", "round", INK_MOULD, base=2)
        for nx in (49, 55, 61):                                          # three long fibres, not a plank wall
            step(img, neck & m_curve(W, H, [(nx, 52), (nx - 1, 66), (nx + (nx - 55) * 0.4, 80 + sag)], 1.3), "hypha", lvn, -1)
        # lopsided: the player-side edge droops lower
        cap = (m_ellipse(W, H, 52, 50, 44, 26) & m_rect(W, H, 0, 0, W, 51)) | m_poly(W, H, [(8, 50), (30, 50), (18, 62), (6, 60)])
        tears = [(22, 51, 8, 7), (40, 52, 10, 6), (60, 52, 8, 8), (78, 52, 10, 6)]
        if hurt:
            cap &= ~m_poly(W, H, [(58, 20), (74, 26), (70, 52), (56, 52), (62, 38)])      # a wedge torn out
            tears += [(8, 62, 8, 10)]
        cap = _ragged(cap, tears)
        gills = (shift(cap, 0, 4) | shift(cap, 0, 2)) & ~cap & m_rect(W, H, 6, 44, 84, 22)
        put(img, gills, RAMP["gill"][1])
        put(img, gills & t_planks(W, H, 3, 0), RAMP["gill"][3])
        rim(img, gills, INK_MOULD, only_empty=True)
        lvc = mass(img, cap, "cap", "round", INK_MOULD, base=2)
        step(img, cap & (m_ellipse(W, H, 30, 36, 5, 3) | m_ellipse(W, H, 50, 30, 6, 3) | m_ellipse(W, H, 72, 40, 4, 2.5) | m_ellipse(W, H, 16, 46, 3, 2)), "cap", lvc, 2)
        if hurt:
            flap = m_poly(W, H, [(70, 30), (84, 40), (86, 58), (78, 62), (74, 48)])
            mass(img, flap, "cap", "flat", INK_MOULD, base=1)
    else:
        # the cap lies broken in front of the nest
        fallen = m_poly(W, H, [(2, 127), (4, 114), (16, 106), (34, 108), (30, 118), (22, 127)])
        mass(img, fallen, "cap", "round", INK_MOULD, base=1)
        stump = m_poly(W, H, [(46, 92), (44, 80), (50, 74), (60, 76), (64, 84), (62, 92)])
        mass(img, stump, "hypha", "wall", INK_MOULD, base=1)
    return img


FRAMES = {}
for _state in ("idle", "damaged", "ruined"):
    for _f in (0, 1):
        FRAMES[f"base_player/{_state}/{_f}"] = (bakery, _state, _f)
        FRAMES[f"base_enemy/{_state}/{_f}"] = (nest, _state, _f)


def render(name: str) -> Img:
    fn, state, f = FRAMES[name]
    return fn(state, f)


if __name__ == "__main__":
    import sys
    from PIL import Image
    out = sys.argv[1]
    sheet = Image.new("RGBA", (W * 6 + 14, H * 2 + 6), (150, 170, 150, 255))
    for row, key in enumerate(("base_player", "base_enemy")):
        for i, (st, f) in enumerate([(s, f) for s in ("idle", "damaged", "ruined") for f in (0, 1)]):
            im = render(f"{key}/{st}/{f}").pil()
            sheet.paste(im, (2 + i * (W + 2), 2 + row * (H + 2)), im)
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    sheet.save(out)
    print("wrote", out)
