# GPU fill at phone resolutions: shipped units vs D1 32 px vs D1 + zoom 4/3 (relative, desktop)

Owner: 08-performance. Run 2026-11-01 03:34–03:53 KST, job `08-phone-fill` (heavy_run_detached, START 03:34:29, END 03:53:21
exit 0). All 8 timing runs, the breakdown run and both UI captures were **CLEAN**: the per-second monitor saw no foreign
Godot/emulator/Gradle process. Every Godot call went through 10's `isolated_godot.ps1`, and the real save was unchanged.
**Evidence class: DESKTOP_PROXY** (Godot 4.7.2 debug binary, GL Compatibility, RTX 2070 SUPER). **No value here is a phone value.**
Desktop GPU times are only used to compare variants with each other. §5 lists what still needs a phone.

## 1. Setup
- Copies of commit **ad47eda**: `base` (shipped art; contains 04's R8 HUD layering 2de6668), `draft` (same commit +
  `ART_DRAFT32=D1FULL` art build in the copy only; working-tree atlases unchanged) and `pre` = 1d359bc (the commit before
  2de6668, for the HUD before/after). The copies live on the local disk (`%TEMP%`): a first attempt at 02:40 with copies on the Z:
  share stalled in `--import` for 15 min and was discarded (exit 1, no results used; NOTE line in heavy_run.log).
- `tools/perf/phone_fill_matrix.ps1` runs `perf_drawcall_probe.gd --dc-set=units --dc-uncapped --dc-window=<W>x<H>`: a borderless
  window of exactly 2400×1080 or 2340×1080 physical px. The window sits on DISPLAY2 and its overflow is off-screen; it is never on the
  primary monitor. The reports confirm the window (2400, 1080) / (2340, 1080), **canvas scale 3.0** (integer stretch) and view
  800×360 / 780×360. Frame rate unlimited (`max_fps 0` held, vsync off). r08 autoplay, same round seed, stress cheat at caps
  (72–76 units). Phases of 3 s × 5 cycles: whole frame / battle view without HUD / view without unit sprites.
- **Zoom 4/3:** 02 has no zoom flag yet (no zoom code in `src/gameplay` at ad47eda), so the probe applies 04's
  `zoom_preview.gd` camera rule in a test-only node: `Camera2D.zoom = 4/3`, ground kept 70 px above the view bottom.
- Fill is counted per drawn unit sprite from the frame rect and the page's alpha mask: **quad** = frame rect, which is what the
  GPU shades today; **bbox** = alpha bounding box, which a trimmed quad would shade; **opaque** = pixels with alpha > 0. Only
  the on-screen part counts. Physical px = world px × (canvas scale × zoom)², i.e. ×9 without and ×16 with zoom.
- "Same seed" applies to the battle. The stress cheat refills armies by wall-clock time, so where the clash sits relative to the
  camera differs between runs. That is why §2 gives both the measured on-screen fill and the all-units upper bound.

## 2. Unit fill per frame (physical pixels; screen = 2.59 Mpx at 2400×1080, 2.53 Mpx at 2340×1080)
| Variant | Window | Upper bound, all units on screen: quad / trimmed (bbox) | Measured on-screen median: quad / bbox (share of screen) |
|---|---|---|---|
| shipped | 2400×1080 | 0.91 / 0.39 Mpx (two runs) | 0.110 / 0.051 Mpx (4 %), drift run 0.131 / 0.051 (5 %) |
| shipped | 2340×1080 | 0.86 / 0.38 | 0.176 / 0.066 (7 %) |
| D1FULL | 2400×1080 | 1.77 / 0.65 | 0.213 / 0.077 (8 %) |
| D1FULL | 2340×1080 | 1.83 / 0.68 | 0.255 / 0.089 (10 %) |
| D1FULL + zoom 4/3 | 2400×1080 | **3.37 / 1.24** | **1.387 / 0.571 (54 %)**: the clash was in view |
| D1FULL + zoom 4/3 | 2340×1080 | 3.33 / 1.23 | 0.302 / 0.100 (12 %) |

- **The earlier "≈ 3.4 Mpx" estimate is confirmed as the upper bound:** 3.33–3.37 Mpx, i.e. ×3.7–3.9 of the shipped 0.86–0.91.
  It counts every unit as on screen. The highest fill measured in a real frame was 1.39 Mpx, about half the screen.
- **Trimmed quads (alpha bbox, see UNIT_SIZE_D1.md §6):** D1 + zoom upper bound 1.23–1.24 Mpx = **×1.36–1.43** of today's untrimmed
  units; D1 without zoom 0.65–0.68 Mpx = **×0.71–0.79**, i.e. less than today. The in-game bbox/quad share (shipped 42 %, D1 37 %)
  matches the static mask table (42 % / 38 %).
- **Background fill is larger than any unit option** (static, from the meadow layer list and alpha masks; not measured):
  `_draw_biome_layers` draws a clear-colour rect over the whole view, then the 100 % opaque sky (16×360 tiles, the full view),
  then far / mid / ground / front strips (368 of 360 rows). That is ≈ **3.0 screens ≈ 7.8 Mpx per frame** at 2400×1080. The
  clear rect is completely hidden by the opaque sky, so **one full screen (2.6 Mpx) of fill per frame is redundant**. That is
  about the same amount D1 + zoom adds even in its upper bound (+2.46 Mpx). Godot's canvas items are drawn with alpha blending
  (blend mode Mix), so I expect the phone GPU to shade the hidden rect too. That expectation is not verified on a phone.

