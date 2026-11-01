"""Scratch (05-audio v4.0): explosion candidates vs T1 (audible end <= 0.50 s at slowest pitch) and the attack guard."""
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/audio"))
import phone_check as P  # noqa: E402
import synth as S  # noqa: E402


def cand(rng, L, tau, thump_d, bub0, bub_step, hiss_r):
    n = S.n_samples(L, S.SR)
    body = S.lowpass(S.noise(n, rng), S.ramp(3500, 400, n), S.SR) * S.env_exp(n, S.SR, tau, 0.002)
    out = S.mix(body, S.thump(180, 90, min(0.45, L - 0.05), thump_d) * 0.35, S.squelch(rng, 0.3, 300, 1200, 250, wet=0.8) * 0.9)
    for i in range(6):
        S.place(out, S.bubble(rng.uniform(350, 900), 0.03) * 0.3, S.n_samples(bub0 + bub_step * i, S.SR))
    hiss = S.highpass(S.noise(n, rng), 4000, S.SR) * S.env_adsr(n, S.SR, 0.05, 0.1, 0.25, hiss_r) * 0.1
    return S.mix(out, hiss)


def fin(x):
    return S.fade_edges(S.normalize(S.highpass(np.asarray(x, dtype=np.float64), 30.0, S.SR), S.SFX_PEAK), S.SR)


fr = int(0.01 * S.SR)


def end(sig):
    e = np.array([np.mean(sig[i:i + fr] ** 2) for i in range(0, len(sig) - fr + 1, fr)])
    db = 10 * np.log10(np.maximum(e, 1e-14))
    return (np.where(db >= db.max() - 30)[0][-1] + 1) * fr / S.SR


def attack(sig):
    ph = P.phone(sig[: int(0.1 * S.SR)])
    k = P.k_weight(ph, S.SR) ** 2
    return 10 * np.log10(np.mean(k) + 1e-14)


seed = 1000 + 1 + sum(len(c["r"]) for k, c in S.CUES.items() if list(S.CUES).index(k) < list(S.CUES).index("explosion"))
cur = P.read_wav(ROOT / "assets/audio/sfx/explosion.wav")
ref = attack(cur)
print(f"explosion seed {seed}; current: end {end(cur):.2f} s (slowest {end(cur) / 0.94:.2f}), attack {ref:.2f} dB")
same = fin(cand(np.random.default_rng(seed), 0.7, 0.15, 0.14, 0.15, 0.07, 0.4))
print("check: recipe copy reproduces the file:", np.max(np.abs(np.round(same * 32767) / 32767 - cur)) < 2e-4)
for p in [(0.5, 0.12, 0.10, 0.12, 0.05, 0.2), (0.5, 0.11, 0.09, 0.12, 0.045, 0.18), (0.48, 0.10, 0.09, 0.10, 0.045, 0.15), (0.5, 0.12, 0.10, 0.10, 0.05, 0.15)]:
    x = fin(cand(np.random.default_rng(seed), *p))
    print(p, f"end {end(x):.2f} slowest {end(x) / 0.94:.2f} | attack {attack(x) - ref:+.2f} dB | len {len(x) / S.SR:.3f}")
