"""Quick A/B composite of the biome, bases and a unit lineup with the engine's placement (owner: 09-art-world).

    python tools/art/world/world_preview.py <out_dir> [old|new] [cam_x]

Uses the source modules directly (biome.py, bases.py, theme remaps as build.py applies them), so no build is needed;
units come from the committed atlas pages (they are 03's and are not changed). Writes preview_<v>_1x.png, _2x.png and
metrics_<v>.json (ring contrast per side, background bands, base contrast). The engine replica is world_metrics.py.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
sys.path.insert(0, ART)
sys.path.insert(0, HERE)
import biome  # noqa: E402
import bases  # noqa: E402
import theme  # noqa: E402
from pixel import RGBA  # noqa: E402
import world_metrics as wm  # noqa: E402

ALLY = ["worker", "melee_basic", "ranged_basic", "tank", "fast", "hero_captain", "melee_basic", "ranged_basic"]
ENEMY = ["e_grunt", "e_spitter", "e_swarm", "e_brute", "e_grunt", "e_bomber", "boss_warlord"]


def layers_from(variant):
    ls = biome.build_meadow(biome.VILLAGE if variant == "old" else biome.VILLAGE2)
    out = []
    for name, cv, meta in ls:
        if name == "front":
            theme.remap_keys(cv, theme.WHEAT_FRONT)
        L = dict(meta)
        L["frame"] = name
        if name == "front":
            L["z"] = "front"
        out.append((L, RGBA[cv.a]))
    return out, "#3b5aa8" if variant == "old" else ls[0][2].get("clear_color", "#3b5aa8")


def base_rgba(variant, key, state):
    if variant == "old":
        fn = bases.player_keep_v1 if key == "player" else bases.mould_nest_v1
    else:
        fn = bases.keep_v2 if key == "player" else bases.nest_v2
    cv = fn(state, 0)
    tbl = theme.BAKERY_KEEP if key == "player" else theme.MOULD_FORT
    theme.remap_keys(cv, tbl)
    return RGBA[cv.a]


def run(out, variant="new", cam=320.0, state="intact"):
    os.makedirs(out, exist_ok=True)
    R = wm.load_root(wm.ROOT)
    gy = int(R["gy"])
    lay = layers_from(variant)
    bg, vt = wm.compose_bg(R, cam, 640, 360, front=False, layers=lay)
    img = bg.copy()
    sx0 = round(cam) - 320
    # bases at the two screen edges (as at the start / end of a round)
    bp = base_rgba(variant, "player", state)
    be = base_rgba(variant, "enemy", state)
    wm._alpha_over(img, bp, 60 - 48, gy - 127)
    wm._alpha_over(img, be, 590 - 48, gy - 127)
    base_masks = {"player": wm.stamp_mask(img.shape[:2], bp, 60 - 48, gy - 127),
                  "enemy": wm.stamp_mask(img.shape[:2], be, 590 - 48, gy - 127)}
    bg_with_bases = img.copy()
    masks = {1: np.zeros(img.shape[:2], bool), -1: np.zeros(img.shape[:2], bool)}
    per = []
    for side, sets, x0, step in ((1, ALLY, 130, 26), (-1, ENEMY, 360, 30)):
        for i, s in enumerate(sets):
            fr, _ = wm.anim_frames(R, s, "walk")
            px, f = fr[0]
            a, ax, ay = wm.place(px, f["pivot"], x0 + i * step, gy + (i % 3) - 1, side < 0)
            m = wm.stamp_mask(img.shape[:2], a, ax, ay)
            solo = bg_with_bases.copy()
            wm._alpha_over(solo, a, ax, ay)
            per.append({"set": s, "side": side, **(wm.unit_contrast(solo, bg_with_bases, m) or {})})
            wm._alpha_over(img, a, ax, ay)
            masks[side] |= m
    for L, px in lay[0]:                                # front layer last, like the engine
        if L.get("z") == "front":
            par = float(L.get("parallax", 1.0))
            tw = px.shape[1]
            bx = int(np.floor(cam * (1 - par) + 0.5))
            x = int(np.floor((cam - 328 - bx) / tw) * tw + bx)
            while x < cam + 336:
                wm._alpha_over(img, px, int(x - sx0), int(L["view_y"] - vt))
                x += tw
    rep = {"variant": variant, "cam": cam, "ground_y": gy,
           "units": per,
           "ally_min_ring_dL": min(p["ring_dL"] for p in per if p["side"] > 0),
           "ally_min_ring_dE": min(p["ring_dE"] for p in per if p["side"] > 0),
           "enemy_min_ring_dL": min(p["ring_dL"] for p in per if p["side"] < 0),
           "enemy_min_ring_dE": min(p["ring_dE"] for p in per if p["side"] < 0),
           "bands": {n: wm.band_stats(bg, a, b) for n, (a, b) in
                     {"far": (60, 175), "street_upper": (180, 244), "head_band": (gy - 35, gy - 5), "lane": (gy - 6, gy + 7)}.items()},
           "bases": {k: wm.unit_contrast(bg_with_bases, bg, m) for k, m in base_masks.items()}}
    Image.fromarray(np.rint(img).astype(np.uint8)).save(os.path.join(out, f"preview_{variant}_{state}_1x.png"))
    Image.fromarray(np.rint(img).astype(np.uint8)).resize((1280, 720), Image.NEAREST).save(os.path.join(out, f"preview_{variant}_{state}_2x.png"))
    json.dump(rep, open(os.path.join(out, f"metrics_{variant}_{state}.json"), "w", encoding="utf-8", newline="\n"), indent=1)
    print(variant, state, "ally min ring dL/dE", rep["ally_min_ring_dL"], rep["ally_min_ring_dE"],
          "| enemy", rep["enemy_min_ring_dL"], rep["enemy_min_ring_dE"])
    for n, b in rep["bands"].items():
        print("  ", n, b)
    for k, b in rep["bases"].items():
        print("   base", k, {x: b[x] for x in ("ring_dL", "ring_dE", "slice_dL_median", "slice_dL_min", "unit_L_mean", "ring_L_mean")})
    return rep


if __name__ == "__main__":
    out = sys.argv[1]
    v = sys.argv[2] if len(sys.argv) > 2 else "new"
    cam = float(sys.argv[3]) if len(sys.argv) > 3 else 320.0
    st = sys.argv[4] if len(sys.argv) > 4 else "intact"
    run(out, v, cam, st)
