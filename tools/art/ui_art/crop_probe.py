#!/usr/bin/env python3
"""06-art-ui: how much of a card's identity part survives the badge crop (03 U3 review). Owner: 06-art-ui. No Godot.

Parts (idle frame 0 of the committed char_player page, frame px, inclusive): tank = loaf shield with the red cross,
ranged_basic = basket (left) and the roll in hand (right). Each candidate = (CARD_CROP entry, badge shape). Reports the
share of part pixels that stay visible in the 24x24 badge, plus the shape IoU against the other deploy badges.
Usage: python tools/art/ui_art/crop_probe.py
"""
from __future__ import annotations

import itertools
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import card_preview as CP  # noqa: E402
import ui  # noqa: E402

PARTS = {"tank": {"shield_cross": (16, 18, 23, 27)}, "ranged_basic": {"basket": (5, 19, 9, 26), "roll": (13, 21, 21, 26)}}
CANDS = {
    "tank": {"now": (None, "shield"), "T1_bbox_dy4": (("bbox", 4, 0), "shield"), "T2_bbox_dy7": (("bbox", 7, 0), "shield")},
    "ranged_basic": {"now": (None, "ticket"), "R1_figure_down3": (("shift", 0, -3), "ticket"),
                     "R2_bites_high": (None, "ticket_hi")},
}
MARK = 255


def visible_share(uid, frame, part):
    x0, y0, x1, y1 = part
    f = frame.copy()
    sel = np.zeros_like(f, bool)
    sel[y0:y1 + 1, x0:x1 + 1] = f[y0:y1 + 1, x0:x1 + 1] > 0
    n = int(sel.sum())
    f[sel] = MARK
    cv = ui.card(uid, f)
    return round(float((cv.a == MARK).sum()) / max(1, n), 3)


def main():
    fr = CP.idle_frames()
    out = {}
    base_crop = dict(ui.CARD_CROP)
    base_style = dict(ui.CARD_STYLE)
    for uid, cands in CANDS.items():
        out[uid] = {}
        for name, (crop, shape) in cands.items():
            ui.CARD_CROP.clear(); ui.CARD_CROP.update(base_crop)
            if crop is not None:
                ui.CARD_CROP[uid] = crop
            st = list(base_style[uid]); st[0] = shape; ui.CARD_STYLE[uid] = tuple(st)
            r = {"crop": crop, "shape": shape}
            for pn, part in PARTS[uid].items():
                r[pn + "_visible"] = visible_share(uid, fr[uid], part)
            m = ui.badge_mask(shape)
            r["max_iou_vs_others"] = round(max(float((m & ui.badge_mask(ui.CARD_STYLE[o][0])).sum()) / float((m | ui.badge_mask(ui.CARD_STYLE[o][0])).sum())
                                           for o in ("worker", "melee_basic", "ranged_basic", "tank", "fast", "siege") if o != uid), 3)
            out[uid][name] = r
            ui.CARD_STYLE[uid] = base_style[uid]
    ui.CARD_CROP.clear(); ui.CARD_CROP.update(base_crop)
    print(json.dumps(out, indent=1))
    return out


if __name__ == "__main__":
    main()
