"""Independent validation of the written art outputs (owner: 03-art).

    python tools/art/validate.py [--determinism]

Reads assets/manifest.json + assets/atlases/*.{png,json} from disk (not the
generator's memory) and checks:
  1. files exist, PNG size == json size, page <= 1024 preferred / 2048 hard
  2. every frame rect (+extrude) is inside the page; distinct rects never overlap
  3. extrusion ring == edge-replicated frame pixels; every pixel outside all
     (rect+extrude) areas is fully transparent  -> no foreign texels adjacent
  4. sampling simulation: nearest AND bilinear sampling of every frame at
     sub-texel offsets (+-0.49 px, as produced by non-snapped transforms)
     never reads a texel outside the frame's rect+extrude area
  5. palette compliance (every texel is a Hearth-48 colour)
  6. animation contract (INTERFACES.md §5.2): required anims, hit_frame range,
     pivot inside frame, consistent frame size within an anim_set
  7. cross-reference: sprite/projectile/vfx/icon ids referenced in data/*.json exist
  8. biome layers tile seamlessly at their repeat period
  9. (--determinism) rebuild into memory twice and compare page bytes
Exit code 0 = all hard checks pass (warnings are printed but don't fail).
"""
from __future__ import annotations

import glob
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
from pixel import RGBA, PALETTE_DEF  # noqa: E402

errors, warns = [], []


def err(m):
    errors.append(m)


def warn(m):
    warns.append(m)


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA"))


def check_page(aid, doc, img):
    H, W = img.shape[:2]
    ext = doc["extrude"]
    if [W, H] != doc["size"]:
        err(f"{aid}: png size {W}x{H} != json {doc['size']}")
    if max(W, H) > 2048:
        err(f"{aid}: exceeds hard max 2048")
    elif max(W, H) > 1024:
        warn(f"{aid}: exceeds preferred max 1024")
    rects = {}
    for name, f in doc["frames"].items():
        r = (f["x"], f["y"], f["w"], f["h"])
        rects.setdefault(r, []).append(name)
        x, y, w, h = r
        if x - ext < 0 or y - ext < 0 or x + w + ext > W or y + h + ext > H:
            err(f"{aid}:{name} rect+extrude out of page")
        px, py = f["pivot"]
        if not (0 <= px <= w and 0 <= py <= h):
            err(f"{aid}:{name} pivot {f['pivot']} outside frame {w}x{h}")
    # overlap of expanded rects + coverage mask
    owner = np.full((H, W), -1, np.int32)
    keys = list(rects)
    for i, (x, y, w, h) in enumerate(keys):
        sl = owner[y - ext:y + h + ext, x - ext:x + w + ext]
        if (sl >= 0).any():
            j = int(sl[sl >= 0][0])
            err(f"{aid}: regions overlap {rects[keys[i]][0]} vs {rects[keys[j]][0]}")
        sl[...] = i
    outside = owner < 0
    if (img[..., 3][outside] != 0).any():
        n = int((img[..., 3][outside] != 0).sum())
        err(f"{aid}: {n} opaque texels outside every region (bleed risk)")
    # extrusion correctness
    bad_ext = 0
    for (x, y, w, h) in keys:
        core = img[y:y + h, x:x + w]
        exp = np.pad(core, ((ext, ext), (ext, ext), (0, 0)), mode="edge")
        got = img[y - ext:y + h + ext, x - ext:x + w + ext]
        if not np.array_equal(exp, got):
            bad_ext += 1
    if bad_ext:
        err(f"{aid}: {bad_ext} regions with wrong extrusion")
    # sampling simulation (nearest + bilinear) at sub-texel offsets
    foreign = 0
    offs = (-0.49, -0.25, 0.0, 0.25, 0.49)
    for i, (x, y, w, h) in enumerate(keys):
        for ox in offs:
            for oy in offs:
                # texel centres of the destination pixels mapped into the page
                us = x + np.arange(w) + 0.5 + ox
                vs = y + np.arange(h) + 0.5 + oy
                # nearest
                tx = np.floor(us).astype(int)
                ty = np.floor(vs).astype(int)
                # bilinear footprint
                bx0 = np.floor(us - 0.5).astype(int)
                by0 = np.floor(vs - 0.5).astype(int)
                for xs, ys in ((tx, ty), (bx0, by0), (bx0 + 1, by0 + 1)):
                    sub = owner[np.clip(ys, 0, H - 1)][:, np.clip(xs, 0, W - 1)]
                    foreign += int((sub != i).sum())
    if foreign:
        err(f"{aid}: sampling simulation read {foreign} foreign texels")
    # palette
    pal = {tuple(int(v) for v in RGBA[i]) for i in range(len(PALETTE_DEF))}
    cols = {tuple(int(v) for v in cc) for cc in np.unique(img.reshape(-1, 4), axis=0)}
    extra = [cc for cc in cols if cc not in pal and cc[3] != 0]
    if extra:
        err(f"{aid}: {len(extra)} colours outside Hearth-48: {extra[:4]}")
    return len(keys), len(cols)


