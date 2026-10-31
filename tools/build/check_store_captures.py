#!/usr/bin/env python3
"""04-client: check store screenshot captures with 06's Play rules (no Godot). Owner: 04-client.

Usage (workspace root):  python tools/build/check_store_captures.py [dir] [--json out.json]
Default dir: docs/qa/store_captures. Uses check_screenshot() from 06's tests/services/check_store_graphics.py
(imported read-only, a68bf51 rules: JPEG or 24-bit PNG without alpha; 320..3840 px; long side <= 2x short;
16:9 >= 1920x1080 for game recommendations). Adds two 04 checks:
  - black frame (PC locked / nothing presented): > 90% of sampled pixels darker than luminance 5/255 = INVALID
  - exact size 1920x1080 (the 640x360 view at integer x3)
Exit 0 = every file passes and none is INVALID; 1 = a FAIL or INVALID; 3 = no files.
"""
import glob
import importlib.util
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
spec = importlib.util.spec_from_file_location("svc_graphics", os.path.join(ROOT, "tests", "services", "check_store_graphics.py"))
svc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(svc)


def black_pct(path, step=16):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    px = img.load()
    dark = total = 0
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            total += 1
            if 0.2126 * r + 0.7152 * g + 0.0722 * b < 5:
                dark += 1
    return 100.0 * dark / max(1, total)


def main():
    argv = sys.argv[1:]
    if "--json" in argv:
        i = argv.index("--json")
        argv = argv[:i] + argv[i + 2:]
    args = [a for a in argv if not a.startswith("--")]
    d = os.path.join(ROOT, args[0]) if args else os.path.join(ROOT, "docs", "qa", "store_captures")
    files = sorted(glob.glob(os.path.join(d, "*.png")) + glob.glob(os.path.join(d, "*.jpg")))
    if not files:
        print("no captures in", d)
        return 3
    bad = 0
    for p in files:
        svc.check_screenshot(p)
        size = Image.open(p).size
        svc.add(svc.rel(p), "04: exactly 1920x1080 (640x360 view x3)", "PASS" if size == (1920, 1080) else "FAIL", "%dx%d" % size)
        bp = black_pct(p)
        svc.add(svc.rel(p), "04: not a black frame (locked PC / not presented)", "PASS" if bp <= 90.0 else "INVALID", "%.1f%% dark samples" % bp)
    for r in svc.results:
        if r["verdict"] in ("FAIL", "INVALID"):
            bad += 1
        print("%-8s %-58s %-70s %s" % (r["verdict"], r["asset"], r["rule"][:70], r["detail"]))
    print("files=%d checks=%d fail_or_invalid=%d" % (len(files), len(svc.results), bad))
    if "--json" in sys.argv:
        with open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8") as f:
            json.dump({"files": [svc.rel(p) for p in files], "results": svc.results}, f, indent=1, ensure_ascii=False)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
