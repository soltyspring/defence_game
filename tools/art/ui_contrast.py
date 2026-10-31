"""ui_main chrome: text contrast (WCAG 2.x) and state / faction separation under CVD (owner: 03-art).

    python tools/art/ui_contrast.py [out.json]

Reads the written ui_main page. Fill colour of a 9-slice frame = its centre pixel.
Text colours are 04's constants in src/ui/ui_style.gd (C_TEXT, C_TEXT_DIM, C_GOLD) and the
outline colour K for dark text on light fills.
Lines (fixed before measuring):
  text      WCAG contrast ratio >= 4.5 for the text colour each frame is meant to carry.
            (WCAG 1.4.3 exempts inactive controls; disabled frames are measured anyway, line 4.5.)
  states    active vs disabled / pressed / selected: CIE dE76 >= 10 under normal, protan,
            deutan and tritan (Machado 2009, full severity) AND |dL*| >= 10 (does not rely on hue).
  faction   ally card vs enemy portrait (mean colour of the 24x24 frame, outline excluded):
            dE76 >= 10 in all four simulations AND |dL*| of the frame background >= 10.
Also reports 04's code-drawn chrome colours (blue-grey) and the bakery values 03 proposes for them.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
from cvd_check import MACHADO, lab, sim  # noqa: E402

TEXT = {"C_TEXT": (0.96, 0.94, 0.88), "C_TEXT_DIM": (0.66, 0.68, 0.74), "C_GOLD": (1.0, 0.80, 0.25),
        "K_dark_text": (0x1b / 255, 0x13 / 255, 0x25 / 255)}
# frame -> text colour it carries (04 draws C_TEXT on dark chrome, C_TEXT_DIM when disabled)
TEXT_PAIRS = [("btn", "C_TEXT"), ("btn_pressed", "C_TEXT"), ("btn_disabled", "C_TEXT_DIM"),
              ("btn_gold", "K_dark_text"), ("panel", "K_dark_text"), ("panel_dark", "C_TEXT"),
              ("panel_dark", "C_GOLD"), ("card_frame", "C_TEXT"), ("card_frame", "C_GOLD"),
              ("card_frame_disabled", "C_TEXT_DIM"), ("card_frame_selected", "K_dark_text")]
STATE_PAIRS = [("btn", "btn_disabled"), ("btn", "btn_pressed"), ("card_frame", "card_frame_disabled"),
               ("card_frame", "card_frame_selected"), ("btn", "btn_gold")]
ALLY_CARDS = ["card_worker", "card_melee_basic", "card_ranged_basic", "card_tank", "card_fast", "card_siege",
              "card_hero_captain"]
ENEMY_PORTRAITS = ["portrait_e_grunt", "portrait_e_swarm", "portrait_e_spitter", "portrait_e_brute",
                   "portrait_e_bomber", "portrait_boss_warlord"]
# 04 code colours (src/ui/ui_style.gd, read 2026-10-31) and 03's bakery proposal (Hearth-48 keys)
CODE_NOW = {"C_BG": "171a24", "C_PANEL": "212636", "C_PANEL_LIGHT": "384054", "C_DISABLED": "4d4f59"}
CODE_PROPOSED = {"C_BG": "2a1a12", "C_PANEL": "3d2519", "C_PANEL_LIGHT": "6e4528", "C_DISABLED": "2f3140"}


def rel_lum(rgb01):
    c = np.asarray(rgb01, float)
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return float(c @ [0.2126, 0.7152, 0.0722])


def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def hex01(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def sims(rgb255):
    return {m: lab(sim(np.asarray(rgb255, float)[None], m))[0] for m in MACHADO}


def sep(a255, b255):
    sa, sb = sims(a255), sims(b255)
    de = {m: round(float(np.linalg.norm(sa[m] - sb[m])), 1) for m in MACHADO}
    dl = round(float(abs(sa["normal"][0] - sb["normal"][0])), 1)
    return de, dl


def main(out=None):
    doc = json.load(open(os.path.join(ROOT, "assets", "atlases", "ui_main.json"), encoding="utf-8"))
    page = np.array(Image.open(os.path.join(ROOT, "assets", "atlases", "ui_main.png")).convert("RGBA"))

    def crop(n):
        f = doc["frames"][n]
        return page[f["y"]:f["y"] + f["h"], f["x"]:f["x"] + f["w"]]

    def fill(n):
        cr = crop(n)
        return cr[cr.shape[0] // 2, cr.shape[1] // 2, :3].astype(float)

    def bg(n):
        cr = crop(n)
        return cr[2, cr.shape[1] - 3, :3].astype(float)     # inner top-right corner = portrait background

    def mean_col(n):
        cr = crop(n)
        a = cr[..., 3] > 0
        rgb = cr[..., :3][a].astype(float)
        keep = ~np.all(rgb == [0x1b, 0x13, 0x25], axis=1)
        return rgb[keep].mean(0)

    rep = {"text": [], "states": [], "faction": {}, "code_chrome": {}, "lines": {"text": 4.5, "dE": 10.0, "dL": 10.0}}
    fails = []
    for fr, tk in TEXT_PAIRS:
        f = fill(fr)
        r = round(contrast(np.array(f) / 255, TEXT[tk]), 2)
        ok = r >= 4.5
        rep["text"].append({"frame": fr, "fill": "%02x%02x%02x" % tuple(int(v) for v in f), "text": tk, "ratio": r, "pass": ok})
        if not ok:
            fails.append(("text", fr, tk, r))
    for a, b in STATE_PAIRS:
        de, dl = sep(fill(a), fill(b))
        ok = min(de.values()) >= 10 and dl >= 10
        rep["states"].append({"a": a, "b": b, "dE76": de, "dL": dl, "pass": ok})
        if not ok:
            fails.append(("state", a, b, de, dl))
    worst = None
    for a in ALLY_CARDS:
        for e in ENEMY_PORTRAITS:
            de, _ = sep(mean_col(a), mean_col(e))
            m = min(de.values())
            if worst is None or m < worst[0]:
                worst = (m, a, e, de)
    bde, bdl = sep(bg(ALLY_CARDS[0]), bg(ENEMY_PORTRAITS[0]))
    ok = worst[0] >= 10 and bdl >= 10
    rep["faction"] = {"closest_pair": [worst[1], worst[2]], "dE76": worst[3],
                      "card_background": {"ally": "%02x%02x%02x" % tuple(int(v) for v in bg(ALLY_CARDS[0])),
                                          "enemy": "%02x%02x%02x" % tuple(int(v) for v in bg(ENEMY_PORTRAITS[0])),
                                          "dE76": bde, "dL": bdl}, "pass": ok}
    if not ok:
        fails.append(("faction", worst, bde, bdl))
    for label, tbl in (("now", CODE_NOW), ("proposed", CODE_PROPOSED)):
        rows = {}
        for k, h in tbl.items():
            tk = "C_TEXT_DIM" if k == "C_DISABLED" else "C_TEXT"
            rows[k] = {"hex": h, "text": tk, "ratio": round(contrast(hex01(h), TEXT[tk]), 2),
                       "gold_ratio": round(contrast(hex01(h), TEXT["C_GOLD"]), 2)}
        de, dl = sep(np.array(hex01(tbl["C_PANEL_LIGHT"])) * 255, np.array(hex01(tbl["C_DISABLED"])) * 255)
        rows["active_vs_disabled"] = {"dE76": de, "dL": dl}
        rep["code_chrome"][label] = rows
    rep["fails"] = [str(f) for f in fails]
    rep["pass"] = not fails
    txt = json.dumps(rep, indent=1, ensure_ascii=False)
    if out:
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(txt + "\n")
    print(txt)
    return rep


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
