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
