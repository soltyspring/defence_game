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

## R13 (16:05) `wave_cleared` signal for the first-wave-broken banner (09 R09-04-7, 01 D16 + D21)
Please add to src/core/events.gd: `signal wave_cleared(info: Dictionary)` with `info = {"index": int, "t": float}`. Emit it once per scripted wave when every unit spawned by that wave is dead (D21). Exclude `pressure` waves and trickle units. `index` uses the same numbering as `HudSnapshot.wave.index` without pressure waves.
04 is ready (0590e7a): the HUD connects to it automatically if the signal exists (`has_signal` check), shows "첫 웨이브 격파!" / "First wave broken!" for index 1 only, once per battle, for 1.8 s, and does not cover base bars or cards (tested with a test bus that has the signal). Until you add it, the banner is inert, so nothing is shown.
Acceptance on your side: r01 headless with the competent bot → wave_cleared(index 1) between 25 and 45 s (09's window). Then I capture it on DISPLAY2.
Also FYI: the shared tree still had your uncommitted src/core/app.gd at 15:50 (breaks App.boot). 04 now tests on HEAD snapshots (`tools/build/verify_and_publish.ps1`).

## R14 (16:25) Upgrade purchase contract, as proposed by 10 (DATA_AND_BACKEND_ANALYSIS §9.4)
Please implement in src/core/save.gd: `func buy_upgrade(upgrade_id: String, to_level: int) -> String`. Codes: ok | already_applied | max_level | not_enough_coins | unknown_id | locked | save_failed | read_only. Validate first. Apply coins and level together, and roll BOTH back if the write fails, as record_result does. A repeated identical `to_level` returns already_applied. Then emit `progress_changed`. 10's probe part C (C1–C5) is the acceptance test.
04 is ready (6051b3c): `src/ui/upgrade_panel.gd` (menu / round select / result → "강화"). It calls only `Save.buy_upgrade(id, level+1)` and never edits `Save.progress`. Each code gets its own message, kind and glyph: ● ok, ▲ not_enough_coins (shows the missing amount), ※ max_level (no call), × save_failed/read_only ("gold and level unchanged"). Until the method exists the buttons are disabled with "강화 기능 준비 중입니다". Verified on the real engine: `upgrade buy inactive with notice (Save.buy_upgrade missing)`.
Also needed for "only unlocked targets": `Content.get_unit(id)` returns `spearman` for unknown ids. 04 handles this (it compares ids), but an explicit `has_unit(id)` would be cleaner. Optional.

## R15 (17:45) Q4 launcher name + release preset (R12 update). Exact keys; nothing changed in your files
User decision Q4 (2026-10-31 17:19 KST): home-screen name ko "빵집 기사단", en "Bakery Knights". In-game and store titles stay the full working title; the final store name waits for KIPRIS.
1. **Launcher label (please set):**
   - `export_presets.cfg` `[preset.0.options]`: `package/name="Bakery Knights"`
   - `project.godot` `[application]`, new key:
     ```
     config/name_localized={
     "en": "Bakery Knights",
     "ko": "빵집 기사단"
     }
     ```
   - Why both: Godot 4.7.2 `_fix_resources` (platform/android/export/export_plugin.cpp, tag 4.7.2-stable) writes the default label from `package/name` (else `config/name`). The prebuilt template has 89 label slots (`godot-project-name-<lang>`); each gets `name_localized[lang]`, else the default. So without `package/name`, ja/de/en-GB/… would still read "Lane Defence".
   - **Proven on a real export, not in your files:** `tools/build/build_android_debug.ps1 -ProbeQ4Label -OutDir build\qa\apk_q4probe` sets exactly these keys in its isolated `git archive` copy only. aapt2 on that APK: default 'Bakery Knights', ko '빵집 기사단', en 'Bakery Knights', 88× 'Bakery Knights' + 1× '빵집 기사단' → OK. Check after your change: `.\tools\build\check_launcher_label.ps1` (exit 0 OK, 3 WAITING, 1 MISMATCH; reads config and every APK in build/qa/apk_head, build/android, build/release). Today it reports WAITING (config and both APKs still "Lane Defence"). 06's `tests/services` launcher_label group checks the same.
2. **Desktop save folder (06's point), please decide:** `user://` on Windows is `%APPDATA%\Godot\app_userdata\<config/name>` (core/os/os.cpp `get_user_data_dir`). Android uses the package's files dir, so phones are unaffected either way.
   - Option A (recommended now): keep `config/name="Lane Defence"`. The Android label comes from package/name + name_localized only, so desktop saves and test `user://` dirs stay where they are. Cost: the desktop window title / editor project name stays "Lane Defence" (desktop is not a release target).
   - Option B: rename `config/name` to "Bakery Knights" and keep the old folder with `config/use_custom_user_dir=true` + `config/custom_user_dir_name="Godot/app_userdata/Lane Defence"` (os.cpp allows paths in the custom name, so the same folder results). Not tested by me.
   - Do NOT change `package/unique_name` (com.soltyspring.lanedefence) as part of this: it is the install identity (saves, updates). Whether the ID should lose "lanedefence" before the first store upload is a separate user decision.
3. **Release preset (R12-2, corrected):** R12-1 is verified: the probe APK ships `assets/fonts/OFL-Galmuri.txt` and `fonts_provenance.json`. Still shipped dev-only: `src/ui/mock/*`, `scenes/ui/ui_preview.tscn` (04), `src/core/diag/*` (yours), `src/services/**/mock_*` (06 decides). **Correction:** keep `src/gameplay/bot_player.gd`, because `src/gameplay/battle.gd` preloads it. Proposed release preset `[preset.1]` "Android Release": same as preset.0 plus `exclude_filter="tools/*, build/*, docs/*, coordination/*, tests/*, src/ui/mock/*, scenes/ui/ui_preview.tscn, src/core/diag/*"`, `architectures/x86_64=false` (arm64-v8a only, 08 R1), release keystore from env/editor settings only. No runtime file of mine references the mock/preview files (grep: only ui_preview.tscn → src/ui/mock/ui_preview.gd).
4. Emulator slot (R12-3) still open; not during 08's 18:00–18:30 window.

## R16 (18:05) HudSnapshot `threat` field for the off-screen nest/enemy markers (03 A11, your R8 option B)
04 wrote the markers (src/ui/threat_marker.gd, HUD wiring, layout, tests; pushed in 31164c8 at 18:35 after the gate: UI 3387/0, integration 48/0). They stay hidden until the snapshot carries this field, so nothing changes in the game before you add it. Proposed field, computed in `battle.gd._publish()` (it knows the camera):
```
s["threat"] = {
  "view_left": float,     # world x of the left screen edge  (cam_x - visible_width/2)
  "view_right": float,    # world x of the right screen edge (cam_x + visible_width/2)
  "nest_left": float,     # world x of the enemy base's DRAWN left edge (03 A11: x 1012 in r01)
  "enemy_visible": bool,  # any alive enemy unit (not towers/bases) with view_left <= x <= view_right
  "enemy_right": float,   # x of the nearest alive enemy unit with x > view_right; OMIT the key if none
  "enemy_left": float,    # x of the nearest alive enemy unit with x < view_left; OMIT the key if none
}
```
- UI rules (pure, tested): right marker = enemy if none is on screen and one is to the right, else nest while < 24 px of it is on screen (03's contrast limit); left marker = enemy behind the camera. Distance = metres past the screen edge, 1 m = 16 px (lane 1600 = 100 m), clamped 1–999.
- Layout assumption: the ground row is 70 px above the view bottom in every view height (your ground_y 290 at 360, bottom-anchored camera). If the auto camera (your R8 option A) changes that, please add `"ground_screen_y"` to the field and I will use it.
- Reply to your R8: an auto camera does not conflict with the HUD layout (all HUD rects are screen-space). For hold-to-move, please let the hero's own movement win while a move button is held (camera eases only when no move button is held), otherwise the hero seems to slide under a moving camera. The markers work with either camera.
- R15 status (seen at origin): package/name + name_localized are in (4b5926d) and my `check_launcher_label.ps1` reads the config as OK. My local APKs are older, so the APK part stays WAITING until I rebuild after 18:30. Release preset (R15 item 3) is on your handoff list, not done yet.

## R17 (19:25) Lane framing: bottom safe inset + unit size (07 QA-J1). Proposal with numbers; nothing changed in your files
Details: docs/qa/LANE_OCCLUSION.md (measured with tests/integration/lane_occlusion_probe.gd).
1. **Bottom HUD vs lane: fixed on the 04 side for desktop (45c05f0).** Windows reported its taskbar work area as the safe area, which lifted the HUD row 16 px into the lane (11–13 px of unit sprites covered). Now 0 px in every condition: three phone shapes 800×360, 2.5× window 800×450, fullscreen 640×360. The lowest sprite bottom is 296–297 against the HUD row top at 300 (390 at 450).
2. **Request:** a phone that reports a real bottom inset still loses 12 px (measured with a 16 px inset). The HUD cannot sit in the inset, so please raise the ground row by the bottom safe inset in `_update_camera`: `ground_screen_y = view.y − 70 − bottom_inset`, where bottom_inset = view.y − SafeArea.safe_rect().end.y (logical px; 04's `src/ui/safe_area.gd` gives it, mobile only). Then tell me and I add `ground_screen_y` to my threat-marker layout (or publish it in `snapshot.threat`, R16).
3. **Unit size:** 12 of 14 units are under 6 mm body height on 360/393/412 dp phones (soldiers 3.0–3.8 mm). Option B for you: a world-only camera zoom of (k+1)/k, i.e. 4/3 at k=3, 3/2 at k=2, 5/4 at k=4. The HUD stays at k, and every art px becomes exactly k+1 device px, so the pixel grid stays exact. The lane on screen becomes 600 world px wide at k=3. Together with 03 redrawing soldiers at ~32 px bodies (option A), soldiers reach 6.8–7.7 mm. B alone gives 4.4–5.1 mm. Please say whether a world zoom fits your camera code and the R8 auto camera; nothing is measured on a device yet.

## R18 (19:50) Preview of R17-3 (world zoom 4/3) on the real engine: no decision, data for you and 01 (docs/qa/ZOOM_PREVIEW.md)
- Runtime-only harness (tests/integration/zoom_preview.gd). I did not edit any of your files. It sets `cam.zoom` 4/3 after your `_update_camera` each frame, keeps the ground 70 px above the view bottom (cam.y = ground_y − (view.y/2 − 70)/zoom), and sets view_w/cam_x/view_top for drawing. Same seeded r06 battle in every combo, sim stepped by the script.
- Results, 393 dp phone (800×360 view), 0–90 s:
  - Lane on screen: 800 → 600 world px.
  - Enemy visible before it engages: 6.0 → 3.9 s mean.
  - Units on screen: allies 5.6 → 5.2, enemies 3.0 → 2.5 (mean).
  - Both sides on screen together: 73.6 → 72.5 %. Player base on screen: 16 → 13 %.
  - Soldier body: 3.6 → 4.9 mm, and 7.3 mm with 03's bigger sprites.
- Things I found that matter if you implement it: `_update_camera` clamps with the full view width, so the clamp must use view.x/zoom. `view.view_w` must be the zoomed width, or the parallax/biome strips are drawn for the wrong width (harmless overdraw, but culling would break). The vertical anchor must be recomputed, otherwise the ground drops 37 px into the HUD at zoom 4/3.
- Not decided: whether to zoom is yours with 01; 03 owns sprite size.
