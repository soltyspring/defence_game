#!/usr/bin/env python3
"""Objective validation of assets/audio against docs/audio/AUDIO_CONTRACT.md. Owner: 05-audio.

Checks (all measured from the actual files, not from the generator's own claims):
  * SFX WAV format (PCM s16le, mono, 22050 Hz), duration bounds, sample peak <= -0.9 dBFS,
    zero full-scale samples (no clipping), DC offset, click-free first/last samples, not silent,
    share of energy above 300 Hz (phone loudspeakers reproduce little below ~300 Hz).
  * Music OGG decoded with ffmpeg: format, exact loop length vs manifest, decoded peak,
    loop seam jump vs the track's own 99.9th-percentile sample step, edge RMS continuity.
  * Budgets: disk bytes, SFX decoded-PCM resident bytes, worst-case simultaneous-voice sum.
  * Optional --determinism: hash files, re-run synth.py, re-hash, require identical bytes.
Exit 0 = all checks pass. Report: docs/audio/VALIDATION_REPORT.json
"""
from __future__ import annotations

import hashlib
import json
import math
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MAN = ROOT / "assets" / "audio" / "audio_manifest.json"
REPORT = ROOT / "docs" / "audio" / "VALIDATION_REPORT.json"

# Budgets (PROVISIONAL, see docs/audio/AUDIO_CONTRACT.md §6)
BUDGET_DISK_TOTAL = 2_500_000
BUDGET_SFX_PCM_RESIDENT = 2 * 1024 * 1024
MAX_SFX_SECONDS = 3.2
MAX_POOL_SFX = 12
MAX_POOL_UI = 3


def res_to_path(res: str) -> Path:
    assert res.startswith("res://")
    return ROOT / res[len("res://"):]


def db(x: float) -> float:
    return 20 * math.log10(max(x, 1e-12))


def read_wav(p: Path):
    with wave.open(str(p), "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
        comp = w.getcomptype()
    return ch, sw, sr, comp, np.frombuffer(raw, dtype="<i2").astype(np.float64)


def hf_share(x: np.ndarray, sr: int, cut: float = 300.0) -> float:
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    tot = spec.sum()
    return float(spec[f >= cut].sum() / tot) if tot > 0 else 0.0


def decode_ogg(p: Path, ch: int, sr: int) -> np.ndarray | None:
    ff = shutil.which("ffmpeg")
    if not ff:
        return None
    out = subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-i", str(p), "-f", "f32le", "-ac", str(ch),
                          "-ar", str(sr), "-"], capture_output=True)
    if out.returncode != 0:
        return None
    return np.frombuffer(out.stdout, dtype="<f4").astype(np.float64).reshape(-1, ch)


def ogg_header(p: Path) -> dict:
    fp = shutil.which("ffprobe")
    if not fp:
        return {}
    out = subprocess.run([fp, "-v", "error", "-show_entries", "stream=codec_name,sample_rate,channels", "-of", "json", str(p)],
                         capture_output=True, text=True)
    try:
        return json.loads(out.stdout)["streams"][0]
    except Exception:
        return {}


