"""Scratch (05-audio v3.8): 20 s before/after listening clips of the densest shoot_spit window in r08 seed 11."""
import json
import shutil
import subprocess
import wave
from pathlib import Path

R = Path(__file__).resolve().parent
OUT = R.parents[2] / "docs/audio/previews/listen"


def window(tag: str) -> tuple[float, int]:
    d = R / f"recording_{tag}_r08_s11"
    meta = json.loads((d / "rec_meta.json").read_text(encoding="utf-8"))
    with wave.open(str(d / "rec_master.wav"), "rb") as w:
        dur = w.getnframes() / w.getframerate()
    scale = dur / float(meta["seconds"])
    ts = [q[0] * scale for q in meta["cues"] if q[1] in ("shoot_spit", "death_enemy", "shoot_arrow", "gold_tick")]
    best = max(((sum(1 for t in ts if a <= t < a + 20), a) for a in [x * 0.5 for x in range(int((dur - 20) * 2))]))
    return best[1], best[0]


ff = shutil.which("ffmpeg")
for tag, name in (("rb", "repeat_before_r08_20s.mp3"), ("rd", "repeat_after_r08_20s.mp3")):
    a, n = window(tag)
    subprocess.run([ff, "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{a:.3f}", "-t", "20", "-i",
                    str(R / f"recording_{tag}_r08_s11" / "rec_master.wav"), "-af", "afade=t=in:d=0.3,afade=t=out:st=19.7:d=0.3",
                    "-map_metadata", "-1", "-c:a", "libmp3lame", "-b:a", "192k", str(OUT / name)], check=True)
    print(tag, name, f"window {a:.1f}-{a + 20:.1f} s", f"{n} plays of the 4 changed cues")
