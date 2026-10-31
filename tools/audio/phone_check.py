#!/usr/bin/env python3
"""Phone-speaker condition check (05-audio, v3.5). Offline, Python only.

Condition "phone": 4th-order high-pass at 300 Hz (small loudspeakers reproduce little below ~300 Hz) and the
whole output 6 dB quieter. Two questions per important cue:
  1. Does it still stick out of a real battle? The cue file (at its manifest vol_db, with its music duck) is
     placed at 57 positions (every 1 s) over the REAL background of an engine recording (music stem with the
     recorded bus gain + the SFX stem = all other battle sounds). SNR = cue loudness - background loudness in
     the cue's own window, both K-weighted (BS.1770 filter) after the phone filter. masked: SNR < 0 dB,
     at risk: < 3 dB.
  2. Is it still loud enough at -6 dB? Absolute max momentary (400 ms) loudness after the phone filter and
     -6 dB; flag below -40 LUFS (internal heuristic, not a standard).
Faction readability: leave-one-out nearest-centroid classification of the 3 hit_bread + 3 hit_mold variants
using octave-band energy profiles (315 Hz - 8 kHz) and an envelope "graininess" feature, full band vs phone.
These are proxies; they do not replace listening on a real phone.
Usage: python tools/audio/phone_check.py [--rec=tools/audio/_render/recording] [--label=v3.5] [--report=docs/audio/PHONE_SPEAKER_CHECK.md]
       [--history=docs/audio/phone_check_history.json]
"""
from __future__ import annotations

import json
import math
import sys
import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

sys.path.insert(0, str(Path(__file__).resolve().parent))
from preview import k_weight  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in sys.argv[1:] if "=" in a}
REC = ROOT / ARGS.get("--rec", "tools/audio/_render/recording")
LABEL = ARGS.get("--label", "latest")
REPORT = ROOT / ARGS.get("--report", "docs/audio/PHONE_SPEAKER_CHECK.md")
# v3.8: --history=<json> keeps a run family (e.g. 9 anomaly-check recordings) out of the main history/report
HISTORY = ROOT / ARGS.get("--history", "docs/audio/phone_check_history.json")
MAN = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))
SR = 22050
HP = butter(4, 300, "highpass", fs=SR, output="sos")
GAIN_PHONE = 10 ** (-6 / 20)
TARGETS = ["hit_bread", "hit_mold", "death_ally", "death_enemy", "deploy", "skill_slam", "skill_rally", "skill_barrage",
           "skill_heal", "wave_incoming", "boss_incoming", "wave_cleared", "ui_confirm", "ui_error", "hit_base", "hit_base_mold"]
QUIET_LUFS = -40.0


def read_wav(p: Path, sr_out: int = SR) -> np.ndarray:
    with wave.open(str(p), "rb") as w:
        sr, ch = w.getframerate(), w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
    x = x.reshape(-1, ch).mean(axis=1)
    if sr != sr_out:
        from scipy.signal import resample_poly
        g = math.gcd(sr, sr_out)
        x = resample_poly(x, sr_out // g, sr // g)
    return x


def phone(x: np.ndarray) -> np.ndarray:
    return sosfilt(HP, x) * GAIN_PHONE


def lufs_max(x: np.ndarray, win: float = 0.4) -> float:
    y = k_weight(x, SR) ** 2
    n = int(win * SR)
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    c = np.convolve(y, np.ones(n) / n, mode="valid")
    return -0.691 + 10 * math.log10(max(float(c.max()), 1e-12))


def lufs_mean(x: np.ndarray) -> float:
    return -0.691 + 10 * math.log10(max(float(np.mean(k_weight(x, SR) ** 2)), 1e-12))


def features(x: np.ndarray) -> np.ndarray:
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1 / SR)
    bands = [315 * 2 ** k for k in range(6)]          # 315 .. 10080 Hz edges
    prof = np.array([spec[(f >= lo) & (f < lo * 2)].sum() for lo in bands[:-1]])
    prof = prof / max(prof.sum(), 1e-12)
    env = np.abs(x)
    m = int(0.003 * SR)
    sm = np.convolve(env, np.ones(m) / m, mode="same")
    grain = float(np.std(np.diff(sm)) / max(np.mean(sm), 1e-9))   # crunchy grains -> large, smooth squish -> small
    return np.concatenate([prof, [min(grain, 5.0) / 5.0]])


