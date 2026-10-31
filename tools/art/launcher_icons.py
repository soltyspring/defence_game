"""Launcher icon set (runtime, assets/branding/) + store graphics (docs only). Owner: 03-art, art 0.12.2.

    python tools/art/launcher_icons.py

Single source: branding.icon48_fg() (hero 제빵 대장 + rolling pin + mould blob, 48 px art grid) and
branding.icon48_bg() (warm ramp + stripes). Every output is an exact integer upscale (nearest):

  assets/branding/launcher_main_192.png                 48 grid x4, rounded square (legacy icon)
  assets/branding/launcher_adaptive_foreground_432.png  72 grid x6 (108 dp at 4 px/dp), transparent
  assets/branding/launcher_adaptive_background_432.png  72 grid x6, opaque full bleed
  assets/branding/launcher_adaptive_monochrome_432.png  72 grid x6, white silhouette on alpha (themed icons)
  docs/art/branding/store/store_icon_512.png            64 grid x8, full square, opaque, 32-bit RGBA
  docs/art/branding/store/feature_graphic_base_1024x500.png        RGB, no text (game art only)
  docs/art/branding/store/feature_graphic_title_<ko|en>_layer.png  RGBA title layer (working title, swap later)
  docs/art/branding/store/feature_graphic_<ko|en>_1024x500.png     RGB, base + title layer
  docs/art/branding/launcher_previews/*.png             masks, scaled sizes, home-screen mock
  docs/art/evidence/branding/launcher_metrics.json

In the 72 grid the 72 dp visible square is exactly the 48 px icon area (offset 12) and the 66 dp safe
circle has a diameter of 44 art px. Real launchers / devices: untested.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import branding  # noqa: E402
from pixel import RGBA, IDX, Sprite  # noqa: E402
from readability import lab_L  # noqa: E402
from cvd_check import MACHADO, lab, sim  # noqa: E402

RUNTIME = os.path.join(ROOT, "assets", "branding")
STORE = os.path.join(ROOT, "docs", "art", "branding", "store")
PREV = os.path.join(ROOT, "docs", "art", "branding", "launcher_previews")
EVID = os.path.join(ROOT, "docs", "art", "evidence", "branding")
DP = 4
CANVAS = 432
VISIBLE = 288
SAFE_R = 132
K = IDX["K"]


def up(a, k):
    return np.kron(a, np.ones((k, k), np.uint8))


def rgba(a):
    return RGBA[a]


def save(arr, path, mode="RGBA"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = Image.fromarray(arr, "RGBA")
    if mode == "RGB":
        im = im.convert("RGB")
    im.save(path, optimize=False)


def place(fg48, size, off):
    out = np.zeros((size, size), np.uint8)
    out[off:off + 48, off:off + 48] = fg48
    return out


def compose(bg_idx, fg_idx):
    out = rgba(bg_idx).copy()
    m = fg_idx > 0
    out[m] = rgba(fg_idx)[m]
    return out


def masks():
    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS] + 0.5
    c, r = CANVAS / 2, VISIBLE / 2
    dx, dy = (xx - c) / r, (yy - c) / r
    circle = dx * dx + dy * dy <= 1.0
    squircle = np.abs(dx) ** 4 + np.abs(dy) ** 4 <= 1.0
    rr = 0.3          # rounded square (Play / many OEMs), corner radius 30 % of the side
    qx, qy = np.maximum(np.abs(dx) - (1 - 2 * rr), 0), np.maximum(np.abs(dy) - (1 - 2 * rr), 0)
    rounded = (np.abs(dx) <= 1) & (np.abs(dy) <= 1) & (qx * qx + qy * qy <= (2 * rr) ** 2)
    tear = circle | ((dx >= 0) & (dy >= 0) & (np.abs(dx) <= 1) & (np.abs(dy) <= 1))
    return {"circle": circle, "rounded_square": rounded, "squircle": squircle, "teardrop": tear}


def legibility(img_rgb, fg_mask, hero_mask, mould_mask):
    """dL* of hero / mould mean vs the background mean, and CVD dE76 hero vs mould."""
    L = lab_L(img_rgb.astype(float))
    bgm = ~fg_mask
    out = {"hero_dL_vs_bg": round(float(abs(L[hero_mask].mean() - L[bgm].mean())), 1),
           "mould_dL_vs_bg": round(float(abs(L[mould_mask].mean() - L[bgm].mean())), 1)}
    h = img_rgb[hero_mask].astype(float).mean(0)
    mo = img_rgb[mould_mask].astype(float).mean(0)
    out["hero_vs_mould_dE76"] = {m: round(float(np.linalg.norm(lab(sim(h[None], m))[0] - lab(sim(mo[None], m))[0])), 1)
                                 for m in MACHADO}
    return out


def feature_graphic():
    """1024x500: real game art (village biome, bakery keep, mould nest, units) at 2 device px per art px."""
    import biome
    import theme
    W, H = 512, 250
    ls = biome.build_meadow()
    for name, cv, meta in ls:
        if name == "front":
            theme.remap_keys(cv, theme.WHEAT_FRONT)
    scene = biome.compose_preview(ls, W, cam=0).crop((0, 70, W, 70 + H))
    gy = 295 - 70
    man = json.load(open(os.path.join(ROOT, "assets", "manifest.json"), encoding="utf-8"))
    docs, pages = {}, {}
    for a in man["atlases"]:
        docs[a["id"]] = json.load(open(os.path.join(ROOT, a["frames"].replace("res://", "")), encoding="utf-8"))
        pages[a["id"]] = Image.open(os.path.join(ROOT, a["image"].replace("res://", ""))).convert("RGBA")

    def put(sid, anim, fi, x, flip=False):
        aid = man["anim_sets"][sid]
        fn = docs[aid]["anims"][sid][anim]["frames"][fi]
        f = docs[aid]["frames"][fn]
        im = pages[aid].crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
        pvx = f["pivot"][0]
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
            pvx = f["w"] - pvx
        scene.alpha_composite(im, (int(x - pvx), int(gy - f["pivot"][1])))
    put("base_player", "idle", 0, 44)
    put("base_enemy", "idle", 0, 470)
    for sid, a, fi, x in [("ranged_basic", "attack", 1, 150), ("melee_basic", "walk", 1, 196), ("tank", "walk", 2, 222),
                          ("hero_captain", "attack", 3, 252), ("melee_basic", "attack", 2, 278)]:
        put(sid, a, fi, x)
    for sid, a, fi, x in [("e_grunt", "attack", 2, 304), ("e_spitter", "walk", 1, 330), ("e_brute", "walk", 2, 362),
                          ("e_swarm", "walk", 1, 392)]:
        put(sid, a, fi, x, flip=True)
    base = scene.resize((1024, 500), Image.NEAREST)
    return base


def title_layer(loc):
    """Working-title logo (ui_title_<loc> 2-line frame) at x2 on a crust plate, centred in the top band."""
    doc = json.load(open(os.path.join(ROOT, "assets", "atlases", f"ui_title_{loc}.json"), encoding="utf-8"))
    page = Image.open(os.path.join(ROOT, "assets", "atlases", f"ui_title_{loc}.png")).convert("RGBA")
    f = doc["frames"][f"logo_title_{loc}_2line"]
    logo = page.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
    logo = logo.resize((f["w"] * 2, f["h"] * 2), Image.NEAREST)
    layer = Image.new("RGBA", (1024, 500), (0, 0, 0, 0))
    pw, ph = logo.width + 48, logo.height + 32
    px, py = (1024 - pw) // 2, 20
    d = ImageDraw.Draw(layer)
    plate = tuple(int(v) for v in RGBA[IDX["w"]][:3]) + (235,)
    edge = tuple(int(v) for v in RGBA[IDX["K"]][:3]) + (255,)
    d.rectangle((px, py, px + pw - 1, py + ph - 1), fill=plate, outline=edge, width=4)
    layer.alpha_composite(logo, ((1024 - logo.width) // 2, py + 16))
    return layer, (px, py, pw, ph)


def home_preview(icon_rgba, label="빵집 기사단"):
    """Mock home-screen tile (3x density): icon 48 dp = 144 px in a circle mask, label under it.
    The label uses Galmuri11 (bundled), not the device system font."""
    W, H = 540, 300
    im = Image.new("RGBA", (W, H), (58, 74, 104, 255))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(58 + 40 * t), int(74 + 20 * t), int(104 - 20 * t), 255))
    ic = Image.fromarray(icon_rgba, "RGBA").resize((144, 144), Image.LANCZOS)
    mk = Image.new("L", (144, 144), 0)
    ImageDraw.Draw(mk).ellipse((0, 0, 143, 143), fill=255)
    x0 = (W - 144) // 2
    im.paste(ic, (x0, 40), mk)
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "Galmuri11.ttf"), 36)
    tw = d.textlength(label, font=font)
    d.text(((W - tw) / 2 + 2, 204), label, font=font, fill=(0, 0, 0, 160))
    d.text(((W - tw) / 2, 202), label, font=font, fill=(255, 255, 255, 255))
    for i, gx in enumerate((40, 400)):                       # two neutral neighbour icons for scale
        d.ellipse((gx, 40, gx + 99, 139), fill=(90 + 30 * i, 110, 130, 255))
    return im, tw


def main():
    fg48 = branding.icon48_fg().a
    # --- legacy main 192 ------------------------------------------------------------------
    main48 = branding.icon48().a
    save(rgba(up(main48, 4)), os.path.join(RUNTIME, "launcher_main_192.png"))
    # --- adaptive layers --------------------------------------------------------------------
    fg72 = place(fg48, 72, 12)
    bg72 = branding.icon48_bg(full_bleed=True, size=72, off=12).a
    fg432, bg432 = up(fg72, 6), up(bg72, 6)
    save(rgba(fg432), os.path.join(RUNTIME, "launcher_adaptive_foreground_432.png"))
    save(rgba(bg432), os.path.join(RUNTIME, "launcher_adaptive_background_432.png"))
    mono = np.zeros((CANVAS, CANVAS, 4), np.uint8)
    solid = (fg432 > 0) & (fg432 != K)
    mono[solid] = (255, 255, 255, 255)
    save(mono, os.path.join(RUNTIME, "launcher_adaptive_monochrome_432.png"))
    # docs copies of the same layers (06's check_store_graphics.py reads docs/art/branding/adaptive/*)
    adp = os.path.join(ROOT, "docs", "art", "branding", "adaptive")
    save(rgba(fg432), os.path.join(adp, "ic_launcher_foreground_432.png"))
    save(rgba(bg432), os.path.join(adp, "ic_launcher_background_432.png"))
    save(mono, os.path.join(adp, "ic_launcher_monochrome_432.png"))
    branding.write_icons(os.path.join(ROOT, "docs", "art", "branding"))      # 48/96/192 candidates, same art
    # --- store icon 512 -----------------------------------------------------------------------
    fg64 = place(fg48, 64, 8)
    bg64 = branding.icon48_bg(full_bleed=True, size=64, off=8).a
    store = compose(up(bg64, 8), up(fg64, 8))
    save(store, os.path.join(STORE, "store_icon_512.png"))
    # --- metrics: safe zone, masks, logo size ---------------------------------------------------
    # safe test = farthest corner of each device pixel inside r = 33 dp (same rule as 06's check)
    yy, xx = np.mgrid[0:CANVAS, 0:CANVAS].astype(float)
    fx = np.maximum(np.abs(xx - CANVAS / 2), np.abs(xx + 1 - CANVAS / 2))
    fy = np.maximum(np.abs(yy - CANVAS / 2), np.abs(yy + 1 - CANVAS / 2))
    safe = fx * fx + fy * fy <= SAFE_R ** 2
    opaque = fg432 > 0
    core = opaque & (fg432 != K)
    ys, xs = np.nonzero(opaque)
    met = {"source": "branding.icon48_fg / icon48_bg (48 px art grid)", "adaptive_px_per_art_px": 6, "dp_px": DP,
           "fg_opaque_px": int(opaque.sum()),
           "fg_outside_safe_circle_px": int((opaque & ~safe).sum()),
           "fg_outside_safe_circle_px_excluding_outline": int((core & ~safe).sum()),
           "logo_bbox_dp": [round((xs.max() - xs.min() + 1) / DP, 1), round((ys.max() - ys.min() + 1) / DP, 1)],
           "bg_transparent_px": int((bg432 == 0).sum()), "masks": {},
           "store_icon": {"size": list(store.shape[:2]), "alpha_min": int(store[..., 3].min()),
                          "transparent_px": int((store[..., 3] < 255).sum())},
           "monochrome_px": int(solid.sum())}
    comp = compose(bg432, fg432)
    tiles = []
    for name, m in masks().items():
        met["masks"][name] = {"fg_clipped_px": int((opaque & ~m).sum()),
                              "fg_clipped_px_excluding_outline": int((core & ~m).sum())}
        t = np.zeros_like(comp)
        t[..., :3] = (40, 44, 58)
        t[..., 3] = 255
        t[m] = comp[m]
        lo, hi = (CANVAS - VISIBLE) // 2, (CANVAS + VISIBLE) // 2
        tiles.append((name, t[lo:hi, lo:hi]))
    os.makedirs(PREV, exist_ok=True)
    sheet = np.concatenate([np.pad(t, ((8, 8), (8, 8), (0, 0))) for _, t in tiles], axis=1)
    sheet[..., 3] = 255
    Image.fromarray(sheet, "RGBA").save(os.path.join(PREV, "mask_previews_circle_rounded_squircle_teardrop.png"))
    # monochrome preview (tinted like a themed icon)
    mt = np.zeros((VISIBLE, VISIBLE, 4), np.uint8)
    mt[..., :3] = (214, 227, 255)
    mt[..., 3] = 255
    lo = (CANVAS - VISIBLE) // 2
    mm = mono[lo:lo + VISIBLE, lo:lo + VISIBLE, 3] > 0
    mt[mm] = (31, 55, 110, 255)
    cm = masks()["circle"][lo:lo + VISIBLE, lo:lo + VISIBLE]
    mt[~cm] = (40, 44, 58, 255)
    Image.fromarray(mt, "RGBA").save(os.path.join(PREV, "monochrome_themed_preview.png"))
    # --- scaled legibility (circle mask, box downscale) -------------------------------------------
    hero_idx = set(IDX[k] for k in "WxUTYZoey")      # hero palette in the icon (hat, face, jacket, apron, pin)
    mould_idx = set(IDX[k] for k in "tlz")
    circle_tile = dict(tiles)["circle"]
    lo = (CANVAS - VISIBLE) // 2
    fg_v = fg432[lo:lo + VISIBLE, lo:lo + VISIBLE]
    met["scaled"] = {}
    for s, label in ((192, "48dp_xxxhdpi"), (144, "48dp_xxhdpi"), (96, "48dp_xhdpi"), (48, "48dp_mdpi")):
        im = Image.fromarray(circle_tile, "RGBA").resize((s, s), Image.BOX)
        im.save(os.path.join(PREV, f"circle_{s}px.png"))
        k = VISIBLE / s
        def down(mask):
            return np.array(Image.fromarray(mask.astype(np.uint8) * 255).resize((s, s), Image.BOX)) > 127
        heroM = down(np.isin(fg_v, list(hero_idx)) & ~np.isin(fg_v, list(mould_idx)))
        mouldM = down(np.isin(fg_v, list(mould_idx)))
        fgM = down(fg_v > 0)
        rgb = np.array(im.convert("RGB"))
        cm_s = down(masks()["circle"][lo:lo + VISIBLE, lo:lo + VISIBLE])
        leg = legibility(rgb, fgM | ~cm_s, heroM & cm_s, mouldM & cm_s)
        hs = np.nonzero(heroM)[0]
        leg["hero_height_pct"] = round(float((hs.max() - hs.min() + 1) / s * 100), 1) if len(hs) else 0.0
        leg["hat_px"] = int(down(fg_v == IDX["W"]).sum())
        met["scaled"][label] = leg
    # --- home screen mock ------------------------------------------------------------------------
    hp, tw = home_preview(comp[lo:lo + VISIBLE, lo:lo + VISIBLE])
    hp.save(os.path.join(PREV, "home_screen_mock_ko.png"))
    met["home_label"] = {"text": "빵집 기사단", "font": "Galmuri11 36 px at 3x (12 dp), not the device font",
                         "width_dp": round(tw / 3, 1), "tile_width_dp_typical": 80}
    # --- feature graphic ------------------------------------------------------------------------
    base = feature_graphic()
    save(np.array(base), os.path.join(STORE, "feature_graphic_base_1024x500.png"), mode="RGB")
    met["feature_graphic"] = {"size": [base.width, base.height], "titles": {}}
    for loc in ("ko", "en"):
        layer, (px, py, pw, ph) = title_layer(loc)
        layer.save(os.path.join(STORE, f"feature_graphic_title_{loc}_layer.png"))
        full = base.copy()
        full.alpha_composite(layer)
        save(np.array(full), os.path.join(STORE, f"feature_graphic_{loc}_1024x500.png"), mode="RGB")
        cx = (px + pw / 2) / 1024
        met["feature_graphic"]["titles"][loc] = {"plate_px": [px, py, pw, ph],
                                                 "plate_centre_x_pct": round(cx * 100, 1),
                                                 "plate_top_bottom_pct": [round(py / 500 * 100, 1), round((py + ph) / 500 * 100, 1)]}
    a = np.array(base.convert("RGB")).astype(float)
    met["feature_graphic"]["mean_rgb"] = [round(float(v), 1) for v in a.reshape(-1, 3).mean(0)]
    met["feature_graphic"]["share_near_white_or_black_pct"] = round(float(((a.min(2) > 240) | (a.max(2) < 20)).mean() * 100), 2)
    os.makedirs(EVID, exist_ok=True)
    with open(os.path.join(EVID, "launcher_metrics.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(met, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(json.dumps(met, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
