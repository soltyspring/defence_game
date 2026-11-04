#!/usr/bin/env python3
"""Deterministic original audio generator for the lane-defence game. Owner: 05-audio.

Every sound is synthesised from scratch with numpy (oscillators, noise, envelopes,
one-pole filters). No samples, no downloaded material, no AI audio service.
Same script + same seeds -> identical PCM (OGG via ffmpeg/libvorbis with bitexact flags).

Usage (workspace root):
    python tools/audio/synth.py            # writes assets/audio/** + assets/audio/audio_manifest.json
    python tools/audio/validate.py         # objective checks (format, peaks, clipping, loop seams, budgets)

Requires: python 3.10+, numpy. Music OGG encode requires ffmpeg with libvorbis on PATH
(if missing, music is skipped and reported; SFX still build).
"""
from __future__ import annotations

import json
import math
import os
import shutil
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
SFX_DIR = OUT / "sfx"
MUSIC_DIR = OUT / "music"
SRC_DIR = ROOT / "tools" / "audio" / "_render"   # git-ignored intermediate WAV for music (see .gitignore request)

SFX_SR = 22050          # mono 16-bit PCM; chip-style SFX do not need >11 kHz bandwidth
MUSIC_SR = 44100        # stereo, encoded to Ogg Vorbis (streamed, not decompressed into RAM)
SFX_PEAK = 10 ** (-1.0 / 20)    # -1 dBFS sample peak ceiling
MUSIC_PEAK = 10 ** (-3.0 / 20)  # -3 dBFS before lossy encode (leaves inter-sample/encoder headroom)
GENERATOR_VERSION = 8

# ----------------------------------------------------------------------------------------------
# DSP primitives
# ----------------------------------------------------------------------------------------------

def n_samples(d: float, sr: int) -> int:
    return max(1, int(round(d * sr)))


def ramp(a: float, b: float, n: int, curve: str = "exp") -> np.ndarray:
    """Frequency/parameter sweep from a to b over n samples."""
    x = np.linspace(0.0, 1.0, n, endpoint=False)
    if curve == "exp" and a > 0 and b > 0:
        return a * (b / a) ** x
    return a + (b - a) * x


def _polyblep(t: np.ndarray, dt: np.ndarray) -> np.ndarray:
    out = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m2 = t > 1.0 - dt
    x2 = (t[m2] - 1.0) / dt[m2]
    out[m2] = x2 * x2 + x2 + x2 + 1.0
    return out


def osc(freq, n: int, sr: int, shape: str = "sine", duty: float = 0.5, phase0: float = 0.0) -> np.ndarray:
    """Band-limited-ish oscillator. freq: scalar or per-sample array (Hz)."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,)).copy()
    dt = np.clip(f / sr, 1e-9, 0.5)
    ph = (phase0 + np.cumsum(dt) - dt[0]) % 1.0
    if shape == "sine":
        return np.sin(2 * np.pi * ph)
    if shape == "tri":
        return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0
    if shape == "saw":
        return (2.0 * ph - 1.0) - _polyblep(ph, dt)
    if shape == "square":
        sq = np.where(ph < duty, 1.0, -1.0)
        sq += _polyblep(ph, dt)
        sq -= _polyblep((ph - duty) % 1.0, dt)
        return sq
    raise ValueError(shape)


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def env_exp(n: int, sr: int, tau: float, attack: float = 0.002) -> np.ndarray:
    t = np.arange(n) / sr
    e = np.exp(-t / max(tau, 1e-4))
    a = n_samples(attack, sr)
    if a > 1:
        e[:a] *= np.linspace(0.0, 1.0, a)
    return e


def env_adsr(n: int, sr: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    na, nd, nr = n_samples(a, sr), n_samples(d, sr), n_samples(r, sr)
    ns = max(0, n - na - nd - nr)
    e = np.concatenate([
        np.linspace(0, 1, na, endpoint=False),
        np.linspace(1, s, nd, endpoint=False),
        np.full(ns, s),
        np.linspace(s, 0, nr),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def lowpass(x: np.ndarray, cutoff, sr: int) -> np.ndarray:
    """One-pole low-pass; cutoff scalar or per-sample array (Hz)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * np.clip(c, 10.0, sr * 0.45) / sr)
    y = np.empty_like(x)
    acc = 0.0
    xl = x.tolist()
    al = a.tolist()
    for i in range(len(xl)):
        acc += al[i] * (xl[i] - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff, sr: int) -> np.ndarray:
    return x - lowpass(x, cutoff, sr)


def bandpass(x: np.ndarray, lo, hi, sr: int) -> np.ndarray:
    return lowpass(highpass(x, lo, sr), hi, sr)


def place(buf: np.ndarray, sig: np.ndarray, at: int, wrap: bool = False) -> None:
    """Add sig into buf at sample offset; wrap=True folds overflow to the start (seamless loops)."""
    L = len(buf)
    if wrap:
        idx = (np.arange(len(sig)) + at) % L
        np.add.at(buf, idx, sig)
        return
    end = min(L, at + len(sig))
    if end > at:
        buf[at:end] += sig[: end - at]


def fade_edges(x: np.ndarray, sr: int, fin: float = 0.002, fout: float = 0.008) -> np.ndarray:
    a, b = n_samples(fin, sr), n_samples(fout, sr)
    x = x.copy()
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def normalize(x: np.ndarray, peak: float) -> np.ndarray:
    x = x - np.mean(x)  # DC removal
    m = float(np.max(np.abs(x)))
    return x if m < 1e-9 else x * (peak / m)


def midi_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12.0)


NOTE_IDX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_midi(name: str) -> int:
    """'C5', 'F#4', 'Bb3' -> midi."""
    base = NOTE_IDX[name[0]]
    rest = name[1:]
    acc = 0
    while rest and rest[0] in "#b":
        acc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + base + acc


def to_pcm16(x: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """TPDF dither to 16-bit."""
    d = (rng.uniform(-0.5, 0.5, x.shape) + rng.uniform(-0.5, 0.5, x.shape))
    return np.clip(np.round(x * 32767.0 + d), -32768, 32767).astype("<i2")


def replace_retry(tmp: Path, dst: Path, tries: int = 40) -> None:
    """Atomic replace with retries: other workers' headless Godot runs on the shared project scan and
    reimport assets/audio, briefly holding files open on Windows (seen as EINVAL/permission errors)."""
    import time
    for i in range(tries):
        try:
            os.replace(tmp, dst)
            return
        except OSError:
            time.sleep(0.25)
    raise OSError(f"could not replace {dst} (file held open by another process)")


def write_wav(path: Path, x: np.ndarray, sr: int, seed: int) -> None:
    final = path
    path = path.with_name(path.name + ".tmp")
    path.parent.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed + 991)
    ch = 1 if x.ndim == 1 else x.shape[1]
    pcm = to_pcm16(x, rng)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    replace_retry(path, final)

# ----------------------------------------------------------------------------------------------
# SFX recipes (mono, SFX_SR). Each returns float array; final normalisation + edge fades applied.
# ----------------------------------------------------------------------------------------------
SR = SFX_SR


def blip(f0, f1, dur, shape="square", duty=0.5, tau=None, curve="exp"):
    n = n_samples(dur, SR)
    s = osc(ramp(f0, f1, n, curve), n, SR, shape, duty)
    return s * (env_exp(n, SR, tau) if tau else env_adsr(n, SR, 0.002, dur * 0.3, 0.6, dur * 0.5))


def mix(*xs):
    """Sum signals of different lengths (zero-padded to the longest)."""
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[: len(x)] += x
    return out


def seq(notes, total: float):
    """notes: list of (t_sec, signal)."""
    buf = np.zeros(n_samples(total, SR))
    for t0, sig in notes:
        place(buf, sig, n_samples(t0, SR))
    return buf


def thump(f0, f1, dur, tau, drive=3.0):
    """Pitched impact body. tanh drive adds odd harmonics (3f, 5f...) so low thumps stay
    audible on phone loudspeakers that roll off below ~300 Hz."""
    n = n_samples(dur, SR)
    s = osc(ramp(f0, f1, n), n, SR, "sine")
    if drive > 0:
        s = np.tanh(drive * s) / np.tanh(drive)
    return s * env_exp(n, SR, tau, 0.001)


def crunch_layer(rng, dur, tau, gain=0.6):
    """Mid-band transient layer (700 Hz-4 kHz) carrying impacts on small speakers."""
    return burst(rng, dur, tau, 700, 4000) * gain


def burst(rng, dur, tau, lo, hi, cutoff_end=None):
    n = n_samples(dur, SR)
    x = noise(n, rng)
    if cutoff_end:
        x = lowpass(highpass(x, lo, SR), ramp(hi, cutoff_end, n), SR)
    else:
        x = bandpass(x, lo, hi, SR)
    return x * env_exp(n, SR, tau, 0.001)


def r_ui_tap(rng):
    return blip(1250, 1650, 0.045, "square", 0.25, tau=0.014)


def r_ui_back(rng):
    return seq([(0, blip(990, 880, 0.04, "square", 0.25, tau=0.012)),
                (0.045, blip(700, 620, 0.06, "square", 0.25, tau=0.02))], 0.12)


def r_ui_confirm(rng):
    return seq([(0, blip(midi_hz(76), midi_hz(76), 0.06, "square", 0.25, tau=0.025)),
                (0.06, blip(midi_hz(83), midi_hz(83), 0.12, "square", 0.25, tau=0.05))], 0.2)


def r_ui_error(rng):
    a = blip(311, 294, 0.08, "square", 0.5, tau=0.05)
    return lowpass(seq([(0, a), (0.1, a)], 0.2), 4000, SR)


def r_deploy(rng):
    whoosh = burst(rng, 0.22, 0.09, 300, 900, cutoff_end=4500) * 0.6
    arp = seq([(0.02 + i * 0.045, blip(midi_hz(m), midi_hz(m), 0.07, "square", 0.25, tau=0.03) * 0.5)
               for i, m in enumerate([67, 72, 76])], 0.26)
    stomp = thump(160, 70, 0.12, 0.04) * 0.7
    return mix(whoosh, arp, stomp)


def r_worker_buy(rng):
    # rising three-note 'ka-ching' (A5, D6, A6) with a soft bell partial
    out = np.zeros(n_samples(0.42, SR))
    for t0, m, d in [(0.0, 81, 0.06), (0.055, 86, 0.08), (0.12, 93, 0.3)]:
        n = n_samples(d, SR)
        f = midi_hz(m)
        s = (osc(f, n, SR, "square", 0.5) * 0.5 + osc(f * 2.01, n, SR, "sine") * 0.3) * env_exp(n, SR, d * 0.5)
        place(out, s, n_samples(t0, SR))
    return out


