"""Campaign-100 unit atlas (baguette, macaron, chili, donut, waffle) from image-model sheets.

Input: docs/art/release_slice/unit_regen/source/<id>.webp, 1536x1024 on flat magenta, 4x2 cells of 384x512 in the order
idle, walk A, walk B, walk C / attack wind-up, attack hit, attack follow-through, defeated (PROMPTS.md in that folder).
Each cell is keyed, aligned, reduced 8x with a premultiplied box filter, cut to hard alpha and reduced to one palette
per unit. Frames are 64x48 with the feet at (24, 44), the same pivot convention as the other character pages.
Output: assets/art/roster10/roster10.png + roster10.json (atlas) and <id>.png 24x24 card portraits.
  python tools/art/release_slice/roster10_sheets.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "docs/art/release_slice/unit_regen/source"
OUT = ROOT / "assets/art/roster10"
IDS = ["baguette", "macaron", "chili", "donut", "waffle"]
CELL_W, CELL_H, SCALE = 384, 512, 8
FW, FH, PX, PY = 64, 48, 24, 44
COLOURS = 22
# animation -> cell numbers (1-based); "squash" is the idle cell with the body pressed down one pixel
ANIMS = {
    "idle": (["idle", "idle", "squash", "squash"], 4, True),
    "walk": ([2, 3, 4, 3], 8, True),
    "attack": ([1, 5, 6, 7], 8, False),
    "death": ([5, 8, 8, 8], 8, False),
}


def key(rgb: np.ndarray) -> np.ndarray:
    """Alpha 0..1: magenta and its anti-aliased fringe become transparent."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    magenta = np.minimum(r, b) - g                     # 255 on pure magenta, ~0 on art
    return np.clip((170.0 - magenta) / 90.0, 0.0, 1.0)


def cell(arr: np.ndarray, n: int):
    c, r = (n - 1) % 4, (n - 1) // 4
    return arr[r * CELL_H:(r + 1) * CELL_H, c * CELL_W:(c + 1) * CELL_W]


def anchors(rgb: np.ndarray, alpha: np.ndarray):
    """(head x, ground y) of a cell: head = mean x of the top quarter of the sprite, ground = lowest opaque row."""
    ys, xs = np.where(alpha > 0.5)
    top, bottom = ys.min(), ys.max()
    head = xs[ys < top + (bottom - top) * 0.25].mean()
    return float(head), int(bottom)


def reduce(rgb: np.ndarray, alpha: np.ndarray, dx: float, dy: float) -> np.ndarray:
    """Shift the cell so its anchor lands on the frame pivot, then 8x box-reduce (premultiplied) to FW x FH."""
    big = np.zeros((FH * SCALE, FW * SCALE, 4), np.float32)
    h, w = alpha.shape
    ox, oy = int(round(dx)), int(round(dy))
    ys0, xs0 = max(0, -oy), max(0, -ox)
    ys1, xs1 = min(h, FH * SCALE - oy), min(w, FW * SCALE - ox)
    if ys1 > ys0 and xs1 > xs0:
        big[ys0 + oy:ys1 + oy, xs0 + ox:xs1 + ox, :3] = rgb[ys0:ys1, xs0:xs1] * alpha[ys0:ys1, xs0:xs1, None]
        big[ys0 + oy:ys1 + oy, xs0 + ox:xs1 + ox, 3] = alpha[ys0:ys1, xs0:xs1]
    small = big.reshape(FH, SCALE, FW, SCALE, 4).mean(axis=(1, 3))
    a = small[..., 3:4]
    out = np.zeros((FH, FW, 4), np.uint8)
    solid = a[..., 0] >= 0.5
    out[..., :3] = np.where(solid[..., None], np.clip(small[..., :3] / np.maximum(a, 1e-6), 0, 255), 0).astype(np.uint8)
    out[..., 3] = np.where(solid, 255, 0)
    return out


def squash(frame: np.ndarray) -> np.ndarray:
    """Breathing frame: everything above the feet moves down one pixel, the feet (bottom 4 rows) stay."""
    out = frame.copy()
    body = frame[:PY - 3]
    out[1:PY - 2] = body
    out[0] = 0
    return out


