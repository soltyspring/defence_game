"""Chapter background tiles from two generated 3:1 images per chapter (docs/art/release_slice/bg_regen/source/<name>_A/B).

A and B are scaled to 544x176 logical pixels and overlapped by 32 px at both joins (A|B and the wrap B|A), cut along
the least-difference path through each overlap, giving one 1024x176 tile that repeats without flips. Then 32 colours, no dither, and a 4x nearest
upscale to 4096x704 (the size src/gameplay/painted_chapter_backdrop.gd reads). The bottom edge is the scene's own
ground: the game should put the road directly under it (no flat band to trim).
  python tools/art/release_slice/bg_tiles.py            -> docs/art/release_slice/bg_regen/tiles/*.png + previews
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "docs/art/release_slice/bg_regen/source"
OUT = ROOT / "docs/art/release_slice/bg_regen/tiles"
SLICE = ROOT / "assets/art/release_slice"
NAMES = ["frost_quarry", "spore_marsh", "frozen_bastion", "root_vault", "aurora_pass", "mould_heart"]
ROUNDS = ["R41-50", "R51-60", "R61-70", "R71-80", "R81-90", "R91-100"]
W, H, LAP = 1024, 176, 32
PART = (W + 2 * LAP) // 2
COLOURS = 32


def part(name: str, side: str) -> np.ndarray:
    im = Image.open(SRC / f"{name}_{side}.webp").convert("RGB")
    return np.asarray(im.resize((PART, H), Image.LANCZOS), dtype=np.float32)


def seam(left: np.ndarray, right: np.ndarray) -> np.ndarray:
    """Least-difference top-to-bottom cut through two overlapping strips (H x LAP x 3): per row, the first column
    that comes from the right strip. Objects are cut where they differ least instead of showing as ghosts."""
    cost = np.abs(left - right).sum(axis=2)
    acc = cost.copy()
    for y in range(1, H):
        prev = acc[y - 1]
        best = np.minimum(prev, np.minimum(np.r_[prev[1:], np.inf], np.r_[np.inf, prev[:-1]]))
        acc[y] += best
    cut = np.zeros(H, int)
    cut[-1] = int(np.argmin(acc[-1]))
    for y in range(H - 2, -1, -1):
        x = cut[y + 1]
        lo, hi = max(0, x - 1), min(LAP, x + 2)
        cut[y] = lo + int(np.argmin(acc[y, lo:hi]))
    return cut


def tile(name: str) -> Image.Image:
    a, b = part(name, "A"), part(name, "B")
    out = np.zeros((H, W, 3), np.float32)
    out[:, :PART] = a
    out[:, PART - LAP:W] = b[:, :W - PART + LAP]
    joins = ((a[:, PART - LAP:], b[:, :LAP], PART - LAP), (b[:, PART - LAP:], a[:, :LAP], 0))
    for left, right, x0 in joins:            # A|B in the middle, B|A at the wrap (x 0..LAP)
        cut = seam(left, right)
        for y in range(H):
            row = np.concatenate([left[y, :cut[y]], right[y, cut[y]:]])
            out[y, x0:x0 + LAP] = row
    flat = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    return flat.quantize(COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")


_pages: dict = {}


def sprite(page: str, frame: str):
    if page not in _pages:
        _pages[page] = (Image.open(SLICE / f"{page}.png").convert("RGBA"), json.loads((SLICE / f"{page}.json").read_text())["frames"])
    img, frames = _pages[page]
    f = frames[frame]
    return img.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"])), f["pivot"]


CAST = [("slice_chars", "hero_captain/idle/0", 70), ("slice_chars", "melee_basic/idle/0", 100), ("slice_chars2", "tank/idle/0", 120),
        ("slice_chars2", "ranged_basic/idle/0", 140), ("slice_chars", "e_grunt/idle/0", 215), ("slice_chars2", "e_brute/idle/0", 250),
        ("slice_chars2", "e_spitter/idle/0", 280)]


def screen(t: Image.Image, x0: int) -> Image.Image:
    """One 320x180 game view: tile bottom on the road top (y 156), feet at y 163."""
    wide = Image.new("RGB", (W * 2, H))
    wide.paste(t, (0, 0))
    wide.paste(t, (W, 0))
    c = Image.new("RGBA", (320, 180))
    c.paste(wide.crop((x0, H - 156, x0 + 320, H)), (0, 0))
    d = ImageDraw.Draw(c)
    d.rectangle([0, 156, 320, 173], fill="#c1a878")
    d.rectangle([0, 156, 320, 157], fill="#a18c5e")
    d.rectangle([0, 171, 320, 172], fill="#967c55")
    d.rectangle([0, 173, 320, 180], fill="#675340")
    for page, frame, x in CAST:
        s, p = sprite(page, frame)
        if frame.startswith("e_"):
            s, p = s.transpose(Image.FLIP_LEFT_RIGHT), [s.width - 1 - p[0], p[1]]
        c.alpha_composite(s, (x - p[0], 163 - p[1]))
    return c.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default(size=22)
    sheet = Image.new("RGB", (W * 2, len(NAMES) * (H * 2 + 36)), (16, 16, 16))
    views = Image.new("RGB", (3 * 960 + 20, len(NAMES) * 576), (16, 16, 16))
    for i, (name, rounds) in enumerate(zip(NAMES, ROUNDS)):
        t = tile(name)
        t.resize((W * 4, H * 4), Image.NEAREST).save(OUT / f"{name}.png")
        y = i * (H * 2 + 36)
        ImageDraw.Draw(sheet).text((8, y + 6), f"{rounds} {name}  (joins at x=0 and x={PART - LAP})", font=font, fill="white")
        sheet.paste(t.resize((W * 2, H * 2), Image.NEAREST), (0, y + 32))
        for k, x0 in enumerate((120, 560, W - 160)):     # A part, B part, the wrap join
            v = screen(t, x0).resize((960, 540), Image.NEAREST)
            ImageDraw.Draw(v).text((10, 8), f"{rounds} {name}  x={x0}", font=font, fill="white", stroke_width=3, stroke_fill="black")
            views.paste(v, (k * 970, i * 576))
    sheet.save(OUT / "_sheet.png")
    views.save(OUT / "_in_game.png")


if __name__ == "__main__":
    main()
