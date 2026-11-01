"""Scratch (05-audio v3.9): P1-P7 summary from job 2 outputs."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
D = ROOT / "docs/audio"
pa = json.loads((D / "rerender_v39_pa.json").read_text(encoding="utf-8"))
pb = json.loads((D / "rerender_v39_pb.json").read_text(encoding="utf-8"))
ab = json.loads((D / "onset_ab_v39.json").read_text(encoding="utf-8"))
ph = json.loads((D / "phone_check_v39.json").read_text(encoding="utf-8"))
log = (ROOT / "build/heavy/05-peak-after-9rec-20261101-074220.log").read_text(encoding="utf-8", errors="replace").splitlines()
keys = [o["key"] for o in pa["recordings"]]
print("P1 real after Master peak:", [o["master_peak_db"] for o in pa["recordings"]], "clipped", sum(o["master_clipped"] for o in pa["recordings"]))
print("   real before Master peak:", [o["master_peak_db"] for o in pb["recordings"]])
print("   same-bg sim rule pre-limiter peak (before battles):", [o["sim_rule"]["prelimiter_estimate_peak_db"] for o in pb["recordings"]],
      "no-rule:", [o["prelimiter_estimate_peak_db"] for o in pb["recordings"]])
print("   sim events/new/retro/exempt:", [(o["sim_rule"]["events"], o["sim_rule"]["lowered_new"], o["sim_rule"]["lowered_retro"], o["sim_rule"]["exempt_touched"]) for o in pb["recordings"]])
print("P4 after-run logged rule:", [(o["key"], o["rule_logged"]) for o in pa["recordings"]])
print("P5 before worst", pb["worst_top_peak_diff_db"], "after worst", pa["worst_top_peak_diff_db"], [o["max_abs_peak_diff_db"] for o in pa["recordings"]])
for cue in ("death_ally", "hit_base"):
    A = [ab["recordings"][k]["cues"][cue]["A"] for k in keys]
    B = [ab["recordings"][k]["cues"][cue]["B"] for k in keys]
    print(f"P2 A/B {cue}: A masked {min(x['masked_pct'] for x in A)}-{max(x['masked_pct'] for x in A)} p10>= {min(x['p10'] for x in A)} | "
          f"B masked {min(x['masked_pct'] for x in B)}-{max(x['masked_pct'] for x in B)} p10>= {min(x['p10'] for x in B)}")
    for tag in ("pb", "pa"):
        v = [next(r for r in ph[f"v3.9-{tag}_{k}"]["rows"] if r["cue"] == cue) for k in keys]
        print(f"   real {tag} {cue}: masked {min(r['masked_pct'] for r in v)}-{max(r['masked_pct'] for r in v)} p10>= {min(r['snr_p10'] for r in v)}")
dif = {c: max(ab["recordings"][k]["cues"][c]["diff"] for k in keys) for c in ab["targets"] if c in ab["recordings"][keys[0]]["cues"]}
print("G2 A/B max worsening per cue:", dif, "max", max(dif.values()))
low = {c: sum(ab["recordings"][k]["cues"][c]["B"]["target_lowered_by_rule"] for k in keys) for c in dif}
print("   A/B target placements lowered by the rule:", {c: v for c, v in low.items() if v})
print("   A/B mix:", [(k, ab["recordings"][k]["mix"]) for k in keys][:3])
mr = {}
for i, l in enumerate(log):
    m = re.match(r"=== python mix_report --rec=tools/audio/_render/recording_(p[ab])_(r\d\d_s\d\d)", l)
    if m:
        mr[(m.group(1), m.group(2))] = json.loads(log[i + 1])
for tag in ("pb", "pa"):
    v = [mr[(tag, k)] for k in keys]
    print(f"G1 mix_report {tag}: LUFS {[x['integrated_lufs'] for x in v]} peak max {max(x['peak_dbfs'] for x in v)} clipped {sum(x['clipped'] for x in v)} fatigue {sorted({c for x in v for c in x['fatigue']})}")
sel = [l for l in log if "onset_cluster policy not in the manifest" in l or "selftest: FAIL" in l or "AUDIO SELFTEST" in l]
print("selftest lines:", sel)
print([l[:160] for l in log if l.startswith("battle ") or l.startswith("hits:") or l.startswith("upgrade:") or l.startswith("hero:") or l.startswith("wave_cleared:")])
