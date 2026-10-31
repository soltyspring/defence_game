#!/usr/bin/env python3
"""06-art-ui: build the card_<unit> and skill frames from the CURRENT tools/art/ui.py without running build.py,
measure them with ui_audit.audit_frames, and write a preview sheet. Owner: 06-art-ui. No Godot.

Figures come from the committed character page (assets/atlases/char_player.png, frame <unit>/idle/0, untrimmed),
converted back to palette indices, i.e. the same arrays build.py passes to ui.portrait()/ui.card().

Usage: python tools/art/ui_art/card_preview.py [--out docs/art/evidence/ui_art/after_cards_x4.png] [--json out.json]
       [--criteria]
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
ROOT = os.path.abspath(os.path.join(ART, "..", ".."))
sys.path.insert(0, ART)
sys.path.insert(0, HERE)

import pixel  # noqa: E402
import ui  # noqa: E402
import ui_audit as A  # noqa: E402


def idle_frames():
    page = np.array(Image.open(os.path.join(ROOT, "assets", "atlases", "char_player.png")).convert("RGBA"))
    meta = json.load(open(os.path.join(ROOT, "assets", "atlases", "char_player.json"), encoding="utf-8"))
    lut = {tuple(int(v) for v in pixel.RGBA[i]): i for i in range(1, len(pixel.RGBA)) if pixel.RGBA[i][3] > 0}
    out = {}
    for u in A.CARDS:
        f = meta["frames"][u + "/idle/0"]
        px = page[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]]
        idx = np.zeros(px.shape[:2], np.uint8)
        for y in range(px.shape[0]):
            for x in range(px.shape[1]):
                if px[y, x, 3]:
                    idx[y, x] = lut[tuple(int(v) for v in px[y, x])]
        out[u] = idx
    return out


def rgba(cv) -> np.ndarray:
    return pixel.RGBA[cv.a].astype(np.uint8)


def sheet(card_px, skill_px, scale=4):
    """Row 1: cards on 04's card body (#694226; worker on its own body). Rows 2-3: deutan, protan simulation.
    Row 4: skill icons on the skill-button fill. Pixel-exact nearest scaling."""
    cell = 24 + 8
    names = list(card_px)
    w = cell * max(len(names), 3)
    rows = []
    for kind in ("normal", "deutan", "protan"):
        row = np.zeros((cell, w, 3), float)
        for i, u in enumerate(names):
            body = A.WORKER_BODY if u == "worker" else A.CARD_BODY
            row[:, i * cell:(i + 1) * cell] = body
            p = card_px[u].astype(float)
            a = p[..., 3:4] / 255.0
            row[4:28, i * cell + 4:i * cell + 28] = p[..., :3] * a + row[4:28, i * cell + 4:i * cell + 28] * (1 - a)
        if kind != "normal":
            flat = row.reshape(-1, 3)
            flat[:] = np.array([A.sim(c, kind) for c in flat])
        rows.append(row)
    srow = np.zeros((cell, w, 3), float)
    srow[:] = (0x2e, 0x3d, 0x6b)   # hud.gd skill button fill Color(0.18, 0.24, 0.42)
    for i, s in enumerate(skill_px):
        p = skill_px[s].astype(float)
        a = p[..., 3:4] / 255.0
        srow[4:28, i * cell + 4:i * cell + 28] = p[..., :3] * a + srow[4:28, i * cell + 4:i * cell + 28] * (1 - a)
    rows.append(srow)
    im = np.clip(np.concatenate(rows, 0), 0, 255).astype(np.uint8)
    return Image.fromarray(im).resize((im.shape[1] * scale, im.shape[0] * scale), Image.NEAREST)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--json", default="")
    ap.add_argument("--criteria", action="store_true")
    ap.add_argument("--from-atlas", default="", help="sheet/measure the frames of this ui_main base path instead "
                    "(e.g. a HEAD copy) - for the BEFORE sheet")
    a = ap.parse_args()
    if a.from_atlas:
        page = np.array(Image.open(a.from_atlas + ".png").convert("RGBA"))
        meta = json.load(open(a.from_atlas + ".json", encoding="utf-8"))
        card_px = {u: A.frame(page, meta, "card_" + u) for u in A.CARDS}
        skill_px = {s: A.frame(page, meta, "icon_" + s) for s in A.SKILLS}
    else:
        fr = idle_frames()
        card_px = {u: rgba(ui.card(u, fr[u])) for u in A.CARDS}
        skill_px = {"skill_slam": rgba(ui.skill_slam()), "skill_rally": rgba(ui.skill_rally()),
                    "skill_barrage": rgba(ui.skill_barrage())}
    res = A.audit_frames(card_px, skill_px)
    print(json.dumps(res, ensure_ascii=False, indent=1))
    if a.out:
        sheet(card_px, skill_px).save(a.out, optimize=True)
        print("wrote", a.out)
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    fails = A.criteria_fails(res) if a.criteria else []
    if a.criteria:
        print("CRITERIA", "PASS" if not fails else "FAIL (%d)" % len(fails))
        for f in fails:
            print("  FAIL", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
