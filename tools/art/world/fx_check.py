"""FX cover check from the source module (owner: 09-art-world).

    python tools/art/world/fx_check.py [out.json]

Places every hit_spark / explosion frame exactly as battle_view.gd `_draw_fx` does (pivot from fx.SETS, hit_spark at
y -12, explosion at y -6 relative to ground_y) over each target's attack frame from the committed character atlas, and
reports per target: peak and mean share of the unit's pixels covered, and the share of FX pixels over the unit whose
dE76 to the unit pixel below is < 20 (the FX would be invisible there). v1 = art 0.13 functions, v2 = shipped SETS.
Pass lines (WORLD_AUDIT P5): hit_spark peak <= 10 %, same <= 5 %; explosion peak <= 20 %.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
sys.path.insert(0, ART)
sys.path.insert(0, HERE)
import fx  # noqa: E402
import world_metrics as wm  # noqa: E402
from cvd_check import lab  # noqa: E402
from pixel import RGBA  # noqa: E402

KINDS = {"hit_spark": -12, "explosion": -6}


def check(fn, dy, piv, R, bg):
    gy = int(R["gy"])
    frs = [RGBA[f.a] for f in list(fn().values())[0]["frames"]]
    rows = []
    for aset, side in wm.TARGETS:
        uf, _ = wm.anim_frames(R, aset, "attack")
        upx, uf0 = uf[min(2, len(uf) - 1)]
        ua, ux0, uy0 = wm.place(upx, uf0["pivot"], 320, gy, side < 0)
        um = wm.stamp_mask(bg.shape[:2], ua, ux0, uy0)
        comp = bg.copy()
        wm._alpha_over(comp, ua, ux0, uy0)
        cov, same = [], []
        for fa in frs:
            fx0, fy0 = 320 - piv[0], gy + dy - piv[1]
            fm = wm.stamp_mask(bg.shape[:2], fa, fx0, fy0)
            ov = um & fm
            cov.append(float(ov.sum()) / um.sum() * 100)
            if ov.any():
                top = np.zeros_like(comp)
                wm._alpha_over(top, fa, fx0, fy0)
                d = np.linalg.norm(lab(top[ov]) - lab(comp[ov]), axis=1)
                same.append(float((d < 20).mean() * 100))
        rows.append({"target": aset, "cover_peak": round(max(cov), 1), "cover_mean": round(float(np.mean(cov)), 1),
                     "same_pct": round(float(np.mean(same)), 1) if same else 0.0})
    return {"peak_max": max(r["cover_peak"] for r in rows), "same_max": max(r["same_pct"] for r in rows), "targets": rows}


def main(out=None):
    R = wm.load_root(wm.ROOT)
    bg, _ = wm.compose_bg(R, 320.0)
    rep = {}
    for k, dy in KINDS.items():
        fn_new, w, h, piv = fx.SETS[k]
        rep[k] = {"v1": check(getattr(fx, f"{k}_v1"), dy, piv, R, bg), "v2": check(fn_new, dy, piv, R, bg)}
        print(k, "v1 peak/same", rep[k]["v1"]["peak_max"], rep[k]["v1"]["same_max"],
              "| v2 peak/same", rep[k]["v2"]["peak_max"], rep[k]["v2"]["same_max"])
    rep["pass"] = {"hit_spark": bool(rep["hit_spark"]["v2"]["peak_max"] <= 10 and rep["hit_spark"]["v2"]["same_max"] <= 5),
                   "explosion": bool(rep["explosion"]["v2"]["peak_max"] <= 20)}
    print("pass", rep["pass"])
    if out:
        json.dump(rep, open(out, "w", encoding="utf-8", newline="\n"), indent=1)
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