def unit_frames(uid: str) -> dict:
    arr = np.asarray(Image.open(SRC / f"{uid}.webp").convert("RGB"), dtype=np.float32)
    alpha = key(arr)
    rgb = arr
    cells = {n: (cell(rgb, n), cell(alpha, n)) for n in range(1, 9)}
    head1, ground1 = anchors(*cells[1])
    feet = cells[1][1][ground1 - 3 * SCALE:ground1 + 1]
    fx = float(np.where(feet > 0.5)[1].mean())
    target_head = PX * SCALE + (head1 - fx)            # where the idle head sits in the 8x frame
    frames = {}
    row2_dx = None
    for n in range(1, 9):
        c_rgb, c_a = cells[n]
        head, ground = anchors(c_rgb, c_a)
        if n <= 4:
            dx = target_head - head
        else:
            if row2_dx is None:
                row2_dx = target_head - head           # cell 5 sets the row; the AI-drawn lunge of 6-8 is kept
            dx = row2_dx
            if n == 8:                                 # lying down reaches further left: keep it inside the frame
                dx = max(dx, SCALE - float(np.where(c_a > 0.5)[1].min()))
        dy = (PY + 1) * SCALE - 1 - ground
        frames[n] = reduce(c_rgb, c_a, dx, dy)
    frames["idle"] = frames[1]
    frames["squash"] = squash(frames[1])
    return frames


def blue_steel(frames: dict) -> dict:
    """Donut only: its steel helmet and frying pan were grey, which made the unit's mean colour match the grey-green
    mould enemies for protan/deutan viewers (suite_theme TH-COL). Grey metal becomes blue steel, value kept."""
    out = {}
    for k, f in frames.items():
        g = f.astype(np.float32)
        rgb = g[..., :3] / 255.0
        mx, mn = rgb.max(axis=2), rgb.min(axis=2)
        grey = (g[..., 3] > 0) & ((mx - mn) < 0.12) & (mx > 0.3) & (mx < 0.97)
        v = mx[grey]
        g[..., 0][grey] = np.clip(v * 0.62, 0, 1) * 255
        g[..., 1][grey] = np.clip(v * 0.74, 0, 1) * 255
        g[..., 2][grey] = np.clip(v * 1.02, 0, 1) * 255
        out[k] = g.astype(np.uint8)
    return out


def palette(frames: dict) -> dict:
    """One palette per unit across all frames, no dither."""
    keys = [k for k in frames]
    strip = np.concatenate([frames[k] for k in keys], axis=1)
    img = Image.fromarray(strip, "RGBA")
    rgb = img.convert("RGB").quantize(COLOURS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    q = np.asarray(rgb).copy()
    out = np.concatenate([q, strip[..., 3:4]], axis=2)
    out[out[..., 3] == 0] = 0
    return {k: out[:, i * FW:(i + 1) * FW] for i, k in enumerate(keys)}


def portrait(frame: np.ndarray) -> Image.Image:
    """24x24 card portrait centred on the face: the eyes are the darkest pixels in the upper part of the idle frame."""
    ys, xs = np.where(frame[..., 3] > 0)
    top, bottom = ys.min(), ys.max()
    lum = frame[..., :3].astype(int).sum(axis=2)
    upper = np.zeros_like(lum, bool)
    upper[top:top + int((bottom - top) * 0.6)] = True
    eyes = np.where((frame[..., 3] > 0) & upper & (lum <= np.percentile(lum[(frame[..., 3] > 0) & upper], 4)))
    cy, cx = int(round(eyes[0].mean())), int(round(eyes[1].mean()))
    x0 = int(np.clip(cx - 12, 0, FW - 24))
    y0 = int(np.clip(cy - 13, 0, FH - 24))
    return Image.fromarray(frame[y0:y0 + 24, x0:x0 + 24], "RGBA")


def main() -> None:
    sheet = np.zeros((FH * len(IDS), FW * 16, 4), np.uint8)
    atlas = {"schema": "defence.atlas/1", "atlas": "roster10", "frames": {}, "anims": {}}
    for row, uid in enumerate(IDS):
        raw = unit_frames(uid)
        frames = palette(blue_steel(raw) if uid == "donut" else raw)
        atlas["anims"][uid] = {}
        col = 0
        for name, (seq, fps, loop) in ANIMS.items():
            names = []
            for i, n in enumerate(seq):
                key_ = f"{uid}/{name}/{i}"
                x, y = col * FW, row * FH
                sheet[y:y + FH, x:x + FW] = frames[n]
                atlas["frames"][key_] = {"x": x, "y": y, "w": FW, "h": FH, "pivot": [PX, PY]}
                names.append(key_)
                col += 1
            atlas["anims"][uid][name] = {"frames": names, "fps": fps, "loop": loop, "hit_frame": 2}
        atlas["anims"][uid]["die"] = atlas["anims"][uid]["death"]
        portrait(frames["idle"]).save(OUT / f"{uid}.png")
    Image.fromarray(sheet, "RGBA").save(OUT / "roster10.png")
    (OUT / "roster10.json").write_text(json.dumps(atlas, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
