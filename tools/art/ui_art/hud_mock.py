#!/usr/bin/env python3
"""06-art-ui: PROPOSAL MOCK (판단용 합성, 실제 화면 아님) of the ui-art 1.1 HUD chrome on 07's baseline frames.
Owner: 06-art-ui. No Godot. Not screen evidence: the real screen needs 04 to wire the frames (NinePatchRect).

Input: 07's fixed set docs/verification/evidence/art-baseline-ad47eda (frames + *_art_report.json) and its local layer
frames build/qa07/art-baseline-ad47eda/run1/layers (git-ignored; regenerate with ART_BASELINE.md §4 if missing).
Per battle scene, at 1x: start from the HUD-hidden layer (_h), put back every baseline HUD pixel that the proposal does
not replace, then draw the proposal in the SAME rects 04 uses now (layout unchanged):
  card group tray (hud_tray, fills only the gaps), unit cards (card_frame / card_frame_disabled + R1 badge, disabled
  badge at 45 % like touch_button.gd), skill buttons (btn_skill + current skill icon), move buttons (btn + current
  move icon), pause (btn_round 44). Text pixels (names, costs) are copied from the baseline. The worker button keeps
  04's octagon (07 QA-J3) and only gets the new badge. 2x = the 1x proposal pixels doubled into the 2x frame.
Measured with 07's own tools/qa/art_metrics.scene_metrics (U1 cards, U2 hud_px_pct, U3 hud_on_units_pct) plus:
  HUD-vs-ground: per bottom-row element, WCAG of the mean of its outer 2-px ring against the dirt in a 3-px band
  outside it (other HUD excluded); G3: 1x pixels whose 2x 2x2 block differs from the 1x pixel.
Variant "all_dimmed": every unit card drawn unaffordable (U1 must still hold, ART_BASELINE U1).
Usage: python tools/art/ui_art/hud_mock.py [--out docs/art/evidence/ui_art] [--work build/ui06/mock]
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
ROOT = os.path.abspath(os.path.join(ART, "..", ".."))
sys.path.insert(0, ART)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools", "qa"))

import art_metrics as AM  # noqa: E402  (07's tool, read-only use)
import card_preview as CP  # noqa: E402
import chrome_preview as CH  # noqa: E402
import pixel  # noqa: E402
import ui  # noqa: E402
import ui_audit as A  # noqa: E402

E = os.path.join(ROOT, "docs", "verification", "evidence", "art-baseline-ad47eda")
L = os.path.join(ROOT, "build", "qa07", "art-baseline-ad47eda", "run1", "layers")
SCENES = ["2_r01_t10", "3_r01_t30", "4_r06_t46", "5_r08_peak", "6_r10_boss"]
BASE_SHA = "ad47eda"
INK = None   # --ink: draw the chrome frames' K pixels in another colour (decision variant, e.g. 04's #07070c)


def ink(px):
    if INK is None:
        return px
    px = px.copy()
    k = np.all(px[..., :3] == (0x1b, 0x13, 0x25), axis=-1) & (px[..., 3] > 0)
    px[k, :3] = INK
    return px


def img(p):
    return np.array(Image.open(p).convert("RGB"))


def rgba(cv):
    return pixel.RGBA[cv.a].astype(np.uint8)


def put(dst, src, x, y, alpha=1.0):
    h, w = src.shape[:2]
    reg = dst[y:y + h, x:x + w].astype(float)
    a = (src[..., 3:4] / 255.0) * alpha
    dst[y:y + h, x:x + w] = np.round(src[..., :3] * a + reg * (1 - a)).astype(np.uint8)


def old_atlas():
    d = os.path.join(os.environ.get("TEMP", "/tmp"), "ui06_ad47eda")
    os.makedirs(d, exist_ok=True)
    for ext in ("png", "json"):
        p = os.path.join(d, "ui_main." + ext)
        if not os.path.exists(p):
            data = subprocess.run(["git", "show", f"{BASE_SHA}:assets/atlases/ui_main.{ext}"], cwd=ROOT,
                                  capture_output=True, check=True).stdout
            open(p, "wb").write(data)
    page = np.array(Image.open(os.path.join(d, "ui_main.png")).convert("RGBA"))
    meta = json.load(open(os.path.join(d, "ui_main.json"), encoding="utf-8"))
    return lambda n: A.frame(page, meta, n)


def find(region, tmpl, body):
    """Best position of an RGBA template inside an RGB region, drawn over the body colour at alpha 1 or .45
    (touch_button.gd dims icons of disabled buttons to .45). Error = mean abs RGB difference on opaque pixels."""
    th, tw = tmpl.shape[:2]
    best = None
    a = tmpl[..., 3:4] / 255.0
    op = tmpl[..., 3] > 0
    for dim in (1.0, 0.45):
        exp = tmpl[..., :3] * a * dim + body.astype(float) * (1 - a * dim)
        for y in range(region.shape[0] - th + 1):
            for x in range(region.shape[1] - tw + 1):
                reg = region[y:y + th, x:x + tw].astype(float)
                err = float(np.abs(exp - reg)[op].mean())
                if best is None or err < best[0]:
                    best = (err, x, y, dim)
    return best


def body_colour(region):
    cols, cnt = np.unique(region.reshape(-1, 3), axis=0, return_counts=True)
    return cols[cnt.argmax()]


def copy_text(dst, src, x0, y0, w, h, bc, exclude=None, inset=3):
    """Copy baseline pixels that are not the old body colour (text, digits, their outline) inside the inset rect."""
    sub = src[y0 + inset:y0 + h - inset, x0 + inset:x0 + w - inset]
    m = np.any(np.abs(sub.astype(int) - bc.astype(int)) > 10, axis=-1)
    if exclude is not None:
        ex, ey, ew, eh = exclude
        m[max(0, ey - y0 - inset):max(0, ey - y0 - inset + eh), max(0, ex - x0 - inset):max(0, ex - x0 - inset + ew)] = False
    d = dst[y0 + inset:y0 + h - inset, x0 + inset:x0 + w - inset]
    d[m] = sub[m]


def components(full, h):
    m = np.any(full != h, axis=-1)
    lab, _ = ndimage.label(ndimage.binary_closing(m, iterations=1))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        ys, xs = sl
        out.append((xs.start, ys.start, xs.stop - xs.start, ys.stop - ys.start))
    return m, out


def build_scene(full, h, meta, rnd_cards, old, new, all_dimmed=False, dim_alpha=0.45):
    """Return (mock RGB 1x, list of replaced rects, element rects for the ground check)."""
    hudm, comps = components(full, h)
    cards = {int(c["button"][0]): c for c in meta.get("cards", [])}
    els = []
    for (x, y, w, hh) in comps:
        if y >= 290 and abs(w - 50) <= 1 and abs(hh - 56) <= 1:
            els.append(("card" if x in cards else "worker", x, y, w, hh))
        elif y >= 290 and abs(w - 52) <= 1 and abs(hh - 52) <= 1:
            els.append(("move", x, y, w, hh))
        elif y >= 290 and abs(w - 48) <= 1 and abs(hh - 48) <= 1:
            els.append(("skill", x, y, w, hh))
        elif y < 60 and abs(w - 44) <= 1 and abs(hh - 44) <= 1 and x > 600:
            els.append(("pause", x, y, w, hh))
    mock = h.copy()
    replaced = np.zeros(hudm.shape, bool)
    for (k, x, y, w, hh) in els:
        if k != "worker":
            replaced[y:y + hh, x:x + w] = True
    group = [e for e in els if e[0] in ("card", "worker")]
    if len(group) >= 2:
        gx0 = min(e[1] for e in group); gx1 = max(e[1] + e[3] for e in group)
        gy0 = min(e[2] for e in group); gy1 = max(e[2] + e[4] for e in group)
        tray = (gx0, gy0, gx1 - gx0, gy1 - gy0)
    else:
        tray = None
    mock[hudm & ~replaced] = full[hudm & ~replaced]
    if tray:
        tx, ty, tw, th = tray
        tcv, tm = new["hud_tray"]
        tr = ink(CH.nine_draw(rgba(tcv), tm, tw, th))
        keep = mock[ty:ty + th, tx:tx + tw].copy()
        put(mock, tr, tx, ty)
        # the worker keeps 04's pixels: re-put them over the tray
        for e in group:
            if e[0] == "worker":
                _, x, y, w, hh = e
                wm = hudm[y:y + hh, x:x + w]
                sub = mock[y:y + hh, x:x + w]
                sub[wm] = full[y:y + hh, x:x + w][wm]
        del keep
    order = sorted([e for e in els if e[0] == "card"], key=lambda e: e[1])
    for (k, x, y, w, hh) in els:
        reg = full[y:y + hh, x:x + w]
        bc = body_colour(reg)
        if k == "card":
            c = cards[x]
            uid = rnd_cards[order.index((k, x, y, w, hh))]
            dis = all_dimmed or bool(c["disabled"])
            cv, m = new["card_frame_disabled" if dis else "card_frame"]
            put(mock, ink(CH.nine_draw(rgba(cv), m, w, hh)), x, y)
            ix, iy = int(c["icon"][0]), int(c["icon"][1])
            copy_text(mock, full, x, y, w, hh, bc, exclude=(ix, iy, 24, 24))
            put(mock, new["card_" + uid], ix, iy, (dim_alpha if all_dimmed else 0.45) if dis else 1.0)
        elif k == "worker":
            hit = find(reg, old("card_worker"), bc)
            if hit and hit[0] < 8:
                _, fx, fy, dim = hit
                ow = old("card_worker")
                cut = ow[..., 3] > 0
                mock[y + fy:y + fy + 24, x + fx:x + fx + 24][cut] = bc
                put(mock, new["card_worker"], x + fx, y + fy, dim)
        elif k == "skill":
            best = None
            for sid in ("skill_slam", "skill_rally", "skill_barrage"):
                r = find(reg, old("icon_" + sid), bc)
                if best is None or r[0] < best[0]:
                    best = r + (sid,)
            cv, m = new["btn_skill"]
            put(mock, ink(CH.nine_draw(rgba(cv), m, w, hh)), x, y)
            _, fx, fy, dim, sid = best
            copy_text(mock, full, x, y, w, hh, bc, exclude=(x + fx, y + fy, 24, 24))
            put(mock, new["icon_" + sid], x + fx, y + fy, dim)
        elif k == "move":
            best = None
            for n in ("btn_move_left", "btn_move_right"):
                r = find(reg, old(n), bc)
                if best is None or r[0] < best[0]:
                    best = r + (n,)
            cv, m = new["btn"]
            put(mock, ink(CH.nine_draw(rgba(cv), m, w, hh)), x, y)
            _, fx, fy, dim, n = best
            put(mock, new[n], x + fx, y + fy, dim)
        elif k == "pause":
            put(mock, ink(rgba(ui.btn_round(44))), x, y)
            copy_text(mock, full, x, y, w, hh, bc, inset=8)
    rects = [(x, y, w, hh) for (_, x, y, w, hh) in els]
    if tray:
        rects.append(tray)
    return mock, rects, [e for e in els if e[2] >= 290], tray


def ground_check(frame, h, hudm, els):
    out = []
    H, W = hudm.shape
    for (k, x, y, w, hh) in els:
        e = np.zeros(hudm.shape, bool); e[y:y + hh, x:x + w] = True
        ring = e & ~ndimage.binary_erosion(e, iterations=2) & hudm
        outer = ndimage.binary_dilation(e, iterations=3) & ~e & ~hudm
        if ring.sum() < 4 or outer.sum() < 4:
            continue
        out.append({"el": k, "x": x, "wcag": round(A.wcag(frame[ring].mean(axis=0), h[outer].mean(axis=0)), 2)})
    return out


def g3(one, two):
    up = np.repeat(np.repeat(one, 2, axis=0), 2, axis=1)
    bad = np.any(up != two, axis=-1).reshape(one.shape[0], 2, one.shape[1], 2).any(axis=(1, 3))
    return int(bad.sum())


def verdict(res):
    """Per rule, over every locale x variant x scene x scale: worst value and PASS/FAIL (rules from the 06 task + 07 §3)."""
    worst = {"ground_min_wcag": 99.0, "u1_failing_pairs": 0, "u2_max_pp_increase": -99.0, "u3_max_pct": 0.0, "g3_max_px": 0}
    where = {}
    for loc, t in res["tags"].items():
        for v, vv in t.items():
            for s, row in vv.items():
                for k in ("1x", "2x"):
                    r = row[k]
                    g = [x["wcag"] for x in r["ground_after"]]
                    if g and min(g) < worst["ground_min_wcag"]:
                        worst["ground_min_wcag"] = min(g); where["ground_min_wcag"] = f"{loc}/{v}/{s}/{k}"
                    f = r["after"].get("cards_pairs_failing_u1") or 0
                    if f > worst["u1_failing_pairs"]:
                        worst["u1_failing_pairs"] = f; where["u1_failing_pairs"] = f"{loc}/{v}/{s}/{k}"
                    d = round(r["after"]["hud_px_pct"] - r["hud_px_pct_before"], 2)
                    if d > worst["u2_max_pp_increase"]:
                        worst["u2_max_pp_increase"] = d; where["u2_max_pp_increase"] = f"{loc}/{v}/{s}/{k}"
                    u3 = r["after"].get("hud_on_units_pct") or 0.0
                    if u3 > worst["u3_max_pct"]:
                        worst["u3_max_pct"] = u3; where["u3_max_pct"] = f"{loc}/{v}/{s}/{k}"
                gb, ga = row["g3_1x_px_differing"]["before"], row["g3_1x_px_differing"]["after"]
                if ga > gb and ga - gb > worst["g3_max_px"]:
                    worst["g3_max_px"] = ga - gb; where["g3_max_px"] = f"{loc}/{v}/{s} (+{ga - gb} over baseline)"
    ok = {"ground_min_wcag": bool(worst["ground_min_wcag"] >= 3.0), "u1_failing_pairs": bool(worst["u1_failing_pairs"] == 0),
          "u2_max_pp_increase": bool(worst["u2_max_pp_increase"] <= 0.5), "u3_max_pct": bool(worst["u3_max_pct"] == 0.0),
          "g3_max_px": bool(worst["g3_max_px"] == 0)}
    worst = {k: (float(v) if isinstance(v, (float, np.floating)) else int(v)) for k, v in worst.items()}
    return {"worst": worst, "where": where, "pass": ok, "all_pass": bool(all(ok.values()))}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "art", "evidence", "ui_art"))
    ap.add_argument("--work", default=os.path.join(ROOT, "build", "ui06", "mock"))
    ap.add_argument("--tags", default="ko,en")
    ap.add_argument("--dim-alpha", type=float, default=0.45, help="badge alpha in the all_dimmed variant (04 draws .45 now)")
    ap.add_argument("--ink", default="", help="hex: draw chrome-frame K pixels in this colour (decision variant only)")
    a = ap.parse_args()
    global INK
    INK = tuple(int(a.ink[i:i + 2], 16) for i in (0, 2, 4)) if a.ink else None
    old = old_atlas()
    fr = CP.idle_frames()
    new = {k: v for k, v in ui.frames9().items()}
    new.update(ui.chrome_proposed())
    new.update({"card_" + u: rgba(ui.card(u, fr[u])) for u in A.CARDS})
    new.update({"icon_skill_slam": rgba(ui.skill_slam()), "icon_skill_rally": rgba(ui.skill_rally()),
                "icon_skill_barrage": rgba(ui.skill_barrage()),
                "btn_move_right": rgba(ui.move_button(1)), "btn_move_left": rgba(ui.move_button(-1))})
    res = {"note": "PROPOSAL MOCK on 07 baseline ad47eda frames; not screen evidence", "all_dimmed_alpha": a.dim_alpha, "tags": {}}
    for loc in a.tags.split(","):
        rep1 = json.load(open(os.path.join(E, f"{loc}_1x_art_report.json"), encoding="utf-8"))
        rep2 = json.load(open(os.path.join(E, f"{loc}_2x_art_report.json"), encoding="utf-8"))
        for variant in ("as_captured", "all_dimmed"):
            vdir = os.path.join(a.work, variant)
            os.makedirs(os.path.join(vdir, "layers"), exist_ok=True)
            for scene in SCENES:
                meta = rep1["scenes"][scene]
                rnd = json.load(open(os.path.join(ROOT, "data", "rounds", meta["round"] + ".json"), encoding="utf-8"))["cards"]
                f1 = img(os.path.join(E, f"{loc}_1x_{scene}.png"))
                h1 = img(os.path.join(L, f"{loc}_1x_{scene}_h.png"))
                f2 = img(os.path.join(E, f"{loc}_2x_{scene}.png"))
                mock1, rects, els, tray = build_scene(f1, h1, meta, rnd, old, new, variant == "all_dimmed", a.dim_alpha)
                mock2 = f2.copy()
                for (x, y, w, hh) in rects:
                    blk = np.repeat(np.repeat(mock1[y:y + hh, x:x + w], 2, axis=0), 2, axis=1)
                    mock2[2 * y:2 * (y + hh), 2 * x:2 * (x + w)] = blk
                row = res["tags"].setdefault(f"{loc}", {}).setdefault(variant, {}).setdefault(scene, {})
                for k, frame, mk in (("1x", f1, mock1), ("2x", f2, mock2)):
                    tag = f"{loc}_{k}"
                    Image.fromarray(mk).save(os.path.join(vdir, f"{tag}_{scene}.png"))
                    for s in ("_h", "_ht", "_htf", "_bg"):
                        shutil.copyfile(os.path.join(L, f"{tag}_{scene}{s}.png"), os.path.join(vdir, "layers", f"{tag}_{scene}{s}.png"))
                    kk = 1 if k == "1x" else 2
                    rep = rep1 if k == "1x" else rep2
                    bdir = os.path.join(a.work, "baseline")
                    os.makedirs(os.path.join(bdir, "layers"), exist_ok=True)
                    shutil.copyfile(os.path.join(E, f"{tag}_{scene}.png"), os.path.join(bdir, f"{tag}_{scene}.png"))
                    for s in ("_h", "_ht", "_htf", "_bg"):
                        shutil.copyfile(os.path.join(L, f"{tag}_{scene}{s}.png"), os.path.join(bdir, "layers", f"{tag}_{scene}{s}.png"))
                    before = AM.scene_metrics(bdir, tag, scene, rep["scenes"][scene], kk)
                    after = AM.scene_metrics(vdir, tag, scene, rep["scenes"][scene], kk)
                    hk = img(os.path.join(L, f"{tag}_{scene}_h.png"))
                    hb = np.any(frame != hk, axis=-1)
                    ha = np.any(mk != hk, axis=-1)
                    sc = 1 if k == "1x" else 2
                    els_k = [(e[0], e[1] * sc, e[2] * sc, e[3] * sc, e[4] * sc) for e in els]
                    keys = ("hud_px_pct", "hud_on_units_pct", "cards_on_screen", "cards_min_dE_normal", "cards_min_dE_deutan",
                            "cards_min_shape_dL", "cards_pairs_failing_u1", "cards_pairs_failing_u1_list")
                    row[k] = {"after": {q: after.get(q) for q in keys},
                              "hud_px_pct_before": round(100.0 * hb.sum() / hb.size, 2),
                              "ground_before": ground_check(frame, hk, hb, els_k),
                              "ground_after": ground_check(mk, hk, ha, els_k)}
                    if before:
                        row[k]["before"] = {q: before.get(q) for q in keys}
                row["g3_1x_px_differing"] = {"before": g3(f1, f2), "after": g3(mock1, mock2)}
    # baseline U1/U2/U3 from 07's committed art_metrics.json
    am = json.load(open(os.path.join(E, "art_metrics.json"), encoding="utf-8"))
    res["baseline_art_metrics_json"] = {t: {s: {q: v.get(q) for q in ("hud_px_pct", "hud_on_units_pct", "cards_min_dE_normal",
                                                                      "cards_min_dE_deutan", "cards_min_shape_dL", "cards_pairs_failing_u1")}
                                            for s, v in r.get("scenes", {}).items()} for t, r in am.items() if isinstance(r, dict) and "scenes" in r}
    os.makedirs(a.out, exist_ok=True)
    res["verdict"] = verdict(res)
    json.dump(res, open(os.path.join(a.out, "mock_metrics.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    # sheets: ko 1x, before | after, two scenes, labelled
    for loc in a.tags.split(",")[:1]:
        rows = []
        for scene in ("4_r06_t46", "5_r08_peak"):
            b = img(os.path.join(E, f"{loc}_1x_{scene}.png"))
            m1 = img(os.path.join(a.work, "as_captured", f"{loc}_1x_{scene}.png"))
            m2 = img(os.path.join(a.work, "all_dimmed", f"{loc}_1x_{scene}.png"))
            rows.append(np.concatenate([b, np.full((b.shape[0], 6, 3), 255, np.uint8), m1, np.full((b.shape[0], 6, 3), 255, np.uint8), m2], axis=1))
        sheet = Image.fromarray(np.concatenate([np.concatenate([r, np.full((6, r.shape[1], 3), 255, np.uint8)], axis=0) for r in rows], axis=0))
        d = ImageDraw.Draw(sheet)
        for i, t in enumerate(("BASELINE ad47eda (real capture)", "PROPOSAL MOCK - not a real screen", "MOCK all cards unaffordable")):
            d.rectangle((i * 806 + 2, 64, i * 806 + 260, 76), fill=(0, 0, 0)); d.text((i * 806 + 4, 65), t, fill=(255, 255, 0))
        sheet.save(os.path.join(a.out, f"mock_{loc}_1x_r06_r08.png"), optimize=True)
        # 2x crop of the HUD row, r08
        b2 = img(os.path.join(E, f"{loc}_2x_5_r08_peak.png"))[580:720]
        m2 = img(os.path.join(a.work, "as_captured", f"{loc}_2x_5_r08_peak.png"))[580:720]
        Image.fromarray(np.concatenate([b2, np.full((6, b2.shape[1], 3), 255, np.uint8), m2], axis=0)).save(
            os.path.join(a.out, f"mock_{loc}_2x_r08_hudrow.png"), optimize=True)
    print(json.dumps(res["verdict"], ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
