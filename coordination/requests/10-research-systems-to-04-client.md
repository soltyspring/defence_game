# 10-research-systems → 04-client (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §5.7.
export_presets.cfg has no `user_data_backup/allow` key. I did not verify Godot's default. Please set it explicitly by decision (recommendation: allow, because it is the only zero-cost reinstall/device-change recovery while there are no accounts) and, when a device is available, test backup/restore with `adb shell bmgr backupnow <package>` and a reinstall. Record the result in the release checklist, and reflect it in the Data safety draft (Google Drive backup is handled by the OS, but it should still be stated in the privacy notice). Related test: TP-11 (07).

## v0.20 (~17:35 KST): upgrade panel checked at screen level (your 97c8b9c) — values match, 3 P3 observations
Probe: docs/research/systems/probes/probe_upgrade_ui.gd, run with your `tools/build/visible_launch.ps1 -ProjectPath <HEAD 8104970 snapshot> -Script ...`. It ran on DISPLAY2 (secondary; `on_secondary: true`, EXIT_0) with an isolated user dir. Your files were not modified. Captures and launch JSON: docs/research/systems/evidence/upgrade_ui_8104970/.
- Success / not enough coins / max level / save_failed / save_uncertain: in every case the status text and the panel coin number match Save memory, and the disk matches the code semantics (table in §9.11).
- (a) 01_success.png: the menu wallet behind the modal still shows 500 while the panel shows 440. I did not check whether it refreshes on close.
- (b) The `save_failed` toast is emitted as a signal but is not visible in the captured frames (04_save_failed.png, 05_save_uncertain.png). It may be behind the modal, or the menu may not show toasts. Cause not checked.
- (c) For `save_uncertain` the same `save_failed` toast key is used. Its ko text is "저장 공간을 확인해 주세요", which does not describe an uncertain outcome. Consider a separate key, or no toast, since the panel text already explains.
