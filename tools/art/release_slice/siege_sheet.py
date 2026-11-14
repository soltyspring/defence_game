"""New 화덕포 (siege) atlas from the ChatGPT sheet: a baguette-barrel cannon on a wooden carriage, a toast gunner with a
lit taper and a pile of round bread shot (candidate D, docs/art/release_slice/siege_regen/PROMPTS.md, 2026-11-15).

Input: docs/art/gpt_sources/siege/siege_sheet.png, 1536x1024 on flat magenta, 4x2 cells of 384x512 in the order
idle, walk A, walk B, walk C / wind-up, shot, recoil, defeated.
The sheet is not drawn on an exact 8x grid, so every cell is scaled by one factor that makes the idle pose WIDTH
wide (premultiplied box filter), cut to hard alpha and reduced to one palette. All cells keep the same cell-relative
x anchor (the idle pose's centre) so the gun never slides; each cell's lowest opaque row sits on the ground row.
Output: assets/art/siege/siege.png + siege.json (atlas page `siege_v2`: anim_sets `siege` and the projectile `bread_ball`)
and siege_card.png (24x24).
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


BALL = 11                   # bread shot sprite size (the grey rock was 10)


def bread_ball() -> list:
    """The round cross-scored bread shot flying out of the muzzle in cell 6, cut out and spun in four quarter turns."""
    sheet = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
    c = cell(sheet, 6)
    a = key(c)
    h, w = a.shape
    mx, mn = c.max(axis=2), c.min(axis=2)
    smoke = (mx > 200) & ((mx - mn) / np.maximum(mx, 1) < 0.3)       # the cream flour puffs around the ball
    m = (a > 0.5) & ~smoke
    m[:, :int(w * 0.72)] = False
    m[int(h * 0.45):] = False
    m = largest_blob(m)                                               # drop stray flour specks
    ys, xs = np.nonzero(m)
    cy, cx = (ys.min() + ys.max() + 1) / 2.0, (xs.min() + xs.max() + 1) / 2.0
    half = max(ys.max() + 1 - ys.min(), xs.max() + 1 - xs.min()) / 2.0 + 2   # square crop: the ball stays round
    y0, y1 = int(round(cy - half)), int(round(cy + half))
    x0, x1 = int(round(cx - half)), int(round(cx + half))
    pad = np.zeros((h + 200, w + 200, 4))
    pad[100:100 + h, 100:100 + w, :3] = c
    pad[100:100 + h, 100:100 + w, 3] = np.where(m, a, 0) * 255
    rgba = pad[y0 + 100:y1 + 100, x0 + 100:x1 + 100].astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    inner = BALL - 2                                                  # leave a pixel each side for the outline
    pre = Image.fromarray(np.clip(rgba[..., :3] * (rgba[..., 3:4] / 255.0), 0, 255).astype(np.uint8), "RGB").resize((inner, inner), Image.BOX)
    al = np.asarray(img.getchannel("A").resize((inner, inner), Image.BOX)) / 255.0
    rgb = np.where(al[..., None] > 0, np.asarray(pre) / np.maximum(al[..., None], 1e-6), 0)
    base = np.dstack([np.clip(rgb, 0, 255), np.where(al >= 0.5, 255, 0)]).astype(np.uint8)
    q = np.asarray(Image.fromarray(base, "RGBA").convert("RGB").quantize(8, method=Image.Quantize.MEDIANCUT,
                                                                         dither=Image.Dither.NONE).convert("RGB"))
    core = np.dstack([q, base[..., 3]])
    core[core[..., 3] == 0] = 0
    base = np.zeros((BALL, BALL, 4), np.uint8)
    base[1:-1, 1:-1] = core
    on = base[..., 3] > 0
    ring = np.zeros_like(on)                                          # 1-px dark crust outline, like the old shot
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        ring |= np.roll(np.roll(on, dy, 0), dx, 1)
    ring &= ~on
    base[ring] = (54, 28, 20, 255)
    return [np.rot90(base, -i).copy() for i in range(4)]


def largest_blob(m: np.ndarray) -> np.ndarray:
    """4-connected component with the most pixels."""
    seen = np.zeros_like(m)
    best = None
    for y, x in zip(*np.nonzero(m)):
        if seen[y, x]: continue
        stack, comp = [(y, x)], []
        seen[y, x] = True
        while stack:
            cy, cx = stack.pop()
            comp.append((cy, cx))
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if best is None or len(comp) > len(best): best = comp
    out = np.zeros_like(m)
    for y, x in best: out[y, x] = True
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
    # projectile `bread_ball` (data/units/units.json siege.projectile): 4 spin frames under the unit row
    balls = bread_ball()
    page = np.concatenate([page, np.zeros((BALL + 2, page.shape[1], 4), np.uint8)], axis=0)
    names = []
    for i, b in enumerate(balls):
        x, y = 2 + i * (BALL + 2), FH + 1
        page[y:y + BALL, x:x + BALL] = b
        k = f"bread_ball/fly/{i}"
        atlas["frames"][k] = {"x": x, "y": y, "w": BALL, "h": BALL, "pivot": [BALL // 2, BALL // 2]}
        names.append(k)
    atlas["anims"]["bread_ball"] = {"fly": {"frames": names, "fps": 12, "loop": True}}
    Image.fromarray(page, "RGBA").save(OUT / "siege.png", optimize=True)
    (OUT / "siege.json").write_text(json.dumps(atlas, indent=2) + "\n", encoding="utf-8")
    portrait(fr["idle"]).save(OUT / "siege_card.png")
    print("page", page.shape[1], "x", page.shape[0])


if __name__ == "__main__":
    main()
