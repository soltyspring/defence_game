#!/usr/bin/env python3
"""QOA decoder (the Quite OK Audio format, https://qoaformat.org, MIT reference qoa.h) for 05-audio analysis.
Owner: 05-audio. Why: Godot imports our SFX WAVs as QOA (compress/mode=2), so the game plays the QOA-decoded
signal, not the source WAV. Noisy transients (bread crunch, baguette whoosh) come out with sample peaks up to
~3.6 dB lower while RMS is unchanged (docs/audio/ONSET_PEAK_CHECK.md). tools/audio/rerender.py uses the decoded data.

decode_godot_sample(path) reads a Godot 4 imported `.sample` resource (binary AudioStreamWAV) and decodes the QOA
stream stored in its `data` field. Returns (int16 numpy array, sample rate).
"""
from __future__ import annotations

import struct
from pathlib import Path

import numpy as np

SCALEFACTOR = [1, 7, 21, 45, 84, 138, 211, 304, 421, 562, 731, 928, 1157, 1419, 1715, 2048]
DQT = [0.75, -0.75, 2.5, -2.5, 4.5, -4.5, 7.0, -7.0]


def _round_away(x: float) -> int:
    return int(x + 0.5) if x >= 0 else -int(-x + 0.5)


DEQUANT = [[_round_away(sf * d) for d in DQT] for sf in SCALEFACTOR]   # = qoa_dequant_tab in qoa.h


def decode(buf: bytes) -> tuple[np.ndarray, int, int]:
    """Decode a QOA file image ('qoaf' header). Returns (samples [n, channels] int16, rate, channels)."""
    if buf[:4] != b"qoaf":
        raise ValueError("not a QOA stream")
    total = struct.unpack(">I", buf[4:8])[0]
    p = 8
    out = []
    rate = ch = 0
    while p + 8 <= len(buf) and sum(len(o) for o in out) < total:
        hdr = struct.unpack(">Q", buf[p:p + 8])[0]
        p += 8
        ch = (hdr >> 56) & 0xFF
        rate = (hdr >> 32) & 0xFFFFFF
        fs = (hdr >> 16) & 0xFFFF
        fsize = hdr & 0xFFFF
        if ch == 0 or fs == 0:
            break
        hist, wts = [], []
        for _c in range(ch):
            h = struct.unpack(">4h", buf[p:p + 8]); p += 8
            w = struct.unpack(">4h", buf[p:p + 8]); p += 8
            hist.append(list(h)); wts.append(list(w))
        frame = np.zeros((fs, ch), dtype=np.int16)
        nslices = (fs + 19) // 20
        for s in range(nslices):
            for c in range(ch):
                sl = struct.unpack(">Q", buf[p:p + 8])[0]
                p += 8
                sf = (sl >> 60) & 0xF
                dq = DEQUANT[sf]
                h, w = hist[c], wts[c]
                for i in range(s * 20, min(fs, s * 20 + 20)):
                    pred = (h[0] * w[0] + h[1] * w[1] + h[2] * w[2] + h[3] * w[3]) >> 13
                    q = (sl >> 57) & 0x7
                    d = dq[q]
                    r = pred + d
                    r = -32768 if r < -32768 else (32767 if r > 32767 else r)
                    frame[i, c] = r
                    sl = (sl << 3) & 0xFFFFFFFFFFFFFFFF
                    delta = d >> 4
                    w[0] += -delta if h[0] < 0 else delta
                    w[1] += -delta if h[1] < 0 else delta
                    w[2] += -delta if h[2] < 0 else delta
                    w[3] += -delta if h[3] < 0 else delta
                    h[0], h[1], h[2], h[3] = h[1], h[2], h[3], r
        out.append(frame)
        del fsize
    x = np.concatenate(out)[:total] if out else np.zeros((0, 1), np.int16)
    return x, rate, ch


def decode_godot_sample(path: Path) -> tuple[np.ndarray, int]:
    """Decode the QOA data inside a Godot 4 imported AudioStreamWAV `.sample` file. Mono -> 1-D int16."""
    b = Path(path).read_bytes()
    k = b.find(b"qoaf")
    if k < 0:
        raise ValueError(f"no QOA stream in {path}")
    x, rate, ch = decode(b[k:])
    return (x[:, 0] if ch == 1 else x), rate


if __name__ == "__main__":
    import sys
    import wave
    for a in sys.argv[1:]:
        x, sr = decode_godot_sample(Path(a))
        print(a, len(x), "samples", sr, "Hz", "peak", int(np.abs(x.astype(np.int32)).max()))
        if len(sys.argv) > 2 and a.endswith(".wav"):
            with wave.open(a) as w:
                print(w.getnframes())
