#!/usr/bin/env python3
"""06-art-ui: size candidates for 04's new HUD layout (card body, HUD tray, skill plate). Owner: 06-art-ui. No Godot.

For each candidate size (logical px of the 800x360 view = the 393 dp phone, 1 px = 0.1733 mm, 07 art_metrics):
  - touch target: >= 44 px and >= 7 mm in both axes;
  - 9-slice: margins fit (L+R <= w, T+B <= h), edges uniform along the stretch axis and flat centre
    (chrome_preview.stretch_safe), outer 2 px stay dark after stretching, 2x = exact 2x copy of 1x;
  - card content, using touch_button.gd's own slot formulas: icon scale k (integer), name fits w - 6 at Galmuri11 12 px
    (ko and en, longest unit name), cost row inside the body.
Writes docs/art/evidence/ui_art/sizes/<element>_<w>x<h>_{1x,2x}.png (affordable / unaffordable (variant C) / selected)
and sizes.json. Text is drawn with Galmuri11 12 px + 1 px drop shadow as an approximation of ui_style.draw_text_centered.
Usage: python tools/art/ui_art/size_candidates.py
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
ROOT = os.path.abspath(os.path.join(ART, "..", ".."))
sys.path.insert(0, ART)
sys.path.insert(0, HERE)

import card_preview as CP  # noqa: E402
import chrome_preview as CH  # noqa: E402
import pixel  # noqa: E402
import ui  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "evidence", "ui_art", "sizes")
MM = 393.0 / 360.0 * 0.15875          # mm per logical px (tools/qa/art_metrics.MM_PER_VIEW_PX)
FONT = os.path.join(ROOT, "assets", "fonts", "Galmuri11.ttf")
C_TEXT, C_TEXT_DIM, C_GOLD, SHADOW = (245, 240, 224), (168, 173, 189), (255, 204, 64), (7, 7, 12)
DIRT = (0x9f, 0x6d, 0x42)
CARD = [(48, 56), (56, 64), (64, 80)]       # current 04: 50x56
TRAY_PAD = 4                                # tray height = card height + 2 x 4
SKILL = [(48, 48), (56, 56), (64, 64)]      # current 04: 48x48
SCREEN = 800 * 360                          # logical px; U2 = HUD px / SCREEN (07 ART_BASELINE)


def names():
    out = {}
    for loc in ("ko", "en"):
        s = json.load(open(os.path.join(ROOT, "data", "text", f"{loc}.json"), encoding="utf-8"))["strings"]
        out[loc] = {k.split(".")[1]: v for k, v in s.items() if k.startswith(("unit.", "skill.")) and k.endswith(".name")}
    return out


def text_w(font, t):
    return int(font.getlength(t))


def rgba(cv):
    return pixel.RGBA[cv.a].astype(np.uint8)


def put(dst, src, x, y):
    h, w = src.shape[:2]
    a = src[..., 3:4] / 255.0
    reg = dst[y:y + h, x:x + w].astype(float)
    dst[y:y + h, x:x + w] = np.round(src[..., :3] * a + reg * (1 - a)).astype(np.uint8)


def draw_text(img, t, cx, cy, col, font):
    pil = Image.fromarray(img)
    d = ImageDraw.Draw(pil)
    d.fontmode = "1"
    w = text_w(font, t)
    x, y = int(round(cx - w / 2)), int(round(cy - 6))
    d.text((x + 1, y + 1), t, fill=SHADOW, font=font)
    d.text((x, y), t, fill=col, font=font)
    img[:] = np.array(pil)


def card_slots(w, h, has_sub=True, show_name=True):
    """touch_button.gd _draw(): cost_y, name_y, icon_bottom, avail, integer icon scale k for a 24 px icon."""
    cost_y = h - 9.0
    name_y = (h - 21.0) if has_sub else (h - 10.0)
    icon_bottom = (name_y - 7.0) if show_name else (cost_y - 6.0 if has_sub else h - 4.0)
    avail = min(w - 8, icon_bottom - 4.0) if (show_name or has_sub) else min(w - 8, h - 8)
    k = max(1, int(avail // 24))
    icon_c = (w / 2, (4.0 + icon_bottom) / 2.0)
    return {"cost_y": cost_y, "name_y": name_y, "icon_bottom": icon_bottom, "avail": avail, "icon_k": k, "icon_c": icon_c}


def render_card(frame, badge, w, h, name, cost, state, font):
    img = np.zeros((h + 8, w + 8, 3), np.uint8)
    img[:] = DIRT
    put(img, CH.nine_draw(rgba(frame[0]), frame[1], w, h), 4, 4)
    s = card_slots(w, h)
    k = s["icon_k"]
    b = np.repeat(np.repeat(badge, k, axis=0), k, axis=1)
    cx, cy = s["icon_c"]
    put(img, b, 4 + int(round(cx - 12 * k)), 4 + int(round(cy - 12 * k)))
    tc = C_TEXT if state != "off" else C_TEXT_DIM
    draw_text(img, name, 4 + w / 2, 4 + s["name_y"], tc, font)
    draw_text(img, cost, 4 + w / 2, 4 + s["cost_y"], C_GOLD if state != "off" else C_TEXT_DIM, font)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    font = ImageFont.truetype(FONT, 12)
    nm = names()
    fr = CP.idle_frames()
    lit = ui.frames9_lit()
    base = ui.frames9()
    prop = ui.chrome_proposed()
    rep = {"mm_per_px": round(MM, 4), "touch_min_px": 44, "touch_min_mm": 7.0, "card": {}, "tray": {}, "skill": {},
           "note": "06 art preview, not a screen capture; text approximates ui_style.draw_text_centered"}
    longest = {loc: max((nm[loc][u] for u in ("worker", "melee_basic", "ranged_basic", "tank", "fast", "siege")),
                        key=lambda t: text_w(font, t)) for loc in nm}
    for (w, h) in CARD:
        s = card_slots(w, h)
        fits = {loc: {"longest": longest[loc], "px": text_w(font, longest[loc]), "room": w - 6,
                      "one_line": text_w(font, longest[loc]) <= w - 6} for loc in nm}
        safe = {n: all(CH.stretch_safe(rgba(f[0]), f[1]).values()) for n, f in
                (("card_frame_lit", lit["card_frame"]), ("card_frame_disabled", base["card_frame_disabled"]),
                 ("card_frame_selected_lit", lit["card_frame_selected"]))}
        row = []
        for st, f, bd in (("on", lit["card_frame"], rgba(ui.card("melee_basic", fr["melee_basic"]))),
                          ("off", base["card_frame_disabled"], rgba(ui.card_off("melee_basic", fr["melee_basic"]))),
                          ("selected", lit["card_frame_selected"], rgba(ui.card("melee_basic", fr["melee_basic"])))):
            row.append(render_card(f, bd, w, h, nm["ko"]["melee_basic"], "30", st, font))
            row.append(np.full((h + 8, 4, 3), 255, np.uint8))
        one = np.concatenate(row, axis=1)
        two = np.repeat(np.repeat(one, 2, axis=0), 2, axis=1)
        p1 = os.path.join(OUT, f"card_{w}x{h}_1x.png"); p2 = os.path.join(OUT, f"card_{w}x{h}_2x.png")
        Image.fromarray(one).save(p1, optimize=True); Image.fromarray(two).save(p2, optimize=True)
        drawn = CH.nine_draw(rgba(lit["card_frame"][0]), lit["card_frame"][1], w, h)
        rep["card"][f"{w}x{h}"] = {"hud_px_delta_pp_est_6cards": round(100.0 * (6 * w * h - 6 * 50 * 56) / SCREEN, 2), "mm": [round(w * MM, 2), round(h * MM, 2)], "touch_ok": w >= 44 and h >= 44 and w * MM >= 7 and h * MM >= 7,
                                   "nine_slice_margins": list(lit["card_frame"][1]), "stretch_safe": safe,
                                   "edge_vs_dirt": CH.edge_vs_dirt(drawn), "icon_scale_k": s["icon_k"],
                                   "icon_px": 24 * s["icon_k"], "name_fit": fits,
                                   "preview": [os.path.relpath(p1, ROOT).replace("\\", "/"), os.path.relpath(p2, ROOT).replace("\\", "/")]}
        # tray for a 6-card group at this card size (04 GAP between cards assumed 4 px)
        th = h + 2 * TRAY_PAD
        tw = 6 * w + 5 * 4 + 2 * TRAY_PAD
        tf = prop["hud_tray"]
        timg = np.zeros((th + 8, tw + 8, 3), np.uint8); timg[:] = DIRT
        put(timg, CH.nine_draw(rgba(tf[0]), tf[1], tw, th), 4, 4)
        for i in range(6):
            put(timg, CH.nine_draw(rgba(lit["card_frame"][0]), lit["card_frame"][1], w, h), 4 + TRAY_PAD + i * (w + 4), 4 + TRAY_PAD)
        pt1 = os.path.join(OUT, f"tray_{tw}x{th}_1x.png"); pt2 = os.path.join(OUT, f"tray_{tw}x{th}_2x.png")
        Image.fromarray(timg).save(pt1, optimize=True)
        Image.fromarray(np.repeat(np.repeat(timg, 2, axis=0), 2, axis=1)).save(pt2, optimize=True)
        gaps0 = 5 * 4 * h                       # tray without padding: only the 5 gaps show (as in hud_mock.py)
        rep["tray"][f"{tw}x{th}"] = {"for_card": f"{w}x{h}", "cards": 6, "gap": 4, "pad": TRAY_PAD,
                                     "hud_px_added_pp_est": {"pad_4": round(100.0 * (tw * th - 6 * w * h) / SCREEN, 2), "pad_0_gaps_only": round(100.0 * gaps0 / SCREEN, 2)},
                                     "stretch_safe": all(CH.stretch_safe(rgba(tf[0]), tf[1]).values()),
                                     "nine_slice_margins": list(tf[1]), "proposed_new_name": True,
                                     "preview": [os.path.relpath(pt1, ROOT).replace("\\", "/"), os.path.relpath(pt2, ROOT).replace("\\", "/")]}
    for (w, h) in SKILL:
        f = prop["btn_skill"]
        show_name = h >= 54          # touch_button: name row appears at >= 54 px even with icon + cost
        s = card_slots(w, h, has_sub=True, show_name=show_name)
        img = np.zeros((h + 8, (w + 8) * 3, 3), np.uint8); img[:] = DIRT
        for j, (sid, cost) in enumerate((("skill_slam", "40"), ("skill_rally", "60"), ("skill_barrage", "80"))):
            put(img, CH.nine_draw(rgba(f[0]), f[1], w, h), 4 + j * (w + 8), 4)
            ic = rgba(getattr(ui, sid)())
            k = s["icon_k"]
            b = np.repeat(np.repeat(ic, k, axis=0), k, axis=1)
            cx, cy = s["icon_c"]
            put(img, b, 4 + j * (w + 8) + int(round(cx - 12 * k)), 4 + int(round(cy - 12 * k)))
            if show_name:
                draw_text(img, nm["ko"][sid], 4 + j * (w + 8) + w / 2, 4 + s["name_y"], C_TEXT, font)
            draw_text(img, cost, 4 + j * (w + 8) + w / 2, 4 + s["cost_y"], C_GOLD, font)
        ps1 = os.path.join(OUT, f"skill_{w}x{h}_1x.png"); ps2 = os.path.join(OUT, f"skill_{w}x{h}_2x.png")
        Image.fromarray(img).save(ps1, optimize=True)
        Image.fromarray(np.repeat(np.repeat(img, 2, axis=0), 2, axis=1)).save(ps2, optimize=True)
        longest_sk = {loc: max((nm[loc][x] for x in ("skill_slam", "skill_rally", "skill_barrage")), key=lambda t: text_w(font, t)) for loc in nm}
        rep["skill"][f"{w}x{h}"] = {"hud_px_delta_pp_est_3skills": round(100.0 * (3 * w * h - 3 * 48 * 48) / SCREEN, 2), "mm": [round(w * MM, 2), round(h * MM, 2)], "touch_ok": w >= 44 and h >= 44 and w * MM >= 7,
                                    "nine_slice_margins": list(f[1]), "stretch_safe": all(CH.stretch_safe(rgba(f[0]), f[1]).values()),
                                    "edge_vs_dirt": CH.edge_vs_dirt(CH.nine_draw(rgba(f[0]), f[1], w, h)), "proposed_new_name": True,
                                    "name_row_shown_by_touch_button": show_name, "icon_scale_k": s["icon_k"],
                                    "name_fit": {loc: {"longest": longest_sk[loc], "px": text_w(font, longest_sk[loc]), "room": w - 6,
                                                       "one_line": text_w(font, longest_sk[loc]) <= w - 6} for loc in nm} if show_name else None,
                                    "preview": [os.path.relpath(ps1, ROOT).replace("\\", "/"), os.path.relpath(ps2, ROOT).replace("\\", "/")]}
    json.dump(rep, open(os.path.join(OUT, "sizes.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(rep, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
