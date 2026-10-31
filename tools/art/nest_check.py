"""Mold-nest edge readability (owner: 09-art-world since 2026-11-01; written by 03-art for art 0.12.0, 09 X9). Python composite only.
Cases: the nest on disk (art-world 1), the 0.12.0 nest from git rev ART_NEST_PREV (default HEAD) and the old bramble fort
(11ceacb), all on the CURRENT biome. ART_GIT_ROOT points git at a checkout when this runs inside a git-archive snapshot.

    python tools/art/nest_check.py [out_dir]

Composes the shipped biome_01 layers (biome.compose_preview, cam 0) and base_enemy idle frame 0
read from the written `bases` page, with ground_y 295 (readability.py), at the RIGHT edge of the
640x360 view so that only the left `vis` columns of the 96 px frame are on screen
(vis = 24, 40, 96). Same for the old bramble fort (page at commit 11ceacb, art 0.11.0) for comparison. Writes 1x and 2x
renders. Metrics, per case:
  dL_mean      |mean L* of visible nest pixels - mean L* of the 4 px background ring around them|
  sil_pct      % of the visible silhouette perimeter where outline or next pixel inward differs
               from the background by dL* >= 15 (readability.py rule)
  dE_bg        CIE dE76 nest mean vs background-ring mean in normal/protan/deutan/tritan
  faction      dE76 of the nest mean colour to the enemy faction mean and to the ally faction
               mean (walk/0 frames, outline excluded), per simulation; mould = closer to enemies
Lines fixed before measuring (03 internal, no player test): dL_mean >= 25, sil_pct >= 60,
min dE_bg >= 20, nest closer to the enemy mean than to the ally mean in all four simulations.
Not measured here: whether the nest is on screen at t = 10 s (camera, 02/04).
"""
from __future__ import annotations

import io
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

import biome  # noqa: E402
import theme  # noqa: E402
from cvd_check import MACHADO, lab, sim, pixels, ALLY, ENEMY  # noqa: E402
from readability import lab_L  # noqa: E402

GY = 295
OUTLINE = np.array([0x1b, 0x13, 0x25])


def page_frame(doc, page, name):
    f = doc["frames"][name]
    return page[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]], f["pivot"]


GIT_ROOT = os.environ.get("ART_GIT_ROOT", ROOT)


def load_bases(rev=None):
    if rev:
        j = json.loads(subprocess.run(["git", "show", f"{rev}:assets/atlases/bases.json"], cwd=GIT_ROOT,
                                      capture_output=True, check=True).stdout)
        p = np.array(Image.open(io.BytesIO(subprocess.run(["git", "show", f"{rev}:assets/atlases/bases.png"], cwd=GIT_ROOT,
                                                          capture_output=True, check=True).stdout)).convert("RGBA"))
    else:
        j = json.load(open(os.path.join(ROOT, "assets", "atlases", "bases.json"), encoding="utf-8"))
        p = np.array(Image.open(os.path.join(ROOT, "assets", "atlases", "bases.png")).convert("RGBA"))
    return j, p


def background():
    ls = biome.build_meadow()
    for name, cv, meta in ls:
        if name == "front":
            theme.remap_keys(cv, theme.WHEAT_FRONT)
    return np.array(biome.compose_preview(ls, 640, cam=0).convert("RGB")).astype(float)


def faction_means():
    m = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    docs, pages = {}, {}
    for a in m["atlases"]:
        docs[a["id"]] = json.load(open(os.path.join(ROOT, a["frames"].replace("res://", "")), encoding="utf-8"))
        pages[a["id"]] = np.array(Image.open(os.path.join(ROOT, a["image"].replace("res://", ""))).convert("RGBA"))
    al = np.concatenate([pixels(m, docs, pages, s) for s in ALLY])
    en = np.concatenate([pixels(m, docs, pages, s) for s in ENEMY])
    return al.mean(0), en.mean(0)


