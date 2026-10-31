"""Atlas import audit on a Godot project tree that has been imported (owner: 03-art).

    python tools/art/import_audit.py <project_dir> [out.json]

Run it on a CLEAN snapshot (git archive HEAD + `godot --headless --import`), never on the main tree.
Pure Python: reads <page>.png.import, .godot/imported/<file>.md5 and the .ctex (Godot 4 "GST2" header,
lossless WebP/PNG payload, decoded with Pillow). For every atlas page in assets/manifest.json:
  import params   importer texture, compress/mode=0 (lossless), mipmaps/generate=false,
                  detect_3d/compress_to=0, size_limit=0, ctex mipmap count 0, no VRAM compression flag
  cache freshness source_md5 in the .md5 == md5 of the PNG
  pixels          imported image size == PNG size == json "size"; every opaque pixel equal (RGBA);
                  fully transparent pixels compared by alpha only (fix_alpha_border may rewrite their RGB)
  rects           every json frame rect inside the page; per-frame pixel equality imported vs PNG
  filter          project.godot rendering/textures/canvas_textures/default_texture_filter == 0 (nearest)
Exit 1 on any mismatch.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import re
import struct
import sys

import numpy as np
from PIL import Image

EXPECT = {"importer": "texture", "compress/mode": "0", "mipmaps/generate": "false", "detect_3d/compress_to": "0",
          "process/size_limit": "0"}


def parse_import(path):
    out, sec = {}, None
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("["):
            sec = line.strip("[]")
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            out[k if sec != "remap" else k] = v.strip().strip('"')
    return out


def read_ctex(path):
    d = open(path, "rb").read()
    assert d[:4] == b"GST2", "not a GST2 ctex"
    version, w, h, flags, mip_limit = struct.unpack("<IIIIi", d[4:24])
    data_format, iw, ih, mipmaps, fmt = struct.unpack("<IHHII", d[36:52])
    size = struct.unpack("<I", d[52:56])[0]
    payload = d[56:56 + size]
    img = Image.open(io.BytesIO(payload)).convert("RGBA")
    return {"version": version, "w": w, "h": h, "flags": flags, "data_format": data_format,
            "mipmaps": mipmaps, "format": fmt}, np.array(img)


def main(proj, out=None):
    man = json.load(open(os.path.join(proj, "assets", "manifest.json"), encoding="utf-8"))
    pg = open(os.path.join(proj, "project.godot"), encoding="utf-8").read()
    m = re.search(r"default_texture_filter=(\d+)", pg)
    rep = {"project": proj, "filter_nearest": bool(m and m.group(1) == "0"), "pages": {}, "fails": []}
    if not rep["filter_nearest"]:
        rep["fails"].append("project default_texture_filter is not 0 (nearest)")
    for a in man["atlases"]:
        aid = a["id"]
        png = os.path.join(proj, a["image"].replace("res://", ""))
        js = json.load(open(os.path.join(proj, a["frames"].replace("res://", "")), encoding="utf-8"))
        imp = parse_import(png + ".import")
        r = {"params": {k: imp.get(k) for k in EXPECT}, "fails": []}
        for k, v in EXPECT.items():
            if imp.get(k) != v:
                r["fails"].append(f"{k}={imp.get(k)} (want {v})")
        ctex = os.path.join(proj, imp["path"].replace("res://", ""))
        md5f = ctex[:-len(".ctex")] + ".md5"
        src_md5 = hashlib.md5(open(png, "rb").read()).hexdigest()
        cached = re.search(r'source_md5="([0-9a-f]+)"', open(md5f, encoding="utf-8").read()).group(1)
        r["source_md5_match"] = cached == src_md5
        if not r["source_md5_match"]:
            r["fails"].append(f"stale cache {cached} != {src_md5}")
        hdr, imgd = read_ctex(ctex)
        r["ctex"] = hdr
        if hdr["mipmaps"] != 0:
            r["fails"].append(f"ctex has {hdr['mipmaps']} mipmaps")
        src = np.array(Image.open(png).convert("RGBA"))
        r["size"] = {"json": js["size"], "png": [src.shape[1], src.shape[0]], "ctex": [hdr["w"], hdr["h"]]}
        if not (list(js["size"]) == [src.shape[1], src.shape[0]] == [hdr["w"], hdr["h"]] == [imgd.shape[1], imgd.shape[0]]):
            r["fails"].append(f"size mismatch {r['size']}")
        else:
            op = src[..., 3] > 0
            diff = np.any(imgd != src, axis=2) & op | ((imgd[..., 3] > 0) != op)
            r["page_px_mismatch"] = int(diff.sum())
            bad, oob = 0, 0
            for n, f in js["frames"].items():
                x, y, w, h = f["x"], f["y"], f["w"], f["h"]
                if x < 0 or y < 0 or x + w > src.shape[1] or y + h > src.shape[0]:
                    oob += 1
                    continue
                if diff[y:y + h, x:x + w].any():
                    bad += 1
            r["frames"] = len(js["frames"])
            r["frames_out_of_page"] = oob
            r["frames_px_mismatch"] = bad
            if r["page_px_mismatch"] or oob or bad:
                r["fails"].append(f"pixels: page {r['page_px_mismatch']} px, frames bad {bad}, out of page {oob}")
        rep["pages"][aid] = r
        rep["fails"] += [f"{aid}: {x}" for x in r["fails"]]
    rep["pass"] = not rep["fails"]
    txt = json.dumps(rep, indent=1)
    if out:
        with open(out, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(txt + "\n")
    for aid, r in rep["pages"].items():
        print(f"{aid:18s} md5={'ok' if r['source_md5_match'] else 'STALE'} mips={r['ctex']['mipmaps']} "
              f"fmt={r['ctex']['data_format']} size={r['size']['ctex']} frames={r.get('frames')} "
              f"bad={r.get('frames_px_mismatch')} oob={r.get('frames_out_of_page')} fails={r['fails']}")
    print("PASS" if rep["pass"] else f"FAIL {rep['fails']}")
    return 0 if rep["pass"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
