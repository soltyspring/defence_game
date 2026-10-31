"""Background / base / FX readability metrics (owner: 09-art-world).

    python tools/art/world/world_metrics.py committed <out.json>          # committed captures (camera matched)
    python tools/art/world/world_metrics.py pair <before_dir> <after_dir> <out.json> [--before-root R] [--after-root R]
    python tools/art/world/world_metrics.py atlas <out.json> [--root R]    # FX cover + base damage from the atlas pages

Everything is measured on real pixels. Colour maths: CIE L*a*b* (D65) and dE76 from tools/art/cvd_check.py.
Engine placement is copied from src/gameplay/battle_view.gd (_draw_biome_layers, _blit_rec, _draw_fx) and
battle.gd (_update_camera): screen_x = world_x - round(cam_x) + view_w / 2, screen_y = world_y - view_top,
layer origin bx = floor(cam_x * (1 - parallax) + 0.5), copies every tile width. ground_y comes from data.

Metrics (definitions fixed before the redraw, see docs/art/world/WORLD_PLAN.md):
  unit_bg_dE       per unit pixel (outline excluded): dE76 between the unit pixel and the background pixel behind it
  camo_pct         share of those pixels with dE76 < 20 (the unit colour almost equals what is behind it)
  ring_dL          |mean L* of the unit interior - mean L* of the background ring 1..3 px outside the unit|
  edge_density     share of 4-neighbour pixel pairs with dE76 >= 15 (background only, per band / inside units)
  chroma_hi_pct    share of pixels with C*ab >= 35
  fx_cover         share of a unit's opaque pixels hidden by one FX frame drawn over it
  fx_same_pct      share of FX pixels over a unit whose dE76 to the unit pixel below is < 20 (FX invisible on it)
  base_state_px    share of the base frame pixels that change between idle and damaged / ruined
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
ROOT = os.path.abspath(os.path.join(ART, "..", ".."))
sys.path.insert(0, ART)
from cvd_check import lab  # noqa: E402  (03's colour maths, read-only import)
from pixel import PALETTE_DEF  # noqa: E402

KEY_OF = {}
for k, _, hx in PALETTE_DEF:
    if hx is not None and k != "_":
        KEY_OF[(int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16))] = k
WARM = set("TUWOowREeYZyrSLsHh")          # bread side keys after theme A (crust, cream, egg-wash, jam)
MOULD = set("DltzqQaAXx")                 # mould side keys
OUTLINE = (0x1B, 0x13, 0x25)


# ----------------------------------------------------------------------------- loading
def load_root(root):
    m = json.load(open(os.path.join(root, "assets", "manifest.json"), encoding="utf-8"))
    pages, docs = {}, {}
    for a in m["atlases"]:
        pid = a["id"]
        docs[pid] = json.load(open(os.path.join(root, a["frames"].replace("res://", "")), encoding="utf-8"))
        pages[pid] = np.array(Image.open(os.path.join(root, a["image"].replace("res://", ""))).convert("RGBA"))
    cfg = json.load(open(os.path.join(root, "data", "game_config.json"), encoding="utf-8"))
    return {"m": m, "pages": pages, "docs": docs, "gy": float(cfg["lane"]["ground_y"])}


def region(R, pid, fname):
    f = R["docs"][pid]["frames"][fname]
    return R["pages"][pid][f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]], f


def biome_layers(R, bid="biome_01"):
    b = R["m"]["biomes"][bid]
    out = []
    for L in b["layers"]:
        px, f = region(R, b["atlas"], L["frame"])
        out.append((L, px))
    return out, b.get("clear_color", "#3b5aa8")


# ----------------------------------------------------------------------------- engine replica
def _alpha_over(dst, src, x0, y0):
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xb <= xa or yb <= ya:
        return
    s = src[ya - y0:yb - y0, xa - x0:xb - x0].astype(float)
    al = s[..., 3:4] / 255.0
    dst[ya:yb, xa:xb] = dst[ya:yb, xa:xb] * (1 - al) + s[..., :3] * al


def compose_bg(R, cam_x, view_w=640, view_h=360, front=True, layers=None):
    layers, clear = layers or biome_layers(R)
    gy = R["gy"]
    cy = round(360 - view_h * 0.5)
    view_top = cy - view_h * 0.5
    img = np.zeros((view_h, view_w, 3), float)
    img[:] = [int(clear[1:3], 16), int(clear[3:5], 16), int(clear[5:7], 16)]
    left = cam_x - view_w * 0.5 - 8.0
    sx0 = round(cam_x) - view_w * 0.5           # world x of screen column 0
    for want_front in (False, True):
        if want_front and not front:
            break
        for L, px in layers:
            if (L.get("z", "") == "front") != want_front:
                continue
            par = float(L.get("parallax", 1.0))
            y = gy - L["lane_line"] if "lane_line" in L else float(L.get("view_y", gy - px.shape[0]))
            tw = px.shape[1]
            bx = math.floor(cam_x * (1.0 - par) + 0.5)
            x = math.floor((left - bx) / tw) * tw + bx
            while x < left + view_w + 16.0:
                _alpha_over(img, px, int(round(x - sx0)), int(round(y - view_top)))
                x += tw
    return img, view_top


def match_camera(R, cap, view_w, lo=-400, hi=3200):
    """Find cam_x so that the composed background matches the capture in background-only rows."""
    gy = int(R["gy"])
    rows_ground = slice(gy - 14, gy - 7)           # cobble rows of the ground layer (above the feet line)
    rows_mid = slice(200, 245)
    rows_far = slice(70, 170)
    layers, _ = biome_layers(R)
    gL, gpx = [(L, px) for L, px in layers if "lane_line" in L][0]
    y0 = int(gy - gL["lane_line"])
    band = gpx[(gy - 14) - y0:(gy - 7) - y0, :, :3].astype(float)
    tw = gpx.shape[1]
    reps = int(math.ceil(view_w / tw)) + 1
    tiled = np.concatenate([band] * reps, axis=1)
    target = cap[rows_ground]
    scores = []
    for s in range(tw):                             # screen column 0 shows ground column s
        scores.append(int((np.abs(tiled[:, s:s + view_w] - target).max(2) == 0).sum()))
    s_best = int(np.argmax(scores))
    r0 = s_best + view_w * 0.5                      # round(cam_x) modulo the tile width (ground parallax 1.0)
    best2 = None
    for k in range(-1, 7):
        for f in np.arange(-0.5, 0.5, 0.1):
            cam = r0 + k * tw + f
            if cam < lo or cam > hi:
                continue
            img, _ = compose_bg(R, float(cam), view_w)
            s = sum(int((np.abs(img[r] - cap[r]).max(2) == 0).sum()) for r in (rows_ground, rows_mid, rows_far))
            if best2 is None or s > best2[0]:
                best2 = (s, float(cam))
    img, vt = compose_bg(R, best2[1], view_w)
    band = slice(70, gy - 7)
    match = float((np.abs(img[band] - cap[band]).max(2) == 0).mean())
    return best2[1], img, match


def read_capture(path):
    im = np.array(Image.open(path).convert("RGB")).astype(float)
    H, W = im.shape[:2]
    k = 2 if H >= 700 else 1
    if k == 2:
        im = im[::2, ::2]
    return im, k


# ----------------------------------------------------------------------------- metrics
def keys_of(img, mask):
    ys, xs = np.nonzero(mask)
    return [KEY_OF.get(tuple(int(v) for v in img[y, x]), None) for y, x in zip(ys, xs)], ys, xs


def edge_density(img, mask=None):
    Lab = lab(img)
    dh = np.linalg.norm(Lab[:, 1:] - Lab[:, :-1], axis=2) >= 15
    dv = np.linalg.norm(Lab[1:] - Lab[:-1], axis=2) >= 15
    if mask is None:
        return float((dh.sum() + dv.sum()) / (dh.size + dv.size) * 100)
    mh = mask[:, 1:] & mask[:, :-1]
    mv = mask[1:] & mask[:-1]
    n = mh.sum() + mv.sum()
    return float((dh[mh].sum() + dv[mv].sum()) / max(1, n) * 100)


def band_stats(img, y0, y1):
    sub = img[y0:y1]
    Lab = lab(sub)
    C = np.hypot(Lab[..., 1], Lab[..., 2])
    return {"rows": [y0, y1], "L_mean": round(float(Lab[..., 0].mean()), 1), "L_std": round(float(Lab[..., 0].std()), 1),
            "C_mean": round(float(C.mean()), 1), "chroma_hi_pct": round(float((C >= 35).mean() * 100), 1),
            "edge_density": round(edge_density(sub), 1)}


def unit_contrast(full, bg, unit_mask, side_mask=None):
    """full/bg: 360xW RGB; unit_mask: bool of visible unit pixels (outline excluded by colour)."""
    m = unit_mask & ~np.all(full == OUTLINE, axis=2)
    if side_mask is not None:
        m &= side_mask
    if m.sum() == 0:
        return None
    La, Lb = lab(full[m]), lab(bg[m])
    dE = np.linalg.norm(La - Lb, axis=1)
    # ring: background pixels 1..3 px outside the unit mask
    grow = unit_mask.copy()
    for _ in range(3):
        g = grow.copy()
        g[1:] |= grow[:-1]; g[:-1] |= grow[1:]; g[:, 1:] |= grow[:, :-1]; g[:, :-1] |= grow[:, 1:]
        grow = g
    ring = grow & ~unit_mask
    ring_L = lab(bg[ring])[:, 0].mean() if ring.any() else float("nan")
    ring_lab = lab(bg[ring]).mean(0) if ring.any() else np.array([np.nan] * 3)
    inner = edge_density(np.where(m[..., None], full, 0), m)
    # per 8-row slice (tall objects such as bases cross the dark street and the light sky): |unit L* - ring L*|
    Lf, Lbg = lab(full)[..., 0], lab(bg)[..., 0]
    sl = []
    ys = np.nonzero(m.any(1))[0]
    for y0 in range(int(ys.min()), int(ys.max()) + 1, 8):
        mm, rr = m[y0:y0 + 8], ring[y0:y0 + 8]
        if mm.sum() >= 8 and rr.sum() >= 4:
            sl.append(abs(float(Lf[y0:y0 + 8][mm].mean()) - float(Lbg[y0:y0 + 8][rr].mean())))
    return {"px": int(m.sum()), "dE_median": round(float(np.median(dE)), 1), "camo_pct": round(float((dE < 20).mean() * 100), 1),
            "dL_median": round(float(np.median(np.abs(La[:, 0] - Lb[:, 0]))), 1),
            "ring_dL": round(float(abs(La[:, 0].mean() - ring_L)), 1),
            "ring_dE": round(float(np.linalg.norm(La.mean(0) - ring_lab)), 1),
            "slice_dL_median": round(float(np.median(sl)), 1) if sl else None,
            "slice_dL_min": round(float(np.min(sl)), 1) if sl else None,
            "unit_L_mean": round(float(La[:, 0].mean()), 1), "ring_L_mean": round(float(ring_L), 1),
            "inner_edge_density": round(inner, 1)}


def side_masks(full, diff):
    """Split changed palette pixels into bread-side / mould-side by palette key (committed captures only)."""
    H, W = diff.shape
    ally = np.zeros_like(diff)
    enemy = np.zeros_like(diff)
    ks, ys, xs = keys_of(full, diff)
    for k, y, x in zip(ks, ys, xs):
        if k is None:
            continue
        if k in WARM:
            ally[y, x] = True
        elif k in MOULD:
            enemy[y, x] = True
    return ally, enemy


def committed(out):
    R = load_root(ROOT)
    gy = int(R["gy"])
    caps = [("r03_30s_2x", "docs/art/evidence/merge_0130/ko_r03_autoplay_30s.png", 640),
            ("r03_45s_2x", "docs/art/evidence/merge_0130/ko_r03_autoplay_45s.png", 640),
            ("r06_46s_2x_view800", "docs/qa/zoom_preview/zoom_preview_current.png", 800)]
    rep = {"ground_y": gy, "captures": {}}
    for name, rel, vw in caps:
        cap, k = read_capture(os.path.join(ROOT, rel))
        cam, bg, match = match_camera(R, cap, vw)
        band = slice(150, gy + 9)
        diff = np.zeros(cap.shape[:2], bool)
        diff[band] = np.abs(cap[band] - bg[band]).max(2) > 0
        ally, enemy = side_masks(cap, diff)
        rep["captures"][name] = {
            "file": rel, "scale": k, "view_w": vw, "cam_x": cam, "bg_match_rows70_283": round(match * 100, 2),
            "ally": unit_contrast(cap, bg, ally), "enemy": unit_contrast(cap, bg, enemy),
            "bg_bands": {n: band_stats(bg, a, b) for n, (a, b) in
                         {"far_hills": (70, 175), "street_upper": (180, 250), "head_band": (gy - 35, gy - 5),
                          "lane": (gy - 6, gy + 7)}.items()},
        }
        Image.fromarray(np.rint(bg).astype(np.uint8)).save(os.path.join(os.path.dirname(out), f"bg_{name}.png"))
        vis = cap.copy()
        vis[ally] = [255, 0, 255]
        vis[enemy] = [0, 255, 255]
        Image.fromarray(np.rint(vis).astype(np.uint8)).save(os.path.join(os.path.dirname(out), f"mask_{name}.png"))
        print(name, json.dumps(rep["captures"][name]["ally"]), json.dumps(rep["captures"][name]["enemy"]), "match", match)
    json.dump(rep, open(out, "w", encoding="utf-8", newline="\n"), indent=1)
    return rep


# ----------------------------------------------------------------------------- atlas composites
def anim_frames(R, aset, anim):
    pid = R["m"]["anim_sets"][aset]
    an = R["docs"][pid]["anims"][aset].get(anim) or R["docs"][pid]["anims"][aset]["idle"]
    return [region(R, pid, n) for n in an["frames"]], an


def place(px, pv, x, y, flip):
    a = px[:, ::-1] if flip else px
    pvx = (px.shape[1] - pv[0]) if flip else pv[0]
    return a, int(x - pvx), int(y - pv[1])


def stamp_mask(shape, a, x0, y0):
    m = np.zeros(shape, bool)
    h, w = a.shape[:2]
    H, W = shape
    xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
    if xb > xa and yb > ya:
        m[ya:yb, xa:xb] = a[ya - y0:yb - y0, xa - x0:xb - x0, 3] > 0
    return m


TARGETS = [("melee_basic", 1), ("ranged_basic", 1), ("tank", 1), ("hero_captain", 1), ("worker", 1),
           ("e_grunt", -1), ("e_spitter", -1), ("e_brute", -1), ("e_swarm", -1)]


def fx_cover(R, bg):
    gy = int(R["gy"])
    out = {}
    for fxk, dy in (("hit_spark", -12), ("explosion", -6)):
        fr, an = anim_frames(R, fxk, "play")
        rows = []
        for aset, side in TARGETS:
            if aset not in R["m"]["anim_sets"]:
                continue
            uf, _ = anim_frames(R, aset, "attack")
            upx, uf0 = uf[min(2, len(uf) - 1)]
            ua, ux0, uy0 = place(upx, uf0["pivot"], 320, gy, side < 0)
            um = stamp_mask(bg.shape[:2], ua, ux0, uy0)
            comp = bg.copy()
            _alpha_over(comp, ua, ux0, uy0)
            covers, same = [], []
            for fpx, ff in fr:
                fa, fx0, fy0 = place(fpx, ff["pivot"], 320, gy + dy, False)
                fm = stamp_mask(bg.shape[:2], fa, fx0, fy0)
                ov = um & fm
                covers.append(float(ov.sum()) / max(1, int(um.sum())) * 100)
                if ov.any():
                    top = np.zeros_like(comp)
                    _alpha_over(top, fa, fx0, fy0)
                    d = np.linalg.norm(lab(top[ov]) - lab(comp[ov]), axis=1)
                    same.append(float((d < 20).mean() * 100))
            rows.append({"target": aset, "cover_peak": round(max(covers), 1), "cover_mean": round(float(np.mean(covers)), 1),
                         "frames": len(covers), "fx_same_pct_mean": round(float(np.mean(same)), 1) if same else 0.0})
        out[fxk] = rows
    return out


def base_states(R, bg):
    gy = int(R["gy"])
    out = {}
    for key, x in (("base_player", 60), ("base_enemy", 580)):
        st = {}
        frames = {s: anim_frames(R, key, s)[0][0] for s in ("idle", "damaged", "ruined")}
        ip = frames["idle"][0]
        ia = ip[..., 3] > 0
        body = lab(ip[ia][:, :3].astype(float))
        for s in ("damaged", "ruined"):
            p = frames[s][0]
            chg = (np.abs(p.astype(int) - ip.astype(int)).max(2) > 0) & ((p[..., 3] > 0) | ia)
            pa = p[..., 3] > 0
            cue = chg & pa
            cue_dE = np.linalg.norm(lab(p[cue][:, :3].astype(float)) - body.mean(0), axis=1) if cue.any() else np.array([0.0])
            st[s] = {"changed_px_pct_of_idle": round(float(chg.sum()) / max(1, int(ia.sum())) * 100, 1),
                     "silhouette_area_ratio": round(float(pa.sum()) / max(1, int(ia.sum())), 2),
                     "cue_dE_to_idle_mean_median": round(float(np.median(cue_dE)), 1),
                     "cue_px": int(cue.sum())}
        # contrast of the idle base mass vs the background behind it at a typical screen position
        a, x0, y0 = place(ip, frames["idle"][1]["pivot"], x, gy, False)
        m = stamp_mask(bg.shape[:2], a, x0, y0)
        comp = bg.copy()
        _alpha_over(comp, a, x0, y0)
        st["idle_vs_bg"] = unit_contrast(comp, bg, m)
        out[key] = st
    return out


def atlas_metrics(out, root=ROOT):
    R = load_root(root)
    bg, _ = compose_bg(R, 320.0)
    rep = {"root": root, "ground_y": R["gy"], "fx": fx_cover(R, bg), "bases": base_states(R, bg)}
    if out:
        json.dump(rep, open(out, "w", encoding="utf-8", newline="\n"), indent=1)
    print(json.dumps(rep, indent=1)[:4000])
    return rep


# ----------------------------------------------------------------------------- before/after capture pairs
def pair_metrics(cap_dir, root):
    """Exact masks from world_cam.gd: full vs bg frames + report (unit/fx rects, pivots, screen positions)."""
    R = load_root(root)
    rep = json.load(open(os.path.join(cap_dir, "shots", "world_report.json"), encoding="utf-8"))
    res = {}
    for c in rep["captures"]:
        if "error" in c:
            res[c.get("round", "?")] = {"error": c["error"]}
            continue
        full = np.array(Image.open(os.path.join(cap_dir, "shots", c["name"] + "_full.png")).convert("RGB")).astype(float)
        bgf = np.array(Image.open(os.path.join(cap_dir, "shots", c["name"] + "_bg.png")).convert("RGB")).astype(float)
        H, W = full.shape[:2]
        vw = c["view_w"]
        sx0 = round(c["cam_x"]) - vw * 0.5
        vt = c["view_top"]
        sh = (H, W)
        umask = {1: np.zeros(sh, bool), -1: np.zeros(sh, bool)}
        tinted = np.zeros(sh, bool)          # hit-flash / dying units: the engine modulates their colours (not art)
        fxm = np.zeros(sh, bool)
        for u in c["units"]:
            if "rect" not in u:
                continue
            pid = R["m"]["anim_sets"][u["anim_set"]]
            x, y, w, h = [int(v) for v in u["rect"]]
            px = R["pages"][pid][y:y + h, x:x + w]
            a, x0, y0 = place(px, u["pivot"], u["x"] - sx0, u["y"] - vt, u["flip"])
            mk = stamp_mask(sh, a, x0, y0)
            if u.get("flash") or u.get("dying"):
                tinted |= mk
            else:
                umask[1 if u["side"] > 0 else -1] |= mk
        for f in c["fx"]:
            if "rect" not in f:
                continue
            pid = R["m"]["anim_sets"][f["kind"]]
            x, y, w, h = [int(v) for v in f["rect"]]
            px = R["pages"][pid][y:y + h, x:x + w]
            a, x0, y0 = place(px, f["pivot"], f["x"] - sx0, f["y"] - vt, False)
            fxm |= stamp_mask(sh, a, x0, y0)
        changed = np.abs(full - bgf).max(2) > 0
        allm = umask[1] | umask[-1] | tinted
        r = {"t": c["t"], "cam_x": c["cam_x"], "units": len(c["units"]), "fx": len(c["fx"]), "ended": c.get("ended", False),
             "bases": c["bases"], "tinted_units_excluded": sum(1 for u in c["units"] if u.get("flash") or u.get("dying"))}
        for side, nm in ((1, "ally"), (-1, "enemy")):
            vis = umask[side] & changed & ~fxm & ~umask[-side] & ~tinted
            r[nm] = unit_contrast(full, bgf, vis)
        # per unit (same exclusions), so a single camouflaged unit is visible in the report
        per = []
        for u in c["units"]:
            if "rect" not in u or u.get("flash") or u.get("dying"):
                continue
            pid = R["m"]["anim_sets"][u["anim_set"]]
            x, y, w, h = [int(v) for v in u["rect"]]
            a, x0, y0 = place(R["pages"][pid][y:y + h, x:x + w], u["pivot"], u["x"] - sx0, u["y"] - vt, u["flip"])
            mk = stamp_mask(sh, a, x0, y0)
            vis = mk & changed & ~fxm & ~(allm & ~mk)
            if vis.sum() >= 15:
                uc = unit_contrast(full, bgf, vis)
                per.append({"set": u["anim_set"], "side": u["side"], "x": u["x"], "ring_dL": uc["ring_dL"], "ring_dE": uc["ring_dE"]})
        r["per_unit"] = per
        r["fx_cover_of_units_pct"] = round(float((fxm & allm).sum()) / max(1, int(allm.sum())) * 100, 1)
        r["fx_px"] = int(fxm.sum())
        gy = int(c["ground_y"] - vt)
        r["bg_bands"] = {n: band_stats(bgf, a, b) for n, (a, b) in
                         {"far": (60, 175), "street_upper": (180, 250), "head_band": (gy - 35, gy - 5), "lane": (gy - 6, gy + 7)}.items()}
        # bases on screen: mask from the atlas frame that matches the capture, true background from the atlas biome
        comp_bg, _ = compose_bg(R, float(c["cam_x"]), int(vw), H)
        for key, b in c["bases"].items():
            ratio = float(b["ratio"])
            state = "idle" if ratio > 0.5 else ("damaged" if ratio > 0.0 else "ruined")
            best = None
            for px, f in anim_frames(R, "base_" + key, state)[0]:
                a, x0, y0 = place(px, f["pivot"], b["x"] - sx0, c["ground_y"] - vt, False)
                m = stamp_mask(sh, a, x0, y0)
                if m.sum() < 200:
                    continue
                tmp = np.zeros_like(bgf)
                _alpha_over(tmp, a, x0, y0)
                score = int((np.abs(tmp[m] - bgf[m]).max(1) == 0).sum())
                if best is None or score > best[0]:
                    best = (score, m)
            if best is not None:
                vis = best[1] & ~umask[1] & ~umask[-1]
                rr = unit_contrast(bgf, comp_bg, vis)
                if rr:
                    rr["state"] = state
                    rr["match_pct"] = round(best[0] / max(1, int(best[1].sum())) * 100, 1)
                r["base_" + key] = rr
        res[c["name"]] = r
    return res


def pair(before, after, out, broot, aroot):
    rep = {"before": {"dir": before, "root": broot, "res": pair_metrics(before, broot)},
           "after": {"dir": after, "root": aroot, "res": pair_metrics(after, aroot)}}
    # same game state check: unit positions and frame indices must be identical
    same = {}
    for name in rep["before"]["res"]:
        b = json.load(open(os.path.join(before, "shots", "world_report.json"), encoding="utf-8"))
        a = json.load(open(os.path.join(after, "shots", "world_report.json"), encoding="utf-8"))
        cb = {c.get("name"): c for c in b["captures"]}
        ca = {c.get("name"): c for c in a["captures"]}
        if name in cb and name in ca:
            ub = [(u["anim_set"], u["x"], u["y"], u.get("frame_index")) for u in cb[name]["units"]]
            ua = [(u["anim_set"], u["x"], u["y"], u.get("frame_index")) for u in ca[name]["units"]]
            same[name] = {"units_identical": ub == ua, "t_before": cb[name]["t"], "t_after": ca[name]["t"],
                          "cam_identical": cb[name]["cam_x"] == ca[name]["cam_x"]}
    rep["same_state"] = same
    json.dump(rep, open(out, "w", encoding="utf-8", newline="\n"), indent=1)
    for name in rep["before"]["res"]:
        b, a = rep["before"]["res"][name], rep["after"]["res"].get(name, {})
        if "error" in b:
            continue
        print(name, same.get(name), "\n  before ally", b["ally"], "\n  after  ally", a.get("ally"),
              "\n  before enemy", b["enemy"], "\n  after  enemy", a.get("enemy"),
              "\n  fx cover", b["fx_cover_of_units_pct"], "->", a.get("fx_cover_of_units_pct"))
    return rep


if __name__ == "__main__":
    cmd = sys.argv[1]
    args = sys.argv[2:]
    opt = {}
    pos = []
    i = 0
    while i < len(args):
        if args[i].startswith("--"):
            opt[args[i][2:]] = args[i + 1]
            i += 2
        else:
            pos.append(args[i])
            i += 1
    if cmd == "committed":
        committed(pos[0])
    elif cmd == "atlas":
        atlas_metrics(pos[0], opt.get("root", ROOT))
    elif cmd == "pair":
        pair(pos[0], pos[1], pos[2], opt.get("before-root", ROOT), opt.get("after-root", ROOT))
