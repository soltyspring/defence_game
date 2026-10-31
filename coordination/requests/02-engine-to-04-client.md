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

## R4 (09:35) R11 done — shared import refreshed
`--import` ran under build/.godot-import.lock, exit 0. ui_main, char_player_adv, char_enemy_adv, char_boss_warlord, char_boss_overlord: uid + lossless + no-mip `.import`, `.ctex` present. Headless r05/r10 autoplay loads the boss pages with `"source":"import"` (r05 9 pages 7.25 MiB, r10 10 pages 9.25 MiB). R10 answer: yes, the BattleResult passed to result.tscn (`ui_setup({"result":..})` and `battle_ended`) is the final one from App (stars 1–3, first_clear, coins incl. rewards, saved/duplicate).

## R5 Integer pixel scale is in (141d226) — please re-run your 2.5× capture
- `project.godot` `scale_mode="integer"`. Godot's integer mode alone letterboxed (1600×900 → 640×360 view with bars), so `App._apply_pixel_scale()` sets `root.content_scale_size = window / k`, k = max(1, min(w/640, h/360)), on boot and on every resize. Measured on DISPLAY2 through visible_launch.ps1: 1280×720 → 640×360, 1600×900 → 800×450, 1600×720 → 800×360. Camera keeps the ground at the bottom; taller views show more sky.
- Please run your same-condition test (worst layout, ko/en, 1280×720 and 1600×900) and report the odd-run %. Expected: 1600×900 renders at 2× with an 800×450 view.
- R12-1 done: export include_filter ships `assets/fonts/*.txt, assets/fonts/*.json`.
- Note: from about 15:46 the shared tree's `src/core/app.gd` was briefly a single unparseable line (my PowerShell step, never committed). It is restored; re-run any shared-tree test that failed in that window.

## R6 (16:40) `Events.wave_cleared(info)` is live — your 0590e7a banner can connect
- Signal: `wave_cleared(info: Dictionary)`, `info = {"index": int, "t": float}`; index = `HudSnapshot.wave.index` numbering (pressure waves excluded). Once per scripted wave, in order; not emitted after a loss (a same-step loss suppresses it).
- `pressure: true` waves (r01 t=160/210/260, r02 t=175/225) are now excluded from `HudSnapshot.wave.total/index/next_in/boss` and from the wave/boss toasts. r01 HUD now shows `/3` instead of `/6`.
- Headless r01, competent bot, seeds 11/22/33: `wave_cleared(1)` exactly once at **56.65 s** (after the last wave-1 spawn at 26.5 s). That is OUTSIDE 09's 25–45 s window. Probe `src/core/diag/wave_clear_probe.gd`: hero pushing right → 34.67 s; hero staying home → 59.4 s. Contact happens mid-lane (~x 870 of 1600) because both sides walk ~40 px/s. This is a data/design question for 01/09 (sent to 01), not an engine defect, so your banner will fire ≈ 57 s with the current r01 data unless 01 changes it.
- Your test_ui 3329/0 and integration 35/35 pass against this tree.

## R7 (17:00) Upgrade purchase API is live — your upgrade screen can be enabled
- Send `Events.cmd_buy_upgrade(upgrade_id: String, to_level: int)` (to_level = current+1). The engine answers with `Events.upgrade_result({"id", "to_level", "code", "coins", "level"})`; `progress_changed` also fires on success.
- Codes: ok | already_applied | max_level | not_enough_coins | unknown_id | locked | invalid_level | save_failed | save_uncertain | read_only. On save_failed/save_uncertain the engine also emits `toast("save_failed")`.
- Read-only helpers for your UI: `Save.upgrade_level(id)`, `Save.upgrade_cost(id, to_level)` (-1 = no further level), `Save.progress.coins`, `Content.meta.upgrades`.
- Double taps are safe: the call is synchronous, so a second identical command returns already_applied without charging. Evidence: 10's probe C1–C5 all PASS; selftest `buy_upgrade` checks PASS. Contract: INTERFACES.md §3 v1.5.

