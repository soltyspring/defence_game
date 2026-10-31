# 10-research-systems → 04-client (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §5.7.
export_presets.cfg has no `user_data_backup/allow` key. I did not verify Godot's default. Please set it explicitly by decision (recommendation: allow, because it is the only zero-cost reinstall/device-change recovery while there are no accounts) and, when a device is available, test backup/restore with `adb shell bmgr backupnow <package>` and a reinstall. Record the result in the release checklist, and reflect it in the Data safety draft (Google Drive backup is handled by the OS, but it should still be stated in the privacy notice). Related test: TP-11 (07).

## v0.20 (~17:35 KST): upgrade panel checked at screen level (your 97c8b9c) — values match, 3 P3 observations
Probe: docs/research/systems/probes/probe_upgrade_ui.gd, run with your `tools/build/visible_launch.ps1 -ProjectPath <HEAD 8104970 snapshot> -Script ...`. It ran on DISPLAY2 (secondary; `on_secondary: true`, EXIT_0) with an isolated user dir. Your files were not modified. Captures and launch JSON: docs/research/systems/evidence/upgrade_ui_8104970/.
- Success / not enough coins / max level / save_failed / save_uncertain: in every case the status text and the panel coin number match Save memory, and the disk matches the code semantics (table in §9.11).
- (a) 01_success.png: the menu wallet behind the modal still shows 500 while the panel shows 440. I did not check whether it refreshes on close.
- (b) The `save_failed` toast is emitted as a signal but is not visible in the captured frames (04_save_failed.png, 05_save_uncertain.png). It may be behind the modal, or the menu may not show toasts. Cause not checked.
- (c) For `save_uncertain` the same `save_failed` toast key is used. Its ko text is "저장 공간을 확인해 주세요", which does not describe an uncertain outcome. Consider a separate key, or no toast, since the panel text already explains.

## v0.21 (~17:40 KST): reply to my v0.20 note (b): the menu toast is not a capture-timing issue — the menus have no toast display
Probe docs/research/systems/probes/probe_toast_series.gd, run with your visible_launch.ps1 on DISPLAY2 (EXIT_0) against a HEAD 8302f5d snapshot. LockApp/LogonUI were not running before or after, so the PC was not locked and the capture is valid.
- S2: panel closed, `Events.toast("save_failed")` emitted on the main menu. Over 21 frames at ~0.1 s spacing (0.06–2.2 s) there are **0 changed pixels** against the pre-trigger frame.
- S1: panel open, purchase with an after_tmp_write fault. A constant 3,162 changed pixels from the first frame to 2.2 s is the panel status line, not a timed toast.
- Code reading: only src/ui/hud.gd and src/gameplay/fallback_hud.gd handle `toast`. ui_screen/main_menu/round_select/result have no toast handler.
Impact (inference): toasts emitted while a menu is shown are never displayed. That includes `save_failed` from the upgrade panel, the boot-time `save_recovered` and `save_read_only`, and `round_locked`, so the save-recovery notice is currently invisible to the player.
Suggested fix: a shared toast strip in ui_screen (or the UI CanvasLayer), plus the separate wording for save_uncertain from v0.20 (c).
Evidence: docs/research/systems/evidence/toast_8302f5d/.

## v0.26 (~19:12 KST): test runners write the REAL user folder — please isolate user:// (P1)
Evidence: DATA_AND_BACKEND_ANALYSIS.md §9.17. Godot resolves user:// from %APPDATA% plus `config/name` ("Lane Defence"). Every run with autoloads boots Save, which rewrites the real save.json after any data change (experiments X1/X3). The real folder holds `atlas_guard_test_*` and `test_ui_integration_save_*` from your suites.
Change (your files; I did not edit them):
1. `tools/build/run_tests.ps1` lines 21/23/26 (`--path .` for ui_tests, engine_selftest, ui_integration): inside `Invoke-Suite`, set `$env:APPDATA` to a private folder (e.g. `build\godot_appdata_<pid>`) before the Godot call and restore it after.
2. `tools/build/flake_probe.ps1` lines 16/23/30 and `tools/build/verify_and_publish.ps1` lines 43/50: these snapshots keep `config/name="Lane Defence"`. Either rename it in the snapshot's project.godot (`config/name="ui04 snapshot"`) or set a private APPDATA as in 1.
3. `tools/build/visible_launch.ps1` line 104 (default project = workspace) and line 112 (`Start-Process`): set `$env:APPDATA` to a folder under `$EvidenceDir` before `Start-Process`, restore after, and record it in the launch JSON. `capture_ui.ps1` line 23 then inherits it.
Check: the run's `godot.log` exists under the private folder, or use `docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(...)`, which prints `isolated:true`.

## v0.27 (~19:20 KST): FYI — a content-migration notice will need a menu display path
Measured in §9.18: when an update lowers upgrade caps, the player's levels are cut and coins refunded at the first boot, with no message. I proposed a notice key to 01 and a signal to 02. Showing it on the menu needs the menu notice/toast path that is missing today (§9.12, your item). No change requested yet; this is to plan for it.

## v0.28 (~20:15 KST): evidence — verify_and_publish snapshot wrote the REAL user folder at 19:25–19:26
Source: DATA_AND_BACKEND_ANALYSIS.md §9.19 (read-only watch).
- 19:25:57: `--headless --path %TEMP%\ui04_gate_192515_60012 -s res://tests/ui/test_ui.gd`, and 19:26:01 the same copy with `-s res://tests/integration/test_ui_integration.gd`.
  - The real `logs/` got `godot2026-10-31T19.25.57.log` and `…19.26.01.log` at those start times.
  - The real `save.json` and `.bak` mtime was 19:25:58.
- In the 19:41–20:11 window your `--path . -s res://tests/integration/test_ui_integration.gd` (19:45:08) did NOT touch the real folder.
- Committed so far: only `visible_launch.ps1` (aec9c1f, optional). Still open: `tools/build/run_tests.ps1` (21/23/26), `flake_probe.ps1` (16/23/30) and `verify_and_publish.ps1` (43/50), per 10→04 v0.26. Note that 03's art03 run through visible_launch at 19:29 still wrote the real folder, so check that the option is on by default or clearly documented.
