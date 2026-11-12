"""Relight the painted chapter panoramas (assets/backgrounds/painted_chapters/*.png, kept unmodified) so light and
buildings sit in one scene. Writes assets/art/release_slice/painted_relit/<chapter>.png (same size and layout, so the
road / troop strip lines stay where painted_chapter_backdrop.gd expects them).

What the originals do wrong, and what this pass changes:
  - no single sun: both roof slopes and every wall are evenly lit
      -> one key light from the upper left, matching the sprites: warm on lit tones, cool blue-violet in the darks
         (split toning), a gentle left-to-right falloff and a soft sun glow in the upper-left sky;
  - buildings float: nothing darkens where walls and trees meet the ground
      -> contact shadows: each column's "how much stands here" is measured in the building band and cast as a soft
         dark pool on the ground below the base line, offset away from the sun (to the right);
  - far and near buildings equally crisp and saturated (stage props)
      -> aerial perspective by height band: the distance is hazed, cooled and loses contrast; the building band a little;
         the troop strip and road keep full contrast so units stay readable.
Band edges are fractions of the image height (from GENERATION.md: buildings 30-64 %, troop strip 64-78 %, road 78 %).
python tools/art/release_slice/relight.py [--sheet <png>]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SRC = os.path.join(ROOT, "assets", "backgrounds", "painted_chapters")
OUT = os.path.join(ROOT, "assets", "art", "release_slice", "painted_relit")
# per chapter: haze colour (the sky near the horizon), key tint, shadow tint, sun strength
LOOK = {
    "meadow": dict(haze=(196, 206, 214), key=(1.05, 1.0, 0.92), shade=(0.86, 0.9, 1.06), sun=1.0),
    "orchard": dict(haze=(206, 196, 196), key=(1.06, 0.99, 0.9), shade=(0.88, 0.88, 1.04), sun=0.9),
    "frost": dict(haze=(206, 216, 230), key=(1.03, 1.0, 0.96), shade=(0.9, 0.95, 1.08), sun=0.6),
    "nest": dict(haze=(70, 96, 100), key=(1.0, 1.04, 1.02), shade=(0.9, 0.95, 1.05), sun=0.0),
}
BUILD_TOP, BASE, ROAD = 0.30, 0.64, 0.78


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def relight(name):
    look = LOOK[name]
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    fy = yy / h
    # 1. aerial perspective: strongest at the top, a little on the buildings, none from the troop strip down
    haze_t = np.where(fy < BUILD_TOP, 0.30 + (BUILD_TOP - fy) * 0.25,
                      np.where(fy < BASE, 0.30 * (BASE - fy) / (BASE - BUILD_TOP) + 0.06, 0.0))
    haze = np.array(look["haze"], np.float32)
    L = lum(a)[..., None]
    a = a * (1 - haze_t[..., None]) + (haze * 0.6 + L * 0.4) * haze_t[..., None]
    # distant contrast down (pull toward the local mean), not in the troop strip
    blur = np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32)
    k = np.where(fy < BASE, np.clip((BASE - fy) / BASE, 0, 1) * 0.35, 0.0)[..., None]
    a = a * (1 - k) + blur * k
    # 2. one key light: split tone by luminance (warm lights, cool darks) and a left-to-right falloff
    L = lum(a)[..., None] / 255.0
    key = np.array(look["key"], np.float32)
    shade = np.array(look["shade"], np.float32)
    tone = shade + (key - shade) * np.clip((L - 0.25) / 0.5, 0, 1)
    a = a * tone
    a *= (1.04 - 0.08 * (xx / w))[..., None] if look["sun"] > 0 else 1.0
    # 3. contact shadows under what stands in the building band, cast to the right
    band = a[int(h * (BASE - 0.12)):int(h * BASE)]
    g = lum(band)
    detail = np.abs(np.diff(g, axis=1)).mean(axis=0)                        # tall objects have edges; open field does not
    darkness = 1.0 - g.mean(axis=0) / 255.0
    stand = np.concatenate([[0], detail]) * 0.06 + darkness * 0.8
    stand = np.clip((stand - np.percentile(stand, 35)) / (np.percentile(stand, 95) - np.percentile(stand, 35) + 1e-6), 0, 1)
    stand = np.convolve(stand, np.ones(25) / 25, mode="same")
    # 3a. one sun on every surface: brightness as a height field -> normals -> Lambert from the upper left.
    #     Faces turned to the sun gain, faces turned away lose; strongest on the building band, faded elsewhere.
    if look["sun"] > 0:
        hgt = np.asarray(Image.fromarray(np.clip(lum(a), 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2))).astype(np.float32) / 255.0
        gy_, gx_ = np.gradient(hgt * 6.0)
        nz = 1.0 / np.sqrt(gx_ ** 2 + gy_ ** 2 + 1.0)
        nx, ny = -gx_ * nz, -gy_ * nz
        ldir = np.array([-0.62, -0.55, 0.56])
        lam = nx * ldir[0] + ny * ldir[1] + nz * ldir[2]
        lam = lam - np.median(lam)
        wgt = np.where(fy < BUILD_TOP, 0.35, np.where(fy < BASE + 0.01, 1.0, 0.25))
        a *= (1.0 + np.clip(lam, -0.5, 0.5) * 1.1 * wgt * look["sun"])[..., None]
    shift = int(w * 0.006)
    stand = np.roll(stand, shift)
    base_y = int(h * BASE)
    depth = int(h * 0.05)
    prof = np.zeros(h, np.float32)
    base_y = int(h * (BASE - 0.015))
    prof[base_y - 4:base_y + depth] = np.concatenate([np.linspace(0.5, 1.0, 4), np.linspace(1.0, 0.0, depth) ** 1.5])
    sh = prof[:, None] * stand[None, :] * 0.6
    shade_col = np.array([60, 58, 90], np.float32)
    a = a * (1 - sh[..., None] * 0.65) + shade_col * sh[..., None] * 0.2
    # 4. sun glow in the upper-left sky
    if look["sun"] > 0:
        d = np.sqrt(((xx - w * 0.08) / w) ** 2 + ((yy - h * 0.02) / h) ** 2 * 3)
        glow = np.clip(1 - d / 0.45, 0, 1) ** 2 * 0.22 * look["sun"]
        glow *= (fy < BASE)
        a = a * (1 - glow[..., None]) + np.array([255, 236, 196], np.float32) * glow[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def main():
    os.makedirs(OUT, exist_ok=True)
    pairs = []
    for name in LOOK:
        out = relight(name)
        out.save(os.path.join(OUT, name + ".png"))
        pairs.append((Image.open(os.path.join(SRC, name + ".png")).convert("RGB"), out))
        print("relit", name)
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        w = 1000
        rows = []
        for o, n in pairs:
            hh = int(o.height * w / o.width)
            rows += [o.resize((w, hh), Image.LANCZOS), n.resize((w, hh), Image.LANCZOS)]
        sheet = Image.new("RGB", (w, sum(r.height + 4 for r in rows)), (20, 20, 24))
        y = 0
        for r in rows:
            sheet.paste(r, (0, y))
            y += r.height + 4
        sheet.save(path)


if __name__ == "__main__":
    main()
