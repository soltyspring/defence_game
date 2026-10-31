"""07-qa frame metrics for captured game frames (Python + Pillow only; no Godot).

Sky share: fraction of pixels whose RGB equals a colour used by the biome's sky layer frame (or the
biome clear_color), read from the committed atlas of the SAME git revision as the capture.

    python tools/qa/frame_metrics.py --frame cap.png --rev 97c8b9c [--biome biome_01] [--band 0.12,0.83]

--rev     git revision the capture was made from; atlas json/png and manifest are read with `git show`
--band    optional vertical band (fractions of frame height) for a second measurement that excludes
          the HUD rows, e.g. 0.12,0.83 at 640x360 (top bar ends ~y44, bottom row starts ~y300)
Prints one JSON line. Owner: 07-qa.
"""
import argparse
import io
import json
import subprocess
import sys

from PIL import Image


def git_bytes(rev: str, path: str) -> bytes:
    return subprocess.run(["git", "show", f"{rev}:{path}"], check=True, capture_output=True).stdout


def sky_palette(rev: str, biome: str) -> tuple[set, dict]:
    manifest = json.loads(git_bytes(rev, "assets/manifest.json"))
    b = manifest["biomes"][biome]
    atlas_id = b["atlas"]
    page = next(a for a in manifest["atlases"] if a["id"] == atlas_id)
    frames = json.loads(git_bytes(rev, page["frames"].replace("res://", "")))["frames"]
    img = Image.open(io.BytesIO(git_bytes(rev, page["image"].replace("res://", "")))).convert("RGBA")
    pal = set()
    sky_layers = [l for l in b["layers"] if l.get("frame") == "sky"]
    for layer in sky_layers:
        f = frames[layer["frame"]]
        crop = img.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
        pal.update(c[:3] for c in crop.getdata() if c[3] >= 128)
    for key in ("clear_color",):
        if key in b:
            h = b[key].lstrip("#")
            pal.add(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)))
    return pal, {"atlas": atlas_id, "sky_layers": len(sky_layers), "palette_size": len(pal)}


def share(img: Image.Image, pal: set, y0: int, y1: int) -> float:
    w = img.width
    px = img.load()
    hit = tot = 0
    for y in range(y0, y1):
        for x in range(w):
            tot += 1
            if px[x, y][:3] in pal:
                hit += 1
    return 100.0 * hit / max(1, tot)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame", required=True)
    ap.add_argument("--rev", required=True)
    ap.add_argument("--biome", default="biome_01")
    ap.add_argument("--band", default="")
    a = ap.parse_args()
    pal, meta = sky_palette(a.rev, a.biome)
    img = Image.open(a.frame).convert("RGB")
    out = {"frame": a.frame, "rev": a.rev, "biome": a.biome, "size": [img.width, img.height], **meta,
           "sky_pct_full": round(share(img, pal, 0, img.height), 1)}
    if a.band:
        f0, f1 = (float(v) for v in a.band.split(","))
        y0, y1 = int(f0 * img.height), int(f1 * img.height)
        out["band_px"] = [y0, y1]
        out["sky_pct_band"] = round(share(img, pal, y0, y1), 1)
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
