"""07-qa screen metrics for the fixed graphics baseline (Python + Pillow + numpy; no Godot).

Input: a capture folder written by tests/acceptance/capture_art_baseline.gd:
    <dir>/<tag>_art_report.json, <dir>/<tag>_<scene>.png, <dir>/layers/<tag>_<scene>_{h,ht,htf,bg}.png
    python tools/qa/art_metrics.py --dir <dir> [--tags ko_1x,ko_2x,en_1x,en_2x] [--out <json>]
Masks (exact pixel differences between frames of the same frozen sim state):
    HUD  = full frame vs UI layer hidden            TEXT = UI hidden vs + damage numbers hidden
    FX   = + effects/projectiles hidden vs before   UNIT = + units/hero hidden vs before, minus HP-bar rects
Per battle scene:
    unit_px_pct        UNIT pixels / screen (the player-visible part is unit_visible_pct: UNIT minus HUD, FX, TEXT)
    j1_rect_pct        capture_m8 definition (walk-frame rects + base boxes), kept for continuity
    allies/enemies_in_camera from the sim state at the frame
    unit_dL_*          per unit: |mean L* of its UNIT pixels - mean L* of the same pixels in the no-unit frame|
    faction_dE_*       mean Lab of all ally UNIT pixels vs all enemy UNIT pixels (normal, deutan, protan;
                       Machado 2009 severity 1.0 in linear RGB); nearest_opposite_dE_* per unit (median, min)
    fx_on_units_pct    UNIT pixels changed by effects / UNIT;  text_on_units_pct likewise; hud_on_units_pct
    hud_px_pct         HUD pixels / screen
    lane_busy_dL       mean |dL*| between neighbouring pixels of the no-unit frame in the lane band (ground-34..ground+6
                       logical px), outside the HUD: how much background detail units have to stand out against
    cards_*            card icons on screen: min pairwise mean-colour dE (normal, deutan) and min pairwise shape
                       distance (16x16 L* pattern, mean |dL*|), with the pair
Prints one JSON summary; writes the full result to --out (default <dir>/art_metrics.json). Owner: 07-qa.
Animation (tags captured with --anim; per unit id, crops of the unit ALONE at its real position, 1x view px):
    walk_change_max/mean_pct   pixels that change between consecutive walk frames / union of both silhouettes
    walk_bob_px, walk_edge_travel_px   top-edge range and largest left/right edge travel over the cycle
    attack_reach_px            how far the front edge moves forward (facing direction) vs walk frame 0
    attack_distinct_pct        most distinct attack frame vs its CLOSEST walk frame (hitting vs walking)
    hit_change_pct, hit_dE_mean   the hit reaction the game draws (flash on walk frame 0) vs walk frame 0
    death_pose_change_pct, death_frames_readable, death_readable_until_s   silhouette change (XOR / union) of the death
                               frames that still show >= 25 % of the body at mean |dL*| >= 10 against the background
                               (fade included), how many such frames, and until when
"""
import argparse
import itertools
import json
import os

import numpy as np
from PIL import Image

MACHADO = {
    "deutan": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "protan": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
}
# 393x873 dp phone in landscape shows the 360 px tall view over 393 dp; 1 dp = 1/160 in = 0.15875 mm
MM_PER_VIEW_PX = 393.0 / 360.0 * 0.15875


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.uint8)


def lin(rgb8):
    v = rgb8.astype(np.float64) / 255.0
    return np.where(v <= 0.04045, v / 12.92, ((v + 0.055) / 1.055) ** 2.4)


def lab_from_lin(l):
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = l @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], axis=-1)


def lab(rgb8, sim=None):
    l = lin(rgb8)
    if sim:
        l = np.clip(l @ MACHADO[sim].T, 0.0, 1.0)
    return lab_from_lin(l)


def rect_px(r, k, grow=0.0, shape=None):
    x0 = int(np.floor((r[0] - grow) * k)); y0 = int(np.floor((r[1] - grow) * k))
    x1 = int(np.ceil((r[0] + r[2] + grow) * k)); y1 = int(np.ceil((r[1] + r[3] + grow) * k))
    if shape is not None:
        x0, y0 = max(0, x0), max(0, y0)
        x1, y1 = min(shape[1], x1), min(shape[0], y1)
    return x0, y0, x1, y1


