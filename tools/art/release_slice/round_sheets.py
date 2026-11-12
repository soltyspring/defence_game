"""Contact sheets from real game captures (tests/art_preview/capture_rounds.gd).
Usage: python tools/art/release_slice/round_sheets.py <captures dir> <out dir> [--before=<dir>]
    rounds_ch<N>_<view>.png      the ten rounds of a chapter, 5 x 2, each frame at 320x180 (half size, nearest)
    pair_r<NN>_<view>.png        with --before: left = current art, right = release-slice art, full 640x360
"""
import glob
import os
import re
import sys
from PIL import Image

BG = (20, 20, 24)


def main():
    src, out = sys.argv[1:3]
    before = next((a.split("=", 1)[1] for a in sys.argv[3:] if a.startswith("--before=")), None)
    os.makedirs(out, exist_ok=True)
    shots = {}
    for p in glob.glob(os.path.join(src, "r??_*_after_640x360.png")):
        m = re.match(r"r(\d\d)_(\w+?)_after_", os.path.basename(p))
        shots[(int(m.group(1)), m.group(2))] = p
    views = sorted({v for _, v in shots})
    for view in views:
        for ch in range(1, 5):
            rounds = [n for n in range(ch * 10 - 9, ch * 10 + 1) if (n, view) in shots]
            if not rounds:
                continue
            sheet = Image.new("RGB", (5 * 322 - 2, 2 * 182 - 2), BG)
            for n in rounds:
                i = (n - 1) % 10
                im = Image.open(shots[(n, view)]).convert("RGB").resize((320, 180), Image.NEAREST)
                sheet.paste(im, ((i % 5) * 322, (i // 5) * 182))
            sheet.save(os.path.join(out, f"rounds_ch{ch}_{view}.png"))
    if before:
        for (n, view), p in sorted(shots.items()):
            q = os.path.join(before, f"r{n:02d}_{view}_before_640x360.png")
            if not os.path.exists(q):
                continue
            sheet = Image.new("RGB", (1284, 360), BG)
            sheet.paste(Image.open(q).convert("RGB"), (0, 0))
            sheet.paste(Image.open(p).convert("RGB"), (644, 0))
            sheet.save(os.path.join(out, f"pair_r{n:02d}_{view}.png"))
    print("round sheets ->", out)


if __name__ == "__main__":
    main()
