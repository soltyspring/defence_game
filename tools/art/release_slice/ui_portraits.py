"""Card / enemy portraits (24x24) cut from the release-slice sprites, written onto a copy of the UI atlas.
    python tools/art/release_slice/ui_portraits.py [--sheet <png>]
Reads assets/atlases/ui_main.png/.json (read only) and the slice character pages; writes
assets/art/release_slice/slice_ui.png + slice_ui.json (same frame table as ui_main, only the portrait pixels differ).
Each portrait: the unit's idle frame, cropped to the head and weapon, 1 px dark outline kept, on a transparent ground.
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
ART = os.path.join(ROOT, "assets", "art", "release_slice")
# portrait frame -> (anim set, frame, crop anchor): "top" keeps the top 24 rows of the figure, "front" the right part
PORTRAITS = {
    "card_hero_captain": ("hero_captain", "idle/0", "head"), "card_worker": ("worker", "idle/0", "top"),
    "card_melee_basic": ("melee_basic", "idle/0", "top"), "card_ranged_basic": ("ranged_basic", "idle/0", "top"),
    "card_tank": ("tank", "idle/0", "top"), "card_fast": ("fast", "idle/0", "front"), "card_siege": ("siege", "idle/0", "fit"),
    "portrait_e_grunt": ("e_grunt", "idle/0", "top"), "portrait_e_swarm": ("e_swarm", "idle/0", "fit"),
    "portrait_e_spitter": ("e_spitter", "idle/0", "top"), "portrait_e_brute": ("e_brute", "idle/0", "front"),
    "portrait_e_bomber": ("e_bomber", "idle/0", "top"),
}


def frames_of():
    out = {}
    for page in ("slice_chars", "slice_chars2"):
        meta = json.load(open(os.path.join(ART, page + ".json"), encoding="utf-8"))
        im = Image.open(os.path.join(ART, page + ".png")).convert("RGBA")
        for nm, f in meta["frames"].items():
            out[nm] = im.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
    return out


def portrait(fr: Image.Image, how: str) -> Image.Image:
    if how == "head":                                 # the captain: toque, face and moustache, 22x26 box at 1:1
        return fr.crop((12, 3, 34, 31))
    a = np.array(fr)
    ys, xs = np.where(a[..., 3] > 0)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    fig = fr.crop((x0, y0, x1, y1))
    if how == "fit" and (fig.width > 24 or fig.height > 24):
        k = min(24 / fig.width, 24 / fig.height)
        fig = fig.resize((max(1, int(fig.width * k)), max(1, int(fig.height * k))), Image.NEAREST)
    w, h = fig.size
    if how == "head":
        fig = fig.crop((0, 0, w, min(h, 22)))
        k = min(20 / fig.width, 20 / fig.height)
        fig = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.NEAREST)
    elif how == "front":
        fig = fig.crop((max(0, w - 24), 0, w, min(h, 24)))
    elif how == "top":
        cx = w // 2
        fig = fig.crop((max(0, min(cx - 12, w - 24)), 0, max(0, min(cx - 12, w - 24)) + min(24, w), min(h, 24)))
    out = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    out.paste(fig, ((24 - fig.width) // 2, 24 - fig.height if how != "fit" else (24 - fig.height) // 2), fig)
    return out


def on_badge(old: Image.Image, fig: Image.Image) -> Image.Image:
    """Keep the old badge (its shape and colour say ally / unit type), wipe its interior to the badge's own ground
    colour and set the new figure inside, clipped to the interior."""
    a = np.array(old).copy()
    solid = a[..., 3] > 0
    inner = solid.copy()
    for _ in range(3):
        inner = inner & np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    ring = solid & ~inner
    core = inner & np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    cols, n = np.unique(a[inner & ~core][:, :3], axis=0, return_counts=True)      # the ground shows at the interior's edge
    ground = cols[n.argmax()] if len(cols) else np.array([60, 44, 36])
    a[inner, :3] = ground
    a[inner, 3] = 255
    out = Image.fromarray(a, "RGBA")
    f = np.array(fig)
    ys, xs = np.where(f[..., 3] > 0)
    fig = fig.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    k = min(1.0, 18 / fig.width, 20 / fig.height)
    if k < 1.0:
        fig = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.NEAREST)
    layer = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    layer.paste(fig, ((24 - fig.width) // 2, 22 - fig.height), fig)
    la = np.array(layer)
    la[~inner, 3] = 0
    out.alpha_composite(Image.fromarray(la, "RGBA"))
    oa = np.array(out)
    oa[ring] = np.array(old)[ring]                       # the badge rim always on top
    return Image.fromarray(oa, "RGBA")


def main():
    src_png = os.path.join(ROOT, "assets", "atlases", "ui_main.png")
    meta = json.load(open(os.path.join(ROOT, "assets", "atlases", "ui_main.json"), encoding="utf-8"))
    page = Image.open(src_png).convert("RGBA")
    fr = frames_of()
    made = {}
    for name, (sid, key, how) in PORTRAITS.items():
        f = meta["frames"][name]
        old = page.crop((f["x"], f["y"], f["x"] + 24, f["y"] + 24))
        p = on_badge(old, portrait(fr[f"{sid}/{key}"], how))
        page.paste(p, (f["x"], f["y"]))
        made[name] = p
    page.save(os.path.join(ART, "slice_ui.png"))
    meta = dict(meta)
    meta["atlas"] = "release_slice_ui"
    meta["image"] = "slice_ui.png"
    json.dump(meta, open(os.path.join(ART, "slice_ui.json"), "w", encoding="utf-8"), indent=1)
    print("slice_ui:", len(made), "portraits")
    if "--sheet" in sys.argv:
        path = sys.argv[sys.argv.index("--sheet") + 1]
        old = Image.open(src_png).convert("RGBA")
        sheet = Image.new("RGBA", (len(made) * 28, 56), (60, 44, 36, 255))
        for i, (name, p) in enumerate(made.items()):
            f = meta["frames"][name]
            o = old.crop((f["x"], f["y"], f["x"] + 24, f["y"] + 24))
            sheet.paste(o, (i * 28 + 2, 2), o)
            sheet.paste(p, (i * 28 + 2, 30), p)
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(path)


if __name__ == "__main__":
    main()
