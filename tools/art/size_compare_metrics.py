"""Per-unit size and readability on size_cam.gd captures (owner: 03-art). Python only.

    python tools/art/size_compare_metrics.py <out.json> "<label>=<capture_dir>|<combo>|<char_player_dir>" ...

<capture_dir> holds zoom_preview_<combo>.png, size_cam_<combo>_bg.png and size_cam_<combo>_units.json from
tools/art/godot_check/size_cam.gd (04's r06 / seed 4242 / t = 46 s / 393 dp harness). <char_player_dir> holds the
char_player.png/json that were imported for that run; other pages come from assets/atlases.
Per drawn unit (dying units skipped):
  body_px      alpha bbox height of the drawn frame (art px)
  body_mm      body_px x zoom x 0.173 mm (04's conversion: one 800x360 view px on a 1080x2400, 393 dp phone at k = 3)
  visible_pct  share of the unit's pixels not covered by units drawn after it (lane_y order, like battle_view.gd);
               units under 10 % visible are counted as hidden and left out of the silhouette mean
  sil_pct      share of perimeter pixels whose colour (or the one a pixel inward) differs from the background capture
               just outside by dL* >= 15 (same rule as readability.py)
  dE_min       min CIE dE76 between the unit's mean colour (visible px, outline excluded) and each unit of the other
               side, minimum over normal / protan / deutan / tritan (Machado 2009)
This is a desktop capture of the phone layout, not a measurement on a phone.
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from cvd_check import MACHADO, lab, sim  # noqa: E402
from readability import lab_L  # noqa: E402

MM = 0.173
OUTLINE = np.array([0x1b, 0x13, 0x25])


def page(pid, cp_dir, cache):
    if pid not in cache:
        d = cp_dir if pid == "char_player" else os.path.join(ROOT, "assets", "atlases")
        cache[pid] = np.array(Image.open(os.path.join(d, f"{pid}.png")).convert("RGBA"))
    return cache[pid]


def measure(cap_dir, combo, cp_dir):
    J = json.load(open(os.path.join(cap_dir, f"size_cam_{combo}_units.json"), encoding="utf-8-sig"))
    full = np.array(Image.open(os.path.join(cap_dir, f"zoom_preview_{combo}.png")).convert("RGB")).astype(float)
    bg = np.array(Image.open(os.path.join(cap_dir, f"size_cam_{combo}_bg.png")).convert("RGB")).astype(float)
    H, W = full.shape[:2]
    s = J["image"][0] / J["view"][0]
    z = J["zoom"]
    f = z * s                                   # capture px per art px
    Lf, Lb = lab_L(full), lab_L(bg)
    cache = {}
    units = [u for u in J["units"] if not u["dying"]]
    # registration: one global (dx, dy) in capture px that best fits the unit masks to the pixels that differ
    # between the capture and the background capture (Godot's pixel snapping vs our rounding differs by <= 1-2 px)
    diff = np.abs(full - bg).sum(2) > 30
    best = (-1.0, 0, 0)
    for ddx in range(-3, 4):
        for ddy in range(-3, 4):
            hit = tot = 0
            for u in units:
                x, y, w, h = (int(round(v)) for v in u["rect"])
                al = page(u["page"], cp_dir, cache)[y:y + h, x:x + w, 3] > 0
                if u["flip"]:
                    al = al[:, ::-1]
                    ox = -(w - u["pivot"][0])
                else:
                    ox = -u["pivot"][0]
                X0 = (u["screen"][0] + ox * z) * s
                Y0 = (u["screen"][1] - u["pivot"][1] * z) * s
                jj, ii = np.nonzero(al)
                Xc = (X0 + (ii + 0.5) * f).astype(int) + ddx
                Yc = (Y0 + (jj + 0.5) * f).astype(int) + ddy
                ok = (Xc >= 0) & (Xc < W) & (Yc >= 0) & (Yc < H)
                hit += int(diff[Yc[ok], Xc[ok]].sum())
                tot += int(ok.sum())
            r = hit / max(1, tot)
            if r > best[0]:
                best = (r, ddx, ddy)
    reg = {"dx": best[1], "dy": best[2], "coverage": round(best[0], 3)}
    order = sorted(range(len(units)), key=lambda i: units[i]["lane_y"])
    masks = []
    for u in units:
        x, y, w, h = (int(round(v)) for v in u["rect"])
        a = page(u["page"], cp_dir, cache)[y:y + h, x:x + w]
        al = a[..., 3] > 0
        if u["flip"]:
            al = al[:, ::-1]
            ox = -(w - u["pivot"][0])
        else:
            ox = -u["pivot"][0]
        oy = -u["pivot"][1]
        X0 = (u["screen"][0] + ox * z) * s + reg["dx"]
        Y0 = (u["screen"][1] + oy * z) * s + reg["dy"]
        M = np.zeros((H, W), bool)
        xs0, ys0 = int(math.floor(X0)), int(math.floor(Y0))
        xs1, ys1 = int(math.ceil(X0 + w * f)), int(math.ceil(Y0 + h * f))
        for Y in range(max(0, ys0), min(H, ys1)):
            j = int((Y + 0.5 - Y0) // f)
            if not 0 <= j < h:
                continue
            for X in range(max(0, xs0), min(W, xs1)):
                i = int((X + 0.5 - X0) // f)
                if 0 <= i < w and al[j, i]:
                    M[Y, X] = True
        ys = np.nonzero(al.any(1))[0]
        masks.append((M, int(ys.max() - ys.min() + 1) if len(ys) else 0))
    owner = np.full((H, W), -1, int)
    for i in order:
        owner[masks[i][0]] = i
    rows = []
    step = max(1, int(round(f)))
    for i, u in enumerate(units):
        M, bpx = masks[i]
        n = int(M.sum())
        if n == 0:
            continue
        vis = (owner == i) & M
        ok = tot = 0
        for (dy, dx) in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(M, (-dy, -dx), axis=(0, 1))
            per = vis & ~nb
            yy, xx = np.nonzero(per)
            sel = (yy + dy >= 0) & (yy + dy < H) & (xx + dx >= 0) & (xx + dx < W)
            yy, xx = yy[sel], xx[sel]
            iy, ix = np.clip(yy - dy * step, 0, H - 1), np.clip(xx - dx * step, 0, W - 1)
            d1 = np.abs(Lf[yy, xx] - Lb[yy + dy, xx + dx])
            d2 = np.where(M[iy, ix], np.abs(Lf[iy, ix] - Lb[yy + dy, xx + dx]), 0)
            ok += int((np.maximum(d1, d2) >= 15).sum())
            tot += len(yy)
        px = full[vis]
        keep = ~np.all(np.abs(px - OUTLINE) < 1, axis=1)
        mean = px[keep].mean(0) if keep.any() else None
        rows.append({"set": u["set"], "side": u["side"], "hero": u["hero"], "body_px": bpx, "body_mm": round(bpx * z * MM, 2),
                     "visible_pct": round(float(vis.sum()) / n * 100, 1), "sil_pct": round(ok / max(1, tot) * 100, 1),
                     "mean": None if mean is None else mean.tolist()})
    for r in rows:
        others = [o for o in rows if o["side"] != r["side"] and o["mean"] is not None]
        if r["mean"] is None or not others:
            r["dE_min"] = None
            continue
        best = 1e9
        for mode in MACHADO:
            a = lab(sim(np.array(r["mean"])[None], mode))[0]
            for o in others:
                best = min(best, float(np.linalg.norm(a - lab(sim(np.array(o["mean"])[None], mode))[0])))
        r["dE_min"] = round(best, 1)
    for r in rows:
        r.pop("mean")
    return {"zoom": z, "t": J["t"], "registration": reg, "units": rows}


def main(out, items):
    rep = {"mm_per_view_px": MM, "runs": {}}
    for it in items:
        label, rest = it.split("=", 1)
        cap, combo, cp = rest.split("|")
        rep["runs"][label] = measure(cap, combo, cp)
    summ = {}
    for label, r in rep["runs"].items():
        agg = {}
        for u in r["units"]:
            agg.setdefault(u["set"], []).append(u)
        for sid, us in agg.items():
            d = summ.setdefault(sid, {})
            d[label] = {"n": len(us), "body_mm": us[0]["body_mm"], "body_px": us[0]["body_px"],
                        "visible_pct": round(float(np.mean([u["visible_pct"] for u in us])), 1),
                        "sil_pct": round(float(np.mean([u["sil_pct"] for u in us if u["visible_pct"] >= 10] or [0])), 1),
                        "hidden_n": sum(1 for u in us if u["visible_pct"] < 10),
                        "dE_min": min((u["dE_min"] for u in us if u["dE_min"] is not None), default=None)}
    rep["summary"] = summ
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(rep, fh, indent=1)
        fh.write("\n")
    for sid, d in summ.items():
        print(f"{sid:13s} " + " | ".join(f"{lab_}: n{x['n']} {x['body_mm']:4.2f}mm vis {x['visible_pct']:5.1f} sil {x['sil_pct']:5.1f} dE {x['dE_min']}"
                                        for lab_, x in d.items()))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
