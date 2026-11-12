"""Build the release-slice atlas.  python tools/art/release_slice/build.py [--mock <png>]

Writes (from the repository root):
    assets/art/release_slice/slice_atlas.png    one RGBA page, 2 px padding + 1 px extrusion, nearest
    assets/art/release_slice/slice_atlas.json   schema defence.atlas/1: frames {x,y,w,h,pivot}, anims (bases)
    assets/art/release_slice/integration.json   which existing contract each frame replaces + the scene layout
--mock also writes a Python composite of three camera positions. That file is a layout check for the artist,
NOT a game screenshot.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import backdrop  # noqa: E402
import bases  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "release_slice")
PAGE = 1024
PAD = 2

# Scene layout shared with src/art_preview/slice_backdrop.gd (world px, G = lane ground_y).
LAYOUT = {
    "sky": [["6fa9d8", -1000], ["8cc0e2", -190], ["aad3e8", -160], ["c9e2ea", -134], ["e6eedc", -112], ["f3ecd2", -96]],
    "clouds": {"y": -150, "parallax": 0.06, "drift": 1.3},
    "far": {"y": -150, "parallax": 0.15},
    "mid": {"y": -90, "parallax": 0.4, "blight_from": 0.62},
    "lane": {"y": -16, "blight_from": 0.62, "home_x": -96},
    "home_set": {"x": -168, "bottom": -10},
    "enemy_set": {"x": -236, "bottom": -10},
    "mill": {"note": "bakery_supply draws region `mill` at (mill_x - 56, ground - 111)"},
}


def main():
    os.makedirs(OUT, exist_ok=True)
    items = []
    for name, fn in backdrop.PIECES.items():
        im = fn()
        items.append((name, im.pil(), [im.w // 2, im.h - 1]))
    for name in bases.FRAMES:
        im = bases.render(name)
        items.append((name, im.pil(), [48, 127]))
    # shelf packing, tallest first
    order = sorted(items, key=lambda it: (-it[1].height, -it[1].width))
    page = Image.new("RGBA", (PAGE, PAGE), (0, 0, 0, 0))
    frames = {}
    x = y = PAD
    shelf = 0
    for name, im, pivot in order:
        if x + im.width + PAD > PAGE:
            x = PAD
            y += shelf + PAD * 2
            shelf = 0
        assert y + im.height + PAD <= PAGE, "atlas page full"
        # 1 px extrusion so nearest sampling at the frame edge never reads a neighbour
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            page.paste(im, (x + dx, y + dy))
        page.paste(im, (x, y))
        frames[name] = {"x": x, "y": y, "w": im.width, "h": im.height, "pivot": pivot}
        x += im.width + PAD * 2
        shelf = max(shelf, im.height)
    used_h = y + shelf + PAD
    page.save(os.path.join(OUT, "slice_atlas.png"))
    anims = {}
    for key in ("base_player", "base_enemy"):
        anims[key] = {st: {"frames": [f"{key}/{st}/0", f"{key}/{st}/1"], "fps": 3 if st == "idle" else 5, "loop": True}
                      for st in ("idle", "damaged", "ruined")}
    meta = {"schema": "defence.atlas/1", "atlas": "release_slice", "image": "slice_atlas.png",
            "image_res": "res://assets/art/release_slice/slice_atlas.png", "size": [PAGE, PAGE], "padding": PAD, "extrude": 1,
            "group": "release_slice", "filter": "nearest", "mipmaps": False, "repeat": False,
            "gpu_format": "RGBA8", "gpu_bytes": PAGE * PAGE * 4, "used_rows": used_h, "frames": frames, "anims": anims}
    json.dump(meta, open(os.path.join(OUT, "slice_atlas.json"), "w", encoding="utf-8"), indent=1)
    integ = {
        "atlas": "release_slice",
        "replaces": {
            "anim_sets": {"base_player": "assets/atlases/bases.json base_player (96x128, pivot 48,127, idle/damaged/ruined x2)",
                          "base_enemy": "assets/atlases/bases.json base_enemy (same contract, not flipped by the engine)"},
            "backdrop": "src/gameplay/lane_backdrop.gd layers for round r01 (src/art_preview/slice_backdrop.gd has the same interface)",
            "mill": "assets/backgrounds/lane_set_v2.png region SET_MILL (112x112) used by src/gameplay/bakery_supply.gd",
        },
        "not_replaced": ["hero_captain", "melee_basic", "e_grunt", "worker", "fx", "title"],
        "layout": LAYOUT,
    }
    json.dump(integ, open(os.path.join(OUT, "integration.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("atlas", PAGE, "x", PAGE, "used rows", used_h, "frames", len(frames))
    if "--mock" in sys.argv:
        mock(dict((n, im) for n, im, _ in items), sys.argv[sys.argv.index("--mock") + 1])


def mock(pieces, path):
    """Three 320x180 world views (home, middle, nest) at 2x. Layout check only."""
    L, G, VW, VH = 1000.0, 150, 320, 180
    px, ex = 40.0, L - 40.0
    views = []
    for cam in (160.0, L * 0.5, L - 110.0):
        v = Image.new("RGBA", (VW, VH), (0, 0, 0, 255))
        left = cam - VW / 2
        prev = -2000
        for col, top in LAYOUT["sky"]:
            y0 = max(0, G + top)
            v.paste(Image.new("RGBA", (VW, VH - y0), tuple(int(col[i:i + 2], 16) for i in (0, 2, 4)) + (255,)), (0, y0))

        def put(name, wx, wy, par=1.0):
            im = pieces[name]
            sx = int(round(wx + cam * (1.0 - par) - left))
            v.paste(im, (sx, int(wy)), im)

        for i, cn in enumerate(("cloud_a", "cloud_c", "cloud_b", "cloud_a")):
            put(cn, i * 150 + 20, G - 150 + (i * 7) % 14, 0.06)
        for i in range(-1, 3):
            put("far", i * 512, G + LAYOUT["far"]["y"], 0.15)
        bx = 0.4 * LAYOUT["mid"]["blight_from"] * L
        for i in range(-1, 3):
            if i * 512 < bx:
                put("mid_home", i * 512, G + LAYOUT["mid"]["y"], 0.4)
        for i in range(0, 3):
            put("mid_blight", bx + i * 512, G + LAYOUT["mid"]["y"], 0.4)
        put("mid_edge", bx - 60, G + LAYOUT["mid"]["y"], 0.4)
        put("home_set", px + LAYOUT["home_set"]["x"], G - 10 - 112)
        put("enemy_set", ex + LAYOUT["enemy_set"]["x"], G - 10 - 124)
        lx = -256
        while lx < L + 256:
            put("lane" if lx < L * 0.62 else "lane_blight", lx, G - 16)
            lx += 256
        put("lane_home", px - 96, G - 16)
        put("mill", px - 96 - 56, G - 111)
        put("base_player/idle/0", px - 48, G - 127)
        put("base_enemy/idle/0", ex - 48, G - 127)
        views.append(v)
    sheet = Image.new("RGBA", (VW * 3 + 8, VH), (20, 20, 24, 255))
    for i, v in enumerate(views):
        sheet.paste(v, (i * (VW + 4), 0))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(path)
    print("mock (layout check, not a game screen):", path)


if __name__ == "__main__":
    main()
