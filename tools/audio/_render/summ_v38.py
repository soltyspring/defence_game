"""Scratch (05-audio v3.8): summarise same_bg_ab_v38.json, phone_check_v38.json and the mix_report lines of the detached log."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ab = json.loads((ROOT / "docs/audio/same_bg_ab_v38.json").read_text(encoding="utf-8"))
keys = list(ab["seeds"])
print("A/B before", ab["before_rev"], "recs", keys)
print(f"{'cue':14s} {'A masked range':>16s} {'B masked range':>16s} {'B p10 min':>9s} {'diff range':>14s}")
worst = {}
for cue in ab["targets"]:
    A = [ab["seeds"][k]["cues"][cue]["A"] for k in keys]
    B = [ab["seeds"][k]["cues"][cue]["B"] for k in keys]
    D = [ab["seeds"][k]["cues"][cue]["diff_masked_pts"] for k in keys]
    worst[cue] = max(D)
    print(f"{cue:14s} {min(a['masked_pct'] for a in A):6.1f}-{max(a['masked_pct'] for a in A):5.1f} %   "
          f"{min(b['masked_pct'] for b in B):6.1f}-{max(b['masked_pct'] for b in B):5.1f} %   {min(b['p10'] for b in B):6.1f}   "
          f"{min(D):+5.1f}..{max(D):+5.1f}  B files {B[0]['files']} worst {B[0].get('file')}")
for cue in ("death_ally", "hit_base"):
    for k in keys:
        b = ab["seeds"][k]["cues"][cue]["B"]
        if b["masked_pct"] > 8 or b["p10"] < 0:
            print("D1/D2 miss", cue, k, b)
print("max diff any cue", max(worst.values()), max(worst, key=worst.get))
mix = [(k, ab["seeds"][k]["mix"]) for k in keys]
print("mix LUFS diff B-A:", [round(m["B_lufs"] - m["A_lufs"], 2) for _k, m in mix], "B peaks", [m["B_peak_dbfs"] for _k, m in mix])

ph = json.loads((ROOT / "docs/audio/phone_check_v38.json").read_text(encoding="utf-8"))
print("\nreal recordings, phone_check (anomaly detection only)")
for cue in ("death_ally", "hit_base", "death_enemy", "hit_bread", "hit_mold", "wave_cleared", "hit_base_mold", "deploy"):
    line = []
    for tag in ("rb", "rd"):
        vals = [next(r for r in ph[f"v3.8-{tag}_{k}"]["rows"] if r["cue"] == cue) for k in keys]
        line.append(f"{tag} masked {min(v['masked_pct'] for v in vals):4.1f}-{max(v['masked_pct'] for v in vals):4.1f} p10 min {min(v['snr_p10'] for v in vals):5.1f}")
    print(f"{cue:14s}", " | ".join(line))
diffs = {}
for k in keys:
    rb = {r["cue"]: r for r in ph[f"v3.8-rb_{k}"]["rows"]}
    rd = {r["cue"]: r for r in ph[f"v3.8-rd_{k}"]["rows"]}
    for c in rd:
        diffs.setdefault(c, []).append(round(rd[c]["masked_pct"] - rb[c]["masked_pct"], 1))
print("real rd-rb masked diff per cue (9 pairs):")
for c, d in diffs.items():
    print(f"  {c:14s} {min(d):+5.1f}..{max(d):+5.1f} mean {sum(d) / len(d):+.1f}")
for k in keys:
    for tag in ("rb", "rd"):
        rows = {r["cue"]: r for r in ph[f"v3.8-{tag}_{k}"]["rows"]}
        for c in ("death_ally", "hit_base"):
            if rows[c]["masked_pct"] > 8 or rows[c]["snr_p10"] < 0:
                print("real D1/D2 miss", tag, k, c, rows[c]["masked_pct"], rows[c]["snr_p10"])

log = (ROOT / "tools/audio/_render/detached_05-audio-v38-analysis.log").read_text(encoding="utf-8", errors="replace").splitlines()
print("\nmix_report (real recordings)")
mr = {}
for i, l in enumerate(log):
    m = re.match(r"=== python tools/audio/mix_report.py --rec=tools/audio/_render/recording_(\w+?)_(r\d\d_s\d\d) ", l + " ")
    if m:
        j = json.loads(log[i + 1])
        mr[(m.group(1), m.group(2))] = j
for tag in ("rb", "rd"):
    v = [mr[(tag, k)] for k in keys]
    print(tag, "LUFS", [x["integrated_lufs"] for x in v], "peak max", max(x["peak_dbfs"] for x in v), "clipped", sum(x["clipped"] for x in v),
          "fatigue", sorted({c for x in v for c in x["fatigue"]}), "buried", [x["buried"] for x in v])
for k in keys:
    print(" ", k, "LUFS rb", mr[("rb", k)]["integrated_lufs"], "rd", mr[("rd", k)]["integrated_lufs"], "top_repeat rd", mr[("rd", k)]["top_repeat"])
