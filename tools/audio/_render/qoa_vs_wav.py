"""Scratch (05-audio v3.9): imported QOA (from the sandbox) vs source WAV, per SFX file: length, peak, rms, error."""
import sys
import tempfile
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import qoa  # noqa: E402
import rerender as R  # noqa: E402

imp = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(tempfile.gettempdir()) / "defence_audio_sandbox" / ".godot" / "imported"
for w in sorted((R.ROOT / "assets/audio/sfx").glob("*.wav")):
    c = list(imp.glob(w.name + "-*.sample"))
    if not c:
        print(w.name, "no imported sample")
        continue
    q, sr = qoa.decode_godot_sample(c[0])
    x, sr0 = R.read_wav_any(w)
    x = x[:, 0]
    qf = q.astype(np.float64) / 32768.0
    n = min(len(x), len(qf))
    err = qf[:n] - x[:n]
    print(f"{w.name:24s} len wav {len(x)} qoa {len(q)} sr {sr0}/{sr} | peak wav {R.db(np.abs(x).max()):6.2f} qoa {R.db(np.abs(qf).max()):6.2f} "
          f"| rms diff {R.db(np.sqrt(np.mean(qf[:n] ** 2))) - R.db(np.sqrt(np.mean(x[:n] ** 2))):+5.2f} | err/sig {R.db(np.sqrt(np.mean(err ** 2))) - R.db(np.sqrt(np.mean(x[:n] ** 2))):6.1f} dB")
