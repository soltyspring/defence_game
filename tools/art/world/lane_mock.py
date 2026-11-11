"""Offline 640x360 mock of the battle backdrop + sprites (no Godot): before/after evidence for the lane set.

    python tools/art/world/lane_mock.py <out_dir> [old_repo_root]

Transliterates src/gameplay/lane_backdrop.gd (v1 = painted panorama, v2 = lane_set_v2) at world zoom 1.
It is a preview tool: the game itself must still be captured in Godot (not done in this pass).
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
G = 290
VW, VH = 640, 360
FACT_V1 = [0.0, 0.08, 0.22, 0.4, 0.68, 1.0]
FACT_V2 = [0.0, 0.08, 0.22, 0.4, 1.0, 1.0]


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Layer:
    def __init__(self, im, cam, factor):
        self.d = ImageDraw.Draw(im)
        self.im = im
        self.ox = cam * (1 - factor) - (cam - VW / 2)     # layer x -> screen x

    def box(self, x, y, w, h, col):
        self.d.rectangle([round(x + self.ox), round(y), round(x + self.ox + w) - 1, round(y + h) - 1], fill=rgb(col))

    def poly(self, pts, col):
        self.d.polygon([(round(x + self.ox), round(y)) for x, y in pts], fill=rgb(col))

    def tex(self, src, x, y, flip=False, tint=None):
        if flip:
            src = src.transpose(Image.FLIP_LEFT_RIGHT)
        if tint:
            r, g, b, a = src.split()
            r = r.point(lambda v: v * tint[0] // 255)
            g = g.point(lambda v: v * tint[1] // 255)
            b = b.point(lambda v: v * tint[2] // 255)
            a = a.point(lambda v: int(v * tint[3] / 255))
            src = Image.merge("RGBA", (r, g, b, a))
        self.im.alpha_composite(src, (round(x + self.ox), round(y)))


def backdrop(im, cam, L, v2, root, px=40.0):
    ex = L - 40.0
    F = FACT_V2 if v2 else FACT_V1
    sky = Layer(im, cam, F[0])
    for i, col in enumerate(["80adca", "9ec2d4", "bcd6dd", "d8e2d6"]):
        sky.box(-2000, G - 800 + i * 170, L + 6000, 174, col)
    sky.box(-2000, G - 120, L + 6000, 300, "d8e2d6")
    cl = Layer(im, cam, F[1])
    for i in range(-4, int(L / 180) + 8):
        x = i * 180 + (i * 71) % 80
        y = G - 205 - (i * 19) % 45
        cl.box(x, y, 55, 8, "c6d9df"); cl.box(x + 7, y - 7, 40, 9, "edf0df"); cl.box(x + 18, y - 12, 20, 7, "edf0df")
    hl = Layer(im, cam, F[2])
    for i in range(-8, int(L / 170) + 12):
        x = i * 170; h = 22 + (i * 37) % 43; y = G - 100
        hl.poly([(x - 40, y + 25), (x + 24, y - h), (x + 68, y - h - 9), (x + 147, y + 16), (x + 202, y + 34)], "86a69a")
        hl.poly([(x + 8, y + 29), (x + 84, y - h + 20), (x + 154, y + 10), (x + 196, y + 37)], "a1b8a0")
    fl = Layer(im, cam, F[3])
    fl.box(-1000, G - 102, L + 3000, 110, "9eae78")
    if not v2:
        for i in range(-5, int(L / 120) + 10):
            x = i * 120; y = G - 77.0
            fl.poly([(x, y), (x + 36, y - 14), (x + 140, y - 14), (x + 112, y + 30)], "d3bd79")
            for row in range(4):
                fl.box(x + 10 + row * 4, y - 4 + row * 6, 91 - row * 7, 2, "b5a66c")
            fl.box(x + 113, y - 4, 3, 39, "6d855e"); fl.box(x + 109, y - 17, 11, 19, "799367")
    else:
        fl.box(-1000, G - 88, L + 3000, 34, "cdbf85")                    # one broad wheat band, no furrows
        fl.box(-1000, G - 88, L + 3000, 3, "ddd09a")
        for i in range(-1, int(L * 0.4 / 420) + 3):                      # sparse sheaves: 3 px+ shapes, 420 px apart
            x = i * 420 + 150
            fl.box(x, G - 66, 12, 12, "b7a468"); fl.box(x + 2, G - 70, 8, 4, "c9b877")
        far = L + 3000
        for (b, base_col, band_col) in ((0.4 * 0.58 * L + 130, "9aa888", "bcb992"), (0.4 * 0.8 * L + 190, "93a290", "a9b09c")):
            # blight creeps into the far fields in 2 flat steps; slanted edges read as terrain, not as a seam
            fl.poly([(b + 70, G - 102), (far, G - 102), (far, G + 8), (b, G + 8)], base_col)
            fl.poly([(b + 61, G - 88), (far, G - 88), (far, G - 54), (b + 39, G - 54)], band_col)
    vl = Layer(im, cam, F[4])
    if not v2:
        pano = Image.open(os.path.join(root, "assets/backgrounds/village_panorama_v1.png")).convert("RGBA")
        pano = pano.crop((0, 128, 2172, 624)).resize((543, 124), Image.NEAREST)
        for i in range(-2, int(L / 735) + 3):
            x = i * 735 - 130
            cold = min(1.0, max(0.0, (x / L - 0.4) / 0.5))
            a, b = (0xdc, 0xe4, 0xd0), (0x7a, 0x99, 0x90)
            tint = tuple(int(a[k] + (b[k] - a[k]) * cold) for k in range(3)) + (int(0.82 * 255),)
            vl.tex(pano, x, G - 142, flip=bool(i % 2), tint=tint)
    else:
        sheet = Image.open(os.path.join(ROOT, "assets/backgrounds/lane_set_v2.png")).convert("RGBA")
        vl.tex(sheet.crop((0, 0, 320, 108)), px + 52, G - 12 - 107)
        vl.tex(sheet.crop((0, 112, 320, 220)), ex - 250, G - 12 - 107)
    ln = Layer(im, cam, F[5])
    ln.box(-450, G - 14, L + 1000, 10, "91a06a")
    ln.box(-450, G - 4, L + 1000, 13, "c9bd9f")
    ln.box(-450, G + 9, L + 1000, 170, "9c805e")
    ln.box(-450, G + 9, L + 1000, 3, "64583f")
    for i in range(-12, int(L / 42) + 15):
        x = i * 42
        ln.box(x, G + 16 + (i * 19) % 35, 9 + (i * 7) % 10, 2, "897354")
        if not v2:
            ln.box(x + 11, G - 9, 3, 6, "b7a77d")
    if v2:
        ln.box(0.6 * L, G - 14, L, 10, "8d9c7c"); ln.box(0.8 * L, G - 14, L, 10, "869687")     # verge cools in 2 steps
        ln.box(0.8 * L, G - 4, L, 13, "bdb7a3")
        ln.box(px - 78, G - 4, 190, 13, "ddd2b2"); ln.box(px - 78, G - 4, 190, 2, "ece3c8")      # bakery forecourt
        for (dx, col) in ((-150, "9fa998"), (-112, "8b9b90"), (-74, "778b84")):                 # mould creep apron
            ln.poly([(ex + dx, G + 9), (ex + dx + 22, G - 4), (ex + 80, G - 4), (ex + 80, G + 9)], col)
        for dx in (-112, -74, -30):
            ln.box(ex + dx, G + 1, 3, 3, "c6d6cb")
    for fr in ([0.25, 0.5, 0.76] if not v2 else [0.3, 0.55]):
        x = L * fr
        ln.box(x, G - 34, 3, 31, "685641")
        ln.poly([(x - 7, G - 33), (x + 16, G - 33), (x + 23, G - 27), (x + 16, G - 21), (x - 7, G - 21)], "b59560")
    if not v2:
        for i in range(9):
            x = L * 0.72 + i * L * 0.029
            ln.box(x, G - 17, 3, 14, "5d7771")
            ln.poly([(x - 8, G - 17), (x - 5, G - 24), (x + 6, G - 24), (x + 11, G - 17)], "82958a")
    else:
        for i, (f, h) in enumerate(((0.70, 12), (0.745, 17), (0.80, 14), (0.83, 22), (0.875, 16), (0.90, 26))):
            x = L * f                                                    # uneven spacing and heights: growth, not a fence
            ln.box(x, G - 3 - h, 3, h, "5d7771")
            ln.poly([(x - 8, G - 3 - h), (x - 5, G - 10 - h), (x + 6, G - 10 - h), (x + 11, G - 3 - h)], "82958a")
    return ln


class Atl:
    def __init__(self, root):
        self.root = root; self.pages = {}
        self.m = json.load(open(os.path.join(root, "assets/manifest.json")))

    def frame(self, sid, anim, i, mod=None):
        page = self.m["anim_sets"][sid]
        if page not in self.pages:
            self.pages[page] = (json.load(open(os.path.join(self.root, f"assets/atlases/{page}.json"))),
                                Image.open(os.path.join(self.root, f"assets/atlases/{page}.png")).convert("RGBA"))
        j, im = self.pages[page]
        fr = j["anims"][sid][anim]["frames"]
        f = j["frames"][fr[i % len(fr)]]
        g = im.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
        if mod:
            g = Image.merge("RGBA", [ch.point(lambda v, k=k: min(255, int(v * k))) for ch, k in zip(g.split(), mod + (1,))])
        return g, f["pivot"]


def scene(root, v2, cam, L, units, hero_x=None, boss_mod=None):
    im = Image.new("RGBA", (VW, VH), (0, 0, 0, 255))
    ln = backdrop(im, cam, L, v2, root)
    at = Atl(root)
    d = ImageDraw.Draw(im, "RGBA")

    def put(sid, anim, i, x, y=0, flip=False, mod=None, shadow=True):
        g, pv = at.frame(sid, anim, i, mod)
        sx = round(x + ln.ox)
        if shadow:
            d.rectangle([sx - 7, G + y, sx + 6, G + y + 1], fill=(20, 20, 18, 82))
        if flip:
            g = g.transpose(Image.FLIP_LEFT_RIGHT); im.alpha_composite(g, (sx - (g.width - pv[0]), G + y - pv[1]))
        else:
            im.alpha_composite(g, (sx - pv[0], G + y - pv[1]))
    put("base_player", "idle", 0, 40.0, shadow=False)
    put("base_enemy", "idle", 0, L - 40.0, shadow=False)
    mill_x = 40.0 - 152.0
    if v2:
        sheet = Image.open(os.path.join(ROOT, "assets/backgrounds/lane_set_v2.png")).convert("RGBA")
        im.alpha_composite(sheet.crop((324, 0, 436, 112)), (round(mill_x - 56 + ln.ox), G - 111))
    else:
        pano = Image.open(os.path.join(root, "assets/backgrounds/village_panorama_v1.png")).convert("RGBA")
        im.alpha_composite(pano.crop((0, 240, 440, 624)).resize((110, 96), Image.NEAREST), (round(mill_x - 55 + ln.ox), G - 96))
    for (sid, anim, i, x, y, side) in sorted(units, key=lambda u: u[4]):
        mod = boss_mod if sid.startswith("boss") else None
        put(sid, anim, i, x, y, flip=side < 0, mod=mod)
    if hero_x is not None:
        sx = round(hero_x + ln.ox)
        d.polygon([(sx - 5, G - 49), (sx + 5, G - 49), (sx, G - 42)], fill=(26, 28, 36, 255))
        d.polygon([(sx - 3, G - 48), (sx + 3, G - 48), (sx, G - 44)], fill=(255, 231, 160, 255))
    return im


def scenes(L=1900.0):
    home = [("hero_captain", "idle", 0, 78, 0, 1)] + [("melee_basic", "walk", i, 120 + i * 34, -10 * (i % 3), 1) for i in range(5)] + [("worker", "walk", 1, -40, 1, 1)]
    mid_c = L / 2
    mid = [("hero_captain", "attack", 2, mid_c - 70, 0, 1)]
    mid += [("melee_basic", "attack" if i % 2 else "walk", i, mid_c - 20 - i * 9, -10 * (i % 3), 1) for i in range(6)]
    mid += [("e_grunt", "attack" if i % 2 else "walk", i + 1, mid_c + 8 + i * 9, -10 * (i % 3), -1) for i in range(6)]
    mid += [("ranged_basic", "attack", 1, mid_c - 150, -10, 1), ("e_spitter", "walk", 1, mid_c + 140, 0, -1)]
    bx = L - 250
    boss = [("boss_warlord", "attack", 2, bx, 0, -1), ("hero_captain", "attack", 3, bx - 62, 0, 1)]
    boss += [("melee_basic", "attack", i, bx - 34 - i * 9, -10 * (i % 3), 1) for i in range(5)]
    boss += [("e_grunt", "walk", i, bx + 44 + i * 16, -10 * (i % 3), -1) for i in range(3)]
    return {"home": (145.0, home, 78), "clash": (mid_c, mid, mid_c - 70), "boss": (L - 145.0, boss, bx - 62)}, L


def main():
    out = sys.argv[1]
    old = sys.argv[2] if len(sys.argv) > 2 else ROOT
    os.makedirs(out, exist_ok=True)
    sc, L = scenes()
    for name, (cam, units, hx) in sc.items():
        before = scene(old, False, cam, L, units, hx, boss_mod=(3.0, 3.0, 3.0))
        after = scene(ROOT, True, cam, L, units, hx)
        pair = Image.new("RGBA", (VW, VH * 2 + 4), (255, 0, 255, 255))
        pair.paste(before, (0, 0)); pair.paste(after, (0, VH + 4))
        pair.save(os.path.join(out, f"pair_{name}_top-before_bottom-after_1x.png"))
        g = Image.new("RGBA", (VW * 2 + 4, VH), (255, 0, 255, 255))
        g.paste(before.convert("L").convert("RGBA"), (0, 0)); g.paste(after.convert("L").convert("RGBA"), (VW + 4, 0))
        g.save(os.path.join(out, f"gray_{name}_left-before_right-after_1x.png"))
        after.resize((VW * 2, VH * 2), Image.NEAREST).crop((0, 300, 1280, 620)).save(os.path.join(out, f"after_{name}_lane_2x.png"))
    print("wrote", out)


if __name__ == "__main__":
    main()
