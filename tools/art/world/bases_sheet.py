"""Base state sheet + damage metrics from the source modules (owner: 09-art-world).

    python tools/art/world/bases_sheet.py <out_dir>

For both bases and both versions (v1 = art 0.12/0.13, v2 = art-world 1): idle / damaged / ruined frame 0, with the
theme remap build.py applies, on the new street background crop and at 1x and 3x. Metrics per base and state:
changed pixels vs idle (% of idle area), silhouette area ratio, median dE76 of the changed pixels to the idle body mean.
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.dirname(HERE)
sys.path.insert(0, ART)
import bases  # noqa: E402
import theme  # noqa: E402
from cvd_check import lab  # noqa: E402
from pixel import RGBA  # noqa: E402


def frame(fn, key, state, phase=0):
    cv = fn(state, phase)
    theme.remap_keys(cv, theme.BAKERY_KEEP if key == "player" else theme.MOULD_FORT)
    return RGBA[cv.a]


def metrics(fr):
    ip = fr["idle"]
    ia = ip[..., 3] > 0
    body = lab(ip[ia][:, :3].astype(float)).mean(0)
    out = {}
    for s in ("damaged", "ruined"):
        p = fr[s]
        pa = p[..., 3] > 0
        chg = (np.abs(p.astype(int) - ip.astype(int)).max(2) > 0) & (pa | ia)
        cue = chg & pa
        d = np.linalg.norm(lab(p[cue][:, :3].astype(float)) - body, axis=1) if cue.any() else np.array([0.0])
        out[s] = {"changed_px_pct_of_idle": round(float(chg.sum()) / int(ia.sum()) * 100, 1),
                  "silhouette_area_ratio": round(float(pa.sum()) / int(ia.sum()), 2),
                  "cue_dE_to_idle_mean_median": round(float(np.median(d)), 1)}
    return out


def main(out):
    os.makedirs(out, exist_ok=True)
    rep = {}
    tiles = []
    for ver, kf, nf in (("v1", bases.player_keep_v1, bases.mould_nest_v1), ("v2", bases.keep_v2, bases.nest_v2)):
        for key, fn in (("player", kf), ("enemy", nf)):
            fr = {s: frame(fn, key, s) for s in ("idle", "damaged", "ruined")}
            rep[f"{ver}_{key}"] = metrics(fr)
            for s in ("idle", "damaged", "ruined"):
                tiles.append(fr[s])
    sheet = np.zeros((128 * 4 + 12, 96 * 3 + 8, 4), np.uint8)
    sheet[..., :3] = (61, 37, 25)
    sheet[..., 3] = 255
    for i, t in enumerate(tiles):
        r, cidx = i // 3, i % 3
        y0, x0 = r * 131, cidx * 99
        a = t[..., 3:4] / 255.0
        sheet[y0:y0 + 128, x0:x0 + 96, :3] = (sheet[y0:y0 + 128, x0:x0 + 96, :3] * (1 - a) + t[..., :3] * a).astype(np.uint8)
    im = Image.fromarray(sheet, "RGBA").convert("RGB")
    im.save(os.path.join(out, "bases_states_1x.png"))
    im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(os.path.join(out, "bases_states_3x.png"))
    json.dump(rep, open(os.path.join(out, "bases_states.json"), "w", encoding="utf-8", newline="\n"), indent=1)
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main(sys.argv[1])
