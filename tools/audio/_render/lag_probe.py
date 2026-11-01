"""Scratch (05-audio v3.9): how far is the cue-log time (wall clock) from the recorded audio time, along the recording?"""
import json
import sys
import wave
from pathlib import Path

import numpy as np

sys.argv, ARGV = sys.argv[:1], sys.argv[1:]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import same_bg_ab as T  # noqa: E402

d = Path(__file__).resolve().parent / ARGV[0]
meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
NEW = T.AssetSet(None)
SR = 22050


def rd(p):
    with wave.open(str(p), "rb") as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
        sr, ch = w.getframerate(), w.getnchannels()
    x = x.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        x = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    return x, sr


sf, sr0 = rd(d / "rec_sfx.wav")
n = len(sf)
out = np.zeros(n + SR * 2)
for q in meta["cues"]:
    c = NEW.man["cues"].get(q[1])
    if not c or c["bus"] != "SFX":
        continue
    s = NEW.file(c["files"][int(q[2]) % len(c["files"])]) * 10 ** (float(q[4]) / 20)
    a = int(q[0] * SR)
    out[a:a + len(s)] += s[: len(out) - a]
out = out[:n]
hop = int(0.01 * SR)
env = lambda x: np.array([np.sum(x[i:i + hop] ** 2) for i in range(0, len(x) - hop, hop)])
er, es = np.log10(env(out) + 1e-9), np.log10(env(sf) + 1e-9)
m = min(len(er), len(es))
er, es = er[:m], es[:m]
print(f"mix_rate {sr0}, audio {n / SR:.3f} s, wall {meta['seconds']:.3f} s, cues {len(meta['cues'])}")
W, H, L = 400, 200, 150   # 4 s window, 2 s hop, +-1.5 s lag (10 ms units)
for st in range(L, m - W - L, H):
    a = es[st:st + W]
    best = max(range(-L, L + 1), key=lambda k: np.corrcoef(a, er[st + k:st + k + W])[0, 1])
    r = np.corrcoef(a, er[st + best:st + best + W])[0, 1]
    print(f"audio t {st / 100:6.1f} s: log time = audio time {best * 10:+5d} ms (corr {r:.2f})")
