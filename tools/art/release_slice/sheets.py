"""Evidence sheets from real game captures (tests/art_preview/capture_slice.gd).
Usage: python tools/art/release_slice/sheets.py <before dir> <after dir> <out dir>
    pair_<shot>_640x360.png      left = current art, right = release slice, same round / staging / camera
    pair_melee_<res>.png         480x270 and 1280x720
    gray_melee_640x360.png       the after frame in grayscale (value check only)
    strip_melee_640x360.png      8 consecutive engine frames, 6 game frames apart (animation as the game plays it)
"""
import os
import sys
from PIL import Image


def main():
    before, after, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)

    def pair(shot, res):
        a = os.path.join(before, f"r01_{shot}_before_{res}.png")
        b = os.path.join(after, f"r01_{shot}_after_{res}.png")
        if not (os.path.exists(a) and os.path.exists(b)):
            return
        ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
        sheet = Image.new("RGB", (ia.width + ib.width + 4, max(ia.height, ib.height)), (20, 20, 24))
        sheet.paste(ia, (0, 0))
        sheet.paste(ib, (ia.width + 4, 0))
        sheet.save(os.path.join(out, f"pair_{shot}_{res}.png"))

    for shot in ("home", "mid", "nest", "crowd", "melee", "damaged_home", "damaged_nest"):
        pair(shot, "640x360")
    for res in ("480x270", "1280x720"):
        pair("melee", res)
        for shot in ("home", "nest"):
            p = os.path.join(after, f"r01_{shot}_after_{res}.png")
            if os.path.exists(p):
                Image.open(p).convert("RGB").save(os.path.join(out, f"after_{shot}_{res}.png"))
    m = os.path.join(after, "r01_melee_after_640x360.png")
    if os.path.exists(m):
        Image.open(m).convert("L").save(os.path.join(out, "gray_melee_640x360.png"))
    frames = [os.path.join(after, f"r01_melee_after_strip{i:02d}_640x360.png") for i in range(8)]
    frames = [f for f in frames if os.path.exists(f)]
    if frames:
        crop = (150, 150, 470, 310)             # the fight, 320x160
        sheet = Image.new("RGB", (4 * 322, ((len(frames) + 3) // 4) * 162), (20, 20, 24))
        for i, f in enumerate(frames):
            sheet.paste(Image.open(f).convert("RGB").crop(crop), ((i % 4) * 322, (i // 4) * 162))
        sheet.save(os.path.join(out, "strip_melee_640x360.png"))
    print("sheets ->", out)


if __name__ == "__main__":
    main()
