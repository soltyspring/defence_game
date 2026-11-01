#!/usr/bin/env python3
"""06-art-ui: QA-B021 reopened (07 09:1x). Re-measure 07's U1 on 07's own e8c6d96 capture (all 5 unit cards dimmed in r08/r10)
and on candidates made by swapping only the 24x24 card icons in those real frames. Owner: 06-art-ui. No Godot.

The dimmed icon is 04 code: touch_button.gd draws the icon with modulate Color(1,1,1,0.45) when disabled (HEAD), over the
code-drawn C_DISABLED body. So per icon pixel: shown = 0.45*a*badge + (1-0.45*a)*under. With the committed badge known,
`under` is recovered exactly where a = 0 or 1 (badges are 1-bit alpha), then each candidate is composed over it.
Candidates (PROPOSAL MOCK on real frames, not screen evidence):
  K0 now: committed badge, alpha .45 (reproduces 07)      K1: alpha .70 (04's uncommitted WIP value)
  K2: grey off badge ui.card_off at alpha 1.0 (variant C)  K3: badge with every colour darkened to 0.6 x L* (keeps hue), alpha 1.0
Each with the tank T1 crop (ui.CARD_CROP_U3) off and on. Metric: tools/qa/art_metrics.scene_metrics (07's own U1 code).
S1 (same card affordable vs not): tank and siege between the real r06 frame (affordable) and r08 (dimmed).
Usage: python tools/art/ui_art/dim_probe.py [--cap build/qa07/art_compare/e8c6d96/cap] [--out docs/art/evidence/ui_art/dim_b021]
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
ROOT = os.path.abspath(os.path.join(ART, "..", ".."))
sys.path.insert(0, ART)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools", "qa"))
import art_metrics as AM  # noqa: E402
import card_preview as CP  # noqa: E402
import hud_mock as HM  # noqa: E402
import pixel  # noqa: E402
import ui  # noqa: E402

UIDS = ["melee_basic", "ranged_basic", "tank", "fast", "siege"]   # r06/r08/r10 card order (data/rounds)
SCENES = ["4_r06_t46", "5_r08_peak", "6_r10_boss"]


def rgba(cv):
    return pixel.RGBA[cv.a].astype(float)


def dark(cv, scale=0.6):
    """Every opaque colour -> the palette colour with the same hue family closest to scale x L* (K kept)."""
    out = ui.Canvas(cv.w, cv.h)
    pal = [(i, pixel.RGBA[i][:3].astype(float)) for i in range(1, len(pixel.RGBA)) if pixel.RGBA[i][3] == 255]
    labs = {i: HM.AM.lab(c[None, None].astype(np.uint8))[0, 0] for i, c in pal}
    for idx in np.unique(cv.a):
        if idx == 0:
            continue
        L = labs[int(idx)]
        if idx == ui.c("K"):
            out.a[cv.a == idx] = idx
            continue
        tgt = np.array([L[0] * scale, L[1] * 0.8, L[2] * 0.8])
        best = min(labs, key=lambda j: float(np.linalg.norm(labs[j] - tgt)))
        out.a[cv.a == idx] = best
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cap", default=os.path.join(ROOT, "build", "qa07", "art_compare", "e8c6d96", "cap"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "art", "evidence", "ui_art", "dim_b021"))
    ap.add_argument("--work", default=os.path.join(ROOT, "build", "ui06", "dim_b021"))
    ap.add_argument("--tag", default="ko_1x")
    a = ap.parse_args()
    rep = json.load(open(os.path.join(a.cap, f"{a.tag}_art_report.json"), encoding="utf-8"))
    fr = CP.idle_frames()
    committed = {u: rgba(ui.card(u, fr[u])) for u in UIDS}
    base_crop = dict(ui.CARD_CROP)
    ui.CARD_CROP.update(ui.CARD_CROP_U3)
    t1 = {u: (rgba(ui.card(u, fr[u])), rgba(ui.card_off(u, fr[u])), rgba(dark(ui.card(u, fr[u])))) for u in UIDS}
    ui.CARD_CROP.clear(); ui.CARD_CROP.update(base_crop)
    t0 = {u: (committed[u], rgba(ui.card_off(u, fr[u])), rgba(dark(ui.card(u, fr[u])))) for u in UIDS}
    cands = {"K0_alpha45": ("on", 0.45), "K1_alpha70": ("on", 0.70), "K2_grey_off_badge": ("off", 1.0), "K3_dark_badge": ("dark", 1.0)}
    res = {"note": "PROPOSAL MOCK on 07's real e8c6d96 frames (only the 24x24 card icons swapped); not screen evidence",
           "cap": os.path.relpath(a.cap, ROOT).replace("\\", "/"), "tag": a.tag, "U1": {}, "S1": {}, "recover_err_max": 0}
    frames = {s: np.array(Image.open(os.path.join(a.cap, f"{a.tag}_{s}.png")).convert("RGB")).astype(float) for s in SCENES}
    for crop_name, badges in (("T1_off", t0), ("T1_on", t1)):
        for cn, (kind, alpha) in cands.items():
            key = f"{cn}/{crop_name}"
            d = os.path.join(a.work, cn + "_" + crop_name)
            os.makedirs(os.path.join(d, "layers"), exist_ok=True)
            out_imgs = {}
            for s in SCENES:
                meta = rep["scenes"][s]
                img = frames[s].copy()
                for i, c in enumerate(meta["cards"]):
                    uid = UIDS[i]
                    x, y = int(c["icon"][0]), int(c["icon"][1])
                    reg = img[y:y + 24, x:x + 24]
                    b = committed[uid]
                    al = b[..., 3:4] / 255.0
                    shown_a = (0.45 if c["disabled"] else 1.0) * al
                    with np.errstate(divide="ignore", invalid="ignore"):
                        under = np.where(shown_a < 1.0, (reg - shown_a * b[..., :3]) / np.maximum(1e-6, 1 - shown_a), reg)
                    under = np.clip(under, 0, 255)
                    if not c["disabled"]:
                        nb, na = badges[uid][0], 1.0
                    elif kind == "on":
                        nb, na = badges[uid][0], alpha
                    elif kind == "off":
                        nb, na = badges[uid][1], 1.0
                    else:
                        nb, na = badges[uid][2], 1.0
                    aa = (nb[..., 3:4] / 255.0) * na
                    full_under = np.where(al > 0, under, reg)          # where the old badge was clear, reg is the body
                    img[y:y + 24, x:x + 24] = nb[..., :3] * aa + full_under * (1 - aa)
                    if crop_name == "T1_off" and cn == "K0_alpha45":
                        res["recover_err_max"] = max(res["recover_err_max"], float(np.abs(img[y:y + 24, x:x + 24] - reg).max()))
                u8 = np.clip(np.round(img), 0, 255).astype(np.uint8)
                Image.fromarray(u8).save(os.path.join(d, f"{a.tag}_{s}.png"))
                for suf in ("_h", "_ht", "_htf", "_bg"):
                    shutil.copyfile(os.path.join(a.cap, "layers", f"{a.tag}_{s}{suf}.png"), os.path.join(d, "layers", f"{a.tag}_{s}{suf}.png"))
                m = AM.scene_metrics(d, a.tag, s, meta, 1)
                res["U1"].setdefault(key, {})[s] = {q: m.get(q) for q in ("cards_disabled", "cards_min_dE_normal", "cards_min_dE_deutan",
                                                                        "cards_min_shape_dL", "cards_pairs_failing_u1", "cards_pairs_failing_u1_list")}
                out_imgs[s] = u8
            # S1 tank and siege: r06 (affordable) vs r08 (dimmed)
            for i, uid in ((2, "tank"), (4, "siege")):
                ce = rep["scenes"]["4_r06_t46"]["cards"][i]; cd = rep["scenes"]["5_r08_peak"]["cards"][i]
                re_ = {"x": ce["button"][0], "y": ce["button"][1], "w": ce["button"][2], "h": ce["button"][3], "ix": ce["icon"][0], "iy": ce["icon"][1]}
                rd_ = {"x": cd["button"][0], "y": cd["button"][1], "w": cd["button"][2], "h": cd["button"][3], "ix": cd["icon"][0], "iy": cd["icon"][1]}
                sm = HM.state_metrics(out_imgs["4_r06_t46"], {k: int(v) for k, v in re_.items()}, out_imgs["5_r08_peak"], {k: int(v) for k, v in rd_.items()}, 1)
                res["S1"].setdefault(key, {})[uid] = {"S1_min": min(sm[s_]["S1_card_dL"] for s_ in ("normal", "deutan", "protan")),
                                                      "signals": sm["pass"]["S2_signals"]}
            if crop_name == "T1_off":
                y0 = 296
                Image.fromarray(np.concatenate([frames["5_r08_peak"][y0:].astype(np.uint8), out_imgs["5_r08_peak"][y0:]], axis=0)).resize((1600, 256), Image.NEAREST) \
                    .save(os.path.join(a.work, f"row_{cn}.png"))
    os.makedirs(a.out, exist_ok=True)
    json.dump(res, open(os.path.join(a.out, "dim_probe.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for k, v in res["U1"].items():
        print(k, {s[:6]: (x["cards_pairs_failing_u1"], x["cards_min_dE_normal"], x["cards_min_dE_deutan"], x["cards_min_shape_dL"]) for s, x in v.items()},
              "S1", {u: x["S1_min"] for u, x in res["S1"][k].items()})
    print("recover_err_max", res["recover_err_max"])


if __name__ == "__main__":
    main()
