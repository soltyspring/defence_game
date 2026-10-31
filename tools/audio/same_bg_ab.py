#!/usr/bin/env python3
"""Same-background A/B for the v3.7 change (05-audio). Offline, Python only.

Question: did the v3.7 change (new death_ally recipe + danger-cue SFX duck) itself make other cues
(wave_cleared, hit_base_mold) more masked, or did the battles just differ?
Method: for each BEFORE recording (tools/audio/_render/recording_base_s11/s23/s37) the battle's SFX/UI
background is RE-RENDERED from its own cue log (every logged cue file placed at its logged time at its
manifest vol_db), twice:
  A = assets + manifest of the BEFORE commit (default 131dcf2), with that build's own duck rules (none before v3.7)
  B = assets + manifest of the working tree (v3.7 or later): new files, and the runtime duck rule applied
      (a cue with duck_sfx lowers SFX cues with prio < duck_sfx_below that are sounding or start while it sounds).
The music stem is the real recorded one with its recorded bus gain (the change does not touch music).
The event timeline is identical in A and B, so any difference comes from the change only.
Then every target cue is placed at 1 s steps exactly as tools/audio/phone_check.py does (300 Hz HP, -6 dB,
SNR median over the cue's own loud 50 ms frames) and masked % / p10 are compared A vs B.
Limits: offscreen attenuation and pitch jitter are not in the cue log, so the re-rendered background differs from
the recording; the same simplification applies to A and B. The sanity line reports how closely the A render
follows the recorded SFX stem (correlation of 400 ms loudness envelopes).
Usage: python tools/audio/same_bg_ab.py [--before=131dcf2] [--targets=wave_cleared,hit_base_mold,death_ally,hit_base]
v3.8 additions: --tag=rb --rounds=r02,r06,r08 reads tools/audio/_render/recording_<tag>_<round>_s<seed> instead of
recording_base_s<seed>. B now models the v3.8 runtime: extra variant files (cycled k % n, which is a valid
non-repeating order like the runtime's random pick) and vol_jitter (seeded uniform +-vol_jitter dB per play).
A target cue with several files is measured per file; the reported row is the WORST file (highest masked %).
"""
from __future__ import annotations

import io
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import phone_check as P  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in sys.argv[1:] if "=" in a}
BEFORE = ARGS.get("--before", "131dcf2")
TARGETS = ARGS.get("--targets", ",".join(P.TARGETS)).split(",")
SEEDS = [int(s) for s in ARGS.get("--seeds", "11,23,37").split(",")]
OUT = ROOT / ARGS.get("--out", "tools/audio/_render/same_bg_ab.json")
# r02 battles have no player-base hits in 60 s, so the hit_base duck never fires there. --inject-hit-base-every=N adds a
# synthetic hit_base every N s to BOTH A and B (same timeline) to test the hit_base duck against the other cues.
INJECT_HB = float(ARGS.get("--inject-hit-base-every", "0"))
TAG = ARGS.get("--tag", "")
ROUNDS = ARGS.get("--rounds", "r02").split(",")
SR = P.SR


def rec_dirs() -> list[tuple[str, Path]]:
    if not TAG:
        return [(f"s{sd}", ROOT / f"tools/audio/_render/recording_base_s{sd}") for sd in SEEDS]
    return [(f"{r}_s{sd}", ROOT / f"tools/audio/_render/recording_{TAG}_{r}_s{sd}") for r in ROUNDS for sd in SEEDS]


def wav_from_bytes(b: bytes) -> np.ndarray:
    with wave.open(io.BytesIO(b), "rb") as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
        assert w.getframerate() == SR and w.getnchannels() == 1
    return x


class AssetSet:
    def __init__(self, rev: str | None):
        self.rev = rev
        if rev:
            self.man = json.loads(subprocess.run(["git", "show", f"{rev}:assets/audio/audio_manifest.json"],
                                                 capture_output=True, check=True, cwd=ROOT).stdout)
        else:
            self.man = P.MAN
        self._cache: dict[str, np.ndarray] = {}

    def file(self, res: str) -> np.ndarray:
        if res not in self._cache:
            rel = res[len("res://"):]
            if self.rev:
                b = subprocess.run(["git", "show", f"{self.rev}:{rel}"], capture_output=True, check=True, cwd=ROOT).stdout
                self._cache[res] = wav_from_bytes(b)
            else:
                self._cache[res] = P.read_wav(ROOT / rel)
        return self._cache[res]

    def cue_signal(self, cue: str, k: int) -> np.ndarray | None:
        c = self.man["cues"].get(cue)
        if not c or c["bus"] == "Music":
            return None
        files = c["files"]
        return self.file(files[k % len(files)]) * 10 ** (float(c["vol_db"]) / 20)


