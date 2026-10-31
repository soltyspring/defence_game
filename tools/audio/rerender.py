#!/usr/bin/env python3
"""Faithful re-render of a recorded battle's SFX bus from its v3.9 cue log, and checks against the recording.
Owner: 05-audio. Python only (numpy/scipy); no Godot.

Why (docs/audio/ONSET_PEAK_CHECK.md): the v3.8 tools placed cues at the cue log's WALL time times a linear scale.
Godot starts a voice at the next mix block, and the headless Dummy driver mixes 4096-frame blocks (92.9 ms) while
falling behind the wall clock, so several cues 30-90 ms apart in wall time really started on ONE sample. A 5-cue
cluster peaked at -0.60 dBFS in the stem but -3.6 dBFS in the old re-render. Log format 2 (integration_probe.gd
v3.9) records the audio-clock start of every cue, its voice, the parts of its volume, and every duck / onset-cluster
change of an earlier voice, so the SFX bus can be rebuilt at the recording's mix rate.

Model: each logged SFX cue = its logged file variant, resampled for its logged pitch (linear interpolation), at its
logged start volume, from sample round(t_audio * mix_rate). A later cue on the same voice cuts the earlier one.
Logged duck/cluster events lower the voice's current cue from their audio time. Not modelled: Godot's QOA decode and
cubic resampler, volume ramps inside a mix block. Off-screen attenuation, jitter and duck-at-start are in vol_db.
--rule=sim additionally simulates the onset-cluster limit (manifest onset_cluster) on a log recorded WITHOUT it,
using the wall time as the manager's clock; this is the "B" side of the same-background A/B.

Usage:
  python tools/audio/rerender.py --tag=pb [--rounds=r02,r06,r08] [--seeds=11,23,37] [--rule=log|sim] [--out=...json]
     -> per recording: stem vs render peak at the stem's 5 largest peaks (separate 0.5 s regions), envelope
        correlation, block size, onset clusters; with --rule=sim also the simulated after-peaks.
  python tools/audio/rerender.py --ab --tag=pb ...   -> same-background A/B (rule off vs simulated rule on):
        phone-condition masking of the phone_check.py targets (D1/D2/G2) and the pre-limiter mix peak (P1/G1).
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

ROOT = Path(__file__).resolve().parents[2]
ARGS = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in sys.argv[1:] if "=" in a}
TAG = ARGS.get("--tag", "pb")
ROUNDS = ARGS.get("--rounds", "r02,r06,r08").split(",")
SEEDS = [int(s) for s in ARGS.get("--seeds", "11,23,37").split(",")]
RULE = ARGS.get("--rule", "log")
AB = "--ab" in sys.argv
OUT = ROOT / ARGS.get("--out", f"tools/audio/_render/rerender_{TAG}{'_ab' if AB else ''}.json")
MAN_REV = ARGS.get("--manifest", "")   # git rev for the manifest/assets (default: working tree)
QOA = "--wav" not in sys.argv          # --wav: render from the source WAVs instead of Godot's imported QOA data


def read_wav_any(p: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(p), "rb") as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
        return x.reshape(-1, w.getnchannels()), w.getframerate()


class Assets:
    """File source. qoa=True (default for the working tree): the QOA data Godot imported and actually plays (decoded
    by tools/audio/qoa.py from the sandbox import, matched to the source by md5, cached in tools/audio/_render/qoa_cache).
    Falls back to the source WAV (counted in self.wav_fallback) when no matching import exists."""

    def __init__(self, rev: str = "", qoa: bool = True):
        self.rev = rev
        self.qoa = qoa and not rev
        self.wav_fallback: list[str] = []
        if rev:
            self.man = json.loads(subprocess.run(["git", "show", f"{rev}:assets/audio/audio_manifest.json"], capture_output=True,
                                                 check=True, cwd=ROOT).stdout)
        else:
            self.man = json.loads((ROOT / "assets/audio/audio_manifest.json").read_text(encoding="utf-8"))
        self.cues = self.man["cues"]
        self._f: dict[str, tuple[np.ndarray, int]] = {}

    def _qoa(self, wav: Path) -> np.ndarray | None:
        import hashlib
        import qoa as Q
        md5 = hashlib.md5(wav.read_bytes()).hexdigest()
        cache = ROOT / "tools/audio/_render/qoa_cache" / f"{wav.name}-{md5}.npy"
        if cache.exists():
            return np.load(cache)
        imp = Path(ARGS.get("--imported", str(Path(__import__("os").environ.get("TEMP", "")) / "defence_audio_sandbox/.godot/imported")))
        for m in imp.glob(wav.name + "-*.md5"):
            if f'source_md5="{md5}"' in m.read_text(encoding="utf-8", errors="replace"):
                x, _sr = Q.decode_godot_sample(m.with_suffix(".sample"))
                y = x.astype(np.float64) / 32768.0
                cache.parent.mkdir(parents=True, exist_ok=True)
                np.save(cache, y)
                return y
        return None

    def file(self, res: str) -> tuple[np.ndarray, int]:
        if res not in self._f:
            rel = res[len("res://"):]
            if self.rev:
                b = subprocess.run(["git", "show", f"{self.rev}:{rel}"], capture_output=True, check=True, cwd=ROOT).stdout
                with wave.open(io.BytesIO(b), "rb") as w:
                    x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
                    self._f[res] = (x, w.getframerate())
            else:
                x, sr = read_wav_any(ROOT / rel)
                y = self._qoa(ROOT / rel) if self.qoa else None
                if self.qoa and y is None:
                    self.wav_fallback.append(rel)
                self._f[res] = (y if y is not None else x[:, 0], sr)
        return self._f[res]


def voice_signal(assets: Assets, cue: str, variant: int, pitch: float, mr: int) -> np.ndarray:
    c = assets.cues[cue]
    x, sr = assets.file(c["files"][variant % len(c["files"])])
    step = sr * pitch / mr
    n = int((len(x) - 1) / step)
    return np.interp(np.arange(n) * step, np.arange(len(x)), x)


def load(d: Path) -> dict:
    meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
    st = {}
    for k in ("sfx", "ui", "music", "master"):
        x, sr = read_wav_any(d / f"rec_{k}.wav")
        st[k] = x.mean(axis=1)
        st[k + "_abs"] = np.abs(x).max(axis=1)   # sample peak over channels (what mix_report.py reports)
        st["mr"] = sr
    n = min(len(st[k]) for k in ("sfx", "ui", "music", "master"))   # captures can end one mix block apart
    for k in ("sfx", "ui", "music", "master"):
        st[k], st[k + "_abs"] = st[k][:n], st[k + "_abs"][:n]
    return {"meta": meta, "st": st, "dir": d}


def events(rec: dict, assets: Assets) -> list[dict]:
    """SFX-bus cues of the log with start sample, signal, prio, voice, wall time."""
    meta, mr = rec["meta"], rec["st"]["mr"]
    fmt2 = int(meta.get("log_format", 1)) >= 2
    n = len(rec["st"]["sfx"])
    scale = (n / mr) / float(meta["seconds"])
    ev = []
    for q in meta["cues"]:
        c = assets.cues.get(q[1])
        if not c or c["bus"] != "SFX":
            continue
        ta = float(q[5]) if fmt2 and len(q) > 5 and float(q[5]) >= 0 else float(q[0]) * scale
        s = voice_signal(assets, q[1], int(q[2]), float(q[3]), mr)
        ev.append({"t": float(q[0]), "ta": ta, "a": int(round(ta * mr)), "cue": q[1], "prio": int(c.get("prio", 1)),
                   "voice": int(q[6]) if fmt2 and len(q) > 6 else -1, "vol": float(q[4]), "sig": s,
                   "dur": len(s) / mr, "cl": float(q[10]) if fmt2 and len(q) > 10 else 0.0, "changes": []})
    # stealing: a later cue on the same voice cuts the earlier one
    last: dict[int, dict] = {}
    for e in ev:
        e["cut"] = None
        if e["voice"] >= 0:
            p = last.get(e["voice"])
            if p is not None and e["a"] < p["a"] + len(p["sig"]):
                p["cut"] = e["a"]
            last[e["voice"]] = e
    return ev


def on_voice_at(ev: list[dict], voice: int, a: int):
    """the event playing on `voice` at sample a (latest start <= a)."""
    best = None
    for e in ev:
        if e["voice"] == voice and e["a"] <= a and (best is None or e["a"] >= best["a"]):
            best = e
    return best


def apply_logged_changes(rec: dict, ev: list[dict]) -> None:
    mr = rec["st"]["mr"]
    for ta, _owner, lst in rec["meta"].get("ducks", []):
        for v, extra in lst:
            e = on_voice_at(ev, int(v), int(round(float(ta) * mr)))
            if e is not None:
                e["changes"].append((int(round(float(ta) * mr)), float(extra), "duck"))
    for ta, _new, v, d in rec["meta"].get("clusters", []):
        e = on_voice_at(ev, int(v), int(round(float(ta) * mr)))
        if e is not None:
            e["changes"].append((int(round(float(ta) * mr)), float(d), "cluster"))


def simulate_rule(ev: list[dict], policy: dict) -> dict:
    """Onset-cluster limit as in AudioManager._onset_cluster_rule, on a log recorded without it (wall time = clock)."""
    w, nmax, db, ex = float(policy["window"]), int(policy["max_full"]), float(policy["db"]), int(policy["exempt_prio"])
    order = sorted(range(len(ev)), key=lambda i: ev[i]["t"])
    ons: list[list] = []   # [t, idx, prio, lowered]
    st = {"events": 0, "lowered_new": 0, "lowered_retro": 0, "exempt_touched": 0}
    for i in order:
        e = ev[i]
        ons = [o for o in ons if e["t"] - o[0] < w]
        cl = 0.0
        if len(ons) + 1 > nmax:
            st["events"] += 1
            if e["prio"] < ex:
                cl = db
                st["lowered_new"] += 1
            else:
                for o in ons:
                    p = ev[o[1]]
                    end_t = p["t"] + p["dur"] + 0.02
                    stolen = p["cut"] is not None and p["cut"] <= e["a"]
                    if o[2] >= ex or o[3] or e["t"] >= end_t or stolen:
                        continue
                    p["changes"].append((e["a"], db, "cluster"))
                    o[3] = True
                    st["lowered_retro"] += 1
                    break
        if cl < 0:
            e["changes"].append((e["a"], cl, "cluster"))
        ons.append([e["t"], i, e["prio"], cl < 0])
    for e in ev:   # independent check of the exemption
        if e["prio"] >= ex and e["changes"] and any(src == "cluster" for _a, _d, src in e["changes"]):
            st["exempt_touched"] += 1
    return st


def render(ev: list[dict], n: int, off: int = 0, cut_fade: int = 0) -> np.ndarray:
    """off: constant sample offset for every start (calibration of the audio clock, see clock_offset).
    cut_fade: a voice cut by a later cue on the same player fades out linearly over this many frames instead of
    stopping on the sample (Godot fades a stopped playback out over its mix buffer; measured in CUT_FADE)."""
    out = np.zeros(n)
    for e in ev:
        s = e["sig"] * 10 ** (e["vol"] / 20)
        a = e["a"] + off
        cut = e["cut"] + off if e["cut"] is not None else None
        if a < 0:
            s, a = s[-a:], 0
        end = min(n, a + len(s))
        if cut is not None:
            end = min(end, cut + cut_fade)
        if end <= a:
            continue
        seg = s[: end - a].copy()
        for ca, d, _src in e["changes"]:
            k = max(0, ca + off - a)
            if k < len(seg):
                seg[k:] *= 10 ** (d / 20)
        if cut is not None and cut_fade > 0 and cut < end:
            k0 = max(0, cut - a)
            m = len(seg) - k0
            seg[k0:] *= np.linspace(1.0, 0.0, cut_fade, endpoint=False)[:m]
        out[a:end] += seg
    return out


def envelope(x: np.ndarray, mr: int) -> np.ndarray:
    hop = int(0.01 * mr)
    m = len(x) // hop
    return np.log10(np.add.reduceat(x[: m * hop] ** 2, np.arange(0, m * hop, hop)) + 1e-9)


def clock_offset(ev: list[dict], stem: np.ndarray, rec: dict) -> tuple[int, float]:
    """One constant start offset per recording (frames), reported. The logged audio clock (playback position of the
    probe's silent 11025 Hz clock voice) runs a fixed ~444 frames (10 ms at 44.1 kHz) ahead of where voices really
    start; measured identically on every clearly matched cue of pb_r02_s11 (64/65) and pb_r06_s11 (75/76).
    Method: matched filter of each cue's first 60 ms (logged file, pitch, volume) against the stem within +-150 ms of
    its logged start; offset = median over matches with normalized correlation >= 0.9. Returns (offset, share of
    those matches within +-2 frames of the median). Only a time shift is calibrated; no level is fitted."""
    if int(rec["meta"].get("log_format", 1)) < 2:
        return 0, float("nan")
    mr = rec["st"]["mr"]
    W, L = int(0.15 * mr), int(0.06 * mr)
    offs = []
    for e in ev:
        s = e["sig"][:L] * 10 ** (e["vol"] / 20)
        a = e["a"]
        if len(s) < L or a - W < 0 or a + W + L > len(stem):
            continue
        seg = stem[a - W:a + W + L]
        c = np.correlate(seg, s, "valid")
        en = np.sqrt(np.convolve(seg ** 2, np.ones(L), "valid"))
        r = c / np.maximum(en * np.linalg.norm(s), 1e-12)
        k = int(np.argmax(r))
        if r[k] >= 0.9:
            offs.append(k - W)
    if not offs:
        return 0, float("nan")
    med = int(np.median(offs))
    return med, round(float(np.mean(np.abs(np.array(offs) - med) <= 2)), 3)


def top_peaks(x: np.ndarray, mr: int, k: int = 5, sep: float = 0.5) -> list[int]:
    idx = np.argsort(-np.abs(x))
    chosen: list[int] = []
    for i in idx[:200000]:
        if all(abs(int(i) - c) > sep * mr for c in chosen):
            chosen.append(int(i))
            if len(chosen) == k:
                break
    return chosen


def db(v: float) -> float:
    return float(20 * np.log10(max(v, 1e-9)))


def music_gain(rec: dict) -> np.ndarray:
    """music bus gain per audio sample: gain log is in wall time, mapped to audio time with the clock log (if any)."""
    meta, mr = rec["meta"], rec["st"]["mr"]
    n = len(rec["st"]["music"])
    clk = np.array(meta.get("clock", []), dtype=float)
    g = np.array([[q[0], q[1]] for q in meta["music_gain"]], dtype=float)
    if len(clk) > 2:
        ta = np.interp(g[:, 0], clk[:, 0], clk[:, 1])
    else:
        ta = g[:, 0] * (n / mr) / float(meta["seconds"])
    return 10 ** (np.interp(np.arange(n) / mr, ta, g[:, 1]) / 20)


def refine_chunks(ev: list[dict], stem: np.ndarray, off: int, mr: int, chunk: int = 512, kmax: int = 2) -> list:
    """DIAGNOSTIC ONLY (--refine-chunks; never used for a verdict). Godot mixes 512-frame chunks inside the 4096-frame
    driver block, and the probe reads the audio clock right after play(): if a mix chunk runs in between, the logged
    position is one chunk late (seen: pa_r08_s23 gold_tick at -956 = -444 - 512 frames, level within 0.03 dB of the
    logged volume). Moves a cue by k*512 frames (|k| <= kmax) only if the local residual drops by > 30 %.
    Time only, no level fit. Returns the moved cues."""
    n = len(stem)
    base = render(ev, n, off)
    moved = []
    for e in sorted(ev, key=lambda x: x["a"]):
        s = e["sig"] * 10 ** (e["vol"] / 20)
        L = min(len(s), int(0.08 * mr))
        a0 = e["a"] + off
        lo, hi = a0 - kmax * chunk, a0 + L + kmax * chunk
        if lo < 0 or hi > n:
            continue
        k0 = a0 - lo
        own = np.zeros(hi - lo)
        own[k0:k0 + L] = s[:L]
        rest = base[lo:hi] - own
        best_k, best_err = 0, float(np.sum((stem[lo:hi] - base[lo:hi]) ** 2))
        for k in range(-kmax, kmax + 1):
            if k == 0:
                continue
            cand = np.zeros(hi - lo)
            cand[k0 + k * chunk:k0 + k * chunk + L] = s[:L]
            err = float(np.sum((stem[lo:hi] - rest - cand) ** 2))
            if err < best_err * 0.7:
                best_k, best_err = k, err
        if best_k:
            e["a"] += best_k * chunk
            moved.append((round(e["ta"], 3), e["cue"], best_k * chunk))
            base = render(ev, n, off)
    return moved


def check_one(key: str, rec: dict, assets: Assets) -> dict:
    mr, st = rec["st"]["mr"], rec["st"]
    n = len(st["sfx"])
    ev = events(rec, assets)
    apply_logged_changes(rec, ev)
    off, off_corr = clock_offset(ev, st["sfx"], rec)
    moved = refine_chunks(ev, st["sfx"], off, mr) if "--refine-chunks" in sys.argv else []
    r = render(ev, n, off)
    pk = top_peaks(st["sfx"], mr)
    win = int(0.02 * mr)
    rows = []
    for i in pk:
        a, b = max(0, i - win), min(n, i + win)
        rows.append({"t": round(i / mr, 3), "stem_db": round(db(np.abs(st["sfx"][a:b]).max()), 2),
                     "render_db": round(db(np.abs(r[a:b]).max()), 2)})
        rows[-1]["diff_db"] = round(rows[-1]["render_db"] - rows[-1]["stem_db"], 2)
    e1, e2 = envelope(st["sfx"], mr), envelope(r, mr)
    corr = float(np.corrcoef(e1, e2)[0, 1])
    mus = st["music"] * music_gain(rec)
    pre = r + st["ui"] + mus
    ex = int((assets.man.get("onset_cluster") or {}).get("exempt_prio", 3))
    # P4 from the log itself: exempt cues that started lowered, or were the target of a logged cluster change
    exempt_new = sum(1 for e in ev if e["prio"] >= ex and e["cl"] < 0)
    exempt_retro = sum(1 for e in ev if e["prio"] >= ex and any(src == "cluster" for _a, _d, src in e["changes"]))
    stats = rec["meta"].get("audio_stats", {}) or {}
    out = {"key": key, "log_format": rec["meta"].get("log_format", 1), "block_frames": rec["meta"].get("audio_block_frames"),
           "clock_offset_frames": off, "clock_offset_agreement": off_corr, "diagnostic_chunk_moves": moved, "mix_rate": mr, "cues_sfx": len(ev), "envelope_corr_10ms": round(corr, 3), "top_peaks": rows,
           "max_abs_peak_diff_db": round(max(abs(x["diff_db"]) for x in rows), 2),
           "stem_peak_db": round(db(st["sfx_abs"].max()), 2), "render_peak_db": round(db(np.abs(r).max()), 2),
           "master_peak_db": round(db(st["master_abs"].max()), 2),
           "master_clipped": int(np.sum(st["master_abs"] >= 32767 / 32768)),
           "prelimiter_estimate_peak_db": round(db(np.abs(pre).max()), 2),
           "rule_logged": {"cluster_events": stats.get("cluster_events"), "cluster_lowered": stats.get("cluster_lowered"),
                           "retro_logged": len(rec["meta"].get("clusters", [])), "exempt_touched": exempt_new + exempt_retro}}
    if RULE == "sim":
        pol = assets.man.get("onset_cluster") or {"window": 0.1, "max_full": 3, "db": -6.0, "exempt_prio": 3}
        ev2 = events(rec, assets)
        apply_logged_changes(rec, ev2)
        s = simulate_rule(ev2, pol)
        r2 = render(ev2, n, off)
        pre2 = r2 + st["ui"] + mus
        out["sim_rule"] = {"policy": pol, **s, "render_peak_db": round(db(np.abs(r2).max()), 2),
                           "prelimiter_estimate_peak_db": round(db(np.abs(pre2).max()), 2)}
    return out


def recs() -> list[tuple[str, Path]]:
    return [(f"{r}_s{s}", ROOT / f"tools/audio/_render/recording_{TAG}_{r}_s{s}") for r in ROUNDS for s in SEEDS]


def main_check() -> int:
    assets = Assets(MAN_REV, QOA)
    res = {"tag": TAG, "rule": RULE, "recordings": []}
    for key, d in recs():
        o = check_one(key, load(d), assets)
        res["recordings"].append(o)
        sim = o.get("sim_rule", {})
        print(f"{key}: fmt {o['log_format']} block {o['block_frames']} clock offset {o['clock_offset_frames']} corr {o['envelope_corr_10ms']:.3f} | top-5 peak diff max "
              f"{o['max_abs_peak_diff_db']:.2f} dB | stem {o['stem_peak_db']:.2f} render {o['render_peak_db']:.2f} | master {o['master_peak_db']:.2f} "
              f"(pre-limiter est {o['prelimiter_estimate_peak_db']:.2f}) clipped {o['master_clipped']} | rule log {o['rule_logged']}"
              + (f" | SIM rule: events {sim['events']} new {sim['lowered_new']} retro {sim['lowered_retro']} exempt {sim['exempt_touched']} "
                 f"-> SFX {sim['render_peak_db']:.2f}, pre-limiter {sim['prelimiter_estimate_peak_db']:.2f}" if sim else ""))
    worst = max(o["max_abs_peak_diff_db"] for o in res["recordings"])
    res["worst_top_peak_diff_db"] = worst
    res["source"] = "QOA as imported by Godot" if assets.qoa else "source WAV"
    res["wav_fallback_files"] = sorted(set(assets.wav_fallback))
    print(f"files: {res['source']}; WAV fallback for {len(res['wav_fallback_files'])} files {res['wav_fallback_files']}")
    print(f"P5 re-render vs stem, worst top-5 peak difference: {worst:.2f} dB -> {'PASS' if worst <= 1.0 else 'FAIL'} (limit 1.0)")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    return 0


def main_ab() -> int:
    """Same-background A/B on the v3.9 renderer: A = log as recorded (rule off), B = simulated rule.
    Targets are placed as in phone_check.py (1 s steps, 300 Hz HP, -6 dB, SNR over the cue's loud 50 ms frames).
    A low-priority target placed where the background already has >= max_full SFX starts within the window is
    lowered by the rule's dB in B (it would be the next start)."""
    import phone_check as P
    from scipy.signal import resample_poly
    assets = Assets(MAN_REV, QOA)
    pol = assets.man.get("onset_cluster") or {"window": 0.1, "max_full": 3, "db": -6.0, "exempt_prio": 3}
    res = {"tag": TAG, "policy": pol, "targets": P.TARGETS, "recordings": {}}
    for key, d in recs():
        rec = load(d)
        mr, st = rec["st"]["mr"], rec["st"]
        n = len(st["sfx"])
        evA = events(rec, assets)
        apply_logged_changes(rec, evA)
        evB = events(rec, assets)
        apply_logged_changes(rec, evB)
        sim = simulate_rule(evB, pol)
        off, _c = clock_offset(evA, st["sfx"], rec)
        rA, rB = render(evA, n, off), render(evB, n, off)
        mus = st["music"] * music_gain(rec)
        to22 = lambda x: resample_poly(x, 1, 2) if mr == 44100 else resample_poly(x, P.SR, mr)
        bm = P.phone(to22(mus))
        bA, bB = P.phone(to22(rA + st["ui"])), P.phone(to22(rB + st["ui"]))
        starts = np.array(sorted(e["ta"] for e in evA))
        row = {"sim": sim, "mix": {"A_prelimiter_peak_db": round(db(np.abs(rA + st["ui"] + mus).max()), 2),
                                   "B_prelimiter_peak_db": round(db(np.abs(rB + st["ui"] + mus).max()), 2),
                                   "A_lufs": round(P.lufs_mean(to22(rA + st["ui"] + mus)), 2), "B_lufs": round(P.lufs_mean(to22(rB + st["ui"] + mus)), 2)},
               "cues": {}}
        for cue in P.TARGETS:
            c = assets.cues.get(cue)
            if not c:
                continue
            worst = None
            for f in c["files"]:
                x = P.read_wav(ROOT / f[len("res://"):]) * 10 ** (float(c["vol_db"]) / 20)
                ra = snr(x, bm, bA, c, None, starts, pol)
                rb = snr(x, bm, bB, c, int(c.get("prio", 1)), starts, pol)
                if worst is None or rb["masked_pct"] - ra["masked_pct"] > worst["diff"]:
                    worst = {"A": ra, "B": rb, "diff": round(rb["masked_pct"] - ra["masked_pct"], 1), "file": f.rsplit("/", 1)[-1]}
            row["cues"][cue] = worst
        res["recordings"][key] = row
        print(f"{key}: sim {sim} | pre-limiter peak A {row['mix']['A_prelimiter_peak_db']} B {row['mix']['B_prelimiter_peak_db']} | LUFS A {row['mix']['A_lufs']} B {row['mix']['B_lufs']}")
        for cue in ("death_ally", "hit_base", "hit_bread", "hit_mold"):
            w = row["cues"][cue]
            print(f"   {cue:12s} A {w['A']['masked_pct']:5.1f}% p10 {w['A']['p10']:5.1f} | B {w['B']['masked_pct']:5.1f}% p10 {w['B']['p10']:5.1f} | diff {w['diff']:+.1f}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(res, indent=1) + "\n", encoding="utf-8")
    return 0


def snr(x, bg_music, bg_other, entry, rule_prio, starts, pol):
    """phone_check.py SNR measure; with rule_prio set, a low-priority target in a dense spot is lowered (rule B)."""
    import phone_check as P
    xph = P.phone(x)
    L = len(x)
    duck = 10 ** (float(entry.get("duck", 0)) / 20)
    sduck = 10 ** (float(entry.get("duck_sfx", 0)) / 20)
    fr = int(0.05 * P.SR)
    kc = P.k_weight(np.pad(xph, (0, fr)), P.SR) ** 2
    nf = max(1, L // fr)
    ce = np.array([kc[i * fr:(i + 1) * fr].mean() for i in range(nf)])
    loud = ce >= ce.max() * 10 ** (-15 / 10)
    n = len(bg_music)
    out, lowered = [], 0
    for t0 in np.arange(2.0, (n - L) / P.SR - 1.0, 1.0):
        a = int(t0 * P.SR)
        g = 1.0
        if rule_prio is not None and rule_prio < int(pol["exempt_prio"]):
            k = int(np.sum((starts > t0 - float(pol["window"])) & (starts <= t0)))
            if k + 1 > int(pol["max_full"]):
                g, lowered = 10 ** (float(pol["db"]) / 20), lowered + 1
        bg = bg_music[a:a + L] * duck + bg_other[a:a + L] * sduck
        kb = P.k_weight(np.pad(bg, (0, fr)), P.SR) ** 2
        be = np.array([kb[i * fr:(i + 1) * fr].mean() for i in range(nf)])
        dd = 10 * np.log10(np.maximum(ce[loud] * g * g, 1e-14)) - 10 * np.log10(np.maximum(be[loud], 1e-14))
        out.append(float(np.median(dd)))
    s = np.array(out)
    return {"masked_pct": round(100 * float(np.mean(s < 0)), 1), "p10": round(float(np.percentile(s, 10)), 1),
            "median": round(float(np.median(s)), 1), "positions": len(s), "target_lowered_by_rule": lowered}


if __name__ == "__main__":
    raise SystemExit(main_ab() if AB else main_check())
