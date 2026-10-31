# World zoom (k+1)/k behind a project setting, default off (03 A19, 04 R17-3/R18) — 2026-11-01

Owner: 02-engine. Nothing is switched on. Turning it on waits for 03's D1 art (32 px bodies) and 01's check of the
warning time (04 R18: an enemy is visible before it engages for 6.0 → 3.9 s mean at 4/3 in r06).

## What changed
- `App.world_zoom()` = (k+1)/k with k = `App.pixel_scale` (4/3 at k = 3, 3/2 at k = 2, 5/4 at k = 4), else 1.
  Switch: project setting `game/camera/world_zoom_plus_one` (project.godot `[game]`, **false**).
  Dev/test user args: `--world-zoom=on|off`, `--world-zoom-k=<k>`.
- `battle.gd _update_camera` (04 R18 notes applied): `cam.zoom`; the x clamp uses the visible world width
  view.x / zoom; `view.view_w`, `view_top`, `view_bottom` are the zoomed world rect; the ground row is fixed
  `GROUND_FROM_BOTTOM` = 70 view px above the view bottom (04 CamFix): cy = ground_y − (view.y / 2 − 70) / zoom, left
  unrounded when zoomed so (ground_y − cy) × zoom is a whole view px; drag-to-pan divides by the zoom.
  With zoom 1 the camera values are the same as before (cy rounded as before; ground_y 290 + 70 = 360).
- The HUD CanvasLayer is not zoomed. Damage numbers are world-space, so they grow with the zoom (1.56 → 2.08 mm at 4/3
  on a 393 dp phone, 04 R19).

## Captures (secondary monitor DISPLAY2, isolated APPDATA, r06 `--autoplay`, App seed)
DISPLAY2 is 1920×1080 (work area 1032 tall), so a k = 3 window (2340/2400×1080) does not fit. Phone framing at k = 3 was
therefore emulated in k = 2 windows with `--world-zoom-k=3` (zoom 4/3): the visible world rect is the phone's, but art
pixels are 2.67 device px in these captures (uneven columns, as 04 noted), so judge framing, not pixel sharpness.
`k2_800x360` is a true k = 2 run (zoom 3/2) for the pixel-grid check.

Camera line printed by the game at each capture (`[App] camera …`):
| capture | window | view | zoom | visible world | ground row (view px from top; bottom) |
|---|---|---|---|---|---|
| off_800x360 | 1600×720 | 800×360 | 1 | 800 × 360 | 290 (360) |
| k3_640x360 (1920×1080 phone) | 1280×720 | 640×360 | 4/3 | 480 × 270 | 290 (360) |
| k3_780x360 (2340×1080 phone) | 1560×720 | 780×360 | 4/3 | 585 × 270 | 290 (360) |
| k3_800x360 (2400×1080 phone) | 1600×720 | 800×360 | 4/3 | 600 × 270 | 290 (360) |
| k2_800x360 (true k = 2) | 1600×720 | 800×360 | 3/2 | 533 × 240 | 290 (360) |
The ground row stays 70 view px above the bottom in every case, so the bottom HUD row keeps its gap.

Pixel-scale uniformity (03's `tools/art/scale_uniformity.py`, t = 46 s frames, units band):
| capture | dominant run | odd runs | blend |
|---|---|---|---|
| off_800x360 | 2 px | 0.1 % | 0.00 % |
| k2_800x360 (zoom 3/2) | 3 px | **11.8 %** | 0.00 % |
| k3_800x360 emulated (4/3 in a k = 2 window) | 3 px | 60.9 % | 0.00 % (expected: 2.67 px per art px) |
At a true k = 2 the dominant run is the expected 3 px with no blending, but 11.8 % of runs are not multiples of 3.
Units and their pivots are drawn at whole world px; a likely source is the parallax biome layers, which sit at fractional
world positions and snap on the 2-px view grid, so their texel grid is offset by 1–2 device px from the units'. Not
verified; 03 may want to check the frames with its tool before the switch is turned on.
Observation for 03: zoomed, the visible world is 270 (or 240) px tall instead of 360, so the far-town strip at the top of
the meadow biome sits behind the top HUD bar and the sky band is not visible.

Files: `world_zoom/` (frames at t = 46 s). Frames with units on screen were planned (t = 90/120 s) but not made: two blue
screens during GPU work on this PC (23:08, 03:55) made visible runs "only when needed", and the t = 46 s frames already
show the framing and the ground row.

## Why the capture job `02-zoom-caps` ended with exit 1 twice (heavy_run.log)
- 02:35–02:38: the job's selftest gate failed on my own parse error in battle.gd (`var cy :=` from an untyped
  `view.ground_y`), so no capture ran. Fixed at 02:43 (`var cy: float = float(view.ground_y) - …`).
- 03:14–03:25: selftest PASS and all 5 captures exit 0. The exit 1 came from the job's last step, 04's UI integration on
  the shared tree: 48/1, "menu draws the ko logo (mode=text)". My files do not touch the menu; 03's art (logo redraw
  700692d) and uncommitted atlases plus the stale main-tree import are the likely cause. Re-checked on a clean HEAD snapshot
  in job `02-verify` (result in the 02 handoff).
Note on the t = 46 s frames: the lane is empty apart from the hero and a worker because the fixed competent bot
(bot_stall_20261101.md) buys its 5 workers before it deploys troops when no enemy is near its base.

## Clean-snapshot check (heavy job `02-verify`, 07:06–07:11 KST, headless, private APPDATA)
`git archive` of HEAD 3f70d8f + 02's files (bot_player.gd, battle.gd, app.gd, content.gd, project.godot, 2 diag scripts):
selftest PASS (77/77 scripts); 04 UI integration **49/0** (the 48/1 logo failure was the shared tree, not this change);
07 acceptance.gd `--only=sim,flow,save,faults` PASS 106 / FAIL 0. 10 AC1: CRLF data (2,758 CR bytes) and LF data (0 CR) both
give c1-989c3422c910 = content_version.py `lf` for HEAD.
