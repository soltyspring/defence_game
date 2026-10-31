"""08-performance: static sprite-fill table from atlas PNG alpha masks (no Godot).

For every regular unit anim set on a character page: mean per-frame destination quad area (= frame rect, what the GPU shades
today), alpha bounding box area (what a trimmed quad would shade) and opaque pixel count (alpha > 0), over the frames of the
walk / attack / idle anims. Run on two project trees (e.g. a shipped copy and an ART_DRAFT32 copy) to compare.

  python tools/perf/sprite_fill_static.py --tree <dirA> --tree <dirB> [--page char_player] [--out <json>]

Output: JSON with per-set rows and totals, and a printed table. Owner: 08-performance.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

from PIL import Image

ANIMS = ("walk", "attack", "idle")
BOSS_PREFIX = "boss_"


def page_stats(tree: str, page: str) -> dict:
    meta = json.load(open(os.path.join(tree, "assets", "atlases", page + ".json"), encoding="utf-8"))
    img = Image.open(os.path.join(tree, "assets", "atlases", meta["image"])).convert("RGBA")
    alpha = img.getchannel("A")
    rows = {}
    for aset, anims in meta["anims"].items():
        if aset.startswith(BOSS_PREFIX):
            continue
        n = q = b = o = 0
        for an in ANIMS:
            for fname in anims.get(an, {}).get("frames", []):
                f = meta["frames"][fname]
                box = (f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])
                a = alpha.crop(box)
                bb = a.getbbox()
                n += 1
                q += f["w"] * f["h"]
                b += 0 if bb is None else (bb[2] - bb[0]) * (bb[3] - bb[1])
                o += sum(1 for v in a.getdata() if v > 0)
        if n:
            rows[aset] = {"frames": n, "quad_px": round(q / n, 1), "bbox_px": round(b / n, 1), "opaque_px": round(o / n, 1),
                          "bbox_share": round(b / q, 3), "opaque_share": round(o / q, 3)}
    tq = sum(r["quad_px"] for r in rows.values())
    tb = sum(r["bbox_px"] for r in rows.values())
    to = sum(r["opaque_px"] for r in rows.values())
    return {"tree": tree, "page": page, "size": meta["size"], "sets": rows,
            "mean_over_sets": {"quad_px": round(tq / len(rows), 1), "bbox_px": round(tb / len(rows), 1), "opaque_px": round(to / len(rows), 1),
                               "bbox_share": round(tb / tq, 3), "opaque_share": round(to / tq, 3)}}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", action="append", required=True)
    ap.add_argument("--page", default="char_player")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    res = [page_stats(t, a.page) for t in a.tree]
    for r in res:
        m = r["mean_over_sets"]
        print(f"[fill] {os.path.basename(os.path.normpath(r['tree']))} {a.page} {r['size'][0]}x{r['size'][1]}: mean quad {m['quad_px']} px, "
              f"bbox {m['bbox_px']} ({m['bbox_share']:.0%}), opaque {m['opaque_px']} ({m['opaque_share']:.0%})")
        for s, v in sorted(r["sets"].items()):
            print(f"[fill]   {s:14s} quad {v['quad_px']:7.1f}  bbox {v['bbox_px']:7.1f} ({v['bbox_share']:.0%})  opaque {v['opaque_px']:7.1f} ({v['opaque_share']:.0%})")
    if a.out:
        os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
        json.dump(res, open(a.out, "w", encoding="utf-8"), indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
