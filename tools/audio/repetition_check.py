#!/usr/bin/env python3
"""Repetition-fatigue metrics R1-R4 from engine cue logs (05-audio, v3.8). Offline, Python only.

Reads tools/audio/_render/recording_<tag>_<round>_s<seed>/rec_meta.json (cue log entries
[t_wall_s, cue, variant_index, pitch_scale, volume_db], written by tools/audio/integration_probe.gd v3.8).
Criteria (fixed in docs/audio/REPETITION_CHECK.md before measuring), for cues with >= 10 plays/min:
  R1 max plays in any 1 s <= 4;  R2 max plays of the SAME file in any 10 s <= 20;
  R3 identical repeats (consecutive plays within 2 s: same file, pitch within 1 %, volume within 0.5 dB) <= 10 %;
  R4 same file back-to-back (consecutive plays within 2 s) <= 50 %.
Usage: python tools/audio/repetition_check.py --tag=rb [--rounds=r02,r06,r08] [--seeds=11,23,37] [--out=...json]
"""
from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in sys.argv[1:] if "=" in a}
TAG = ARGS.get("--tag", "rb")
ROUNDS = ARGS.get("--rounds", "r02,r06,r08").split(",")
SEEDS = ARGS.get("--seeds", "11,23,37").split(",")
OUT = ROOT / ARGS.get("--out", f"tools/audio/_render/repetition_{TAG}.json")
MAN = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))
MIN_PER_MIN = 10.0
LIM = {"R1": 4, "R2": 20, "R3": 10.0, "R4": 50.0}


def windows_max(ts, w):
    best, j = 0, 0
    for i in range(len(ts)):
        while ts[i] - ts[j] >= w:
            j += 1
        best = max(best, i - j + 1)
    return best


def analyse(meta):
    by = defaultdict(list)
    for e in meta["cues"]:
        if len(e) < 5:
            raise SystemExit("cue log has no variant/pitch columns: record with integration_probe.gd v3.8")
        by[e[1]].append(e)
    mins = float(meta["seconds"]) / 60.0
    out = {}
    for cue, es in by.items():
        c = MAN["cues"].get(cue, {})
        if c.get("bus") != "SFX":
            continue
        es.sort(key=lambda e: e[0])
        ts = [e[0] for e in es]
        per_file = defaultdict(list)
        for e in es:
            per_file[e[2]].append(e[0])
        pairs = [(a, b) for a, b in zip(es, es[1:]) if b[0] - a[0] <= 2.0]
        same = [p for p in pairs if p[0][2] == p[1][2]]
        ident = [p for p in same if abs(p[1][3] / max(p[0][3], 1e-6) - 1) < 0.01 and abs(p[1][4] - p[0][4]) <= 0.5]
        out[cue] = {"plays": len(es), "per_min": round(len(es) / mins, 1), "files": len(c.get("files", [])),
                    "R1_max_1s": windows_max(ts, 1.0), "R2_max_same_file_10s": max(windows_max(v, 10.0) for v in per_file.values()),
                    "pairs_2s": len(pairs), "R3_identical_pct": round(100 * len(ident) / len(pairs), 1) if pairs else 0.0,
                    "R4_same_file_pct": round(100 * len(same) / len(pairs), 1) if pairs else 0.0}
    return out


def main() -> int:
    res = {"tag": TAG, "recordings": {}, "fails": []}
    for rnd in ROUNDS:
        for sd in SEEDS:
            d = ROOT / f"tools/audio/_render/recording_{TAG}_{rnd}_s{sd}"
            meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
            a = analyse(meta)
            res["recordings"][f"{rnd}_s{sd}"] = a
            for cue, m in a.items():
                if m["per_min"] < MIN_PER_MIN:
                    continue
                bad = []
                if m["R1_max_1s"] > LIM["R1"]: bad.append("R1")
                if m["R2_max_same_file_10s"] > LIM["R2"]: bad.append("R2")
                if m["R3_identical_pct"] > LIM["R3"]: bad.append("R3")
                if m["R4_same_file_pct"] > LIM["R4"]: bad.append("R4")
                if bad:
                    res["fails"].append({"rec": f"{rnd}_s{sd}", "cue": cue, "fail": bad, **m})
    # summary per cue over all recordings (frequent ones only)
    summ = defaultdict(lambda: defaultdict(list))
    for rec, a in res["recordings"].items():
        for cue, m in a.items():
            for k, v in m.items():
                summ[cue][k].append(v)
    res["summary"] = {cue: {k: [min(v), max(v)] for k, v in d.items()} for cue, d in summ.items()
                      if max(d["per_min"]) >= MIN_PER_MIN}
    OUT.write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    print(f"{'cue':14s} {'per_min':>12s} {'files':>5s} {'R1 1s':>7s} {'R2 10s':>7s} {'R3 ident%':>12s} {'R4 same%':>12s}")
    for cue, s in sorted(res["summary"].items(), key=lambda kv: -kv[1]["per_min"][1]):
        print(f"{cue:14s} {str(s['per_min']):>12s} {s['files'][1]:5d} {str(s['R1_max_1s']):>7s} {str(s['R2_max_same_file_10s']):>7s} "
              f"{str(s['R3_identical_pct']):>12s} {str(s['R4_same_file_pct']):>12s}")
    fails = defaultdict(set)
    for f in res["fails"]:
        fails[f["cue"]].update(f["fail"])
    print("FAILS:", {k: sorted(v) for k, v in fails.items()} or "none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
