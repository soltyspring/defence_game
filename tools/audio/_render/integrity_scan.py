"""Scratch (05-audio): post-crash integrity scan of modified/new 05 files and job files."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
files = [l[3:].strip() for l in subprocess.run(["git", "status", "--porcelain", "--", "assets/audio", "src/audio", "tools/audio", "docs/audio",
                                                 "coordination/requests/05-audio-to-08-performance.md", "coordination/handoffs/05-audio.md",
                                                 "coordination/status/05-audio.md"], capture_output=True, text=True, cwd=ROOT).stdout.splitlines()]
files = [f for f in files if "_render/" not in f]
files += ["build/heavy/05-peak-before-job.ps1", "build/heavy/05-peak-after-job.ps1"]
bad = 0
for f in files:
    p = ROOT / f
    if p.is_dir():
        continue
    b = p.read_bytes()
    nul = b.count(b"\x00")
    tail_nul = len(b) - len(b.rstrip(b"\x00"))
    eol = b.endswith(b"\n")
    head = subprocess.run(["git", "cat-file", "-s", f"HEAD:{f}"], capture_output=True, text=True, cwd=ROOT).stdout.strip()
    flag = "" if (len(b) > 0 and nul == 0 and eol) else "  <-- CHECK"
    bad += bool(flag)
    print(f"{f:55s} {len(b):7d} B (HEAD {head or '-':>6}) NUL {nul} tailNUL {tail_nul} EOL {eol}{flag}")
try:
    for f in [x for x in files if x.endswith(".py")]:
        compile((ROOT / f).read_text(encoding="utf-8"), f, "exec")
    print("python compile OK")
except SyntaxError as e:
    print("PY SYNTAX", e)
    bad += 1
sys.exit(1 if bad else 0)
