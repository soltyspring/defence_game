"""Reference images for redrawing the five campaign-100 units with an image model (docs/art/release_slice/unit_regen)."""
import json, re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
SLICE = ROOT / "assets/art/release_slice"
OUT = ROOT / "docs/art/release_slice/unit_regen"
_pages = {}


def frame(page, name):
    if page not in _pages:
        _pages[page] = (Image.open(SLICE / f"{page}.png").convert("RGBA"), json.loads((SLICE / f"{page}.json").read_text())["frames"])
    img, fr = _pages[page]
    f = fr[name]
    return img.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))


def font(s): return ImageFont.load_default(size=s)


def style_reference():
    units = [("slice_chars", "hero_captain", "hero 48px"), ("slice_chars", "melee_basic", "bread-slice soldier 32px"),
             ("slice_chars2", "ranged_basic", "roll-bread archer 32px"), ("slice_chars2", "tank", "loaf tank 32px"),
             ("slice_chars2", "fast", "pretzel runner 40x32"), ("slice_chars2", "siege", "oven cannon 48x40")]
    poses = ["idle/0", "walk/1", "walk/3", "attack/0", "attack/2"]
    k, cw, ch = 5, 260, 270
    img = Image.new("RGB", (cw * len(poses) + 300, ch * len(units)), "#e9e4da")
    d = ImageDraw.Draw(img)
    for r, (page, uid, label) in enumerate(units):
        d.text((12, r * ch + 110), label, font=font(22), fill="#3a2a24")
        for c, p in enumerate(poses):
            f = frame(page, f"{uid}/{p}")
            f = f.resize((f.width * k, f.height * k), Image.NEAREST)
            img.paste(f, (300 + c * cw + (cw - f.width) // 2, r * ch + ch - 20 - f.height), f)
    for c, p in enumerate(poses):
        d.text((300 + c * cw + 80, 4), p.replace("/", " "), font=font(20), fill="#7a6a5a")
    img.save(OUT / "1_style_reference.png")


def layout_guide():
    W, H, cols, rows = 1536, 1024, 4, 2
    cw, ch = W // cols, H // rows
    img = Image.new("RGB", (W, H), "#ff00ff")
    d = ImageDraw.Draw(img)
    names = ["1 idle", "2 walk A", "3 walk B (passing)", "4 walk C", "5 attack wind-up", "6 attack hit", "7 attack follow-through", "8 defeated, lying down"]
    for i, n in enumerate(names):
        x0, y0 = (i % cols) * cw, (i // cols) * ch
        d.rectangle([x0, y0, x0 + cw - 1, y0 + ch - 1], outline="#ffffff", width=2)
        ground = y0 + ch - 64
        d.line([x0 + 20, ground, x0 + cw - 20, ground], fill="#ffffff", width=2)
        bx = x0 + (cw - 256) // 2
        for y in range(ground - 256, ground, 16):        # dashed 32-px (x8) body box
            d.line([bx, y, bx, y + 8], fill="#ffd0ff", width=2); d.line([bx + 255, y, bx + 255, y + 8], fill="#ffd0ff", width=2)
        d.text((x0 + 12, y0 + 10), n, font=font(26), fill="white", stroke_width=3, stroke_fill="#80007f")
    ex = frame("slice_chars", "melee_basic/idle/0").resize((256, 256), Image.NEAREST)
    img.paste(ex, ((cw - 256) // 2, ch - 64 - 256 + 6), ex)
    d.text((14, ch - 52), "example: existing soldier, 32 px drawn at 8x", font=font(20), fill="white", stroke_width=3, stroke_fill="#80007f")
    img.save(OUT / "3_sheet_layout.png")


def current_units():
    svg = (ROOT / "assets/art/roster10/roster10.svg")
    if not svg.exists():
        return
    src = svg.read_text(encoding="utf-8")
    sheet = Image.new("RGBA", (768, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for m in re.finditer(r'<g transform="translate\((\d+) (\d+)\)">(.*?)</g>(?=<g transform="translate|</svg>)', src, re.S):
        ox, oy, body = int(m[1]), int(m[2]), m[3]
        if "opacity" in body:
            continue
        for r in re.finditer(r'<rect x="(-?\d+)" y="(-?\d+)" width="(\d+)" height="(\d+)" fill="(#\w+)"/>', body):
            x, y, w, h = map(int, r.groups()[:4])
            d.rectangle([ox + x, oy + y, ox + x + w - 1, oy + y + h - 1], fill=r[5])
    roles = ["baguette: long pike, reach melee", "macaron: sniper, strong single shot", "chili bread: flamethrower, area attack",
             "donut: guardian, heavy armour + shield", "waffle: siege, destroys enemy base"]
    k = 4
    img = Image.new("RGB", (1500, 5 * 210 + 60), "#2b2430")
    dd = ImageDraw.Draw(img)
    dd.text((16, 12), "CURRENT placeholder art: replace all five. Keep only the role idea.", font=font(28), fill="#ffb0a0")
    for row in range(5):
        f = sheet.crop((0, row * 48, 48, row * 48 + 48)).resize((48 * k, 48 * k), Image.NEAREST)
        img.paste(f, (20, 60 + row * 210), f)
        a = sheet.crop((8 * 48 + 2 * 48, row * 48, 8 * 48 + 3 * 48, row * 48 + 48)).resize((48 * k, 48 * k), Image.NEAREST)
        img.paste(a, (240, 60 + row * 210), a)
        dd.text((480, 60 + row * 210 + 80), roles[row], font=font(30), fill="white")
    img.save(OUT / "4_current_units.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    style_reference()
    layout_guide()
    current_units()