def diff(a, b):
    return np.any(a != b, axis=-1)


def pct(n, d):
    return round(100.0 * n / d, 2) if d else None


def scene_metrics(d, tag, scene, meta, k, view=(800, 360)):
    base = os.path.join(d, "layers", f"{tag}_{scene}")
    full = load(os.path.join(d, f"{tag}_{scene}.png"))
    h, ht, htf, bg = (load(base + s + ".png") for s in ("_h", "_ht", "_htf", "_bg"))
    shape = full.shape
    screen = shape[0] * shape[1]
    hud = diff(full, h)
    text = diff(h, ht)
    fx = diff(ht, htf)
    unit = diff(htf, bg)
    for u in meta["units"]:
        if u.get("bar"):
            x0, y0, x1, y1 = rect_px(u["bar"], k, 1.0, shape)
            unit[y0:y1, x0:x1] = False
    nunit = int(unit.sum())
    visible = unit & ~hud & ~fx & ~text
    lab_u, lab_b = lab(htf), lab(bg)
    lab_ud, lab_up = lab(htf, "deutan"), lab(htf, "protan")
    per = []
    side_px = {"ally": np.zeros(shape[:2], bool), "enemy": np.zeros(shape[:2], bool)}
    for u in meta["units"]:
        if not u["in_camera"] or u["dying"]:
            continue
        x0, y0, x1, y1 = rect_px(u["rect"], k, 1.0, shape)
        m = np.zeros(shape[:2], bool)
        m[y0:y1, x0:x1] = unit[y0:y1, x0:x1]
        n = int(m.sum())
        if n < 4 * k * k:
            continue
        side_px[u["side"]] |= m
        rows = np.where(m.any(axis=1))[0]
        per.append({"id": u["id"], "side": u["side"], "hero": u["hero"], "boss": u["boss"], "px": n,
                    "h_view": float(rows.max() - rows.min() + 1) / k,
                    "dL": float(abs(lab_u[m][:, 0].mean() - lab_b[m][:, 0].mean())),
                    "lab": lab_u[m].mean(axis=0), "lab_d": lab_ud[m].mean(axis=0), "lab_p": lab_up[m].mean(axis=0),
                    "fx_pct": pct(int((m & fx).sum()), n), "visible_pct": pct(int((m & visible).sum()), n)})
    out = {"scene": scene, "sim_t": meta["sim_t"], "units_in_camera": meta["units_in_camera"],
           "allies_in_camera": meta["allies_in_camera"], "enemies_in_camera": meta["enemies_in_camera"],
           "boss_in_camera": meta["boss_in_camera"], "j1_rect_pct": meta["j1_rect_pct"],
           "unit_px_pct": pct(nunit, screen), "unit_visible_pct": pct(int(visible.sum()), screen),
           "hud_px_pct": pct(int(hud.sum()), screen),
           "fx_on_units_pct": pct(int((unit & fx).sum()), nunit), "text_on_units_pct": pct(int((unit & text).sum()), nunit),
           "hud_on_units_pct": pct(int((unit & hud).sum()), nunit), "units_measured": len(per)}
    if per:
        dls = sorted(p["dL"] for p in per)
        out["unit_dL_median"] = round(float(np.median(dls)), 1)
        out["unit_dL_min"] = round(dls[0], 1)
        out["unit_dL_min_id"] = min(per, key=lambda p: p["dL"])["id"]
        out["unit_dL_share_below_15"] = pct(sum(1 for v in dls if v < 15.0), len(dls))
        fxs = [p["fx_pct"] for p in per if p["fx_pct"] is not None]
        out["fx_on_unit_max_pct"] = max(fxs) if fxs else None
        reg = [p for p in per if not p["hero"] and not p["boss"]]
        if reg:
            hs = sorted(p["h_view"] for p in reg)
            out["regular_unit_height_median_px"] = round(float(np.median(hs)), 1)
            out["regular_unit_height_median_mm_393dp"] = round(float(np.median(hs)) * MM_PER_VIEW_PX, 2)
            out["regular_unit_px_median"] = int(np.median([p["px"] / (k * k) for p in reg]))
        for p in per:
            if p["hero"] or p["boss"]:
                key = "hero" if p["hero"] else "boss"
                out[f"{key}_dL"] = round(p["dL"], 1)
                out[f"{key}_height_px"] = round(p["h_view"], 1)
                out[f"{key}_id"] = p["id"]
    a, e = side_px["ally"], side_px["enemy"]
    if a.any() and e.any():
        for key, L in (("normal", lab_u), ("deutan", lab_ud), ("protan", lab_up)):
            out[f"faction_dE_{key}"] = round(float(np.linalg.norm(L[a].mean(axis=0) - L[e].mean(axis=0))), 1)
        for key, fld in (("normal", "lab"), ("deutan", "lab_d")):
            near = []
            for p in per:
                opp = [q for q in per if q["side"] != p["side"]]
                if opp:
                    near.append(min(float(np.linalg.norm(p[fld] - q[fld])) for q in opp))
            if near:
                out[f"nearest_opposite_dE_{key}_median"] = round(float(np.median(near)), 1)
                out[f"nearest_opposite_dE_{key}_min"] = round(min(near), 1)
    gy = meta["ground_screen_y"]
    y0, y1 = max(0, int((gy - 34) * k)), min(shape[0], int((gy + 6) * k))
    band = lab_b[y0:y1, :, 0]
    bm = ~hud[y0:y1, :]
    gx = np.abs(np.diff(band, axis=1)); gyy = np.abs(np.diff(band, axis=0))
    mx = bm[:, 1:] & bm[:, :-1]; my = bm[1:, :] & bm[:-1, :]
    if mx.any() and my.any():
        out["lane_busy_dL"] = round(float((gx[mx].mean() + gyy[my].mean()) / 2.0), 2)
    cards = [c for c in meta.get("cards", []) if c.get("icon")]
    if len(cards) >= 2:
        feats = []
        for c in cards:
            x0, y0, x1, y1 = rect_px(c["icon"], k, 0.0, shape)
            crop = full[y0:y1, x0:x1]
            pat = np.asarray(Image.fromarray(crop).resize((16, 16), Image.BOX), dtype=np.uint8)
            feats.append({"text": c["text"], "disabled": c["disabled"], "lab": lab(crop).reshape(-1, 3).mean(axis=0),
                          "lab_d": lab(crop, "deutan").reshape(-1, 3).mean(axis=0), "pat": lab(pat)[..., 0]})
        best = {}
        fails = []
        for i, j in itertools.combinations(range(len(feats)), 2):
            p, q = feats[i], feats[j]
            dn = float(np.linalg.norm(p["lab"] - q["lab"]))
            dd = float(np.linalg.norm(p["lab_d"] - q["lab_d"]))
            sh = float(np.abs(p["pat"] - q["pat"]).mean())
            if not ((dn >= 10.0 and dd >= 8.0) or sh >= 12.0):   # ART_BASELINE U1, per pair
                fails.append(f'{p["text"]} / {q["text"]}')
            for key, val in (("cards_min_dE_normal", dn), ("cards_min_dE_deutan", dd), ("cards_min_shape_dL", sh)):
                if key not in best or val < best[key][0]:
                    best[key] = (val, f'{p["text"]} / {q["text"]}')
        for key, (val, pair) in best.items():
            out[key] = round(val, 1)
            out[key + "_pair"] = pair
        out["cards_disabled"] = [f["text"] for f in feats if f["disabled"]]
        out["cards_on_screen"] = len(feats)
        out["cards_pairs_total"] = len(feats) * (len(feats) - 1) // 2
        out["cards_pairs_failing_u1"] = len(fails)
        out["cards_pairs_failing_u1_list"] = fails
    # LAYOUT L1/L2: battlefield left visible by the HUD, and HUD pixels on the lane band (same band as lane_busy_dL)
    out["battlefield_visible_pct"] = round(100.0 - out["hud_px_pct"], 2)
    ly0, ly1 = max(0, int((gy - 34) * k)), min(shape[0], int((gy + 6) * k))   # own names: y0/y1 are reused by the card loop above
    band_hud = hud[ly0:ly1, :]
    out["hud_on_lane_px"] = int(round(band_hud.sum() / (k * k)))
    out["hud_on_lane_pct"] = pct(int(band_hud.sum()), band_hud.size)
    if meta.get("layout"):
        out.update(layout_metrics(meta["layout"], view, meta))
    out["frame_mean"] = round(float(full.mean()), 1)
    out["frame_near_black_pct"] = pct(int((full.sum(axis=-1) < 30).sum()), screen)
    return out


