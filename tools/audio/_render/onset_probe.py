"""Scratch (05-audio v3.9): find the REAL start sample of each logged cue near a moment of a recording by matched
filtering the recorded SFX stem with the cue's own file (logged variant and pitch), then re-render that moment with
those real starts and compare peaks with the stem."""
import json
import sys
import wave
from pathlib import Path

import numpy as np

sys.argv, ARGV = sys.argv[:1], sys.argv[1:]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import same_bg_ab as T  # noqa: E402

rec, lt0, lt1, lag = ARGV[0], float(ARGV[1]), float(ARGV[2]), float(ARGV[3])   # log-time window, approx log-audio lag (s)
d = Path(__file__).resolve().parent / rec
meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
NEW = T.AssetSet(None)


def rdw(p):
    with wave.open(str(p), "rb") as w:
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float64) / 32768.0
        return x.reshape(-1, w.getnchannels()), w.getframerate()


st, MR = rdw(d / "rec_sfx.wav")
stm = st.mean(axis=1)


def play(f, pitch):
    """22050 Hz file -> mix rate at pitch (linear interpolation)."""
    x = NEW.file(f)
    step = 22050.0 * pitch / MR
    n = int((len(x) - 1) / step)
    return np.interp(np.arange(n) * step, np.arange(len(x)), x)


ev = []
for q in meta["cues"]:
    if lt0 <= q[0] <= lt1:
        c = NEW.man["cues"].get(q[1])
        if not c or c["bus"] != "SFX":
            continue
        f = c["files"][int(q[2]) % len(c["files"])]
        s = play(f, float(q[3])) * 10 ** (float(q[4]) / 20)
        exp = int((q[0] - lag) * MR)
        lo, hi = exp - int(0.3 * MR), exp + int(0.3 * MR)
        seg = stm[lo:hi + len(s)]
        # normalized cross-correlation over the window
        best, bk = -2, 0
        L = min(len(s), int(0.08 * MR))   # first 80 ms (the transient) decide
        tpl = s[:L]
        for k in range(0, hi - lo, 8):
            w = seg[k:k + L]
            den = np.linalg.norm(w) * np.linalg.norm(tpl)
            r = float(np.dot(w, tpl) / den) if den > 0 else 0
            if r > best:
                best, bk = r, k
        for k in range(max(0, bk - 8), bk + 9):   # refine to 1 sample
            w = seg[k:k + L]
            den = np.linalg.norm(w) * np.linalg.norm(tpl)
            r = float(np.dot(w, tpl) / den) if den > 0 else 0
            if r > best:
                best, bk = r, k
        start = lo + bk
        ev.append((q, s, start, best, c))
print(f"mix rate {MR}")
t_first = min(e[2] for e in ev)
for q, s, start, r, c in ev:
    print(f"  log {q[0]:7.3f}  {q[1]:12s} v{q[2]} p{q[3]:.3f} {q[4]:6.2f} dB -> audio start {start / MR:8.4f} s "
          f"(log-audio {q[0] - start / MR:+.3f} s, rel {1000 * (start - t_first) / MR:6.1f} ms) match r={r:.2f}")


def render(starts, duck=True):
    a0 = min(starts) - int(0.05 * MR)
    n = max(st_ + len(e[1]) for st_, e in zip(starts, ev)) - a0
    out = np.zeros(n)
    items = []
    for (q, s, _st, _r, c), s0 in zip(ev, starts):
        items.append([s0 - a0, s0 - a0 + len(s), int(c.get("prio", 1)), s.copy(), float(c.get("duck_sfx", 0)), int(c.get("duck_sfx_below", 0))])
    if duck:
        for it in items:
            for o in items:
                if o is not it and o[4] < 0 and it[2] < o[5] and it[0] <= o[0] < it[1] and o[0] >= it[0]:
                    it[3][o[0] - it[0]:] *= 10 ** (o[4] / 20)   # already-playing voice lowered from the duck start
    for a, e, _p, s, *_ in items:
        out[a:e] += s[: e - a]
    k = int(np.abs(out).argmax())
    return 20 * np.log10(np.abs(out).max()), (a0 + k) / MR


real_starts = [e[2] for e in ev]
log_starts = [int((e[0][0] - lag) * MR) for e in ev]
pk_s = 20 * np.log10(np.abs(stm[min(real_starts) - 2000:max(real_starts) + 20000]).max())
pk_s_ch = 20 * np.log10(np.abs(st[min(real_starts) - 2000:max(real_starts) + 20000]).max())
print(f"recorded SFX stem peak in this window: {pk_s_ch:.2f} dBFS (any channel), {pk_s:.2f} (channel mean)")
for nm, ss in (("real starts", real_starts), ("log starts", log_starts)):
    pk, tp = render(ss)
    print(f"render with {nm:11s}: peak {pk:6.2f} dBFS at audio {tp:.4f} s")
# what-if on the real starts: lower / remove some cues
base = [e[1].copy() for e in ev]
for nm, g in (("low prio (<=2) -6 dB", {"shoot_spit": -6, "hit_bread": -6, "hit_mold": -6, "gold_tick": -6, "shoot_arrow": -6}),
              ("low prio removed", {"shoot_spit": -99, "hit_bread": -99, "hit_mold": -99, "gold_tick": -99, "shoot_arrow": -99}),
              ("low prio -6, death_enemy -6", {"shoot_spit": -6, "hit_bread": -6, "death_enemy": -6}),
              ("explosion -6 only", {"explosion": -6}),
              ("deploy -6 only", {"deploy": -6})):
    for (q, s, *_r), b in zip(ev, base):
        s[:] = b * 10 ** (g.get(q[1], 0) / 20)
    pk, tp = render(real_starts)
    print(f"what-if {nm:28s}: peak {pk:6.2f} dBFS")
for (q, s, *_r), b in zip(ev, base):
    s[:] = b
for dl in (0.02, 0.04, 0.06):   # low-priority starts pushed back
    ss = [st_ + (int(dl * MR) if e[0][1] in ("shoot_spit", "hit_bread") else 0) for st_, e in zip(real_starts, ev)]
    pk, tp = render(ss)
    print(f"what-if low prio delayed {dl * 1000:.0f} ms: peak {pk:6.2f} dBFS")
