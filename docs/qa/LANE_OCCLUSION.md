# Lane occlusion and unit size on phones — 04-client

Date: 2026-10-31 19:25 KST. Codex follow-up to 13aade1 (store captures): "units are small (07 QA-J1) and the bottom HUD row covers lane units".
Evidence folder: docs/qa/lane_occlusion/ (before_/after_ captures + JSON per condition, unit_screen_size.json).

## 1. Bottom HUD row vs lane units (measured on the real engine)
Tool: `tests/integration/lane_occlusion_probe.gd` (visible run on DISPLAY2). It runs r08 or r03 with every card deployed twice and fast-forwards to the first contact, then samples every frame for 6 s. Each unit's sprite rect is computed from the same AnimRec frame and pivot the battle view draws with. For every sprite, the covered px are the rows below the top of any HUD bottom-row rect (worker, cards, move buttons, skills) that overlaps it horizontally.

Phone shapes are emulated as 1080×2400 landscape, which gives k=3 and an 800×360 view. 48 dp converts to 48 / 44 / 42 logical px at density 3.0 / 2.75 / 2.625 (`--target`). The window is 1600×720, so the same 800×360 view is shown at k=2. Notches are 34/34. "2.5×" is a 1600×900 window: the integer scale rule gives k=2 and an 800×450 view.

| condition | view | safe area | lowest sprite bottom y | HUD row top y | covered px (worst) | samples covered |
|---|---|---|---|---|---|---|
| **before** 360×800 dp (target 48) | 800×360 | 34,0,34,0 | 296 | 300 | 0 | 0 / 3001 |
| **before** 393×873 dp (44) | 800×360 | 34,0,34,0 | 296 | 300 | 0 | 0 / 3001 |
| **before** 412×915 dp (42) | 800×360 | 34,0,34,0 | 297 | 300 | 0 | 0 / 3001 |
| **before** 2.5× (1600×900) | 800×450 | 34,0,34,0 | 386 | 390 | 0 | 0 / 3000 |
| **before** store setup (fullscreen 1920×1080 on DISPLAY2, r08) | 640×360 | **0,0,0,16 (taskbar)** | 297 | **284** | **13** | 2637 / 2701 |
| **before** store setup (r03) | 640×360 | 0,0,0,16 | 295 | 284 | **11** | 1976 / 3020 |
| **before** phone with a 16 px bottom inset (360×800 dp) | 800×360 | 34,0,34,16 | 296 | 284 | **12** | 2139 / 3001 |
| **after 45c05f0** 360×800 dp | 800×360 | 34,0,34,0 | 296 | 300 | **0** | 0 / 3001 |
| **after** 393×873 dp | 800×360 | 34,0,34,0 | 297 | 300 | **0** | 0 / 3001 |
| **after** 412×915 dp | 800×360 | 34,0,34,0 | 297 | 300 | **0** | 0 / 3001 |
| **after** 2.5× (1600×900) | 800×450 | 34,0,34,0 | 387 | 390 | **0** | 0 / 3001 |
| **after** store setup (fullscreen, r08) | 640×360 | 0,0,0,0 | 296 | 300 | **0** | 0 / 2709 |
| **after** store setup (r03) | 640×360 | 0,0,0,0 | 297 | 300 | **0** | 0 / 3020 |

Findings:
- **Cause of the covered units in the 13aade1 store images:** on Windows, `DisplayServer.get_display_safe_area()` returns the monitor's work area, which excludes the 48 px taskbar. In borderless fullscreen on a 1080 px monitor this became a 16 logical px bottom inset. The HUD row moved up 16 px into the lane and covered 11–13 px of most unit sprites.
- **Fix (45c05f0, src/ui/safe_area.gd):** the display safe area is used only when `OS.has_feature("mobile")`. Desktop uses the full view. Unit test `test_safe_area_display` covers the desktop work-area case, a phone cutout (102 px at k=3 → 34 px), an implausible report, and HUD-row top ≥ lowest sprite for the three phone targets and 800×450. Gate: UI 3395/0, integration 48/0.
- **Phones without a bottom inset (the three shapes, immersive landscape):** 0 px before and after. The lowest sprite bottom is the ground row (view.y − 70) + lane_y max 6 + 1 px rounding, which leaves 3 px to the HUD row.
- **Not fixed by 04:** a phone that reports a real bottom inset (e.g. a gesture area of 16 px) still gets 12 px covered. The HUD must stay out of the inset (touch targets in a gesture area conflict with the system), so the lane has to move up. That is the camera's vertical framing (02, `battle.gd._update_camera`: ground row = view.y − 70). Requested from 02 (R17): lift the ground row by the bottom safe inset. Not measured on a real device: no phone here.
- Store captures were retaken after the fix: every frame records HUD row top = 300 (store_capture_*.json).

