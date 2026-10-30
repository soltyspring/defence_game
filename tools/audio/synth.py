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
GENERATOR_VERSION = 1

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


def write_wav(path: Path, x: np.ndarray, sr: int, seed: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(seed + 991)
    ch = 1 if x.ndim == 1 else x.shape[1]
    pcm = to_pcm16(x, rng)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())

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


def r_hit_melee(rng, var):
    p = [1.0, 0.88, 1.12][var]
    crack = burst(rng, 0.07, 0.02, 900 * p, 5000 * p)
    body = thump(260 * p, 120 * p, 0.08, 0.025) * 0.45
    return seq([(0, crack), (0.003, body)], 0.1)


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
    return seq([(0, thump(160, 110, 0.15, 0.05) * 0.4), (0.0, crunch_layer(rng, 0.12, 0.04, 0.9))], 0.16)


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
    drum = mix(thump(150, 60, 0.18, 0.06), burst(rng, 0.1, 0.03, 200, 1500) * 0.4)
    out = seq([(0.0, drum), (0.16, drum * 0.8)], 0.9)
    n = n_samples(0.5, SR)
    f = midi_hz(62)
    horn = lowpass(osc(f, n, SR, "saw") + osc(f * 1.5, n, SR, "saw") * 0.5, 1800, SR) * env_adsr(n, SR, 0.04, 0.1, 0.7, 0.15)
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
CUES = {
    "ui_tap":          dict(r=[r_ui_tap], bus="UI", vol_db=-8, max=2, gap=0.03, prio=6, pitch=0.03),
    "ui_back":         dict(r=[r_ui_back], bus="UI", vol_db=-8, max=1, gap=0.05, prio=6, pitch=0.0),
    "ui_confirm":      dict(r=[r_ui_confirm], bus="UI", vol_db=-7, max=1, gap=0.05, prio=7, pitch=0.0),
    "ui_error":        dict(r=[r_ui_error], bus="UI", vol_db=-9, max=1, gap=0.25, prio=6, pitch=0.0),
    "deploy":          dict(r=[r_deploy], bus="SFX", vol_db=-6, max=2, gap=0.06, prio=7, pitch=0.04),
    "worker_buy":      dict(r=[r_worker_buy], bus="SFX", vol_db=-7, max=1, gap=0.1, prio=7, pitch=0.0),
    "gold_tick":       dict(r=[r_gold_tick], bus="SFX", vol_db=-16, max=2, gap=0.09, prio=2, pitch=0.05),
    "hit_melee":       dict(r=[lambda g: r_hit_melee(g, 0), lambda g: r_hit_melee(g, 1), lambda g: r_hit_melee(g, 2)],
                            bus="SFX", vol_db=-14, max=3, gap=0.045, prio=1, pitch=0.08),
    "hit_arrow":       dict(r=[r_hit_arrow], bus="SFX", vol_db=-15, max=2, gap=0.05, prio=1, pitch=0.08),
    "shoot_arrow":     dict(r=[r_shoot_arrow], bus="SFX", vol_db=-17, max=2, gap=0.06, prio=1, pitch=0.08),
    "shoot_rock":      dict(r=[r_shoot_rock], bus="SFX", vol_db=-13, max=1, gap=0.12, prio=2, pitch=0.06),
    "shoot_spit":      dict(r=[r_shoot_spit], bus="SFX", vol_db=-15, max=2, gap=0.08, prio=1, pitch=0.08),
    "hit_base":        dict(r=[r_hit_base], bus="SFX", vol_db=-9, max=1, gap=0.35, prio=5, pitch=0.05),
    "explosion":       dict(r=[r_explosion], bus="SFX", vol_db=-8, max=2, gap=0.12, prio=5, pitch=0.06),
    "death_ally":      dict(r=[lambda g: r_death(g, False)], bus="SFX", vol_db=-12, max=2, gap=0.08, prio=3, pitch=0.06),
    "death_enemy":     dict(r=[lambda g: r_death(g, True)], bus="SFX", vol_db=-12, max=2, gap=0.07, prio=3, pitch=0.08),
    "hero_death":      dict(r=[r_hero_death], bus="SFX", vol_db=-5, max=1, gap=1.0, prio=9, pitch=0.0, duck=-6),
    "hero_respawn":    dict(r=[r_hero_respawn], bus="SFX", vol_db=-8, max=1, gap=1.0, prio=8, pitch=0.0),
    "skill_slam":      dict(r=[r_skill_slam], bus="SFX", vol_db=-4, max=1, gap=0.2, prio=9, pitch=0.0, duck=-4),
    "skill_rally":     dict(r=[r_skill_rally], bus="SFX", vol_db=-6, max=1, gap=0.2, prio=9, pitch=0.0, duck=-4),
    "skill_barrage":   dict(r=[r_skill_barrage], bus="SFX", vol_db=-4, max=1, gap=0.2, prio=9, pitch=0.0, duck=-5),
    "skill_heal":      dict(r=[r_skill_heal], bus="SFX", vol_db=-7, max=1, gap=0.2, prio=9, pitch=0.0, duck=-3),
    "skill_cast":      dict(r=[r_skill_cast], bus="SFX", vol_db=-7, max=1, gap=0.2, prio=8, pitch=0.0, duck=-3),
    "wave_incoming":   dict(r=[r_wave_incoming], bus="SFX", vol_db=-6, max=1, gap=1.0, prio=8, pitch=0.0, duck=-4),
    "boss_incoming":   dict(r=[r_boss_incoming], bus="SFX", vol_db=-4, max=1, gap=2.0, prio=10, pitch=0.0, duck=-8),
    "stinger_win":     dict(r=[r_stinger_win], bus="Music", vol_db=-3, max=1, gap=1.0, prio=10, pitch=0.0),
    "stinger_defeat":  dict(r=[r_stinger_defeat], bus="Music", vol_db=-3, max=1, gap=1.0, prio=10, pitch=0.0),
}