def r_gold_tick(rng):
    return seq([(0, blip(1760, 1760, 0.035, "square", 0.25, tau=0.012) * 0.6),
                (0.03, blip(2349, 2349, 0.07, "sine", tau=0.03))], 0.11)


def r_quality_bread(rng, var):
    """A rounded wooden knock and a little crust, without the old high-frequency crackle."""
    p = [1.0, 0.91, 1.09][var % 3]
    body = thump(470 * p, 260 * p, 0.105, 0.026, drive=0.0)
    cloth = burst(rng, 0.065, 0.025, 450, 2200) * 0.18
    return lowpass(mix(body, cloth), 2800, SR)


def r_quality_mold(rng, var):
    """A short, soft plop. No hard saturation or abrasive wide-band spray."""
    p = [1.0, 0.92, 1.08][var % 3]
    body = thump(620 * p, 330 * p, 0.095, 0.024, drive=0.0) * 0.7
    wet = squelch(rng, 0.095, 470 * p, 780 * p, 350 * p, wet=0.2) * 0.24
    return lowpass(mix(body, wet), 2400, SR)


def r_flour_delivery(rng):
    return lowpass(mix(thump(180, 110, 0.14, 0.035, drive=0.0), burst(rng, 0.12, 0.04, 300, 1800) * 0.22), 2000, SR)


def r_ui_scout(rng):
    return seq([(0, blip(740, 960, 0.045, "sine", tau=0.018) * 0.6), (0.025, blip(980, 1100, 0.045, "sine", tau=0.018) * 0.3)], 0.08)


def r_hit_melee(rng, var):
    # v2 (MIX_REPORT): body moved above 300 Hz and thinner, crack carries the hit; 5 variants
    p = [1.0, 0.88, 1.12, 0.94, 1.06][var]
    lo = [900, 1100, 800, 1300, 1000][var]
    crack = burst(rng, 0.07, 0.02, lo * p, 5500 * p)
    body = thump(520 * p, 300 * p, 0.06, 0.02) * 0.22
    return highpass(seq([(0, crack), (0.003, body)], 0.1), 220, SR)


def r_hit_arrow(rng):
    click = burst(rng, 0.025, 0.006, 2000, 8000)
    thunk = thump(420, 220, 0.07, 0.022) * 0.5
    return seq([(0, click), (0.002, thunk)], 0.08)


def r_shoot_arrow(rng):
    n = n_samples(0.12, SR)
    x = bandpass(noise(n, rng), ramp(3000, 1200, n), ramp(7000, 2500, n), SR)
    twang = blip(520, 480, 0.08, "tri", tau=0.03) * 0.3
    return x * env_adsr(n, SR, 0.008, 0.03, 0.5, 0.08) + seq([(0, twang)], 0.12)


def r_shoot_rock(rng):
    return highpass(seq([(0, thump(200, 140, 0.15, 0.05) * 0.25), (0.0, crunch_layer(rng, 0.12, 0.04, 1.0))], 0.16), 200, SR)


def r_shoot_spit(rng):
    n = n_samples(0.13, SR)
    gloop = osc(ramp(380, 900, n) + 60 * np.sin(np.arange(n) * 2 * np.pi * 35 / SR), n, SR, "sine")
    return mix(gloop * env_exp(n, SR, 0.05), burst(rng, 0.1, 0.03, 600, 3000) * 0.3)


def r_hit_base(rng):
    boom = thump(140, 70, 0.38, 0.12) * 0.28
    crunch = mix(burst(rng, 0.25, 0.06, 500, 3000, cutoff_end=900), crunch_layer(rng, 0.2, 0.05, 0.7))
    rattle = burst(rng, 0.3, 0.1, 2000, 6000) * 0.25
    return boom + seq([(0, crunch), (0.03, rattle)], 0.38)


def r_explosion(rng):
    n = n_samples(0.7, SR)
    body = lowpass(noise(n, rng), ramp(4000, 200, n), SR) * env_exp(n, SR, 0.18, 0.002)
    rumble = thump(110, 50, 0.6, 0.2) * 0.5
    body = mix(body, crunch_layer(rng, 0.25, 0.07, 0.8))
    return mix(body * 1.2, rumble)


def r_death(rng, enemy: bool):
    f0, f1 = (520, 130) if enemy else (700, 260)
    n = n_samples(0.22, SR)
    tone = osc(ramp(f0, f1, n), n, SR, "square", 0.5 if enemy else 0.25) * env_exp(n, SR, 0.07)
    puff = burst(rng, 0.2, 0.06, 400, 3500, cutoff_end=800) * 0.5
    return lowpass(mix(tone * 0.6, puff), 6000, SR)


def r_hero_death(rng):
    out = np.zeros(n_samples(1.0, SR))
    for i, m in enumerate([72, 68, 65, 60]):
        n = n_samples(0.26 if i < 3 else 0.5, SR)
        f = midi_hz(m) * (ramp(1.0, 0.94, n) if i == 3 else 1.0)
        s = osc(f, n, SR, "tri") * env_adsr(n, SR, 0.005, 0.05, 0.7, 0.12)
        place(out, s, n_samples(i * 0.17, SR))
    return out + seq([(0, burst(rng, 0.3, 0.1, 300, 2000) * 0.25)], 1.0)


def r_hero_respawn(rng):
    out = np.zeros(n_samples(0.6, SR))
    for i, m in enumerate([67, 71, 74, 79, 83]):
        n = n_samples(0.2, SR)
        s = (osc(midi_hz(m), n, SR, "sine") + 0.3 * osc(midi_hz(m) * 2, n, SR, "sine")) * env_exp(n, SR, 0.08)
        place(out, s * 0.6, n_samples(i * 0.06, SR))
    n = len(out)
    shimmer = bandpass(noise(n, rng), 5000, 9000, SR) * env_adsr(n, SR, 0.2, 0.1, 0.5, 0.3) * 0.15
    return out + shimmer


def r_skill_slam(rng):
    boom = mix(thump(170, 70, 0.5, 0.15) * 0.35, crunch_layer(rng, 0.3, 0.08, 1.0))
    n = n_samples(0.5, SR)
    sweep = lowpass(noise(n, rng), ramp(6000, 300, n), SR) * env_exp(n, SR, 0.12)
    crack = burst(rng, 0.05, 0.012, 1500, 8000) * 0.7
    return seq([(0, crack), (0.005, boom), (0.0, sweep * 0.8)], 0.6)


def r_skill_rally(rng):
    out = np.zeros(n_samples(0.85, SR))
    for t0, m, d in [(0.0, 67, 0.12), (0.12, 72, 0.12), (0.24, 76, 0.12), (0.36, 79, 0.45)]:
        n = n_samples(d, SR)
        f = midi_hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 6 * np.arange(n) / SR))
        horn = osc(f, n, SR, "saw") * 0.6 + osc(f, n, SR, "square", 0.5) * 0.25
        horn = lowpass(horn, ramp(1500, 3800, n, "lin"), SR) * env_adsr(n, SR, 0.015, 0.05, 0.75, 0.06)
        place(out, horn, n_samples(t0, SR))
    drum = thump(220, 120, 0.12, 0.04) * 0.4
    return out + seq([(0.0, drum), (0.36, drum)], 0.85)


def r_skill_barrage(rng):
    # falling whistle aligned with data skill_barrage delay 0.8 s, then three staggered impacts
    n = n_samples(0.8, SR)
    whistle = osc(ramp(1800, 500, n), n, SR, "sine") * env_adsr(n, SR, 0.05, 0.1, 0.6, 0.1) * 0.35
    out = np.zeros(n_samples(1.6, SR))
    place(out, whistle, 0)
    for i, (dt, p) in enumerate([(0.8, 1.0), (0.93, 0.85), (1.06, 1.1)]):
        imp = mix(thump(150 * p, 60, 0.4, 0.12) * 0.45, burst(rng, 0.3, 0.07, 400, 3000, cutoff_end=900) * 0.6, crunch_layer(rng, 0.2, 0.05, 0.7))
        place(out, imp * (1.0 - 0.15 * i), n_samples(dt, SR))
    return out


def r_skill_heal(rng):
    out = np.zeros(n_samples(0.8, SR))
    for i, m in enumerate([72, 76, 79, 84, 88]):
        n = n_samples(0.45, SR)
        f = midi_hz(m)
        s = (osc(f, n, SR, "sine") + 0.25 * osc(f * 1.005, n, SR, "sine")) * env_exp(n, SR, 0.18, 0.01)
        place(out, s * 0.45, n_samples(i * 0.07, SR))
    return out


def r_skill_cast(rng):
    n = n_samples(0.35, SR)
    rise = osc(ramp(300, 1200, n), n, SR, "square", 0.25) * env_adsr(n, SR, 0.01, 0.1, 0.6, 0.15)
    return lowpass(rise, 4000, SR) * 0.6 + burst(rng, 0.35, 0.12, 1500, 6000) * 0.25


def r_wave_incoming(rng):
    drum = mix(thump(220, 120, 0.18, 0.06) * 0.45, burst(rng, 0.1, 0.03, 500, 2500) * 0.6)
    out = seq([(0.0, drum), (0.16, drum * 0.8)], 0.9)
    n = n_samples(0.5, SR)
    f = midi_hz(74)
    horn = lowpass(osc(f, n, SR, "saw") + osc(f * 1.5, n, SR, "saw") * 0.5, 3000, SR) * env_adsr(n, SR, 0.04, 0.1, 0.7, 0.15)
    place(out, horn * 0.5, n_samples(0.34, SR))
    return out


def r_boss_incoming(rng):
    total = 1.8
    out = np.zeros(n_samples(total, SR))
    n = n_samples(1.5, SR)
    t = np.arange(n) / SR
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 5.5 * t)
    f = midi_hz(53)
    drone = (osc(f, n, SR, "saw") + osc(f * 1.06, n, SR, "saw") * 0.7 + osc(f * 0.5, n, SR, "square") * 0.12)
    drone = drone + osc(f * 2, n, SR, "saw") * 0.5
    drone = lowpass(drone, ramp(700, 2600, n), SR) * env_adsr(n, SR, 0.2, 0.2, 0.8, 0.5) * trem
    place(out, drone * 0.6, n_samples(0.15, SR))
    for t0 in (0.0, 0.5, 1.0):
        place(out, mix(thump(130, 60, 0.4, 0.14) * 0.3, crunch_layer(rng, 0.15, 0.04, 0.5)), n_samples(t0, SR))
    return out


