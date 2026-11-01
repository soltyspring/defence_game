"""Scratch (05-audio v4.0): length and audible tail of death/hit SFX vs the 0.5 s death animation (03 e8c6d96).
Audible end = last 10 ms frame whose level is within 30 dB of the file's loudest 10 ms frame (internal heuristic),
also after pitch jitter -max (slowest playback = longest) and in the phone condition (300 Hz HP)."""
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/audio"))
import phone_check as P  # noqa: E402

man = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))["cues"]
ANIM = 0.5
cues = sys.argv[1:] or ["death_ally", "death_enemy", "explosion", "hit_bread", "hit_mold", "hit_melee", "hit_arrow", "hero_death"]
print(f"| cue | file | length s | audible end s (-30 dB) | phone audible end s | slowest pitch (1-{'{jit}'}) end s | over 0.5 s by |")
for cue in cues:
    c = man[cue]
    jit = float(c.get("pitch", 0.0))
    for f in c["files"]:
        x = P.read_wav(ROOT / f[len("res://"):])
        fr = int(0.01 * P.SR)

        def end(sig):
            e = np.array([np.mean(sig[i:i + fr] ** 2) for i in range(0, len(sig) - fr + 1, fr)])
            db = 10 * np.log10(np.maximum(e, 1e-14))
            k = np.where(db >= db.max() - 30)[0]
            return (k[-1] + 1) * fr / P.SR

        e_full, e_ph = end(x), end(P.phone(x))
        slow = e_full / (1 - jit)
        print(f"| {cue} | {Path(f).name} | {len(x) / P.SR:.3f} | {e_full:.2f} | {e_ph:.2f} | {slow:.2f} (jitter {jit}) | {max(0.0, slow - ANIM):+.2f} |")
