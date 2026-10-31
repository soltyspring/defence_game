# Lane zoom / bigger units: preview of the cost before a decision — 04-client

Date: 2026-10-31 19:50 KST. Codex review of e3c871c. **No decision is made here.** 01 (difficulty), 02 (camera) and 03 (sprites) decide.
Evidence: docs/qa/zoom_preview/ (3 captures + JSON per combo, text_screen_size.json).

## How
- `tests/integration/zoom_preview.gd`, run on DISPLAY2 from a clean `git archive` snapshot of origin/main **84c18ab**. The run uses an isolated APPDATA (10's isolated_godot.ps1 method, `visible_launch.ps1 -IsolateAppData`).
  - Log proof: `user_data_dir = %TEMP%/ui04_iso_zoom/Godot/app_userdata/Lane Defence`.
  - The real save.json and .bak hashes are unchanged before and after (E4263BE6…, 9E9F05BF…).
- All changes are made at runtime in that process only. No 02 or 03 file was edited, in the tree or in the snapshot.
  - **current**: the game as it is.
  - **zoom**: world camera zoom 4/3 (02 option B). The HUD is unchanged, and the ground row stays 70 px above the view bottom, so the HUD gap is unchanged.
  - **zoom_big**: zoom 4/3, plus regular unit sprites upscaled ×1.5 nearest. That gives ≈ 32 px bodies, a stand-in for 03's redraw (option A). Hero, siege and bosses are not scaled.
- Same battle in every combo: seed 4242, r06, 17 scripted deploys at fixed sim times, hero kept 150 px behind the front. The sim is stepped by the script (battle.time_scale = 0), and all three runs end with 19 kills at t = 90 s. The camera x is snapped to hero + 60 in all combos, so the numbers are comparable; the real game eases toward it.
- **393×873 dp condition:** 800×360 view (1080×2400 at density 2.75 → k=3), 48 dp = 44 px touch target, notches 34/34. The capture window is 1600×720 (k=2, same 800×360 layout), because a 2400×1080 window does not fit DISPLAY2.
  - In the *zoom* capture, art pixels are therefore 2.67 device px (uneven 2/3 px columns). On the real k=3 phone they would be exactly 4 px.
  - *zoom_big* is exact in both (2 view px per original art px).
- Metrics are sampled every 0.25 s of sim time over 90 s (360 samples). Captures are at t = 46.0 s, with 0 % dark samples, so none is invalid.

## Results (one table)
| metric (r06, 0–90 s, 393 dp phone) | current | zoom 4/3 | zoom 4/3 + big units |
|---|---|---|---|
| lane width on screen (world px) | 800 | 600 | 600 |
| soldier body height (21 art px) | 21 px = **3.6 mm** | 28 px = 4.9 mm | 42 px = **7.3 mm** |
| hero body (32 art px, not upscaled) | 5.5 mm | 7.4 mm | 7.4 mm |
| lane damage numbers (Galmuri9 10, world space) | 1.56 mm | 2.08 mm | 2.08 mm |
| enemy visible before it engages, mean / median (s) | **6.0 / 5.3** | **3.9 / 3.3** | 3.9 / 3.3 |
| enemies that engaged while off screen | 0 of 21 | 0 of 21 | 0 of 21 |
| allies on screen, mean / max | 5.6 / 10 | 5.2 / 9 | 5.2 / 9 |
| enemies on screen, mean / max | 3.0 / 7 | 2.5 / 6 | 2.5 / 6 |
| both sides on screen at once (% of time) | 73.6 % | 72.5 % | 72.5 % |
| player base on screen (% of time) | 16.1 % | 13.3 % | 13.3 % |
| enemy base (nest) on screen (% of time) | 0 % | 0 % | 0 % |
| off-screen marker needed (any, % of time) | 100 % | 100 % | 100 % |
| — of which enemy-ahead marker | 15.6 % | 16.7 % | 16.7 % |
| — nest marker | 84.4 % | 83.3 % | 83.3 % |
| — enemy-behind marker (left) | 0 % | 0 % | 0 % |
| capture | zoom_preview_current.png | zoom_preview_zoom.png | zoom_preview_zoom_big.png |

Reading:
- The main cost of the zoom is warning time. A new enemy is on screen for about 2 s less (6.0 → 3.9 s mean) before it reaches the line. The counts on screen drop by about 10–15 %. The chance to see both sides together barely changes (73.6 → 72.5 %).
- The bigger sprites cost nothing in these metrics, because positions are unchanged. They are what makes soldiers pass 6 mm (7.3 mm); zoom alone gives 4.9 mm.
- The nest is never on screen in this r06 run (the hero stays with the army, far from x 1860), so a nest marker is needed in every sample. This is independent of the zoom.
- Not covered: human play, other rounds, r01's shorter lane, the auto camera (02 R8), and device viewing.

## Text height (same mm conversion; line 1.7 mm ink = Hangul of Android's 12 sp minimum, a working criterion)
`python tools/build/text_screen_size.py` (FreeType ink box of the bundled fonts at the UI's grid sizes):
| HUD text | font / px | ink px | 360 dp | 393 dp | 412 dp |
|---|---|---|---|---|---|
| resource name 밀가루 / 기력 | Galmuri11 12 | 11 | 1.75 | 1.90 | 2.00 |
| resource amount (bold) | Galmuri11-Bold 12 | 11 | 1.75 | 1.90 | 2.00 |
| resource cap / income | Galmuri9 10 | 9 | **1.43** | **1.56** | **1.63** |
| base HP numbers 1500/1500 | Galmuri9 10 | 9 | **1.43** | **1.56** | **1.63** |
| army count 5/36 | Galmuri9 10 | 9 | **1.43** | **1.56** | **1.63** |
| wave line, boss name, card names, toast, hint, marker distance | Galmuri11 12 | 11 | 1.75 | 1.90 | 2.00 |
| card cost, card badge | Galmuri9 10 | 9 | **1.43** | **1.56** | **1.63** |
| respawn countdown | Galmuri9 20 | 18 | 2.86 | 3.12 | 3.27 |
| banner | Galmuri11-Bold 24 | 22 | 3.49 | 3.81 | 3.99 |
| lane damage numbers (02 battle_view) | Galmuri9 10 | 9 | **1.43** | **1.56** | **1.63** |

Every Galmuri9 10 px number is under the line on all three phones: base HP, card cost, income, army count, badges, and damage numbers (damage numbers only at zoom 1). The 12 px Hangul labels pass, narrowly on 360 dp (1.75). This is a 04 item. The fix is Galmuri9 20 or Galmuri11 12 for those numbers, which needs layout room (cards are 56 px tall). Not changed yet: it is not part of this preview.
