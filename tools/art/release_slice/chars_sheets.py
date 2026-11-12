"""Character evidence sheets from real game captures (tests/art_preview/capture_slice.gd --tag=chars_before|chars_after).
Both sets use the release-slice field and bases; only hero_captain / melee_basic / e_grunt differ.
Usage: python tools/art/release_slice/chars_sheets.py <chars_before dir> <chars_after dir> <out dir>
    pair_<shot>_640x360.png   left = current characters, right = new characters (home, crowd, grunts, melee, duel)
    zoom_piles_3x.png         3x crops of the 8-toast pile, the 8-grunt pile and the mixed fight (left old, right new)
    strip_duel_<old|new>.png  12 consecutive engine frames, 3 game frames apart, cropped to the fight (attack poses)
"""
import os
import sys
from PIL import Image


def main():
    before, after, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    tags = (("chars_before", before), ("chars_after", after))

    def load(d, tag, shot, extra=""):
        p = os.path.join(d, f"r01_{shot}_{tag}{extra}_640x360.png")
        return Image.open(p).convert("RGB") if os.path.exists(p) else None

    for shot in ("home", "crowd", "grunts", "melee", "duel"):
        ims = [load(d, t, shot) for t, d in tags]
        if None in ims:
            continue
        sheet = Image.new("RGB", (640 * 2 + 4, 360), (20, 20, 24))
        sheet.paste(ims[0], (0, 0))
        sheet.paste(ims[1], (644, 0))
        sheet.save(os.path.join(out, f"pair_{shot}_640x360.png"))
    rows = [("crowd", (330, 190, 490, 300)), ("grunts", (190, 190, 350, 300)), ("melee", (180, 190, 360, 300))]
    sheet = Image.new("RGB", (2 * 180 * 3 + 6, len(rows) * 110 * 3), (20, 20, 24))
    for r, (shot, box) in enumerate(rows):
        for c, (t, d) in enumerate(tags):
            im = load(d, t, shot)
            if im is None:
                continue
            im = im.crop(box)
            sheet.paste(im.resize((im.width * 3, im.height * 3), Image.NEAREST), (c * (180 * 3 + 6), r * 110 * 3))
    sheet.save(os.path.join(out, "zoom_piles_3x.png"))
    for (t, d), name in zip(tags, ("old", "new")):
        frames = [load(d, t, "duel", f"_strip{i:02d}") for i in range(12)]
        frames = [f for f in frames if f is not None]
        if not frames:
            continue
        crop = (130, 180, 350, 300)                 # 220 x 120 around the three fighters
        strip = Image.new("RGB", (4 * 444, ((len(frames) + 3) // 4) * 244), (20, 20, 24))
        for i, f in enumerate(frames):
            c = f.crop(crop)
            strip.paste(c.resize((440, 240), Image.NEAREST), ((i % 4) * 444, (i // 4) * 244))
        strip.save(os.path.join(out, f"strip_duel_{name}.png"))
    print("character sheets ->", out)


if __name__ == "__main__":
    main()
