"""Texture atlas packer + per-atlas JSON writer (owner: 03-art).

Packing rules (contract with 02, see docs/art/ATLAS_CONTRACT.md):
  * every region is surrounded by EXTRUDE px of duplicated edge pixels and
    then GAP px of fully transparent pixels (so >= 2*EXTRUDE+GAP between
    the real contents of two neighbouring regions),
  * regions never overlap, never touch the page edge (margin = GAP),
  * identical frames are de-duplicated (same pixels -> same rect),
  * page size = smallest power-of-two (w >= h) that fits, max 1024 (hard 2048).
Algorithm: MaxRects (best short side fit), deterministic ordering.
"""
from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

from pixel import RGBA, save_indexed_png

EXTRUDE = 1
GAP = 2
MAX_PAGE = 1024
HARD_MAX_PAGE = 2048


@dataclass
class Region:
    key: str              # unique name inside the atlas
    pix: np.ndarray       # palette-index array (h, w)
    x: int = -1           # placement of the content (excluding extrusion)
    y: int = -1

    @property
    def w(self):
        return self.pix.shape[1]

    @property
    def h(self):
        return self.pix.shape[0]


class MaxRects:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.free = [(0, 0, w, h)]

    def insert(self, rw, rh):
        best = None
        for (fx, fy, fw, fh) in self.free:
            if rw <= fw and rh <= fh:
                short = min(fw - rw, fh - rh)
                long_ = max(fw - rw, fh - rh)
                score = (short, long_, fy, fx)
                if best is None or score < best[0]:
                    best = (score, fx, fy)
        if best is None:
            return None
        _, x, y = best
        self._split(x, y, rw, rh)
        return x, y

    def _split(self, x, y, w, h):
        new = []
        for (fx, fy, fw, fh) in self.free:
            if x >= fx + fw or x + w <= fx or y >= fy + fh or y + h <= fy:
                new.append((fx, fy, fw, fh))
                continue
            if x > fx:
                new.append((fx, fy, x - fx, fh))
            if x + w < fx + fw:
                new.append((x + w, fy, fx + fw - (x + w), fh))
            if y > fy:
                new.append((fx, fy, fw, y - fy))
            if y + h < fy + fh:
                new.append((fx, y + h, fw, fy + fh - (y + h)))
        # prune contained rects
        pruned = []
        for i, a in enumerate(new):
            contained = False
            for j, b in enumerate(new):
                if i != j and a[0] >= b[0] and a[1] >= b[1] and a[0] + a[2] <= b[0] + b[2] and a[1] + a[3] <= b[1] + b[3]:
                    if a != b or i > j:
                        contained = True
                        break
            if not contained:
                pruned.append(a)
        self.free = pruned


def _pack(regions, pw, ph, locked=None):
    """locked: {key: (x, y)} content positions from the previous build. Locked regions keep
    their exact place (so adding frames never moves existing ones -> a stale GPU import can
    at worst miss NEW frames, never show wrong art); others fill the remaining space."""
    mr = MaxRects(pw - GAP, ph - GAP)  # keep GAP margin on right/bottom too
    locked = locked or {}
    for r in sorted(regions, key=lambda r: r.key):
        if r.key in locked:
            x, y = locked[r.key]
            cw, ch = r.w + 2 * EXTRUDE + GAP, r.h + 2 * EXTRUDE + GAP
            cx, cy = x - GAP - EXTRUDE, y - GAP - EXTRUDE
            if cx < 0 or cy < 0 or cx + cw > pw - GAP or cy + ch > ph - GAP:
                return False
            mr._split(cx, cy, cw, ch)
            r.x, r.y = x, y
    order = sorted((r for r in regions if r.key not in locked), key=lambda r: (-r.h, -r.w, r.key))
    for r in order:
        cw = r.w + 2 * EXTRUDE + GAP
        ch = r.h + 2 * EXTRUDE + GAP
        pos = mr.insert(cw, ch)
        if pos is None:
            return False
        r.x = pos[0] + GAP + EXTRUDE
        r.y = pos[1] + GAP + EXTRUDE
    return True


