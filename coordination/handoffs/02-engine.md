# 02-engine handoff — CHECKPOINT for account change
Updated: 2026-10-31 07:35 +09:00
Status: STOPPED on user request (account change). No work in progress after this file is saved.
Model: claude-opus-5.5, trust-all. Session ID: not exposed to me inside this session (check Kiro session list for the 02-engine window; do not guess).

## User decisions
None answered yet. Q1 theme is still PENDING (DECISIONS.md D1–D9 are reversible DEFAULTs, not user approvals). Nothing changed by 02.

## Read receipts / processed requests
BRIEF.md, OWNERSHIP.md (incl. 05–08), GIT_WORKFLOW.md, coordinator-to-02-engine.md through Dispatch R4 + completion review gate + C02, QUALITY_REVIEW.md (secondary-monitor rule acknowledged), DECISIONS.md D1–D9/Q1, 04-client-to-02-engine R1–R7.
Processed: 04 R1 (ui_setup after mount), R2 (back button only for fallback UI), R3 (screen_shake), R4 (export preset + SDK/JDK paths), R6 (boss/speed snapshot keys; tutorial step signal NOT done). 01 D7 caps adopted from game_config. C02 (raw PNG fallback cannot certify APK) answered by the APK test below.

## Commits
- 1eb4637 `[Feat] Godot 4.7.2 엔진 기반과 플레이 가능한 레인 전투 구현` — PUSHED origin/main (44 files).
- Checkpoint commit of the files listed under "Completed since 1eb4637" — result recorded in coordination/status/02-engine.md after the helper runs (see the bottom of that file).

## Completed since 1eb4637 (owned, validated as noted)
- src/core/app.gd: ui_setup(params) mounting, back handling only for fallback UI, failed-root-script → fallback UI, always-resident ui pages acquired at boot, `[App] boot ok ...` log line, screenshot/autoplay args.
- src/core/atlas.gd: per-page `source` (import / raw_png_dev_fallback) in texture_report, warning on dev fallback.
- src/core/save.gd: `screen_shake` setting. src/core/perf.gd: unit ceiling 40.
- src/gameplay/battle_sim.gd: `boss` + `speed` in HudSnapshot, shake events, removed per-hit array duplicates. src/gameplay/battle.gd: camera shake honouring setting.
- src/core/diag/selftest.gd: combat cap stress (ranged enemies forced into contact) with avg/p99/worst step timings.
- docs/architecture/ANDROID_BUILD.md (tracker A1–A15), docs/architecture/evidence/*.png (emulator menu, emulator battle r01, desktop autoplay 60 s).
- coordination/requests/02-engine-to-01-director.md R2, 02-engine-to-03-art.md R2, 02-engine-to-04-client.md R2.

## Validation actually run
- selftest (headless) after the sim/stress changes: SELFTEST PASS, exit 0. r01–r03 competent bot 3/3; r04–r10 0/3 (BALANCE flags sent to 01); passive player loses all rounds; save roundtrip/corruption→.bak/tamper/migration pass; combat cap stress: step avg 0.50 ms, p99 1.21 ms, worst 1.33 ms (desktop proxy, RTX 2070S; not a phone claim).
- Export templates: official .tpz SHA-512 match=True, installed.
- `--export-debug "Android"` → build/android/defence-debug.apk 59,021,726 B, signed (apksigner build-tools 36.0.0).
- APK contents: all 6 atlas .ctex + remapped .import packed. `--main-pack` desktop run loaded 6/6 pages.
- Emulator (project-local AVD build/avd/LaneDefence_Phone, Android 16/API 36 x86_64, 720×1600, -gpu host): app boots, logcat `[App] boot ok platform=Android ... ui_source={"menu":"scenes/ui"} ... "source":"import"`; tapping Play opens battle r01 rendered with 03 atlases + 04 HUD. PSS ≈172–174 MB. Emulator = proxy only.
- NOT re-run: final regression selftest after the last atlas.gd/app.gd edits (the run was interrupted by this stop request). Those edits did execute on Android (boot log printed), but rerun selftest first on resume.

## Known failures / open defects
1. swiftshader emulator GPU: Godot GLES3 shaders fail to link (GL_MAX_FRAGMENT_UNIFORM_VECTORS 261) → black/failed render. Host GPU works. Real low-end GPU behaviour unknown.
2. Headless emulator image shows SystemUI ANR dialogs (environment). Shared adb server was restarted by another process twice during testing.
3. Rounds r04–r10 not won by the competent bot (data or bot policy; 01 R2).
4. 04 `src/ui/hud_top.gd` parse error earlier (06:58); engine fell back to its own HUD on desktop. On the 07:26 Android build the 04 HUD rendered, so 04 may have fixed it — re-verify.
5. No physical device; no real-device fps/thermal/memory evidence. AAB/Gradle path, cmdline-tools, release signing, Korean font on Android: pending (ANDROID_BUILD.md).
6. Not implemented: hit_frame-timed damage, cast_time, tutorial step signal, 2× speed.
7. Visible desktop previews so far ran on the main monitor (before the secondary-monitor rule was read). Future visible runs must go on the secondary monitor.

## Local state left running
Android emulator `emulator-5580` (LaneDefence_Phone) may still be running headless; it is safe to kill: `adb -s emulator-5580 emu kill`. Local-only (git-ignored): tools/engine/** (editor, templates, debug keystore, editor settings), build/** (APK, previews, AVD).

## Exact next steps on resume
1. Reread coordinator-to-02-engine.md, DECISIONS.md and peer handoffs.
2. Rerun `& .\tools\engine\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/selftest.gd` and confirm PASS.
3. Close 03 R2 with 03 (they should commit the Godot-generated .import files).
4. Tutorial step signal + hit_frame timing + 2× speed (04 R6, 01).
5. Balance follow-up with 01 (r04+), more bot variants if 01 specifies them.
6. Secondary-monitor visible preview using 04's launcher. Real device test once one is attached.
