"""Compare Godot-rendered ui_main contact sheets with the expected sheet built from the
source PNG + manifest rects (owner: 03-art).  python tools/art/ui_sheet_compare.py <dir>
Writes expected_sheet.png, diff_<state>.png and compare.json (per-frame pixel equality)."""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def main(d):
    lay = json.load(open(os.path.join(d, "ui_sheet_layout.json"), encoding="utf-8"))
    doc = json.load(open(os.path.join(ROOT, "assets", "atlases", "ui_main.json"), encoding="utf-8"))
    src = Image.open(os.path.join(ROOT, "assets", "atlases", "ui_main.png")).convert("RGBA")
    exp = Image.new("RGBA", (640, 360), (40, 44, 58, 255))
    for n, x, y, w, h in lay:
        f = doc["frames"][n]
        exp.alpha_composite(src.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])), (int(x), int(y)))
    exp.save(os.path.join(d, "expected_sheet.png"))
    e = np.array(exp.convert("RGB")).astype(int)
    res = {}
    for state in ("stale", "fixed"):
        p = os.path.join(d, f"ui_main_godot_sheet_{state}.png")
        if not os.path.exists(p):
            continue
        g0 = Image.open(p).convert("RGB")
        k = g0.width // 640                       # integer stretch factor of the capture
        g = np.array(g0).astype(int)[::k, ::k][: e.shape[0], : e.shape[1]]
        res_scale = k
        bad = []
        for n, x, y, w, h in lay:
            x, y, w, h = int(x), int(y), int(w), int(h)
            if not np.array_equal(g[y:y + h, x:x + w], e[y:y + h, x:x + w]):
                bad.append(n)
        diff = (np.abs(g - e).sum(axis=2) > 0)
        im = Image.fromarray((np.dstack([diff * 255, diff * 40, diff * 40])).astype(np.uint8))
        im.save(os.path.join(d, f"diff_{state}.png"))
        res[state] = {"frames": len(lay), "frames_differing": len(bad), "sample": bad[:10],
                      "pixels_differing": int(diff.sum()), "capture_scale": res_scale}
        print(f"{state}: rendered sheet vs source+manifest: {len(bad)}/{len(lay)} frames differ, {int(diff.sum())} px")
    json.dump(res, open(os.path.join(d, "compare.json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1])