# Engine mapping hints consumed by the runtime bridge (data-driven, so 01 can add skills without code).
SKILL_KIND_CUE = {"aoe_damage": "skill_slam", "rally": "skill_rally", "meteor": "skill_barrage",
                  "heal_allies": "skill_heal", "summon": "skill_cast"}
PROJECTILE_CUE = {"arrow": "shoot_arrow", "rock": "shoot_rock", "spit": "shoot_spit"}

# ----------------------------------------------------------------------------------------------
# Music: tiny pattern sequencer rendering seamless loops (all note tails wrap to the loop start)
# ----------------------------------------------------------------------------------------------
MSR = MUSIC_SR


def m_tone(f, dur, shape, duty=0.5, a=0.004, d=0.05, s=0.7, r=0.03, vib=0.0, vib_delay=0.15):
    n = n_samples(dur + r, MSR)
    ff = np.full(n, f, dtype=np.float64)
    if vib > 0:
        t = np.arange(n) / MSR
        ff *= 1 + vib * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - vib_delay) / 0.1, 0, 1)
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
            m = root - 12 + step if spec.get("bass_low", True) else root + step
            put(m_tone(midi_hz(m), beat_sec * 0.42, "tri", a=0.003, d=0.06, s=0.8, r=0.02), b0 + i * 0.5, 0.0, spec["g_bass"])
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
    arp_order=[0, 1, 2, 3, 2, 1], arp16=True, arp_shape="square",
    drums=dict(kick=(0, 6, 8, 10), snare=(4, 12), hat=(0, 2, 4, 6, 8, 10, 12, 14), open=(14,)),
    fills=True, lead_shape="square", echo=0.25, soft_clip=True,
    g_bass=0.42, g_arp=0.07, g_kick=0.6, g_snare=0.32, g_hat=0.07, g_lead=0.2,
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
    arp_order=[0, 1, 2, 3, 2, 1, 0, 2], arp16=False, arp_shape="tri",
    drums=dict(kick=(0, 8), hat=(4, 12)), fills=False,
    lead_shape="tri", echo=0.3, soft_clip=False,
    g_bass=0.4, g_arp=0.12, g_pad=0.06, g_kick=0.3, g_snare=0.0, g_hat=0.05, g_lead=0.3,
)

MUSIC = {
    "music_battle": dict(spec=BATTLE, seed=7001, vol_db=-8),
    "music_menu": dict(spec=MENU, seed=7002, vol_db=-9),
}


def encode_ogg(src: Path, dst: Path, quality: float) -> bool:
    ff = shutil.which("ffmpeg")
    if not ff:
        print("WARN: ffmpeg not found; music OGG skipped", file=sys.stderr)
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    cmd = [ff, "-hide_banner", "-loglevel", "error", "-y", "-i", str(src), "-map_metadata", "-1",
           "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", str(quality), str(dst)]
    return subprocess.run(cmd).returncode == 0


def stats(x: np.ndarray) -> dict:
    pk = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(np.square(x))))
    return {"peak_dbfs": round(20 * math.log10(max(pk, 1e-9)), 2), "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 2)}


def main() -> int:
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1, "generator": "tools/audio/synth.py", "generator_version": GENERATOR_VERSION,
        "technique": "deterministic numpy synthesis (oscillators/noise/envelopes/filters); no samples, no AI services",
        "license": "original work for this project", "sfx_format": {"codec": "pcm_s16le", "rate": SFX_SR, "channels": 1},
        "cues": {}, "music": {}, "skill_kind_cue": SKILL_KIND_CUE, "projectile_cue": PROJECTILE_CUE,
    }
    seed = 1000
    for cue, c in CUES.items():
        files = []
        info = []
        for vi, recipe in enumerate(c["r"]):
            seed += 1
            rng = np.random.default_rng(seed)
            x = fade_edges(normalize(highpass(np.asarray(recipe(rng), dtype=np.float64), 30.0, SR), SFX_PEAK), SR)
            name = f"{cue}.wav" if len(c["r"]) == 1 else f"{cue}_{vi + 1}.wav"
            write_wav(SFX_DIR / name, x, SR, seed)
            files.append(f"res://assets/audio/sfx/{name}")
            info.append({"file": name, "seconds": round(len(x) / SR, 3), "bytes": (SFX_DIR / name).stat().st_size, **stats(x)})
        entry = {k: v for k, v in c.items() if k != "r"}
        entry.setdefault("duck", 0)
        entry["files"] = files
        entry["variants"] = info
        manifest["cues"][cue] = entry
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    (SRC_DIR / ".gdignore").write_text("", encoding="utf-8")   # keep Godot from importing intermediates
    for mid, m in MUSIC.items():
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
            "bytes": ogg.stat().st_size if ok else 0, **stats(st),
        }
        print(f"{mid}: {len(st) / MSR:.2f}s loop, ogg={'ok' if ok else 'SKIPPED'}")
    (OUT / "audio_manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"cues={len(manifest['cues'])} files={sum(len(c['files']) for c in manifest['cues'].values())} music={len(manifest['music'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