def r_stinger_win(rng):
    total = 2.8
    out = np.zeros(n_samples(total, SR))
    lead = [(0.0, "G4", 0.11), (0.11, "C5", 0.11), (0.22, "E5", 0.11), (0.33, "G5", 0.28),
            (0.62, "E5", 0.11), (0.73, "G5", 0.14), (0.9, "C6", 1.5)]
    for t0, nm, d in lead:
        n = n_samples(d, SR)
        f = midi_hz(note_midi(nm))
        if d > 1:
            f = f * (1 + 0.008 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR) * np.linspace(0, 1, n))
        s = osc(f, n, SR, "square", 0.5) * env_adsr(n, SR, 0.005, 0.05, 0.7, min(0.4, d * 0.4))
        place(out, lowpass(s, 5000, SR) * 0.45, n_samples(t0, SR))
    for nm in ("C4", "E4", "G4"):
        n = n_samples(1.7, SR)
        place(out, osc(midi_hz(note_midi(nm)), n, SR, "tri") * env_adsr(n, SR, 0.02, 0.2, 0.6, 0.6) * 0.25, n_samples(0.9, SR))
    for i in range(6):  # snare roll into the final chord
        place(out, burst(rng, 0.06, 0.02, 800, 6000) * (0.25 + 0.06 * i), n_samples(0.6 + i * 0.05, SR))
    n = n_samples(1.6, SR)
    place(out, highpass(noise(n, rng), 5000, SR) * env_exp(n, SR, 0.5) * 0.18, n_samples(0.9, SR))
    place(out, thump(120, 50, 0.3, 0.1) * 0.8, n_samples(0.9, SR))
    return out


def r_stinger_defeat(rng):
    total = 3.0
    out = np.zeros(n_samples(total, SR))
    for i, (nm, d) in enumerate([("E4", 0.38), ("D#4", 0.38), ("D4", 0.38), ("C#4", 1.4)]):
        n = n_samples(d, SR)
        f = midi_hz(note_midi(nm))
        if i == 3:
            f = f * ramp(1.0, 0.93, n) * (1 + 0.012 * np.sin(2 * np.pi * 5 * np.arange(n) / SR))
        s = lowpass(osc(f, n, SR, "saw"), 2400, SR) * env_adsr(n, SR, 0.02, 0.08, 0.7, 0.2 if i < 3 else 0.7)
        place(out, s * 0.5, n_samples(i * 0.42, SR))
    n = n_samples(2.6, SR)
    place(out, osc(midi_hz(note_midi("C#3")), n, SR, "tri") * env_adsr(n, SR, 0.3, 0.2, 0.6, 1.0) * 0.25, 0)
    place(out, thump(110, 55, 0.5, 0.18) * 0.3, n_samples(1.26, SR))
    return out


# ----------------------------------------------------------------------------------------------
# Cue table: id -> recipe(s) + runtime mixing policy (consumed by src/audio/audio_manager.gd)
#   bus: SFX | UI | Music ; vol_db: mix gain ; max: simultaneous instances of this cue ;
#   gap: minimum seconds between triggers ; prio: 0..10 (voice stealing; higher wins) ;
#   pitch: +- random pitch scale jitter ; duck: music duck dB while playing (0 = none)
# ----------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------
# v3 THEME (Q1 = A, user-decided 2026-10-31 09:03): bakery knights (player) vs mold legion (enemy).
# Sound palette rule, so factions are told apart by ear:
#   BAKERY = warm + bouncy + DRY: oven bells (inharmonic sine partials), crust crunch (bright, short,
#            dry noise grains), wooden/rolling-pin thunks, major keys, accordion/brass-like leads.
#   MOLD   = wet + sticky + SLOW: squelch (noise through a moving formant band-pass), bubble pops
#            (fast rising sine chirps), sticky low-passed tails, minor/tritone, wobbling pitch.
# Both palettes keep most energy above 300 Hz (phone loudspeakers), validated by validate.py/mix_report.py.
# v1/v2 recipes above are kept so earlier versions can be regenerated for A/B comparison.
# ----------------------------------------------------------------------------------------------

def bell(f, dur, tau=None, bright=1.0):
    """Small oven/shop bell: inharmonic partials (1, 2.756, 5.404) with faster-decaying upper partials."""
    n = n_samples(dur, SR)
    tau = tau or dur * 0.45
    s = osc(f, n, SR, "sine") * env_exp(n, SR, tau, 0.001)
    s += 0.5 * bright * osc(f * 2.756, n, SR, "sine") * env_exp(n, SR, tau * 0.55, 0.001)
    s += 0.25 * bright * osc(f * 5.404, n, SR, "sine") * env_exp(n, SR, tau * 0.3, 0.001)
    return s


def crumbs(rng, dur, count, lo=1800, hi=7000, gain=1.0):
    """Dry crust crackle: `count` tiny noise grains (3-9 ms) scattered over `dur` seconds."""
    out = np.zeros(n_samples(dur, SR))
    for _ in range(count):
        g = n_samples(rng.uniform(0.003, 0.009), SR)
        grain = bandpass(noise(g, rng), lo, hi, SR) * env_exp(g, SR, g / SR * 0.35, 0.0003)
        place(out, grain * rng.uniform(0.4, 1.0) * gain, int(rng.uniform(0, 0.85) * len(out)))
    return out


def bubble(f0, dur=0.035, rise=2.2):
    """Wet bubble pop: short sine chirp rising in pitch (the classic 'bloop' of a bursting bubble)."""
    n = n_samples(dur, SR)
    return osc(ramp(f0, f0 * rise, n), n, SR, "sine") * env_adsr(n, SR, 0.002, dur * 0.4, 0.4, dur * 0.4)


def squelch(rng, dur, f_start, f_peak, f_end, wet=0.6):
    """Sticky squelch: noise through a band (one octave) whose centre sweeps start -> peak -> end."""
    n = n_samples(dur, SR)
    k = n // 3
    centre = np.concatenate([ramp(f_start, f_peak, k), ramp(f_peak, f_end, n - k)])
    x = noise(n, rng)
    x = lowpass(highpass(x, centre * 0.7, SR), centre * 1.4, SR)
    body = osc(centre * 0.5, n, SR, "sine") * 0.35          # gooey tonal component following the sweep
    e = env_adsr(n, SR, 0.004, dur * 0.25, 0.55, dur * 0.5)
    return lowpass((x + body * wet) * e, 3500, SR)


# --- bakery side ------------------------------------------------------------------------------
def r3_deploy(rng):
    """Bakery troop marches out of the oven: oven-door bell (G6/D7) + two dry crust footsteps + puff."""
    out = np.zeros(n_samples(0.42, SR))
    place(out, bell(midi_hz(91), 0.35, 0.12) * 0.55, 0)
    place(out, bell(midi_hz(98), 0.3, 0.1) * 0.35, n_samples(0.06, SR))
    for t0 in (0.1, 0.22):
        step = mix(crumbs(rng, 0.05, 7, 1500, 6000), thump(420, 260, 0.05, 0.015) * 0.3)
        place(out, step * 0.8, n_samples(t0, SR))
    n = n_samples(0.2, SR)
    puff = bandpass(noise(n, rng), 600, 2500, SR) * env_adsr(n, SR, 0.02, 0.05, 0.4, 0.12) * 0.25
    place(out, puff, 0)
    return out


def r3_worker_buy(rng):
    """Little baker hired: shop bell 'ka-ching' (two bell strikes up a fourth) + coin glint."""
    out = np.zeros(n_samples(0.45, SR))
    place(out, bell(midi_hz(84), 0.25, 0.08) * 0.6, 0)
    place(out, bell(midi_hz(89), 0.4, 0.16) * 0.7, n_samples(0.07, SR))
    place(out, blip(2349, 2349, 0.06, "sine", tau=0.025) * 0.25, n_samples(0.12, SR))
    return out


def r3_hit_bread(rng, var):
    """Mold hits a bread soldier: crisp crust crunch + small wooden-ish knock (dry, bright, short)."""
    p = [1.0, 0.9, 1.1][var]
    crunch = crumbs(rng, 0.06, 12 + 3 * var, 1600 * p, 7500)
    knock = thump(480 * p, 330 * p, 0.05, 0.014, drive=1.5) * 0.35
    return highpass(mix(crunch, knock), 250, SR)


def r3_death_ally(rng):
    """Bread soldier crumbles: crust SNAP onset + crackle that thins out + warm falling 'aww'.
    v3.7 (PHONE_SPEAKER_CHECK 3-seed diagnosis: masked by other battle SFX at 1-4 kHz, where the v3 recipe had
    only 3-11 % of its energy): snap = 25 ms 1.6-4.5 kHz crack + 1.7 kHz wooden tock at t=0; crackle band moved
    to 1.5-4.5 kHz; the 'aww' gains odd harmonics (pulse wave, low-passed 4 kHz) so it is heard on a phone."""
    n0 = n_samples(0.32, SR)
    out = crumbs(rng, 0.32, 40, 1500, 4500) * np.linspace(1.0, 0.3, n0)
    snap = mix(burst(rng, 0.025, 0.006, 1600, 4500) * 0.9, thump(1700, 1250, 0.04, 0.01, drive=2.0) * 0.35)
    n = n_samples(0.25, SR)
    f = ramp(midi_hz(79), midi_hz(72), n)
    tone = (osc(f, n, SR, "tri") * 0.6 + lowpass(osc(f, n, SR, "square", 0.3), 4000, SR) * 0.4)
    tone = tone * env_adsr(n, SR, 0.006, 0.05, 0.6, 0.12) * 0.35
    return mix(seq([(0.0, snap)], 0.05), seq([(0.012, out)], 0.34), seq([(0.012, tone)], 0.27))


def r3_hit_base_bakery(rng):
    """Player bakery tower hit: wooden crack + crust shower + low (but >300 Hz-led) knock."""
    knock = thump(330, 200, 0.2, 0.06, drive=2.5) * 0.22
    # v3.5: longer, brighter wood crack so "our base is hit" survives a phone speaker (PHONE_SPEAKER_CHECK)
    # v3.7: a 1.4 kHz "tock" was tried and REJECTED (offline 3-seed estimate: p10 -1.0 -> -3.4 dB, the tock raised the
    # peak so the file got quieter after normalisation). v3.7 keeps this recipe and adds an SFX duck in the manifest.
    crack = mix(burst(rng, 0.07, 0.018, 1500, 6000), seq([(0.05, burst(rng, 0.05, 0.012, 1800, 6500) * 0.6)], 0.12))
    return mix(knock, crack, seq([(0.02, crumbs(rng, 0.3, 30, 1500, 6000) * 0.6)], 0.34))


