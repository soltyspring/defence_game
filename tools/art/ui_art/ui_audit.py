#!/usr/bin/env python3
"""06-art-ui: pixel measurements of the UI art (no Godot). Owner: 06-art-ui.

Usage: python tools/art/ui_art/ui_audit.py [--atlas assets/atlases/ui_main] [--hud <1280x720 2x HUD capture>]
       [--json out.json] [--criteria]
Measures, on the atlas frames that reach the screen (card_<unit>, skill icons) and on a real HUD capture:
  M1 card identity: per card, plate colour and plate shape mask; pairwise colour difference (CIEDE76 in Lab)
     in normal vision and in simulated protan/deutan (Machado 2009, severity 1.0); pairwise shape IoU;
     figure contrast against its own plate (WCAG ratio of mean relative luminance); figure coverage.
  M2 HUD band vs battlefield (capture): WCAG contrast and dL* of the card/HUD band against the ground strip.
  M3 skill icons: glyph-vs-plate WCAG contrast and glyph coverage.
--criteria prints PASS/FAIL against the numeric targets in docs/art/ui/UI_ART_CRITERIA.md.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CARDS = ["worker", "melee_basic", "ranged_basic", "tank", "fast", "siege", "hero_captain"]
DEPLOY = ["worker", "melee_basic", "ranged_basic", "tank", "fast", "siege"]   # the HUD row
SKILLS = ["skill_slam", "skill_rally", "skill_barrage"]
# Machado et al. 2009, severity 1.0 (linear RGB)
CVD = {"protan": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
       "deutan": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]])}
CRIT = {"plate_dE_min": 20.0, "plate_dE_cvd_min": 12.0, "shape_iou_max": 0.80, "figure_edge_contrast_min": 4.5,
        "plate_vs_card_body_min": 3.0, "skill_glyph_contrast_min": 4.5, "logo_face_share_ge3_min": 0.80}
MENU_SKY = (0x3d, 0x51, 0x7a)      # sky band behind the title logo, most common colour in the logo rows (en and ko)
# Card body behind the card icon, as it reaches the screen: 04's TouchButton default fill C_PANEL_LIGHT #6e4528
# at alpha .95, measured #694226 in docs/qa/readable_numbers/ko_640_notch_r05_3_hud.png (unit cards x=248/302/410).
CARD_BODY = (0x69, 0x42, 0x26)
WORKER_BODY = (0x49, 0x3f, 0x27)   # hud.gd btn_worker.fill (0.30,0.26,0.16,.95), measured on the same capture
OUTLINE = (0x1b, 0x13, 0x25)       # palette K


def lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def rel_lum(rgb):
    l = lin(rgb)
    return float(0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]) if l.ndim == 1 else 0.2126 * l[..., 0] + 0.7152 * l[..., 1] + 0.0722 * l[..., 2]


def wcag(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def lab(rgb):
    l = lin(rgb)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = m @ l / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def sim(rgb, kind):
    if kind == "normal":
        return np.asarray(rgb, float)
    l = np.clip(CVD[kind] @ lin(rgb), 0, 1)
    s = np.where(l <= 0.0031308, l * 12.92, 1.055 * l ** (1 / 2.4) - 0.055)
    return s * 255.0


def dE(a, b):
    return float(np.linalg.norm(lab(a) - lab(b)))


def frame(page, meta, name):
    f = meta["frames"][name]
    return page[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]]


def _erode(m):
    p = np.pad(m, 1, constant_values=False)
    return m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]


def plate_info(px):
    """Badge = opaque silhouette. Frame ring = its 2 outermost pixel rings (outline + rim/bevel), as in the old
    square frames (framed(): K border + highlight/rim). Core = silhouette eroded twice.
    Plate = the most common core colour, K (#1b1325, palette 'outline') excluded. Figure = core pixels that are
    not plate. Figure edge = figure pixels 4-adjacent to a plate pixel."""
    mask = px[..., 3] > 0
    core = _erode(_erode(mask))
    cols, counts = np.unique(px[core][:, :3].reshape(-1, 3), axis=0, return_counts=True)
    keep = ~np.all(cols == OUTLINE, axis=1)
    if keep.any():
        cols, counts = cols[keep], counts[keep]
    plate = tuple(int(v) for v in cols[counts.argmax()])
    is_plate = np.all(px[..., :3] == plate, axis=-1) & core
    fig = core & ~is_plate
    ip = np.pad(is_plate, 1, constant_values=False)
    touch = ip[:-2, 1:-1] | ip[2:, 1:-1] | ip[1:-1, :-2] | ip[1:-1, 2:]
    n_core = max(1, int(core.sum()))
    return {"plate": plate, "mask": mask, "figure_rgb": px[fig][:, :3], "edge_rgb": px[fig & touch][:, :3],
            "figure_cov": float(fig.sum()) / n_core, "plate_share": float(is_plate.sum()) / n_core}


def audit_frames(card_px: dict, skill_px: dict) -> dict:
    """card_px / skill_px: name -> RGBA uint8 array (h, w, 4). Used for the atlas and for previews."""
    cards = {}
    for u in CARDS:
        if u not in card_px:
            continue
        info = plate_info(card_px[u])
        fig = info["figure_rgb"]
        pl = rel_lum(info["plate"])
        # M1a (baseline metric): median luminance of all figure pixels vs plate (mixes outline and interior)
        fl = np.median(rel_lum(fig)) if len(fig) else pl
        fc = (max(fl, pl) + 0.05) / (min(fl, pl) + 0.05)
        # M1b (criterion): median WCAG of the figure-edge pixels against the plate
        ed = info["edge_rgb"]
        if len(ed):
            el = rel_lum(ed)
            ec = float(np.median((np.maximum(el, pl) + 0.05) / (np.minimum(el, pl) + 0.05)))
        else:
            ec = 1.0
        body = WORKER_BODY if u == "worker" else CARD_BODY
        cards[u] = {"plate": "#%02x%02x%02x" % info["plate"], "figure_contrast": round(float(fc), 2),
                    "figure_edge_contrast": round(ec, 2),
                    "figure_coverage": round(info["figure_cov"], 3), "plate_share": round(info["plate_share"], 3),
                    "plate_vs_card_body": round(wcag(info["plate"], body), 2), "_mask": info["mask"], "_plate": info["plate"]}
    pairs = []
    for i, a in enumerate(DEPLOY):
        for b in DEPLOY[i + 1:]:
            if a in cards and b in cards:
                ma, mb = cards[a]["_mask"], cards[b]["_mask"]
                iou = float((ma & mb).sum()) / float((ma | mb).sum())
                row = {"a": a, "b": b, "shape_iou": round(iou, 3)}
                for k in ("normal", "protan", "deutan"):
                    row["dE_" + k] = round(dE(sim(cards[a]["_plate"], k), sim(cards[b]["_plate"], k)), 1)
                pairs.append(row)
    skills = {}
    for s in SKILLS:
        if s not in skill_px:
            continue
        info = plate_info(skill_px[s])
        fig = info["figure_rgb"]
        fl = np.percentile(rel_lum(fig), 75) if len(fig) else rel_lum(info["plate"])
        pl = rel_lum(info["plate"])
        skills[s] = {"plate": "#%02x%02x%02x" % info["plate"], "glyph_contrast": round(float((max(fl, pl) + 0.05) / (min(fl, pl) + 0.05)), 2),
                     "glyph_coverage": round(info["figure_cov"], 3)}
    for v in cards.values():
        v.pop("_mask"); v.pop("_plate")
    return {"cards": cards, "card_pairs": pairs, "skills": skills}


def audit_atlas(base):
    page = np.array(Image.open(base + ".png").convert("RGBA"))
    meta = json.load(open(base + ".json", encoding="utf-8"))
    card_px = {u: frame(page, meta, "card_" + u) for u in CARDS if ("card_" + u) in meta["frames"]}
    skill_px = {}
    for s in SKILLS:
        n = "icon_" + s if ("icon_" + s) in meta["frames"] else s
        skill_px[s] = frame(page, meta, n)
    out = audit_frames(card_px, skill_px)
    out.update({"page_size": meta.get("size"), "gpu_bytes": meta.get("gpu_bytes")})
    return out


def audit_hud(path):
    im = np.array(Image.open(path).convert("RGB")).astype(float)
    h, w, _ = im.shape
    s = w / 640.0
    def mean(x0, y0, x1, y1):
        return im[int(y0 * s):int(y1 * s), int(x0 * s):int(x1 * s)].reshape(-1, 3).mean(axis=0)
    # logical 640x360 rects (2x capture of 04's HUD at 1280x720; measured on ko_640_notch_r05_3_hud.png)
    ground = mean(475, 281, 640, 298)          # dirt strip right of the units, above the HUD row
    cards = [mean(x, 300, x + 49, 356) for x in (194, 248, 302, 356, 410)]
    move = mean(39, 304, 90, 356)
    skills = [mean(503, 309, 549, 355), mean(554, 309, 600, 355)]
    out = {"ground": [round(v) for v in ground]}
    out["card_vs_ground_wcag"] = [round(wcag(c, ground), 2) for c in cards]
    out["card_vs_ground_dL"] = [round(float(lab(c)[0] - lab(ground)[0]), 1) for c in cards]
    out["move_vs_ground_wcag"] = round(wcag(move, ground), 2)
    out["skill_vs_ground_wcag"] = [round(wcag(c, ground), 2) for c in skills]
    cp = []
    for i in range(len(cards)):
        for j in range(i + 1, len(cards)):
            cp.append(round(dE(cards[i], cards[j]), 1))
    out["card_mean_colour_pairwise_dE"] = {"min": min(cp), "median": float(np.median(cp)), "max": max(cp)}
    return out


def audit_logo():
    """M4 title logo: share of glyph-face pixels (inside the glyph mask, i.e. no outline/drop shadow) with
    >= 3:1 against the menu sky behind the logo (#3d517a, measured on visual7-fca9346/*_2x_notch_1_menu.png),
    per scheme (crust line 1, mould line 2), from tools/art/branding.py as it is now."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
    import branding
    import pixel
    out = {}
    for name, scheme, text in (("crust_ko", branding.CRUST, branding.KO_A), ("mould_ko", branding.MOULD, branding.KO_B),
                               ("crust_en", branding.CRUST, "Bakery Knights"), ("mould_en", branding.MOULD, "Mold Defense")):
        mask = branding.glyph_mask(text, 2)
        cv = branding.paint(mask, scheme)
        h, w = mask.shape
        face = cv.a[3:3 + h, 3:3 + w][mask]
        rgb = pixel.RGBA[face][:, :3]
        lum = rel_lum(rgb)
        sl = rel_lum(MENU_SKY)
        cr = (np.maximum(lum, sl) + 0.05) / (np.minimum(lum, sl) + 0.05)
        out[name] = {"face_px": int(len(face)), "share_ge3": round(float((cr >= 3.0).mean()), 3),
                     "median_contrast": round(float(np.median(cr)), 2)}
    return out


def criteria_fails(at: dict, logo: dict | None = None) -> list:
    """at = audit_frames()/audit_atlas() result. Returns failure strings (empty = PASS)."""
    fails = []
    for p in at["card_pairs"]:
        if p["dE_normal"] < CRIT["plate_dE_min"]:
            fails.append("plate dE %s/%s %.1f" % (p["a"], p["b"], p["dE_normal"]))
        if min(p["dE_protan"], p["dE_deutan"]) < CRIT["plate_dE_cvd_min"]:
            fails.append("CVD plate dE %s/%s %.1f" % (p["a"], p["b"], min(p["dE_protan"], p["dE_deutan"])))
        if p["shape_iou"] > CRIT["shape_iou_max"]:
            fails.append("shape IoU %s/%s %.2f" % (p["a"], p["b"], p["shape_iou"]))
    for u, v in at["cards"].items():
        if v["figure_edge_contrast"] < CRIT["figure_edge_contrast_min"]:
            fails.append("figure edge contrast %s %.2f" % (u, v["figure_edge_contrast"]))
        if v["plate_vs_card_body"] < CRIT["plate_vs_card_body_min"]:
            fails.append("plate vs card body %s %.2f" % (u, v["plate_vs_card_body"]))
    for s_, v in at["skills"].items():
        if v["glyph_contrast"] < CRIT["skill_glyph_contrast_min"]:
            fails.append("skill glyph %s %.2f" % (s_, v["glyph_contrast"]))
    for k, v in (logo or {}).items():
        if v["share_ge3"] < CRIT["logo_face_share_ge3_min"]:
            fails.append("logo %s face share >=3:1 %.2f" % (k, v["share_ge3"]))
    return fails


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--atlas", default=os.path.join(ROOT, "assets", "atlases", "ui_main"))
    ap.add_argument("--hud", default="")
    ap.add_argument("--json", default="")
    ap.add_argument("--criteria", action="store_true")
    a = ap.parse_args()
    res = {"atlas": audit_atlas(a.atlas), "logo": audit_logo()}
    if a.hud:
        res["hud"] = audit_hud(a.hud)
    print(json.dumps(res, ensure_ascii=False, indent=1))
    fails = criteria_fails(res["atlas"], res["logo"]) if a.criteria else []
    if a.criteria:
        print("CRITERIA", "PASS" if not fails else "FAIL (%d)" % len(fails))
        for f in fails:
            print("  FAIL", f)
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
