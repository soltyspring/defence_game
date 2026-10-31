"""Character quality metrics on REAL captures (owner: 03-art).

    python tools/art/char_quality.py lineup <out.json> "<label>=<capture_dir_or_prefix>|<char_dir>" ...
    python tools/art/char_quality.py frames <out.json> "<label>=<char_dir>" ...

lineup: captures from tools/art/godot_check/lineup_cam.gd (walk pose t 0 and attack pose t 0.22, same frozen
lineup and camera, plus background frames). Units are cut from the real capture with masks rebuilt from the
imported atlas frame (the battle band of a 1280x720 capture is an exact 2x of the 640x360 frame, round 15) and
measured on the capture pixels downsampled by 2 (exact):
  feature_pct  share of the unit's interior pixels that differ from BOTH horizontal neighbours or BOTH vertical
               neighbours: 1-px details (eyes, seams, crust grain, spores). Flat fills and 2-px doubled blobs score 0.
  doubled_pct  share of rows+columns of the unit crop that repeat the previous row/column exactly
               (nearest-scaled parts; 0 for art drawn at its own resolution)
  colours      distinct colours in the unit crop
  motion_pct   (attack pose vs walk pose of the same unit at the same place) changed pixels / union of both masks
  reach_px     how far the unit's mask extends forward in the attack pose beyond the walk pose (art px)
  iou          pairwise silhouette IoU of same-side regular units (masks aligned at the feet / pivot)
frames: the same per-frame measures straight from an atlas (walk/attack/hit frames), for anims the lineup
cannot show (walk bob and stride, hit knock-back).
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_K = np.array([0x1b, 0x13, 0x25])
REGULAR_A = ["worker", "melee_basic", "ranged_basic", "tank", "fast"]
REGULAR_E = ["e_grunt", "e_swarm", "e_spitter", "e_bomber", "e_brute"]


def feature_pct(img, mask):
    """img HxWx3 uint, mask bool. Interior = mask pixels whose 4 neighbours are in the mask."""
    m = mask
    inner = m.copy()
    inner[1:, :] &= m[:-1, :]
    inner[:-1, :] &= m[1:, :]
    inner[:, 1:] &= m[:, :-1]
    inner[:, :-1] &= m[:, 1:]
    inner[0, :] = inner[-1, :] = False
    inner[:, 0] = inner[:, -1] = False
    key = (img[..., 0].astype(np.int64) << 16) | (img[..., 1].astype(np.int64) << 8) | img[..., 2].astype(np.int64)
    l, r = np.roll(key, 1, 1), np.roll(key, -1, 1)
    u, d = np.roll(key, 1, 0), np.roll(key, -1, 0)
    feat = ((key != l) & (key != r)) | ((key != u) & (key != d))
    n = int(inner.sum())
    return round(float((feat & inner).sum()) / max(1, n) * 100, 1), n


def doubled_pct(crop):
    rows = sum(int((crop[i] == crop[i - 1]).all()) for i in range(1, crop.shape[0]))
    cols = sum(int((crop[:, i] == crop[:, i - 1]).all()) for i in range(1, crop.shape[1]))
    return round((rows + cols) / max(1, crop.shape[0] + crop.shape[1] - 2) * 100, 1)


def atlas_frame(char_dir, page, name, man):
    d = json.load(open(os.path.join(char_dir if page == "char_player" else os.path.join(ROOT, "assets", "atlases"), f"{page}.json"), encoding="utf-8"))
    p = np.array(Image.open(os.path.join(char_dir if page == "char_player" else os.path.join(ROOT, "assets", "atlases"), f"{page}.png")).convert("RGBA"))
    f = d["frames"][name]
    return p[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]], f


def unit_cut(cap, rep, pose, u, char_dir):
    """Cut a unit from the 1x (downsampled) capture: returns (rgb crop, mask crop, feet-aligned box)."""
    x, y, w, h = (int(v) for v in u["rect"])
    mp = os.path.join(char_dir, "manifest.json")
    man = json.load(open(mp if os.path.exists(mp) else os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    pid = man["anim_sets"].get(u["anim_set"], "char_player")
    d0 = char_dir if os.path.exists(os.path.join(char_dir, f"{pid}.png")) else os.path.join(ROOT, "assets", "atlases")
    pg = np.array(Image.open(os.path.join(d0, f"{pid}.png")).convert("RGBA"))
    a = pg[y:y + h, x:x + w, 3] > 0
    if u["flip"]:
        a = a[:, ::-1]
        x0 = round(u["x"]) - (w - u["pivot"][0])
    else:
        x0 = round(u["x"]) - u["pivot"][0]
    left = rep["poses"][pose]["cam_x"] - rep["view_w"] / 2
    y0 = round(rep["ground_y"] + u["lane_y"]) - u["pivot"][1]
    sx, sy = int(round(x0 - left)), int(round(y0 - rep["poses"][pose]["view_top"]))
    H, W = cap.shape[:2]
    m = np.zeros((h, w), bool)
    c = np.zeros((h, w, 3), np.uint8)
    ys, xs = np.nonzero(a)
    for j, i in zip(ys, xs):
        X, Y = sx + i, sy + j
        if 0 <= X < W and 0 <= Y < H:
            m[j, i] = True
            c[j, i] = cap[Y, X]
    return c, m


def lineup(out, items):
    res = {}
    for it in items:
        label, rest = it.split("=", 1)
        prefix, char_dir = rest.split("|")
        rep = json.load(open(prefix + "_lineup_report.json", encoding="utf-8-sig"))
        caps = {p: np.array(Image.open(prefix + f"_{p}_full.png").convert("RGB"))[::2, ::2] for p in ("walk", "attack")}
        rows = {}
        for pose in ("walk", "attack"):
            for ui, u in enumerate(rep["poses"][pose]["units"]):
                if "rect" not in u or u["anim_set"] in ("e_brute",):   # e_brute page not resident in r01 (placeholder)
                    continue
                c, m = unit_cut(caps[pose], rep, pose, u, char_dir)
                key = f"{u['anim_set']}#{ui}"
                ys, xs = np.nonzero(m)
                crop = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1] if len(ys) else c
                fp, n = feature_pct(c, m)
                r = rows.setdefault(key, {"set": u["anim_set"], "side": u["side"]})
                r[pose] = {"feature_pct": fp, "interior_px": n, "doubled_pct": doubled_pct(crop),
                           "colours": len({tuple(v) for v in c[m].tolist()}), "mask": m, "front": int(xs.max()) if len(xs) else 0,
                           "body_px": int(ys.max() - ys.min() + 1) if len(ys) else 0}
        for k, r in rows.items():
            if "walk" in r and "attack" in r:
                a, b = r["walk"]["mask"], r["attack"]["mask"]
                if a.shape == b.shape:
                    r["motion_pct"] = round(float((a ^ b).sum()) / max(1, int((a | b).sum())) * 100, 1)
                fwd = (r["attack"]["front"] - r["walk"]["front"]) * (1 if r["side"] > 0 else -1)
                r["reach_px"] = int(fwd)
        # pairwise IoU of same-side regular units, walk pose, aligned at the bottom-centre of the mask
        def norm(m):
            ys, xs = np.nonzero(m)
            cx = (xs.min() + xs.max()) // 2
            out = np.zeros((96, 96), bool)
            for j, i in zip(ys, xs):
                Y, X = 95 - (ys.max() - j), 48 + (i - cx)
                if 0 <= X < 96 and 0 <= Y < 96:
                    out[Y, X] = True
            return out
        seen = {}
        for k, r in rows.items():
            if "walk" in r and r["set"] not in seen:
                seen[r["set"]] = (r["side"], norm(r["walk"]["mask"]))
        iou = {}
        sets = sorted(seen)
        for i, a in enumerate(sets):
            for b in sets[i + 1:]:
                if seen[a][0] == seen[b][0]:
                    A, B = seen[a][1], seen[b][1]
                    iou[f"{a}~{b}"] = round(float((A & B).sum()) / max(1, int((A | B).sum())), 2)
        for r in rows.values():
            for p in ("walk", "attack"):
                if p in r:
                    r[p].pop("mask"); r[p].pop("front")
        res[label] = {"units": rows, "iou_same_side": iou}
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1)
        f.write("\n")
    for label, r in res.items():
        print("==", label, "IoU", r["iou_same_side"])
        for k, u in r["units"].items():
            w, a = u.get("walk", {}), u.get("attack", {})
            print(f"  {k:20s} body {w.get('body_px')} feat {w.get('feature_pct')} dbl {w.get('doubled_pct')} col {w.get('colours')} | motion {u.get('motion_pct')} reach {u.get('reach_px')}")


def frames(out, items):
    res = {}
    man = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    for it in items:
        label, char_dir = it.split("=", 1)
        d = json.load(open(os.path.join(char_dir, "char_player.json"), encoding="utf-8"))
        p = np.array(Image.open(os.path.join(char_dir, "char_player.png")).convert("RGBA"))
        r = {}
        for sid in REGULAR_A + REGULAR_E + ["hero_captain"]:
            an = d["anims"].get(sid)
            if not an:
                continue
            def fr(name):
                f = d["frames"][name]
                return p[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]]
            def stat(names):
                ms = [fr(n)[..., 3] > 0 for n in names]
                tops = [np.nonzero(m.any(1))[0].min() for m in ms]
                fronts = [np.nonzero(m.any(0))[0].max() for m in ms]
                ch = [float((ms[i] ^ ms[i - 1]).sum()) / max(1, int((ms[i] | ms[i - 1]).sum())) * 100 for i in range(1, len(ms))]
                return {"bob_px": int(max(tops) - min(tops)), "front_range_px": int(max(fronts) - min(fronts)),
                        "mean_change_pct": round(float(np.mean(ch)) if ch else 0.0, 1),
                        "max_change_pct": round(float(max(ch)) if ch else 0.0, 1)}
            idle0 = fr(an["idle"]["frames"][0])
            ys, xs = np.nonzero(idle0[..., 3] > 0)
            crop = idle0[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            m = crop[..., 3] > 0
            fp, n = feature_pct(crop[..., :3], m)
            r[sid] = {"body_px": int(ys.max() - ys.min() + 1), "feature_pct": fp, "doubled_pct": doubled_pct(crop),
                      "colours": len({tuple(v) for v in crop[m][:, :3].tolist()}),
                      "walk": stat(an["walk"]["frames"]),
                      "attack": stat(an["attack"]["frames"]) if "attack" in an else stat(an.get("work", an["walk"])["frames"]),
                      "hit": stat([an["idle"]["frames"][0]] + an["hit"]["frames"]) if "hit" in an else None,
                      "death": stat([an["idle"]["frames"][0]] + an["death"]["frames"][:3]) if "death" in an else None}
            r[sid]["_walk0"] = fr(an["walk"]["frames"][0])[..., 3] > 0
        # same-side IoU on walk frame 0 (bottom-centre aligned, as in lineup mode)
        def norm(m):
            ys, xs = np.nonzero(m)
            cx = (xs.min() + xs.max()) // 2
            o = np.zeros((128, 128), bool)
            Y, X = 127 - (ys.max() - ys), 64 + (xs - cx)
            ok = (X >= 0) & (X < 128) & (Y >= 0)
            o[Y[ok], X[ok]] = True
            return o
        iou = {}
        for side in (REGULAR_A, REGULAR_E):
            ss = [s for s in side if s in r]
            for i, a in enumerate(ss):
                for b in ss[i + 1:]:
                    A, B = norm(r[a]["_walk0"]), norm(r[b]["_walk0"])
                    iou[f"{a}~{b}"] = round(float((A & B).sum()) / max(1, int((A | B).sum())), 2)
        for v in r.values():
            v.pop("_walk0")
        r["_iou"] = iou
        res[label] = r
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1)
        f.write("\n")
    for label, r in res.items():
        print("==", label)
        for sid, v in r.items():
            if sid == "_iou":
                print("  IoU", " ".join(f"{k} {x}" for k, x in v.items()))
                continue
            print(f"  {sid:13s} body {v['body_px']:3d} feat {v['feature_pct']:5.1f} dbl {v['doubled_pct']:5.1f} col {v['colours']:3d} | walk bob {v['walk']['bob_px']} chg {v['walk']['mean_change_pct']} | atk reach {v['attack']['front_range_px']} chg {v['attack']['max_change_pct']} | hit {v['hit'] and v['hit']['max_change_pct']} | death {v['death'] and v['death']['max_change_pct']}")


def battle(out, items):
    """r06 captures from size_cam.gd (zoom 1 only): per unit type, detail measures on the visible pixels."""
    import size_compare_metrics as SC
    res = {}
    for it in items:
        label, rest = it.split("=", 1)
        cap_dir, combo, char_dir = rest.split("|")
        J = json.load(open(os.path.join(cap_dir, f"size_cam_{combo}_units.json"), encoding="utf-8-sig"))
        full = np.array(Image.open(os.path.join(cap_dir, f"zoom_preview_{combo}.png")).convert("RGB"))
        assert J["zoom"] == 1.0
        one = full[::2, ::2]
        cache = {}
        r = {}
        for u in J["units"]:
            if u["dying"]:
                continue
            x, y, w, h = (int(round(v)) for v in u["rect"])
            al = SC.page(u["page"], char_dir, cache)[y:y + h, x:x + w, 3] > 0
            if u["flip"]:
                al = al[:, ::-1]
                ox = -(w - u["pivot"][0])
            else:
                ox = -u["pivot"][0]
            X0 = int(round(u["screen"][0] + ox - 0.5))     # registration -1 capture px = -0.5 view px (round 17)
            Y0 = int(round(u["screen"][1] - u["pivot"][1] - 0.5))
            H, W = one.shape[:2]
            if X0 < 0 or Y0 < 0 or X0 + w > W or Y0 + h > H:
                continue
            c = one[Y0:Y0 + h, X0:X0 + w].copy()
            m = al
            fp, n = feature_pct(c, m)
            ys, xs = np.nonzero(m)
            crop = np.where(m[..., None], c, 0)[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            r.setdefault(u["set"], []).append({"feature_pct": fp, "doubled_pct": doubled_pct(crop),
                                               "colours": len({tuple(v) for v in c[m].tolist()}), "body_px": int(ys.max() - ys.min() + 1)})
        res[label] = {k: {f: round(float(np.mean([x[f] for x in v])), 1) for f in v[0]} | {"n": len(v)} for k, v in r.items()}
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1)
        f.write("\n")
    for label, r in res.items():
        print("==", label)
        for k, v in r.items():
            print(f"  {k:13s} n{v['n']} body {v['body_px']} feat {v['feature_pct']} dbl {v['doubled_pct']} col {v['colours']}")


def sheet(out, items):
    """Evidence sheet from real captures (size_cam.gd, zoom 1): per unit set, the first live instance cut from
    the 1x capture (screen pixels, background kept), magnified x4 nearest. Columns = labelled captures."""
    import size_compare_metrics as SC
    from PIL import ImageDraw
    cols = []
    for it in items:
        label, rest = it.split("=", 1)
        cap_dir, combo, char_dir = rest.split("|")
        J = json.load(open(os.path.join(cap_dir, f"size_cam_{combo}_units.json"), encoding="utf-8-sig"))
        one = np.array(Image.open(os.path.join(cap_dir, f"zoom_preview_{combo}.png")).convert("RGB"))[::2, ::2]
        cache, got = {}, {}
        for u in sorted(J["units"], key=lambda u: u["screen"][0]):
            if u["dying"] or u["set"] in got:
                continue
            x, y, w, h = (int(round(v)) for v in u["rect"])
            ox = -(w - u["pivot"][0]) if u["flip"] else -u["pivot"][0]
            X0 = int(round(u["screen"][0] + ox - 0.5))
            Y0 = int(round(u["screen"][1] - u["pivot"][1] - 0.5))
            if X0 < 2 or Y0 < 2 or X0 + w + 2 > one.shape[1] or Y0 + h + 2 > one.shape[0]:
                continue
            got[u["set"]] = one[Y0 - 2:Y0 + h + 2, X0 - 2:X0 + w + 2]
        cols.append((label, got))
    sets = [s for s in REGULAR_A + REGULAR_E + ["hero_captain"] if any(s in g for _, g in cols)]
    Z = 3
    cw = Z * max(g[s].shape[1] for _, g in cols for s in g) + 6
    rh = Z * max(g[s].shape[0] for _, g in cols for s in g) + 6
    img = Image.new("RGB", (110 + cw * len(cols), 18 + rh * len(sets)), (40, 40, 48))
    dr = ImageDraw.Draw(img)
    for j, (label, _) in enumerate(cols):
        dr.text((110 + j * cw + 4, 3), label, fill=(255, 255, 255))
    for i, s in enumerate(sets):
        dr.text((4, 18 + i * rh + 4), s, fill=(255, 255, 255))
        for j, (_, got) in enumerate(cols):
            if s in got:
                t = Image.fromarray(got[s]).resize((got[s].shape[1] * Z, got[s].shape[0] * Z), Image.NEAREST)
                img.paste(t.crop((0, 0, min(cw - 4, t.width), min(rh - 4, t.height))), (110 + j * cw, 18 + i * rh))
    img.save(out)
    print("sheet", out, img.size, "sets", len(sets))


def anim07(out, items):
    """07's animation rules (docs/verification/ART_BASELINE.md §5: A1 A1c A5 A6 A6b) predicted for an atlas build WITHOUT
    Godot. Backgrounds come from 07's baseline contact sheets (anim_<uid>.png, row 0 column 0 = the real background
    crop of the 393 dp ko_1x capture). Each unit is placed at the pivot point found by registering the shipped walk
    frame 0 on the baseline's captured walk frame 0. Death frames get battle_view's fade
    (alpha = (0.7 - t) / 0.7 at t = (i + 0.5) / fps, as capture_art_baseline.gd does). Frames are written in 07's
    layers/anim layout, then 07's own tools/qa/art_metrics.anim_metrics() measures them, so the numbers use 07's code.
    items: "<label>=<char_dir>"; the first item must hold the character pixels 07's baseline captured (ad47eda; the
    char pages did not change between 253f2b6 and e8c6d96), because it is used for the registration."""
    import shutil
    import tempfile
    sys.path.insert(0, os.path.join(ROOT, "tools", "qa"))
    import art_metrics as AM
    base = os.path.join(ROOT, "docs", "verification", "evidence", "art-baseline-ad47eda")
    rep0 = json.load(open(os.path.join(base, "ko_1x_art_report.json"), encoding="utf-8-sig"))["anim"]

    def pages(d):
        man = json.load(open(os.path.join(d, "manifest.json") if os.path.exists(os.path.join(d, "manifest.json"))
                             else os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
        return man

    def frame(d, cache, sid, an, i):
        for pid in ("char_player", "char_boss_warlord", "char_boss_overlord"):
            if pid not in cache:
                jp = os.path.join(d, f"{pid}.json")
                if not os.path.exists(jp):
                    continue
                cache[pid] = (json.load(open(jp, encoding="utf-8")), np.array(Image.open(os.path.join(d, f"{pid}.png")).convert("RGBA")))
            j, p = cache[pid]
            if sid in j["anims"] and an in j["anims"][sid]:
                a = j["anims"][sid][an]
                f = j["frames"][a["frames"][i]]
                return p[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]], f, a
        return None, None, None

    def comp(bg, img, x0, y0, flip, alpha=1.0):
        o = bg.astype(np.float64).copy()
        im = img[:, ::-1] if flip else img
        H, W = bg.shape[:2]
        for yy in range(im.shape[0]):
            Y = y0 + yy
            if not 0 <= Y < H:
                continue
            for xx in range(im.shape[1]):
                X = x0 + xx
                if not 0 <= X < W or im[yy, xx, 3] == 0:
                    continue
                a = im[yy, xx, 3] / 255.0 * alpha
                o[Y, X] = im[yy, xx, :3] * a + o[Y, X] * (1 - a)
        return np.clip(np.rint(o), 0, 255).astype(np.uint8)

    ship_dir = items[0].split("=", 1)[1]
    sc = {}
    anchor = {}
    for uid, info in rep0.items():
        sheet = np.asarray(Image.open(os.path.join(base, "anim", f"anim_{uid}.png")).convert("RGB"))[::2, ::2]
        cw, ch = int(info["crop"][2]), int(info["crop"][3])
        rows = [an for an in ("idle", "walk", "attack", "hitflash", "death") if an in info["anims"] or an == "hitflash"]
        bg = sheet[0:ch, 0:cw]
        wr = rows.index("walk")
        cap0 = sheet[wr * ch:(wr + 1) * ch, cw:2 * cw]
        img, f, _ = frame(ship_dir, sc, uid, "walk", 0)
        flip = info["facing"] < 0
        best = None
        # search near the mask bbox, exact pixel check
        m = np.any(cap0 != bg, axis=-1)
        ys, xs = np.nonzero(m)
        am = img[..., 3] > 0
        am = am[:, ::-1] if flip else am
        ay, ax = np.nonzero(am)
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                y0 = ys.min() - ay.min() + dy
                x0 = xs.min() - ax.min() + dx
                c = comp(bg, img, x0, y0, flip)
                err = int(np.any(c != cap0, axis=-1).sum())
                if best is None or err < best[0]:
                    best = (err, x0, y0)
        piv = f.get("pivot") or [0, 0]
        anchor[uid] = (bg, best[1] + ((img.shape[1] - piv[0]) if flip else piv[0]), best[2] + piv[1], flip, best[0], info)
    res = {}
    for it in items:
        label, d = it.split("=", 1)
        fade = 0.7
        if "|fade=" in d:                  # what-if for 02: alpha = (0.7 - t) / fade (hold at 1 for 0.7 - fade s)
            d, fs = d.split("|fade=")
            fade = float(fs)
        cache = {}
        clipped = {}
        tmp = tempfile.mkdtemp(prefix="cq_anim07_")
        ad = os.path.join(tmp, "layers", "anim")
        os.makedirs(ad)
        rep = {}
        for uid, (bg, PX, PY, flip, err, info) in anchor.items():
            Image.fromarray(bg).save(os.path.join(ad, f"ko_1x_{uid}_bg.png"))
            anims = {}
            for an in ("idle", "walk", "attack", "death"):
                img, f, a = frame(d, cache, uid, an, 0)
                if img is None:
                    continue
                n = len(a["frames"])
                anims[an] = {"fps": float(a["fps"]), "frames": n, "loop": bool(a.get("loop", False))}
                for i in range(n):
                    img, f, _ = frame(d, cache, uid, an, i)
                    piv = f.get("pivot") or [0, 0]
                    x0 = PX - ((img.shape[1] - piv[0]) if flip else piv[0])
                    y0 = PY - piv[1]
                    ys_, xs_ = np.nonzero(img[..., 3])
                    if len(ys_) and (x0 + (img.shape[1] - 1 - xs_.min() if flip else xs_.max()) >= bg.shape[1] or
                                     x0 + (img.shape[1] - 1 - xs_.max() if flip else xs_.min()) < 0 or
                                     y0 + ys_.min() < 0 or y0 + ys_.max() >= bg.shape[0]):
                        clipped[uid] = clipped.get(uid, 0) + 1
                    al = 1.0
                    if an == "death":
                        al = min(1.0, max(0.0, (0.7 - (i + 0.5) / a["fps"]) / fade))
                    Image.fromarray(comp(bg, img, x0, y0, flip, al)).save(os.path.join(ad, f"ko_1x_{uid}_{an}_{i}.png"))
            rep[uid] = dict(info, anims=anims, bars={})
        m = AM.anim_metrics(tmp, "ko_1x", {"anim": rep}, 1.0)
        shutil.rmtree(tmp, ignore_errors=True)
        res[label] = {u: {k: v for k, v in r.items() if k in (
            "walk_change_max_pct", "walk_bob_px", "walk_edge_travel_px", "death_pose_change_pct",
            "death_readable_until_s", "death_readable_share_pct", "death_frames", "death_anim_s")} | {"reg_err_px": anchor[u][4],
                                                                                                    "frames_clipped": clipped.get(u, 0)}
            for u, r in m.items()}
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(res, fh, indent=1)
        fh.write("\n")
    for label, r in res.items():
        print("==", label)
        for u, v in r.items():
            mv = max(v.get("walk_bob_px") or 0, v.get("walk_edge_travel_px") or 0)
            print(f"  {u:13s} walk chg {v.get('walk_change_max_pct')} move {mv} | death chg {v.get('death_pose_change_pct')} "
                  f"readable {v.get('death_readable_until_s')} s ({v.get('death_readable_share_pct')} %) anim {v.get('death_anim_s')} s | reg {v['reg_err_px']}"
                  + (f" CLIPPED {v['frames_clipped']} frames" if v["frames_clipped"] else ""))


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    {"lineup": lineup, "frames": frames, "battle": battle, "sheet": sheet, "anim07": anim07}[sys.argv[1]](sys.argv[2], sys.argv[3:])
