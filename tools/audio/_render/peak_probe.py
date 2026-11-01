"""Scratch (05-audio v3.8): where is the master peak of a recording, and which cues sound around it."""
import json
import sys
import wave
from pathlib import Path

import numpy as np

d = Path(__file__).resolve().parent / sys.argv[1]


def rd(p):
    with wave.open(str(p), "rb") as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
        return x.reshape(-1, w.getnchannels()), w.getframerate()


meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
m, sr = rd(d / "rec_master.wav")
a = np.abs(m).max(axis=1)
i = int(a.argmax())
dur = len(a) / sr
scale = dur / float(meta["seconds"])
t = i / sr
print(f"master peak {20 * np.log10(a[i]):.2f} dBFS at {t:.3f} s (audio), {np.sum(a > 10 ** (-1 / 20))} samples above -1 dBFS,"
      f" {np.sum(a > 10 ** (-0.6 / 20))} above -0.6")
over = np.where(a > 10 ** (-1 / 20))[0]
if len(over):
    print("times above -1 dBFS:", sorted({round(x / sr, 2) for x in over})[:20])
for st in ("rec_sfx.wav", "rec_ui.wav", "rec_music.wav"):
    x, _ = rd(d / st)
    w = np.abs(x[max(0, i - 2205):i + 2205]).max()
    print(f"  {st}: peak near master peak {20 * np.log10(max(w, 1e-9)):.2f} dBFS (pre-fader stem), whole-stem peak {20 * np.log10(np.abs(x).max()):.2f}")
print("sfx_bus_db", meta.get("sfx_bus_db"), "limiter", meta.get("limiter"))
for q in meta["cues"]:
    tq = q[0] * scale
    if t - 0.6 <= tq <= t + 0.1:
        print(f"  cue {tq:7.3f} s  {q[1:]}")
