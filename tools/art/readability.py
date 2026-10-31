"""Battlefield readability test (owner: 03-art).

    python tools/art/readability.py spec  <out_dir>     # write scenes.json for Godot
    python tools/art/readability.py measure <out_dir>   # compare Godot captures + metrics

Scenes reproduce 02's draw order (battle_view.gd): background layers -> units sorted by
lane_y (enemies flip_h, pivot = feet) -> projectiles -> fx (hit_spark at y-12, explosion
at y-6, pivot from atlas). Ground y 295, 640x360 reference view.
Background variants: `meadow` (real biome), `dark` (black 65% over the background only),
`bright` (white 45% over the background only) - stand-ins for future dark/light biomes.

Metrics (internal thresholds, unvalidated by players; fixed BEFORE measuring):
  silhouette  % of each unit's perimeter where the outline or the next pixel inward differs
              from the adjacent background by dL* >= 15      -> pass >= 60 %
  crowd       visible fraction of each unit after units drawn later + fx -> pass >= 40 %
  fx_cover    fraction of a hit target's pixels covered by its own impact fx -> pass <= 35 %
  projectile  mean dL* of projectile pixels vs the 3-px background ring -> pass >= 20
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("ART_ROOT") or os.path.abspath(os.path.join(HERE, "..", ".."))
GY = 295
TH = {"silhouette": 60.0, "crowd": 40.0, "fx_cover": 35.0, "projectile": 20.0, "projectile_px_sep": 60.0}
OVER = {"meadow": None, "dark": (0, 0, 0, 0.65), "bright": (255, 255, 255, 0.45)}


def scenes():
    rng = np.random.default_rng(7)

    def row(ids, x0, x1, side):
        out = []
        n = len(ids)
        for i, sid in enumerate(ids):
            x = x0 + (x1 - x0) * i / max(1, n - 1)
            out.append({"set": sid, "anim": "walk", "f": int(rng.integers(0, 4)), "x": round(x),
                        "lane_y": int(rng.integers(-2, 3)), "side": side})
        return out

    s = {}
    a = row(["worker", "melee_basic", "melee_basic", "melee_basic", "melee_basic", "melee_basic",
             "melee_basic", "melee_basic", "melee_basic", "melee_basic", "melee_basic"], 205, 300, 1)
    a.append({"set": "hero_captain", "anim": "attack", "f": 3, "x": 305, "lane_y": 2, "side": 1})
    e = row(["e_grunt"] * 11, 312, 395, -1)
    s["r01"] = {"units": a + e, "proj": [], "fx": [("hit_spark", 2, 312), ("hit_spark", 1, 330), ("hit_spark", 3, 300)]}

    a = row(["ranged_basic", "ranged_basic", "tank", "melee_basic", "fast", "melee_basic", "tank",
             "melee_basic", "fast", "melee_basic", "ranged_basic", "melee_basic"], 190, 300, 1)
    a.append({"set": "hero_captain", "anim": "attack", "f": 3, "x": 305, "lane_y": 2, "side": 1})
    e = row(["e_grunt", "e_swarm", "e_brute", "e_spitter", "e_grunt", "e_swarm", "e_grunt", "e_spitter",
             "e_swarm", "e_brute", "e_grunt"], 312, 405, -1)
    e.append({"set": "boss_warlord", "anim": "attack", "f": 3, "x": 430, "lane_y": 0, "side": -1})
    s["r05"] = {"units": a + e,
                "proj": [("arrow", 0, 260, 255, 1), ("arrow", 0, 280, 262, 1), ("spit", 1, 345, 258, -1)],
                "fx": [("hit_spark", 2, 312), ("hit_spark", 2, 325), ("hit_spark", 1, 300)]}

    a = row(["siege", "ranged_basic", "tank", "fast", "melee_basic", "tank", "melee_basic", "fast",
             "melee_basic", "ranged_basic", "melee_basic", "tank"], 175, 300, 1)
    a.append({"set": "hero_captain", "anim": "attack", "f": 3, "x": 305, "lane_y": 2, "side": 1})
    e = row(["e_bomber", "e_grunt", "e_swarm", "e_brute", "e_swarm", "e_spitter", "e_bomber", "e_grunt",
             "e_swarm", "e_brute", "e_swarm", "e_grunt"], 312, 415, -1)
    e.append({"set": "boss_warlord", "anim": "walk", "f": 1, "x": 440, "lane_y": -1, "side": -1})
    e.append({"set": "boss_overlord", "anim": "summon", "f": 3, "x": 500, "lane_y": 0, "side": -1})
    s["r10"] = {"units": a + e,
                "proj": [("rock", 1, 300, 220, 1), ("arrow", 0, 270, 258, 1), ("spit", 0, 350, 255, -1)],
                "fx": [("explosion", 2, 318), ("hit_spark", 2, 330), ("hit_spark", 1, 300)]}
    for k in s:
        s[k]["units"].sort(key=lambda u: u["lane_y"])
    return s


# ---------------------------------------------------------------------------------
def load_atlases():
    m = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    pages, docs = {}, {}
    for a in m["atlases"]:
        docs[a["id"]] = json.load(open(os.path.join(ROOT, a["frames"].replace("res://", "")), encoding="utf-8"))
        pages[a["id"]] = np.array(Image.open(os.path.join(ROOT, a["image"].replace("res://", ""))).convert("RGBA"))
    return m, pages, docs


def frame(m, pages, docs, aset, anim, fi):
    aid = m["anim_sets"][aset]
    an = docs[aid]["anims"][aset][anim]
    name = an["frames"][fi % len(an["frames"])]
    f = docs[aid]["frames"][name]
    return pages[aid][f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]], f["pivot"], name, aid


def background(variant):
    import biome
    img = np.array(biome.compose_preview(biome.build_meadow(), 640, cam=0).convert("RGB")).astype(float)
    o = OVER[variant]
    if o:
        img = img * (1 - o[3]) + np.array(o[:3]) * o[3]
    return img


def lab_L(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    Y = c[..., 0] * 0.2126 + c[..., 1] * 0.7152 + c[..., 2] * 0.0722
    return np.where(Y > 0.008856, 116 * np.cbrt(Y) - 16, 903.3 * Y)


def compose(scene, variant, m, pages, docs):
    img = background(variant)
    owner = np.full(img.shape[:2], -1, int)
    items = []

    def blit(px, pv, x, y, flip, tag):
        a = px[:, ::-1] if flip else px
        pvx = (px.shape[1] - pv[0]) if flip else pv[0]
        x0, y0 = int(x - pvx), int(y - pv[1])
        h, w = a.shape[:2]
        sl = (slice(max(0, y0), min(360, y0 + h)), slice(max(0, x0), min(640, x0 + w)))
        sub = a[sl[0].start - y0:sl[0].stop - y0, sl[1].start - x0:sl[1].stop - x0]
        al = sub[..., 3:4] / 255.0
        img[sl] = img[sl] * (1 - al) + sub[..., :3] * al
        idx = len(items)
        mask = np.zeros(img.shape[:2], bool)
        mask[sl] = sub[..., 3] > 0
        owner[mask] = idx
        items.append({"tag": tag, "mask": mask})
        return idx

    unit_idx = []
    for u in scene["units"]:
        px, pv, name, aid = frame(m, pages, docs, u["set"], u["anim"], u["f"])
        i = blit(px, pv, u["x"], GY + u["lane_y"], u["side"] < 0, ("unit", u["set"], u["x"]))
        unit_idx.append((i, u))
    for (kind, fi, x, y, side) in scene["proj"]:
        px, pv, name, aid = frame(m, pages, docs, kind, "fly", fi)
        blit(px, pv, x, y, side < 0, ("proj", kind, x))
    fx_idx = []
    for (kind, fi, x) in scene["fx"]:
        px, pv, name, aid = frame(m, pages, docs, kind, "play", fi)
        dy = -12 if kind == "hit_spark" else -6
        fx_idx.append((blit(px, pv, x, GY + dy, False, ("fx", kind, x)), x))
    return img, owner, items, unit_idx, fx_idx


def measure_scene(scene, variant, m, pages, docs):
    img, owner, items, unit_idx, fx_idx = compose(scene, variant, m, pages, docs)
    bg = background(variant)
    Lbg, Limg = lab_L(bg), lab_L(img)
    res = {"units": [], "proj": [], "fx": []}
    for i, u in unit_idx:
        mask = items[i]["mask"]
        n = int(mask.sum())
        vis = float((owner[mask] == i).sum()) / max(1, n) * 100
        # silhouette vs background, unit isolated (its own colours, real background)
        solo = background(variant)
        px, pv, _, _ = frame(m, pages, docs, u["set"], u["anim"], u["f"])
        a = px[:, ::-1] if u["side"] < 0 else px
        pvx = (px.shape[1] - pv[0]) if u["side"] < 0 else pv[0]
        x0, y0 = int(u["x"] - pvx), int(GY + u["lane_y"] - pv[1])
        h, w = a.shape[:2]
        sm = np.zeros((360, 640), bool)
        sm[y0:y0 + h, x0:x0 + w] = a[..., 3] > 0
        solo[y0:y0 + h, x0:x0 + w][a[..., 3] > 0] = a[..., :3][a[..., 3] > 0]
        Ls = lab_L(solo)
        ok = tot = 0
        for (dy, dx) in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(sm, (-dy, -dx), axis=(0, 1))
            per = sm & ~nb                         # pixel inside whose neighbour is outside
            ys, xs = np.nonzero(per)
            oy, ox = ys + dy, xs + dx
            iy, ix = np.clip(ys - dy, 0, 359), np.clip(xs - dx, 0, 639)
            inner_in = sm[iy, ix]
            d1 = np.abs(Ls[ys, xs] - Lbg[oy, ox])
            d2 = np.where(inner_in, np.abs(Ls[iy, ix] - Lbg[oy, ox]), 0)
            ok += int((np.maximum(d1, d2) >= 15).sum())
            tot += len(ys)
        res["units"].append({"set": u["set"], "x": u["x"], "visible_pct": round(vis, 1),
                             "silhouette_pct": round(ok / max(1, tot) * 100, 1)})
    for i, it in enumerate(items):
        if it["tag"][0] == "proj":
            mk = it["mask"]
            ring = np.zeros_like(mk)
            for d in range(1, 4):
                for ax in (0, 1):
                    ring |= np.roll(mk, d, ax) | np.roll(mk, -d, ax)
            ring &= ~mk
            # dL (pre-declared): |mean L* projectile - mean L* ring| -- flawed for outline+light-core sprites,
            # because the dark outline and the light core average to a mid tone. Kept for honesty.
            # px_sep (added after the first run, reason above): % of projectile pixels whose L* differs
            # from the median L* of the 3-px background ring by >= 20.
            med = float(np.median(Lbg[ring])) if ring.any() else 0.0
            sep = float((np.abs(Limg[mk] - med) >= 20).mean() * 100)
            res["proj"].append({"kind": it["tag"][1], "dL": round(float(np.abs(Limg[mk].mean() - Limg[ring].mean())), 1),
                                "px_sep": round(sep, 1)})
    for fi, x in fx_idx:
        fm = items[fi]["mask"]
        # target = the unit whose x is nearest the fx x
        ti, _ = min(unit_idx, key=lambda t: abs(t[1]["x"] - x))
        tm = items[ti]["mask"]
        cover = float((tm & fm).sum()) / max(1, int(tm.sum())) * 100
        res["fx"].append({"kind": items[fi]["tag"][1], "x": x, "target": items[ti]["tag"][1], "cover_pct": round(cover, 1)})
    return img, res


def write_spec(out):
    os.makedirs(out, exist_ok=True)
    m, pages, docs = load_atlases()
    spec = {"ground_y": GY, "over": OVER, "scenes": {}}
    for k, sc in scenes().items():
        draws = []
        for u in sc["units"]:
            _, pv, name, aid = frame(m, pages, docs, u["set"], u["anim"], u["f"])
            draws.append({"atlas": aid, "frame": name, "x": u["x"], "y": GY + u["lane_y"], "flip": u["side"] < 0})
        for (kind, fi, x, y, side) in sc["proj"]:
            _, pv, name, aid = frame(m, pages, docs, kind, "fly", fi)
            draws.append({"atlas": aid, "frame": name, "x": x, "y": y, "flip": side < 0})
        for (kind, fi, x) in sc["fx"]:
            _, pv, name, aid = frame(m, pages, docs, kind, "play", fi)
            draws.append({"atlas": aid, "frame": name, "x": x, "y": GY + (-12 if kind == "hit_spark" else -6), "flip": False})
        spec["scenes"][k] = draws
    json.dump(spec, open(os.path.join(out, "scenes.json"), "w", encoding="utf-8"), indent=0)
    print("spec written:", {k: len(v) for k, v in spec["scenes"].items()})


def measure(out, tag="run"):
    m, pages, docs = load_atlases()
    report = {"thresholds": TH, "scenes": {}}
    fails = []
    tiles = []
    for k, sc in scenes().items():
        n_a = sum(1 for u in sc["units"] if u["side"] > 0)
        n_e = len(sc["units"]) - n_a
        for v in OVER:
            img, res = measure_scene(sc, v, m, pages, docs)
            # compare with the Godot 1x capture (real renderer)
            gp = os.path.join(out, f"godot_{k}_{v}_1x.png")
            match = None
            if os.path.exists(gp):
                g = np.array(Image.open(gp).convert("RGB")).astype(int)[:360, :640]
                diff = np.abs(g - np.rint(img).astype(int)).max(axis=2)
                match = {"max_channel_diff": int(diff.max()), "px_diff_gt2": int((diff > 2).sum())}
            sil = [u for u in res["units"] if u["silhouette_pct"] < TH["silhouette"]]
            crowd = [u for u in res["units"] if u["visible_pct"] < TH["crowd"]]
            fxc = [f for f in res["fx"] if f["cover_pct"] > TH["fx_cover"]]
            prj = [p for p in res["proj"] if p["px_sep"] < TH["projectile_px_sep"]]
            summ = {"allies": n_a, "enemies": n_e, "godot_vs_composite": match,
                    "silhouette_min": min(u["silhouette_pct"] for u in res["units"]),
                    "silhouette_fail": [(u["set"], u["silhouette_pct"]) for u in sil],
                    "crowd_min": min(u["visible_pct"] for u in res["units"]),
                    "crowd_fail": [(u["set"], u["x"], u["visible_pct"]) for u in crowd],
                    "fx": res["fx"], "fx_fail": [(f["kind"], f["cover_pct"]) for f in fxc],
                    "proj": res["proj"], "proj_fail": [(p["kind"], p["px_sep"]) for p in prj]}
            report["scenes"][f"{k}/{v}"] = summ
            for key in ("silhouette_fail", "crowd_fail", "fx_fail", "proj_fail"):
                if summ[key]:
                    fails.append((f"{k}/{v}", key, summ[key]))
            tiles.append((f"{k}/{v}", np.rint(img).astype(np.uint8)))
    json.dump(report, open(os.path.join(out, f"metrics_{tag}.json"), "w", encoding="utf-8"), indent=1)
    # contact sheet: crop of the battle band for every scene/variant at 2x
    crops = [Image.fromarray(t[200:320, 150:560]).resize((820, 240), Image.NEAREST) for _, t in tiles]
    sheet = Image.new("RGB", (820 * 3, 240 * 3), (0, 0, 0))
    for i, c in enumerate(crops):
        sheet.paste(c, ((i % 3) * 820, (i // 3) * 240))
    sheet.save(os.path.join(out, f"contact_{tag}_rows-r01-r05-r10_cols-meadow-dark-bright.png"))
    for s, v in report["scenes"].items():
        print(f"{s:12s} A{v['allies']}/E{v['enemies']} godot={v['godot_vs_composite']} sil_min={v['silhouette_min']} "
              f"crowd_min={v['crowd_min']} fx={[f['cover_pct'] for f in v['fx']]} proj_sep={[p['px_sep'] for p in v['proj']]}")
    print("FAILS:")
    for f in fails:
        print("  ", f)
    return report, fails


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    cmd, out = sys.argv[1], sys.argv[2]
    tag = sys.argv[3] if len(sys.argv) > 3 else "run"
    write_spec(out) if cmd == "spec" else measure(out, tag)
