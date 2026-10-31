"""Metrics for lineup_cam.gd captures (owner: 03-art). Real-game frames, masks rebuilt from the atlas.

    python tools/art/lineup_metrics.py <out.json> "<label>=<capture_dir>|<char_player_dir>" [...]

For every unit in lineup_report.json (both poses): the frame alpha is cut from the atlas page that
was imported for that capture (every page found in <char_player_dir>, the rest from assets/atlases),
scaled x2 (window 1280x720 = 2 x 640x360) and placed where battle_view.gd draws it. Then, on the real
captures:
  silhouette_pct  % of perimeter pixels where the unit pixel (or the next one inward) differs from
                  the background pixel just outside by dL* >= 15 (background = the *_bg capture)
  dE_enemy_min    min CIE dE76 between the unit's mean colour (outline excluded) and each unit of the
                  other side (allies vs enemies, enemies vs allies), per simulation (normal / protan / deutan / tritan)
Units drawn as engine placeholders (their page is not resident in r01: e_brute) are skipped.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from cvd_check import MACHADO, lab, sim  # noqa: E402
from readability import lab_L  # noqa: E402

OUTLINE = np.array([0x1b, 0x13, 0x25])
SKIP = {"e_brute"}


def page_for(anim_set, man):
    return man["anim_sets"][anim_set]


def measure(cap_dir, cp_dir):
    man = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    rep = json.load(open(os.path.join(cap_dir, "lineup_report.json"), encoding="utf-8-sig"))
    pages = {}
    out = {}
    for pose, pd in rep["poses"].items():
        full = np.array(Image.open(os.path.join(cap_dir, f"lineup_{pose}_full.png")).convert("RGB")).astype(float)
        bg = np.array(Image.open(os.path.join(cap_dir, f"lineup_{pose}_bg.png")).convert("RGB")).astype(float)
        Lf, Lb = lab_L(full), lab_L(bg)
        s = full.shape[1] / rep["view_w"]
        left = pd["cam_x"] - rep["view_w"] / 2
        rows = []
        for u in pd["units"]:
            if u["anim_set"] in SKIP or "rect" not in u:
                continue
            pid = page_for(u["anim_set"], man)
            if pid not in pages:
                d = cp_dir if os.path.exists(os.path.join(cp_dir, f"{pid}.png")) else os.path.join(ROOT, "assets", "atlases")
                pages[pid] = np.array(Image.open(os.path.join(d, f"{pid}.png")).convert("RGBA"))
            x, y, w, h = (int(v) for v in u["rect"])
            a = pages[pid][y:y + h, x:x + w, 3] > 0
            px, py = round(u["x"]), round(rep["ground_y"] + u["lane_y"])
            pvx, pvy = u["pivot"]
            if u["flip"]:
                a = a[:, ::-1]
                x0 = px - (w - pvx)
            else:
                x0 = px - pvx
            y0 = py - pvy
            m = np.kron(a, np.ones((int(s), int(s)), bool))
            M = np.zeros(full.shape[:2], bool)
            sx, sy = int(round((x0 - left) * s)), int(round((y0 - pd["view_top"]) * s))
            M[sy:sy + m.shape[0], sx:sx + m.shape[1]] = m
            ok = tot = 0
            for (dy, dx) in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nb = np.roll(M, (-dy, -dx), axis=(0, 1))
                per = M & ~nb
                ys, xs = np.nonzero(per)
                iy, ix = ys - dy * int(s), xs - dx * int(s)
                inner = M[np.clip(iy, 0, M.shape[0] - 1), np.clip(ix, 0, M.shape[1] - 1)]
                d1 = np.abs(Lf[ys, xs] - Lb[ys + dy, xs + dx])
                d2 = np.where(inner, np.abs(Lf[np.clip(iy, 0, M.shape[0] - 1), np.clip(ix, 0, M.shape[1] - 1)] - Lb[ys + dy, xs + dx]), 0)
                ok += int((np.maximum(d1, d2) >= 15).sum())
                tot += len(ys)
            px_rgb = full[M]
            keep = ~np.all(np.abs(px_rgb - OUTLINE) < 1, axis=1)
            rows.append({"set": u["anim_set"], "side": u["side"], "x": u["x"], "silhouette_pct": round(ok / max(1, tot) * 100, 1),
                         "mean_rgb": px_rgb[keep].mean(0).tolist(), "px": int(M.sum())})
        enemies = [r for r in rows if r["side"] < 0]
        allies = [r for r in rows if r["side"] > 0]
        for r in rows:
            if r["side"] < 0 and allies:
                r["dE_enemy_min"] = {}
                for mode in MACHADO:
                    ua = lab(sim(np.array(r["mean_rgb"])[None], mode))[0]
                    r["dE_enemy_min"][mode] = round(min(float(np.linalg.norm(ua - lab(sim(np.array(e["mean_rgb"])[None], mode))[0]))
                                                        for e in allies), 1)   # for enemies: vs the allies
        for r in rows:
            if r["side"] > 0 and enemies:
                r["dE_enemy_min"] = {}
                for mode in MACHADO:
                    ua = lab(sim(np.array(r["mean_rgb"])[None], mode))[0]
                    r["dE_enemy_min"][mode] = round(min(float(np.linalg.norm(ua - lab(sim(np.array(e["mean_rgb"])[None], mode))[0]))
                                                        for e in enemies), 1)
        for r in rows:
            r.pop("mean_rgb")
        out[pose] = rows
    return out


def main(out, args):
    res = {}
    for a in args:
        label, rest = a.split("=", 1)
        cap, cp = rest.split("|", 1)
        res[label] = measure(cap, cp)
    summary = {}
    for label, poses in res.items():
        for pose, rows in poses.items():
            for r in rows:
                if "dE_enemy_min" in r:
                    k = f"{r['set']}@{int(r['x'])}"
                    summary.setdefault(k, {}).setdefault(pose, {})[label] = {
                        "sil": r["silhouette_pct"], "dE_protan": r["dE_enemy_min"]["protan"],
                        "dE_min_all": min(r["dE_enemy_min"].values()), "px": r["px"]}
    res["summary"] = summary
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1)
        f.write("\n")
    for k, v in summary.items():
        for pose, d in v.items():
            print(f"{k:22s} {pose:6s} " + "  ".join(f"{lab_}: sil {x['sil']:5.1f} dE {x['dE_min_all']:5.1f} px {x['px']}" for lab_, x in d.items()))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