def r3_wave_incoming(rng):
    """Bakery alarm bell tolls twice (watchtower bell, E6) over a short march-drum roll: 'they're coming'."""
    out = np.zeros(n_samples(1.0, SR))
    for i, t0 in enumerate((0.0, 0.32)):
        place(out, bell(midi_hz(76), 0.6, 0.25, bright=1.3) * (0.7 - 0.15 * i), n_samples(t0, SR))
    for i in range(6):
        place(out, burst(rng, 0.05, 0.015, 900, 5000) * (0.2 + 0.05 * i), n_samples(0.5 + i * 0.06, SR))
    place(out, thump(260, 160, 0.15, 0.05) * 0.3, n_samples(0.86, SR))
    return out


def r3_stinger_win(rng):
    """Bakery victory: bouncy major fanfare (warm square lead, low-passed), oven-bell double ding on the
    final chord, crust confetti. Character: proud, cheerful, short (2.8 s)."""
    out = np.zeros(n_samples(2.8, SR))
    lead = [(0.0, "G4", 0.11), (0.11, "C5", 0.11), (0.22, "E5", 0.11), (0.33, "G5", 0.28),
            (0.62, "E5", 0.11), (0.73, "G5", 0.14), (0.9, "C6", 1.5)]
    for t0, nm, d in lead:
        n = n_samples(d, SR)
        f = midi_hz(note_midi(nm))
        if d > 1:
            f = f * (1 + 0.007 * np.sin(2 * np.pi * 5.5 * np.arange(n) / SR) * np.linspace(0, 1, n))
        s = (osc(f, n, SR, "square", 0.3) + 0.5 * osc(f * 1.003, n, SR, "saw")) * env_adsr(n, SR, 0.006, 0.05, 0.7, min(0.4, d * 0.4))
        place(out, lowpass(s, 3200, SR) * 0.4, n_samples(t0, SR))
    for nm in ("C4", "E4", "G4"):
        n = n_samples(1.7, SR)
        place(out, osc(midi_hz(note_midi(nm)), n, SR, "tri") * env_adsr(n, SR, 0.02, 0.2, 0.6, 0.6) * 0.22, n_samples(0.9, SR))
    for i in range(6):
        place(out, burst(rng, 0.06, 0.02, 800, 6000) * (0.22 + 0.05 * i), n_samples(0.6 + i * 0.05, SR))
    place(out, bell(midi_hz(96), 1.2, 0.45) * 0.4, n_samples(0.9, SR))
    place(out, bell(midi_hz(103), 1.0, 0.35) * 0.3, n_samples(1.15, SR))
    place(out, crumbs(rng, 1.2, 60, 3000, 9000) * np.linspace(0.6, 0.0, n_samples(1.2, SR)), n_samples(0.95, SR))
    return out


# --- mold side ---------------------------------------------------------------------------------
def r3_hit_mold(rng, var):
    """Bread soldier hits mold: short wet squish + one bubble (soft, sticky, no bright crack)."""
    p = [1.0, 0.88, 1.14][var]
    s = squelch(rng, 0.09, 700 * p, 1600 * p, 500 * p, wet=0.5)
    return highpass(mix(s, seq([(0.03 + 0.01 * var, bubble(420 * p, 0.03) * 0.45)], 0.1)), 250, SR)


def r3_death_enemy(rng):
    """Mold blob bursts: big squelch, then a fizz of 4 bubbles of falling size (rising pitch)."""
    out = np.zeros(n_samples(0.42, SR))
    place(out, squelch(rng, 0.22, 500, 1400, 350, wet=0.7), 0)
    for i, (t0, f) in enumerate([(0.12, 380), (0.18, 520), (0.25, 690), (0.31, 900)]):
        place(out, bubble(f * rng.uniform(0.92, 1.08), 0.03) * (0.5 - 0.08 * i), n_samples(t0, SR))
    n = len(out)
    fizz = bandpass(noise(n, rng), 3000, 7000, SR) * env_adsr(n, SR, 0.1, 0.1, 0.3, 0.2) * 0.08
    return out + fizz


def r3_shoot_spit(rng):
    """Spore spitter: wet 'ptoo' (squelch up) + 2 bubbles trailing."""
    out = np.zeros(n_samples(0.18, SR))
    place(out, squelch(rng, 0.1, 400, 1800, 900, wet=0.4), 0)
    place(out, bubble(500, 0.025) * 0.4, n_samples(0.07, SR))
    place(out, bubble(650, 0.025) * 0.3, n_samples(0.11, SR))
    return out


def r3_explosion(rng):
    """Spore bomber bursts: wet splat (squelch) + mid-band boom + spore hiss + bubbles raining down.
    v4.0 (DEATH_SYNC_CHECK.md T1): 03 e8c6d96 made every death animation 0.5 s and a self-destructing bomber dies on
    the explosion frame, so the tail was shortened: 0.7 -> 0.5 s file, body tau 0.15 -> 0.12, boom decay 0.14 -> 0.10,
    bubbles 0.12 + 0.05 i (was 0.15 + 0.07 i), hiss release 0.4 -> 0.2. Audible end 0.53 -> 0.40 s; attack unchanged."""
    n = n_samples(0.5, SR)
    body = lowpass(noise(n, rng), ramp(3500, 400, n), SR) * env_exp(n, SR, 0.12, 0.002)
    out = mix(body, thump(180, 90, 0.45, 0.10) * 0.35, squelch(rng, 0.3, 300, 1200, 250, wet=0.8) * 0.9)
    for i in range(6):
        place(out, bubble(rng.uniform(350, 900), 0.03) * 0.3, n_samples(0.12 + 0.05 * i, SR))
    hiss = highpass(noise(n, rng), 4000, SR) * env_adsr(n, SR, 0.05, 0.1, 0.25, 0.2) * 0.1
    return mix(out, hiss)


def r3_hit_base_mold(rng):
    """Enemy mold hive hit: heavy wet thud (squelch, slower) + gooey wobble + bubbles."""
    out = mix(squelch(rng, 0.35, 380, 1200, 330, wet=0.6), thump(260, 170, 0.25, 0.08, drive=2.0) * 0.14)
    for t0, f in [(0.12, 420), (0.2, 560)]:
        place(out, bubble(f, 0.03) * 0.35, n_samples(t0, SR))
    return out


def r3_boss_incoming(rng):
    """Mold boss rises: oozing tritone drone (D4/G#4 detuned saws, low-passed and slowly bending down),
    three heavy squelch stomps, a growing bubble boil. Character: slimy menace, not a horror scream."""
    total = 2.0
    out = np.zeros(n_samples(total, SR))
    n = n_samples(1.7, SR)
    t = np.arange(n) / SR
    bend = 1 - 0.03 * np.clip(t / 1.7, 0, 1) + 0.006 * np.sin(2 * np.pi * 3.1 * t)    # oozy pitch sag + wobble
    drone = np.zeros(n)
    for m, g in ((62, 1.0), (68, 0.7), (74, 0.3)):
        f = midi_hz(m) * bend
        drone += (osc(f * 0.995, n, SR, "saw") + osc(f * 1.005, n, SR, "saw")) * 0.5 * g
    drone = lowpass(drone, ramp(600, 1800, n), SR) * env_adsr(n, SR, 0.25, 0.2, 0.8, 0.5)
    place(out, drone * 0.45, n_samples(0.15, SR))
    for t0 in (0.0, 0.55, 1.1):
        place(out, mix(squelch(rng, 0.25, 350, 1000, 300, wet=0.6), thump(200, 130, 0.3, 0.1) * 0.12), n_samples(t0, SR))
    for i in range(14):
        tt = 0.4 + 1.4 * (i / 14) ** 0.7
        place(out, bubble(rng.uniform(300, 800), rng.uniform(0.025, 0.045)) * (0.15 + 0.02 * i), n_samples(tt, SR))
    return out


def r3_stinger_defeat(rng):
    """Mold wins: the bakery tune collapses — descending chromatic line in a wet, wobbling voice whose
    low-pass closes like dough going soggy, then bubbles take over. Mid register (no sub-heavy drone)."""
    out = np.zeros(n_samples(3.0, SR))
    for i, (nm, d) in enumerate([("E5", 0.38), ("D#5", 0.38), ("D5", 0.38), ("C#5", 1.5)]):
        n = n_samples(d, SR)
        f = midi_hz(note_midi(nm)) * (1 + 0.015 * np.sin(2 * np.pi * 4.5 * np.arange(n) / SR))
        if i == 3:
            f = f * ramp(1.0, 0.9, n)
        s = osc(f, n, SR, "square", 0.3) * 0.6 + osc(f * 0.5, n, SR, "tri") * 0.4
        cut = ramp(2400, 700, n) if i == 3 else 2400 - 350 * i
        s = lowpass(s, cut, SR) * env_adsr(n, SR, 0.02, 0.08, 0.7, 0.2 if i < 3 else 0.8)
        place(out, s * 0.55, n_samples(i * 0.42, SR))
    n = n_samples(2.6, SR)
    place(out, osc(midi_hz(note_midi("C#4")), n, SR, "tri") * env_adsr(n, SR, 0.3, 0.2, 0.5, 1.0) * 0.18, 0)
    for i in range(10):
        place(out, bubble(rng.uniform(280, 700), 0.035) * 0.22, n_samples(1.5 + 0.12 * i, SR))
    place(out, squelch(rng, 0.4, 300, 700, 220, wet=0.8) * 0.5, n_samples(1.26, SR))
    return out


# --- flow / meta UI (v3.1) ----------------------------------------------------------------------
def r31_wave_cleared(rng):
    """A scripted wave is broken (Events.wave_cleared): short bakery triumph, 0.7 s.
    Two quick bells up a fifth (C6 -> G6) + crust 'cheer' crackle. Distinct from wave_incoming (alarm
    bell tolls, lower) and stinger_win (long fanfare), so it never reads as 'battle won'."""
    out = np.zeros(n_samples(0.7, SR))
    place(out, bell(midi_hz(84), 0.3, 0.1) * 0.55, 0)
    place(out, bell(midi_hz(91), 0.55, 0.22) * 0.65, n_samples(0.09, SR))
    place(out, crumbs(rng, 0.35, 28, 2500, 8000) * np.linspace(0.5, 0.0, n_samples(0.35, SR)), n_samples(0.1, SR))
    place(out, thump(330, 220, 0.08, 0.025) * 0.25, n_samples(0.09, SR))
    return out


