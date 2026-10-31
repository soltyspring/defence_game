#!/usr/bin/env python3
"""Theme showcase for listeners: faction A/B pairs + boss/win/defeat cues. Owner: 05-audio.

This is an OFFLINE concatenation of the shipped asset files at their manifest mix gains (vol_db), with
silence between items; it is not an engine recording (the battle recording is battle_preview_30s.mp3).
Use it to judge whether bakery (dry/warm) and mold (wet/sticky) are told apart by ear.
Output: docs/audio/previews/listen/theme_showcase.mp3 + theme_showcase.txt (timestamps).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MAN = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))
OUT = ROOT / "docs/audio/previews/listen"
SR = 22050
ORDER = [  # (label, cue, variant index)
    ("BAKERY  a bread soldier is hit (crust crunch)", "hit_bread", 0),
    ("MOLD    a mold unit is hit (wet squish)", "hit_mold", 0),
    ("BAKERY  bread soldier dies (crumble)", "death_ally", 0),
    ("MOLD    mold blob dies (squelch + bubbles)", "death_enemy", 0),
    ("BAKERY  bakery tower hit", "hit_base", 0),
    ("MOLD    mold hive hit", "hit_base_mold", 0),
    ("BAKERY  troop deployed (oven bell)", "deploy", 0),
    ("MOLD    spore spitter shot", "shoot_spit", 0),
    ("BAKERY  wave alarm bell", "wave_incoming", 0),
    ("MOLD    boss incoming", "boss_incoming", 0),
    ("BAKERY  victory", "stinger_win", 0),
    ("MOLD    defeat", "stinger_defeat", 0),
]


def read(p: Path) -> np.ndarray:
    with wave.open(str(p), "rb") as w:
        assert w.getframerate() == SR and w.getnchannels() == 1
        return np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0


def main() -> int:
    parts, lines, t = [], [], 0.0
    gap = np.zeros(int(0.6 * SR))
    for label, cue, vi in ORDER:
        c = MAN["cues"][cue]
        x = read(ROOT / c["files"][vi][len("res://"):])
        g = min(10 ** ((c["vol_db"] + 6) / 20), 0.89 / max(float(np.abs(x).max()), 1e-9))  # +6 dB, capped at -1 dBFS peak
        x = x * g
        lines.append(f"{t:6.2f}s  {label}  [{cue}, vol_db {c['vol_db']}]")
        parts += [x, gap]
        t += (len(x) + len(gap)) / SR
    y = np.concatenate(parts)
    peak = float(np.abs(y).max())
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = OUT / "theme_showcase.wav.part"
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(np.round(y * 32767).astype("<i2").tobytes())
    subprocess.run([shutil.which("ffmpeg"), "-hide_banner", "-loglevel", "error", "-y", "-f", "wav", "-i", str(tmp),
                    "-map_metadata", "-1", "-c:a", "libmp3lame", "-b:a", "128k", str(OUT / "theme_showcase.mp3")], check=True)
    tmp.unlink()
    (OUT / "theme_showcase.txt").write_text(
        "Theme showcase (offline concatenation of shipped assets at manifest gain +6 dB, each item capped at -1 dBFS peak; NOT an engine recording)\n"
        + "\n".join(lines) + f"\npeak {20 * np.log10(peak):.2f} dBFS, full-scale samples: {int(np.sum(np.abs(y) >= 0.999))}\n", encoding="utf-8")
    print("\n".join(lines), f"\ntotal {t:.1f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
