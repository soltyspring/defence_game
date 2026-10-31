"""Unit-size draft comparison (owner: 03-art). Reads lineup_cam.gd captures + the atlases imported for them.

    python tools/art/size_draft_metrics.py <captures_root> <atlas_root> <out.json>

<captures_root>/<variant>_<WxH>/ = lineup_cam.gd output; <atlas_root>/<variant>/ holds char_player/char_enemy
png+json that were imported for that run (base = HEAD files). For melee_basic and e_grunt, per variant:
  body_px         alpha bbox height of the idle frame 0 (view px)
  body_mm_393dp   body_px x 0.173 mm (1080x2400 phone, 393 dp wide, integer scale 3; 04's conversion)
  doubled_pct     % of rows+columns inside the sprite bbox that repeat the previous row/column exactly
                  (1 source pixel drawn 2 px wide in the art itself; high for a non-integer nearest upscale)
  colours         distinct colours in the idle frame (detail available to the eye)
and, from the real captures (tools/art/lineup_metrics.py rules), silhouette % and min dE76 to the other side
(4 simulations) in the walk and attack poses at each window size.
"""
from __future__ import annotations

import glob
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lineup_metrics as LM  # noqa: E402

MM = 0.173
UNITS = {"melee_basic": "char_player", "e_grunt": "char_enemy"}   # page ids of the art 0.12.x drafts (pre-merge)


def frame(root, page, name):
    d = json.load(open(os.path.join(root, f"{page}.json"), encoding="utf-8"))
    p = np.array(Image.open(os.path.join(root, f"{page}.png")).convert("RGBA"))
    f = d["frames"][name]
    return p[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]]


def static(root):
    out = {}
    for sid, page in UNITS.items():
        t = frame(root, page, f"{sid}/idle/0")
        a = t[..., 3] > 0
        ys, xs = np.nonzero(a)
        sub = t[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        rows = sum(int((sub[i] == sub[i - 1]).all()) for i in range(1, sub.shape[0]))
        cols = sum(int((sub[:, i] == sub[:, i - 1]).all()) for i in range(1, sub.shape[1]))
        cl = {tuple(v) for v in sub[sub[..., 3] > 0][:, :3].tolist()}
        out[sid] = {"body_px": int(ys.max() - ys.min() + 1), "width_px": int(xs.max() - xs.min() + 1),
                    "body_mm_393dp": round((ys.max() - ys.min() + 1) * MM, 2),
                    "doubled_pct": round((rows + cols) / max(1, sub.shape[0] + sub.shape[1] - 2) * 100, 1),
                    "colours": len(cl), "frame": list(t.shape[:2])}
    return out


def main(cap_root, atlas_root, out):
    rep = {"mm_per_view_px": MM, "variants": {}}
    for d in sorted(glob.glob(os.path.join(cap_root, "*_*x*"))):
        name = os.path.basename(d)
        v, res = name.rsplit("_", 1)
        ar = os.path.join(atlas_root, "base_head" if v == "base" else os.path.join(v, "atlases"))
        vr = rep["variants"].setdefault(v, {"static": static(ar), "capture": {}})
        m = LM.measure(d, ar)
        cap = {}
        for pose, rows in m.items():
            for r in rows:
                if r["set"] in UNITS:
                    k = f"{r['set']}@{int(r['x'])}"
                    cap.setdefault(k, {})[pose] = {"sil": r["silhouette_pct"], "dE_min": min(r["dE_enemy_min"].values()),
                                                   "dE_protan": r["dE_enemy_min"]["protan"], "px": r["px"]}
        vr["capture"][res] = cap
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1)
        f.write("\n")
    for v, vr in rep["variants"].items():
        st = vr["static"]
        print(v, {s: (x["body_px"], x["body_mm_393dp"], x["doubled_pct"], x["colours"]) for s, x in st.items()})
        for res, cap in vr["capture"].items():
            print("   ", res, {k: {p: (x["sil"], x["dE_min"]) for p, x in d.items()} for k, d in cap.items()})


if __name__ == "__main__":
    main(*sys.argv[1:4])