# Upgrade screen results (04 upgrade_panel codes). Meta upgrades are bought with gold EARNED in play;
# these are not purchase/ad sounds (Q2 monetization is on hold: none were made).
def r31_upgrade_ok(rng):
    """Upgrade done: warm rising level-up (bell G5-B5-D6 + sparkle), 0.55 s."""
    out = np.zeros(n_samples(0.55, SR))
    for i, m in enumerate((79, 83, 86)):
        place(out, bell(midi_hz(m), 0.35, 0.12) * (0.45 + 0.1 * i), n_samples(i * 0.07, SR))
    n = n_samples(0.35, SR)
    place(out, bandpass(noise(n, rng), 5000, 9000, SR) * env_adsr(n, SR, 0.05, 0.1, 0.3, 0.15) * 0.08, n_samples(0.12, SR))
    return out


def r31_upgrade_no_coins(rng):
    """Not enough gold: two dull coin taps falling (soft, not alarming), 0.25 s."""
    return seq([(0.0, blip(1320, 1250, 0.05, "tri", tau=0.018) * 0.6),
                (0.09, blip(990, 900, 0.08, "tri", tau=0.03) * 0.6)], 0.25)


def r31_upgrade_max(rng):
    """Already at max level: neutral 'sealed' knock + one soft bell (informative, not an error), 0.4 s."""
    return mix(thump(520, 400, 0.06, 0.018, drive=1.5) * 0.4, seq([(0.05, bell(midi_hz(76), 0.32, 0.1) * 0.45)], 0.4))


def r31_upgrade_save_failed(rng):
    """Save failed: clearly different from 'no coins' and ui_error — falling two-tone buzz (A#4 -> D#4) + crack, 0.35 s."""
    a = lowpass(blip(466, 440, 0.12, "square", 0.5, tau=0.07), 3500, SR)
    b = lowpass(blip(311, 294, 0.16, "square", 0.5, tau=0.09), 3500, SR)
    return mix(seq([(0.0, a), (0.14, b)], 0.35), burst(rng, 0.04, 0.01, 1500, 6000) * 0.5)


# --- v3.4: 01 R1 timbre requests (tray-bell/whisk UI confirm, crumb-shell barrage) -----------------
def whisk(rng, dur=0.09, up=True):
    """Kitchen whisk swish: band-passed noise whose band sweeps up (or down) fast."""
    n = n_samples(dur, SR)
    lo = ramp(1800, 4500, n) if up else ramp(4500, 1800, n)
    x = bandpass(noise(n, rng), lo, lo * 2.0, SR)
    return x * env_adsr(n, SR, 0.01, dur * 0.3, 0.6, dur * 0.4)


def r34_ui_confirm(rng):
    """UI confirm (01 R1: 'tray-bell or whisk'): quick whisk swish up, then a small bright tray bell (A6) with a
    softer partial a fifth up. 0.32 s, dry, clearly 'yes' but not as big as wave_cleared."""
    out = np.zeros(n_samples(0.32, SR))
    place(out, whisk(rng, 0.08, True) * 0.45, 0)
    place(out, bell(midi_hz(93), 0.26, 0.08, bright=1.2) * 0.7, n_samples(0.06, SR))
    place(out, bell(midi_hz(100), 0.2, 0.06) * 0.25, n_samples(0.075, SR))
    return out


def r34_skill_barrage(rng):
    """Barrage (01 R1: 'a crumb-shell volley'): five oven-cannon 'pfoomp' launches in a rolling volley, a soft
    rising whistle while the shells fly, then a rain of crumb-shell impacts starting at 0.8 s (data delay 0.8 s):
    each impact = crust crack + small knock + crumb shower. 1.6 s."""
    out = np.zeros(n_samples(1.6, SR))
    for i in range(5):
        n = n_samples(0.12, SR)
        puff = bandpass(noise(n, rng), 500, 2200, SR) * env_adsr(n, SR, 0.004, 0.03, 0.4, 0.07)
        launch = mix(puff * 0.6, thump(300 - 15 * i, 200, 0.08, 0.025, drive=2.0) * 0.25)
        place(out, launch * (0.8 + 0.05 * i), n_samples(0.03 + 0.09 * i, SR))
    n = n_samples(0.6, SR)
    place(out, osc(ramp(900, 1600, n), n, SR, "sine") * env_adsr(n, SR, 0.08, 0.1, 0.5, 0.2) * 0.12, n_samples(0.2, SR))
    for i, (dt, p) in enumerate([(0.80, 1.0), (0.88, 0.9), (0.95, 1.1), (1.03, 0.95), (1.10, 1.05)]):
        hit = mix(burst(rng, 0.04, 0.01, 1500 * p, 6000), thump(380 * p, 250 * p, 0.07, 0.02, drive=2.0) * 0.3,
                  crumbs(rng, 0.25, 22, 1600, 7000) * 0.6)
        place(out, hit * (1.0 - 0.08 * i), n_samples(dt, SR))
    return out


# --- v3.6: 01 R1 "Rally = cheer plus an oven whoosh" ------------------------------------------------
def voice_hey(rng, f0, dur=0.22):
    """One synthetic 'hey!' shout: buzzy glottal source (saw with jitter) through two vowel formants that glide
    from 'eh' (F1 530 / F2 1850 Hz) towards 'ay' (F2 2300 Hz). No samples, no speech data."""
    n = n_samples(dur, SR)
    f = f0 * ramp(1.0, 1.12, n, "lin") * (1 + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(n))
    src = osc(f, n, SR, "saw")
    f1 = bandpass(src, 430, 650, SR)
    f2 = bandpass(src, ramp(1650, 2100, n), ramp(2050, 2600, n), SR)
    return (f1 * 0.8 + f2 * 0.9) * env_adsr(n, SR, 0.015, 0.05, 0.7, 0.09)


def r36_skill_rally(rng):
    """Rally: an oven-door WHOOSH (warm air swell, band-passed noise rising 400 -> 2500 Hz) under a short troop
    cheer: five 'hey!' voices with different pitches and start times, then a bright bell accent. 0.9 s."""
    out = np.zeros(n_samples(0.9, SR))
    n = n_samples(0.55, SR)
    whoosh = lowpass(highpass(noise(n, rng), ramp(300, 1200, n), SR), ramp(900, 3000, n), SR)
    place(out, whoosh * env_adsr(n, SR, 0.18, 0.1, 0.6, 0.25) * 0.9, 0)
    for i, (t0, f0) in enumerate([(0.16, 165), (0.18, 220), (0.20, 196), (0.22, 247), (0.25, 147)]):
        place(out, voice_hey(rng, f0 * rng.uniform(0.98, 1.02)) * (0.5 - 0.04 * i), n_samples(t0, SR))
    place(out, bell(midi_hz(88), 0.4, 0.14) * 0.35, n_samples(0.42, SR))
    place(out, thump(260, 160, 0.1, 0.03) * 0.3, n_samples(0.17, SR))
    return out


# --- v3.8: extra variants for repetition fatigue (docs/audio/REPETITION_CHECK.md) ---------------------
# Extra variants are listed in a cue's "rx" field. They get their own stable seeds (70000 + n) and file names
# <cue>_v2.wav, <cue>_v3.wav, so every existing file and every existing seed stays byte-identical.
def r38_shoot_spit_v(rng, k):
    """Spore spit variant k (1, 2): different squelch formant range and bubble pattern."""
    p = [0.88, 1.13][k - 1]
    out = np.zeros(n_samples(0.18, SR))
    place(out, squelch(rng, [0.10, 0.11][k - 1], 400 * p, 1800 * p, 900 * p, wet=0.45), 0)
    # v3.8 level match against shoot_spit.wav in the phone band (loud-frame energy; validate.py allows +-0.5 dB):
    # first versions were v2 -0.73 dB (0.11 s squelch, bubbles 0.35/0.3) and v3 -1.5 dB (0.09 s, 0.35/0.25/0.2)
    pat = [[(0.06, 430, 0.4), (0.12, 560, 0.35)], [(0.05, 700, 0.45), (0.09, 600, 0.38), (0.13, 820, 0.3)]][k - 1]
    for t0, f, g in pat:
        place(out, bubble(f, 0.025) * g, n_samples(t0, SR))
    return out


def r38_death_enemy_v(rng, k):
    """Mold burst variant: darker squelch (formant 450-1300 Hz -> 320 Hz instead of 500-1400 -> 350) and a
    higher bubble line (460/600/780/1000 Hz instead of 380/520/690/900), same 4-bubble timing as death_enemy.wav,
    then a mild tanh compression (k=0.8) so its body sits at the original's level after peak normalisation.
    Why the timing is kept: two earlier versions with a shorter or re-timed bubble rhythm were as loud by the
    loud-frame level (-1.3 / -0.3 dB) but 6.6 points more masked on average in the same-background A/B over the
    9 v3.8 battle backgrounds (r02/r06/r08 x seeds 11/23/37); this one: masked 11.5 % vs 12.5 % for the original
    (mean of the 9, p10 -0.8 vs -1.1 dB, same_bg_ab.py renderer and SNR measure)."""
    out = np.zeros(n_samples(0.42, SR))
    place(out, squelch(rng, 0.22, 450, 1300, 320, wet=0.7), 0)
    for i, (t0, f) in enumerate([(0.12, 460), (0.18, 600), (0.25, 780), (0.31, 1000)]):
        place(out, bubble(f * rng.uniform(0.94, 1.06), 0.03) * (0.5 - 0.08 * i), n_samples(t0, SR))
    n = len(out)
    out = out + bandpass(noise(n, rng), 3200, 7500, SR) * env_adsr(n, SR, 0.1, 0.1, 0.3, 0.2) * 0.08
    out = out / max(float(np.max(np.abs(out))), 1e-9)
    return np.tanh(0.8 * out) / np.tanh(0.8)


def r38_gold_tick_v(rng, k):
    """Coin glint variant: two notes a fourth apart (E6 -> A6) instead of A6 -> D7, slightly longer ring."""
    return seq([(0, blip(1319, 1319, 0.035, "square", 0.25, tau=0.012) * 0.6),
                (0.032, blip(1760, 1760, 0.08, "sine", tau=0.034))], 0.12)


