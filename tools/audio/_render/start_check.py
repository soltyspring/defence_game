"""Scratch (05-audio v3.9): for every SFX cue in a v3.9 recording, find its real start by matched filtering of the
stem (template = first 60 ms of the cue's logged file/pitch/vol) within +-150 ms of the logged audio time.
Prints the distribution of (real - logged) start in output frames, for cues with a clear match."""
import sys
from collections import Counter
from pathlib import Path

import numpy as np

rec_name = sys.argv[1]
show = len(sys.argv) > 2
show_t = sys.argv[2] if show else "0"
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

rec = R.load(R.ROOT / "tools/audio/_render" / rec_name)
assets = R.Assets("")
ev = R.events(rec, assets)
mr = rec["st"]["mr"]
st = rec["st"]["sfx"]
W = int(0.15 * mr)
dist = Counter()
rows = []
for e in ev:
    s = e["sig"] * 10 ** (e["vol"] / 20)
    L = min(len(s), int(0.06 * mr))
    tpl = s[:L]
    a = e["a"]
    if a - W < 0 or a + W + L > len(st):
        continue
    seg = st[a - W:a + W + L]
    c = np.correlate(seg, tpl, "valid")
    en = np.sqrt(np.convolve(seg ** 2, np.ones(L), "valid"))
    r = c / np.maximum(en * np.linalg.norm(tpl), 1e-12)
    k = int(np.argmax(r))
    if r[k] < 0.8:
        continue
    d = k - W
    dist[d] += 1
    seg2 = st[a + d:a + d + L]
    gain = float(np.dot(seg2, tpl) / max(np.dot(tpl, tpl), 1e-12))
    rows.append((e["ta"], e["cue"], d, round(float(r[k]), 3), round(20 * np.log10(max(abs(gain), 1e-9)), 2)))
print(f"{rec_name}: clear matches {sum(dist.values())} of {len(ev)}; (real - logged) start in frames, most common:", dist.most_common(8))
if show:
    g = [x[4] for x in rows if x[3] >= 0.95]
    print("level of matched cue in stem vs logged vol (dB), r>=0.95: median %.2f, p5 %.2f, p95 %.2f" % (np.median(g), np.percentile(g, 5), np.percentile(g, 95)))
    for x in rows:
        if abs(x[4]) > 0.5 or abs(x[0] - float(show_t)) < 0.5:
            print("  ", x)
