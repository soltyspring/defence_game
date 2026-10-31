#!/usr/bin/env python3
"""Self-test of tools/perf/asset_budget_check.py with synthetic over-cap trees (owner: 08-performance).
Never touches assets/: it extracts the base commit with git archive into build/perf/asset_selftest/ and edits the copies.
Usage: python tests/performance/test_asset_budget_check.py   (exit 0 = all cases behave as specified)
"""
from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import sys
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "perf"))
import asset_budget_check as abc  # noqa: E402

WORK = os.path.join(ROOT, "build", "perf", "asset_selftest")
TOOL = os.path.join(ROOT, "tools", "perf", "asset_budget_check.py")
results = []


def check(name, cond, detail=""):
    results.append((name, bool(cond)))
    print(f"[asset_selftest] {'PASS' if cond else 'FAIL'} {name} {detail}")


def run_tree(tree, extra=()):
    out = os.path.join(WORK, "out")
    r = subprocess.run([sys.executable, TOOL, "--tree", tree, "--out", out, *extra], cwd=ROOT, capture_output=True, text=True)
    rep_path = os.path.join(out, os.path.basename(tree), "report.json")
    rep = json.load(open(rep_path, encoding="utf-8")) if os.path.isfile(rep_path) else {}
    return r.returncode, rep, r.stdout + r.stderr


def variant(name):
    d = os.path.join(WORK, name)
    if os.path.isdir(d):
        shutil.rmtree(d)
    shutil.copytree(BASE, d)
    return d


def write_wav(path, seconds, rate=22050, ch=1):
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"\x00\x00" * ch * int(rate * seconds))


def write_png(path, w, h):
    from PIL import Image
    Image.new("RGBA", (w, h), (0, 0, 0, 0)).save(path)


if os.path.isdir(WORK):
    shutil.rmtree(WORK)
os.makedirs(WORK)
BASE = os.path.join(WORK, "base_copy")
abc.extract_commit(abc.DEFAULT_BASE, BASE)

# 1 identical tree -> PASS, exit 0, no changed files
code, rep, log = run_tree(variant("same"))
check("identical_tree_passes", code == 0 and rep.get("verdict") == "PASS" and not rep.get("files"), f"exit={code}")

# 2 one page enlarged to 2048x1024 -> page side cap + all-pages cap fail, exit 1
d = variant("big_page")
png = os.path.join(d, "assets", "atlases", "char_enemy.png")
write_png(png, 2048, 1024)
code, rep, log = run_tree(d)
check("oversized_page_fails", code == 1 and "page_side:char_enemy" in rep.get("fails", []) and "atlas_all_pages_gpu" in rep.get("fails", []),
      f"exit={code} fails={rep.get('fails')}")
check("oversized_page_gpu_estimate", any(f["id"] == "char_enemy" and f["target"]["gpu"] == 2048 * 1024 * 4 for f in rep.get("files", [])))

# 3 a 4 s SFX -> length cap fail
d = variant("long_sfx")
write_wav(os.path.join(d, "assets", "audio", "sfx", "zz_long.wav"), 4.0)
code, rep, log = run_tree(d)
check("long_sfx_fails", code == 1 and "sfx_length:assets/audio/sfx/zz_long.wav" in rep.get("fails", []), f"exit={code} fails={rep.get('fails')}")

# 4 stereo 44.1 kHz SFX pushing decoded PCM over 2 MiB -> pcm cap fail
d = variant("fat_sfx")
for i in range(5):
    write_wav(os.path.join(d, "assets", "audio", "sfx", f"zz_fat_{i}.wav"), 3.0, rate=44100, ch=2)   # 529 200 B each
code, rep, log = run_tree(d)
check("pcm_over_cap_fails", code == 1 and "sfx_pcm_resident" in rep.get("fails", []), f"exit={code} fails={rep.get('fails')}")

# 5 --report-only never exits 1
code, rep, log = run_tree(d, ("--report-only",))
check("report_only_exit0", code == 0 and rep.get("verdict") == "FAIL", f"exit={code} verdict={rep.get('verdict')}")

# 6 GPU estimate honours .import compress mode / mipmaps
check("gpu_lossless", abc.gpu_estimate(512, 512, {"compress_mode": 0, "mipmaps": False}) == 1048576)
check("gpu_vram_compressed", abc.gpu_estimate(512, 512, {"compress_mode": 2, "mipmaps": False}) == 262144)
check("gpu_mipmaps", abc.gpu_estimate(512, 512, {"compress_mode": 0, "mipmaps": True}) == 1398101)

# 7 OGG header parse on the real committed music
ogg = os.path.join(BASE, "assets", "audio", "music", "music_battle.ogg")
oi = abc.ogg_info(ogg)
check("ogg_parse", oi.get("rate") in (22050, 44100, 48000) and 5 < oi.get("seconds", 0) < 600, json.dumps(oi))

# 8 WAV parse matches the wave module
wi = abc.wav_info(os.path.join(BASE, "assets", "audio", "sfx", "ui_tap.wav"))
with wave.open(os.path.join(BASE, "assets", "audio", "sfx", "ui_tap.wav")) as w:
    frames = w.getnframes() * w.getnchannels() * w.getsampwidth()
check("wav_parse", wi["pcm_bytes"] == frames, f"{wi['pcm_bytes']} vs {frames}")

bad = [n for n, ok in results if not ok]
print(f"[asset_selftest] {'ALL PASS' if not bad else 'FAILED: ' + ', '.join(bad)} ({len(results) - len(bad)}/{len(results)})")
sys.exit(0 if not bad else 1)