def r38_shoot_arrow_v(rng, k):
    """Baguette throw variant: higher, slightly faster whoosh and a different twang pitch."""
    n = n_samples(0.11, SR)
    x = bandpass(noise(n, rng), ramp(3400, 1400, n), ramp(7600, 2800, n), SR)
    twang = blip(600, 555, 0.075, "tri", tau=0.028) * 0.3
    return x * env_adsr(n, SR, 0.007, 0.03, 0.5, 0.07) + seq([(0, twang)], 0.11)


CUES = {
    # faction: bakery (player side), mold (enemy side), neutral (UI/flow). desc = sound design intent.
    "ui_tap":          dict(r=[r_ui_tap], bus="UI", vol_db=-8, max=2, gap=0.03, prio=6, pitch=0.03, faction="neutral", desc="short square tick"),
    "ui_back":         dict(r=[r_ui_back], bus="UI", vol_db=-8, max=1, gap=0.05, prio=6, pitch=0.0, faction="neutral", desc="two falling ticks"),
    "ui_confirm":      dict(r=[r34_ui_confirm], bus="UI", vol_db=-8, max=1, gap=0.05, prio=7, pitch=0.0, faction="bakery", desc="whisk swish + small tray bell (01 R1)"),
    "ui_error":        dict(r=[r_ui_error], bus="UI", vol_db=-9, max=1, gap=0.25, prio=6, pitch=0.0, faction="neutral", desc="double low buzz"),
    "deploy":          dict(r=[r3_deploy], bus="SFX", vol_db=-7, max=2, gap=0.06, prio=7, pitch=0.04, faction="bakery", desc="oven-door bell + crust footsteps"),
    "worker_buy":      dict(r=[r3_worker_buy], bus="SFX", vol_db=-9, max=1, gap=0.1, prio=7, pitch=0.0, faction="bakery", desc="shop bell ka-ching"),
    "gold_tick":       dict(r=[r_gold_tick], rx=[lambda g: r38_gold_tick_v(g, 1)], vol_jitter=1.0, bus="SFX", vol_db=-13, max=2, gap=0.09, prio=2, pitch=0.05, faction="bakery", desc="coin glint"),
    "hit_melee":       dict(r=[lambda g, v=v: r_quality_bread(g, v) for v in range(5)], peak_dbfs_target=-4.5, fade_in=0.004, fade_out=0.015,
                            bus="SFX", vol_db=-7, max=2, gap=0.26, prio=1, pitch=0.08, faction="neutral", group="hit",
                            desc="rounded wooden impact, fallback when the target side is unknown"),
    "hit_bread":       dict(r=[lambda g, v=v: r_quality_bread(g, v) for v in range(3)], peak_dbfs_target=-4.5, fade_in=0.004, fade_out=0.015,
                            bus="SFX", vol_db=-8, max=2, gap=0.22, prio=1, pitch=0.07, faction="bakery", group="hit",
                            desc="a bread soldier is hit: rounded wood and soft crust"),
    "hit_mold":        dict(r=[lambda g, v=v: r_quality_mold(g, v) for v in range(3)], peak_dbfs_target=-4.5, fade_in=0.004, fade_out=0.015,
                            bus="SFX", vol_db=-6, max=2, gap=0.22, prio=1, pitch=0.08, faction="mold", group="hit",
                            desc="a mold unit is hit: soft plop with restrained noise"),
    "hit_arrow":       dict(r=[r_hit_arrow], bus="SFX", vol_db=-10, max=2, gap=0.05, prio=1, pitch=0.08, faction="neutral", group="hit", desc="ranged impact fallback"),
    "shoot_arrow":     dict(r=[r_shoot_arrow], rx=[lambda g: r38_shoot_arrow_v(g, 1)], vol_jitter=1.0, bus="SFX", vol_db=-12, max=2, gap=0.06, prio=1, pitch=0.08, faction="bakery", desc="baguette thrower whoosh"),
    "shoot_rock":      dict(r=[r_shoot_rock], bus="SFX", vol_db=-10, max=1, gap=0.12, prio=2, pitch=0.06, faction="bakery", desc="oven cannon puff + thunk"),
    "shoot_spit":      dict(r=[r3_shoot_spit], rx=[lambda g: r38_shoot_spit_v(g, 1), lambda g: r38_shoot_spit_v(g, 2)], vol_jitter=1.0, bus="SFX", vol_db=-11, max=2, gap=0.08, prio=1, pitch=0.08, faction="mold", desc="spore spit: wet ptoo + bubbles"),
    "hit_base":        dict(r=[r3_hit_base_bakery], bus="SFX", vol_db=-4.5, max=1, gap=0.35, prio=5, pitch=0.05, duck_sfx=-6, duck_sfx_below=5, faction="bakery", desc="bakery tower hit: wooden crack + crust shower"),
    "hit_base_mold":   dict(r=[r3_hit_base_mold], bus="SFX", vol_db=-9, max=1, gap=0.35, prio=5, pitch=0.05, faction="mold", desc="mold hive hit: heavy wet thud"),
    "explosion":       dict(r=[r3_explosion], bus="SFX", vol_db=-8, max=2, gap=0.12, prio=5, pitch=0.06, faction="mold", desc="spore bomber burst: splat + hiss + bubbles"),
    "death_ally":      dict(r=[r3_death_ally], bus="SFX", vol_db=-8.5, max=2, gap=0.08, prio=3, pitch=0.06, duck_sfx=-6, duck_sfx_below=3, faction="bakery", desc="bread crumbles: dry crackle + soft falling tone"),
    "death_enemy":     dict(r=[r3_death_enemy], rx=[lambda g: r38_death_enemy_v(g, 1)], vol_jitter=1.0, bus="SFX", vol_db=-11, max=2, gap=0.07, prio=3, pitch=0.08, faction="mold", desc="mold bursts: squelch + bubble fizz"),
    "hero_death":      dict(r=[r_hero_death], bus="SFX", vol_db=-5, max=1, gap=1.0, prio=9, pitch=0.0, duck=-6, faction="bakery", desc="head baker falls: 4-note falling triangle line"),
    "hero_respawn":    dict(r=[r_hero_respawn], bus="SFX", vol_db=-8, max=1, gap=1.0, prio=8, pitch=0.0, faction="bakery", desc="rising sparkle arpeggio"),
    "skill_slam":      dict(r=[r_skill_slam], bus="SFX", vol_db=-4, max=1, gap=0.2, prio=9, pitch=0.0, duck=-4, faction="bakery", desc="rolling-pin ground pound"),
    "skill_rally":     dict(r=[r36_skill_rally], bus="SFX", vol_db=-6, max=1, gap=0.2, prio=9, pitch=0.0, duck=-4, faction="bakery", desc="oven-door whoosh + troop cheer + bell accent (01 R1)"),
    "skill_barrage":   dict(r=[r34_skill_barrage], bus="SFX", vol_db=-5, max=1, gap=0.2, prio=9, pitch=0.0, duck=-5, faction="bakery", desc="crumb-shell volley: 5 oven-cannon launches, impacts rain from 0.8 s (01 R1)"),
    "skill_heal":      dict(r=[r_skill_heal], bus="SFX", vol_db=-7, max=1, gap=0.2, prio=9, pitch=0.0, duck=-3, faction="bakery", desc="warm sine arpeggio"),
    "skill_cast":      dict(r=[r_skill_cast], bus="SFX", vol_db=-7, max=1, gap=0.2, prio=8, pitch=0.0, duck=-3, faction="bakery", desc="rising cast"),
    "wave_incoming":   dict(r=[r3_wave_incoming], bus="SFX", vol_db=-7, max=1, gap=1.0, prio=8, pitch=0.0, duck=-4, faction="bakery", desc="bakery alarm bell tolls twice + drum roll"),
    "boss_incoming":   dict(r=[r3_boss_incoming], bus="SFX", vol_db=-4, max=1, gap=2.0, prio=10, pitch=0.0, duck=-8, faction="mold", desc="oozing tritone drone + squelch stomps + boiling bubbles"),
    "stinger_win":     dict(r=[r3_stinger_win], bus="Music", vol_db=-3, max=1, gap=1.0, prio=10, pitch=0.0, faction="bakery", desc="bouncy major fanfare + oven-bell ding"),
    "wave_cleared":    dict(r=[r31_wave_cleared], bus="SFX", vol_db=-7, max=1, gap=1.0, prio=8, pitch=0.0, duck=-3, faction="bakery", desc="wave broken: two quick bells up a fifth + crust cheer"),
    "ui_upgrade_ok":         dict(r=[r31_upgrade_ok], bus="UI", vol_db=-7, max=1, gap=0.2, prio=7, pitch=0.0, faction="neutral", desc="upgrade done: warm rising bells"),
    "ui_upgrade_no_coins":   dict(r=[r31_upgrade_no_coins], bus="UI", vol_db=-9, max=1, gap=0.25, prio=6, pitch=0.0, faction="neutral", desc="not enough gold: two soft falling coin taps"),
    "ui_upgrade_max":        dict(r=[r31_upgrade_max], bus="UI", vol_db=-9, max=1, gap=0.25, prio=6, pitch=0.0, faction="neutral", desc="max level: neutral knock + soft bell"),
    "ui_upgrade_save_failed": dict(r=[r31_upgrade_save_failed], bus="UI", vol_db=-8, max=1, gap=0.25, prio=7, pitch=0.0, faction="neutral", desc="save failed: low two-tone buzz + crack"),
    "stinger_defeat":  dict(r=[r3_stinger_defeat], bus="Music", vol_db=-3, max=1, gap=1.0, prio=10, pitch=0.0, faction="mold", desc="tune sinks into a soggy wobble, bubbles take over"),
}
# Engine mapping hints consumed by the runtime bridge (data-driven, so 01 can add skills without code).
SKILL_KIND_CUE = {"aoe_damage": "skill_slam", "rally": "skill_rally", "meteor": "skill_barrage",
                  "heal_allies": "skill_heal", "summon": "skill_cast"}
