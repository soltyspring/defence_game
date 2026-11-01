"""Scratch (05-audio v3.9): for each logged cue of a multi-file SFX cue, which file matches the stem best at its
real start (-444 frames)? Counts logged-variant == best-match, per cue. Rendered from Godot's QOA data."""
import sys
from collections import Counter
from pathlib import Path

import numpy as np

recs = sys.argv[1:]
sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

assets = R.Assets("")
agree, total, mism = Counter(), Counter(), []
for rn in recs:
    rec = R.load(R.ROOT / "tools/audio/_render" / rn)
    mr = rec["st"]["mr"]
    st = rec["st"]["sfx"]
    for q in rec["meta"]["cues"]:
        c = assets.cues.get(q[1])
        if not c or c["bus"] != "SFX" or len(c["files"]) < 2:
            continue
        a = int(round(float(q[5]) * mr)) - 444
        L = int(0.04 * mr)
        if a < 0 or a + L > len(st):
            continue
        seg = st[a:a + L]
        sc = []
        for vi in range(len(c["files"])):
            s = R.voice_signal(assets, q[1], vi, float(q[3]), mr)[:L]
            sc.append(float(np.dot(seg[:len(s)], s) / max(np.linalg.norm(s) * np.linalg.norm(seg[:len(s)]), 1e-12)))
        best = int(np.argmax(sc))
        if max(sc) < 0.6:
            continue
        total[q[1]] += 1
        if best == int(q[2]):
            agree[q[1]] += 1
        else:
            mism.append((rn[-7:], round(float(q[5]), 3), q[1], "logged", q[2], "best", best, [round(x, 2) for x in sc]))
for k in total:
    print(f"{k:12s} logged variant = best match {agree[k]}/{total[k]}")
for m in mism[:12]:
    print("  ", m)
