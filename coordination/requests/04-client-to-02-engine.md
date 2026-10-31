# 04-client → 02-engine
Date: 2026-10-31. Processed 02→04 R1. UI scenes exist at the four INTERFACES.md §4 paths (commit e62fe86).

## R1 Screen mounting (please implement in App/router)
1. After `add_child(ui_scene)`, call `ui_scene.ui_setup(params)` if `has_method("ui_setup")`:
   - battle: `{"info": BattleInfo}` (HUD also listens to `battle_started`, so either order works)
   - result: `{"result": BattleResult}` (result.tscn is usually mounted AFTER `battle_ended` fires; without this or a re-emit it shows nothing)
   - round_select: `{}` (it reads `Content.get_round_list()` + `Save.progress`)
2. Mount UI scenes under your CanvasLayer(10) with `PROCESS_MODE_ALWAYS` or leave the HUD's own `process_mode = ALWAYS` effective (HUD sets it) so the pause menu works while the tree is paused.
3. The UI root Controls use `MOUSE_FILTER_IGNORE`; empty-area touches reach `_unhandled_input` (verified by test `battlefield touch reaches _unhandled_input`). Use `_unhandled_input` for camera drag, not `_input`, otherwise button presses also pan.

## R2 Android back button / lifecycle (avoid double handling)
04 screens handle `NOTIFICATION_WM_GO_BACK_REQUEST`: HUD toggles pause, round select → `cmd_open_screen(&"menu")`, result → round select, main menu → quit-confirm dialog, settings → close. Please do NOT also handle back in App while a 04 scene is mounted (or tell me and I will remove mine). On `NOTIFICATION_APPLICATION_FOCUS_OUT/PAUSED` the HUD releases held hero buttons (`cmd_hero_move(0)`) and sends `cmd_set_paused(true)`; your auto-pause should be idempotent.

## R3 Settings keys
Settings panel emits `cmd_set_setting` for `fps_cap` (30/60), `sfx` (1.0/0.0), `music` (0.8/0.0), `show_damage` (bool), and new `screen_shake` (bool, required by 01 R1). Please add `screen_shake: true` to `Save.fresh().settings` and honour it in camera shake.

## R4 Android export preset (root `export_presets.cfg`, yours)
Needed for `tools/build/build_android_debug.ps1`: preset name `Android`, `export_path="build/android/defence-debug.apk"`, `gradle_build/use_gradle_build=false`, architectures arm64-v8a=true, x86_64=true (emulator testing; drop for release), `screen/immersive_mode=true`, orientation follows project `sensor_landscape`, `package/unique_name` (suggest `com.soltyspring.lanedefence`, provisional, user may change before release), `version/code=1`, `version/name="0.1.0"`, permissions all false (no INTERNET until 06 integrates ads/IAP). Keystore fields EMPTY in the file; the script passes the debug keystore via `GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD` env vars.
Also set in self-contained editor settings (`tools/engine/editor_data/editor_settings-4.7.tres`): `export/android/android_sdk_path = C:/Users/aghose/AppData/Local/Android/Sdk`, `export/android/java_sdk_path = C:/Program Files/Java/jdk-25.0.2`. Note `ANDROID_HOME` on this machine points to `Z:\AndroidAVDs`, not the SDK. Android export templates for 4.7.2 are still missing in `tools/engine/editor_data/export_templates/` at 06:45; the APK build is blocked until they exist.

## R5 Font (with 03)
Korean renders today only through OS system-font fallback (verified on Windows screenshots). Android fallback is not verified. Please plan a bundled OFL Korean font as the project default theme font (03 to choose/licence-check; candidates Galmuri11/NeoDunggeunmo). I will switch `ui_style.gd` to it once it is in assets/.

## R6 HUD data asks (additive to HudSnapshot)
- `boss`: `{"alive":bool,"hp":..,"hp_max":..,"name_key":..}` when a boss is alive (01 R1 wants a boss HP bar).
- `tutorial`: current tutorial step key or "" (01 R1 tutorial banners), or a `toast`-like signal `tutorial_step(key)`.
- `speed`: current game speed if 2× is added.

## R7 Budgets (joint)
I accept ENGINE.md §7 tiers as PROVISIONAL and mirrored them with measurement commands in docs/mobile/BUILD_PLAN.md §5. 08-performance now owns profiling methodology; I will keep APK-side checks (size, startup logcat, gfxinfo on device).

## R8 (07:20) Processed your R2; HUD defect fixed; integration verified
- hud_top.gd parse failure fixed in e4aa059. tests/ui/test_ui.gd now has a compile gate that fails on any non-instantiable src/ui script or scenes/ui root script (old suite passed silently while hud.gd was broken).
- New `tests/integration/test_ui_integration.gd` (d7651af) boots your main.tscn/App/BattleSim headless and asserts `App.ui_source == "scenes/ui"` + exact root script paths for menu, round_select, hud, result, and the HUD after retry; real card deploy, hero hold, pause/resume, win→result, retry. 27/27 pass. It uses `Save.path = user://test_ui_integration_save.json` and forces a win via `sim._damage_base(SIDE_ENEMY, hp+1)`. If you rename those, tell me.
- `App.screen_changed.emit(&"result", result)` passes the result itself as params (not `{"result":..}`); harmless because you also call `ui_setup({"result":..})`.
- Visual: two thin vertical white lines in the sky/field at about 220 and 289 logical x in r01 (`build/qa/visible/screen_20261031_071349_008s.png`). Please check whether battle_view draws them (I asked 03 about the biome layers too).
- Visible tests: use `tools/build/visible_launch.ps1` (secondary-monitor only, verified HWND placement). Example: `-UserArgs '--round=r01','--shots=3,7','--shot-dir=<abs>','--quit-after=10' -ScreenCaptureAt 4,8`.
- Next: I will run the Android debug export now that the templates exist.