def render_bg(assets: AssetSet, events, n: int, with_duck: bool, jitter_seed: int | None = None) -> np.ndarray:
    """events: list of (t_audio_s, cue). Returns the re-rendered SFX+UI background (mono, SR).
    jitter_seed: apply the manifest's vol_jitter (uniform +-dB per play, like AudioManager.play) with this seed."""
    man = assets.man["cues"]
    out = np.zeros(n)
    count: dict[str, int] = {}
    placed = []   # (start, end, cue, prio, signal)
    rng = np.random.default_rng(jitter_seed) if jitter_seed is not None else None
    for t, cue in events:
        k = count.get(cue, 0)
        count[cue] = k + 1
        s = assets.cue_signal(cue, k)
        if s is None:
            continue
        a = int(t * SR)
        if a >= n:
            continue
        vj = float(man[cue].get("vol_jitter", 0.0))
        if rng is not None and vj > 0.0:
            s = s * 10 ** (rng.uniform(-vj, vj) / 20)
        placed.append([a, min(n, a + len(s)), cue, int(man[cue].get("prio", 1)), s.copy()])
    if with_duck:
        ducks = [(a, e, float(man[c].get("duck_sfx", 0.0)), int(man[c].get("duck_sfx_below", 0)))
                 for a, e, c, _p, _s in placed if float(man[c].get("duck_sfx", 0.0)) < 0.0]
        for item in placed:
            a, e, c, prio, s = item
            for da, de, ddb, below in ducks:
                if prio >= below or (da, de) == (a, e):
                    continue
                lo, hi = max(a, da), min(e, de)
                if hi > lo:   # runtime: the whole remaining voice / the new voice is lowered (not just the overlap)
                    start = 0 if a >= da else lo - a
                    s[start:] *= 10 ** (ddb / 20)
    for a, e, _c, _p, s in placed:
        out[a:e] += s[: e - a]
    return out


