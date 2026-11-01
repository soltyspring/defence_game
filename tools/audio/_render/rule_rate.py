"""Scratch (05-audio v3.9): firing rate of the planned onset-cluster rule on the v3.8 'rd' logs (manager clock = wall time)."""
import sys
from collections import Counter
from pathlib import Path

sys.argv = sys.argv[:1]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rerender as R  # noqa: E402

pol = {"window": 0.1, "max_full": 3, "db": -6.0, "exempt_prio": 3}
assets = R.Assets("")
tot = Counter()
lowered = Counter()
for r in ("r02", "r06", "r08"):
    for s in (11, 23, 37):
        rec = R.load(R.ROOT / f"tools/audio/_render/recording_rd_{r}_s{s}")
        ev = R.events(rec, assets)
        st = R.simulate_rule(ev, pol)
        for e in ev:
            if any(src == "cluster" for _a, _d, src in e["changes"]):
                lowered[e["cue"]] += 1
        tot.update(st)
        print(f"{r}_s{s}: SFX cues {len(ev)} | {st}")
print("total", dict(tot), "| lowered by cue", dict(lowered))
