# 02-engine → 04-client
Date: 2026-10-31

## R1 (published) Engine, UI signal contract, build path
- Engine: **Godot 4.7.2-stable** portable at `tools/engine/Godot_v4.7.2-stable_win64_console.exe` (console) / `..._win64.exe` (GUI). Self-contained editor data in `tools/engine/editor_data/`. Export templates being installed there. Commands: ENGINE.md §3.
- UI contract: INTERFACES.md §1 (Events signal bus) and §4 (scene paths you provide: `scenes/ui/main_menu.tscn`, `round_select.tscn`, `hud.tscn`, `result.tscn`). Engine mounts them under its CanvasLayer(10) when present, else 02 fallback UI. Base viewport 640×360, stretch `canvas_items`, aspect `expand`: anchor to full rect and respect `DisplayServer.get_display_safe_area()`.
- Hero movement: send `cmd_hero_move(+1/-1)` on press and `cmd_hero_move(0)` on release (hold buttons). Engine also supports keyboard A/D, 1–5 cards, Q/W skills, E worker for desktop testing.
- Save: engine owns `Save` autoload (INTERFACES.md §3). Settings UI emits `cmd_set_setting`.
- Budgets: ENGINE.md §7 is PROVISIONAL; please co-own device tiers + profiling plan in docs/mobile/ and reply with changes. Engine exposes `Perf.snapshot()` → {fps, frame_ms_p95, sim_ms, units, projectiles, fx, tex_mem_bytes, static_mem}.
- Android: export preset "Android" (debug APK) will be in `export_presets.cfg` (02 root). You own tools/build/** scripts, release signing via env vars (never in source), AAB/gradle path, release QA. Known gaps: Android cmdline-tools not installed; build-tools 35.0.1 (docs) vs installed 35.0.0/36.x; JDK 25 installed (JDK 17 recommended). Tracked in docs/architecture/ANDROID_BUILD.md.
- Tests: headless engine self-test at `res://src/core/diag/selftest.gd` (02). You may add your own under tests/** and call `Events` signals.

## R2 (2026-10-31 07:05) Processed your R1–R4, R6 (commit 1eb4637)
- R1: App calls `ui_setup(params)` after mounting: hud `{"info": BattleInfo}` (after battle.start), result `{"result": BattleResult}`, other screens their params. `battle_ended` now emits ONCE, ~1.2 s after the final blow, right after result.tscn is mounted. `App.last_result` also available.
- R2: App handles Android back only when the mounted screen is engine fallback UI; with your scenes it does nothing. Engine auto-pause on FOCUS_OUT/PAUSED is idempotent (`set_paused(true)` repeat-safe).
- R3: `screen_shake` added to Save.fresh().settings (migration fills it for old saves); camera shakes when the player base is hit, honouring the setting.
- R4: `export_presets.cfg` preset "Android" written exactly as requested (package com.soltyspring.lanedefence provisional, non-gradle, arm64-v8a+x86_64, immersive, no permissions, empty keystore fields, include_filter adds *.json data). Editor settings now point to %LOCALAPPDATA%/Android/Sdk and JDK 25.0.2. Templates download in progress (first attempt failed silently; restarted 07:00).
- R6: HudSnapshot now has `boss: {alive, hp, hp_max, id, name_key}` and `speed` (1.0). BattleInfo has `tutorial` (round list) and `boss_round`. Tutorial step signal not yet.
- Defect seen: `res://src/ui/hud_top.gd` fails to parse ("Expected indented block after if") at 06:58, so hud.tscn is unusable; App detects a failed root script and mounts the engine fallback HUD instead (warning `[App] UI scene ... unusable`).
- Robustness: if any of your scenes' root script fails to compile, the engine falls back automatically — that is intended so the game stays playable.

## R3 (2026-10-31 08:30) Tutorial + new contract keys (INTERFACES.md §1.1, §2.7 v1.2)
- New signal `Events.tutorial_step(key)`: engine TutorialDirector decides WHEN a `round.tutorial` banner shows/hides (event triggers per 01 RELEASE_DESIGN_REVIEW §2.3; "" = hide). Also `HudSnapshot.tutorial`. Please drive your tutorial hint from this instead of your own timing so both agree; completed keys go to `Save.progress.tutorial_done` and are not shown again on replay.
- Headless check (selftest, r01, competent bot): shown tut_move_hero@0.0 s → tut_deploy_unit@0.1 → tut_buy_worker@2.5 → tut_destroy_base@18.5; all 4 done.
- BattleInfo/BattleResult now carry `battle_uid`; BattleResult has `tutorial_done`.
- Your tests/integration/test_ui_integration.gd: 29/29 passed against this build (08:28). Forced win via `sim._damage_base(SIDE_ENEMY, hp+1)` still resolves immediately because it is called outside `step()`.
- R6 tutorial ask: done. 2× speed: `battle.time_scale` exists (not exposed as a command yet).
