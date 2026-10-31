"""Where do the "odd" pixel runs in 03's units band come from at world zoom 3/2 (k = 2)? (02-engine, measurement only)

    python docs/architecture/evidence/world_zoom/odd_runs_split.py <capture.png> [k_world]

Uses the same run definition as tools/art/scale_uniformity.py (runs of identical RGB between two colour changes,
length <= 16, horizontal and vertical, partial runs at the region edges excluded) and the same "units" band
(x 15-85 %, y 72-86 % of the window). It then splits the band at the HUD card-row top (view y 300 = device y 600 at
k = 2, 04 layout) and reports, for each part, the share of runs that are not a multiple of k_world (default 3 =
device px per art px at zoom 3/2), the share not a multiple of 2 (the HUD's k), and the most common colours of
the odd runs.
"""
import sys
from collections import Counter

import numpy as np
from PIL import Image


def runs_with_colour(a):
    key = (a[..., 0].astype(np.int64) << 16) | (a[..., 1].astype(np.int64) << 8) | a[..., 2].astype(np.int64)
    out = []
    for m in (key, key.T):
        for row in m:
            ch = np.nonzero(np.diff(row))[0]
            if len(ch) < 2:
                continue
            for s, e in zip(ch[:-1], ch[1:]):
                n = int(e - s)
                if n <= 16:
                    out.append((n, int(row[s + 1])))
    return out


def report(name, sub, k):
    r = runs_with_colour(sub)
    if not r:
        print(f"{name}: no runs")
        return
    odd = [(n, c) for n, c in r if n % k]
    odd2 = [n for n, _ in r if n % 2]
    cols = Counter(c for _, c in odd).most_common(5)
    print(f"{name}: rows {sub.shape[0]}, runs {len(r)}, not multiple of {k}: {100 * len(odd) / len(r):.1f} %, "
          f"not multiple of 2: {100 * len(odd2) / len(r):.1f} %")
    print("   odd-run lengths:", dict(sorted(Counter(n for n, _ in odd).items())))
    print("   odd-run colours:", ", ".join(f"#{c:06x} x{m}" for c, m in cols))


def main():
    path = sys.argv[1]
    k = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    img = np.array(Image.open(path).convert("RGB"))
    H, W = img.shape[:2]
    x0, x1 = int(0.15 * W), int(0.85 * W)
    y0, y1 = int(0.72 * H), int(0.86 * H)
    hud = int(round(H * 300 / 360))  # HUD card row top (view y 300)
    print(f"{path}: {W}x{H}, units band x {x0}-{x1}, y {y0}-{y1}, HUD row top y {hud}")
    report("whole band (03's region)", img[y0:y1, x0:x1], k)
    report("world part (above HUD)", img[y0:min(y1, hud), x0:x1], k)
    if hud < y1:
        report("HUD part", img[hud:y1, x0:x1], k)


if __name__ == "__main__":
    main()