def loo_accuracy(items):
    ok = 0
    for i, (lab, v) in enumerate(items):
        rest = [it for j, it in enumerate(items) if j != i]
        cents = {l: np.mean([w for (ll, w) in rest if ll == l], axis=0) for l in {"bread", "mold"}}
        pred = min(cents, key=lambda l: np.linalg.norm(v - cents[l]))
        ok += pred == lab
    return ok / len(items)


def main() -> int:
    meta = json.loads((REC / "rec_meta.json").read_text(encoding="utf-8"))
    music = read_wav(REC / "rec_music.wav")
    sfx = read_wav(REC / "rec_sfx.wav")
    ui = read_wav(REC / "rec_ui.wav")
    n = min(len(music), len(sfx), len(ui))
    music, sfx, ui = music[:n], sfx[:n], ui[:n]
    scale = (n / SR) / float(meta["seconds"])
    g = np.array([[x[0] * scale, x[1]] for x in meta["music_gain"]])
    mgain = 10 ** (np.interp(np.arange(n) / SR, g[:, 0], g[:, 1]) / 20)
    music_eff = music * mgain
    bg_music_ph = phone(music_eff)
    bg_other_ph = phone(sfx + ui)
    rows = []
    for cue in TARGETS:
        c = MAN["cues"].get(cue)
        if not c:
            continue
        x = read_wav(ROOT / c["files"][0][len("res://"):]) * 10 ** (float(c["vol_db"]) / 20)
        xph = phone(x)
        duck = 10 ** (float(c.get("duck", 0)) / 20)
        # v3.7: model the runtime danger-cue SFX duck (manifest duck_sfx): lower-priority battle SFX are lowered while
        # the cue sounds. The recorded "other SFX" stem also holds higher-priority cues, so this slightly overstates it.
        sduck = 10 ** (float(c.get("duck_sfx", 0)) / 20)
        L = len(x)
        # SNR over the cue's OWN loud frames only (50 ms frames within 15 dB of its loudest frame), so sparse cues
        # (barrage: whistle then impacts) are not penalised for their gaps.
        fr = int(0.05 * SR)
        kc = k_weight(np.pad(xph, (0, fr)), SR) ** 2
        nf = max(1, L // fr)
        ce = np.array([kc[i * fr:(i + 1) * fr].mean() for i in range(nf)])
        loud = ce >= ce.max() * 10 ** (-15 / 10)
        snrs = []
        for t0 in np.arange(2.0, (n - L) / SR - 1.0, 1.0):
            a = int(t0 * SR)
            bg = bg_music_ph[a:a + L] * duck + bg_other_ph[a:a + L] * sduck
            kb = k_weight(np.pad(bg, (0, fr)), SR) ** 2
            be = np.array([kb[i * fr:(i + 1) * fr].mean() for i in range(nf)])
            d = 10 * np.log10(np.maximum(ce[loud], 1e-14)) - 10 * np.log10(np.maximum(be[loud], 1e-14))
            snrs.append(float(np.median(d)))
        snrs = np.array(snrs)
        rows.append({"cue": cue, "bus": c["bus"], "vol_db": c["vol_db"], "duck": c.get("duck", 0),
                     "snr_median": round(float(np.median(snrs)), 1), "snr_p10": round(float(np.percentile(snrs, 10)), 1),
                     "masked_pct": round(100 * float(np.mean(snrs < 0)), 1), "risk_pct": round(100 * float(np.mean(snrs < 3)), 1),
                     "abs_lufs_phone": round(lufs_max(xph), 1), "abs_lufs_full": round(lufs_max(x), 1), "positions": len(snrs)})
    # faction readability
    items_full, items_ph = [], []
    for lab, cue in (("bread", "hit_bread"), ("mold", "hit_mold")):
        for f in MAN["cues"][cue]["files"]:
            x = read_wav(ROOT / f[len("res://"):])
            items_full.append((lab, features(x)))
            items_ph.append((lab, features(phone(x))))
    acc_full, acc_ph = loo_accuracy(items_full), loo_accuracy(items_ph)
    cb = np.mean([v for l, v in items_ph if l == "bread"], axis=0)
    cm = np.mean([v for l, v in items_ph if l == "mold"], axis=0)
    spread = np.mean([np.linalg.norm(v - (cb if l == "bread" else cm)) for l, v in items_ph])
    sep = float(np.linalg.norm(cb - cm) / max(spread, 1e-9))
    out = {"label": LABEL, "rec": str(REC.relative_to(ROOT)).replace("\\", "/"), "rows": rows,
           "faction_loo_accuracy_full": acc_full, "faction_loo_accuracy_phone": acc_ph, "faction_separation_phone": round(sep, 2),
           "grain_bread_phone": round(float(cb[-1] * 5), 2), "grain_mold_phone": round(float(cm[-1] * 5), 2)}
    hist_p = HISTORY
    hist = json.loads(hist_p.read_text(encoding="utf-8")) if hist_p.exists() else {}
    hist[LABEL] = out
    hist_p.write_text(json.dumps(hist, indent=1) + "\n", encoding="utf-8")
    # keep the hand-written preamble (criteria, baselines) above the marker; regenerate only below it
    MARK = "<!-- generated below by tools/audio/phone_check.py -->"
    pre = ""
    if REPORT.exists():
        old = REPORT.read_text(encoding="utf-8")
        if MARK in old:
            pre = old.split(MARK)[0]
    L = [pre.rstrip("\n") + "\n\n" + MARK if pre else "# PHONE_SPEAKER_CHECK.md — phone-speaker condition (generated by tools/audio/phone_check.py)\n\n" + MARK, "",
         "Condition: 300 Hz 4th-order high-pass + the whole output −6 dB. Background = a real engine battle recording "
         f"(`{out['rec']}`: music stem at its recorded bus gain + all other SFX/UI). Each cue (manifest vol_db, own music duck) is "
         "placed at 1 s steps over that background; SNR = median over the cue's own loud 50 ms frames (within 15 dB of its peak frame) of K-weighted cue minus background, "
         f"both after the phone filter. masked = SNR < 0 dB, at risk = < 3 dB. Too quiet = max momentary < {QUIET_LUFS:.0f} LUFS after "
         "filter and −6 dB (internal heuristic). Proxies only; nobody has listened on a phone.", ""]
    for lab in hist:
        h = hist[lab]
        L += [f"## {lab}", "", "| Cue | Bus | vol_db | duck | SNR median dB | SNR p10 dB | masked % | at risk % | phone −6 dB LUFS | flags |",
              "|---|---|---|---|---|---|---|---|---|---|"]
        for r in h["rows"]:
            fl = []
            if r["masked_pct"] > 25: fl.append("MASKED")
            elif r["risk_pct"] > 50: fl.append("at risk")
            if r["abs_lufs_phone"] < QUIET_LUFS: fl.append("too quiet")
            L.append(f"| {r['cue']} | {r['bus']} | {r['vol_db']} | {r['duck']} | {r['snr_median']} | {r['snr_p10']} | {r['masked_pct']} | "
                     f"{r['risk_pct']} | {r['abs_lufs_phone']} | {', '.join(fl)} |")
        L += ["", f"Faction hits (3 bread vs 3 mold variants), leave-one-out nearest-centroid accuracy: full band "
              f"{h['faction_loo_accuracy_full']:.0%}, phone {h['faction_loo_accuracy_phone']:.0%}; centroid separation / spread "
              f"{h['faction_separation_phone']} (> 1 = groups apart); envelope graininess bread {h['grain_bread_phone']} vs mold "
              f"{h['grain_mold_phone']}.", ""]
    REPORT.write_text("\n".join(L).rstrip("\n") + "\n", encoding="utf-8")   # no blank line at EOF (git diff --check)
    for r in rows:
        print(f"{r['cue']:15s} snr_med {r['snr_median']:6.1f} p10 {r['snr_p10']:6.1f} masked {r['masked_pct']:5.1f}% risk {r['risk_pct']:5.1f}% phoneLUFS {r['abs_lufs_phone']}")
    print("faction LOO full", acc_full, "phone", acc_ph, "sep", round(sep, 2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
