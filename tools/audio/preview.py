#!/usr/bin/env python3
"""Visual + loudness evidence for reviewers who cannot listen. Owner: 05-audio.

Writes:
  docs/audio/previews/sfx_contact_sheet.png  spectrogram (0-11 kHz, log magnitude) + waveform per SFX file
  docs/audio/previews/music_overview.png     spectrogram + RMS envelope per music loop, seam marked
  docs/audio/LOUDNESS.md                     K-weighted (ITU-R BS.1770 filter) loudness per cue and mix level
Loudness here: max momentary loudness over 100 ms windows (short SFX are too short for gated
integrated loudness). "Mix" = that value + manifest vol_db (what the player hears relative to others,
before bus volume). Deviations are listed for review, not auto-failed: different roles deserve
different levels (UI quieter than boss alerts).
Usage: python tools/audio/preview.py
"""
from __future__ import annotations

import json
import math
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy.signal import lfilter

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MAN = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))
OUTD = ROOT / "docs/audio/previews"


def k_weight(x: np.ndarray, fs: int) -> np.ndarray:
    # libebur128 / BS.1770 coefficient formulas for arbitrary sample rate
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / fs)
    d = 1 + K / Q + K * K
    a2 = [1, 2 * (K * K - 1) / d, (1 - K / Q + K * K) / d]
    b2 = [1, -2, 1]
    return lfilter(b2, a2, lfilter(b1, a1, x))


def momentary_max(x: np.ndarray, fs: int, win: float = 0.1) -> float:
    y = k_weight(x, fs) ** 2
    n = max(1, int(win * fs))
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    c = np.convolve(y, np.ones(n) / n, mode="valid")
    return -0.691 + 10 * math.log10(max(float(c.max()), 1e-12))


def read_wav(p: Path):
    with wave.open(str(p), "rb") as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return sr, x


