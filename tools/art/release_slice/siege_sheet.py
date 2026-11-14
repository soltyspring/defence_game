"""New 화덕포 (siege) atlas from the ChatGPT sheet: a baguette-barrel cannon on a wooden carriage, a toast gunner with a
lit taper and a pile of round bread shot (candidate D, docs/art/release_slice/siege_regen/PROMPTS.md, 2026-11-15).

Input: docs/art/gpt_sources/siege/siege_sheet.png, 1536x1024 on flat magenta, 4x2 cells of 384x512 in the order
idle, walk A, walk B, walk C / wind-up, shot, recoil, defeated.
The sheet is not drawn on an exact 8x grid, so every cell is scaled by one factor that makes the idle pose WIDTH
wide (premultiplied box filter), cut to hard alpha and reduced to one palette. All cells keep the same cell-relative
x anchor (the idle pose's centre) so the gun never slides; each cell's lowest opaque row sits on the ground row.
Output: assets/art/siege/siege.png + siege.json (atlas page `siege_v2`, anim_set `siege`) and siege_card.png (24x24).
  python tools/art/release_slice/siege_sheet.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "docs/art/gpt_sources/siege/siege_sheet.png"
OUT = ROOT / "assets/art/siege"
CELL_W, CELL_H, MARGIN = 384, 512, 6
WIDTH = 56                  # idle pose width in game pixels (the old oven was 48 wide and 40 tall)
FW, FH, PX, PY = 80, 48, 34, 44
COLOURS = 24
ANIMS = {
    "idle": (["idle", "idle", "squash", "squash"], 4, True),
    "walk": ([2, 3, 4, 3], 8, True),
    "attack": ([1, 5, 6, 7], 8, False),
    "hit": ([1], 8, False),
    "death": ([5, 8, 8, 8], 8, False),
}


def key(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return np.clip((170.0 - (np.minimum(r, b) - g)) / 90.0, 0.0, 1.0)


def cell(sheet: np.ndarray, n: int) -> np.ndarray:
    c, r = (n - 1) % 4, (n - 1) // 4
    return sheet[r * CELL_H + MARGIN:(r + 1) * CELL_H - MARGIN, c * CELL_W + MARGIN:(c + 1) * CELL_W - MARGIN]


def frames() -> dict:
    sheet = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
    cells = {n: cell(sheet, n) for n in range(1, 9)}
    a1 = key(cells[1])
    ys, xs = np.nonzero(a1 > 0.5)
    k = WIDTH / float(xs.max() + 1 - xs.min())
    anchor_x = (xs.min() + xs.max() + 1) / 2.0
    out = {}
    for n, c in cells.items():
        a = key(c)
        ys, _ = np.nonzero(a > 0.5)
        ground = ys.max() + 1
        h, w = a.shape
        nw, nh = round(w * k), round(h * k)
        pre = Image.fromarray(np.clip(c * a[..., None], 0, 255).astype(np.uint8), "RGB").resize((nw, nh), Image.BOX)
        al = np.asarray(Image.fromarray((a * 255).astype(np.uint8), "L").resize((nw, nh), Image.BOX)) / 255.0
        rgb = np.asarray(pre).astype(np.float64)
        rgb = np.where(al[..., None] > 0, rgb / np.maximum(al[..., None], 1e-6), 0)
        frame = np.zeros((FH, FW, 4), np.uint8)
        ox = PX - round(anchor_x * k)
        oy = (PY + 1) - round(ground * k)
        for y in range(nh):
            fy = y + oy
            if not 0 <= fy < FH: continue
            for x in range(nw):
                fx = x + ox
                if 0 <= fx < FW and al[y, x] >= 0.5:
                    frame[fy, fx, :3] = np.clip(rgb[y, x], 0, 255)
                    frame[fy, fx, 3] = 255
        out[n] = frame
    out["idle"] = out[1]
    sq = out[1].copy()                       # breathing: everything above the wheels' bottom 4 rows drops a pixel
    sq[1:PY - 2] = out[1][:PY - 3]
    sq[0] = 0
    out["squash"] = sq
    return out


def palette(fr: dict) -> dict:
    keys = list(fr)
    strip = np.concatenate([fr[k] for k in keys], axis=1)
    q = np.asarray(Image.fromarray(strip, "RGBA").convert("RGB").quantize(COLOURS, method=Image.Quantize.MEDIANCUT,
                                                                         dither=Image.Dither.NONE).convert("RGB"))
    out = np.concatenate([q, strip[..., 3:4]], axis=2)
    out[out[..., 3] == 0] = 0
    return {k: out[:, i * FW:(i + 1) * FW] for i, k in enumerate(keys)}


def portrait(frame: np.ndarray) -> Image.Image:
    """24x24 card portrait: the gunner's face, the wheel and the barrel's breech (left-centre of the idle pose)."""
    ys, xs = np.nonzero(frame[..., 3] > 0)
    left, right, top, bottom = xs.min(), xs.max(), ys.min(), ys.max()
    x0 = int(np.clip(round(left + (right - left) * 0.36) - 12, 0, FW - 24))
    y0 = int(np.clip((top + bottom) // 2 - 12, 0, FH - 24))
    return Image.fromarray(frame[y0:y0 + 24, x0:x0 + 24], "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fr = palette(frames())
    n = sum(len(seq) for seq, _, _ in ANIMS.values())
    page = np.zeros((FH, FW * n, 4), np.uint8)
    atlas = {"schema": "defence.atlas/1", "atlas": "siege_v2", "frames": {}, "anims": {"siege": {}}}
    col = 0
    for name, (seq, fps, loop) in ANIMS.items():
        names = []
        for i, c in enumerate(seq):
            k = f"siege/{name}/{i}"
            page[:, col * FW:(col + 1) * FW] = fr[c]
            atlas["frames"][k] = {"x": col * FW, "y": 0, "w": FW, "h": FH, "pivot": [PX, PY]}
            names.append(k)
            col += 1
        atlas["anims"]["siege"][name] = {"frames": names, "fps": fps, "loop": loop, "hit_frame": 2}
    atlas["anims"]["siege"]["die"] = atlas["anims"]["siege"]["death"]
    Image.fromarray(page, "RGBA").save(OUT / "siege.png", optimize=True)
    (OUT / "siege.json").write_text(json.dumps(atlas, indent=2) + "\n", encoding="utf-8")
    portrait(fr["idle"]).save(OUT / "siege_card.png")
    print("page", page.shape[1], "x", page.shape[0])


if __name__ == "__main__":
    main()
