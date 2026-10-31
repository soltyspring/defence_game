#!/usr/bin/env python3
"""06-services: Google Play graphic-asset check (no Godot needed). Owner: 06-services.

Usage (workspace root):  python tests/services/check_store_graphics.py [--json out.json]
Rules: docs/services/STORE_GRAPHICS.md section 1 (Google Play "Add preview assets", Play icon design
specs, Android adaptive icon guide; checked 2026-10-31). Exit: 0 = every present asset passes and
nothing required is missing; 3 = nothing fails but required assets are missing; 1 = a present asset fails.
Only mechanical rules are checked (size, format, alpha, file size, safe zone). Content rules (no
ranking words, real gameplay, etc.) need a person.
"""
import glob
import json
import math
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BRANDING = os.path.join(ROOT, "docs", "art", "branding")
STORE_DIR = os.path.join(ROOT, "docs", "services", "store_assets")   # where final store assets go
results = []


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def add(asset, rule, verdict, detail):
    results.append({"asset": asset, "rule": rule, "verdict": verdict, "detail": detail})


def alpha_stats(img):
    if img.mode not in ("RGBA", "LA") and not (img.mode == "P" and "transparency" in img.info):
        return {"has_alpha_channel": False, "transparent_px": 0, "total_px": img.width * img.height}
    a = img.convert("RGBA").getchannel("A")
    hist = a.histogram()
    return {"has_alpha_channel": True, "transparent_px": sum(hist[:255]), "total_px": img.width * img.height,
            "corners_alpha": [a.getpixel((0, 0)), a.getpixel((img.width - 1, 0)), a.getpixel((0, img.height - 1)),
                              a.getpixel((img.width - 1, img.height - 1))]}


def check_play_icon(path):
    """Play store icon: 512x512, 32-bit PNG with alpha, <= 1024 KB, full square (no transparency advised)."""
    name = rel(path)
    img = Image.open(path)
    w, h = img.size
    add(name, "Play icon 512x512", "PASS" if (w, h) == (512, 512) else "FAIL", "%dx%d" % (w, h))
    add(name, "Play icon 32-bit PNG (RGBA)", "PASS" if img.format == "PNG" and img.mode == "RGBA" else "FAIL",
        "%s %s" % (img.format, img.mode))
    kb = os.path.getsize(path) / 1024
    add(name, "Play icon <= 1024 KB", "PASS" if kb <= 1024 else "FAIL", "%.1f KB" % kb)
    st = alpha_stats(img)
    opaque = st.get("transparent_px", 0) == 0
    add(name, "Play icon full square, no transparency (spec: transparent areas show Play's background)",
        "PASS" if opaque else "WARN", "transparent px %d of %d; corner alpha %s" % (
            st.get("transparent_px", 0), st["total_px"], st.get("corners_alpha", "-")))


def check_feature_graphic(path):
    name = rel(path)
    img = Image.open(path)
    add(name, "Feature graphic 1024x500", "PASS" if img.size == (1024, 500) else "FAIL", "%dx%d" % img.size)
    ok_fmt = img.format == "JPEG" or (img.format == "PNG" and img.mode == "RGB")
    add(name, "Feature graphic JPEG or 24-bit PNG (no alpha)", "PASS" if ok_fmt else "FAIL", "%s %s" % (img.format, img.mode))


def check_screenshot(path):
    name = rel(path)
    img = Image.open(path)
    w, h = img.size
    ok_fmt = img.format == "JPEG" or (img.format == "PNG" and img.mode == "RGB")
    add(name, "Screenshot JPEG or 24-bit PNG (no alpha)", "PASS" if ok_fmt else "FAIL", "%s %s" % (img.format, img.mode))
    lo, hi = min(w, h), max(w, h)
    add(name, "Screenshot 320..3840 px, long side <= 2x short side",
        "PASS" if lo >= 320 and hi <= 3840 and hi <= 2 * lo else "FAIL", "%dx%d" % (w, h))
    rec = (w * 9 == h * 16 and w >= 1920) or (h * 9 == w * 16 and h >= 1920)
    add(name, "Game recommendation format: 16:9 landscape >= 1920x1080 (or 9:16 >= 1080x1920)",
        "PASS" if rec else "WARN", "%dx%d" % (w, h))


