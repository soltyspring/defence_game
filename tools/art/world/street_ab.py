"""09-art-world: street colour A/B (biome.STREET_*) on world_preview composites.
python tools/art/world/street_ab.py STREET_SHADOW,STREET_LIGHT [out_dir]
C4 = 07 art_compare formula (whole unit incl. outline vs background under it), every walk frame at x 200/300/420."""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); sys.path.insert(0, os.path.dirname(HERE))
import numpy as np, contextlib, io
import biome, bases, world_metrics as wm, world_preview as wp
from cvd_check import lab
R = wm.load_root(wm.ROOT); gy = int(R["gy"])
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.environ.get("TEMP", "."), "a09", "street_ab"); os.makedirs(out, exist_ok=True)
SETS = [(1, s) for s in wp.ALLY] + [(-1, s) for s in wp.ENEMY]
res = {}
for name in sys.argv[1].split(","):
    biome.STREET = getattr(biome, name)
    with contextlib.redirect_stdout(io.StringIO()):
        rep = wp.run(os.path.join(out, name), "new", 320.0, "intact")
    lay = wp.layers_from("new")
    bg, _ = wm.compose_bg(R, 320.0, 640, 360, front=False, layers=lay)
    kp = wp.base_rgba("new", "player", "intact"); img = bg.copy(); wm._alpha_over(img, kp, 12, gy - 127)
    c4 = {}
    for side, s in SETS:
        fr, _ = wm.anim_frames(R, s, "walk")
        v = []
        for fi in range(len(fr)):
            px, f = fr[fi]
            for x in (200, 300, 420):                       # open street at three places
                a, ax, ay = wm.place(px, f["pivot"], x, gy, side < 0)
                m = wm.stamp_mask(img.shape[:2], a, ax, ay); comp = img.copy(); wm._alpha_over(comp, a, ax, ay)
                v.append(abs(lab(comp)[m][:, 0].mean() - lab(img)[m][:, 0].mean()))
        c4[s] = round(float(min(v)), 1)
    front = {}
    for s, x in (("hero_captain", 60), ("melee_basic", 70), ("worker", 52), ("ranged_basic", 80), ("tank", 44)):
        fr, _ = wm.anim_frames(R, s, "walk"); px, f = fr[0]
        a, ax, ay = wm.place(px, f["pivot"], x, gy, False)
        m = wm.stamp_mask(img.shape[:2], a, ax, ay); comp = img.copy(); wm._alpha_over(comp, a, ax, ay)
        front[s] = round(float(abs(lab(comp)[m][:, 0].mean() - lab(img)[m][:, 0].mean())), 1)
    b = rep["bands"]
    res[name] = {"c4_min": min(c4.values()), "c4_lt15": [s for s, v in c4.items() if v < 15], "c4_median": float(np.median(list(c4.values()))),
                 "c4": c4, "keep_front_c4_min": min(front.values()), "keep_front": front,
                 "keep_ring_dE": rep["bases"]["player"]["ring_dE"], "nest_ring_dE": rep["bases"]["enemy"]["ring_dE"],
                 "ring_ally_min": (rep["ally_min_ring_dL"], rep["ally_min_ring_dE"]), "ring_enemy_min": (rep["enemy_min_ring_dL"], rep["enemy_min_ring_dE"]),
                 "head_band": b["head_band"], "lane": b["lane"], "far": b["far"]}
    r = res[name]
    print(name, "| C4 min", r["c4_min"], "median", round(r["c4_median"], 1), "lt15", r["c4_lt15"], "| keep-front C4 min", r["keep_front_c4_min"],
          "| keep ring dE", r["keep_ring_dE"], "nest ring dE", r["nest_ring_dE"], "| P1 ring ally", r["ring_ally_min"], "enemy", r["ring_enemy_min"])
    print("   head", b["head_band"]); print("   lane", b["lane"])
json.dump(res, open(os.path.join(out, "street_ab.json"), "w"), indent=1, default=float)
