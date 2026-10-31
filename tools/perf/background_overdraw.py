"""08-performance: STATIC background overdraw per screen pixel, from git revisions only (no Godot).

Replays battle_view.gd `_draw_biome_layers` placement for one biome and counts, per frame:
  - the layers covering each screen row (clear-colour rect + every non-front layer + the front layer);
  - shaded fragments (every covered on-screen pixel of every layer; canvas items are alpha-blended, so all of them cost fill);
  - their split by texel alpha: opaque (a = 255), blended (0 < a < 255), invisible (a = 0, pure waste).
Geometry (battle.gd `_update_camera`, zoom off): view 800 x 360 world px at both phone sizes (2400x1080 = scale 3,
1600x720 = scale 2), cy = ground_y - (360/2 - 70) -> view rows 0..360. Layers tile horizontally with whole-tile steps, so over
all camera positions each covered row's alpha mix equals the frame row's mix (expected value over cam_x; exact per row).
Variants: as drawn today, and "P11" = without the clear rect on rows an opaque layer already covers.

  python tools/perf/background_overdraw.py --rev 92a1718~1 --rev 92a1718 [--biome biome_01] [--out <json>]

Owner: 08-performance.
"""
from __future__ import annotations

import argparse
import io
import json
import subprocess
import sys

from PIL import Image

VIEW_W, VIEW_H = 800, 360
GROUND_FROM_BOTTOM = 70.0
SCREENS = {"2400x1080": 3, "1600x720": 2}


def git_bytes(rev: str, path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{rev}:{path}"])


def analyse(rev: str, biome: str) -> dict:
    manifest = json.loads(git_bytes(rev, "assets/manifest.json"))
    b = manifest["biomes"][biome]
    atlas_id = b["atlas"]
    meta = json.loads(git_bytes(rev, f"assets/atlases/{atlas_id}.json"))
    img = Image.open(io.BytesIO(git_bytes(rev, f"assets/atlases/{atlas_id}.png"))).convert("RGBA")
    cfg = json.loads(git_bytes(rev, "data/game_config.json"))
    ground_y = float(cfg.get("lane", {}).get("ground_y", 290))
    cy = round(ground_y - (VIEW_H * 0.5 - GROUND_FROM_BOTTOM))
    top, bottom = cy - VIEW_H / 2, cy + VIEW_H / 2
    rows = int(VIEW_H)
    # per screen row: list of (layer, opaque_frac, blend_frac, zero_frac)
    cover = [[] for _ in range(rows)]
    for r in range(rows):
        cover[r].append(("clear_rect", 1.0, 0.0, 0.0))   # draw_rect over the whole view, opaque colour (only if a layer has clear_color)
    if not any("clear_color" in L for L in b["layers"] if L.get("z", "") != "front"):
        cover = [[] for _ in range(rows)]
    layers_out = []
    order = [L for L in b["layers"] if L.get("z", "") != "front"] + [L for L in b["layers"] if L.get("z", "") == "front"]
    for L in order:
        f = meta["frames"][L["frame"]]
        fw, fh = int(f["w"]), int(f["h"])
        y0 = ground_y - float(L["lane_line"]) if "lane_line" in L else float(L.get("view_y", ground_y - fh))
        a = img.crop((f["x"], f["y"], f["x"] + fw, f["y"] + fh)).getchannel("A")
        px = a.load()
        covered = 0
        for fr in range(fh):
            sy = int(round(y0 - top)) + fr
            if sy < 0 or sy >= rows:
                continue
            op = sum(1 for x in range(fw) if px[x, fr] == 255) / fw
            ze = sum(1 for x in range(fw) if px[x, fr] == 0) / fw
            cover[sy].append((L["frame"], op, max(0.0, 1.0 - op - ze), ze))
            covered += 1
        layers_out.append({"frame": L["frame"], "size": [fw, fh], "screen_y": y0 - top, "rows_on_screen": covered,
                           "z": L.get("z", "back"), "parallax": L.get("parallax", 1.0)})

    def totals(skip_clear_where_opaque: bool) -> dict:
        frag = op = bl = ze = 0.0
        hist = {}
        for r in range(rows):
            ent = cover[r]
            if skip_clear_where_opaque and any(n != "clear_rect" and o >= 0.999 for n, o, _, _ in ent):
                ent = [e for e in ent if e[0] != "clear_rect"]
            n = len(ent)
            hist[n] = hist.get(n, 0) + 1
            for _, o, bb, z in ent:
                frag += VIEW_W
                op += o * VIEW_W
                bl += bb * VIEW_W
                ze += z * VIEW_W
        screen = VIEW_W * VIEW_H
        return {"world_fragments": frag, "overdraw": frag / screen, "opaque": op, "blended": bl, "invisible": ze,
                "rows_by_layer_count": dict(sorted(hist.items())), "max_layers": max(hist), "mean_layers": frag / screen}

    today, p11 = totals(False), totals(True)
    out = {"rev": rev, "biome": biome, "atlas": atlas_id, "ground_y": ground_y, "view_rows": [top, bottom], "layers": layers_out,
           "today": today, "p11": p11, "screens": {}}
    for name, k in SCREENS.items():
        s = k * k
        out["screens"][name] = {v: {"shaded_mpx": round(t["world_fragments"] * s / 1e6, 3), "opaque_mpx": round(t["opaque"] * s / 1e6, 3),
                                    "blended_mpx": round(t["blended"] * s / 1e6, 3), "invisible_mpx": round(t["invisible"] * s / 1e6, 3),
                                    "screen_mpx": round(VIEW_W * VIEW_H * s / 1e6, 3)} for v, t in (("today", today), ("p11", p11))}
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rev", action="append", required=True)
    ap.add_argument("--biome", default="biome_01")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    res = [analyse(r, a.biome) for r in a.rev]
    for r in res:
        print(f"[overdraw] {r['rev']} {r['biome']} ({r['atlas']}) view rows {r['view_rows'][0]:.0f}..{r['view_rows'][1]:.0f}")
        for L in r["layers"]:
            print(f"[overdraw]   layer {L['frame']:7s} {L['size'][0]}x{L['size'][1]} screen_y {L['screen_y']:.0f} rows on screen {L['rows_on_screen']} ({L['z']})")
        for v in ("today", "p11"):
            t = r[v]
            print(f"[overdraw]   {v:5s} layers per pixel mean {t['mean_layers']:.3f} max {t['max_layers']} rows by count {t['rows_by_layer_count']}")
            for sname, sv in r["screens"].items():
                x = sv[v]
                print(f"[overdraw]     {sname}: shaded {x['shaded_mpx']} Mpx (screen {x['screen_mpx']}), opaque {x['opaque_mpx']}, blended {x['blended_mpx']}, invisible {x['invisible_mpx']}")
    if a.out:
        json.dump(res, open(a.out, "w", encoding="utf-8"), indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
