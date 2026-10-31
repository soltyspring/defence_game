"""A/B of the bakery keep's lower course (owner: 09-art-world).

    python tools/art/world/keep_plinth_ab.py [out.json]

Units spawn at the player keep and walk in front of its lower ~40 px. The real r10 110 s capture of art-world 1 showed
the hero against the tan keep at ring dL* 0.6. This compares lower-course colourings of keep_v2 on the art-world 1
street (world_preview composite, ground_y from data) for: the keep's own ring contrast (WORLD_AUDIT P4, mean-vs-mean and
8-row slices) and the ring contrast of five ally units placed in front of it.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import bases  # noqa: E402
import world_metrics as wm  # noqa: E402
import world_preview as wp  # noqa: E402

VARIANTS = {
    "none (tan to the ground)": dict(base="T", mortar="U", hi="U", edge="o"),
    "crust o": dict(base="o", mortar="O", hi="T", edge="O"),
    "dark crust O (shipped)": dict(base="O", mortar="w", hi="o", edge="w"),
    "grey stone M": dict(base="M", mortar="m", hi="N", edge="m"),
}
UNITS = (("hero_captain", 60), ("melee_basic", 70), ("worker", 52), ("ranged_basic", 80), ("tank", 44))


def main(out=None):
    R = wm.load_root(wm.ROOT)
    gy = int(R["gy"])
    lay = wp.layers_from("new")
    bg, _ = wm.compose_bg(R, 320.0, 640, 360, front=False, layers=lay)
    keep0 = dict(bases.KEEP_PLINTH)
    rep = {}
    for name, v in VARIANTS.items():
        bases.KEEP_PLINTH = v
        kp = wp.base_rgba("new", "player", "intact")
        img = bg.copy()
        wm._alpha_over(img, kp, 60 - 48, gy - 127)
        km = wm.stamp_mask(img.shape[:2], kp, 60 - 48, gy - 127)
        keep = wm.unit_contrast(img, bg, km)
        units = []
        for s, x in UNITS:
            fr, _ = wm.anim_frames(R, s, "walk")
            px, f = fr[0]
            a, ax, ay = wm.place(px, f["pivot"], x, gy, False)
            m = wm.stamp_mask(img.shape[:2], a, ax, ay)
            comp = img.copy()
            wm._alpha_over(comp, a, ax, ay)
            r = wm.unit_contrast(comp, img, m)
            units.append({"set": s, "ring_dL": r["ring_dL"], "ring_dE": r["ring_dE"]})
        rep[name] = {"keep_ring_dE": keep["ring_dE"], "keep_ring_dL": keep["ring_dL"], "keep_slice_dL_median": keep["slice_dL_median"],
                     "units_min_dL": min(u["ring_dL"] for u in units), "units_min_dE": min(u["ring_dE"] for u in units), "units": units}
        print(f"{name:26s} keep ring dE {keep['ring_dE']:5.1f} slice {keep['slice_dL_median']:5.1f} | units in front min dL {rep[name]['units_min_dL']:5.1f} min dE {rep[name]['units_min_dE']:5.1f}")
    bases.KEEP_PLINTH = keep0
    if out:
        json.dump(rep, open(out, "w", encoding="utf-8", newline="\n"), indent=1)
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
