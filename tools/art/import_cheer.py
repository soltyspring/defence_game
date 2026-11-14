"""Victory cheer frames (4 per unit) from the supplied ChatGPT sheets.

Input: docs/art/gpt_sources/cheer/cheer_N.png, 1536x1024 on flat magenta, 2 rows x 4 cells (384x512) with a white
ground line in each cell (docs/art/release_slice/cheer_regen/PROMPTS.md). Some sheets also have thin cell borders,
so a margin inside every cell is ignored.
Only units whose sheet matches the in-game sprite are imported (USE below); the others wait for a redraw.
Each cell is keyed, scaled so the first (crouch) pose is as tall as the unit's in-game idle frame (SCALE_FIX trims a few), reduced with a
premultiplied box filter, cut to hard alpha and colour-matched to the unit's in-game sprite (same mean/spread, then only in-game colours). The pivot is the feet on the
ground line, at the in-game sprite's pivot x (as a share of the crouch pose), the same in all four frames, so jumps keep their height and nothing jitters sideways.
Output: assets/art/cheer/cheer.png + cheer.json {anim_set: {"frames": [[x, y, w, h], ...], "pivot": [px, py]}}
  python tools/art/import_cheer.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs/art/gpt_sources/cheer"
OUT = ROOT / "assets/art/cheer"
CELL_W, CELL_H, MARGIN = 384, 512, 10
# per-unit size trim after the height match: the oven sheet is drawn wider than the game's oven
SCALE_FIX = {"siege": 0.8, "melee_basic": 0.85}
# per-unit frame swaps: the toast's landing pose stretches its legs; it ends on its happy crouch instead
FRAME_SUB = {"melee_basic": {3: 0}}
# anim_set: (sheet, row) — only sheets drawn from the sprites the game really uses
USE = {
    "hero_captain": (1, 0),
    "baguette": (4, 0), "macaron": (4, 1),
    "chili": (5, 0), "donut": (5, 1),
    "waffle": (6, 0),
    "worker": (6, 1),          # the first apprentice sheet (2026-11-15 user: better than the redraw in sheet 9)
    "melee_basic": (7, 0), "ranged_basic": (7, 1),
    "tank": (8, 0), "fast": (8, 1),
    "siege": (9, 0),
}
# in-game idle frame of each set: (atlas json, atlas png) — the page assets/manifest.json anim_sets really uses
GAME = {
    "hero_captain": ("assets/art/gpt/gpt_bakery_crew.json", "assets/art/gpt/gpt_bakery_crew.png"),
}
for _s in ("baguette", "macaron", "chili", "donut", "waffle"):
    GAME[_s] = ("assets/art/roster10/roster10.json", "assets/art/roster10/roster10.png")
GAME["worker"] = GAME["hero_captain"]
GAME["melee_basic"] = ("assets/art/release_slice/slice_chars.json", "assets/art/release_slice/slice_chars.png")
for _s in ("ranged_basic", "tank", "fast", "siege"):
    GAME[_s] = ("assets/art/release_slice/slice_chars2.json", "assets/art/release_slice/slice_chars2.png")


def key(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return np.clip((170.0 - (np.minimum(r, b) - g)) / 90.0, 0.0, 1.0)


def game_idle(aset: str):
    """Height of the in-game idle frame's art and where its pivot sits across that art (0 = left, 1 = right)."""
    js, png = GAME[aset]
    a = json.loads((ROOT / js).read_text(encoding="utf-8"))
    img = Image.open(ROOT / png).convert("RGBA")
    v = a["frames"][a["anims"][aset]["idle"]["frames"][0]]
    f = img.crop((v["x"], v["y"], v["x"] + v["w"], v["y"] + v["h"]))
    bb = f.getbbox()
    return bb[3] - bb[1], bb[2] - bb[0], (float(v["pivot"][0]) - bb[0]) / float(bb[2] - bb[0])


def game_pixels(aset: str) -> np.ndarray:
    """Every opaque pixel of the unit's in-game idle / walk / attack frames (N x 3, 0..255)."""
    js, png = GAME[aset]
    a = json.loads((ROOT / js).read_text(encoding="utf-8"))
    img = np.asarray(Image.open(ROOT / png).convert("RGBA"))
    px = []
    for anim in ("idle", "walk", "attack"):
        for fn in a["anims"][aset].get(anim, {}).get("frames", []):
            v = a["frames"][fn]
            f = img[v["y"]:v["y"] + v["h"], v["x"]:v["x"] + v["w"]].reshape(-1, 4)
            px.append(f[f[:, 3] > 127][:, :3])
    return np.concatenate(px).astype(np.float64)


def to_lab(rgb: np.ndarray) -> np.ndarray:
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    xyz = c @ np.array([[0.4124, 0.2126, 0.0193], [0.3576, 0.7152, 0.1192], [0.1805, 0.0722, 0.9505]])
    xyz = xyz / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16.0 / 116.0)
    return np.stack([116.0 * f[:, 1] - 16.0, 500.0 * (f[:, 0] - f[:, 1]), 200.0 * (f[:, 1] - f[:, 2])], axis=1)


