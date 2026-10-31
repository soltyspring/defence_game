#!/usr/bin/env python3
"""06-art-ui: HUD chrome frame sheet (ui-art 1.1) without Godot. Owner: 06-art-ui.

Draws every chrome frame stretched to the sizes 04's HUD uses at the 393 dp view (800x360 logical) with a
NinePatchRect-like STRETCH (corners copied, edges and centre stretched by nearest neighbour), before (ui-art 1.0)
and after, on the dirt colour of the r08 baseline frame. Also checks that every frame is stretch-safe:
each edge strip is uniform along its stretch axis and the centre is one colour.

Usage: python tools/art/ui_art/chrome_preview.py [--out docs/art/evidence/ui_art/chrome_sheet_x3.png] [--json out.json]
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
sys.path.insert(0, ART)
sys.path.insert(0, HERE)

import pixel  # noqa: E402
import ui  # noqa: E402
import ui_audit as A  # noqa: E402

DIRT = (0x9f, 0x6d, 0x42)          # measured ground strip (ui_audit.audit_hud)
SIZES = {"card_frame": (50, 56), "card_frame_disabled": (50, 56), "card_frame_selected": (50, 56),
         "btn": (52, 52), "btn_pressed": (52, 52), "btn_disabled": (52, 52), "btn_gold": (80, 28),
         "panel_dark": (380, 120), "ribbon_victory": (160, 16), "ribbon_defeat": (160, 16),
         "hud_tray": (80, 56), "btn_skill": (48, 48), "chip_resource": (72, 18)}
# drawn directly over the battlefield (edge vs dirt >= 3:1 applies); the rest sits on panels or the result dim
ON_FIELD = {"card_frame", "card_frame_disabled", "card_frame_selected", "btn", "btn_pressed", "btn_disabled",
            "hud_tray", "btn_skill", "chip_resource", "btn_round"}


def rgba(cv) -> np.ndarray:
    return pixel.RGBA[cv.a].astype(np.uint8)


def nine_draw(px: np.ndarray, m, w: int, h: int) -> np.ndarray:
    """px: RGBA source, m: (left, top, right, bottom). Corners copied, edges/centre nearest-stretched."""
    l, t, r, b = m
    sh, sw = px.shape[:2]
    xs = np.concatenate([np.arange(l), l + (np.arange(w - l - r) * (sw - l - r) // max(1, w - l - r)),
                         np.arange(sw - r, sw)])
    ys = np.concatenate([np.arange(t), t + (np.arange(h - t - b) * (sh - t - b) // max(1, h - t - b)),
                         np.arange(sh - b, sh)])
    return px[ys][:, xs]


def stretch_safe(px: np.ndarray, m, axis: str = "xy") -> dict:
    """axis 'x': drawn at the source height (ribbons), so only horizontal stretching has to be safe."""
    l, t, r, b = m
    sh, sw = px.shape[:2]
    top = px[:t, l:sw - r]; bot = px[sh - b:, l:sw - r]
    lef = px[t:sh - b, :l]; rig = px[t:sh - b, sw - r:]
    cen = px[t:sh - b, l:sw - r]
    def uni_x(a):
        return bool(a.size == 0 or np.all(a == a[:, :1]))
    def uni_y(a):
        return bool(a.size == 0 or np.all(a == a[:1, :]))
    out = {"top": uni_x(top), "bottom": uni_x(bot), "corners_fit": bool(l + r <= sw and t + b <= sh)}
    if axis == "x":
        out["centre_uniform_x"] = uni_x(cen)
    else:
        out.update({"left": uni_y(lef), "right": uni_y(rig), "centre_flat": bool(cen.size == 0 or np.all(cen == cen[:1, :1]))})
    return out


def edge_vs_dirt(px: np.ndarray) -> float:
    """WCAG of the mean colour of the outer 2 opaque rings against the dirt (the HUD-vs-ground line, >= 3:1)."""
    a = px[..., 3] > 0
    core = A._erode(A._erode(a))
    ring = a & ~core
    return round(A.wcag(px[ring][:, :3].mean(axis=0), DIRT), 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    new = ui.frames9()
    new.update(ui.chrome_proposed())
    old = ui._frames9_v10()
    rep = {}
    rows = []
    for name, (w, h) in SIZES.items():
        cv, m = new[name]
        px = rgba(cv)
        drawn = nine_draw(px, m, w, h)
        safe = stretch_safe(px, m, "x" if name.startswith("ribbon_") else "xy")
        rep[name] = {"source": [cv.w, cv.h], "margins": list(m), "drawn": [w, h], "stretch_safe": all(safe.values()),
                     "stretch_axis": "x" if name.startswith("ribbon_") else "xy", "on_battlefield": name in ON_FIELD,
                     "detail": safe, "edge_vs_dirt": edge_vs_dirt(drawn), "proposed_new_name": name in ui.CHROME_PROPOSED}
        pair = [drawn]
        if name in old:
            ocv, om = old[name]
            od = nine_draw(rgba(ocv), om, w, h)
            rep[name]["edge_vs_dirt_before"] = edge_vs_dirt(od)
            pair.insert(0, od)
        rows.append(pair)
    br = rgba(ui.btn_round(24))
    rep["btn_round"] = {"source": [24, 24], "fixed_size": True, "edge_vs_dirt": edge_vs_dirt(br), "proposed_new_name": True,
                        "icon_pause_on_body_wcag": round(A.wcag((0xf2, 0xf6, 0xf8), (0x3d, 0x25, 0x19)), 2)}
    rows.append([br])
    print(json.dumps(rep, indent=1))
    if a.out:
        W = max(sum(p.shape[1] + 6 for p in r) for r in rows) + 6
        H = sum(max(p.shape[0] for p in r) + 6 for r in rows) + 6
        sheet = np.zeros((H, W, 3), float)
        sheet[:] = DIRT
        y = 6
        for r in rows:
            x = 6
            for p in r:
                al = p[..., 3:4] / 255.0
                reg = sheet[y:y + p.shape[0], x:x + p.shape[1]]
                sheet[y:y + p.shape[0], x:x + p.shape[1]] = p[..., :3] * al + reg * (1 - al)
                x += p.shape[1] + 6
            y += max(p.shape[0] for p in r) + 6
        im = Image.fromarray(np.clip(sheet, 0, 255).astype(np.uint8))
        im.resize((W * 3, H * 3), Image.NEAREST).save(a.out, optimize=True)
        print("wrote", a.out)
    if a.json:
        json.dump(rep, open(a.json, "w", encoding="utf-8"), indent=1)
    bad = [n for n, v in rep.items() if v.get("stretch_safe") is False]
    low = [n for n, v in rep.items() if (n in ON_FIELD) and v["edge_vs_dirt"] < 3.0]
    print("STRETCH", "PASS" if not bad else "FAIL %s" % bad)
    print("EDGE_VS_DIRT (battlefield frames >= 3:1)", "PASS" if not low else "FAIL %s" % low)
    return 1 if (bad or low) else 0


if __name__ == "__main__":
    sys.exit(main())
