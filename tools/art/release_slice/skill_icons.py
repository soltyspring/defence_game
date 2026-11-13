"""24x24 icons for the four new energy skills, in the style of the ui_main skill icons: dark 1-px rim, a coloured
frame, a dark tinted field and one simple pictogram lit from the upper left.
  python tools/art/release_slice/skill_icons.py   -> assets/art/skills/<skill id>.png
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[3] / "assets/art/skills"
INK = (28, 22, 34, 255)


def frame(rim, field):
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([1, 1, 22, 22], fill=INK)
    d.rectangle([2, 2, 21, 21], fill=rim)
    d.rectangle([3, 3, 20, 20], fill=field)
    d.line([3, 19, 20, 19], fill=tuple(max(0, c - 18) for c in field[:3]) + (255,))
    return im, d


def px(d, pts, c):
    for p in pts:
        d.point(p, fill=c)


def flour():
    im, d = frame((214, 160, 72, 255), (72, 52, 34, 255))
    sack, shade, tie = (240, 226, 192, 255), (204, 182, 140, 255), (150, 104, 60, 255)
    d.rectangle([7, 9, 16, 18], fill=sack)                 # body
    d.rectangle([8, 8, 15, 8], fill=sack)
    d.rectangle([14, 10, 16, 18], fill=shade)              # right side in shade
    d.rectangle([9, 6, 14, 7], fill=tie)                   # tied neck
    d.rectangle([10, 5, 13, 5], fill=sack)
    px(d, [(9, 11), (10, 11), (9, 12)], (255, 250, 236, 255))
    d.rectangle([10, 13, 13, 14], fill=(214, 160, 72, 255))  # wheat mark
    d.rectangle([11, 12, 12, 15], fill=(214, 160, 72, 255))
    px(d, [(18, 5), (19, 4), (18, 4), (17, 4), (18, 3)], (255, 236, 150, 255))   # plus spark
    return im


def shield():
    im, d = frame((236, 140, 178, 255), (70, 36, 58, 255))
    outer, inner, hi = (255, 196, 222, 255), (248, 160, 198, 255), (255, 240, 248, 255)
    # a heart-topped sugar shield
    rows = [(8, 15), (6, 17), (5, 18), (5, 18), (5, 18), (6, 17), (6, 17), (7, 16), (8, 15), (9, 14), (10, 13), (11, 12)]
    for i, (a, b) in enumerate(rows):
        y = 6 + i
        d.line([a, y, b, y], fill=outer)
        if a + 1 <= b - 1:
            d.line([a + 1, y, b - 1, y], fill=inner)
    d.line([12, 6, 12, 7], fill=(70, 36, 58, 255))          # heart notch
    px(d, [(7, 8), (8, 8), (7, 9), (8, 7)], hi)
    d.line([11, 9, 11, 15], fill=hi)                        # sugar glaze stripe
    return im


def frost():
    im, d = frame((130, 196, 236, 255), (30, 50, 82, 255))
    ice, hi = (186, 228, 255, 255), (244, 252, 255, 255)
    c = 12
    for dx, dy in [(1, 0), (0, 1), (1, 1), (1, -1)]:
        for t in range(-6, 7):
            d.point((c + dx * t if dx else c, c + dy * t if dy else c), fill=ice)
    for s in (-1, 1):                                       # little barbs
        px(d, [(c + 4 * s, c - 1), (c + 4 * s, c + 1), (c - 1, c + 4 * s), (c + 1, c + 4 * s)], ice)
    px(d, [(c, c), (c - 1, c - 1), (c - 2, c - 2), (c, c - 3), (c - 3, c)], hi)
    return im


def oven():
    im, d = frame((236, 120, 52, 255), (48, 26, 22, 255))
    hot, mid, core = (226, 76, 40, 255), (250, 150, 48, 255), (255, 226, 120, 255)
    for x, h in [(6, 8), (9, 12), (12, 14), (15, 11), (18, 7)]:
        d.rectangle([x - 1, 19 - h, x + 1, 18], fill=hot)
        d.rectangle([x - 1, 19 - int(h * 0.7), x + 1, 18], fill=mid)
        d.rectangle([x, 19 - int(h * 0.4), x, 18], fill=core)
    d.line([4, 18, 19, 18], fill=core)
    return im


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in {"skill_flour": flour, "skill_shield": shield, "skill_frost": frost, "skill_oven": oven}.items():
        fn().save(OUT / f"{name}.png")
