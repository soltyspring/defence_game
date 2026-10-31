#!/usr/bin/env python3
"""04-client: on-screen height (mm) of HUD Korean labels and numbers on target phones (no Godot). Owner: 04-client.

Usage (workspace root):  python tools/build/text_screen_size.py [--json out.json] [--md out.md]
Ink height = FreeType bounding box of a sample string in the bundled font at the exact UI px size (the UI uses
these grid sizes only: Galmuri11 12/24/36, Galmuri9 10/20). Converted like unit_screen_size.py:
mm = px * k / (density * 160) * 25.4 with k=3 on 1080x2400 (360/393/412 dp classes).
Line: 1.7 mm ink height = Hangul ink (about 0.9 em) of Android's 12 sp minimum body text (12/160 in = 1.9 mm em).
Working criterion for this project, not a published standard.
"""
import json
import os
import sys

from PIL import ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = os.path.join(ROOT, "assets", "fonts")
DEVICES = [("360x800dp", 3.0), ("393x873dp", 2.75), ("412x915dp", 2.625)]
K = 3
LINE_MM = 1.7
# (HUD item, font file, px size, sample)
ITEMS = [
    ("resource name 밀가루 / 기력 (hud_top)", "Galmuri11.ttf", 12, "밀가루기력"),
    ("resource amount (bold digits)", "Galmuri11-Bold.ttf", 12, "0123456789"),
    ("resource cap / income digits (NUM_READ)", "Galmuri11.ttf", 12, "/300+4.0"),
    ("base HP numbers 1500/1500 (NUM_READ)", "Galmuri11.ttf", 12, "1500/1200"),
    ("army count 5/36 (NUM_READ)", "Galmuri11.ttf", 12, "5/36"),
    ("wave line 웨이브 1/4 다음 7초", "Galmuri11.ttf", 12, "웨이브다음초"),
    ("boss name 곰팡이 장군", "Galmuri11.ttf", 12, "곰팡이장군"),
    ("card name 식빵병 (12 px)", "Galmuri11.ttf", 12, "식빵병제빵사"),
    ("card cost 30 (NUM_READ)", "Galmuri11.ttf", 12, "0123456789"),
    ("card badge / worker count (NUM_READ)", "Galmuri11.ttf", 12, "08"),
    ("upgrade Lv / effect, menu version (NUM_READ)", "Galmuri11.ttf", 12, "Lv1/5+8%v0.1"),
    ("toast / tutorial hint", "Galmuri11.ttf", 12, "밀가루가부족합니다"),
    ("off-screen marker distance 57m", "Galmuri11.ttf", 12, "57m"),
    ("respawn countdown (Galmuri9 20)", "Galmuri9.ttf", 20, "0123456789"),
    ("banner 웨이브 1/4 (bold 24)", "Galmuri11-Bold.ttf", 24, "웨이브보스"),
    ("damage numbers in the lane (Galmuri9 10, 02 battle_view)", "Galmuri9.ttf", 10, "2574"),
]


def ink_px(font_file, size, sample):
    f = ImageFont.truetype(os.path.join(FONTS, font_file), size)
    top, bottom = 10 ** 6, -10 ** 6
    for ch in sample:
        bb = f.getbbox(ch)
        if bb[3] > bb[1]:
            top, bottom = min(top, bb[1]), max(bottom, bb[3])
    return bottom - top


def main():
    rows = []
    for name, ff, size, sample in ITEMS:
        h = ink_px(ff, size, sample)
        r = {"item": name, "font": ff, "px": size, "ink_px": h, "devices": {}}
        for dn, d in DEVICES:
            mm = h * K / (d * 160.0) * 25.4
            r["devices"][dn] = {"mm": round(mm, 2), "ok": mm >= LINE_MM}
        rows.append(r)
    lines = ["| HUD text | font / px | ink px | " + " | ".join(dn + " mm" for dn, _ in DEVICES) + " |", "|---|---|---|" + "---|" * len(DEVICES)]
    for r in rows:
        cells = ["%.2f%s" % (r["devices"][dn]["mm"], "" if r["devices"][dn]["ok"] else " (<1.7)") for dn, _ in DEVICES]
        lines.append("| %s | %s %d | %d | %s |" % (r["item"], r["font"].replace(".ttf", ""), r["px"], r["ink_px"], " | ".join(cells)))
    md = "\n".join(lines)
    sys.stdout.buffer.write((md + "\n").encode("utf-8"))
    if "--json" in sys.argv:
        json.dump({"line_mm": LINE_MM, "k": K, "devices": DEVICES, "rows": rows}, open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    if "--md" in sys.argv:
        open(sys.argv[sys.argv.index("--md") + 1], "w", encoding="utf-8").write(md + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