def spec(ax, x, sr, nfft=256):
    ax.specgram(x, NFFT=nfft, Fs=sr, noverlap=nfft * 3 // 4, cmap="magma", vmin=-110, vmax=-10)
    ax.set_ylim(0, min(11025, sr / 2))


def main() -> int:
    OUTD.mkdir(parents=True, exist_ok=True)
    rows = []
    items = []
    for cue, c in MAN["cues"].items():
        for res in c["files"]:
            p = ROOT / res[len("res://"):]
            sr, x = read_wav(p)
            items.append((cue, p.name, sr, x, c))
    cols = 5
    nrow = math.ceil(len(items) / cols)
    fig, axes = plt.subplots(nrow * 2, cols, figsize=(cols * 3.2, nrow * 2.6),
                             gridspec_kw={"height_ratios": [3, 1] * nrow})
    for i, (cue, name, sr, x, c) in enumerate(items):
        r, k = divmod(i, cols)
        a_s, a_w = axes[r * 2][k], axes[r * 2 + 1][k]
        spec(a_s, x, sr)
        lm = momentary_max(x, sr)
        a_s.set_title(f"{name}\n{len(x) / sr:.2f}s  M{lm:.1f}  mix{lm + c['vol_db']:.1f}  [{c['bus']}]", fontsize=7)
        a_s.tick_params(labelsize=5)
        t = np.arange(len(x)) / sr
        a_w.plot(t, x, lw=0.4, color="#2a6")
        a_w.set_ylim(-1, 1)
        a_w.set_xlim(0, t[-1])
        a_w.tick_params(labelsize=5)
        rows.append((cue, name, c["bus"], c["vol_db"], round(lm, 1), round(lm + c["vol_db"], 1), c["prio"]))
    for j in range(len(items), nrow * cols):
        r, k = divmod(j, cols)
        axes[r * 2][k].axis("off")
        axes[r * 2 + 1][k].axis("off")
    fig.suptitle("05-audio SFX contact sheet — spectrogram 0–11 kHz (log magnitude) + waveform. "
                 "M = max momentary K-weighted loudness (LUFS, 100 ms); mix = M + vol_db", fontsize=9)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    fig.savefig(OUTD / "sfx_contact_sheet.png", dpi=90)
    plt.close(fig)
    # music
    ff = shutil.which("ffmpeg")
    mus_rows = []
    if ff:
        fig, axes = plt.subplots(len(MAN["music"]) * 2, 1, figsize=(14, 3.2 * len(MAN["music"])),
                                 gridspec_kw={"height_ratios": [3, 1] * len(MAN["music"])})
        for i, (mid, m) in enumerate(MAN["music"].items()):
            p = ROOT / m["file"][len("res://"):]
            raw = subprocess.run([ff, "-v", "error", "-i", str(p), "-f", "f32le", "-ac", "1", "-ar", "22050", "-"],
                                 capture_output=True).stdout
            x = np.frombuffer(raw, dtype="<f4").astype(np.float64)
            # show the loop twice so the seam (middle line) can be inspected
            xx = np.concatenate([x, x])
            spec(axes[i * 2], xx, 22050, 1024)
            axes[i * 2].axvline(len(x) / 22050, color="cyan", lw=0.8)
            lm = momentary_max(x, 22050, 0.4)
            integ = -0.691 + 10 * math.log10(float(np.mean(k_weight(x, 22050) ** 2)))
            axes[i * 2].set_title(f"{mid}: {m['bpm']} BPM, {m['bars']} bars, {m['seconds']}s loop shown twice (cyan = seam); "
                                  f"ungated loudness {integ:.1f} LUFS, max momentary {lm:.1f}", fontsize=8)
            n = 2205
            env = np.sqrt(np.convolve(xx ** 2, np.ones(n) / n, mode="same"))
            axes[i * 2 + 1].plot(np.arange(len(xx)) / 22050, 20 * np.log10(env + 1e-6), lw=0.5)
            axes[i * 2 + 1].axvline(len(x) / 22050, color="cyan", lw=0.8)
            axes[i * 2 + 1].set_ylim(-60, 0)
            axes[i * 2 + 1].set_ylabel("RMS dB", fontsize=6)
            mus_rows.append((mid, round(integ, 1), round(lm, 1), m["vol_db"], round(integ + m["vol_db"], 1)))
        fig.tight_layout()
        fig.savefig(OUTD / "music_overview.png", dpi=80)
        plt.close(fig)
    # loudness doc
    by_bus: dict[str, list[float]] = {}
    for r in rows:
        by_bus.setdefault(r[2], []).append(r[5])
    med = {b: float(np.median(v)) for b, v in by_bus.items()}
    lines = ["# LOUDNESS.md — measured loudness per cue (generated by tools/audio/preview.py)", "",
             "M = max momentary K-weighted loudness over 100 ms (BS.1770 K filter; short SFX are too short for gated "
             "integrated loudness). Mix = M + manifest `vol_db` (relative level before bus volume). "
             "Δ = Mix − median Mix of the same bus. |Δ| > 6 dB is listed for review; roles may justify it.", "",
             "| Cue | File | Bus | vol_db | M (LUFS) | Mix | Δ bus median | prio |", "|---|---|---|---|---|---|---|---|"]
    flagged = []
    for r in rows:
        d = r[5] - med[r[2]]
        lines.append(f"| {r[0]} | {r[1]} | {r[2]} | {r[3]} | {r[4]} | {r[5]} | {d:+.1f} | {r[6]} |")
        if abs(d) > 6:
            flagged.append(f"- {r[1]} ({r[2]}): Δ {d:+.1f} dB")
    lines += ["", "Bus medians: " + ", ".join(f"{b} {v:.1f}" for b, v in med.items()), "", "## Review list (|Δ| > 6 dB)"]
    lines += flagged or ["- none"]
    if mus_rows:
        lines += ["", "## Music", "| Track | Ungated loudness (LUFS) | Max momentary 400 ms | vol_db | Mix |", "|---|---|---|---|---|"]
        lines += [f"| {a} | {b} | {c} | {d} | {e} |" for a, b, c, d, e in mus_rows]
    lines += ["", "Images: previews/sfx_contact_sheet.png, previews/music_overview.png.",
              "Limit: these are measurements, not a listening judgement."]
    (ROOT / "docs/audio/LOUDNESS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"sheet rows={len(rows)} flagged={len(flagged)} music={len(mus_rows)}")
    for f in flagged:
        print(f)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
