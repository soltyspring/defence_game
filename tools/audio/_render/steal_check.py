"""Scratch (05-audio v3.9): what really happens when a cue reuses a voice whose previous sound is still playing in
audio time (game clock thinks it ended)? Fit stem = sum of candidate sounds by least squares around the moment."""
import sys
from pathlib import Path

import numpy as np

rec_name, t0 = sys.argv[1], float(sys.argv[2])
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

rec = R.load(R.ROOT / "tools/audio/_render" / rec_name)
assets = R.Assets("")
ev = R.events(rec, assets)
R.apply_logged_changes(rec, ev)
mr = rec["st"]["mr"]
st = rec["st"]["sfx"]
OFF = -444
a0, a1 = int((t0 - 0.02) * mr), int((t0 + 0.25) * mr)
near = [e for e in ev if e["a"] - 0 < a1 and e["a"] + len(e["sig"]) > a0]
cols, names = [], []
for e in near:
    s = e["sig"] * 10 ** (e["vol"] / 20)
    full = np.zeros(a1 - a0)
    st_ = e["a"] + OFF - a0
    lo, hi = max(0, st_), min(a1 - a0, st_ + len(s))
    if hi > lo:
        full[lo:hi] = s[lo - st_:hi - st_]
    # split each sound into the part before and after the next cue on its voice (if cut)
    if e["cut"] is not None:
        c = e["cut"] + OFF - a0
        before, after = full.copy(), full.copy()
        before[max(0, c):] = 0
        after[:max(0, c)] = 0
        cols += [before, after]
        names += [f"{e['cue']}@{e['ta']:.3f} v{e['voice']} BEFORE cut", f"{e['cue']}@{e['ta']:.3f} v{e['voice']} AFTER cut"]
    else:
        cols.append(full)
        names.append(f"{e['cue']}@{e['ta']:.3f} v{e['voice']}")
X = np.array(cols).T
g, *_ = np.linalg.lstsq(X, st[a0:a1], rcond=None)
res = st[a0:a1] - X @ g
print(f"fit residual {R.db(np.sqrt(np.mean(res ** 2))):.1f} dB rms vs stem {R.db(np.sqrt(np.mean(st[a0:a1] ** 2))):.1f} dB rms")
for nm, gg, col in zip(names, g, cols):
    if np.any(col):
        print(f"  gain {gg:6.3f} ({R.db(abs(gg)):6.2f} dB)  {nm}")