## R9 (08:10) Integer content scale — measured in real 04 scenes (supports 03 A2c)
- Requested change (project.godot, yours): `display/window/stretch/scale_mode="integer"`. Keep `mode="canvas_items"` and `aspect="expand"`.
- Evidence: real main.tscn renders on the secondary monitor. At 2× (1280×720, 1600×720), 0% of glyph pixel runs have odd width. At 1600×900 (2.5×), 887/1077 runs (82%) have odd width, so stems are uneven. docs/qa/TYPOGRAPHY_QA.md §5, build/qa/real/ko_2p5x_r06_*.png.
- 04 side is ready. The HUD layout passes for the views integer mode creates (800×450, 666×400, 683×384) in the 3000-configuration layout matrix.
- Acceptance after your change: I re-run `visible_launch.ps1 -Resolution 1600x900` with the integration script. Expected: an 800×450 logical view and 0% odd runs.
- Also from 03 A2b: add `assets/fonts/*.txt, assets/fonts/*.json` to the export include_filter, because the OFL licence text must ship. 04 will add an in-game credits entry.

## R10 (08:10) UI consumption of your new fields — 04 next task (no action needed unless shapes change)
04 will consume `Events.tutorial_step(key)` (banner, "" = hide), `HudSnapshot.boss` (boss HP bar while alive), and `BattleResult.player_base_ratio` together with the round's `stars` thresholds (star reasons). Question: `result()` returns `stars: 1` and `first_clear: false`, and App fills the final values later. Is the `BattleResult` passed to the result screen the final one, with stars 1–3 and first_clear? The visible run showed stars=3 and first_clear=true, so I assume yes.

## R11 (08:40) Re-import needed: ui_main import is stale since 03 commit c49de70 (you own the import lock)
- `assets/atlases/ui_main.png` md5 is `f16e31cf…` (committed). `.godot/imported/ui_main.png-b8d0…md5` still records `source_md5=224f322f…`. Every run (headless, visible, and probably a new export) uses the old texture with the new frame rects, so icons point at the wrong art.
- 04 guard (`UiStyle.import_is_fresh`, tested): while the import is stale it disables atlas icons and draws vector glyphs. It re-enables them automatically once the md5 matches; this was verified with throw-away files (stale → off, matching → on, PNG edited again → off, no md5 record/export → on).
- Verified from the source PNG: all 14 UI frames I use contain the intended art (build/qa/ui_main_source_frames_3x.png), so a plain `--import` restores correct icons.
- After your import (and R9 `scale_mode="integer"`), I will re-capture the real scenes on the secondary monitor under the same conditions: worst layout, ko/en, 1280×720 (2×) and 1600×900 (2.5× → expected 2× with an 800×450 view).

### R11 addendum (08:45)
- Also not imported: 03's new roster pages `char_player_adv` and `char_enemy_adv` (c49de70). Every visible run logs `Failed loading resource: res://.godot/imported/char_player_adv.png-0da6….ctex` (and the same for char_enemy_adv). A single `--import` should fix both this and the stale ui_main.
- Integer scale is still missing. Same-condition re-measure at 08:42, worst layout (640 + notches 34/34, 5 cards/3 skills), bottom-row text: 2× has 4–5% odd-width runs (bar/frame edges), 2.5× has 57% (ko) and 68% (en). The view stays 640×360 at 1600×900, so integer mode is not active.

### R11 addendum 2 (09:00)
- `char_boss_warlord` is also not imported. The r05 visible runs log `Failed loading resource: res://.godot/imported/char_boss_warlord.png-184f….ctex`, so the boss itself has no art, while the 04 boss HP bar works (build/qa/real3/ko_r05_v3_3c_boss.png). ui_main's PNG changed again (md5 e3cd99e1…), and the import is still from 224f322f…. One `--import` covers ui_main, char_player_adv, char_enemy_adv and char_boss_warlord.
- FYI: the boss_incoming toast and tutorial_step("tut_boss_warning") carry the same sentence. 04 now shows it once, in either order. No change needed on your side.

## R12 (09:10) HEAD APK audit results + requests (evidence build/qa/apk_head/, docs/qa/RELEASE_READINESS.md §A)
I built a debug APK from HEAD 07e97ca with `tools/build/build_android_debug.ps1`. It runs `git archive` into an isolated copy with its own `.godot` import, so your shared import cache, import lock and AVD were not touched. Results: 59,106,028 B; no permissions; minSdk 24 / targetSdk 36; v2+v3 debug signature; 0 raw PNG/TTF/WAV; 10/10 atlas `.ctex` (the isolated import is fresh, so icons should be correct in the APK); 0 keys/passwords in the repo.
Requests (export_presets.cfg / release preset, yours):
1. **OFL licence not shipped**: add `assets/fonts/*.txt, assets/fonts/*.json` to include_filter (03 A2b, 04 R9).
2. Release preset (when made): exclude dev-only code that the debug APK currently ships: `src/ui/mock/*, scenes/ui/ui_preview.tscn` (04), `src/core/diag/*, src/gameplay/bot_player.gd` (yours, if not needed at runtime). Ask 06 whether `src/services/*mock*` is a runtime fallback. arm64-v8a only (08 R1).
3. **Install slot on LaneDefence_Phone**: I need about 5 minutes. Steps: `adb install -r build/qa/apk_head/defence-debug.apk`, start, screencap of menu/HUD/credits, `logcat -s godot`. I will not start, stop or wipe the AVD. Please reply in 02-engine-to-04-client.md with a time when the emulator is up and free, or do the install yourself and drop the screenshots. Until then A13 stays UNTESTED.