def _anim_mask(fr, bg, bar, k):
    m = diff(fr, bg)
    if bar:
        x0, y0, x1, y1 = rect_px(bar, k, 1.0, m.shape)
        m[y0:y1, x0:x1] = False
    return m


def _bbox(m):
    ys, xs = np.where(m)
    if len(ys) == 0:
        return None
    return int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())


def anim_metrics(d, tag, rep, k, sheet_dir=""):
    """Per unit id: pose crops from capture_art_baseline.gd --anim (1x view px; all lengths in view px)."""
    adir = os.path.join(d, "layers", "anim")
    out = {}
    for uid, info in rep.get("anim", {}).items():
        bgp = os.path.join(adir, f"{tag}_{uid}_bg.png")
        if not os.path.exists(bgp):
            continue
        bg = load(bgp)
        fr, mk = {}, {}
        for an, a in info["anims"].items():
            fr[an] = [load(os.path.join(adir, f"{tag}_{uid}_{an}_{i}.png")) for i in range(a["frames"])]
            mk[an] = [_anim_mask(f, bg, info["bars"].get(f"{an}_{i}"), k) for i, f in enumerate(fr[an])]
        hp = os.path.join(adir, f"{tag}_{uid}_hitflash_0.png")
        if os.path.exists(hp):
            fr["hitflash"] = [load(hp)]
            mk["hitflash"] = [_anim_mask(fr["hitflash"][0], bg, info["bars"].get("hitflash_0"), k)]

        def change(a, ia, b, ib):
            ma, mb = mk[a][ia], mk[b][ib]
            u = ma | mb
            ch = diff(fr[a][ia], fr[b][ib]) & u
            den = u.sum()
            return 100.0 * ch.sum() / den if den else 0.0

        r = {"scene": info["scene"], "side": info["side"], "hero": info["hero"], "boss": info["boss"],
             "atlas_hit_frames": info.get("atlas_hit_frames", 0), "hit_anim_drawn_by_game": False}
        fac = info["facing"]

        def front(m):
            bb = _bbox(m)
            return None if bb is None else (bb[3] if fac > 0 else -bb[2])
        if "walk" in mk:
            n = len(mk["walk"])
            pairs = [(i, (i + 1) % n) for i in range(n if info["anims"]["walk"]["loop"] else n - 1)]
            ch = [change("walk", i, "walk", j) for i, j in pairs]
            tops = [b[0] for b in map(_bbox, mk["walk"]) if b]
            lefts = [b[2] for b in map(_bbox, mk["walk"]) if b]
            rights = [b[3] for b in map(_bbox, mk["walk"]) if b]
            r["body_px"] = int(np.median([m.sum() for m in mk["walk"]]) / (k * k))
            bb0 = _bbox(mk["walk"][0])
            r["body_height_px"] = (bb0[1] - bb0[0] + 1) / k if bb0 else None
            r["walk_change_max_pct"] = round(max(ch), 1)
            r["walk_change_mean_pct"] = round(float(np.mean(ch)), 1)
            r["walk_bob_px"] = (max(tops) - min(tops)) / k if tops else None
            r["walk_edge_travel_px"] = max(max(lefts) - min(lefts), max(rights) - min(rights)) / k if lefts else None
            r["walk_fps"] = info["anims"]["walk"]["fps"]
            r["walk_frames"] = n
        if "attack" in mk and "walk" in mk:
            f0 = front(mk["walk"][0])
            reach = [front(m) - f0 for m in mk["attack"] if front(m) is not None and f0 is not None]
            r["attack_reach_px"] = max(reach) / k if reach else None
            r["attack_vs_walk0_max_pct"] = round(max(change("attack", i, "walk", 0) for i in range(len(mk["attack"]))), 1)
            # most distinct attack frame against its CLOSEST walk frame: can a player tell hitting from walking?
            r["attack_distinct_pct"] = round(max(min(change("attack", i, "walk", j) for j in range(len(mk["walk"])))
                                                 for i in range(len(mk["attack"]))), 1)
            r["attack_frames"] = len(mk["attack"])
            r["attack_s"] = round(len(mk["attack"]) / info["anims"]["attack"]["fps"], 2)
        if "hitflash" in mk and "walk" in mk:
            m0 = mk["walk"][0]
            r["hit_change_pct"] = round(change("hitflash", 0, "walk", 0), 1)
            if m0.any():
                r["hit_dE_mean"] = round(float(np.linalg.norm(lab(fr["hitflash"][0])[m0] - lab(fr["walk"][0])[m0], axis=-1).mean()), 1)
            r["hit_shown_s"] = 0.12
        if "death" in mk and "walk" in mk:
            alive = mk["walk"][0].sum()
            Lb = lab(bg)[..., 0]
            vis = []
            for i, m in enumerate(mk["death"]):
                dl = float(np.abs(lab(fr["death"][i])[..., 0][m] - Lb[m]).mean()) if m.any() else 0.0
                vis.append(bool(m.sum() >= 0.25 * alive and dl >= 10.0))
            fps = info["anims"]["death"]["fps"]
            r["death_first_change_pct"] = round(change("death", 0, "walk", 0), 1)
            # silhouette change of the frames the player can still see (colour fade excluded): does it fall / collapse?
            m0 = mk["walk"][0]
            xs = [100.0 * (m ^ m0).sum() / max(1, (m | m0).sum()) for i, m in enumerate(mk["death"]) if vis[i]]
            r["death_pose_change_pct"] = round(max(xs), 1) if xs else 0.0
            r["death_frames"] = len(mk["death"])
            r["death_frames_readable"] = int(sum(vis))
            r["death_readable_share_pct"] = round(100.0 * sum(vis) / len(vis), 1) if vis else 0.0
            last = max([i for i, v in enumerate(vis) if v], default=-1)
            r["death_readable_until_s"] = round((last + 1) / fps, 2) if last >= 0 else 0.0
            r["death_anim_s"] = round(len(mk["death"]) / fps, 2)
        out[uid] = r
        if sheet_dir:
            rows = []
            for an in ("idle", "walk", "attack", "hitflash", "death"):
                if an in fr:
                    rows.append(np.concatenate([bg] + fr[an], axis=1))
            w = max(x.shape[1] for x in rows)
            rows = [np.pad(x, ((0, 0), (0, w - x.shape[1]), (0, 0)), constant_values=255) for x in rows]
            Image.fromarray(np.concatenate(rows, axis=0)).resize((w * 2, sum(x.shape[0] for x in rows) * 2), Image.NEAREST) \
                .save(os.path.join(sheet_dir, f"anim_{uid}.png"))
    return out


