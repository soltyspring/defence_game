#!/usr/bin/env python3
"""06-art-ui: put 09's new battlefield (biome_meadow + bases at a SHA) under 07's ad47eda fixed-set frames, in Python.
Owner: 06-art-ui. No Godot. PROPOSAL MOCK input, not screen evidence.

How (1x, 800x360 logical):
  1. Re-render the ad47eda background from the ad47eda biome atlas with battle_view.gd's own layer rule
     (bx = floor(cam_x * (1 - parallax) + 0.5), tiles every frame width, view_y / ground_y - lane_line) and check it
     reproduces 07's `_bg` layer frame (match % reported). Pixels of `_bg` the biome render does not explain = bases etc.
  2. Base sprites: find each ad47eda base frame in `_bg` by exact template match, then draw the new SHA's frame of the
     same name at the same pivot point.
  3. Render the new biome (same rule, new atlas) -> new back; draw new bases; paste the unit pixels (`_htf` != `_bg`),
     re-blending translucent unit shadows (96/255 of K) over the new ground; draw the new front layer; then the fx/text
     pixels (`_h` != `_htf`) and finally the HUD pixels (`full` != `_h`) unchanged.
  4. 2x = exact 2x of the 1x result (07 G3 says 2x frames are a x2 copy of 1x up to 44-101 px).
Output: <out>/<tag>_<scene>.png and <out>/layers/<tag>_<scene>_{h,ht,htf,bg}.png + the report json copies, i.e. the
same layout as 07's set, so tools/qa/art_metrics.scene_metrics and hud_mock.py read it unchanged.
Usage: python tools/art/ui_art/bg_swap.py --sha 92a1718 --out build/ui06/bg_92a1718
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
E = os.path.join(ROOT, "docs", "verification", "evidence", "art-baseline-ad47eda")
L = os.path.join(ROOT, "build", "qa07", "art-baseline-ad47eda", "run1", "layers")
SCENES = ["2_r01_t10", "3_r01_t30", "4_r06_t46", "5_r08_peak", "6_r10_boss"]
K = np.array([0x1b, 0x13, 0x25], float)
SHADOW_A = 96 / 255.0


def git_file(sha, path, cache):
    os.makedirs(cache, exist_ok=True)
    p = os.path.join(cache, sha + "_" + path.replace("/", "_"))
    if not os.path.exists(p):
        open(p, "wb").write(subprocess.run(["git", "show", f"{sha}:{path}"], cwd=ROOT, capture_output=True, check=True).stdout)
    return p


def load_set(sha, cache):
    man = json.load(open(git_file(sha, "assets/manifest.json", cache), encoding="utf-8"))
    out = {}
    for page in ("biome_meadow", "bases"):
        png = np.array(Image.open(git_file(sha, f"assets/atlases/{page}.png", cache)).convert("RGBA"))
        meta = json.load(open(git_file(sha, f"assets/atlases/{page}.json", cache), encoding="utf-8"))
        out[page] = (png, meta)
    return man["biomes"]["meadow"], out


def frame(page, name):
    png, meta = page
    f = meta["frames"][name]
    return png[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]], f


def over(dst, src, x, y):
    """Alpha-composite src (RGBA uint8) onto dst (RGB float) at integer x, y with clipping."""
    H, W = dst.shape[:2]
    h, w = src.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x0 >= x1 or y0 >= y1:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x].astype(float)
    a = s[..., 3:4] / 255.0
    dst[y0:y1, x0:x1] = s[..., :3] * a + dst[y0:y1, x0:x1] * (1 - a)


def render_biome(biome, pages, cam_x, ground_y, view=(800, 360), front=False, oy=0):
    W, H = view
    img = np.zeros((H, W, 3), float)
    left = cam_x - W * 0.5 - 8.0
    w = W + 16.0
    drew = False
    for layer in biome["layers"]:
        if (str(layer.get("z", "")) == "front") != front:
            continue
        tex, f = frame(pages["biome_meadow"], layer["frame"])
        if not drew and not front and "clear_color" in layer:
            img[:] = [int(layer["clear_color"][i:i + 2], 16) for i in (1, 3, 5)]
        drew = True
        par = float(layer.get("parallax", 1.0))
        y = ground_y - float(layer["lane_line"]) if "lane_line" in layer else float(layer.get("view_y", ground_y - f["h"]))
        tw = f["w"]
        bx = np.floor(cam_x * (1.0 - par) + 0.5)
        x = np.floor((left - bx) / tw) * tw + bx
        while x < left + w:
            sx = int(round(x - cam_x + W * 0.5))          # world -> screen (camera centred, zoom 1)
            over(img, tex, sx, int(y) + oy)
            x += tw
    return img


def base_names(meta):
    return [n for n in meta["frames"] if n.startswith(("base_player", "base_enemy"))]


def find_bases(bg, old_pages, explained):
    """Bases = connected blobs the biome render does not explain. For each blob, test every old base frame aligned on
    the blob's bottom edge and on its left or right edge (+-2 px), exact pixel match on the template's opaque pixels."""
    from scipy import ndimage
    png, meta = old_pages["bases"]
    lab, n = ndimage.label(ndimage.binary_closing(~explained, iterations=2))
    hits = []
    for sl in ndimage.find_objects(lab):
        ys, xs = sl
        bh, bw = ys.stop - ys.start, xs.stop - xs.start
        if bh < 40 or bw < 30:
            continue
        best = None
        for nme in base_names(meta):
            t, f = frame(old_pages["bases"], nme)
            a = t[..., 3] > 0
            if a.sum() < 200:
                continue
            ty, tx = np.nonzero(a)
            tb, tl, tr = ty.max(), tx.min(), tx.max()
            for xa in (xs.start - tl, xs.stop - 1 - tr):
                for dx in (-2, -1, 0, 1, 2):
                    for dy in (-2, -1, 0, 1, 2):
                        x, y = xa + dx, ys.stop - 1 - tb + dy
                        y0, x0 = max(0, y), max(0, x)
                        y1, x1 = min(bg.shape[0], y + t.shape[0]), min(bg.shape[1], x + t.shape[1])
                        if y1 <= y0 or x1 <= x0:
                            continue
                        tt = t[y0 - y:y1 - y, x0 - x:x1 - x]
                        m = tt[..., 3] == 255
                        if m.sum() < 100:
                            continue
                        eq = float(np.all(bg[y0:y1, x0:x1][m] == tt[..., :3][m], axis=-1).mean())
                        if best is None or eq > best[0]:
                            best = (eq, x, y, nme, f.get("pivot"))
        if best and best[0] > 0.95:
            hits.append({"frame": best[3], "x": int(best[1]), "y": int(best[2]), "match": round(best[0], 3), "pivot": best[4]})
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sha", default="92a1718")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "ui06", "bg_92a1718"))
    ap.add_argument("--tags", default="ko,en")
    ap.add_argument("--scenes", default=",".join(SCENES))
    a = ap.parse_args()
    cache = os.path.join(ROOT, "build", "ui06", "gitcache")
    ob, op_ = load_set("ad47eda", cache)
    nb, np_ = load_set(a.sha, cache)
    os.makedirs(os.path.join(a.out, "layers"), exist_ok=True)
    rep_all = {"sha": a.sha, "note": "PROPOSAL MOCK input: ad47eda frames with the battlefield of " + a.sha, "scenes": {}}
    for loc in a.tags.split(","):
        r1 = json.load(open(os.path.join(E, f"{loc}_1x_art_report.json"), encoding="utf-8"))
        for k in ("1x", "2x"):
            shutil.copyfile(os.path.join(E, f"{loc}_{k}_art_report.json"), os.path.join(a.out, f"{loc}_{k}_art_report.json"))
        for scene in a.scenes.split(","):
            meta = r1["scenes"][scene]
            cam, gy = float(meta["camera_x"]), float(meta["ground_screen_y"])
            t1 = f"{loc}_1x_{scene}"
            full = np.array(Image.open(os.path.join(E, t1 + ".png")).convert("RGB")).astype(float)
            lay = {s: np.array(Image.open(os.path.join(L, f"{t1}_{s}.png")).convert("RGB")).astype(float) for s in ("h", "ht", "htf", "bg")}
            bg = lay["bg"]
            # 1. old render: back + front, compare with _bg outside HUD-free... (bg has no HUD, no units, no fx)
            ob_back = render_biome(ob, op_, cam, gy)
            ob_front = render_biome(ob, op_, cam, gy, front=True)
            fm = np.zeros(bg.shape[:2], bool)
            ft = render_biome(ob, {"biome_meadow": (op_["biome_meadow"][0][..., :], op_["biome_meadow"][1])}, cam, gy, front=True)
            # front mask: where the front layer is opaque (render front over black and over white, compare)
            black = np.zeros_like(bg); white = np.full_like(bg, 255.0)
            fb = black.copy(); fw = white.copy()
            for layer in ob["layers"]:
                if str(layer.get("z", "")) != "front":
                    continue
            old_comp = ob_back.copy()
            front_tex = [l for l in ob["layers"] if str(l.get("z", "")) == "front"]
            def front_alpha(biome, pages):
                acc = np.zeros(bg.shape[:2], float)
                for layer in biome["layers"]:
                    if str(layer.get("z", "")) != "front":
                        continue
                    tex, f = frame(pages["biome_meadow"], layer["frame"])
                    par = float(layer.get("parallax", 1.0))
                    y = gy - float(layer["lane_line"]) if "lane_line" in layer else float(layer.get("view_y", gy - f["h"]))
                    left = cam - 400 - 8.0
                    bx = np.floor(cam * (1.0 - par) + 0.5)
                    x = np.floor((left - bx) / f["w"]) * f["w"] + bx
                    while x < left + 816:
                        sx = int(round(x - cam + 400))
                        y0, x0 = max(0, int(y)), max(0, sx)
                        y1, x1 = min(360, int(y) + f["h"]), min(800, sx + f["w"])
                        if y1 > y0 and x1 > x0:
                            acc[y0:y1, x0:x1] = np.maximum(acc[y0:y1, x0:x1], tex[y0 - int(y):y1 - int(y), x0 - sx:x1 - sx, 3] / 255.0)
                        x += f["w"]
                return acc
            fa_old = front_alpha(ob, op_)
            old_comp = old_comp * (1 - fa_old[..., None]) + render_biome(ob, op_, cam, gy, front=True) * fa_old[..., None]
            explained = np.all(np.abs(old_comp - bg) <= 1, axis=-1)
            bases = find_bases(bg, op_, explained.copy())
            # 3. new composite
            nb_back = render_biome(nb, np_, cam, gy)
            new_bg = nb_back.copy()
            for b in bases:
                ot, of = frame(op_["bases"], b["frame"])
                name = b["frame"] if b["frame"] in np_["bases"][1]["frames"] else b["frame"].split("/")[0] + "/idle/0"
                nt, nf = frame(np_["bases"], name)
                opv, npv = of.get("pivot", [0, 0]), nf.get("pivot", [0, 0])
                over(new_bg, nt, b["x"] + opv[0] - npv[0], b["y"] + opv[1] - npv[1])
            fa_new = front_alpha(nb, np_)
            nfront = render_biome(nb, np_, cam, gy, front=True)
            new_bg_f = new_bg * (1 - fa_new[..., None]) + nfront * fa_new[..., None]
            # units: htf != bg; shadows = K blended at 96/255 over the old bg
            um = np.any(lay["htf"] != bg, axis=-1)
            exp_sh = np.round(bg * (1 - SHADOW_A) + K * SHADOW_A)
            sh = um & np.all(np.abs(lay["htf"] - exp_sh) <= 2, axis=-1)
            new_htf = new_bg.copy()
            new_htf[um] = lay["htf"][um]
            new_htf[sh] = np.round(new_bg[sh] * (1 - SHADOW_A) + K * SHADOW_A)
            new_htf = new_htf * (1 - fa_new[..., None]) + nfront * fa_new[..., None]
            # where the old front hid a unit we have no unit pixels: those stay new front / new bg
            new_ht = new_htf.copy(); m = np.any(lay["ht"] != lay["htf"], axis=-1); new_ht[m] = lay["ht"][m]
            new_h = new_ht.copy(); m = np.any(lay["h"] != lay["ht"], axis=-1); new_h[m] = lay["h"][m]
            new_full = new_h.copy(); m = np.any(full != lay["h"], axis=-1); new_full[m] = full[m]
            outs = {"": new_full, "_h": new_h, "_ht": new_ht, "_htf": new_htf, "_bg": new_bg_f}
            for kk, sc in (("1x", 1), ("2x", 2)):
                for suf, im in outs.items():
                    u8 = np.clip(np.round(im), 0, 255).astype(np.uint8)
                    if sc == 2:
                        u8 = np.repeat(np.repeat(u8, 2, axis=0), 2, axis=1)
                    p = os.path.join(a.out, f"{loc}_{kk}_{scene}.png") if suf == "" else os.path.join(a.out, "layers", f"{loc}_{kk}_{scene}{suf}.png")
                    Image.fromarray(u8).save(p)
            rep_all["scenes"][f"{loc}/{scene}"] = {"old_render_explains_bg_pct": round(100.0 * explained.mean(), 2),
                                                  "bases": bases, "unit_px": int(um.sum()), "shadow_px_reblended": int(sh.sum()),
                                                  "unexplained_after_bases_pct": None}
            print(loc, scene, "old biome render explains %.2f %% of _bg" % (100.0 * explained.mean()), "bases", [(b["frame"], b["match"]) for b in bases],
                  "units", int(um.sum()), "shadows", int(sh.sum()))
    json.dump(rep_all, open(os.path.join(a.out, "bg_swap_report.json"), "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
