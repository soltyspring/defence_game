"""Scratch (05-audio v3.9): which cut-fade length makes the render match the stem around voice reuses?"""
import sys
from pathlib import Path

import numpy as np

recs = sys.argv[1:]
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

assets = R.Assets("")
for F in (0, 128, 256, 512, 1024, 2048, 4096):
    errs, pk = [], []
    for rn in recs:
        rec = R.load(R.ROOT / "tools/audio/_render" / rn)
        ev = R.events(rec, assets)
        R.apply_logged_changes(rec, ev)
        st = rec["st"]["sfx"]
        r = R.render(ev, len(st), -444, F)
        for e in ev:
            if e["cut"] is None:
                continue
            c = e["cut"] - 444
            a, b = c - 256, c + 4096
            if a < 0 or b > len(st):
                continue
            errs.append(10 * np.log10(np.sum((st[a:b] - r[a:b]) ** 2) / max(np.sum(st[a:b] ** 2), 1e-12)))
            pk.append(R.db(np.abs(r[a:b]).max()) - R.db(np.abs(st[a:b]).max()))
    print(f"cut fade {F:5d} frames: cuts {len(errs)}, residual/stem energy median {np.median(errs):6.1f} dB, "
          f"peak diff median {np.median(pk):+.2f} max |{np.max(np.abs(pk)):.2f}| dB")