## 3. Desktop GPU, render CPU and frame time (relative only)
| Run | GPU whole frame mean / p95 ms | render CPU mean / p95 ms | frame mean / p95 ms | GPU of unit sprites (view − view without units) |
|---|---|---|---|---|
| shipped 2400 | 0.337 / 0.653 | 0.432 / 0.523 | 2.447 / 2.896 | +0.013 |
| shipped 2400 (drift, last base run) | 0.320 / 0.643 | 0.402 / 0.485 | 2.290 / 2.778 | +0.022 |
| D1FULL 2400 | 0.336 / 0.659 | 0.419 / 0.503 | 2.328 / 2.778 | +0.018 |
| D1FULL + zoom 2400 | 0.342 / 0.666 | 0.422 / 0.495 | 2.399 / 2.778 | +0.018 |
| shipped 2340 | 0.335 / 0.659 | 0.434 / 0.521 | 2.489 / 3.030 | +0.005 |
| D1FULL 2340 | 0.349 / 0.678 | 0.450 / 0.552 | 2.504 / 3.030 | +0.008 |
| D1FULL + zoom 2340 | 0.348 / 0.660 | 0.446 / 0.520 | 2.523 / 2.816 | +0.019 |
| pre-R8 (1d359bc) 2400 | 0.355 / 0.685 | 0.451 / 0.538 | 2.470 / 2.819 | +0.013 |

- **The desktop cannot separate the variants.** The same build measured twice (shipped 2400, first and last run) differs by
  0.017 ms GPU, 0.030 ms render CPU and 0.16 ms frame mean. Every D1 / zoom difference is inside that drift. The unit sprites
  cost ≤ 0.022 ms of GPU in every run, even at 1.39 Mpx on screen, so this GPU's fill rate hides the whole question.
- Frame p50 was 2.381 ms in every run (timer quantisation at 1/420 s), so the table uses mean and p95.
- Draw calls: 58 whole frame / 9 battle view in all shipped, D1 and zoom runs. The page count is unchanged.

## 4. 04 R8 HUD layering at the same phone condition (2400×1080, scale 3)
| | whole frame | HUD alone | hud_top | card button | skill buttons |
|---|---|---|---|---|---|
| pre-R8 1d359bc | 65 | – | – | – | – |
| R8 ad47eda | **58** | 49 | **7** | **5** each | 2–3 |
- Targets (whole ≤ 100, hud_top ≤ 10, card ≤ 5) are **met at scale 3**. The breakdown shows every HUD child; the 4 Labels cost 0.
- At scale 2, 04 measured the same code at 1280×720 (04's file, 07:0x): frame 129, hud_top 53. The same commit costs 53 at 2×
  and 7 at 3×, which supports 04's glyph-cache-page explanation. At 2× the 12 px text is drawn from the 24 px cache (256² pages,
  about 100 glyphs each, about 183 HUD glyphs, so 2–4 pages). At 3× it is the 36 px cache (512² pages). So 1080-high phones
  are fine, but **720-high phones (1600×720, 1520×720; scale 2) will be at about 129**, the same as the desktop 1280×720 case.
  04's planned `FontFile.oversampling = 1.0` test targets exactly that.
- **Number readability:** 04's mock UI (`scenes/ui/ui_preview.tscn --capture`, 1280×720) before vs after 2de6668. Menu,
  round select, **HUD**, pause and threat-behind are **pixel-identical** (0 px differ). Threat-ahead and both result screens differ
  in 80 px inside a 21×40 px box: 40 px change from green to light and 40 px from light to green. The cause is the new order in
  `threat_marker.gd`: the arrow glyph is now drawn before the vector enemy stand-in where the two overlap. The distance text
  "%dm" is drawn last in both. The stand-in is drawn only when the ui_main icon is missing (as in the mock). No number pixel
  changed, so there is no readability regression.

## 5. Still needs a phone (not measurable here)
1. GPU frame time at r08 caps for shipped / D1FULL / D1FULL + zoom on a low-end phone, at 1080 high (scale 3) and 720 high
   (scale 2). Godot render GPU ms and SurfaceFlinger frame pacing, same seed. Needs 02's P10 APK with baked args.
2. Whether removing the redundant clear rect, and trimming quads, move the phone GPU time as the pixel counts predict.
3. The HUD at scale 2 on a 720p phone (draw calls and whether per-call cost matters there).
4. Thermal and frame pacing over a 15–20 min cap soak (ANDROID_PROFILING.md §6).

## 6. Reproduce
```
build\heavy\08-phone-fill-job.ps1:  & .\tools\perf\phone_fill_matrix.ps1 -Rev ad47eda -PreRev 1d359bc -Draft D1FULL -Windows @('2400x1080','2340x1080') -Zoom 1.3333333
& .\coordination\heavy_run_detached.ps1 -Label '08-phone-fill' -ScriptFile build\heavy\08-phone-fill-job.ps1
```
Output (git-ignored): `build/perf/phonefill_ad47eda_20261101-033429/` (summary.md/json, run01–08, breakdown_base, ui_base, ui_pre,
ui_diff.json). Static tables: `python tools/perf/sprite_fill_static.py --tree <copy> --tree <copy>`.
