"""Scratch (05-audio v3.9): level of each cue's first 0-256 / 256-512 / 512-1024 / 1024-2048 frames in the stem, by
least squares against ALL sounds overlapping that window (logged file/pitch/vol, -444 frame offset), split by whether
the voice was reused while its previous sound was still playing in audio time."""
import sys
from pathlib import Path

import numpy as np

recs = sys.argv[1:]
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

assets = R.Assets("")
OFF = -444
bins = [(0, 256), (256, 512), (512, 1024), (1024, 2048)]
out = {True: [[] for _ in bins], False: [[] for _ in bins]}
for rn in recs:
    rec = R.load(R.ROOT / "tools/audio/_render" / rn)
    ev = R.events(rec, assets)
    R.apply_logged_changes(rec, ev)
    st = rec["st"]["sfx"]
    sigs = []
    for e in ev:
        s = e["sig"] * 10 ** (e["vol"] / 20)
        for ca, d, _src in e["changes"]:
            k = max(0, ca - e["a"])
            if k < len(s):
                s = s.copy()
                s[k:] *= 10 ** (d / 20)
        end = len(s) if e["cut"] is None else max(0, e["cut"] - e["a"])
        sigs.append((e["a"] + OFF, s[:end]))
    reused = set()
    for e in ev:
        if e["cut"] is not None:
            for f in ev:
                if f["voice"] == e["voice"] and f["a"] == e["cut"]:
                    reused.add(id(f))
    for i, e in enumerate(ev):
        a = e["a"] + OFF
        for bi, (b0, b1) in enumerate(bins):
            w0, w1 = a + b0, a + b1
            if w0 < 0 or w1 > len(st) or b1 > len(sigs[i][1]):
                continue
            cols, mine = [], None
            for j, (sa, s) in enumerate(sigs):
                lo, hi = max(w0, sa), min(w1, sa + len(s))
                if hi <= lo:
                    continue
                col = np.zeros(w1 - w0)
                col[lo - w0:hi - w0] = s[lo - sa:hi - sa]
                if j == i:
                    mine = len(cols)
                cols.append(col)
            if mine is None or len(cols) > 4:
                continue
            X = np.array(cols).T
            if np.linalg.matrix_rank(X) < X.shape[1]:
                continue
            g, *_ = np.linalg.lstsq(X, st[w0:w1], rcond=None)
            if np.sum(cols[mine] ** 2) > 1e-6:
                out[id(e) in reused][bi].append(20 * np.log10(max(abs(g[mine]), 1e-6)))
for k in (False, True):
    print("reused-while-playing" if k else "free voice          ", " | ".join(
        f"{b0}-{b1}: n {len(v):3d} median {np.median(v):6.2f} dB" if v else f"{b0}-{b1}: n 0" for (b0, b1), v in zip(bins, out[k])))
