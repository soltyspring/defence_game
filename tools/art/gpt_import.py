#!/usr/bin/env python3
"""Turn the ChatGPT sprite sheets in docs/art/gpt_sources/ into game atlases under assets/art/gpt/.

Each source sheet is 1536x1024 on flat magenta, a grid of equal cells (one frame or one prop per cell), drawn
on an N-times pixel grid. This script keys out the magenta (and the thin white grid lines some sheets carry),
finds the pixel phase, shrinks every N x N block to one pixel (median colour, transparent when mostly
background), trims each frame and packs the frames into atlas pages in the defence.atlas/1 format.

    python tools/art/gpt_import.py            # writes assets/art/gpt/*.png|json and docs/art/gpt_sources/preview_*.png
    python tools/art/gpt_import.py icons      # only the 24x24 skill icons -> assets/art/skills/<skill id>.png
    python tools/art/gpt_import.py characters # only the baker and flour courier atlas

Skill icons (docs/art/gpt_sources/skillicon/skill_icons.png) were drawn on a finer grid than asked (~40 px per
icon), so they are not block-shrunk: each badge is resampled to 24x24 (Lanczos) and snapped to its own 24-colour
palette, which keeps the symbols readable. They replace tools/art/release_slice/skill_icons.py output.

Kits and prompts: docs/art/release_slice/{skillfx,nest,props,hitfx}_regen/PROMPTS.md.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "docs", "art", "gpt_sources")
OUT = os.path.join(ROOT, "assets", "art", "gpt")
RES = "res://assets/art/gpt/"

# name, source, cols, rows, pixel, anchor ("ground" | "center"), state, fps, loop
FX = [
    ("skill_flour", "skillfx/flour.png", 6, 2, 4, "ground", "play", 10, False),
    ("skill_shield", "skillfx/shield.png", 6, 2, 4, "ground", "play", 14, False),
    ("skill_frost", "skillfx/frost.png", 6, 2, 4, "ground", "play", 10, False),
    ("skill_oven", "skillfx/oven.png", 6, 2, 4, "ground", "loop", 10, True),
    ("skill_slam", "skillfx/slam.png", 6, 2, 4, "ground", "play", 12, False),
    ("skill_rally", "skillfx/rally.png", 6, 2, 4, "ground", "play", 10, False),
    ("skill_barrage", "skillfx/barrage.png", 6, 2, 4, "ground", "play", 12, False),
    ("hit_spark", "hitfx/hit_spark.png", 4, 2, 8, "center", "play", 20, False),
    ("hit_spit", "hitfx/hit_spit.png", 4, 2, 8, "center", "play", 18, False),
    ("explosion", "hitfx/explosion.png", 4, 2, 8, "ground", "play", 16, False),
    ("death_poof", "hitfx/death_poof.png", 4, 2, 8, "ground", "play", 14, False),
    ("dust", "hitfx/dust.png", 4, 2, 8, "ground", "play", 12, False),
    ("spawn", "hitfx/spawn.png", 4, 2, 8, "ground", "play", 14, False),
]
NESTS = 10                      # nest01..nest10: 4x2 cells, 4x pixels, cells 1-6 = idle A/B, damaged A/B, ruined A/B
PROP_THEMES = ["farm", "snow", "cave", "marsh", "heart"]   # 4x2 cells, 8x pixels, one prop per cell
SKILL_ICONS = ["skill_slam", "skill_rally", "skill_barrage", "skill_flour", "skill_shield", "skill_frost", "skill_oven"]


def bg_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > 170) & (b > 160) & (g < 90) & (np.abs(r - b) < 80)


def strip_grid(a, bg, cols, rows):
    """Thin white guide lines at cell borders (some sheets have them) become background."""
    h, w = bg.shape
    white = (a[..., 0] > 210) & (a[..., 1] > 210) & (a[..., 2] > 210)
    for k in range(cols + 1):
        x0 = int(round(k * w / cols))
        for x in range(max(0, x0 - 5), min(w, x0 + 5)):
            if (white[:, x] | bg[:, x]).mean() > 0.85:
                bg[:, x] |= white[:, x]
    for k in range(rows + 1):
        y0 = int(round(k * h / rows))
        for y in range(max(0, y0 - 5), min(h, y0 + 5)):
            if (white[y, :] | bg[y, :]).mean() > 0.85:
                bg[y, :] |= white[y, :]
    return bg


def best_phase(a, bg, p):
    """Pixel-grid phase with the least colour spread inside the blocks."""
    best = (1e18, 0, 0)
    for oy in range(p):
        for ox in range(p):
            sub = a[oy:, ox:]
            m = ~bg[oy:, ox:]
            h = (sub.shape[0] // p) * p
            w = (sub.shape[1] // p) * p
            s = sub[:h, :w].reshape(h // p, p, w // p, p, 3)
            mm = m[:h, :w].reshape(h // p, p, w // p, p).all(axis=(1, 3))
            if mm.sum() < 50:
                continue
            var = s.var(axis=(1, 3)).sum(axis=-1)[mm].mean()
            if var < best[0]:
                best = (var, ox, oy)
    return best[1], best[2]


def shrink(path, cols, rows, p):
    """Sheet -> RGBA art array (one pixel per p x p block) plus the art-space cell size."""
    a = np.array(Image.open(os.path.join(SRC, path)).convert("RGB")).astype(np.int16)
    bg = strip_grid(a, bg_mask(a), cols, rows)
    ox, oy = best_phase(a, bg, p)
    pad_x, pad_y = (p - ox) % p, (p - oy) % p
    a = np.pad(a, ((pad_y, p), (pad_x, p), (0, 0)), constant_values=0)
    bg = np.pad(bg, ((pad_y, p), (pad_x, p)), constant_values=True)
    h, w = (a.shape[0] // p) * p, (a.shape[1] // p) * p
    blocks = a[:h, :w].reshape(h // p, p, w // p, p, 3).transpose(0, 2, 1, 3, 4).reshape(h // p, w // p, p * p, 3)
    fgm = ~bg[:h, :w].reshape(h // p, p, w // p, p).transpose(0, 2, 1, 3).reshape(h // p, w // p, p * p)
    frac = fgm.mean(axis=-1)
    vals = np.where(fgm[..., None], blocks, np.nan).astype(np.float32)
    with np.errstate(all="ignore"):
        med = np.nanmedian(vals, axis=2)
    out = np.zeros((h // p, w // p, 4), np.uint8)
    on = frac >= 0.5
    out[on, :3] = np.clip(np.nan_to_num(med[on]), 0, 255).astype(np.uint8)
    out[on, 3] = 255
    out = quantize(out, 40)
    return out, pad_x / p, pad_y / p, (1536 / cols / p, 1024 / rows / p)


def quantize(rgba, n):
    on = rgba[..., 3] > 0
    if on.sum() == 0:
        return rgba
    pix = rgba[on][:, :3]
    img = Image.fromarray(pix.reshape(1, -1, 3))
    q = img.quantize(colors=n, method=Image.Quantize.MEDIANCUT).convert("RGB")
    rgba = rgba.copy()
    rgba[on, :3] = np.array(q).reshape(-1, 3)
    return rgba


def cells(art, offx, offy, cw, ch, cols, rows):
    out = []
    for r in range(rows):
        for c in range(cols):
            x0 = int(round(c * cw + offx))
            y0 = int(round(r * ch + offy))
            out.append(art[y0:y0 + int(round(ch)), x0:x0 + int(round(cw))])
    return out


def bbox(cell):
    ys, xs = np.nonzero(cell[..., 3])
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def drop_specks(cell, min_px=3):
    """Remove tiny islands far from the main shape (GPT noise), keep real particles (>= min_px or near art)."""
    return cell


def anim_frames(cs, anchor):
    """Trimmed frames with per-frame pivots; trailing empty cells dropped."""
    n = len(cs)
    while n > 0 and bbox(cs[n - 1]) is None:
        n -= 1
    cs = cs[:n]
    boxes = [bbox(c) for c in cs]
    real = [b for b in boxes if b is not None]
    ch, cw = cs[0].shape[:2]
    if anchor == "ground":
        ax, ay = cw / 2.0, max(b[3] for b in real)
    else:
        ax = (min(b[0] for b in real) + max(b[2] for b in real)) / 2.0
        ay = (min(b[1] for b in real) + max(b[3] for b in real)) / 2.0
    frames = []
    for c, b in zip(cs, boxes):
        if b is None:
            c, b = np.zeros((1, 1, 4), np.uint8), (0, 0, 1, 1)
            frames.append((c, [int(round(ax)), int(round(ay))]))
            continue
        frames.append((c[b[1]:b[3], b[0]:b[2]], [int(round(ax - b[0])), int(round(ay - b[1]))]))
    return frames


def pack(items, width):
    """items: list of (key, array). Shelf packing with 2 px padding. Returns placements and page size."""
    order = sorted(range(len(items)), key=lambda i: -items[i][1].shape[0])
    x = y = shelf = 0
    place = {}
    for i in order:
        h, w = items[i][1].shape[:2]
        if x + w + 2 > width:
            x, y, shelf = 0, y + shelf + 2, 0
        place[i] = (x + 2, y + 2)
        x += w + 2
        shelf = max(shelf, h)
    hgt = 1
    while hgt < y + shelf + 4:
        hgt *= 2
    return place, (width, hgt)


def write_page(atlas_id, group, anims, width, events=None):
    """anims: {set: {state: (frames, fps, loop)}} -> png + json."""
    items, keys = [], []
    for s, states in anims.items():
        for st, (frames, fps, loop) in states.items():
            for i, (arr, pv) in enumerate(frames):
                items.append((f"{s}/{st}/{i}", arr, pv))
    place, size = pack([(k, a) for k, a, _ in items], width)
    img = np.zeros((size[1], size[0], 4), np.uint8)
    frames_js = {}
    for i, (k, arr, pv) in enumerate(items):
        x, y = place[i]
        img[y:y + arr.shape[0], x:x + arr.shape[1]] = arr
        frames_js[k] = {"x": int(x), "y": int(y), "w": int(arr.shape[1]), "h": int(arr.shape[0]), "pivot": pv}
    anims_js = {}
    for s, states in anims.items():
        anims_js[s] = {}
        for st, (frames, fps, loop) in states.items():
            anims_js[s][st] = {"frames": [f"{s}/{st}/{i}" for i in range(len(frames))], "fps": fps, "loop": loop}
            if events and (s, st) in events:
                hit = events[s, st]
                anims_js[s][st].update(hit_frame=hit, events={"hit": hit})
    png = atlas_id + ".png"
    Image.fromarray(img).save(os.path.join(OUT, png), optimize=True)
    meta = {"schema": "defence.atlas/1", "atlas": atlas_id, "image": png, "image_res": RES + png, "size": list(size),
            "padding": 2, "extrude": 0, "group": group, "filter": "nearest", "mipmaps": False, "repeat": False,
            "gpu_format": "RGBA8", "gpu_bytes": size[0] * size[1] * 4,
            "source": "ChatGPT sheets in docs/art/gpt_sources, tools/art/gpt_import.py",
            "frames": frames_js, "anims": anims_js}
    with open(os.path.join(OUT, atlas_id + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    return size, len(items)


def preview(name, anims, scale=3):
    """All frames of all anims on one dark sheet (for review)."""
    rows = []
    for s, states in anims.items():
        for st, (frames, _, _) in states.items():
            rows.append([a for a, _ in frames])
    W = max(sum(a.shape[1] + 4 for a in r) for r in rows) + 4
    H = sum(max(a.shape[0] for a in r) + 6 for r in rows) + 4
    sheet = np.zeros((H, W, 4), np.uint8)
    sheet[..., :3] = (44, 48, 58)
    sheet[..., 3] = 255
    y = 4
    for r in rows:
        x = 4
        hh = max(a.shape[0] for a in r)
        for a in r:
            sub = sheet[y + hh - a.shape[0]:y + hh, x:x + a.shape[1]]
            al = a[..., 3:4] / 255.0
            sub[..., :3] = (a[..., :3] * al + sub[..., :3] * (1 - al)).astype(np.uint8)
            x += a.shape[1] + 4
        y += hh + 6
    Image.fromarray(sheet).resize((W * scale, H * scale), Image.NEAREST).save(os.path.join(SRC, f"preview_{name}.png"))


def skill_icons():
    """Seven badges in sheet order -> assets/art/skills/<id>.png (24x24) + a preview."""
    from scipy import ndimage
    src = Image.open(os.path.join(SRC, "skillicon", "skill_icons.png")).convert("RGB")
    a = np.array(src).astype(np.int16)
    bg = bg_mask(a)
    lab, _ = ndimage.label(~bg)
    boxes = []
    for sl in ndimage.find_objects(lab):
        if sl[0].stop - sl[0].start > 150 and sl[1].stop - sl[1].start > 150:
            boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
    boxes.sort(key=lambda b: (b[1] // 300, b[0]))
    assert len(boxes) == len(SKILL_ICONS), boxes
    out_dir = os.path.join(ROOT, "assets", "art", "skills")
    icons = []
    for sid, b in zip(SKILL_ICONS, boxes):
        c = a[b[1]:b[3], b[0]:b[2]].copy()
        cbg = bg[b[1]:b[3], b[0]:b[2]]
        c[cbg] = (26, 18, 30)                        # corners: outline colour, so the resample does not bleed pink
        crop = Image.fromarray(c.astype(np.uint8))
        pal = crop.quantize(colors=24, method=Image.Quantize.MEDIANCUT)
        small = crop.resize((24, 24), Image.LANCZOS).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
        icon = np.zeros((24, 24, 4), np.uint8)
        icon[..., :3] = np.array(small)
        icon[..., 3] = 255
        corner = np.array(Image.fromarray(cbg.astype(np.uint8) * 255).resize((24, 24), Image.BOX)) > 140
        icon[corner, 3] = 0
        Image.fromarray(icon).save(os.path.join(out_dir, sid + ".png"))
        icons.append((icon, [12, 12]))
    preview("skill_icons", {"skill_icons": {"idle": (icons, 1, False)}}, 8)
    print("skill icons:", ", ".join(SKILL_ICONS))


def characters():
    """Pack the approved 3x2 sheets, using a stable body origin instead of the weapon bounds."""
    anims = {}
    for unit, name, height, origin, states in [
        ("hero_captain", "hero", 44 / 335, (245, 440),
         {"idle": (4, 5, True), "walk": (6, 10, True), "attack": (6, 14, False),
          "cast": (6, 12, False), "hit": (2, 10, False), "death": (6, 12, False)}),
        ("worker", "apprentice", 28 / 303, (242, 436),
         {"idle": (4, 4, True), "walk": (6, 10, True), "carry": (6, 9, True)}),
    ]:
        anims[unit] = {}
        for state, (count, fps, loop) in states.items():
            path = os.path.join(SRC, "characters", f"{name}_{state}.png")
            img = Image.open(path).convert("RGB")
            if img.size != (1536, 1024):
                raise ValueError(f"Unexpected sheet dimensions: {path}")
            frames = []
            for i in range(6):
                x, y = (i % 3) * 512, (i // 3) * 512
                rgb = np.array(img.crop((x, y, x + 512, y + 512))).astype(np.int16)
                mask = bg_mask(rgb)
                if i >= count:
                    if (~mask).sum() > 32:
                        raise ValueError(f"Expected a blank cell: {path}, cell {i + 1}")
                    continue
                rgba = np.zeros((512, 512, 4), np.uint8)
                rgba[~mask, :3] = rgb[~mask]
                rgba[~mask, 3] = 255
                # Sample the original dot colors directly. Averaging here softens eyes,
                # outlines and flour marks before Godot can display the pixels.
                side = round(512 * height)
                sm = np.array(Image.fromarray(rgba).resize((side, side), Image.Resampling.NEAREST))
                sm = quantize(sm, 32)
                bounds = bbox(sm)
                if bounds is None:
                    raise ValueError(f"Empty frame: {path}, cell {i + 1}")
                l, t, r, b = bounds
                ax, ay = (round(v * side / 512) for v in origin)
                frames.append((sm[t:b, l:r], [int(ax - l), int(ay - t)]))
            anims[unit][state] = (frames, fps, loop)
    anims["hero_captain"]["die"] = anims["hero_captain"]["death"]
    print("gpt_bakery_crew", write_page("gpt_bakery_crew", "character", anims, 512,
                                      {("hero_captain", "attack"): 3}))


def main():
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == "characters":
        characters()
        return 0
    skill_icons()
    if len(sys.argv) > 1 and sys.argv[1] == "icons":
        return 0
    fx = {}
    for name, src, cols, rows, p, anchor, st, fps, loop in FX:
        art, ox, oy, (cw, ch) = shrink(src, cols, rows, p)
        frames = anim_frames(cells(art, ox, oy, cw, ch, cols, rows), anchor)
        fx[name] = {st: (frames, fps, loop)}
        print(f"{name}: {len(frames)} frames, max {max(a.shape[1] for a, _ in frames)}x{max(a.shape[0] for a, _ in frames)}")
    print("gpt_fx", write_page("gpt_fx", "fx", fx, 1024))
    preview("fx", fx)
    allnest = {}
    for c in range(1, NESTS + 1):
        art, ox, oy, (cw, ch) = shrink(f"nest/nest{c:02d}.png", 4, 2, 4)
        cs = cells(art, ox, oy, cw, ch, 4, 2)[:6]
        frames = anim_frames(cs, "ground")
        s = f"base_enemy_c{c:02d}"
        anims = {s: {"idle": (frames[0:2], 3, True), "damaged": (frames[2:4], 5, True), "ruined": (frames[4:6], 5, True)}}
        allnest.update(anims)
        print(f"gpt_nest_c{c:02d}", write_page(f"gpt_nest_c{c:02d}", "nest", anims, 512))
    preview("nest", allnest, 2)
    props = {}
    for th in PROP_THEMES:
        art, ox, oy, (cw, ch) = shrink(f"props/props_{th}.png", 4, 2, 8)
        cs = cells(art, ox, oy, cw, ch, 4, 2)
        frames = []
        for c in cs:
            b = bbox(c)
            if b is None:
                continue
            frames.append((c[b[1]:b[3], b[0]:b[2]], [int(round((b[2] - b[0]) / 2.0)), int(b[3] - b[1])]))
        props[f"prop_{th}"] = {"idle": (frames, 1, False)}
        print(f"props {th}: {[a.shape[1::-1] for a, _ in frames]}")
    print("gpt_props", write_page("gpt_props", "biome_props", props, 512))
    preview("props", props)
    return 0


if __name__ == "__main__":
    sys.exit(main())