def _rect_gap(a, b):
    dx = max(0.0, b[0] - (a[0] + a[2]), a[0] - (b[0] + b[2]))
    dy = max(0.0, b[1] - (a[1] + a[3]), a[1] - (b[1] + b[3]))
    if dx == 0.0 and dy == 0.0:
        ox = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
        oy = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
        return -1.0 if ox > 0 and oy > 0 else 0.0
    return float(np.hypot(dx, dy))


def _overlap_area(a, b):
    ox = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    oy = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return max(0.0, ox) * max(0.0, oy)


def layout_metrics(lay, view, meta=None):
    """LAYOUT.md L3-L8 from the UI node dump (logical px of the 800x360 view; mm on the 393 dp phone)."""
    vw, vh = view
    nodes = lay.get("nodes", [])
    # only the top screen counts: targets under a later full-screen top-level layer (e.g. HUD under /Result) are not
    # reachable by the player and are left out of L3/L4/L5/L8
    top = [i for i, n in enumerate(nodes) if n["path"].count("/") == 1 and n["rect"][2] * n["rect"][3] >= 0.9 * vw * vh]
    first = top[-1] if top else -1
    tg = [n for i, n in enumerate(nodes) if i > first and n["touch"] and n["rect"][2] > 0 and n["rect"][3] > 0]
    out = {"touch_targets": len(tg), "top_layer": nodes[first]["path"] if first >= 0 else ""}
    if tg:
        sides = [(min(n["rect"][2], n["rect"][3]), n) for n in tg]
        mn = min(sides, key=lambda s: s[0])
        out["touch_min_side_px"] = round(mn[0], 1)
        out["touch_min_side_mm"] = round(mn[0] * MM_PER_VIEW_PX, 2)
        out["touch_min_side_who"] = (mn[1]["role"] or mn[1]["text"] or mn[1]["path"].split("/")[-1])[:24]
        out["touch_below_44"] = sum(1 for s, _ in sides if s < 44.0)
        gaps, ov = [], 0
        for i in range(len(tg)):
            for j in range(i + 1, len(tg)):
                g = _rect_gap(tg[i]["rect"], tg[j]["rect"])
                if g < 0:
                    ov += 1
                gaps.append((max(g, 0.0), tg[i], tg[j]))
        if gaps:
            g = min(gaps, key=lambda x: x[0])
            out["touch_min_gap_px"] = round(g[0], 1)
            out["touch_min_gap_mm"] = round(g[0] * MM_PER_VIEW_PX, 2)
            out["touch_min_gap_pair"] = " / ".join((x["role"] or x["text"] or x["path"].split("/")[-1])[:16] for x in (g[1], g[2]))
        out["touch_overlaps"] = ov
        ins = lay.get("safe_insets", [0, 0, 0, 0])
        out["touch_outside_safe"] = sum(1 for n in tg if n["rect"][0] < ins[0] - 0.5 or n["rect"][0] + n["rect"][2] > vw - ins[2] + 0.5
                                        or n["rect"][1] < ins[1] - 0.5 or n["rect"][1] + n["rect"][3] > vh - ins[3] + 0.5)
        # frequent controls (move, card, skill, worker) with their centre in the top half of the screen
        out["frequent_outside_bottom_half"] = sum(1 for n in tg if n["role"] in ("move", "card", "skill", "worker")
                                                  and n["rect"][1] + n["rect"][3] / 2.0 < vh / 2.0)
        # thumb reach: centre distance to the nearest BOTTOM corner of the screen (both hands hold the bottom corners)
        for role in ("move", "card", "skill", "worker", "pause"):
            ds = []
            for n in tg:
                if n["role"] == role:
                    cx, cy = n["rect"][0] + n["rect"][2] / 2.0, n["rect"][1] + n["rect"][3] / 2.0
                    ds.append(min(np.hypot(cx, vh - cy), np.hypot(vw - cx, vh - cy)))
            if ds:
                out[f"thumb_{role}_max_mm"] = round(max(ds) * MM_PER_VIEW_PX, 1)
    txt = [n for n in nodes if n["text"].strip() and n["font_size"] > 0]
    if txt:
        m = min(txt, key=lambda n: n["font_size"])
        out["text_min_px"] = m["font_size"]
        out["text_min_mm"] = round(m["font_size"] * MM_PER_VIEW_PX, 2)
        out["text_min_who"] = m["text"][:24]
    for t in lay.get("threat", []):
        if t["name"] != "threat_right":
            continue
        out["threat_right_shown"] = bool(t["visible"])
        big = vw * vh * 0.5
        anc = [n for n in nodes if not (n["rect"][2] * n["rect"][3] >= big) and "threat" not in n["path"]]
        out["threat_right_overlap_px"] = round(max([_overlap_area(t["rect"], n["rect"]) for n in anc] or [0.0]), 1) if t["visible"] else None
    if meta is not None and "enemy_offscreen_right" in meta:
        out["enemy_offscreen_right_px"] = meta["enemy_offscreen_right"]
        need = meta["enemy_offscreen_right"] > 0
        out["threat_needed"] = need
        # None = not exercised (no enemy beyond the right edge at this frame), so L6 cannot pass vacuously
        out["threat_missing"] = (0 if out.get("threat_right_shown", False) else 1) if need else None
    return out


