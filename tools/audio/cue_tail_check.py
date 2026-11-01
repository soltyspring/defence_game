#!/usr/bin/env python3
"""How long does a cue really sound in a recording? (05-audio, DEATH_SYNC_CHECK.md T1/T2 on real recordings)
For every logged SFX play of the given cues:
  - played sound = the file Godot really played (imported QOA data, logged variant, logged pitch, logged volume,
    cut if its voice was reused), placed with tools/audio/rerender.py's model;
  - confirmed = the SFX stem minus the re-render of all OTHER cues correlates >= 0.9 with it over its first 0.3 s
    (or its whole length), i.e. this file at this pitch really sounded there;
  - audible end = end of the last 10 ms frame within 30 dB of its loudest 10 ms frame.
A full-stem tail cannot be measured during battle (other sounds overlap within ~0.1 s), so the end is taken from the
confirmed played sound, not from the stem.
Usage: python tools/audio/cue_tail_check.py --tag=xr [--rounds=..] [--seeds=..] [--cues=explosion,death_ally,...] [--out=..]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rerender as R  # noqa: E402

CUES = R.ARGS.get("--cues", "explosion,death_ally,death_enemy,hit_bread,hit_mold").split(",")
OUT = R.ROOT / R.ARGS.get("--out", f"tools/audio/_render/cue_tail_{R.TAG}.json")


def audible_end(x: np.ndarray, mr: int) -> float:
    fr = int(0.01 * mr)
    m = len(x) // fr
    if m == 0:
        return 0.0
    db = 10 * np.log10(np.maximum(np.add.reduceat(x[: m * fr] ** 2, np.arange(0, m * fr, fr)) / fr, 1e-14))
    k = np.where(db >= db.max() - 30.0)[0]
    return (k[-1] + 1) * fr / mr


def main() -> int:
    assets = R.Assets(R.MAN_REV, R.QOA)
    res = {"tag": R.TAG, "cues": CUES, "plays": []}
    for key, d in R.recs():
        rec = R.load(d)
        mr, st = rec["st"]["mr"], rec["st"]["sfx"]
        n = len(st)
        ev = R.events(rec, assets)
        R.apply_logged_changes(rec, ev)
        off, _agree = R.clock_offset(ev, st, rec)
        full = R.render(ev, n, off)
        for e in ev:
            if e["cue"] not in CUES:
                continue
            a = e["a"] + off
            own_full = R.render([e], n, off)
            L = len(e["sig"]) if e["cut"] is None else max(0, e["cut"] - e["a"])
            if a < 0 or a + L > n or L == 0:
                continue
            own = own_full[a:a + L]
            w = min(L, int(0.3 * mr))
            played = st[a:a + w] - (full[a:a + w] - own[:w])
            corr = float(np.corrcoef(played, own[:w])[0, 1]) if np.std(own[:w]) > 0 else float("nan")
            res["plays"].append({"rec": key, "cue": e["cue"], "t_audio": round(e["ta"], 4), "played_len_s": round(L / mr, 3),
                                 "cut_by_voice_reuse": e["cut"] is not None, "audible_end_s": round(audible_end(own, mr), 3),
                                 "confirmed": bool(corr >= 0.9), "corr": round(corr, 3)})
    out = {}
    for cue in CUES:
        p = [x for x in res["plays"] if x["cue"] == cue]
        c = [x for x in p if x["confirmed"]]
        out[cue] = {"plays": len(p), "confirmed": len(c), "audible_end_max_s": max((x["audible_end_s"] for x in c), default=None),
                    "audible_end_median_s": round(float(np.median([x["audible_end_s"] for x in c])), 3) if c else None,
                    "played_len_max_s": max((x["played_len_s"] for x in p), default=None), "cut": sum(x["cut_by_voice_reuse"] for x in p)}
        print(f"{cue:12s} plays {len(p):3d} confirmed {len(c):3d} | audible end median {out[cue]['audible_end_median_s']} max "
              f"{out[cue]['audible_end_max_s']} s | longest played {out[cue]['played_len_max_s']} s | cut by voice reuse {out[cue]['cut']}")
    res["summary"] = out
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