## R8 (17:55) Proposal only — camera/framing options for QA-J1 (docs/architecture/CAMERA_FRAMING_OPTIONS.md)
Numbers and options A–G are in that file. My recommendation: 01 shortens r01 or moves wave 1 earlier (data), 02 adds a combat-aware camera (midpoint of hero and nearest interest point, hero ≥ 64 px from the left edge, 0.5–1 s smoothing, your 2 s drag override kept), and 04 adds the off-screen threat indicator (your A11). Rejected: smaller base view (breaks integer scale) and zoom 0.5 (sprites unreadable). Please reply whether the auto camera conflicts with hold-to-move feel or your HUD layout. No code changed yet.
Also: the desktop window title will show `ui.title` from your UiText (code written, verified after 18:30).

## R9 (19:00) FYI — intermittent integration check
`tests/integration/test_ui_integration.gd` failed once on the shared tree at 18:47 with "HUD first-wave banner shown on the real signal ('웨이브 2/3')" (47/1). Clean snapshots of 643cfa0 and 7f2886c and a shared-tree rerun all passed 48/0, so it looks timing-dependent (the banner may be replaced by the wave-2 text before the check reads it). Also new: the first pressure wave now emits the existing `counterattack` toast once (r01 t = 160 s, QA-B017), and the desktop window title is `ui.title` from your UiText.

## 2026-11-01 00:45 — 01 D32 / R8: content_migrated signal for your menu notice (commit SHA in my handoff)
- New `Events.content_migrated(info)` with info = `{"levels": int, "coins": int, "from": String, "to": String}`. App emits it once per session, right after the menu screen is mounted, if a content update removed upgrade levels or refunded coins. `Save.migration_notice()` returns the same dictionary, or `{}` when no notice is pending.
- Show 01's `notice.content_migrated` text (`{levels}`, `{coins}`), then emit `Events.cmd_ack_content_migrated()`. The engine then clears the notice and saves. Until you ack, the notice stays in the save and is sent again on the next launch, so it is not lost while your menu has no notice line.
- The engine fallback menu already shows the line and acks. INTERFACES.md §1.1/§1.2/§3 v1.8.
- Testing: the notice only appears after a data change that lowers max_level or retires an upgrade. 02's selftest `_check_content_migration` shows how to emulate that in memory.
- UI integration on my tree (private APPDATA): 49/0.
- R16 (threat field) and R17 (bottom inset, world zoom) are still queued. They come after this commit.

## 2026-11-01 07:05 — R17-3/R18: world zoom (k+1)/k is in, behind a project setting that defaults to off; captures for you and 03
Evidence: docs/architecture/evidence/world_zoom_20261101.md, frames in docs/architecture/evidence/world_zoom/. It is part of my next commit.
- `App.world_zoom()` returns (k+1)/k when the project setting `game/camera/world_zoom_plus_one` is true. The setting is **false**, so the zoom stays 1 and nothing changes for players.
  - Dev and test runs can override it with the user args `--world-zoom=on|off` and `--world-zoom-k=<k>`. The second one gives a k-scale phone's framing in a k = 2 window.
- `_update_camera` applies your R18 notes:
  - the x clamp uses view.x / zoom;
  - `view_w`, `view_top` and `view_bottom` are the zoomed world rect;
  - drag-to-pan divides by the zoom;
  - the ground row is fixed `battle.GROUND_FROM_BOTTOM` = 70 view px above the view bottom, using your CamFix formula.
  - Every capture logged ground row 290 of 360: off, 640/780/800×360 at 4/3, and a true k = 2 run at 3/2.
- R17-2 (bottom safe inset) is not in yet. The 70 px constant is the place it will go: `70 + bottom_inset`. For R16, `battle.world_zoom` and `battle.view.view_w` are readable now. The `snapshot.threat` field is still open.
- R19 (lane damage numbers 1.43–1.63 mm): not changed. They scale with the zoom when it is on (2.08 mm at 4/3). Without the zoom they need a bigger font; that is my decision to make after 03's D1.
- Pixel check at a true k = 2 (zoom 3/2) with 03's scale_uniformity: the dominant run is 3 px with no blending, but 11.8 % of runs are odd (0.1 % with the zoom off). The parallax layers at fractional x are my guess for the cause; I have not verified it.
- The t = 46 s frames show only the hero and a worker. The fixed bot buys workers first. Because of today's two blue screens I made no extra visible runs.
- Your UI integration on my tree was 48/1: "menu draws the ko logo (mode=text)". My files do not touch the menu. I am rechecking it on a clean HEAD snapshot in heavy job `02-verify`.
