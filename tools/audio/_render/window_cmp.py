"""Scratch (05-audio v3.9): stem vs render, peak and rms in 10 ms windows after an audio time."""
import sys
from pathlib import Path

import numpy as np

rn, t0 = sys.argv[1], float(sys.argv[2])
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

rec = R.load(R.ROOT / "tools/audio/_render" / rn)
assets = R.Assets("")
ev = R.events(rec, assets)
R.apply_logged_changes(rec, ev)
st = rec["st"]["sfx"]
mr = rec["st"]["mr"]
r = R.render(ev, len(st), -444)
a = int(t0 * mr) - 444
for k in range(0, 12):
    w0, w1 = a + int(k * 0.01 * mr), a + int((k + 1) * 0.01 * mr)
    s, x = st[w0:w1], r[w0:w1]
    print(f"{k * 10:3d}-{k * 10 + 10:3d} ms: stem peak {R.db(np.abs(s).max()):6.2f} rms {R.db(np.sqrt(np.mean(s ** 2))):6.2f} | "
          f"render peak {R.db(np.abs(x).max()):6.2f} rms {R.db(np.sqrt(np.mean(x ** 2))):6.2f} | corr {np.corrcoef(s, x)[0, 1]:.3f}")