def match_colours(frames, aset: str):
    """Colour-correct the cheer to the in-game sprite (2026-11-15 user: e.g. the roll came out darker): move the
    cheer's Lab mean / spread onto the game sprite's, then paint every pixel with its nearest in-game colour."""
    game = game_pixels(aset)
    pal = np.unique(game.astype(np.uint8), axis=0).astype(np.float64)
    pal_lab = to_lab(pal)
    g_lab = to_lab(game)
    c_lab = to_lab(np.concatenate([f[0][f[1]] for f in frames]).astype(np.float64))
    mu_g, sd_g = g_lab.mean(0), g_lab.std(0) + 1e-6
    mu_c, sd_c = c_lab.mean(0), c_lab.std(0) + 1e-6
    gain = np.clip(sd_g / sd_c, 0.7, 1.4)
    out = []
    for rgb, on in frames:
        flat = rgb.reshape(-1, 3).astype(np.float64)
        lab = (to_lab(flat) - mu_c) * gain + mu_g
        d = ((lab[:, None, :] - pal_lab[None, :, :]) ** 2).sum(-1)
        q = pal[d.argmin(1)].reshape(rgb.shape).astype(np.uint8)
        out.append(Image.fromarray(np.dstack([q, np.where(on, 255, 0).astype(np.uint8)]), "RGBA"))
    return out


def cells(sheet: np.ndarray, row: int):
    out = []
    for c in range(4):
        y0, x0 = row * CELL_H + MARGIN, c * CELL_W + MARGIN
        cell = sheet[y0:y0 + CELL_H - 2 * MARGIN, x0:x0 + CELL_W - 2 * MARGIN].copy()
        a = key(cell)
        white = cell.min(axis=2) > 200
        ground = None
        for y in range(cell.shape[0]):
            if white[y].mean() > 0.5:
                a[y] = 0.0
                ground = y if ground is None else ground
        out.append((cell, a, ground))
    return out


def unit(sheet: np.ndarray, row: int, aset: str):
    cs = cells(sheet, row)
    grounds = [g for _, _, g in cs if g is not None]
    ground = int(np.median(grounds)) if grounds else cs[0][0].shape[0] - 40
    a0 = cs[0][1]
    ys, xs = np.nonzero(a0 > 0.5)
    gh, gw, ratio = game_idle(aset)
    k = gh / float(ys.max() + 1 - ys.min()) * SCALE_FIX.get(aset, 1.0)
    px_cell = xs.min() + ratio * (xs.max() + 1 - xs.min())     # same foot point as the game sprite (waffle: its body)
    frames = []
    for cell, a, _ in cs:
        pre = np.dstack([cell * a[..., None], a])
        h, w = a.shape
        nw, nh = max(1, round(w * k)), max(1, round(h * k))
        img = Image.fromarray(np.clip(pre[..., :3], 0, 255).astype(np.uint8), "RGB").resize((nw, nh), Image.BOX)
        al = Image.fromarray((a * 255).astype(np.uint8), "L").resize((nw, nh), Image.BOX)
        rgb = np.asarray(img).astype(np.float64)
        aa = np.asarray(al).astype(np.float64) / 255.0
        rgb = np.where(aa[..., None] > 0, rgb / np.maximum(aa[..., None], 1e-6), 0)
        frames.append((np.clip(rgb, 0, 255).astype(np.uint8), aa >= 0.5))
    out = match_colours(frames, aset)
    for dst, src in FRAME_SUB.get(aset, {}).items():
        out[dst] = out[src].copy()
    # trim all four frames to one shared box so the pivot stays put
    boxes = [im.getbbox() for im in out]
    l = min(b[0] for b in boxes); t = min(b[1] for b in boxes)
    r = max(b[2] for b in boxes); b = max(b[3] for b in boxes)
    out = [im.crop((l, t, r, b)) for im in out]
    pivot = [round(px_cell * k) - l, round(ground * k) - t]
    return out, pivot


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {}
    units = {}
    for aset, (n, row) in USE.items():
        if n not in sheets:
            sheets[n] = np.asarray(Image.open(SRC / f"cheer_{n}.png").convert("RGB")).astype(np.float64)
        units[aset] = unit(sheets[n], row, aset)
    pad = 2
    width = max(sum(f.width + pad for f in fr) for fr, _ in units.values()) + pad
    height = sum(max(f.height for f in fr) + pad for fr, _ in units.values()) + pad
    page = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    meta = {}
    y = pad
    for aset, (fr, pivot) in units.items():
        x = pad
        rects = []
        for f in fr:
            page.alpha_composite(f, (x, y))
            rects.append([x, y, f.width, f.height])
            x += f.width + pad
        meta[aset] = {"frames": rects, "pivot": pivot}
        y += max(f.height for f in fr) + pad
    page.save(OUT / "cheer.png", optimize=True)
    (OUT / "cheer.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    for aset, m in meta.items():
        print(aset, m["frames"][0][2:], "pivot", m["pivot"])


if __name__ == "__main__":
    main()