def compare_dirs(a_dir, b_dir, tag):
    """Re-run check: every PNG of `tag` in a_dir (main shots and layers) against the same file in b_dir."""
    rows = []
    for sub in ("", "layers"):
        pa = os.path.join(a_dir, sub)
        for fn in sorted(os.listdir(pa)):
            if not (fn.startswith(tag + "_") and fn.endswith(".png")):
                continue
            fb = os.path.join(b_dir, sub, fn)
            if not os.path.exists(fb):
                rows.append({"file": os.path.join(sub, fn), "status": "missing in B"})
                continue
            x, y = load(os.path.join(pa, fn)), load(fb)
            n = int(diff(x, y).sum()) if x.shape == y.shape else -1
            rows.append({"file": os.path.join(sub, fn), "diff_px": n})
    same = sum(1 for r in rows if r.get("diff_px") == 0)
    return {"files": len(rows), "identical": same, "differing": [r for r in rows if r.get("diff_px") != 0]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--tags", default="ko_1x,ko_2x,en_1x,en_2x")
    ap.add_argument("--out", default="")
    ap.add_argument("--compare-dir", default="", help="second capture folder of the same tags: pixel-exact re-run check")
    ap.add_argument("--sheets", default="", help="write one animation contact sheet per unit id here (x2 nearest)")
    a = ap.parse_args()
    if a.compare_dir:
        res = {t: compare_dirs(a.dir, a.compare_dir, t) for t in a.tags.split(",") if t}
        print(json.dumps(res, ensure_ascii=False))
        if a.out:
            with open(a.out, "w", encoding="utf-8") as f:
                json.dump(res, f, ensure_ascii=False, indent=1)
        return
    res = {}
    for tag in [t for t in a.tags.split(",") if t]:
        rp = os.path.join(a.dir, f"{tag}_art_report.json")
        if not os.path.exists(rp):
            res[tag] = {"error": "no report"}
            continue
        rep = json.load(open(rp, encoding="utf-8"))
        k = rep["window"][0] / rep["view"][0] if rep["window"][0] else 1.0
        res[tag] = {"k": k, "notes": rep.get("notes", []), "scenes": {}}
        for scene, meta in rep["scenes"].items():
            if meta.get("kind") != "battle":
                img = load(os.path.join(a.dir, f"{tag}_{scene}.png"))
                res[tag]["scenes"][scene] = {"scene": scene, "frame_mean": round(float(img.mean()), 1),
                                             "frame_near_black_pct": pct(int((img.sum(axis=-1) < 30).sum()), img.shape[0] * img.shape[1])}
                if meta.get("layout"):
                    res[tag]["scenes"][scene].update(layout_metrics(meta["layout"], rep["view"]))
                continue
            res[tag]["scenes"][scene] = scene_metrics(a.dir, tag, scene, meta, k, rep["view"])
            for key in ("prepass", "prepass_matches", "battle_seed", "budget", "bot"):
                if key in meta:
                    res[tag]["scenes"][scene][key] = meta[key]
        res[tag]["script_sha256"] = rep.get("script_sha256", "")
        if rep.get("anim"):
            sd = ""
            if a.sheets:
                sd = a.sheets
                os.makedirs(sd, exist_ok=True)
            res[tag]["anim"] = anim_metrics(a.dir, tag, rep, k, sd)
    out = a.out or os.path.join(a.dir, "art_metrics.json")
    # pixel integrity: a 2x frame must be the 1x frame scaled by exactly 2 (nearest), scene by scene
    for loc in ("ko", "en"):
        t1, t2 = f"{loc}_1x", f"{loc}_2x"
        if t1 in res and t2 in res and "scenes" in res[t1] and "scenes" in res[t2]:
            chk = {}
            for scene in res[t1]["scenes"]:
                f1, f2 = os.path.join(a.dir, f"{t1}_{scene}.png"), os.path.join(a.dir, f"{t2}_{scene}.png")
                if os.path.exists(f1) and os.path.exists(f2):
                    x, y = load(f1), load(f2)
                    if y.shape[0] == 2 * x.shape[0] and y.shape[1] == 2 * x.shape[1]:
                        same = all(np.array_equal(y[i::2, j::2], x) for i in (0, 1) for j in (0, 1))
                        chk[scene] = {"exact_2x": same, "diff_px_vs_1x": int(diff(y[0::2, 0::2], x).sum())}
            res[f"scale_check_{loc}"] = chk
    with open(out, "w", encoding="utf-8") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print(json.dumps({t: {s: {kk: v for kk, v in m.items() if kk in ("unit_px_pct", "enemies_in_camera", "unit_dL_median", "faction_dE_normal", "fx_on_units_pct", "hud_px_pct", "cards_min_dE_normal")} for s, m in r.get("scenes", {}).items()} for t, r in res.items()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
