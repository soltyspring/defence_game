"""Before/after contact sheets from two world_cam.gd capture folders (owner: 09-art-world).

    python tools/art/world/pair_sheet.py <before_dir> <after_dir> <out_dir> [name ...]

For every capture name present in both folders (or the names given), stacks the real `_full` frames: before on top,
after below, 1x, with a 2 px gap. Also writes one sheet of the base captures (base_<side>_<state>) when present.
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image


def names(d):
    r = json.load(open(os.path.join(d, "shots", "world_report.json"), encoding="utf-8"))
    return [c["name"] for c in r["captures"] if "name" in c]


def main(before, after, out, only=None):
    os.makedirs(out, exist_ok=True)
    common = [n for n in names(before) if n in set(names(after))]
    if only:
        common = [n for n in common if n in only]
    rounds = {}
    for n in common:
        key = "bases" if n.startswith("base_") else n.split("_")[0]
        rounds.setdefault(key, []).append(n)
    for key, ns in rounds.items():
        tiles = []
        for n in ns:
            a = Image.open(os.path.join(before, "shots", n + "_full.png")).convert("RGB")
            b = Image.open(os.path.join(after, "shots", n + "_full.png")).convert("RGB")
            tiles.append((a, b))
        w, h = tiles[0][0].size
        sheet = Image.new("RGB", (len(tiles) * (w + 2) - 2, 2 * h + 2), (255, 0, 255))
        for i, (a, b) in enumerate(tiles):
            sheet.paste(a, (i * (w + 2), 0))
            sheet.paste(b, (i * (w + 2), h + 2))
        p = os.path.join(out, f"pair_{key}_top-before_bottom-after_1x.png")
        sheet.save(p)
        print(p, [n for n in ns])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:] or None)