def case(bg, frame, pivot, vis):
    img = bg.copy()
    h, w = frame.shape[:2]
    x0 = 640 - vis
    y0 = GY - pivot[1]
    sub = frame[:, :vis]
    a = sub[..., 3] > 0
    region = img[y0:y0 + h, x0:640]
    region[a] = sub[..., :3][a]
    mask = np.zeros((360, 640), bool)
    mask[y0:y0 + h, x0:640] = a
    ring = np.zeros_like(mask)
    for d in range(1, 5):
        for ax in (0, 1):
            ring |= np.roll(mask, d, ax) | np.roll(mask, -d, ax)
    ring &= ~mask
    ring[:, 639] = False
    L, Lb = lab_L(img), lab_L(bg)
    px = img[mask]
    keep = ~np.all(px == OUTLINE, axis=1)
    nest_mean, ring_mean = px[keep].mean(0), bg[ring].mean(0)
    ok = tot = 0
    for (dy, dx) in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        nb = np.roll(mask, (-dy, -dx), axis=(0, 1))
        per = mask & ~nb
        ys, xs = np.nonzero(per)
        sel = (xs + dx >= 0) & (xs + dx < 640) & (ys + dy < 360)
        ys, xs = ys[sel], xs[sel]
        iy, ix = np.clip(ys - dy, 0, 359), np.clip(xs - dx, 0, 639)
        d1 = np.abs(L[ys, xs] - Lb[ys + dy, xs + dx])
        d2 = np.where(mask[iy, ix], np.abs(L[iy, ix] - Lb[ys + dy, xs + dx]), 0)
        ok += int((np.maximum(d1, d2) >= 15).sum())
        tot += len(ys)
    de = {}
    for mode in MACHADO:
        de[mode] = round(float(np.linalg.norm(lab(sim(nest_mean[None], mode))[0] - lab(sim(ring_mean[None], mode))[0])), 1)
    return img, nest_mean, {"vis_px": vis, "dL_mean": round(float(abs(L[mask][keep].mean() - Lb[ring].mean())), 1),
                            "sil_pct": round(ok / max(1, tot) * 100, 1), "dE_bg": de}


def main(out):
    os.makedirs(out, exist_ok=True)
    bg = background()
    ally, enemy = faction_means()
    rep = {"ground_y": GY, "lines": {"dL_mean": 25, "sil_pct": 60, "dE_bg_min": 20},
           "camera_note": "r01: enemy base x = lane 1100 - 40 = 1060, frame left edge 1012; a 640-px view shows it once "
                          "cam_x >= 692 (800-px wide view: cam_x >= 612). Camera follows the hero (02), so t = 10 s "
                          "visibility needs a camera change or an edge indicator (04), not art.", "cases": {}}
    renders = []
    for label, rev in (("nest_world1", None), ("nest_0.12.0", os.environ.get("ART_NEST_PREV", "HEAD")), ("fort_0.11.0", "11ceacb")):
        doc, page = load_bases(rev)
        fr, pv = page_frame(doc, page, "base_enemy")
        for vis in (24, 40, 96):
            img, mean, m = case(bg, fr, pv, vis)
            fac = {}
            for mode in MACHADO:
                s = lab(sim(np.stack([mean, enemy, ally]), mode))
                fac[mode] = {"to_enemy": round(float(np.linalg.norm(s[0] - s[1])), 1),
                             "to_ally": round(float(np.linalg.norm(s[0] - s[2])), 1)}
            m["faction"] = fac
            m["pass"] = {"dL": m["dL_mean"] >= 25, "sil": m["sil_pct"] >= 60, "dE_bg": min(m["dE_bg"].values()) >= 20,
                         "reads_as_mould": all(v["to_enemy"] < v["to_ally"] for v in fac.values())}
            rep["cases"][f"{label}/vis{vis}"] = m
            renders.append((label, vis, img))
    for label, vis, img in renders:
        im = Image.fromarray(np.rint(img).astype(np.uint8))
        crop = im.crop((400, 140, 640, 320))
        crop.save(os.path.join(out, f"{label}_vis{vis}_1x.png"))
        crop.resize((480, 360), Image.NEAREST).save(os.path.join(out, f"{label}_vis{vis}_2x.png"))
    with open(os.path.join(out, "nest_metrics.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1)
        f.write("\n")
    for k, v in rep["cases"].items():
        print(k, v["dL_mean"], v["sil_pct"], v["dE_bg"], v["pass"])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "art", "evidence", "nest_x9"))
