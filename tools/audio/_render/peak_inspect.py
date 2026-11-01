"""Scratch (05-audio v3.9): cues around an audio time in a v3.9 recording, render vs stem near it."""
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
n = len(rec["st"]["sfx"])
r = R.render(ev, n)
for e in ev:
    if t0 - 0.8 <= e["ta"] <= t0 + 0.1:
        print(f"  ta {e['ta']:8.4f} wall {e['t']:7.3f} {e['cue']:12s} voice {e['voice']:2d} prio {e['prio']} vol {e['vol']:6.2f} dur {e['dur']:.3f} "
              f"cut {None if e['cut'] is None else round(e['cut'] / mr, 4)} changes {[(round(a / mr, 4), d, s) for a, d, s in e['changes']]}")
a, b = int((t0 - 0.05) * mr), int((t0 + 0.05) * mr)
st = rec["st"]["sfx"]
print(f"stem peak {R.db(np.abs(st[a:b]).max()):.2f} at {(a + np.abs(st[a:b]).argmax()) / mr:.4f}; render {R.db(np.abs(r[a:b]).max()):.2f} at {(a + np.abs(r[a:b]).argmax()) / mr:.4f}")
# cross-correlation lag between stem and render in +-0.3 s around t0
w = int(0.3 * mr)
seg_s, seg_r = st[a - w:b + w], r[a - w:b + w]
c = np.correlate(seg_s, seg_r[w:-w], "valid")
print("best lag (stem vs render) ms:", round((int(np.argmax(c)) - w) / mr * 1000, 1))
for k in sorted({e["voice"] for e in ev if t0 - 0.8 <= e["ta"] <= t0 + 0.1}):
    pass
