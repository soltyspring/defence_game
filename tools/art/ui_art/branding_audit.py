#!/usr/bin/env python3
"""06-art-ui: launcher icon + title logo against docs/art/ui/BRANDING_CRITERIA.md (B1-B6, T1-T4). Owner: 06-art-ui. No Godot.

Reads the written files (assets/branding/launcher_*_432.png, docs/art/branding/store/*, assets/atlases/ui_title_*) or, with
--src <dir>, the same relative paths under <dir> (a clean HEAD copy after a rebuild). Genre icons for B5 come from
%TEMP%/genre_ref/<game>_00.png (official Play store icons downloaded 2026-11-01 02:50 KST, never stored in the repo).
Title on screen (T1-T3): 07's ad47eda menu frames (800x360 view, safe 34,0,34,0), logo bbox = pixels whose colour is a
logo palette colour inside the top half. Usage: python tools/art/ui_art/branding_audit.py [--src DIR] [--json OUT]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import ui_audit as A  # noqa: E402

MM = 393.0 / 360.0 * 0.15875
GENRE = ["battlecats", "catwar2", "stickwar", "growcastle", "aow2"]
WALL = {"light": (0xf2, 0xf2, 0xf2), "dark": (0x20, 0x21, 0x24)}
THEME = {"light": ((0xd8, 0xe2, 0xff), (0x00, 0x1a, 0x41)), "dark": ((0x00, 0x1a, 0x41), (0xd8, 0xe2, 0xff))}


def rgba(p):
    return np.array(Image.open(p).convert("RGBA"))


def lab(img):
    return np.stack([A.lab(c) for c in img.reshape(-1, 3)]).reshape(img.shape)


def masks(n):
    yy, xx = np.mgrid[0:n, 0:n]
    c = (n - 1) / 2.0
    u, v = (xx - c) / (n / 2.0), (yy - c) / (n / 2.0)
    r = 0.5 * 0.4 * 2   # rounded square corner radius 20 % of the side
    rs = (np.maximum(np.abs(u) - (1 - r), 0) ** 2 + np.maximum(np.abs(v) - (1 - r), 0) ** 2) <= r * r
    return {"circle": u * u + v * v <= 1.0, "rounded_square": rs, "squircle": np.abs(u) ** 4 + np.abs(v) ** 4 <= 1.0,
            "teardrop": (u * u + v * v <= 1.0) | ((u > 0) & (v > 0) & (np.maximum(u, v) <= 1.0))}


def visible(fg, bg):
    """Composite fg over bg (432 = 108 dp) and crop the 72 dp visible square (offset 18 dp = 72 px)."""
    a = fg[..., 3:4] / 255.0
    comp = fg[..., :3] * a + bg[..., :3] * (1 - a)
    return comp[72:360, 72:360], fg[72:360, 72:360, 3] > 0


def down(img, n):
    return np.array(Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((n, n), Image.BOX)).astype(float)


def subprocess_show(path):
    import subprocess
    return subprocess.run(["git", "show", "HEAD:" + path], cwd=ROOT, capture_output=True, check=True).stdout.decode("utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=ROOT)
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    S = a.src
    fg = rgba(os.path.join(S, "assets/branding/launcher_adaptive_foreground_432.png")).astype(float)
    bg = rgba(os.path.join(S, "assets/branding/launcher_adaptive_background_432.png")).astype(float)
    mono = rgba(os.path.join(S, "assets/branding/launcher_adaptive_monochrome_432.png")).astype(float)
    rep = {"src": "working tree" if os.path.abspath(S) == ROOT else "clean HEAD copy (" + os.path.basename(os.path.abspath(S)) + ")"}
    # B1 safe circle 66 dp (r = 33 dp = 132 px) on the 432 canvas
    yy, xx = np.mgrid[0:432, 0:432]
    # farthest pixel corner from the canvas centre (216, 216), same rule as tests/services/check_store_graphics.py
    dxm = np.maximum(np.abs(xx - 216.0), np.abs(xx + 1 - 216.0)); dym = np.maximum(np.abs(yy - 216.0), np.abs(yy + 1 - 216.0))
    out = (fg[..., 3] > 0) & (np.hypot(dxm, dym) > 132 + 1e-9)
    vis, fgm = visible(fg, bg)
    clipped = {k: int((fgm & ~m).sum()) for k, m in masks(288).items()}
    rep["B1"] = {"fg_outside_66dp_px": int(out.sum()), "mask_clipped_px": clipped, "pass": int(out.sum()) == 0 and max(clipped.values()) == 0}
    # B2 silhouette at 48 / 36 dp (mdpi px): hero = fg pixels that are not mould greys (palette t, l, z, D)
    # mould blob colours: sage ramp (t l z D) up to ui-art 1.2, blue-mould teal (q Q d) from ui-art 1.3; same object either way
    mould_cols = np.array([[0x84, 0xa0, 0x8c], [0x4b, 0x60, 0x5d], [0xdc, 0xe8, 0xdf], [0x1e, 0x2b, 0x30],
                           [0x2a, 0x7f, 0x9e], [0x4f, 0xe3, 0xe0], [0x23, 0x48, 0x5a]], float)
    fv = fg[72:360, 72:360]
    is_m = np.zeros(fv.shape[:2], bool)
    for c in mould_cols:
        is_m |= np.all(np.abs(fv[..., :3] - c) < 1, axis=-1)
    is_k = np.all(np.abs(fv[..., :3] - [0x1b, 0x13, 0x25]) < 1, axis=-1)
    hero = (fv[..., 3] > 0) & ~is_m & ~is_k
    mould = (fv[..., 3] > 0) & is_m
    rep["B2"] = {}
    ok2 = True
    for n in (48, 36):
        im = down(vis, n)
        hm = np.array(Image.fromarray((hero * 255).astype(np.uint8)).resize((n, n), Image.BOX)) > 127
        mm = np.array(Image.fromarray((mould * 255).astype(np.uint8)).resize((n, n), Image.BOX)) > 127
        bm = ~(np.array(Image.fromarray((fgm * 255).astype(np.uint8)).resize((n, n), Image.BOX)) > 32)
        L = lab(im)
        r = {"hero_area_pct": round(100.0 * hm.mean(), 1),
             "hero_dL_vs_bg": round(float(abs(L[hm][:, 0].mean() - L[bm][:, 0].mean())), 1) if hm.any() and bm.any() else None}
        hmc, mmc = im[hm].mean(axis=0), im[mm].mean(axis=0) if mm.any() else None
        r["hero_vs_mould_dE"] = {k: round(A.dE(A.sim(hmc, k), A.sim(mmc, k)), 1) for k in ("normal", "protan", "deutan")} if mmc is not None else None
        r["pass"] = bool(r["hero_area_pct"] >= 25 and (r["hero_dL_vs_bg"] or 0) >= 25 and r["hero_vs_mould_dE"] and min(r["hero_vs_mould_dE"].values()) >= 20)
        ok2 &= r["pass"]
        rep["B2"][f"{n}dp"] = r
        Image.fromarray(np.clip(im, 0, 255).astype(np.uint8)).resize((n * 4, n * 4), Image.NEAREST).save(os.path.join(ROOT, "build", "ui06", f"icon_{n}dp_x4.png"))
    rep["B2"]["pass"] = ok2
    # B3 edge band (2 dp = 8 px) of each mask vs wallpapers
    rep["B3"] = {}
    ok3 = True
    for k, m in masks(288).items():
        band = m & ~ndimage.binary_erosion(m, iterations=8)
        col = vis[band].mean(axis=0)
        r = {w: round(A.wcag(col, c), 2) for w, c in WALL.items()}
        ok3 &= min(r.values()) >= 1.5
        rep["B3"][k] = r
    rep["B3"]["pass"] = bool(ok3)
    # B4 monochrome at 48 dp, themed
    ma = mono[72:360, 72:360, 3] / 255.0
    m48 = np.array(Image.fromarray((ma * 255).astype(np.uint8)).resize((48, 48), Image.BOX)) > 127
    ncomp = int(ndimage.label(m48)[1])
    rep["B4"] = {"area_pct_48dp": round(100.0 * m48.mean(), 1), "components_48dp": ncomp,
                 "pass": bool(15 <= 100.0 * m48.mean() <= 60 and ncomp <= 3)}
    # B5 genre icons
    ours48 = down(vis, 48)
    o16 = lab(down(vis, 16))[..., 0]
    rep["B5"] = {}
    ok5 = True
    for g in GENRE:
        p = os.path.join(os.environ.get("TEMP", "/tmp"), "genre_ref", f"{g}_00.png")
        if not os.path.exists(p):
            rep["B5"][g] = "icon not available"; ok5 = False; continue
        gi = np.array(Image.open(p).convert("RGB")).astype(float)
        g48 = down(gi, 48)
        g16 = lab(down(gi, 16))[..., 0]
        de = round(A.dE(ours48.reshape(-1, 3).mean(axis=0), g48.reshape(-1, 3).mean(axis=0)), 1)
        pat = round(float(np.abs(o16 - g16).mean()), 1)
        rep["B5"][g] = {"mean_dE": de, "pattern_dL": pat, "pass": bool(de >= 15 and pat >= 12)}
        ok5 &= de >= 15 and pat >= 12
    rep["B5"]["pass"] = bool(ok5)
    # B6 store files
    st = {}
    for f, need in (("docs/art/branding/store/store_icon_512.png", (512, 512)),
                    ("docs/art/branding/store/feature_graphic_ko_1024x500.png", (1024, 500)),
                    ("docs/art/branding/store/feature_graphic_en_1024x500.png", (1024, 500))):
        p = os.path.join(S, f)
        if not os.path.exists(p):
            st[f] = "missing"; continue
        im = Image.open(p)
        info = {"size": list(im.size), "mode": im.mode, "size_ok": tuple(im.size) == need}
        if im.mode == "RGBA":
            info["alpha_min"] = int(np.array(im)[..., 3].min())
        st[f] = info
    rep["B6"] = st
    # T1-T4 title: src/ui/main_menu.gd _draw() slot + src/ui/title_block.gd compute() (largest integer scale k >= 1 of
    # logo_title_<loc> / _2line that fits the slot), for the 393 dp view (800x360, safe 34,0,34,0) and two narrower views.
    sys.path.insert(0, os.path.join(S, "tools", "art"))
    import branding
    rep["T"] = {}
    views = {"393dp_800x360_notch34": (800, 360, 34, 34), "640x360": (640, 360, 0, 0), "720x360_notch34": (720, 360, 34, 34)}
    ok = {"T1": True, "T2": True, "T3": True, "T4": True}
    for loc in ("ko", "en"):
        meta = json.load(open(os.path.join(S, f"assets/atlases/ui_title_{loc}.json"), encoding="utf-8"))
        page = np.array(Image.open(os.path.join(S, f"assets/atlases/ui_title_{loc}.png")).convert("RGBA"))
        head = json.loads(subprocess_show(f"assets/atlases/ui_title_{loc}.json"))
        r = {"page_size": meta.get("size"), "page_size_HEAD": head.get("size")}
        if meta.get("size") != head.get("size") or set(meta["frames"]) != set(head["frames"]):
            ok["T4"] = False
        # T2: the 2-line frame = two blocks of glyph rows; text split at the colon (branding.KO_A / KO_B, EN_A / EN_B)
        two = meta["frames"][f"logo_title_{loc}_2line"]
        crop = page[two["y"]:two["y"] + two["h"], two["x"]:two["x"] + two["w"], 3] > 0
        rows = np.nonzero(crop.any(axis=1))[0]
        gaps = [i for i in range(1, len(rows)) if rows[i] - rows[i - 1] > 1]
        a_txt = branding.KO_A if loc == "ko" else branding.EN_A
        b_txt = branding.KO_B if loc == "ko" else branding.EN_B
        full = branding.KO_FULL if loc == "ko" else branding.EN_FULL
        r["two_line_text"] = [a_txt, b_txt]
        r["split_at_colon"] = bool(full.replace(" ", "") == (a_txt + ":" + b_txt).replace(" ", ""))
        ok["T2"] &= r["split_at_colon"]
        # glyph line heights (rows of the first line, drop shadow 2 px excluded) in art px
        line_h = []
        lab_, n_ = ndimage.label(crop.any(axis=1))
        for i in range(1, n_ + 1):
            ys_ = np.nonzero(lab_ == i)[0]
            line_h.append(int(ys_.max() - ys_.min() + 1))
        r["views"] = {}
        for vn, (vw, vh, sl, sr) in views.items():
            safe_w = vw - sl - sr
            slot = (sl + 8, 28, safe_w - 16, max(40.0, (vh * 0.5 - 22) - 28))
            best = None
            for fr in (f"logo_title_{loc}", f"logo_title_{loc}_2line"):
                f = meta["frames"][fr]
                k = int(np.floor(min(slot[2] / f["w"], slot[3] / f["h"])))
                if k < 1:
                    continue
                area = f["w"] * k * f["h"] * k
                if best is None or area > best[3]:
                    best = (fr, k, (f["w"] * k, f["h"] * k), area)
            if best is None:
                r["views"][vn] = {"logo": None, "fallback": "text (title_block.gd)"}
                ok["T1"] = False
                continue
            fr, k, (dw, dh), _ = best
            glyph_px = (min(line_h) - 3) if fr.endswith("_2line") else (two["h"] // 2 - 3) // 1
            mm = round(glyph_px * k * MM, 2) if fr.endswith("_2line") else round((meta["frames"][fr]["h"] - 5) * k * MM, 2)
            v = {"frame": fr, "scale": k, "drawn": [dw, dh], "width_pct_of_view": round(100.0 * dw / vw, 1),
                 "fits_slot": bool(dw <= slot[2] and dh <= slot[3]), "glyph_height_mm_est": mm}
            ok["T1"] &= v["fits_slot"] and v["width_pct_of_view"] <= 92.0
            ok["T3"] &= mm >= 2.5
            r["views"][vn] = v
        rep["T"][loc] = r
    logo = A.audit_logo()
    rep["T"]["T3_face_share_ge3"] = {k: v["share_ge3"] for k, v in logo.items()}
    ok["T3"] &= all(v["share_ge3"] >= 0.80 for v in logo.values())
    rep["T"]["pass"] = ok
    print(json.dumps(rep, ensure_ascii=False, indent=1))
    if a.json:
        json.dump(rep, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
