"""Scratch (05-audio v4.1): does the v4.1 cue-log layout (13th field appended) keep the existing format?
1. The GDScript append in integration_probe.gd has as many fields as meta cue_fields, and fields 0-11 keep the v3.9 names.
2. A copy of a v3.9 recording with a 13th field appended gives identical results in rerender.py, repetition_check.py
   and mix_report.py --no-publish."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
R = ROOT / "tools/audio/_render"
probe = (ROOT / "tools/audio/integration_probe.gd").read_text(encoding="utf-8")
names = json.loads(re.search(r'"cue_fields": (\[[^\]]*\])', probe).group(1))
block = re.search(r"_cue_log\.append\(\[(.*?)\]\)\n", probe, re.S).group(1)
depth, n = 0, 1
for ch in block:
    depth += ch in "([{"
    depth -= ch in ")]}"
    n += ch == "," and depth == 0
old = json.loads((R / "recording_pa_r08_s23/rec_meta.json").read_text(encoding="utf-8"))
print(f"1. probe append fields {n}, cue_fields {len(names)}: {'OK' if n == len(names) else 'MISMATCH'}; "
      f"first 12 names unchanged: {names[:12] == old['cue_fields']}; v3.9 log has {len(old['cue_fields'])} fields")
src, dst = R / "recording_pa_r08_s23", R / "recording_fmt_r08_s23"
if dst.exists():
    shutil.rmtree(dst)
shutil.copytree(src, dst)
new = dict(old, cue_fields=names, t_audio_source="pre_play", cues=[q + [q[5]] for q in old["cues"]])
(dst / "rec_meta.json").write_text(json.dumps(new), encoding="utf-8")
imp = sys.argv[1] if len(sys.argv) > 1 else ""


def run(args):
    return subprocess.run([sys.executable] + args, capture_output=True, text=True, cwd=ROOT).stdout


ok = True
for tag in ("pa", "fmt"):
    run(["tools/audio/rerender.py", f"--tag={tag}", "--rounds=r08", "--seeds=23", f"--imported={imp}", f"--out=tools/audio/_render/fmt_rr_{tag}.json"])
    run(["tools/audio/repetition_check.py", f"--tag={tag}", "--rounds=r08", "--seeds=23", f"--out=tools/audio/_render/fmt_rep_{tag}.json"])
a, b = (json.loads((R / f"fmt_rr_{t}.json").read_text())["recordings"][0] for t in ("pa", "fmt"))
same_rr = all(a[k] == b[k] for k in ("top_peaks", "clock_offset_frames", "stem_peak_db", "render_peak_db", "cues_sfx"))
ra, rb = (json.loads((R / f"fmt_rep_{t}.json").read_text()) for t in ("pa", "fmt"))
same_rep = ra["summary"] == rb["summary"] and ra["fails"] == rb["fails"]
ma = json.loads(run(["tools/audio/mix_report.py", f"--rec={src}", "--no-publish"]))
mb = json.loads(run(["tools/audio/mix_report.py", f"--rec={dst}", "--no-publish"]))
same_mix = ma == mb
print(f"2. rerender identical: {same_rr} | repetition_check identical: {same_rep} | mix_report identical: {same_mix}")
shutil.rmtree(dst)
sys.exit(0 if (n == len(names) and names[:12] == old["cue_fields"] and same_rr and same_rep and same_mix) else 1)