PROJECTILE_CUE = {"arrow": "shoot_arrow", "rock": "shoot_rock", "spit": "shoot_spit"}
# Shared rate limits (v3.4). "hit": minimum seconds between ANY two hit cues (bread/mold/fallbacks), so the
# faction split does not double hit density. Value chosen by the same-seed A/B in docs/audio/HIT_DENSITY_AB.md.
CUES.update({
    "flour_delivery": dict(r=[r_flour_delivery], bus="SFX", vol_db=-16, max=1, gap=1.2, prio=1, pitch=0.04,
                           peak_dbfs_target=-5.0, fade_in=0.004, fade_out=0.02, faction="bakery", desc="a flour sack settles onto the delivery pallet"),
    "ui_scout": dict(r=[r_ui_scout], bus="UI", vol_db=-13, max=1, gap=0.2, prio=6, pitch=0.0,
                     peak_dbfs_target=-5.0, fade_in=0.003, fade_out=0.01, faction="neutral", desc="soft scouting and return-to-hero cue"),
})
CUE_GROUPS = {"hit": {"min_gap": 0.36}}   # same-seed A/B: 83 -> 49 hits/min (target 48-56); NOT yet confirmed by listening
# v3.9 onset-cluster limit (docs/audio/ONSET_PEAK_CHECK.md): from the 4th SFX start within 0.1 s, low-priority cues
# (prio < 3: hits, shots, gold_tick) start / are lowered 6 dB; prio >= 3 (danger, deaths, deploy, skills, boss) never.
# OFF in the committed manifest until the after-run (job 05-peak-after-9rec) meets P1-P7; ONSET_CLUSTER_ON enables it.
ONSET_CLUSTER = {"window": 0.1, "max_full": 3, "db": -6.0, "exempt_prio": 3}
ONSET_CLUSTER_ON = False
# 04 upgrade_panel result codes -> cue (semantic Events.sfx &"upgrade_result" {"code": code}); key name requested from 04 (C5)
# "" = intentionally silent (already_applied = repeated tap of a finished purchase; the first tap already sounded)
UPGRADE_RESULT_CUE = {"ok": "ui_upgrade_ok", "already_applied": "", "not_enough_coins": "ui_upgrade_no_coins",
                      "max_level": "ui_upgrade_max", "save_failed": "ui_upgrade_save_failed", "save_uncertain": "ui_upgrade_save_failed",
                      "read_only": "ui_upgrade_save_failed", "locked": "ui_error", "unknown_id": "ui_error", "invalid_level": "ui_error",
                      "unavailable": "ui_error", "no_reply": "ui_error"}

# ----------------------------------------------------------------------------------------------
# Music: tiny pattern sequencer rendering seamless loops (all note tails wrap to the loop start)
# ----------------------------------------------------------------------------------------------
MSR = MUSIC_SR


def m_tone(f, dur, shape, duty=0.5, a=0.004, d=0.05, s=0.7, r=0.03, vib=0.0, vib_delay=0.15):
    n = n_samples(dur + r, MSR)
    ff = np.full(n, f, dtype=np.float64)
    t = np.arange(n) / MSR
    if vib > 0:
        ff *= 1 + vib * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - vib_delay) / 0.1, 0, 1)
    # v3 bakery voices
    if shape == "accordion":   # street-band accordion: two detuned saws, gentle bellows tremolo, warm low-pass
        sig = 0.5 * (osc(ff * 0.997, n, MSR, "saw") + osc(ff * 1.003, n, MSR, "saw"))
        sig = lowpass(sig, 2200, MSR) * (1 + 0.07 * np.sin(2 * np.pi * 5.2 * t))
        return sig * env_adsr(n, MSR, max(a, 0.012), d, s, r)
    if shape == "bell":        # music-box / shop bell: inharmonic partials, struck decay
        tau = max(0.12, dur * 0.7)
        sig = osc(ff, n, MSR, "sine") * env_exp(n, MSR, tau, 0.001)
        sig += 0.4 * osc(ff * 2.756, n, MSR, "sine") * env_exp(n, MSR, tau * 0.5, 0.001)
        sig += 0.18 * osc(ff * 5.404, n, MSR, "sine") * env_exp(n, MSR, tau * 0.25, 0.001)
        return sig
    if shape == "pluck":       # pizzicato / wooden pluck: triangle + fast decay
        return osc(ff, n, MSR, "tri") * env_exp(n, MSR, 0.09, 0.002)
    if shape == "pluckbass":   # plucked bass with audible upper harmonics (phone speakers drop the fundamental)
        sig = osc(ff, n, MSR, "tri") * 0.55 + osc(ff, n, MSR, "square", 0.2) * 0.45
        return lowpass(sig, 2200, MSR) * env_exp(n, MSR, 0.1, 0.002)
    return osc(ff, n, MSR, shape, duty) * env_adsr(n, MSR, a, d, s, r)


def m_kick(n_dur=0.22):
    # sine drop + short 1-3 kHz click so the beat survives phone speakers (little output < ~300 Hz)
    n = n_samples(n_dur, MSR)
    body = osc(ramp(160, 50, n), n, MSR, "sine") * env_exp(n, MSR, 0.07, 0.001)
    nc = n_samples(0.012, MSR)
    click = osc(ramp(2600, 900, nc), nc, MSR, "tri") * env_exp(nc, MSR, 0.003, 0.0003)
    body[:nc] += click * 0.35
    return body


def m_snare(rng):
    n = n_samples(0.16, MSR)
    nz = highpass(noise(n, rng), 1200, MSR) * env_exp(n, MSR, 0.045, 0.001)
    body = osc(ramp(210, 170, n), n, MSR, "tri") * env_exp(n, MSR, 0.03, 0.001)
    return nz * 0.8 + body * 0.5


def m_hat(rng, open_=False):
    n = n_samples(0.12 if open_ else 0.04, MSR)
    return highpass(noise(n, rng), 6500, MSR) * env_exp(n, MSR, 0.04 if open_ else 0.012, 0.0005)


def parse_line(line: str):
    """'C5:1 E5:0.5 r:1' -> [(beat_offset, beats, midi|None)]"""
    out, t = [], 0.0
    for tok in line.split():
        nm, b = tok.split(":")
        b = float(b)
        out.append((t, b, None if nm == "r" else note_midi(nm)))
        t += b
    assert abs(t - 4.0) < 1e-6, (line, t)
    return out


CHORDS = {  # root midi (octave 3), intervals
    "C": (48, (0, 4, 7)), "Am": (45, (0, 3, 7)), "F": (41, (0, 4, 7)), "G": (43, (0, 4, 7)),
    "Em": (40, (0, 3, 7)), "Dm": (50, (0, 3, 7)), "Bb": (46, (0, 4, 7)),
}


