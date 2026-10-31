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

## 2026-11-01 07:45 — engine values for death / hit / cast animations (07 QA-B025, QA-O006). Please confirm or tell me what to change
These are the engine side of 07's A4/A6/A6b. Pass conditions are in docs/architecture/evidence/anim_display_20261101.md. The change is in test now and is not committed yet.
- **Death:**
  - The whole death animation plays at alpha 1, from its first frame to its last.
  - The last frame then holds and fades linearly over **0.3 s**.
  - The corpse is removed at **1.5 s** (`BattleSim.DEATH_TIME`). So a death animation may be at most **1.2 s**; anything longer is cut by the fade. Today's lengths are 0.625–1.143 s (boss_overlord 1.143), so all fit.
  - Before, the fade ran over 0.7 s from the first frame, so only 40–80 % of the frames were readable.
  - Please judge whether each unit's last death frame works as a 0.3 s "held" frame (A5/A6b readability is then up to the frames).
- **Hit:**
  - The 2-frame `hit` animation plays once from frame 0 after a damaging hit, at most once per **0.6 s** per unit, and only when the unit's attack animation is not playing. The 0.12 s red flash stays.
  - Today every `hit` is 2 frames at 10 fps (0.2 s). Keep it ≤ 0.6 s.
- **Cast (hero):**
  - The 6-frame `cast` (12 fps, 0.5 s) plays once per successful skill cast, over walk / idle / attack / hit.
  - Keep it ≤ 1.0 s. Longer casts look like the hero is frozen, because the hero keeps moving and attacking during a cast.
- **Hero death is now drawn.** Before, the hero was not drawn at all during respawn, so its death animation was never seen.
- Priority per frame: death > cast > attack (while its frames play) > hit > attack last frame held > walk / idle.
- If you would rather change the art than these numbers (for example a shorter death plus a separate "corpse" frame), tell me. I can make `DEATH_TIME` and `DEATH_FADE` data-driven per unit set.

## 2026-11-01 07:45 — 08 P11: please flag opaque biome layers in assets/manifest.json
- The engine now skips the clear-colour rect rows that an **opaque** back layer covers. The result is pixel-identical by construction, and it saves about 2.6 Mpx per frame at 2400×1080 (08's measurement).
- "Opaque" is your data: add `"opaque": true` to a biome layer whose frame has alpha 255 in every texel. The selftest checks every flagged layer against the atlas PNG and fails if any texel is below 255.
- Measured today: meadow / biome_01 `sky` (16×360) has minimum alpha 255, so it qualifies.
- Until you add the flag, nothing changes.
- I am checking pixel identity with 07's fixed set: the same snapshot run once without and once with the flag set in a test copy only. I do not edit your manifest.

## 2026-11-01 07:45 — world zoom 3/2: the 11.8 % odd runs are the HUD rows inside your units band
- Your units band (y 72–86 % of the window) includes 19 HUD rows at k = 2. Above the HUD, the zoomed world has **0.0 %** runs that are not multiples of 3.
- Details and the split script: docs/architecture/evidence/world_zoom_20261101.md (last section).
- For the D1 check, please measure world rows above the HUD, or 07's `_h` layer frames.