def check_adaptive(fg_path, bg_path):
    """Adaptive icon layers: 108x108 dp; at 432 px that is 4 px/dp. Safe zone: inner 66 dp circle
    (never clipped by OEM masks); logo at least 48x48 dp; background opaque (06 reading: an
    adaptive background layer is drawn full-bleed under the mask)."""
    for p in (fg_path, bg_path):
        img = Image.open(p)
        add(rel(p), "Adaptive layer 432x432 px (108 dp at xxxhdpi)", "PASS" if img.size == (432, 432) else "FAIL", "%dx%d" % img.size)
    fg = Image.open(fg_path).convert("RGBA")
    bg = Image.open(bg_path).convert("RGBA")
    px_per_dp = fg.width / 108.0
    r_safe = 33 * px_per_dp
    cx = cy = fg.width / 2.0
    a = fg.getchannel("A")
    outside = 0
    xs, ys = [], []
    for y in range(fg.height):
        for x in range(fg.width):
            if a.getpixel((x, y)) > 0:
                xs.append(x)
                ys.append(y)
                # farthest corner of the pixel from the centre
                dx = max(abs(x - cx), abs(x + 1 - cx))
                dy = max(abs(y - cy), abs(y + 1 - cy))
                if math.hypot(dx, dy) > r_safe + 1e-9:
                    outside += 1
    add(rel(fg_path), "Foreground inside the 66 dp safe circle", "PASS" if outside == 0 else "FAIL",
        "%d px outside r=%.0f px" % (outside, r_safe))
    if xs:
        bw = (max(xs) - min(xs) + 1) / px_per_dp
        bh = (max(ys) - min(ys) + 1) / px_per_dp
        add(rel(fg_path), "Logo at least 48x48 dp (and not over 66 dp)",
            "PASS" if max(bw, bh) >= 48 and max(bw, bh) <= 66 else "WARN", "bbox %.1f x %.1f dp" % (bw, bh))
    bt = sum(bg.getchannel("A").histogram()[:255])
    add(rel(bg_path), "Background layer fully opaque", "PASS" if bt == 0 else "FAIL", "%d transparent px" % bt)


def main():
    missing = []
    # 1) Play store icon (512). Candidates: anything 512 in branding or store_assets.
    icons512 = [p for p in glob.glob(os.path.join(BRANDING, "**", "*.png"), recursive=True) +
                glob.glob(os.path.join(STORE_DIR, "icon*.png")) if Image.open(p).size == (512, 512)]
    for p in icons512:
        check_play_icon(p)
    if not icons512:
        missing.append("Play store icon 512x512 (32-bit PNG, <= 1024 KB)")
    # Existing launcher icon candidates: report against the Play icon rule (they are not 512).
    for p in sorted(glob.glob(os.path.join(BRANDING, "app_icon_candidate_*.png"))):
        img = Image.open(p)
        st = alpha_stats(img)
        add(rel(p), "Usable as Play store icon as is?", "NO (wrong size)" if img.size != (512, 512) else "YES",
            "%dx%d %s; transparent px %d; corner alpha %s; integer scale to 512: %s" % (
                img.width, img.height, img.mode, st.get("transparent_px", 0), st.get("corners_alpha", "-"),
                "x%d" % (512 // img.width) if 512 % img.width == 0 else "none (512/%d = %.2f)" % (img.width, 512 / img.width)))
    # 2) Adaptive launcher icon layers.
    fg = os.path.join(BRANDING, "adaptive", "ic_launcher_foreground_432.png")
    bg = os.path.join(BRANDING, "adaptive", "ic_launcher_background_432.png")
    if os.path.exists(fg) and os.path.exists(bg):
        check_adaptive(fg, bg)
    else:
        missing.append("Adaptive icon layers 432x432")
    mono = glob.glob(os.path.join(BRANDING, "adaptive", "*monochrome*.png"))
    add("docs/art/branding/adaptive/*monochrome*", "Monochrome layer (optional; themed icons on Android 13+)",
        "PRESENT" if mono else "ABSENT (optional)", "%d file(s)" % len(mono))
    # 3) Feature graphic, 4) screenshots: final store assets are expected in docs/services/store_assets/.
    feats = glob.glob(os.path.join(STORE_DIR, "feature*.png")) + glob.glob(os.path.join(STORE_DIR, "feature*.jpg"))
    for p in feats:
        check_feature_graphic(p)
    if not feats:
        missing.append("Feature graphic 1024x500 (JPEG or 24-bit PNG, no alpha)")
    shots = sorted(glob.glob(os.path.join(STORE_DIR, "screenshot*.png")) + glob.glob(os.path.join(STORE_DIR, "screenshot*.jpg")))
    for p in shots:
        check_screenshot(p)
    if len(shots) < 2:
        missing.append("Screenshots: at least 2 (store minimum); 3+ 16:9 >= 1920x1080 for game recommendations (%d found)" % len(shots))
    # 5) Existing captures that could become screenshots (format/size only).
    caps = {}
    for p in glob.glob(os.path.join(ROOT, "docs", "**", "*.png"), recursive=True):
        try:
            caps.setdefault(Image.open(p).size, []).append(rel(p))
        except Exception:
            pass
    for size in [(1280, 720), (1600, 720), (1920, 1080)]:
        n = len(caps.get(size, []))
        lo, hi = min(size), max(size)
        basic = lo >= 320 and hi <= 3840 and hi <= 2 * lo
        add("existing captures %dx%d (%d files)" % (size[0], size[1], n), "Screenshot size rules",
            ("basic PASS" if basic else "basic FAIL") + ("; recommendation PASS" if size == (1920, 1080) else "; recommendation WARN (< 1920x1080 or not 16:9)"),
            "e.g. %s" % (caps[size][0] if n else "-"))
    fails = [r for r in results if r["verdict"] == "FAIL"]
    for r in results:
        print("%-62s | %-58s | %-22s | %s" % (r["asset"][:62], r["rule"][:58], r["verdict"], r["detail"]))
    print("MISSING:", missing if missing else "none")
    out = {"results": results, "missing": missing}
    if "--json" in sys.argv:
        with open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)
    code = 1 if fails else (3 if missing else 0)
    print("EXIT", code)
    return code


if __name__ == "__main__":
    sys.exit(main())
