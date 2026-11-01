"""Scratch (05-audio v3.9): decoded QOA samples at or near full scale, per file (cached decodes)."""
import json
import sys
from pathlib import Path

import numpy as np

R = Path(__file__).resolve().parents[3]
man = json.loads((R / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))["cues"]
vol = {Path(f).name: (k, c["vol_db"]) for k, c in man.items() for f in c["files"]}
for p in sorted((R / "tools/audio/_render/qoa_cache").glob("*.npy")):
    x = np.load(p)
    name = p.name.split("-")[0]
    fs = int(np.sum(np.abs(x) >= 32767 / 32768))
    pk = 20 * np.log10(max(np.abs(x).max(), 1e-9))
    if pk > -0.9:
        cue, vd = vol.get(name, ("?", 0))
        print(f"{name:24s} decoded peak {pk:6.2f} dBFS, full-scale samples {fs:3d}, cue {cue} vol_db {vd} -> at the bus {pk + vd:6.2f} dBFS")
