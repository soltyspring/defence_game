"""09-art-world: measure world indicators on external store screenshots and on our own captures, same method.

python tools/art/world/ext_metrics.py <spec.json> [out.json]

The spec (docs/art/world/external_range.json) lists, per screenshot: game, store page URL, image URL, access date,
local file (never committed), image size and rectangles in image pixels:
  layers  {name: [x0, y0, x1, y1]}  sky / far / mid / behind (rows where unit bodies are) / lane (ground under feet)
  band    [x0, y0, x1, y1]          strip where units walk; foreground objects are found here
  bases   {name: [x0, y0, x1, y1]}  base / castle box; ring = 3 % of image width outside the box
Every image is first resized to 800 px wide (our capture width at 1x) so pixel thresholds mean the same thing.

Indicators
  L, Lsd, C, C35, edge   per layer: mean L*, L* std, mean C*ab, % px with C* >= 35, % 4-neighbour pairs with dE76 >= 15
                         (behind / lane: L/C values from background pixels only, units removed by the background model
                         below; edge always over the whole rectangle, so units add edges there)
  obj_dL_med / obj_dL_lt15   foreground objects in the band: |mean L* of the object (outline included) - mean L* of the
                         background pixels in its box grown by 3 px|, median and % below 15. This is the screenshot
                         stand-in for 07 C4/C4m (unit vs what is behind it); objects include props, not only units.
  base_dL / base_dE      |mean Lab of the base box - mean Lab of the ring|
Background model (band only): Lab binned (L 6, a 8, b 8); the most common bins up to 60 % of band pixels are background
colours; a pixel is background if it is within dE76 10 of one of them. Objects = 8-connected non-background areas of
40 px to 4 % of the band, at least 8 px tall.
For our own captures (entries with "layers_dir") the exact unit masks from 07's layer files are measured too
(c4_exact_*), so the stand-in can be checked against the real C4 on the same frame.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

W = 800


def lab(rgb):
    c = rgb.astype(np.float64) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def load(path, size=None):
    im = Image.open(os.path.expandvars(path)).convert("RGB")
    k = W / im.size[0]
    if im.size[0] != W:
        im = im.resize((W, max(1, round(im.size[1] * k))), Image.BOX)
    return np.asarray(im), k


def box(r, k, shape):
    x0, y0, x1, y1 = (int(round(v * k)) for v in r)
    return max(0, x0), max(0, y0), min(shape[1], x1), min(shape[0], y1)


def bg_model(L):
    q = np.stack([np.floor(L[..., 0] / 6), np.floor(L[..., 1] / 8), np.floor(L[..., 2] / 8)], -1).reshape(-1, 3).astype(int)
    keys, inv, cnt = np.unique(q, axis=0, return_inverse=True, return_counts=True)
    order = np.argsort(-cnt)
    acc, chosen = 0, []
    flat = L.reshape(-1, 3)
    inv = inv.reshape(-1)
    for i in order:
        chosen.append(flat[inv == i].mean(axis=0))
        acc += cnt[i]
        if acc >= 0.6 * len(flat):
            break
    cs = np.array(chosen)
    d = np.sqrt(((L[..., None, :] - cs[None, None]) ** 2).sum(-1)).min(-1)
    return d < 10.0


def edge_pct(L, mask=None):
    dx = np.sqrt(((L[:, 1:] - L[:, :-1]) ** 2).sum(-1)) >= 15
    dy = np.sqrt(((L[1:] - L[:-1]) ** 2).sum(-1)) >= 15
    if mask is not None:
        mx, my = mask[:, 1:] & mask[:, :-1], mask[1:] & mask[:-1]
        n = mx.sum() + my.sum()
        return round(100.0 * ((dx & mx).sum() + (dy & my).sum()) / n, 1) if n else None
    return round(100.0 * (dx.sum() + dy.sum()) / (dx.size + dy.size), 1)


def layer_stats(L, mask=None):
    px = L[mask] if mask is not None else L.reshape(-1, 3)
    if len(px) == 0:
        return None
    C = np.hypot(px[:, 1], px[:, 2])
    return {"L": round(float(px[:, 0].mean()), 1), "Lsd": round(float(px[:, 0].std()), 1), "C": round(float(C.mean()), 1),
            "C35": round(100.0 * float((C >= 35).mean()), 1), "edge": edge_pct(L),
            "px_pct": round(100.0 * len(px) / (L.shape[0] * L.shape[1]), 1)}


def objects(L, bg):
    fg = ~bg
    lab_, n = ndimage.label(fg, structure=np.ones((3, 3)))
    out = []
    amax = 0.04 * fg.size
    for i, sl in enumerate(ndimage.find_objects(lab_), 1):
        m = lab_[sl] == i
        a = int(m.sum())
        if a < 40 or a > amax or (sl[0].stop - sl[0].start) < 8:
            continue
        y0, y1 = max(0, sl[0].start - 3), min(L.shape[0], sl[0].stop + 3)
        x0, x1 = max(0, sl[1].start - 3), min(L.shape[1], sl[1].stop + 3)
        b = bg[y0:y1, x0:x1]
        if b.sum() < 10:
            continue
        lo = L[sl][m][:, 0].mean()
        lb = L[y0:y1, x0:x1][b][:, 0].mean()
        out.append({"box": [int(sl[1].start), int(sl[0].start), int(sl[1].stop), int(sl[0].stop)], "px": a,
                    "L": round(float(lo), 1), "Lbg": round(float(lb), 1), "dL": round(float(abs(lo - lb)), 1)})
    return out


def summarise(dls):
    if not dls:
        return None, None, 0
    return round(float(np.median(dls)), 1), round(100.0 * sum(1 for v in dls if v < 15) / len(dls), 1), len(dls)


def c4_exact(entry, k):
    d, tag, sc = entry["layers_dir"], entry.get("tag", "ko_1x"), entry["scene"]
    rep = json.load(open(os.path.join(os.path.dirname(d), f"{tag}_art_report.json"), encoding="utf-8"))
    meta = (rep.get("scenes") or rep)[sc]
    htf = np.asarray(Image.open(os.path.join(d, f"{tag}_{sc}_htf.png")).convert("RGB"))
    bgi = np.asarray(Image.open(os.path.join(d, f"{tag}_{sc}_bg.png")).convert("RGB"))
    unit = np.any(htf != bgi, axis=-1)
    lu, lb = lab(htf), lab(bgi)
    kk = htf.shape[1] / 800
    dls = []
    for u in meta["units"]:
        if not u["in_camera"] or u["dying"]:
            continue
        r = u["rect"]
        x0, y0 = int(np.floor((r[0] - 1) * kk)), int(np.floor((r[1] - 1) * kk))
        x1, y1 = int(np.ceil((r[0] + r[2] + 1) * kk)), int(np.ceil((r[1] + r[3] + 1) * kk))
        m = np.zeros(unit.shape, bool)
        m[max(0, y0):y1, max(0, x0):x1] = unit[max(0, y0):y1, max(0, x0):x1]
        if m.sum() < 4 * kk * kk:
            continue
        dls.append(float(abs(lu[m][:, 0].mean() - lb[m][:, 0].mean())))
    return summarise(dls)


def measure(e):
    rgb, k = load(e["file"])
    L = lab(rgb)
    res = {"id": e["id"], "layers": {}, "bases": {}}
    bx = box(e["band"], k, L.shape)
    band = L[bx[1]:bx[3], bx[0]:bx[2]]
    bg = bg_model(band)
    full_bg = np.ones(L.shape[:2], bool)
    full_bg[bx[1]:bx[3], bx[0]:bx[2]] = bg
    for name, r in e["layers"].items():
        x0, y0, x1, y1 = box(r, k, L.shape)
        sub = L[y0:y1, x0:x1]
        mask = full_bg[y0:y1, x0:x1] if name in ("behind", "lane") else None
        res["layers"][name] = layer_stats(sub, mask)
    obs = objects(band, bg)
    med, lt15, n = summarise([o["dL"] for o in obs])
    res.update({"obj_n": n, "obj_dL_med": med, "obj_dL_lt15": lt15, "objects": obs,
                "band_bg_pct": round(100.0 * float(bg.mean()), 1)})
    g = int(round(0.03 * W))
    for name, r in e.get("bases", {}).items():
        x0, y0, x1, y1 = box(r, k, L.shape)
        X0, Y0, X1, Y1 = max(0, x0 - g), max(0, y0 - g), min(L.shape[1], x1 + g), min(L.shape[0], y1 + g)
        ring = np.zeros(L.shape[:2], bool)
        ring[Y0:Y1, X0:X1] = True
        ring[y0:y1, x0:x1] = False
        a, b = L[y0:y1, x0:x1].reshape(-1, 3).mean(0), L[ring].mean(0)
        res["bases"][name] = {"dL": round(float(abs(a[0] - b[0])), 1), "dE": round(float(np.sqrt(((a - b) ** 2).sum())), 1)}
    if e.get("layers_dir"):
        med, lt15, n = c4_exact(e, k)
        res.update({"c4_exact_med": med, "c4_exact_lt15": lt15, "c4_exact_n": n})
    return res


def main():
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    out = [measure(e) for e in spec["shots"]]
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)
    for r in out:
        ly = r["layers"]
        cell = lambda n, k: ("-" if not ly.get(n) else ly[n][k])
        print(r["id"], "| L sky/far/mid/behind/lane", [cell(n, "L") for n in ("sky", "far", "mid", "behind", "lane")],
              "| C", [cell(n, "C") for n in ("sky", "far", "mid", "behind", "lane")],
              "| C35", [cell(n, "C35") for n in ("far", "mid", "behind", "lane")],
              "| edge", [cell(n, "edge") for n in ("far", "mid", "behind", "lane")],
              "| obj", r["obj_n"], r["obj_dL_med"], r["obj_dL_lt15"], "| bases", r["bases"],
              "| exact", r.get("c4_exact_med"), r.get("c4_exact_lt15"))


if __name__ == "__main__":
    main()
