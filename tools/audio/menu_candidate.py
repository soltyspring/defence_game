#!/usr/bin/env python3
"""Folk-style menu melody CANDIDATE (01 R1 "bright cheerful folk motif for menus"). Owner: 05-audio.

PREVIEW ONLY: writes docs/audio/previews/listen/menu_folk_candidate_30s.mp3 (+ .txt). It is NOT written to
assets/audio, NOT in the manifest and NOT connected to the game. Whether it replaces music_menu or is added
is a 01/user decision (overlaps the music-variation question candidate).
Same deterministic synthesis as tools/audio/synth.py: G major, 120 BPM (22,050 samples per beat -> exact loop),
accordion lead + fiddle-like second voice (saw with delayed vibrato, a sixth below in the B part), plucked
bass on 1 and 3, bodhran-like frame drum (low tom + slap) in a jig-ish pattern, shaker.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import synth as S  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/audio/previews/listen"
S.CHORDS.setdefault("D", (50, (0, 4, 7)))
S.CHORDS.setdefault("Em", (40, (0, 3, 7)))
S.CHORDS.setdefault("G3", (43, (0, 4, 7)))

FOLK = dict(
    bpm=120,
    chords=["G", "C", "G", "D", "G", "C", "D", "G"],
    melody=[
        "D5:0.5 G5:0.5 G5:0.5 A5:0.5 B5:1 G5:1", "E5:0.5 G5:0.5 E5:0.5 D5:0.5 C5:1 E5:1",
        "D5:0.5 G5:0.5 B5:0.5 A5:0.5 G5:1 D5:1", "F#5:0.5 A5:0.5 F#5:0.5 E5:0.5 D5:2",
        "B5:0.5 A5:0.5 G5:0.5 A5:0.5 B5:1 D6:1", "C6:0.5 B5:0.5 A5:0.5 G5:0.5 E5:2",
        "D5:0.5 F#5:0.5 A5:0.5 C6:0.5 B5:1 A5:1", "G5:1.5 D5:0.5 G5:2",
    ],
    bass=[0, None, None, None, 7, None, None, None], bass_low=False, bass_shape="pluckbass", bass_oct=0,
    arp_order=[0, 2, 1, 2], arp16=False, arp_shape="pluck",
    drums=dict(kick=(0, 6, 8, 14), snare=(4, 12), hat=(2, 6, 10, 14)), fills=False,
    lead_shape="accordion", echo=0.0, soft_clip=False,
    g_bass=0.3, g_arp=0.08, g_pad=0.0, g_kick=0.22, g_snare=0.12, g_hat=0.06, g_lead=0.32,
)


def main() -> int:
    loop = S.render_loop(FOLK, seed=7101)            # stereo, 8 bars = 16 s
    y = np.concatenate([loop, loop])[: int(30 * S.MSR)]
    n = len(y)
    fade = int(0.5 * S.MSR)
    y[-fade:] *= np.linspace(1, 0, fade)[:, None]
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = OUT / "menu_folk_candidate.wav.part"
    S.write_wav(Path(str(tmp).replace(".part", "")), y, S.MSR, 7101)
    wav = OUT / "menu_folk_candidate.wav"
    mp3 = OUT / "menu_folk_candidate_30s.mp3"
    subprocess.run([shutil.which("ffmpeg"), "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-map_metadata", "-1",
                    "-c:a", "libmp3lame", "-b:a", "160k", str(mp3)], check=True)
    wav.unlink()
    pk = float(np.abs(y).max())
    (OUT / "menu_folk_candidate_30s.txt").write_text(
        "Folk menu CANDIDATE (preview only; not in assets, not connected). G major 120 BPM, 8-bar loop (16 s) played "
        f"twice then cut at 30 s with a 0.5 s fade. Peak {20 * np.log10(pk):.2f} dBFS. Made by tools/audio/menu_candidate.py.\n",
        encoding="utf-8")
    print(f"menu candidate: {n / S.MSR:.1f}s peak {20 * np.log10(pk):.2f} dBFS, mp3 {mp3.stat().st_size} B")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
