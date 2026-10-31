"""Pixel-scale uniformity on real-game captures (owner: 03-art). Measurement only.

    python tools/art/scale_uniformity.py <out.json> <label>=<png>[@<content_rect x,y,w,h>] ...

For each capture, inside the game image (content rect; default = whole window):
  runs        horizontal and vertical runs of identical colour, length <= 16 px, in three regions:
              units   = battle band (y 72-86 % of the content height, x 15-85 %)
              text    = HUD resource panel (top-left, x 1-27 %, y 2-12 %)
              borders = bottom card row frames (y 83-99 %, x 26-74 %)
  scale       dominant source-pixel width k: the most common run length among runs of length 1..6
  odd_pct     % of runs whose length is not a multiple of k (0 for an exact integer scale)
  mixed_pct   % of runs with length in {floor(s), ceil(s)} pairs mixed (only reported for fractional s)
  blend_pct   % of pixels whose colour is not one of the 64 most frequent colours of the region
              (resampling blur creates in-between colours; nearest scaling does not)
  screen_use  % of the window covered by the content rect
"""
from __future__ import annotations

import json
import sys
from collections import Counter

import numpy as np
from PIL import Image

REG = {"units": (0.15, 0.72, 0.85, 0.86), "text": (0.01, 0.02, 0.27, 0.12), "borders": (0.26, 0.83, 0.74, 0.99)}


def runs(a):
    key = (a[..., 0].astype(np.int64) << 16) | (a[..., 1].astype(np.int64) << 8) | a[..., 2].astype(np.int64)
    out = []
    for m in (key, key.T):
        for row in m:
            ch = np.nonzero(np.diff(row))[0]
            if len(ch) < 2:
                continue
            lens = np.diff(ch)
            out.extend(int(x) for x in lens if x <= 16)
    return out, key


def region_metrics(img, rect):
    x0, y0, w, h = rect
    res = {}
    for name, (fx0, fy0, fx1, fy1) in REG.items():
        sub = img[y0 + int(fy0 * h):y0 + int(fy1 * h), x0 + int(fx0 * w):x0 + int(fx1 * w)]
        r, key = runs(sub)
        c = Counter(x for x in r if x <= 6)
        k = max(c, key=c.get) if c else 1
        odd = sum(1 for x in r if x % k) / max(1, len(r)) * 100
        top = {v for v, _ in Counter(key.ravel().tolist()).most_common(64)}
        blend = float(np.mean([v not in top for v in key.ravel().tolist()]) * 100)
        res[name] = {"runs": len(r), "k": int(k), "odd_pct": round(odd, 1), "blend_pct": round(blend, 2),
                     "len_hist": {str(n): int(c2) for n, c2 in sorted(Counter(r).items()) if n <= 8}}
    return res


def main(out, items):
    rep = {}
    for it in items:
        label, rest = it.split("=", 1)
        if "@" in rest:
            path, rc = rest.split("@", 1)
            rect = tuple(int(v) for v in rc.split(","))
        else:
            path, rect = rest, None
        img = np.array(Image.open(path).convert("RGB"))
        H, W = img.shape[:2]
        if rect is None:
            rect = (0, 0, W, H)
        r = region_metrics(img, rect)
        r["window"] = [W, H]
        r["content_rect"] = list(rect)
        r["screen_use_pct"] = round(rect[2] * rect[3] / (W * H) * 100, 1)
        rep[label] = r
        print(f"{label:28s} use {r['screen_use_pct']:5.1f}%  " + "  ".join(
            f"{n}: k{r[n]['k']} odd {r[n]['odd_pct']:5.1f}% blend {r[n]['blend_pct']:5.2f}%" for n in REG))
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rep, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
