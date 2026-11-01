"""09-art-world: 06 W-2 ground band under the HUD row, measured the way 06 measured it.

python tools/art/world/hud_band.py <bg_swap out dir> [tag=ko_1x]

<dir> is the output of tools/art/ui_art/bg_swap.py (06's tool: 07's ad47eda fixed-set frames with the battlefield of
a SHA drawn in). Value = mean CIE L* of the background layer (`layers/<tag>_<scene>_bg.png`, no HUD, units or text)
over screen rows y >= 296, all columns, plus the mean WCAG relative luminance of the same pixels.
Check: on 92a1718 this gives 23.4 in every scene, the number in 06's request (06-art-ui-to-09-art-world.md W-2).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "qa"))
import art_metrics as am  # noqa: E402  (07's colour maths, read-only import)

SCENES = ["2_r01_t10", "3_r01_t30", "4_r06_t46", "5_r08_peak", "6_r10_boss"]
Y0 = 296


def main(d, tag="ko_1x"):
    out = {}
    for sc in SCENES:
        p = os.path.join(d, "layers", f"{tag}_{sc}_bg.png")
        if not os.path.exists(p):
            continue
        bg = np.asarray(Image.open(p).convert("RGB"))[Y0:]
        lin = bg.astype(float) / 255.0
        lin = np.where(lin <= 0.04045, lin / 12.92, ((lin + 0.055) / 1.055) ** 2.4)
        out[sc] = {"L_mean": round(float(am.lab(bg)[..., 0].mean()), 1),
                   "rel_lum_mean": round(float((lin @ np.array([0.2126, 0.7152, 0.0722])).mean()), 3)}
    print(json.dumps(out))
    return out


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "ko_1x")
