#!/usr/bin/env python3
"""04-client: on-screen size of every lane unit on target phones (no Godot). Owner: 04-client.

Usage (workspace root):  python tools/build/unit_screen_size.py [--json out.json] [--md out.md]
Body height = rows with alpha > 0 in the unit's idle frame 0 (and the tallest walk frame), read from the
atlas PNG + JSON in assets/atlases (manifest anim_sets). Screen size uses the game's integer scale rule
(App._apply_pixel_scale: k = max(1, min(W/640, H/360)), view = window / k) and the device density:
  physical px = h * k * world_zoom;  mm = physical px / (density * 160) * 25.4
Devices (landscape, 1080x2400 physical, the common size for these dp classes):
  360x800 dp @ 3.0, 393x873 dp @ 2.75, 412x915 dp @ 2.625 (1440x3200 @ 3.5 gives the same mm: k=4).
Readability line: 6 mm body height (about 1.0 deg of visual angle at a 33 cm phone viewing distance).
This is a working criterion proposed for this project, not a published standard.
"""
import json
import math
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ATL = os.path.join(ROOT, "assets", "atlases")
DEVICES = [("360x800dp", 2400, 1080, 3.0), ("393x873dp", 2400, 1080, 2.75), ("412x915dp", 2400, 1080, 2.625)]
LINE_MM = 6.0
UNITS = ["hero_captain", "worker", "melee_basic", "ranged_basic", "tank", "fast", "siege",
         "e_grunt", "e_spitter", "e_swarm", "e_brute", "e_bomber", "boss_warlord", "boss_overlord"]


def k_of(w, h):
    return max(1, min(w // 640, h // 360))


def body_px(atlas_id, frame_names, cache):
    if atlas_id not in cache:
        meta = json.load(open(os.path.join(ATL, atlas_id + ".json"), encoding="utf-8"))
        cache[atlas_id] = (meta, Image.open(os.path.join(ATL, meta.get("image", atlas_id + ".png"))).convert("RGBA"))
    meta, img = cache[atlas_id]
    best = (0, 0, 0)
    for fn in frame_names:
        f = meta["frames"].get(fn)
        if not f:
            continue
        crop = img.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])).getchannel("A")
        bb = crop.getbbox()
        if bb is None:
            continue
        h = bb[3] - bb[1]
        if h > best[0]:
            best = (h, f["h"], bb[2] - bb[0])
    return best   # (visible body px, frame px, visible width px)


def main():
    man = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    sets = man["anim_sets"]
    cache = {}
    rows = []
    for u in UNITS:
        a = sets.get(u)
        if not a or not os.path.exists(os.path.join(ATL, a + ".json")):
            rows.append({"unit": u, "missing": True})
            continue
        meta = json.load(open(os.path.join(ATL, a + ".json"), encoding="utf-8"))
        anims = meta.get("anims", {}).get(u, {})
        names = anims.get("idle", {}).get("frames", [])[:1] + anims.get("walk", {}).get("frames", [])
        h, fh, w = body_px(a, names, cache)
        r = {"unit": u, "atlas": a, "frame_h": fh, "body_px": h, "body_w_px": w, "view_pct": round(100.0 * h / 360.0, 1), "devices": {}}
        for name, W, H, d in DEVICES:
            k = k_of(W, H)
            mm = h * k / (d * 160.0) * 25.4
            need = math.ceil(LINE_MM * d * 160.0 / 25.4 / k)
            r["devices"][name] = {"k": k, "physical_px": h * k, "mm": round(mm, 2), "readable": mm >= LINE_MM, "body_px_needed": need}
        rows.append(r)
    out = {"line_mm": LINE_MM, "devices": [{"name": n, "px": [w, h], "density": d, "k": k_of(w, h), "mm_per_view_px": round(k_of(w, h) / (d * 160) * 25.4, 4)} for n, w, h, d in DEVICES], "units": rows}
    hdr = "| unit | frame h | body h (view px, % of 360) | " + " | ".join("%s: phys px / mm" % n for n, *_ in DEVICES) + " | body px for 6 mm on 360 dp |"
    lines = [hdr, "|" + "---|" * (4 + len(DEVICES))]
    for r in rows:
        if r.get("missing"):
            lines.append("| %s | – | atlas missing | %s | – |" % (r["unit"], " | ".join("–" for _ in DEVICES)))
            continue
        cells = []
        for n, *_ in DEVICES:
            dv = r["devices"][n]
            cells.append("%d / %.1f%s" % (dv["physical_px"], dv["mm"], "" if dv["readable"] else " (<6)"))
        lines.append("| %s | %d | %d (%.1f %%) | %s | %d |" % (r["unit"], r["frame_h"], r["body_px"], r["view_pct"], " | ".join(cells), r["devices"][DEVICES[0][0]]["body_px_needed"]))
    md = "\n".join(lines)
    print(md)
    if "--json" in sys.argv:
        json.dump(out, open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    if "--md" in sys.argv:
        open(sys.argv[sys.argv.index("--md") + 1], "w", encoding="utf-8").write(md + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