def snr_stats(cue_sig: np.ndarray, bg_music: np.ndarray, bg_other: np.ndarray, cue_entry: dict):
    xph = P.phone(cue_sig)
    L = len(cue_sig)
    duck = 10 ** (float(cue_entry.get("duck", 0)) / 20)
    sduck = 10 ** (float(cue_entry.get("duck_sfx", 0)) / 20)
    fr = int(0.05 * SR)
    kc = P.k_weight(np.pad(xph, (0, fr)), SR) ** 2
    nf = max(1, L // fr)
    ce = np.array([kc[i * fr:(i + 1) * fr].mean() for i in range(nf)])
    loud = ce >= ce.max() * 10 ** (-15 / 10)
    n = len(bg_music)
    snrs = []
    for t0 in np.arange(2.0, (n - L) / SR - 1.0, 1.0):
        a = int(t0 * SR)
        bg = bg_music[a:a + L] * duck + bg_other[a:a + L] * sduck
        kb = P.k_weight(np.pad(bg, (0, fr)), SR) ** 2
        be = np.array([kb[i * fr:(i + 1) * fr].mean() for i in range(nf)])
        snrs.append(float(np.median(10 * np.log10(np.maximum(ce[loud], 1e-14)) - 10 * np.log10(np.maximum(be[loud], 1e-14)))))
    s = np.array(snrs)
    return {"masked_pct": round(100 * float(np.mean(s < 0)), 1), "p10": round(float(np.percentile(s, 10)), 1),
            "median": round(float(np.median(s)), 1), "positions": len(s)}


def envelope(x: np.ndarray) -> np.ndarray:
    n = int(0.4 * SR)
    k = P.k_weight(x, SR) ** 2
    return np.array([10 * np.log10(max(k[i:i + n].mean(), 1e-12)) for i in range(0, len(k) - n, n)])


def worst_file_stats(assets: AssetSet, cue: str, bm, bg, entry: dict) -> dict:
    """SNR stats per file of the cue; returns the worst file (highest masked %, then lowest p10) and the file count."""
    c = assets.man["cues"][cue]
    rows = []
    for f in c["files"]:
        r = snr_stats(assets.file(f) * 10 ** (float(c["vol_db"]) / 20), bm, bg, entry)
        r["file"] = f.rsplit("/", 1)[-1]
        rows.append(r)
    w = max(rows, key=lambda r: (r["masked_pct"], -r["p10"]))
    return dict(w, files=len(rows))


def main() -> int:
    A = AssetSet(BEFORE)
    B = AssetSet(None)
    res = {"before_rev": BEFORE, "tag": TAG or "base", "targets": TARGETS, "seeds": {}}
    for idx, (key, d) in enumerate(rec_dirs()):
        meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
        mu = P.read_wav(d / "rec_music.wav")
        sf = P.read_wav(d / "rec_sfx.wav")
        ui = P.read_wav(d / "rec_ui.wav")
        n = min(len(mu), len(sf), len(ui))
        mu, sf, ui = mu[:n], sf[:n], ui[:n]
        scale = (n / SR) / float(meta["seconds"])
        g = np.array([[q[0] * scale, q[1]] for q in meta["music_gain"]])
        bm = P.phone(mu * 10 ** (np.interp(np.arange(n) / SR, g[:, 0], g[:, 1]) / 20))
        events = [(q[0] * scale, q[1]) for q in meta["cues"]]
        if INJECT_HB > 0:
            events = sorted(events + [(t, "hit_base") for t in np.arange(3.0, n / SR - 1.0, INJECT_HB)])
        bgA = render_bg(A, events, n, with_duck=True)   # ducks only where A's manifest has duck_sfx
        bgB = render_bg(B, events, n, with_duck=True, jitter_seed=1000 + idx)
        ea, er = envelope(bgA), envelope(sf + ui)
        m = min(len(ea), len(er))
        corr = float(np.corrcoef(ea[:m], er[:m])[0, 1])
        bApH, bBpH = P.phone(bgA), P.phone(bgB)
        mus_full = mu * 10 ** (np.interp(np.arange(n) / SR, g[:, 0], g[:, 1]) / 20)
        mixA, mixB = mus_full + bgA, mus_full + bgB
        mix_ab = {"A_lufs": round(P.lufs_mean(mixA), 2), "B_lufs": round(P.lufs_mean(mixB), 2),
                  "A_peak_dbfs": round(float(20 * np.log10(max(np.abs(mixA).max(), 1e-9))), 2), "B_peak_dbfs": round(float(20 * np.log10(max(np.abs(mixB).max(), 1e-9))), 2)}
        row = {"render_vs_recorded_envelope_corr": round(corr, 3),
               "bg_loudness_A_lufs": round(P.lufs_mean(bApH), 2), "bg_loudness_B_lufs": round(P.lufs_mean(bBpH), 2),
               "danger_events": sum(1 for _t, c in events if c in ("death_ally", "hit_base")), "mix": mix_ab, "cues": {}}
        for cue in TARGETS:
            ca, cb = A.man["cues"][cue], B.man["cues"][cue]
            # each side uses its own manifest: a duck rule exists only if that build had it (131dcf2: none; 64a95c6+: v3.7 duck)
            ra = worst_file_stats(A, cue, bm, bApH, ca)
            rb = worst_file_stats(B, cue, bm, bBpH, cb)
            row["cues"][cue] = {"A": ra, "B": rb, "diff_masked_pts": round(rb["masked_pct"] - ra["masked_pct"], 1)}
        res["seeds"][key] = row
        print(f"{key}: render/recorded envelope corr {corr:.3f}, bg A {row['bg_loudness_A_lufs']} vs B {row['bg_loudness_B_lufs']} LUFS, danger events {row['danger_events']}, mix {mix_ab}")
        for cue in TARGETS:
            r = row["cues"][cue]
            print(f"   {cue:14s} A masked {r['A']['masked_pct']:5.1f}% p10 {r['A']['p10']:5.1f} ({r['A']['files']}f) | B masked {r['B']['masked_pct']:5.1f}% p10 {r['B']['p10']:5.1f} ({r['B']['files']}f) | diff {r['diff_masked_pts']:+.1f} pts")
    OUT.write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
