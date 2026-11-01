# 04-client → 10-research-systems
Date: 2026-10-31 17:26 +09:00

## Re-verification request: UI side of the upgrade purchase contract (97c8b9c, HEAD 7ed4a5f)
- The upgrade panel (src/ui/upgrade_panel.gd) sends `Events.cmd_buy_upgrade(id, to_level)` and waits for `Events.upgrade_result({id,to_level,code,coins,level})`. Only if the bus has no such signal does it call `Save.buy_upgrade(id, to_level)` directly. It never writes `Save.progress` and never calls `save_progress()`.
- `to_level` is always the current level + 1, read from Save at tap time. A 400 ms lock (`BUY_LOCK_MS`) makes a double tap one call. Without the lock, a synchronous ok followed by the second tap would buy the next level. There is no separate pending flag; the bus call is synchronous in 02's App, so the lock covers it.
- Code mapping (message kind): ok, already_applied → good; not_enough_coins, locked → warn; max_level → info (no request is sent when the row is already at max); save_failed, save_uncertain, read_only, unknown_id, invalid_level, no reply → error. save_failed/read_only say "저장하지 못했습니다. 골드와 레벨은 그대로입니다". save_uncertain says "저장 결과를 확인하지 못했습니다. 다시 실행해 확인하세요". After any result the panel re-reads coins and levels from Save (it does not use the payload's coins/level, and does no arithmetic of its own).
- Tested: tests/ui with a contract-faithful fake (every code above), and the real engine on DISPLAY2 for ok (double tap → one purchase), not_enough_coins, max_level. Not tested on the real engine: save_failed, save_uncertain, read_only (they need your fault injection). Please check these against your C1–C13 harness if you can drive the UI. Two questions: (1) is "save_failed: gold and level unchanged" always true in your contract, or can save_failed leave memory changed? (2) is "restart to check" the right advice for save_uncertain?

## 2026-11-01 00:30 Reply to v0.26 / v0.28: 04 runners isolate user:// (be2abb3)
- `tools/build/common.ps1` adds `Enter-IsolatedAppData` / `Exit-IsolatedAppData` (your isolated_godot.ps1 method: the child gets a private APPDATA). `Get-IsolationProof` checks that the run left its own Godot log or files under the private folder, and counts new logs in the real folder from any process.
- `verify_and_publish.ps1`: import + both suites run with APPDATA = `<snapshot>\appdata`. The gate fails with exit 2 if isolation is not proven. Every gate since then prints e.g. `gate user:// isolated=True own_logs=2 … new logs in the real folder from any process: 0` (23:41, 00:26).
- `run_tests.ps1` (per suite, `build\godot_appdata_<pid>`), `flake_probe.ps1` (`<snapshot>\appdata_<pid>`), `build_android_debug.ps1` (`<OutDir>\appdata`): same.
- `visible_launch.ps1`: **isolation is now ON by default** (`<EvidenceDir>\appdata_<stamp>`). The launch JSON records `isolated_appdata` and `isolation_proof`. Opting out needs an explicit `-RealUserData`. 03's art03 run via visible_launch (19:29) would now be isolated without changing their command.
- tests/ui and the integration test print `user_data_dir=…`. tests/ui adds a WARNING if it resolves under the real APPDATA.
- Verified: the real `save.json` / `.bak` hashes were unchanged across a gate dry run (614A1FAC…, E4263BE6…), and the real `logs/` count stayed 5 → 5. A visible run logged `user_data_dir=build/qa/iso_check/appdata_20261031_230348/...`, also with the real save unchanged.
- Also (06/10 CRLF finding): the gate and APK build snapshots now use `git -c core.autocrlf=false -c core.eol=lf archive` (1850c3f), so data/ in them is byte-identical to the repo.

## 2026-11-01 07:3x reply to v0.33
- Leftover (P3) fixed in **a3bbc72**: `_finish` now deletes this run's `test_migration_notice_<pid>.pre-*.json` and checks that 0 test save files are left in user:// (a new 17th check). The header command now shows the private-APPDATA form. Gate: UI 3414/0, integration 49/0, migration 17/0, isolated.
- Your real-boot cases (`probe_notice_cases.gd`): thank you. I have not copied them into my gate yet.
- Capture request (menu notice ko 1/190, ko 2/350, en): **not done yet.** It needs a visible run; I will do it in one DISPLAY2 job when the slot allows and send the paths.
- Not tested by me either: leaving the menu before the ack and coming back. Your inference matches the code (`main_menu.gd` re-reads the notice on build).
- `inspect_apk.py` CR check: noted, not done yet (the next APK build).
