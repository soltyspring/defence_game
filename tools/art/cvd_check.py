"""Faction colour separation under colour-vision deficiency (owner: 03-art).

    python tools/art/cvd_check.py [out.json]

Two measurements, both from the written atlas pages:
 1. 07's proxy (QA-B011): mean colour of opaque pixels of each anim set's walk/0 frame;
    Machado 2009 full-severity protan/deutan/tritan; CIE dE76 of the CLOSEST ally/enemy pair.
    07 pass line: dE >= 2.3 (one JND).
 2. 03 mass test (D14 acceptance: hue AND luminance step): for every ally/enemy pair, the
    share of pixel MASS within dE76 < 10 of the other faction's pixels (simulated), and the
    faction mean L* difference. Internal lines (fixed before measuring, unvalidated):
    confusable mass <= 10 %, |dL*| ally-enemy >= 10.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MACHADO = {
    "normal": np.eye(3),
    "protan": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    "deutan": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "tritan": np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}
ALLY = ["worker", "melee_basic", "ranged_basic", "tank", "fast", "siege", "hero_captain"]
ENEMY = ["e_grunt", "e_swarm", "e_spitter", "e_brute", "e_bomber", "boss_warlord", "boss_overlord"]


def lab(rgb):
    c = np.clip(rgb, 0, 255) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ M.T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def sim(rgb, mode):
    """Machado matrices apply to linear RGB."""
    c = np.clip(rgb, 0, 255) / 255.0
    lin = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    out = np.clip(lin @ MACHADO[mode].T, 0, 1)
    srgb = np.where(out > 0.0031308, 1.055 * out ** (1 / 2.4) - 0.055, out * 12.92)
    return srgb * 255


def pixels(m, docs, pages, sid, anim="walk", fi=0):
    aid = m["anim_sets"][sid]
    an = docs[aid]["anims"][sid].get(anim) or docs[aid]["anims"][sid]["idle"]
    f = docs[aid]["frames"][an["frames"][fi]]
    reg = pages[aid][f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]]
    a = reg[..., 3] > 0
    rgb = reg[..., :3][a].astype(float)
    # drop the outline colour (shared by both factions, carries no faction information)
    keep = ~np.all(rgb == [0x1b, 0x13, 0x25], axis=1)
    return rgb[keep]


def main(out=None):
    m = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    docs, pages = {}, {}
    for a in m["atlases"]:
        docs[a["id"]] = json.load(open(os.path.join(ROOT, a["frames"].replace("res://", "")), encoding="utf-8"))
        pages[a["id"]] = np.array(Image.open(os.path.join(ROOT, a["image"].replace("res://", ""))).convert("RGBA"))
    px = {s: pixels(m, docs, pages, s) for s in ALLY + ENEMY}
    rep = {"proxy_07": {}, "mass_03": {}}
    for mode in MACHADO:
        means = {s: lab(sim(px[s].mean(0, keepdims=True), mode))[0] for s in px}
        best = min(((np.linalg.norm(means[a] - means[e]), a, e) for a in ALLY for e in ENEMY))
        rep["proxy_07"][mode] = {"closest_pair": [best[1], best[2]], "dE76": round(float(best[0]), 2),
                                 "pass_ge_2.3": bool(best[0] >= 2.3)}
        # mass test
        A = lab(sim(np.concatenate([px[s] for s in ALLY]), mode))
        E = lab(sim(np.concatenate([px[s] for s in ENEMY]), mode))
        ua, ia = np.unique(np.round(A, 1), axis=0, return_counts=True)
        ue, ie = np.unique(np.round(E, 1), axis=0, return_counts=True)
        d = np.linalg.norm(ua[:, None, :] - ue[None, :, :], axis=2)
        near = d < 10
        # revised after run 1 (documented in ART_AUDIT A25): a colour counts as confusable only if the
        # OTHER faction has >= 1 % of its mass near it; otherwise 5-px accents (bomber fuse) flagged
        # whole 385-px crust ramps. The unweighted value is kept as *_any_pct.
        e_share_near = (near * ie[None, :]).sum(1) / ie.sum()
        a_share_near = (near * ia[:, None]).sum(0) / ia.sum()
        conf_a = float(ia[e_share_near >= 0.01].sum() / ia.sum() * 100)
        conf_e = float(ie[a_share_near >= 0.01].sum() / ie.sum() * 100)
        any_a = float(ia[near.any(1)].sum() / ia.sum() * 100)
        any_e = float(ie[near.any(0)].sum() / ie.sum() * 100)
        dL = float(A[:, 0].mean() - E[:, 0].mean())
        rep["mass_03"][mode] = {"ally_mass_confusable_pct": round(conf_a, 1), "enemy_mass_confusable_pct": round(conf_e, 1),
                                "ally_any_pct": round(any_a, 1), "enemy_any_pct": round(any_e, 1),
                                "mean_L_ally": round(float(A[:, 0].mean()), 1), "mean_L_enemy": round(float(E[:, 0].mean()), 1),
                                "dL_ally_minus_enemy": round(dL, 1),
                                "pass": bool(conf_a <= 10 and conf_e <= 10 and abs(dL) >= 10)}
    for mode in MACHADO:
        p, q = rep["proxy_07"][mode], rep["mass_03"][mode]
        print(f"{mode:7s} 07-proxy closest {p['closest_pair']} dE={p['dE76']:6.2f} {'PASS' if p['pass_ge_2.3'] else 'FAIL'} | "
              f"mass confusable ally {q['ally_mass_confusable_pct']:5.1f}% enemy {q['enemy_mass_confusable_pct']:5.1f}% "
              f"dL*={q['dL_ally_minus_enemy']:+5.1f} {'PASS' if q['pass'] else 'FAIL'}")
    if out:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        json.dump(rep, open(out, "w", encoding="utf-8"), indent=1)
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
