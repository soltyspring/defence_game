"""Measure title-logo renders and app-icon legibility (owner: 03-art).

    python tools/art/branding_check.py docs/art/evidence/branding

Logo: for each Godot render at scale s (360-px-wide reference view), every logo must
(a) fit inside 360 px with >= 4 px margin, (b) equal the source frame upscaled x s
with nearest (pixel-exact, no blur/shimmer) -> max channel diff 0.
Icon (internal lines, fixed before measuring, not player-validated):
  subject (hero) bounding box >= 50 % of the icon height at 48 px,
  foreground outside the central 32x32 safe zone: 0 px excluding the 1 px outline,
  mean dL* hero vs background >= 25, mould blob vs background >= 25,
  content inside the central 66 % safe zone except the rolling-pin tip.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)


def lab_L(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    Y = c[..., 0] * 0.2126 + c[..., 1] * 0.7152 + c[..., 2] * 0.0722
    return np.where(Y > 0.008856, 116 * np.cbrt(Y) - 16, 903.3 * Y)


def safe_zone():
    z = np.zeros((48, 48), bool)
    z[8:40, 8:40] = True          # central 32x32 = 66 % (Android adaptive icon safe zone)
    return z


def branding_bg_mask(ic):
    import branding
    bg = branding.icon48(background_only=True)
    return (bg.a > 0) & (bg.a == ic.a)


def fg_mask(ic):
    return ~branding_bg_mask(ic) & (ic.a > 0)


def main(d):
    rep = json.load(open(os.path.join(d, "report.json"), encoding="utf-8-sig"))
    doc = json.load(open(os.path.join(ROOT, "assets", "atlases", "ui_title.json"), encoding="utf-8"))
    page = np.array(Image.open(os.path.join(ROOT, "assets", "atlases", "ui_title.png")).convert("RGBA"))
    out = {"logos": [], "icon": {}, "window_screen": rep.get("window_screen"), "primary_screen": rep.get("primary_screen")}
    bg = np.array([40, 44, 58])
    for r in rep["renders"]:
        s = r["scale"]
        g = np.array(Image.open(os.path.join(d, f"title_{s}x.png")).convert("RGB")).astype(int)
        for name, x, y, w, h in r["layout"]:
            x, y, w, h = int(x), int(y), int(w), int(h)
            f = doc["frames"][name]
            src = page[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]].astype(float)
            a = src[..., 3:4] / 255.0
            comp = src[..., :3] * a + bg * (1 - a)
            exp = np.kron(np.rint(comp), np.ones((s, s, 1))).astype(int)
            got = g[int(y) * s:int(y) * s + h * s, int(x) * s:int(x) * s + w * s]
            diff = int(np.abs(got - exp).max())
            out["logos"].append({"scale": s, "name": name, "w": w, "h": h, "fits_360": w <= 352,
                                 "device_w": w * s, "pixel_exact_maxdiff": diff})
    # icon legibility at 48 (native)
    import branding
    from pixel import RGBA, IDX
    ic = branding.icon48()
    rgb = RGBA[ic.a][..., :3].astype(float)
    L = lab_L(rgb)
    hero_keys = [IDX[k] for k in "WxUTR"]
    mould_keys = [IDX[k] for k in "ltz"]
    bgk = [IDX[k] for k in "oOwT"]
    hero = np.isin(ic.a, [IDX[k] for k in "WxURYZ"])
    hero[:, 28:] = False                       # left part = hero (excludes pin + blob)
    back = np.zeros_like(hero)
    back[:, :] = False
    mould = np.isin(ic.a, mould_keys)
    bgmask = branding_bg_mask(ic)
    back = bgmask
    ys, xs = np.nonzero(hero)
    out["icon"] = {
        "hero_bbox_h_pct": round((ys.max() - ys.min() + 1) / 48 * 100, 1),
        "dL_hero_vs_bg": round(float(abs(L[hero].mean() - L[back].mean())), 1),
        "dL_mould_vs_bg": round(float(abs(L[mould].mean() - L[back].mean())), 1),
        "outside_safe_zone_px": int((fg_mask(ic) & ~safe_zone()).sum()),
        "outside_safe_zone_px_excl_outline": int((fg_mask(ic) & ~safe_zone() & (ic.a != IDX["K"])).sum()),
        "godot_import": rep.get("icons"),
    }
    json.dump(out, open(os.path.join(d, "branding_metrics.json"), "w", encoding="utf-8"), indent=1)
    for l in out["logos"]:
        print(f"{l['scale']}x {l['name']:22s} {l['w']}x{l['h']} fits_360={l['fits_360']} pixel_exact_maxdiff={l['pixel_exact_maxdiff']}")
    print("icon", out["icon"], "screen", out["window_screen"], "/primary", out["primary_screen"])


if __name__ == "__main__":
    main(sys.argv[1])