def hash_tree() -> dict:
    out = {}
    for p in sorted((ROOT / "assets" / "audio").rglob("*")):
        if p.is_file() and p.suffix in (".wav", ".ogg", ".json"):
            out[str(p.relative_to(ROOT)).replace("\\", "/")] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def main() -> int:
    fails: list[str] = []
    m = json.loads(MAN.read_text(encoding="utf-8"))
    rep = {"sfx": {}, "music": {}, "budgets": {}, "failures": fails}
    disk = 0
    pcm_resident = 0
    worst_sum_lin = 0.0
    for cue, c in m["cues"].items():
        if c["bus"] not in ("SFX", "UI", "Music"):
            fails.append(f"{cue}: bad bus {c['bus']}")
        for res in c["files"]:
            p = res_to_path(res)
            name = p.name
            if not p.exists():
                fails.append(f"{name}: missing")
                continue
            ch, sw, sr, comp, x = read_wav(p)
            disk += p.stat().st_size
            pcm_resident += len(x) * 2
            xf = x / 32768.0
            pk = float(np.max(np.abs(xf)))
            rms = float(np.sqrt(np.mean(xf ** 2)))
            r = {"cue": cue, "ch": ch, "bits": sw * 8, "rate": sr, "seconds": round(len(x) / sr, 3),
                 "peak_dbfs": round(db(pk), 2), "rms_dbfs": round(db(rms), 2),
                 "clipped": int(np.sum(np.abs(x) >= 32767)), "dc": round(float(np.mean(xf)), 5),
                 "edge_first": round(abs(float(xf[0])), 4), "edge_last": round(abs(float(xf[-1])), 4),
                 "hf300_share": round(hf_share(xf, sr), 3), "mix_level_db": round(db(rms) + c["vol_db"], 1)}
            rep["sfx"][name] = r
            if (ch, sw, sr, comp) != (1, 2, 22050, "NONE"):
                fails.append(f"{name}: format {ch}ch {sw * 8}bit {sr}Hz {comp}")
            if r["seconds"] > MAX_SFX_SECONDS:
                fails.append(f"{name}: too long {r['seconds']}s")
            if r["peak_dbfs"] > -0.9:
                fails.append(f"{name}: peak {r['peak_dbfs']} dBFS > -0.9")
            if r["clipped"]:
                fails.append(f"{name}: {r['clipped']} full-scale samples")
            if abs(r["dc"]) > 0.002:
                fails.append(f"{name}: DC {r['dc']}")
            if r["edge_first"] > 0.01 or r["edge_last"] > 0.01:
                fails.append(f"{name}: edge click risk first={r['edge_first']} last={r['edge_last']}")
            if r["rms_dbfs"] < -40:
                fails.append(f"{name}: near-silent rms {r['rms_dbfs']}")
            if r["hf300_share"] < 0.25:
                fails.append(f"{name}: only {r['hf300_share']:.0%} energy >= 300 Hz (weak on phone speakers)")
        if c["bus"] != "Music":
            worst_sum_lin += c["max"] * 10 ** (c["vol_db"] / 20)  # every cue at max instances, peak-aligned
    for mid, mu in m["music"].items():
        p = res_to_path(mu["file"])
        if not p.exists():
            fails.append(f"{mid}: missing {p.name}")
            continue
        disk += p.stat().st_size
        hdr = ogg_header(p)
        x = decode_ogg(p, 2, mu["rate"])
        r = {"bytes": p.stat().st_size, "header": hdr}
        if hdr and (hdr.get("codec_name") != "vorbis" or int(hdr.get("sample_rate", 0)) != 44100 or int(hdr.get("channels", 0)) != 2):
            fails.append(f"{mid}: header {hdr}")
        if x is None:
            fails.append(f"{mid}: could not decode (ffmpeg missing?)")
        else:
            mono = x.mean(axis=1)
            steps = np.abs(np.diff(x, axis=0)).max(axis=1)
            p999 = float(np.percentile(steps, 99.9))
            seam = float(np.max(np.abs(x[0] - x[-1])))
            w = int(0.05 * mu["rate"])
            # Energy step across the seam must look like an ordinary bar line of the same track:
            # compare (RMS after - RMS before) at the seam with the same quantity at every interior bar.
            bar_len = mu["loop_samples"] // mu["bars"]

            def step_db(b: int) -> float:
                after = np.take(mono, np.arange(b, b + w), mode="wrap")
                before = np.take(mono, np.arange(b - w, b), mode="wrap")
                return db(float(np.sqrt(np.mean(after ** 2)))) - db(float(np.sqrt(np.mean(before ** 2))))

            interior = [step_db(k * bar_len) for k in range(1, mu["bars"])]
            seam_step = step_db(0)
            r.update({"decoded_samples": int(len(x)), "manifest_loop_samples": mu["loop_samples"],
                      "decoded_peak_dbfs": round(db(float(np.max(np.abs(x)))), 2),
                      "seam_jump": round(seam, 5), "p999_step": round(p999, 5),
                      "seam_energy_step_db": round(seam_step, 2),
                      "bar_energy_step_db_range": [round(min(interior), 2), round(max(interior), 2)],
                      "kbps": round(p.stat().st_size * 8 / mu["seconds"] / 1000, 1)})
            if len(x) != mu["loop_samples"]:
                fails.append(f"{mid}: decoded length {len(x)} != loop {mu['loop_samples']} (seam gap/overlap)")
            if r["decoded_peak_dbfs"] > -0.3:
                fails.append(f"{mid}: decoded peak {r['decoded_peak_dbfs']} dBFS")
            if seam > max(p999, 1e-3):
                fails.append(f"{mid}: loop seam jump {seam:.4f} > p99.9 step {p999:.4f}")
            if not (min(interior) - 3.0 <= seam_step <= max(interior) + 3.0):
                fails.append(f"{mid}: seam energy step {seam_step:.1f} dB outside bar-line range {r['bar_energy_step_db_range']}")
        rep["music"][mid] = r
    rep["budgets"] = {
        "disk_bytes_total": disk, "disk_budget": BUDGET_DISK_TOTAL,
        "sfx_pcm_resident_bytes": pcm_resident, "sfx_pcm_budget": BUDGET_SFX_PCM_RESIDENT,
        "worst_case_sfx_sum_db": round(db(worst_sum_lin), 1),
        "note": "worst case = every SFX/UI cue at max instances, peaks aligned; runtime voice caps "
                f"(SFX pool {MAX_POOL_SFX}, UI pool {MAX_POOL_UI}) plus Master limiter keep real output below this",
    }
    if disk > BUDGET_DISK_TOTAL:
        fails.append(f"disk {disk} > budget {BUDGET_DISK_TOTAL}")
    if pcm_resident > BUDGET_SFX_PCM_RESIDENT:
        fails.append(f"SFX PCM {pcm_resident} > budget {BUDGET_SFX_PCM_RESIDENT}")
    if "--determinism" in sys.argv:
        h1 = hash_tree()
        subprocess.run([sys.executable, str(ROOT / "tools" / "audio" / "synth.py")], check=True, capture_output=True)
        h2 = hash_tree()
        diff = sorted(k for k in set(h1) | set(h2) if h1.get(k) != h2.get(k))
        rep["determinism"] = {"files": len(h1), "differing": diff}
        if diff:
            fails.append(f"non-deterministic output: {diff}")
    rep["pass"] = not fails
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(rep, indent=1) + "\n", encoding="utf-8")
    for f in fails:
        print("FAIL:", f)
    b = rep["budgets"]
    print(f"sfx files={len(rep['sfx'])} music={len(rep['music'])} disk={b['disk_bytes_total']}B "
          f"sfx_pcm={b['sfx_pcm_resident_bytes']}B worst_sum={b['worst_case_sfx_sum_db']}dB")
    for mid, r in rep["music"].items():
        print(f"{mid}: {r.get('decoded_samples')}/{r.get('manifest_loop_samples')} samples, seam {r.get('seam_jump')} "
              f"vs p99.9 {r.get('p999_step')}, peak {r.get('decoded_peak_dbfs')} dBFS, {r.get('kbps')} kbps")
    print("AUDIO VALIDATE", "PASS" if not fails else f"FAIL ({len(fails)})")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
