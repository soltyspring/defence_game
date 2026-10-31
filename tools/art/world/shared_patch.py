"""Patch the shared generated files with ONLY this role's pages (owner: 09-art-world).

    python tools/art/world/shared_patch.py <build_dir> <out_dir> [--rev HEAD]

assets/manifest.json and docs/art/ATLAS_BUDGET.md are written by build.py and shared by 03, 06-art-ui and 09
(coordination/OWNERSHIP.md). When other pages in the tree are uncommitted work of another role, a plain build would
carry their numbers into this role's commit. This script takes the committed files at <rev>, replaces only the
entries of biome_meadow, bases and fx_combat (atlas rows, biomes block, page rows) with the values of <build_dir>
(a build of <rev> + this role's sources), recomputes the totals, and writes both files in build.py's exact format.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys

MINE = ("biome_meadow", "bases", "fx_combat")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def show(rev, path):
    return subprocess.run(["git", "show", f"{rev}:{path}"], cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8")


def main(build_dir, out, rev="HEAD"):
    os.makedirs(out, exist_ok=True)
    head = json.loads(show(rev, "assets/manifest.json"))
    new = json.load(open(os.path.join(build_dir, "assets", "manifest.json"), encoding="utf-8"))
    by_id = {a["id"]: a for a in new["atlases"]}
    changed = []
    for i, a in enumerate(head["atlases"]):
        if a["id"] in MINE and a != by_id[a["id"]]:
            changed.append(a["id"])
            head["atlases"][i] = by_id[a["id"]]
    head["biomes"] = new["biomes"]
    head["totals"]["disk_bytes"] = sum(a["disk_bytes"] for a in head["atlases"])
    with open(os.path.join(out, "manifest.json"), "w", newline="\n", encoding="utf-8") as f:
        json.dump(head, f, indent=1, ensure_ascii=False)
    # budget: replace my rows, recompute the disk total from the patched manifest
    hb = show(rev, "docs/art/ATLAS_BUDGET.md").replace("\r\n", "\n").split("\n")
    nb = open(os.path.join(build_dir, "docs", "art", "ATLAS_BUDGET.md"), encoding="utf-8").read().split("\n")
    rows = {ln.split("`")[1]: ln for ln in nb if ln.startswith("| `")}
    out_lines = []
    for ln in hb:
        if ln.startswith("| `") and ln.split("`")[1] in MINE:
            ln = rows[ln.split("`")[1]]
        elif ln.startswith("| **Total**"):
            parts = ln.split("|")
            parts[5] = f" **{head['totals']['disk_bytes'] / 1024:.1f} KiB** "
            ln = "|".join(parts)
        out_lines.append(ln)
    with open(os.path.join(out, "ATLAS_BUDGET.md"), "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(out_lines))
    print("patched atlases:", changed, "| totals.disk_bytes:", head["totals"]["disk_bytes"])


if __name__ == "__main__":
    a = sys.argv[1:]
    rev = "HEAD"
    if "--rev" in a:
        rev = a[a.index("--rev") + 1]
        a = [x for x in a if x not in ("--rev", rev)]
    main(a[0], a[1], rev)