def render_loop(spec: dict, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    bpm = spec["bpm"]
    spb = MSR * 60.0 / bpm
    assert abs(spb - round(spb)) < 1e-9, "choose a BPM with an integer samples-per-beat for exact loop length"
    spb = int(round(spb))
    bars = len(spec["chords"])
    L = bars * 4 * spb
    left = np.zeros(L)
    right = np.zeros(L)

    def put(sig, beat, pan=0.0, gain=1.0):
        at = int(round(beat * spb))
        gl = gain * math.cos((pan + 1) * math.pi / 4) * math.sqrt(2)
        gr = gain * math.sin((pan + 1) * math.pi / 4) * math.sqrt(2)
        place(left, sig * gl, at, wrap=True)
        place(right, sig * gr, at, wrap=True)

    beat_sec = 60.0 / bpm
    kick, hat_c, hat_o = m_kick(), m_hat(rng), m_hat(rng, True)
    snares = [m_snare(rng) for _ in range(3)]
    for bar, ch in enumerate(spec["chords"]):
        root, ivs = CHORDS[ch]
        b0 = bar * 4
        # bass
        for i, step in enumerate(spec["bass"]):
            if step is None:
                continue
            m = (root - 12 + step if spec.get("bass_low", True) else root + step) + spec.get("bass_oct", 0)
            put(m_tone(midi_hz(m), beat_sec * 0.42, spec.get("bass_shape", "tri"), a=0.003, d=0.06, s=0.8, r=0.02), b0 + i * 0.5, 0.0, spec["g_bass"])
        # arpeggio (16ths) over chord tones
        if spec["g_arp"] > 0:
            tones = [root + 12 + iv for iv in ivs] + [root + 24]
            order = spec["arp_order"]
            for i in range(16 if spec["arp16"] else 8):
                step_b = 0.25 if spec["arp16"] else 0.5
                m = tones[order[i % len(order)]]
                put(m_tone(midi_hz(m), beat_sec * step_b * 0.6, spec["arp_shape"], 0.25, a=0.002, d=0.04, s=0.4, r=0.02),
                    b0 + i * step_b, -0.35, spec["g_arp"])
        # pad (menu)
        if spec.get("g_pad", 0) > 0:
            for iv in ivs:
                put(m_tone(midi_hz(root + 12 + iv), beat_sec * 3.8, "tri", a=0.25, d=0.3, s=0.7, r=0.25), b0, 0.25 if iv else -0.25, spec["g_pad"])
        # drums
        dr = spec["drums"]
        fill = (bar % 4 == 3) and spec.get("fills", False)
        for st in range(16):
            beat = b0 + st * 0.25
            if st in dr.get("kick", ()):
                put(kick, beat, 0.0, spec["g_kick"])
            sn = dr.get("snare", ())
            if st in sn or (fill and st in (13, 14, 15)):
                put(snares[(bar + st) % 3], beat, 0.1, spec["g_snare"] * (0.6 if fill and st not in sn else 1.0))
            if st in dr.get("hat", ()):
                put(hat_o if st in dr.get("open", ()) else hat_c, beat, 0.3, spec["g_hat"] * (1.0 if st % 4 == 0 else 0.7))
        # lead
        for off, beats, m in parse_line(spec["melody"][bar]):
            if m is None:
                continue
            sig = m_tone(midi_hz(m), beat_sec * beats * 0.92, spec["lead_shape"], 0.5, a=0.006, d=0.08, s=0.72, r=0.05, vib=0.006)
            put(sig, b0 + off, 0.2, spec["g_lead"])
            if spec.get("echo", 0) > 0:  # 3/8-beat echo, wraps with the loop
                put(lowpass(sig, 2500, MSR), b0 + off + 0.75, -0.4, spec["g_lead"] * spec["echo"])
    st = np.stack([left, right], axis=1)
    st = st - st.mean(axis=0)
    st = np.tanh(st * 1.2) / np.tanh(1.2) if spec.get("soft_clip") else st
    m = float(np.max(np.abs(st)))
    return st * (MUSIC_PEAK / m)


BATTLE = dict(
    bpm=140,  # 44100*60/140 = 18900 samples per beat (integer -> exact loop length)
    chords=["C", "C", "Am", "Am", "F", "F", "G", "G", "C", "C", "Em", "Em", "F", "F", "G", "G"],
    melody=[
        "C5:1 E5:0.5 G5:0.5 A5:1 G5:1", "E5:1.5 D5:0.5 C5:1 r:1",
        "A4:1 C5:0.5 E5:0.5 A5:1.5 G5:0.5", "E5:2 r:1 E5:0.5 F5:0.5",
        "F5:1 A5:0.5 F5:0.5 C6:1 A5:1", "G5:1 F5:0.5 E5:0.5 F5:1 r:1",
        "G5:1 B4:0.5 D5:0.5 G5:1 F5:1", "D5:1 E5:0.5 F5:0.5 G5:1 r:1",
        "C6:1 B5:0.5 A5:0.5 G5:1 E5:1", "G5:1.5 E5:0.5 C5:1 G4:1",
        "B4:1 E5:0.5 G5:0.5 B5:1.5 A5:0.5", "G5:2 r:1 G5:0.5 A5:0.5",
        "A5:1 C6:0.5 A5:0.5 F5:1 A5:1", "G5:1 A5:0.5 G5:0.5 F5:1 E5:1",
        "D5:1 G5:0.5 B5:0.5 D6:1 B5:1", "G5:1 F5:0.5 D5:0.5 B4:1 r:1",
    ],
    bass=[0, 0, 12, 0, 7, 0, 12, 7], bass_low=False,
    # v3 theme: bakery street-band march. Accordion lead, music-box bell arpeggio, plucked bass.
    arp_order=[0, 1, 2, 3, 2, 1], arp16=True, arp_shape="bell", bass_shape="pluckbass", bass_oct=12,
    drums=dict(kick=(0, 6, 8, 10), snare=(4, 12), hat=(0, 2, 4, 6, 8, 10, 12, 14), open=(14,)),
    fills=True, lead_shape="accordion", echo=0.2, soft_clip=True,
    g_bass=0.24, g_arp=0.05, g_kick=0.22, g_snare=0.3, g_hat=0.07, g_lead=0.24,
)

MENU = dict(
    bpm=105,  # 44100*60/105 = 25200 samples per beat
    chords=["F", "C", "Dm", "Bb", "F", "C", "Bb", "C"],
    melody=[
        "A4:1 C5:1 F5:1.5 E5:0.5", "E5:1 G5:0.5 E5:0.5 C5:2",
        "D5:1 F5:1 A5:1.5 G5:0.5", "F5:1 D5:1 Bb4:2",
        "C5:1 F5:0.5 G5:0.5 A5:1.5 C6:0.5", "Bb5:1 A5:0.5 G5:0.5 E5:2",
        "D5:1 F5:1 Bb5:1 A5:1", "G5:1.5 E5:0.5 C5:1 G4:1",
    ],
    bass=[0, None, None, None, 7, None, None, None], bass_low=False,
    # v3 theme: morning bakery. Music-box bell lead, plucked arpeggio, soft pad.
    arp_order=[0, 1, 2, 3, 2, 1, 0, 2], arp16=False, arp_shape="pluck", bass_shape="pluck",
    drums=dict(kick=(0, 8), hat=(4, 12)), fills=False,
    lead_shape="bell", echo=0.3, soft_clip=False,
    g_bass=0.4, g_arp=0.12, g_pad=0.06, g_kick=0.3, g_snare=0.0, g_hat=0.05, g_lead=0.3,
)

MUSIC = {
    "music_battle": dict(spec=BATTLE, seed=7001, vol_db=-12, faction="bakery",
                         desc="bakery street-band march, C major 140 BPM: accordion lead, bell arpeggio, plucked bass"),
    "music_menu": dict(spec=MENU, seed=7002, vol_db=-9, faction="bakery",
                       desc="morning bakery, F major 105 BPM: music-box bell melody, plucked chords, soft pad"),
}


def encode_ogg(src: Path, dst: Path, quality: float) -> bool:
    ff = shutil.which("ffmpeg")
    if not ff:
        print("WARN: ffmpeg not found; music OGG skipped", file=sys.stderr)
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_name(dst.name + ".part")   # unknown extension: Godot never imports it
    cmd = [ff, "-hide_banner", "-loglevel", "error", "-y", "-i", str(src), "-map_metadata", "-1",
           "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", str(quality), "-f", "ogg", str(tmp)]
    if subprocess.run(cmd).returncode != 0:
        return False
    replace_retry(tmp, dst)
    return True


def stats(x: np.ndarray) -> dict:
    pk = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(np.square(x))))
    return {"peak_dbfs": round(20 * math.log10(max(pk, 1e-9)), 2), "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 2)}


def main() -> int:
    only = set()
    for arg in sys.argv[1:]:
        if not arg.startswith("--only="):
            raise SystemExit("Usage: synth.py [--only=cue,cue,...]")
        only.update(filter(None, arg.split("=", 1)[1].split(",")))
    if only - CUES.keys():
        raise SystemExit("Unknown cues: " + ",".join(sorted(only - CUES.keys())))
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1, "generator": "tools/audio/synth.py", "generator_version": GENERATOR_VERSION,
        "technique": "deterministic numpy synthesis (oscillators/noise/envelopes/filters); no samples, no AI services",
        "license": ("Original work created for this project by the 05-audio worker with tools/audio/synth.py. "
                    "No third-party samples, loops, presets, downloaded audio or AI audio services were used, so no "
                    "third-party licence or attribution applies. Rights belong to the project owner; the public "
                    "licence (if any) is the project owner\u2019s decision and has not been chosen."),
        "provenance": {"tool": "tools/audio/synth.py", "python": "3.11 + numpy", "encoder": "ffmpeg libvorbis q3 (music only, bitexact)",
                       "reproduce": "python tools/audio/synth.py && python tools/audio/validate.py --determinism",
                       "deterministic": True},
        "theme": {"decision": "Q1 = A, bakery knights (player) vs mold legion (enemy); user-decided 2026-10-31 09:03",
                  "bakery": "warm, bouncy, dry: oven/shop bells, crust crunch, wooden knocks, major keys, accordion lead",
                  "mold": "wet, sticky, slow: squelch (sweeping formant band), bubble pops, wobbling pitch, minor/tritone",
                  "neutral": "UI and fallback cues"},
        "sfx_format": {"codec": "pcm_s16le", "rate": SFX_SR, "channels": 1},
        "cues": {}, "music": {}, "skill_kind_cue": SKILL_KIND_CUE, "projectile_cue": PROJECTILE_CUE,
        "upgrade_result_cue": UPGRADE_RESULT_CUE, "groups": CUE_GROUPS, **({"onset_cluster": ONSET_CLUSTER} if ONSET_CLUSTER_ON else {}),
    }
    if only:
        manifest = json.loads((OUT / "audio_manifest.json").read_text(encoding="utf-8"))
        manifest["generator_version"] = GENERATOR_VERSION
    seed = 1000
    for cue, c in CUES.items():
        if only and cue not in only:
            seed += len(c["r"])
            continue
        files = []
        info = []
        for vi, recipe in enumerate(c["r"]):
            seed += 1
            rng = np.random.default_rng(seed)
            x = fade_edges(normalize(highpass(np.asarray(recipe(rng), dtype=np.float64), 30.0, SR), 10 ** (float(c.get("peak_dbfs_target", -1.0)) / 20)), SR, float(c.get("fade_in", 0.002)), float(c.get("fade_out", 0.008)))
            name = f"{cue}.wav" if len(c["r"]) == 1 else f"{cue}_{vi + 1}.wav"
            write_wav(SFX_DIR / name, x, SR, seed)
            files.append(f"res://assets/audio/sfx/{name}")
            info.append({"file": name, "seconds": round(len(x) / SR, 3), "bytes": (SFX_DIR / name).stat().st_size, **stats(x)})
        # v3.8 extra variants: stable seeds 70000+n and names <cue>_v2.wav ... (existing files/seeds unchanged)
        xseeds = []
        for xi, recipe in enumerate(c.get("rx", [])):
            xs = 70000 + 10 * list(CUES).index(cue) + xi
            xseeds.append(xs)
            rng = np.random.default_rng(xs)
            x = fade_edges(normalize(highpass(np.asarray(recipe(rng), dtype=np.float64), 30.0, SR), 10 ** (float(c.get("peak_dbfs_target", -1.0)) / 20)), SR, float(c.get("fade_in", 0.002)), float(c.get("fade_out", 0.008)))
            name = f"{cue}_v{xi + 2}.wav"
            write_wav(SFX_DIR / name, x, SR, xs)
            files.append(f"res://assets/audio/sfx/{name}")
            info.append({"file": name, "seconds": round(len(x) / SR, 3), "bytes": (SFX_DIR / name).stat().st_size, **stats(x)})
        entry = {k: v for k, v in c.items() if k not in ("r", "rx")}
        entry["provenance"] = {"recipes": [getattr(rc, "__name__", "lambda") for rc in c["r"]],
                               "seeds": list(range(seed - len(c["r"]) + 1, seed + 1)) + xseeds}
        entry.setdefault("duck", 0)
        entry["files"] = files
        entry["variants"] = info
        manifest["cues"][cue] = entry
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    (SRC_DIR / ".gdignore").write_text("", encoding="utf-8")   # keep Godot from importing intermediates
    for mid, m in (MUSIC.items() if not only else []):
        st = render_loop(m["spec"], m["seed"])
        wav = SRC_DIR / f"{mid}.wav"
        write_wav(wav, st, MSR, m["seed"])
        ogg = MUSIC_DIR / f"{mid}.ogg"
        ok = encode_ogg(wav, ogg, 3)
        spb = int(round(MSR * 60 / m["spec"]["bpm"]))
        manifest["music"][mid] = {
            "file": f"res://assets/audio/music/{mid}.ogg", "bus": "Music", "vol_db": m["vol_db"], "loop": True,
            "bpm": m["spec"]["bpm"], "bars": len(m["spec"]["chords"]), "loop_samples": len(st), "rate": MSR,
            "seconds": round(len(st) / MSR, 3), "samples_per_beat": spb, "encoded": ok,
            "faction": m.get("faction", ""), "desc": m.get("desc", ""),
            "provenance": {"recipe": "render_loop", "seed": m["seed"], "encoder": "libvorbis q3"},
            "bytes": ogg.stat().st_size if ok else 0, **stats(st),
        }
        print(f"{mid}: {len(st) / MSR:.2f}s loop, ogg={'ok' if ok else 'SKIPPED'}")
    (OUT / "audio_manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"cues={len(manifest['cues'])} files={sum(len(c['files']) for c in manifest['cues'].values())} music={len(manifest['music'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
