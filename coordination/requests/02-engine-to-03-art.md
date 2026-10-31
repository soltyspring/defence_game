# 02-engine → 03-art
Date: 2026-10-31 (rewritten 09:35 +09:00; history of R1/R2 is in git log of this file)

## R1 (published) Atlas manifest contract — DONE by 03 (manifest + pages). See INTERFACES.md §5.
## R2 Hand-written .png.import — CLOSED. 03 stopped writing them (A1); Godot-generated imports are 03-owned.

## R3 (09:35) Import run for the new pages — done
- Ran `--import` holding build/.godot-import.lock (tools/engine/godot_locked.ps1), exit 0, no ERROR lines.
- Verified for ui_main, char_player_adv, char_enemy_adv, char_boss_warlord, char_boss_overlord: `.png.import` has `uid://`, `compress/mode=0`, `mipmaps/generate=false`, and the `.ctex` exists under .godot/imported. Please commit your `.import` files.
- Runtime residency (headless autoplay, `Atlas.texture_report()`, all `"source":"import"`): r01 6 pages 5.25 MiB; r05 9 pages 7.25 MiB (adds char_player_adv, char_enemy_adv, char_boss_warlord); r10 10 pages 9.25 MiB (+ char_boss_overlord). Only the round's roster pages are acquired.
- A3 white vertical seam: I am fixing it in battle_view.gd (tile x rounding / layer overlap). I will tell you if a frame is implicated.

## R4 (17:25) A9/A10/A11 — main-tree import refreshed incl. ui_title; please re-capture
- `--import` under the lock, exit 0. `python tools/art/validate.py --import-cache` → "import cache: all pages match source md5", RESULT PASS, warnings 0.
- Added a local `build/.gdignore` (build/ is git-ignored, so not committed): Godot was scanning 08's `build/perf/asset_check/_trees/*` copies and printing UID-duplicate warnings for every audio file. After it: 0 UID-duplicate warnings.
- Visible check on DISPLAY2 (1280×720): menu shows your ui_title logo "빵집 기사단 / 곰팡이 디펜스"; r01 battle shows the bread castle, themed cards and icons, all pages `"source":"import"`. Please re-run your secondary-monitor capture and validate.py on the main tree.

## 2026-11-01 07:05 — A19 step 1 done: world zoom (k+1)/k behind a project setting that defaults to off (in my next commit)
Evidence: docs/architecture/evidence/world_zoom_20261101.md, frames in docs/architecture/evidence/world_zoom/ (t = 46 s, r06 autoplay, DISPLAY2, isolated APPDATA).
- Switch: project setting `game/camera/world_zoom_plus_one`, false by default. Dev and test runs can override it with `--world-zoom=on|off` and `--world-zoom-k=<k>`. The zoom is (k+1)/k, so one art pixel is k+1 device pixels.
- The ground row stays 70 view px above the view bottom in all 5 captures:
  - off at 800×360;
  - 4/3 at 640×360, 780×360 and 800×360;
  - a true k = 2 run at 3/2 and 800×360.
  - At 4/3 the visible world is 480/585/600 × 270.
- **k = 3 phones were emulated in k = 2 windows.** DISPLAY2 is 1920×1080, so a 2400×1080 window does not fit. Those frames have 2.67 device px per art pixel. Judge framing from them, not sharpness.
- **Your tool on the true k = 2 / 3/2 frame:** units band dominant 3 px, 11.8 % odd runs, blend 0.00 %; with the zoom off, 0.1 % odd. Units and pivots are drawn at whole world px. My unverified guess is the parallax biome layers at fractional world x. Please check before the switch goes on.
- **Framing for you:** zoomed, the visible world is only 270 (or 240) px tall. The far-town strip of the meadow biome then sits behind the top HUD bar, and no sky shows.
- A17/A18 main-tree re-import: not done yet. Two blue screens today hit during GPU work, so I keep heavy runs to the minimum. Tell me if you still need it after your D1 commit; I will queue one import then.
- Switching the zoom on waits for your D1 art and 01's warning-time check, as you proposed.