def page_sizes(max_side):
    sizes = []
    s = 64
    while s <= max_side:
        sizes.append((s, s // 2) if s >= 128 else (s, s))
        sizes.append((s, s))
        s *= 2
    return sizes


class Atlas:
    def __init__(self, atlas_id: str, group: str, load_policy: str, note: str = ""):
        self.id = atlas_id
        self.group = group
        self.load_policy = load_policy
        self.note = note
        self.unique: dict[str, Region] = {}   # hash -> region
        self.sprites: dict = {}               # animated sprites
        self.images: dict = {}                # single images (icons, ui, layers)
        self.size = None

    # -- registration ------------------------------------------------------
    def _add_pix(self, pix: np.ndarray) -> str:
        hsh = hashlib.sha1(pix.tobytes() + bytes(str(pix.shape), "ascii")).hexdigest()[:16]
        if hsh not in self.unique:
            self.unique[hsh] = Region(hsh, pix)
        return hsh

    def add_sprite(self, sprite_id: str, frame_w: int, frame_h: int, pivot, anims: dict, facing="right", meta=None):
        """anims: name -> dict(frames=[ndarray], fps, loop, events={name: frame}, points={})"""
        entry = {"frame_size": [frame_w, frame_h], "pivot": list(pivot), "facing": facing, "anims": {}}
        if meta:
            entry.update(meta)
        for name, an in anims.items():
            keys = []
            for f in an["frames"]:
                assert f.shape == (frame_h, frame_w), (sprite_id, name, f.shape)
                keys.append(self._add_pix(f))
            entry["anims"][name] = {
                "fps": an["fps"], "loop": an["loop"], "frame_keys": keys,
                **({"events": an["events"]} if an.get("events") else {}),
                **({"points": an["points"]} if an.get("points") else {}),
            }
        self.sprites[sprite_id] = entry

    def add_image(self, image_id: str, pix: np.ndarray, pivot=None, nine_slice=None, meta=None):
        k = self._add_pix(pix)
        h, w = pix.shape
        e = {"key": k, "size": [w, h], "pivot": list(pivot) if pivot else [w // 2, h // 2]}
        if nine_slice:
            e["nine_slice"] = list(nine_slice)  # left, top, right, bottom margins
        if meta:
            e.update(meta)
        self.images[image_id] = e

    # -- build ---------------------------------------------------------------
    def pack(self, lock_dir=None):
        regions = list(self.unique.values())
        locked, lock_size = {}, None
        lock_path = os.path.join(lock_dir, f"{self.id}.json") if lock_dir else None
        if lock_path and os.path.exists(lock_path):
            lk = json.load(open(lock_path, encoding="utf-8"))
            lock_size = tuple(lk["size"])
            locked = {k: tuple(v) for k, v in lk["regions"].items() if k in self.unique}
        self.dropped_locks = 0 if not lock_path or not os.path.exists(lock_path) else \
            len(json.load(open(lock_path, encoding="utf-8"))["regions"]) - len(locked)
        sizes = page_sizes(HARD_MAX_PAGE)
        if lock_size:   # never shrink below the locked page; grow only if needed
            sizes = [s for s in sizes if s[0] >= lock_size[0] and s[1] >= lock_size[1]]
        for (pw, ph) in sizes:
            if pw * ph < sum((r.w + 2 * EXTRUDE + GAP) * (r.h + 2 * EXTRUDE + GAP) for r in regions):
                continue
            if _pack(regions, pw, ph, locked):
                self.size = (pw, ph)
                break
        if self.size is None and locked:          # locks cannot be honoured -> full repack
            print(f"WARNING atlas {self.id}: layout lock dropped (repack moves existing frames; re-import required)")
            for (pw, ph) in page_sizes(HARD_MAX_PAGE):
                if _pack(regions, pw, ph):
                    self.size = (pw, ph)
                    break
        if self.size is None:
            raise RuntimeError(f"atlas {self.id} does not fit in {HARD_MAX_PAGE}")
        if max(self.size) > MAX_PAGE:
            print(f"WARNING atlas {self.id} exceeds preferred max {MAX_PAGE}: {self.size}")
        if lock_path:
            os.makedirs(lock_dir, exist_ok=True)
            with open(lock_path, "w", encoding="utf-8", newline="\n") as f:
                json.dump({"atlas": self.id, "size": list(self.size),
                           "regions": {k: [r.x, r.y] for k, r in sorted(self.unique.items())}}, f, indent=0)
                f.write("\n")
        return self.size

    def render_index(self) -> np.ndarray:
        pw, ph = self.size
        page = np.zeros((ph, pw), np.uint8)
        for r in self.unique.values():
            p = r.pix
            # extrusion: pad by edge replication
            ext = np.pad(p, EXTRUDE, mode="edge")
            page[r.y - EXTRUDE:r.y + r.h + EXTRUDE, r.x - EXTRUDE:r.x + r.w + EXTRUDE] = ext
        return page

    def rect_of(self, key):
        r = self.unique[key]
        return [r.x, r.y, r.w, r.h]

    def write(self, out_dir: str, rel_dir: str):
        """Writes <id>.png (indexed) and <id>.json in INTERFACES.md §5.2 schema."""
        os.makedirs(out_dir, exist_ok=True)
        page = self.render_index()
        png_path = os.path.join(out_dir, f"{self.id}.png")
        # 8-bit indexed PNG + tRNS (lossless, deterministic, smallest download).
        save_indexed_png(page, png_path)
        pw, ph = self.size
        frames, anims, sets_meta = {}, {}, {}

        def frame_entry(key, pivot, extra=None):
            x, y, w, h = self.rect_of(key)
            d = {"x": x, "y": y, "w": w, "h": h, "pivot": list(pivot)}
            if extra:
                d.update(extra)
            return d

        for sid, e in self.sprites.items():
            anims[sid] = {}
            sets_meta[sid] = {k: v for k, v in e.items() if k != "anims"}
            for an, a in e["anims"].items():
                names = []
                for n, k in enumerate(a["frame_keys"]):
                    nm = f"{sid}/{an}/{n}"
                    frames[nm] = frame_entry(k, e["pivot"])
                    names.append(nm)
                d = {"frames": names, "fps": a["fps"], "loop": a["loop"]}
                ev = a.get("events") or {}
                if "hit" in ev:
                    d["hit_frame"] = ev["hit"]
                if ev:
                    d["events"] = ev
                if a.get("points"):
                    d["points"] = a["points"]
                anims[sid][an] = d
        for iid, e in self.images.items():
            extra = {k: v for k, v in e.items() if k not in ("key", "pivot", "size")}
            frames[iid] = frame_entry(e["key"], e["pivot"], extra)
        used = sum(r.w * r.h for r in self.unique.values())
        doc = {
            "schema": "defence.atlas/1",
            "atlas": self.id,
            "image": f"{self.id}.png",
            "image_res": f"res://{rel_dir}/{self.id}.png",
            "size": [pw, ph],
            "padding": GAP, "extrude": EXTRUDE,
            "group": self.group,
            "load_policy": self.load_policy,
            "note": self.note,
            "filter": "nearest", "mipmaps": False, "repeat": False,
            "gpu_format": "RGBA8 (lossless, no VRAM compression)",
            "gpu_bytes": pw * ph * 4,
            "disk_bytes": os.path.getsize(png_path),
            "unique_regions": len(self.unique),
            "occupancy": round(used / (pw * ph), 3),
            "frames": frames,
            "anims": anims,
            "anim_sets_meta": sets_meta,
        }
        with open(os.path.join(out_dir, f"{self.id}.json"), "w", newline="\n", encoding="utf-8") as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write("\n")
        return doc, page
