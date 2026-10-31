# Background overdraw before and after 09's redraw (92a1718), and the P11 effect (STATIC, 2026-11-01 07:5x)

Owner: 08-performance. `python tools/perf/background_overdraw.py --rev 92a1718~1 --rev 92a1718`, run on the git blobs only (no
Godot). The tool replays `battle_view.gd _draw_biome_layers` for biome_01 with the camera of `battle.gd _update_camera`, zoom off.
Ground at 290 and the ground row 70 px above the bottom put the view rows at 0..360. That holds at **2400×1080** (canvas scale 3)
and **1600×720** (scale 2), because both give an 800×360 view. Layers tile horizontally in whole tiles, so each row's alpha mix is
the frame row's mix: an exact expected value over camera positions. Canvas items are drawn with alpha blending, so every covered
on-screen pixel of every layer is shaded, including fully transparent texels. Units, fx and HUD are not included.

## 1. Layer placement (identical in both revisions)
| Layer | Frame | Screen rows | Note |
|---|---|---|---|
| clear rect | colour | 0–360 (whole view) | drawn first, because the sky layer has `clear_color` |
| sky | 16×360 | 0–360 | 100 % opaque (old and new) |
| far | 640×150 | 50–200 | old 24.8 %, new 28.3 % fully transparent texels |
| mid | 640×120 | 180–300 | old 7.9 %, new 10.8 % transparent |
| ground | 640×80 | 275–355 (lane_line 15) | 100 % opaque |
| front | 640×18 | 342–360 | drawn after the units; 93.5 % transparent |

## 2. Per frame (physical pixels)
| | Layers per pixel (mean / max) | Rows with 2 / 3 / 4 layers | 2400×1080 shaded | of which opaque / partial alpha / invisible (a = 0) | 1600×720 shaded |
|---|---|---|---|---|---|
| old 92a1718~1, as drawn | 3.02 / 4 | 50 / 252 / 58 | **7.834 Mpx** (3.02 screens) | 7.376 / 0 / 0.457 | 3.482 Mpx |
| new 92a1718, as drawn | 3.02 / 4 | 50 / 252 / 58 | **7.834 Mpx** | 7.313 / 0 / 0.521 | 3.482 Mpx |
| new, **after P11** (no clear rect under the opaque sky) | 2.02 / 3 | (1 / 2 / 3 layers) 50 / 252 / 58 | **5.242 Mpx** (−2.592) | 4.721 / 0 / 0.521 | 2.330 Mpx (−1.152) |

- **09's redraw did not increase fill:** the same layers at the same rows and sizes give the same 7.834 Mpx shaded per frame. The
  pixel art has no partial alpha (0 texels with 0 < a < 255). The share of fully transparent texels rose by 0.064 Mpx (far and mid
  have more gaps). Those pixels are shaded either way, so this costs no extra GPU work, but it is wasted work in both versions.
- **P11 is still the lever:** removing the hidden clear rect cuts the background from 3.02 to 2.02 layers per pixel: −2.59 Mpx per
  frame at 2400×1080 and −1.15 Mpx at 1600×720 (−33 %). That is about as much as the whole D1 + zoom 4/3 unit fill upper bound
  adds (+2.46 Mpx, PHONE_FILL.md §2).
- A second, smaller lever: the front strip is 93.5 % transparent (0.13 Mpx of invisible fragments at 2400×1080). Splitting it into
  only its opaque pieces would be a contract change and is not asked.
- Not measured on a GPU; desktop GPUs cannot show this (PHONE_FILL.md §3). The phone session (DEVICE_SESSION.md) reports the
  game's `gpu_ms` before and after P11.
