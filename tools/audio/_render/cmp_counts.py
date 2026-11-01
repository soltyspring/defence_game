"""Scratch (05-audio v3.8): cue counts per recording, before (rb) vs after (rd)."""
import collections
import json
from pathlib import Path

R = Path(__file__).resolve().parent
for r in ("r02", "r06", "r08"):
    for s in (11, 23, 37):
        row = []
        for t in ("rb", "rd"):
            m = json.loads((R / f"recording_{t}_{r}_s{s}" / "rec_meta.json").read_text(encoding="utf-8"))
            c = collections.Counter(q[1] for q in m["cues"])
            row.append(f"{t}: n={len(m['cues'])} spit={c['shoot_spit']} de={c['death_enemy']} da={c['death_ally']} "
                       f"dep={c['deploy']} hb={c['hit_base']} hbm={c['hit_base_mold']} end={m.get('battle_ended_at')}")
        print(r, s, " | ".join(row))
