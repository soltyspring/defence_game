#!/usr/bin/env python3
"""Analyse a real-mix battle recording made by `run_godot_checks.ps1 -Record`. Owner: 05-audio.

Inputs (tools/audio/_render/recording/): rec_master.wav (engine Master bus AFTER the hard limiter),
rec_sfx.wav / rec_ui.wav / rec_music.wav (bus stems captured in the same mix callbacks, before bus
fader), rec_meta.json (cue onset log, Music bus gain log incl. ducking).
Outputs:
  docs/audio/previews/listen/battle_mix_60s.wav   exact engine Master output (copy, no processing)
  docs/audio/previews/listen/battle_preview_30s.mp3  30 s excerpt for listening (MP3 192 kbps, 0.3 s fades only)
  docs/audio/previews/mix_timeline.png            loudness / SFX-vs-music / cue timeline
  docs/audio/MIX_REPORT.md                        measured findings
Measurements are objective proxies. They do not replace a human listening on a phone.
"""
from __future__ import annotations

import json
import math
import shutil
import subprocess
import sys
import wave
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt

sys.path.insert(0, str(Path(__file__).resolve().parent))
from preview import k_weight  # noqa: E402  (BS.1770 K-filter, same as LOUDNESS.md)

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
_ARGS = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--") and "=" in a}
REC = ROOT / _ARGS.get("--rec", "tools/audio/_render/recording")
LISTEN = ROOT / "docs/audio/previews/listen"
NO_PUBLISH = "--no-publish" in sys.argv   # A/B analysis: do not overwrite MIX_REPORT/previews/history
MAN = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))

# Internal heuristics (NOT external standards; labelled as such in the report)
BURIED_DB = 0.0          # SFX momentary loudness <= music loudness  -> buried
AT_RISK_DB = 3.0         # SFX less than 3 dB above music           -> at risk
REPEAT_RATE_HZ = 4.0     # same file > 4 onsets within any 1 s
REPEAT_10S = 20          # same file > 20 onsets within any 10 s
LOW_SHARE_FLAG = 0.5     # > 50 % of a sound's energy below 300 Hz -> mostly lost on phone speakers


def read(p: Path):
    with wave.open(str(p), "rb") as w:
        sr, ch = w.getframerate(), w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return sr, x.reshape(-1, ch)


def db(v: float) -> float:
    return 20 * math.log10(max(v, 1e-12))


def lufs_series(x: np.ndarray, sr: int, win: float, hop: float):
    """Ungated loudness per window (stereo: channel sum of K-weighted mean squares)."""
    k = np.stack([k_weight(x[:, c], sr) for c in range(x.shape[1])], axis=1) ** 2
    n, h = int(win * sr), int(hop * sr)
    t, v = [], []
    for s in range(0, max(1, len(k) - n + 1), h):
        ms = float(k[s:s + n].mean(axis=0).sum())
        t.append((s + n / 2) / sr)
        v.append(-0.691 + 10 * math.log10(max(ms, 1e-12)))
    return np.array(t), np.array(v)


def integrated_lufs(x: np.ndarray, sr: int) -> float:
    """BS.1770 gated integrated loudness (400 ms blocks, 75 % overlap, -70 abs / -10 rel gates)."""
    _, m = lufs_series(x, sr, 0.4, 0.1)
    m = m[m > -70]
    if len(m) == 0: return -70.0
    rel = 10 * math.log10(np.mean(10 ** (m / 10))) - 10
    m = m[m > rel]
    return 10 * math.log10(np.mean(10 ** (m / 10)))


def onsets(x: np.ndarray, sr: int) -> np.ndarray:
    """Energy-flux onsets (10 ms frames) of a mono-summed stem."""
    mono = np.abs(x).sum(axis=1)
    f = int(0.01 * sr)
    e = np.add.reduceat(mono ** 2, np.arange(0, len(mono) - f, f))
    d = np.diff(np.log(e + 1e-9))
    idx = np.where((d > 2.0) & (e[1:] > 1e-4))[0]
    out, last = [], -10
    for i in idx:
        if i - last > 3: out.append((i + 1) * f / sr)
        last = i
    return np.array(out)


