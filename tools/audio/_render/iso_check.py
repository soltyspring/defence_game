"""Scratch (05-audio v3.9): isolated cues (nothing else sounding): stem vs render sample peak and rms, per cue, with
the source WAV (linear and cubic resampling) and with a QOA round trip of the source (tools/audio/qoa.py)."""
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

recs = sys.argv[1:]
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

assets = R.Assets("")
rows = defaultdict(list)
for rn in recs:
    rec = R.load(R.ROOT / "tools/audio/_render" / rn)
    ev = R.events(rec, assets)
    st = rec["st"]["sfx"]
    mr = rec["st"]["mr"]
    for i, e in enumerate(ev):
        a = e["a"] - 444
        L = len(e["sig"])
        if e["cut"] is not None or a < 0 or a + L > len(st):
            continue
        if any(f is not e and f["a"] - 444 < a + L + 2000 and f["a"] - 444 + len(f["sig"]) > a - 2000 for f in ev):
            continue
        s = st[a:a + L]
        x = e["sig"] * 10 ** (e["vol"] / 20)
        rows[e["cue"]].append((R.db(np.abs(x).max()) - R.db(np.abs(s).max()),
                               R.db(np.sqrt(np.mean(x ** 2))) - R.db(np.sqrt(np.mean(s ** 2))), float(np.corrcoef(s, x)[0, 1])))
for cue, v in sorted(rows.items()):
    v = np.array(v)
    print(f"{cue:13s} n {len(v):3d}  render-stem peak median {np.median(v[:, 0]):+5.2f} (min {v[:, 0].min():+5.2f} max {v[:, 0].max():+5.2f})  "
          f"rms {np.median(v[:, 1]):+5.2f}  corr {np.median(v[:, 2]):.3f}")
