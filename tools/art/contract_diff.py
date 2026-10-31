"""Atlas contract diff: git revision vs working tree (owner: 03-art).

    python tools/art/contract_diff.py [--rev HEAD] [--json out.json]

Contract = per frame name: owning page, w/h, pivot, nine_slice; per anim set: frame_size, pivot,
facing, anim names, frame lists, fps, loop, hit_frame, events, points; plus page sizes.
Pixel changes and moved rects (x/y) are reported but are NOT contract changes.
Exit code 1 if any contract change is found.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _git_json(rev, rel):
    try:
        out = subprocess.run(["git", "show", f"{rev}:{rel}"], cwd=ROOT, capture_output=True, check=True)
    except subprocess.CalledProcessError:
        return None
    return json.loads(out.stdout.decode("utf-8"))


def _wt_json(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return None
    return json.load(open(p, encoding="utf-8"))


def _pages(manifest):
    return {a["id"]: a["frames"].replace("res://", "") for a in manifest["atlases"]}


def collect(load, manifest_rel="assets/manifest.json"):
    m = load(manifest_rel)
    frames, anims, sizes, rects = {}, {}, {}, {}
    for pid, rel in _pages(m).items():
        d = load(rel)
        if d is None:
            continue
        sizes[pid] = d["size"]
        for n, f in d["frames"].items():
            frames[n] = {"page": pid, "w": f["w"], "h": f["h"], "pivot": f.get("pivot"),
                         "nine_slice": f.get("nine_slice")}
            rects[n] = (pid, f["x"], f["y"])
        for sid, a in d.get("anims", {}).items():
            meta = d.get("anim_sets_meta", {}).get(sid, {})
            anims[sid] = {"page": pid, "meta": meta,
                          "anims": {k: {kk: vv for kk, vv in v.items()} for k, v in a.items()}}
    return frames, anims, sizes, rects


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rev", default="HEAD")
    ap.add_argument("--json")
    args = ap.parse_args()
    f0, a0, s0, r0 = collect(lambda rel: _git_json(args.rev, rel))
    f1, a1, s1, r1 = collect(_wt_json)
    rep = {"rev": args.rev, "frames_added": sorted(set(f1) - set(f0)), "frames_removed": sorted(set(f0) - set(f1)),
           "frame_changes": {}, "frame_page_moves": {}, "anim_changes": {}, "anim_sets_added": sorted(set(a1) - set(a0)),
           "anim_sets_removed": sorted(set(a0) - set(a1)), "page_sizes": {}, "moved_rects": 0}
    for n in sorted(set(f0) & set(f1)):
        x, y = f0[n], f1[n]
        diff = {k: [x[k], y[k]] for k in ("w", "h", "pivot", "nine_slice") if x[k] != y[k]}
        if diff:
            rep["frame_changes"][n] = diff
        if x["page"] != y["page"]:
            rep["frame_page_moves"][n] = [x["page"], y["page"]]
        if r0[n] != r1[n]:
            rep["moved_rects"] += 1
    for sid in sorted(set(a0) & set(a1)):
        x, y = a0[sid], a1[sid]
        d = {}
        if x["meta"] != y["meta"]:
            d["meta"] = [x["meta"], y["meta"]]
        if x["page"] != y["page"]:
            d["page"] = [x["page"], y["page"]]
        if x["anims"] != y["anims"]:
            d["anims"] = {k: [x["anims"].get(k), y["anims"].get(k)]
                          for k in sorted(set(x["anims"]) | set(y["anims"])) if x["anims"].get(k) != y["anims"].get(k)}
        if d:
            rep["anim_changes"][sid] = d
    for p in sorted(set(s0) | set(s1)):
        if s0.get(p) != s1.get(p):
            rep["page_sizes"][p] = [s0.get(p), s1.get(p)]
    contract = any(rep[k] for k in ("frames_added", "frames_removed", "frame_changes", "frame_page_moves",
                                    "anim_changes", "anim_sets_added", "anim_sets_removed", "page_sizes"))
    rep["contract_changed"] = contract
    txt = json.dumps(rep, indent=1, ensure_ascii=False)
    if args.json:
        with open(args.json, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(txt + "\n")
    print(txt)
    sys.exit(1 if contract else 0)


if __name__ == "__main__":
    main()