def main() -> int:
    meta = json.loads((REC / "rec_meta.json").read_text(encoding="utf-8"))
    sr, master = read(REC / "rec_master.wav")
    _, sfx = read(REC / "rec_sfx.wav")
    _, ui = read(REC / "rec_ui.wav")
    _, music = read(REC / "rec_music.wav")
    n = min(len(master), len(sfx), len(ui), len(music))
    master, sfx, ui, music = master[:n], sfx[:n], ui[:n], music[:n]
    dur = n / sr
    wall = float(meta["seconds"])
    # --- align cue log (wall clock) with audio sample clock: search offset/scale that best matches SFX onsets
    cue_t = np.array([c[0] for c in meta["cues"]])
    cue_n = [c[1] for c in meta["cues"]]
    on = onsets(sfx + ui, sr)
    # The Dummy driver mixes slightly slower than wall clock (audio length < wall length), so search a
    # linear drift (scale) and an offset; tolerance 40 ms (10 ms onset frames + mix chunking).
    best = (-1, 0.0, 1.0)
    if len(on):
        for scale in np.linspace(min(1.0, dur / wall) - 0.004, 1.0005, 30):
            for off in np.arange(-0.6, 0.6, 0.004):
                tt = cue_t * scale + off
                hits = int(np.sum(np.min(np.abs(on[None, :] - tt[:, None]), axis=1) < 0.04))
                if hits > best[0]: best = (hits, float(off), float(scale))
    hits, off, scale = best
    cue_a = cue_t * scale + off
    mgain_t = [x[0] * scale + off for x in meta["music_gain"]]
    clk = np.array(meta.get("clock", []), dtype=float)
    if int(meta.get("log_format", 1)) >= 2 and len(clk) > 2:
        # v3.9 log: every cue has its audio-clock start and the clock maps wall -> audio time; no fit needed
        cue_a = np.array([float(c[5]) if float(c[5]) >= 0 else float(c[0]) * scale + off for c in meta["cues"]])
        mgain_t = list(np.interp([x[0] for x in meta["music_gain"]], clk[:, 0], clk[:, 1]))
        hits = int(sum(1 for t0 in cue_a if len(on) and np.min(np.abs(on - t0)) < 0.04))
    # --- music bus gain(t) (incl. ducking), mapped to the audio clock
    g = np.array([[t0, x[1]] for t0, x in zip(mgain_t, meta["music_gain"])])
    ts = np.arange(n) / sr
    gain_db = np.interp(ts, g[:, 0], g[:, 1])
    music_eff = music * (10 ** (gain_db / 20))[:, None]
    fx = sfx + ui                                    # SFX/UI buses at 0 dB in this run (meta)
    pre_lim = fx + music_eff
    # --- level / clipping
    pk = float(np.abs(master).max())
    tp = max(float(np.abs(resample_poly(master[:, c], 4, 1)).max()) for c in range(2))
    clipped = int(np.sum(np.abs(master) >= 32767 / 32768))
    over = int(np.sum(np.abs(pre_lim) > 10 ** (-0.5 / 20)))
    il = integrated_lufs(master, sr)
    st_t, st_v = lufs_series(master, sr, 3.0, 1.0)
    # --- SFX vs music (momentary 400 ms, full band and phone-speaker band >= 300 Hz)
    hp = butter(4, 300, "highpass", fs=sr, output="sos")
    mt, fx_m = lufs_series(fx, sr, 0.4, 0.1)
    _, mu_m = lufs_series(music_eff, sr, 0.4, 0.1)
    fx_hp = np.stack([sosfilt(hp, fx[:, c]) for c in range(2)], axis=1)
    mu_hp = np.stack([sosfilt(hp, music_eff[:, c]) for c in range(2)], axis=1)
    _, fx_mh = lufs_series(fx_hp, sr, 0.4, 0.1)
    _, mu_mh = lufs_series(mu_hp, sr, 0.4, 0.1)
    active = fx_m > -45
    ratio = fx_m - mu_m
    ratio_hp = fx_mh - mu_mh
    buried = active & (ratio <= BURIED_DB)
    risk = active & (ratio > BURIED_DB) & (ratio < AT_RISK_DB)
    buried_hp = active & (ratio_hp <= BURIED_DB)
    # which cues sound inside buried windows
    buried_cues = Counter()
    for i in np.where(buried | buried_hp)[0]:
        c0 = mt[i] - 0.2
        for t0, cn in zip(cue_a, cue_n):
            if c0 - 0.05 <= t0 <= c0 + 0.4: buried_cues[cn] += 1
    # --- low-frequency share: per source file and in the mix
    low_rows = []
    for cue, c in MAN["cues"].items():
        for res in c["files"]:
            s, y = read(ROOT / res[len("res://"):])
            y = y[:, 0]
            spec = np.abs(np.fft.rfft(y)) ** 2
            f = np.fft.rfftfreq(len(y), 1 / s)
            low = float(spec[f < 300].sum() / max(spec.sum(), 1e-12))
            yh = sosfilt(butter(4, 300, "highpass", fs=s, output="sos"), y)
            loss = db(float(np.sqrt(np.mean(y ** 2)))) - db(float(np.sqrt(np.mean(yh ** 2))))
            low_rows.append((Path(res).name, cue, low, loss))
    for mid, m in MAN["music"].items():
        p = ROOT / m["file"][len("res://"):]
        raw = subprocess.run([shutil.which("ffmpeg"), "-v", "error", "-i", str(p), "-f", "f32le", "-ac", "1", "-ar", "22050", "-"],
                             capture_output=True).stdout
        y = np.frombuffer(raw, "<f4").astype(np.float64)
        spec = np.abs(np.fft.rfft(y)) ** 2
        f = np.fft.rfftfreq(len(y), 1 / 22050)
        yh = sosfilt(butter(4, 300, "highpass", fs=22050, output="sos"), y)
        low_rows.append((p.name, mid, float(spec[f < 300].sum() / spec.sum()),
                         db(float(np.sqrt(np.mean(y ** 2)))) - db(float(np.sqrt(np.mean(yh ** 2))))))
    mono_m = master.mean(axis=1)
    mix_loss = db(float(np.sqrt(np.mean(mono_m ** 2)))) - db(float(np.sqrt(np.mean(sosfilt(hp, mono_m) ** 2))))
    # --- repetition / fatigue from the cue log (file-level: hit_melee has 3 variants, others 1)
    by_cue = defaultdict(list)
    for t0, cn in zip(cue_t, cue_n): by_cue[cn].append(t0)
    rep_rows = []
    for cn, tl in by_cue.items():
        tl = np.array(sorted(tl))
        w1 = max(int(np.sum((tl >= a) & (tl < a + 1.0))) for a in tl)
        w10 = max(int(np.sum((tl >= a) & (tl < a + 10.0))) for a in tl)
        ioi = np.diff(tl)
        nvar = len(MAN["cues"].get(cn, {}).get("files", [1]))
        rep_rows.append({"cue": cn, "n": len(tl), "per_min": len(tl) / wall * 60, "max_1s": w1, "max_10s": w10,
                         "per_file_10s": w10 / nvar, "median_ioi": float(np.median(ioi)) if len(ioi) else None,
                         "ioi_lt_150ms": int(np.sum(ioi < 0.15)), "variants": nvar,
                         "pitch_jitter": MAN["cues"].get(cn, {}).get("pitch", 0), "gap": MAN["cues"].get(cn, {}).get("gap", 0)})
    rep_rows.sort(key=lambda r: -r["n"])
    fatigue = [r for r in rep_rows if r["max_1s"] > REPEAT_RATE_HZ or r["per_file_10s"] > REPEAT_10S]
    # --- 30 s preview: window with the most distinct cues (ties -> more cues), whole seconds
    best_w, best_score = 0.0, (-1, -1)
    for a in np.arange(0.0, max(0.0, dur - 30.0) + 0.001, 1.0):
        names = [cn for t0, cn in zip(cue_a, cue_n) if a <= t0 < a + 30]
        sc = (len(set(names)), len(names))
        if sc > best_score: best_w, best_score = float(a), sc
    summary_early = None
    if NO_PUBLISH:
        print(json.dumps({"integrated_lufs": round(il, 1), "peak_dbfs": round(db(pk), 2), "clipped": clipped,
                          "active": int(active.sum()), "buried": int(buried.sum()), "at_risk": int(risk.sum()),
                          "buried_hp300": int(buried_hp.sum()), "seconds_audio": round(dur, 2), "seconds_wall": round(wall, 2),
                          "cue_counts": {k: len(v) for k, v in by_cue.items()},
                          "top_repeat": {r["cue"]: {"per_min": round(r["per_min"], 1), "max_1s": r["max_1s"], "gaps_lt_150ms": r["ioi_lt_150ms"]} for r in rep_rows[:3]},
                          "fatigue": [r["cue"] for r in fatigue], "best_window": best_w}))
        return 0
    LISTEN.mkdir(parents=True, exist_ok=True)
    (LISTEN / ".gdignore").write_text("", encoding="utf-8")
    shutil.copyfile(REC / "rec_master.wav", LISTEN / "battle_mix_60s.wav")
    ff = shutil.which("ffmpeg")
    mp3 = LISTEN / "battle_preview_30s.mp3"
    subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{best_w:.3f}", "-t", "30", "-i", str(REC / "rec_master.wav"),
                    "-af", "afade=t=in:d=0.3,afade=t=out:st=29.7:d=0.3", "-map_metadata", "-1", "-c:a", "libmp3lame", "-b:a", "192k", str(mp3)], check=True)
    # --- chart
    fig, ax = plt.subplots(3, 1, figsize=(14, 8), sharex=True)
    ax[0].plot(st_t, st_v, label="Master short-term (3 s) LUFS")
    ax[0].plot(mt, fx_m, lw=0.5, alpha=0.6, label="SFX+UI momentary")
    ax[0].plot(mt, mu_m, lw=0.8, label="Music (after bus gain/duck) momentary")
    ax[0].set_ylim(-50, 0); ax[0].legend(fontsize=7, loc="lower right"); ax[0].set_ylabel("LUFS")
    ax[1].plot(mt, np.where(active, ratio, np.nan), lw=0.7, label="SFX − music (full band)")
    ax[1].plot(mt, np.where(active, ratio_hp, np.nan), lw=0.7, label="SFX − music (≥300 Hz, phone-speaker proxy)")
    ax[1].axhline(0, color="r", lw=0.6); ax[1].axhline(AT_RISK_DB, color="orange", lw=0.6, ls="--")
    ax[1].legend(fontsize=7); ax[1].set_ylabel("dB")
    for i, cn in enumerate(sorted(set(cue_n))):
        tt = [t0 for t0, c in zip(cue_a, cue_n) if c == cn]
        ax[2].scatter(tt, [i] * len(tt), s=6)
    ax[2].set_yticks(range(len(set(cue_n)))); ax[2].set_yticklabels(sorted(set(cue_n)), fontsize=6)
    ax[2].axvspan(best_w, best_w + 30, color="green", alpha=0.08)
    ax[2].set_xlabel("seconds (audio clock); green = 30 s preview window")
    fig.suptitle(f"Real-mix battle recording r02 — integrated {il:.1f} LUFS, sample peak {db(pk):.2f} dBFS, true peak≈{db(tp):.2f} dBTP", fontsize=9)
    fig.tight_layout()
    fig.savefig(ROOT / "docs/audio/previews/mix_timeline.png", dpi=80)
    plt.close(fig)
    # --- report
    L = ["# MIX_REPORT.md — real-mix battle recording (generated by tools/audio/mix_report.py)", "",
         f"Source: `pwsh tools/audio/run_godot_checks.ps1 -Record` — real headless battle {meta['round']} with the project's Audio autoload, "
         f"02's `Events.sfx` emitters and a scripted player (sandbox AudioProbe). Engine mix via `AudioEffectRecord` on Master after the "
         f"{meta['limiter']} (driver: {meta['driver']}). Settings at defaults: music 0.8, sfx 1.0.",
         f"Length {dur:.2f} s of audio for {wall:.2f} s wall clock. Cue log aligned to audio by onset matching: {hits}/{len(cue_t)} cues within 40 ms "
         f"(offset {off:+.3f} s, scale {scale:.4f}).", "",
         "Files for listening: `previews/listen/battle_mix_60s.wav` (exact engine output, 16-bit 44.1 kHz stereo) and "
         f"`previews/listen/battle_preview_30s.mp3` ({best_w:.0f}–{best_w + 30:.0f} s, the 30 s with the most distinct cues: "
         f"{best_score[0]} kinds, {best_score[1]} cues; 0.3 s fades, no other processing). Chart: `previews/mix_timeline.png`.", "",
         "## 1. Level and clipping",
         f"- Integrated loudness (BS.1770 gated): **{il:.1f} LUFS**. Short-term (3 s) range {st_v.min():.1f} … {st_v.max():.1f} LUFS.",
         f"- Sample peak {db(pk):.2f} dBFS, true peak (4× oversampled) ≈ {db(tp):.2f} dBTP. Full-scale samples in the output: **{clipped}**.",
         f"- Samples of the reconstructed pre-limiter sum above the −0.5 dB limiter ceiling: {over} ({over / n / 2:.4%}) → limiter engagement "
         "(reconstruction from stems; approximate).",
         "- Reference only (not a requirement here): mobile platforms/streaming commonly target about −14 to −16 LUFS integrated for full programmes.",
         "", "## 2. SFX vs music (masking proxy, 400 ms windows where SFX+UI is active)",
         f"- Active windows: {int(active.sum())}. Buried (SFX ≤ music): **{int(buried.sum())}** ({buried.sum() / max(active.sum(), 1):.0%}); "
         f"at risk (< +{AT_RISK_DB:.0f} dB): {int(risk.sum())} ({risk.sum() / max(active.sum(), 1):.0%}).",
         f"- Same with both signals high-passed at 300 Hz (phone loudspeaker proxy): buried **{int(buried_hp.sum())}** "
         f"({buried_hp.sum() / max(active.sum(), 1):.0%}).",
         f"- Median SFX − music: {np.nanmedian(np.where(active, ratio, np.nan)):+.1f} dB full band, "
         f"{np.nanmedian(np.where(active, ratio_hp, np.nan)):+.1f} dB ≥300 Hz.",
         "- Cues sounding in buried windows: " + (", ".join(f"{k} ×{v}" for k, v in buried_cues.most_common()) or "none") + ".",
         "", "## 3. Low-frequency content (phone loudspeakers reproduce little below ~300 Hz)",
         f"- Whole battle mix: high-passing at 300 Hz removes {mix_loss:.1f} dB of RMS level.",
         f"- Flag: > {LOW_SHARE_FLAG:.0%} of a sound's energy below 300 Hz.", "",
         "| File | Cue | Energy < 300 Hz | RMS lost by 300 Hz HP | Flag |", "|---|---|---|---|---|"]
    for name, cue, low, loss in sorted(low_rows, key=lambda r: -r[2]):
        L.append(f"| {name} | {cue} | {low:.0%} | {loss:.1f} dB | {'LOW-HEAVY' if low > LOW_SHARE_FLAG else ''} |")
    L += ["", "## 4. Repetition / fatigue (from the cue log; internal heuristics, not a standard)",
          f"Flag if a cue exceeds {REPEAT_RATE_HZ:.0f} onsets in any 1 s, or more than {REPEAT_10S} plays of the same file in any 10 s. "
          "Pitch jitter and variants reduce identical repeats but are listed so a listener can judge.", "",
          "| Cue | plays | per min | max in 1 s | max in 10 s | per file /10 s | median gap s | gaps < 150 ms | variants | pitch ± | min gap s |",
          "|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in rep_rows:
        L.append(f"| {r['cue']} | {r['n']} | {r['per_min']:.0f} | {r['max_1s']} | {r['max_10s']} | {r['per_file_10s']:.1f} | "
                 f"{r['median_ioi']:.2f} | {r['ioi_lt_150ms']} | {r['variants']} | {r['pitch_jitter']} | {r['gap']} |" if r['median_ioi'] is not None else
                 f"| {r['cue']} | {r['n']} | {r['per_min']:.0f} | {r['max_1s']} | {r['max_10s']} | {r['per_file_10s']:.1f} | – | 0 | {r['variants']} | {r['pitch_jitter']} | {r['gap']} |")
    L += ["", "Fatigue flags: " + (", ".join(f"{r['cue']} (max {r['max_1s']}/s, {r['per_file_10s']:.0f} per file per 10 s)" for r in fatigue) or "none") + ".",
          "", "## 5. Limits",
          "- Headless Dummy driver mix: same AudioServer mixing code path as devices, but no device output stage, OS mixer, speaker EQ or latency.",
          "- One scripted battle (one round, one seed policy); busier late rounds may differ.",
          "- Masking is a loudness proxy (no psychoacoustic model). Nobody has listened yet; the preview file exists for that."]
    label = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--label=")), "latest")
    hist_p = ROOT / "docs/audio/mix_history.json"
    hist = json.loads(hist_p.read_text(encoding="utf-8")) if hist_p.exists() else {}
    hist[label] = {"integrated_lufs": round(il, 1), "peak_dbfs": round(db(pk), 2), "clipped": clipped,
                   "buried_pct": round(100 * buried.sum() / max(active.sum(), 1), 1),
                   "at_risk_pct": round(100 * risk.sum() / max(active.sum(), 1), 1),
                   "buried_hp300_pct": round(100 * buried_hp.sum() / max(active.sum(), 1), 1),
                   "median_sfx_minus_music_db": round(float(np.nanmedian(np.where(active, ratio, np.nan))), 1),
                   "mix_hp300_loss_db": round(mix_loss, 1),
                   "low_heavy": [r[0] for r in low_rows if r[2] > LOW_SHARE_FLAG],
                   "fatigue": [r["cue"] for r in fatigue],
                   "top_repeat": {r["cue"]: {"per_min": round(r["per_min"]), "max_1s": r["max_1s"], "gaps_lt_150ms": r["ioi_lt_150ms"]} for r in rep_rows[:2]},
                   "disk_bytes": sum(p.stat().st_size for p in (ROOT / "assets/audio").rglob("*") if p.suffix in (".wav", ".ogg")),
                   "align": f"{hits}/{len(cue_t)}"}
    hist_p.write_text(json.dumps(hist, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    L += ["", "## 6. History (same harness, same round/policy; one run each)", "",
          "| Version | Integrated LUFS | Peak dBFS | Clipped | Buried % | At risk % | Buried ≥300 Hz % | Median SFX−music dB | Mix lost by 300 Hz HP dB | Low-heavy | Fatigue flags | Audio disk B |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for k, h in hist.items():
        L.append(f"| {k} | {h['integrated_lufs']} | {h['peak_dbfs']} | {h['clipped']} | {h['buried_pct']} | {h['at_risk_pct']} | {h['buried_hp300_pct']} | "
                 f"{h['median_sfx_minus_music_db']} | {h['mix_hp300_loss_db']} | {', '.join(h['low_heavy']) or 'none'} | {', '.join(h['fatigue']) or 'none'} | {h.get('disk_bytes', '')} |")
    out = ROOT / "docs/audio/MIX_REPORT.md"
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    summary = {"integrated_lufs": round(il, 1), "peak_dbfs": round(db(pk), 2), "true_peak_dbtp": round(db(tp), 2), "clipped": clipped,
               "limiter_over_samples": over, "active": int(active.sum()), "buried": int(buried.sum()), "at_risk": int(risk.sum()),
               "buried_hp300": int(buried_hp.sum()), "align_hits": f"{hits}/{len(cue_t)}", "preview_window": best_w,
               "fatigue": [r["cue"] for r in fatigue], "low_heavy": [r[0] for r in low_rows if r[2] > LOW_SHARE_FLAG]}
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
