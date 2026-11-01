"""Scratch (05-audio v3.8): re-render the cue cluster around a recording's master peak from its own cue log
(logged file variant, pitch and volume; runtime SFX duck) with different asset sets, to see what sets the peak."""
import json
import sys
from pathlib import Path

import numpy as np

sys.argv, ARGV = sys.argv[:1], sys.argv[1:]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import same_bg_ab as T  # noqa: E402

rec, t0, t1 = ARGV[0], float(ARGV[1]), float(ARGV[2])
d = Path(__file__).resolve().parent / rec
meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
SR = T.SR
OLD, NEW = T.AssetSet("64a95c6"), T.AssetSet(None)


def pitched(x, p):
    if abs(p - 1.0) < 1e-6:
        return x
    n = int(len(x) / p)
    return np.interp(np.arange(n) * p, np.arange(len(x)), x)


def render(mode):
    """mode: new_logged = new assets, logged variant/pitch/vol; old = old files (1 variant), logged pitch, manifest vol;
    new_de_v1 = like new_logged but death_enemy always file 0; new_nojitter = logged variant/pitch, manifest vol."""
    n = int((t1 - t0 + 1.0) * SR)
    out = np.zeros(n)
    placed = []
    for q in meta["cues"]:
        t, cue, vi, p, vol = q[0], q[1], int(q[2]), float(q[3]), float(q[4])
        if not (t0 - 0.6 <= t <= t1):
            continue
        A = OLD if mode == "old" else NEW
        c = A.man["cues"].get(cue)
        if not c or c["bus"] != "SFX":
            continue
        files = c["files"]
        f = files[0] if mode in ("old",) or (mode == "new_de_v1" and cue == "death_enemy") else files[vi % len(files)]
        v = vol if mode in ("new_logged", "new_de_v1") else float(c["vol_db"])
        s = pitched(A.file(f), p) * 10 ** (v / 20)
        a = int((t - t0) * SR)
        if a < 0:
            s, a = s[-a:], 0
        placed.append([a, min(n, a + len(s)), cue, int(c.get("prio", 1)), s.copy(), float(c.get("duck_sfx", 0.0)), int(c.get("duck_sfx_below", 0))])
    for it in placed:
        a, e, cue, prio, s = it[:5]
        for da, de, dc, dp, _s, ddb, below in placed:
            if ddb < 0 and prio < below and (da, de) != (a, e):
                lo, hi = max(a, da), min(e, de)
                if hi > lo:
                    s[(0 if a >= da else lo - a):] *= 10 ** (ddb / 20)
    for a, e, _c, _p, s, *_ in placed:
        out[a:e] += s[: e - a]
    k = int(np.abs(out).argmax())
    return 20 * np.log10(np.abs(out).max()), t0 + k / SR


for mode in ("old", "new_logged", "new_de_v1", "new_nojitter"):
    pk, tp = render(mode)
    print(f"{mode:13s} SFX sum peak {pk:6.2f} dBFS at log t {tp:.3f}")
