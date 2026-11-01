"""Scratch (05-audio, v3.8): death_enemy_v2 candidates vs death_enemy.wav on re-rendered battle backgrounds."""
import json
import sys
from pathlib import Path

sys.argv = ["x", "--before=64a95c6", "--tag=rb", "--rounds=" + (sys.argv[1] if len(sys.argv) > 1 else "r02"), "--seeds=11,23,37"]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import numpy as np  # noqa: E402
import phone_check as P  # noqa: E402
import same_bg_ab as T  # noqa: E402
import synth as S  # noqa: E402

B = T.AssetSet(None)
c = B.man["cues"]["death_enemy"]
ci = list(S.CUES).index("death_enemy")


def fin(x):
    return S.fade_edges(S.normalize(S.highpass(np.asarray(x, dtype=np.float64), 30.0, S.SR), S.SFX_PEAK), S.SR)


def de(rng, sq, times, bg, bstep, sqlo=560, sqhi=1550, fz=0.08):
    out = np.zeros(S.n_samples(0.40, S.SR))
    S.place(out, S.squelch(rng, sq, sqlo, sqhi, 400, wet=0.7), 0)
    for i, (t0, f) in enumerate(zip(times, [430, 610, 820])):
        S.place(out, S.bubble(f * rng.uniform(0.94, 1.06), 0.03) * (bg - bstep * i), S.n_samples(t0, S.SR))
    n = len(out)
    return out + S.bandpass(S.noise(n, rng), 3200, 7500, S.SR) * S.env_adsr(n, S.SR, 0.08, 0.1, 0.3, 0.2) * fz


def de4(rng, sq, times, freqs, bg, bstep, sqlo, sqhi, sqend, fz=0.08):
    """v1-like envelope (4 bubbles over 0.3 s) with a different formant range and bubble pitches."""
    out = np.zeros(S.n_samples(0.42, S.SR))
    S.place(out, S.squelch(rng, sq, sqlo, sqhi, sqend, wet=0.7), 0)
    for i, (t0, f) in enumerate(zip(times, freqs)):
        S.place(out, S.bubble(f * rng.uniform(0.94, 1.06), 0.03) * (bg - bstep * i), S.n_samples(t0, S.SR))
    n = len(out)
    return out + S.bandpass(S.noise(n, rng), 3200, 7500, S.SR) * S.env_adsr(n, S.SR, 0.1, 0.1, 0.3, 0.2) * fz


cands = {"v1": P.read_wav(T.ROOT / "assets/audio/sfx/death_enemy.wav"), "cur": P.read_wav(T.ROOT / "assets/audio/sfx/death_enemy_v2.wav")}
D3 = (0.22, (0.12, 0.18, 0.25, 0.31), (460, 600, 780, 1000), 0.5, 0.08, 450, 1300, 320)


def drive(x, k):
    x = x / np.max(np.abs(x))
    return np.tanh(k * x) / np.tanh(k)


for k in (0.8, 1.0, 1.2, 1.35):
    cands[f"d3k{k}"] = fin(drive(de4(np.random.default_rng(70000 + 10 * ci), *D3), k))
for nm, p in {}.items():
    cands[nm] = fin(de4(np.random.default_rng(70000 + 10 * ci), *p))
bgs = []
for key, d in T.rec_dirs():
    meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
    mu = P.read_wav(d / "rec_music.wav")
    sf = P.read_wav(d / "rec_sfx.wav")
    n = min(len(mu), len(sf))
    mu = mu[:n]
    scale = (n / T.SR) / float(meta["seconds"])
    g = np.array([[q[0] * scale, q[1]] for q in meta["music_gain"]])
    bm = P.phone(mu * 10 ** (np.interp(np.arange(n) / T.SR, g[:, 0], g[:, 1]) / 20))
    ev = [(q[0] * scale, q[1]) for q in meta["cues"]]
    bgs.append((key, bm, P.phone(T.render_bg(B, ev, n, True, 1000))))
fr = int(0.05 * S.SR)


def lvl(x):
    k = P.k_weight(np.pad(P.phone(x), (0, fr)), P.SR) ** 2
    e = np.array([k[i * fr:(i + 1) * fr].mean() for i in range(max(1, len(x) // fr))])
    return float(10 * np.log10(e[e >= e.max() * 10 ** -1.5].mean()))


ref = lvl(cands["v1"])
for nm, x in cands.items():
    r = [T.snr_stats(x * 10 ** (c["vol_db"] / 20), bm, bb, c) for _k, bm, bb in bgs]
    k = P.k_weight(np.pad(P.phone(x), (0, fr)), P.SR) ** 2
    e = 10 * np.log10(np.maximum([k[i * fr:(i + 1) * fr].mean() for i in range(len(x) // fr)], 1e-14))
    print(f"{nm:7s} lvl {lvl(x) - ref:+.2f} mean masked {np.mean([q['masked_pct'] for q in r]):5.1f} p10 {np.mean([q['p10'] for q in r]):5.1f} |",
          " | ".join(f"{q['masked_pct']:5.1f}% p10 {q['p10']:5.1f}" for q in r),
          "| frames", " ".join(f"{v:.0f}" for v in e))