def check_anims(aid, doc):
    for sid, anims in doc["anims"].items():
        meta = doc.get("anim_sets_meta", {}).get(sid, {})
        kind = meta.get("kind", "")
        if kind == "character":
            req = ["idle", "walk", "death"] + ([] if sid == "worker" else ["attack"])
            for r in req:
                if r not in anims:
                    err(f"{aid}:{sid} missing required anim '{r}'")
        sizes = set()
        for an, a in anims.items():
            if not a["frames"]:
                err(f"{aid}:{sid}/{an} has no frames")
            for fn in a["frames"]:
                if fn not in doc["frames"]:
                    err(f"{aid}:{sid}/{an} frame {fn} not in frames")
                    continue
                f = doc["frames"][fn]
                sizes.add((f["w"], f["h"]))
            if "hit_frame" in a and not (0 <= a["hit_frame"] < len(a["frames"])):
                err(f"{aid}:{sid}/{an} hit_frame {a['hit_frame']} out of range")
            if a["fps"] <= 0:
                err(f"{aid}:{sid}/{an} fps <= 0")
        if len(sizes) > 1:
            err(f"{aid}:{sid} inconsistent frame sizes {sizes}")


def check_data_refs(manifest, all_frames):
    sets = set(manifest["anim_sets"])
    missing = []
    for path in glob.glob(os.path.join(ROOT, "data", "**", "*.json"), recursive=True):
        try:
            d = json.load(open(path, encoding="utf-8"))
        except Exception as e:  # noqa: BLE001
            warn(f"data parse {path}: {e}")
            continue

        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k in ("sprite", "vfx", "fx") and isinstance(v, str) and v:
                        if v not in sets:
                            missing.append((os.path.relpath(path, ROOT), k, v))
                    elif k == "icon" and isinstance(v, str) and v:
                        if v not in all_frames:
                            missing.append((os.path.relpath(path, ROOT), k, v))
                    else:
                        walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
        walk(d)
    return missing


def check_tiling(doc, img):
    for name, f in doc["frames"].items():
        if not f.get("tile") and f.get("parallax") in (None, 0.0):
            continue
        x, y, w, h = f["x"], f["y"], f["w"], f["h"]
        reg = img[y:y + h, x:x + w].astype(int)
        inner = [np.abs(reg[:, i] - reg[:, i + 1]).sum() for i in range(w - 1)]
        seam = np.abs(reg[:, -1] - reg[:, 0]).sum()
        lim = np.percentile(inner, 99.5)
        if seam > lim:
            err(f"{doc['atlas']}:{name} seam diff {seam} > 99.5th pct of inner column diffs {lim:.0f}")


def determinism():
    import importlib
    import build
    digests = []
    for _ in range(2):
        tmp = os.path.join(ROOT, "docs", "art", "previews", "_det")
        hs = []
        build.ATLAS_DIR = tmp
        importlib.reload(build) if False else None
        docs = build.build()
        for aid, (d, page) in sorted(docs.items()):
            hs.append(hashlib.sha256(page.tobytes()).hexdigest())
        digests.append(hs)
    return digests[0] == digests[1]