## 2. Unit body height on the three phones
Tool: `python tools/build/unit_screen_size.py` (no Godot). Body height is the alpha bounding box of the idle and walk frames in the atlas PNGs. The game's integer scale rule gives k=3 on 1080×2400 (1440×3200 @ 3.5 gives the same mm with k=4). Physical px = body × k. mm = physical px / (density × 160) × 25.4, i.e. 0.159 / 0.173 / 0.181 mm per view px.

**Readability line used here: 6 mm body height**, which is about 1.0° of visual angle at a 33 cm viewing distance. This is a working criterion for this project, not a published standard.

| unit | frame h | body h (view px, % of 360) | 360×800 dp: phys px / mm | 393×873 dp | 412×915 dp | body px for 6 mm on 360 dp |
|---|---|---|---|---|---|---|
| hero_captain | 48 | 32 (8.9 %) | 96 / 5.1 (<6) | 96 / 5.5 (<6) | 96 / 5.8 (<6) | 38 |
| worker | 32 | 20 (5.6 %) | 60 / 3.2 (<6) | 60 / 3.5 (<6) | 60 / 3.6 (<6) | 38 |
| melee_basic (식빵병) | 32 | 21 (5.8 %) | 63 / 3.3 (<6) | 63 / 3.6 (<6) | 63 / 3.8 (<6) | 38 |
| ranged_basic (롤빵병) | 32 | 19 (5.3 %) | 57 / 3.0 (<6) | 57 / 3.3 (<6) | 57 / 3.5 (<6) | 38 |
| tank (통식빵) | 32 | 20 (5.6 %) | 60 / 3.2 (<6) | 60 / 3.5 (<6) | 60 / 3.6 (<6) | 38 |
| fast (프레첼) | 32 | 27 (7.5 %) | 81 / 4.3 (<6) | 81 / 4.7 (<6) | 81 / 4.9 (<6) | 38 |
| siege (화덕포) | 40 | 40 (11.1 %) | 120 / 6.3 | 120 / 6.9 | 120 / 7.3 | 38 |
| e_grunt | 32 | 19 (5.3 %) | 57 / 3.0 (<6) | 57 / 3.3 (<6) | 57 / 3.5 (<6) | 38 |
| e_spitter | 32 | 19 (5.3 %) | 57 / 3.0 (<6) | 57 / 3.3 (<6) | 57 / 3.5 (<6) | 38 |
| e_swarm | 24 | 15 (4.2 %) | 45 / 2.4 (<6) | 45 / 2.6 (<6) | 45 / 2.7 (<6) | 38 |
| e_brute | 48 | 24 (6.7 %) | 72 / 3.8 (<6) | 72 / 4.2 (<6) | 72 / 4.3 (<6) | 38 |
| e_bomber | 32 | 20 (5.6 %) | 60 / 3.2 (<6) | 60 / 3.5 (<6) | 60 / 3.6 (<6) | 38 |
| boss_warlord | 64 | 45 (12.5 %) | 135 / 7.1 | 135 / 7.8 | 135 / 8.2 | 38 |
| boss_overlord | 80 | 56 (15.6 %) | 168 / 8.9 | 168 / 9.7 | 168 / 10.2 | 38 |

12 of 14 units are under 6 mm on all three phones; only siege and the two bosses pass. The regular soldiers are 3.0–3.8 mm. To pass 6 mm on the smallest (360 dp) phone, a body needs ≥ 38 view px at zoom 1, i.e. about 1.8× today's 21 px.

Options (numbers from the same formula; 360 dp → 412 dp):
| option | owner | soldier body 21 px becomes | lane width on screen (800 px view) | pixel grid |
|---|---|---|---|---|
| A. redraw soldiers/enemies at 48 px frames with ~32 px bodies | 03 | 5.1 → 5.8 mm | unchanged 800 | exact |
| B. world-only camera zoom (k+1)/k: 4/3 at k=3, 3/2 at k=2, 5/4 at k=4 (HUD unchanged) | 02 | 4.4 → 5.1 mm | 600 world px at k=3 (533 at k=2) | exact (every art px = k+1 device px) |
| A + B | 03 + 02 | 6.8 → 7.7 mm | 600 | exact |
| C. world zoom 2 (6 device px per art px at k=3) | 02 | 6.7 → 7.6 mm | 400 | exact, but half the lane |

04 recommends A + B with 02's combat-aware camera (02 R8 option A). That is the only option here that passes 6 mm on every phone while keeping ¾ of today's lane width. It also needs the off-screen markers (04 31164c8, waiting for 02 R16), because less of the lane is visible. Not measured on a device; on-device viewing is the final check.
