"""Scratch (05-audio v3.9): how often do several SFX start within a short window (cue-log wall time)?"""
import json
from collections import Counter
from pathlib import Path

R = Path(__file__).resolve().parent
MAN = json.loads((R.parents[2] / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))["cues"]
for W in (0.025, 0.06, 0.1):
    hist = Counter()
    worst = []
    for r in ("r02", "r06", "r08"):
        for s in (11, 23, 37):
            m = json.loads((R / f"recording_rd_{r}_s{s}" / "rec_meta.json").read_text(encoding="utf-8"))
            ev = [(q[0], q[1]) for q in m["cues"] if MAN.get(q[1], {}).get("bus") == "SFX"]
            for i, (t, c) in enumerate(ev):
                grp = [x for x in ev if t <= x[0] < t + W]
                hist[len(grp)] += 1
                if len(grp) >= 5:
                    worst.append((f"{r}_s{s}", round(t, 3), [x[1] for x in grp]))
    print(f"W={W * 1000:.0f} ms: starts-in-window histogram {dict(sorted(hist.items()))}")
    for w in worst[:6]:
        print("   ", w)