def main():
    mpath = os.path.join(ROOT, "assets", "manifest.json")
    manifest = json.load(open(mpath, encoding="utf-8"))
    all_frames = set()
    report = []
    gpu = disk = 0
    for a in manifest["atlases"]:
        aid = a["id"]
        jp = os.path.join(ROOT, a["frames"].replace("res://", ""))
        ip = os.path.join(ROOT, a["image"].replace("res://", ""))
        if not (os.path.exists(jp) and os.path.exists(ip)):
            err(f"{aid}: missing file {jp} or {ip}")
            continue
        doc = json.load(open(jp, encoding="utf-8"))
        img = load_rgba(ip)
        n, ncol = check_page(aid, doc, img)
        check_anims(aid, doc)
        if doc["group"] == "biome":
            check_tiling(doc, img)
        all_frames |= set(doc["frames"])
        sz = os.path.getsize(ip)
        if sz != a["disk_bytes"]:
            err(f"{aid}: manifest disk_bytes {a['disk_bytes']} != actual {sz}")
        g = img.shape[0] * img.shape[1] * 4
        if g != a["gpu_bytes"]:
            err(f"{aid}: manifest gpu_bytes mismatch")
        gpu += g
        disk += sz
        if os.path.exists(ip + ".import"):
            t = open(ip + ".import", encoding="utf-8").read()
            if 'path="res://.godot/imported/' not in t or "uid=" not in t:
                err(f"{aid}: .import is not Godot-generated (missing uid/remap path) -> delete and re-import (02 R2)")
            for k in ("compress/mode=0", "mipmaps/generate=false"):
                if k not in t:
                    err(f"{aid}: .import lacks {k}")
        else:
            warn(f"{aid}: no Godot-generated .import yet (02 runs --import; 03 commits it)")
        report.append(f"  {aid:14s} {img.shape[1]}x{img.shape[0]} rects={n:4d} colours={ncol:3d} disk={sz/1024:6.1f}KiB gpu={g/1048576:.2f}MiB")
    for sid, aid in manifest["anim_sets"].items():
        if not any(a["id"] == aid for a in manifest["atlases"]):
            err(f"anim_set {sid} -> unknown atlas {aid}")
    missing = check_data_refs(manifest, all_frames)
    for (p, k, v) in missing:
        warn(f"data ref not in art yet: {p} {k}={v}")
    # fonts: shipped files + licence + no tofu for any data text
    try:
        import fonts as fontmod
        for e in fontmod.coverage_errors():
            err(e)
        for req in ("OFL-Galmuri.txt", "fonts_provenance.json"):
            if not os.path.exists(os.path.join(ROOT, "assets", "fonts", req)):
                err(f"fonts: missing assets/fonts/{req}")
        for name in fontmod.FONTS:
            ip = os.path.join(ROOT, "assets", "fonts", name + ".import")
            if not os.path.exists(ip):
                warn(f"fonts: {name}.import not generated yet (02 --import)")
                continue
            t = open(ip, encoding="utf-8").read()
            for k in ("antialiasing=0", "hinting=0", "subpixel_positioning=0", "allow_system_fallback=false",
                      "multichannel_signed_distance_field=false", "generate_mipmaps=false"):
                if k not in t.replace("\r", "").split("\n") and f"\n{k}\n" not in t.replace("\r", "") + "\n":
                    err(f"fonts: {name}.import lacks pixel-font param {k}")
            if "uid=" not in t or 'path="res://.godot/imported/' not in t:
                err(f"fonts: {name}.import is not Godot-generated")
        report.append("  fonts: " + ", ".join(sorted(fontmod.FONTS)) + " -> data text coverage checked")
    except ImportError as e:  # fontTools missing
        warn(f"font check skipped: {e}")
    if "--determinism" in sys.argv:
        ok = determinism()
        (report.append("  determinism: identical page bytes across 2 builds") if ok else err("non-deterministic build"))
    print("ATLAS VALIDATION")
    print("\n".join(report))
    print(f"  total disk={disk/1024:.1f}KiB gpu={gpu/1048576:.2f}MiB")
    for w in warns:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print("RESULT:", "PASS" if not errors else f"FAIL ({len(errors)} errors)", f"warnings={len(warns)}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
