# 06-services → 07-qa
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.

## Q1 Add service suites to regression runs (headless, ~0.5 s each, no network)
```
tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd
tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_m2.gd
```
Exit 0 = pass. Reports: `user://services_test_report.json`, `user://services_m2_test_report.json`. A group that aborts on a script error counts as a failure.

## Q2 What these suites do NOT prove (please keep in your hostile review)
- Only mock adapters. No real ad SDK, Play Billing or verification server exists.
- Crash/persistence safety is shown against a save double, not src/core/save.gd (02 request S2 pending).
- Monetization is undecided by the user; everything ships disabled.

## Q3 Diagnostics for reports
`Services.diagnostics()` (once 02 registers the autoload), or `preload("res://src/services/service_diagnostics.gd").snapshot(bundle)`. JSON-safe, no tokens or ids. Use `live.*` flags to confirm nothing real is enabled in a build under test.

# Update M3 (2026-10-31) — QUEUED
Add `res://tests/services/test_services_m3.gd` (real src/core/save.gd in isolated user://svc_m3_test, spawns 3 child Godot processes and kills them; ~5–10 s; cleans up its directory). It proves both-or-neither persistence for that save script in isolation, not game integration (02 S2 still open).

# Update M4 (2026-10-31) — QUEUED
Run `pwsh -File tests/services/run_services_suites.ps1` (sequential, ~30 s, mocks only). Expected today: `OVERALL exit=2 (BLOCKED_NOT_INTEGRATED)` with blockers I1–I4 (02 S1/S2). Treat exit 2 as an OPEN blocker, never as a pass; exit 1 is a defect for 06. Per-row results are in user://services_integration_report.json (`binding` must be `game` and `game_evidence` true before you accept any row as game evidence). Expected outcomes: docs/services/REWARD_STATE_TABLE.md. Disabled-mode rows D1–D6 must PASS in every build you verify.

# Update M8 (2026-10-31) — QUEUED
Gate now expected to exit 0 (PASS_INTEGRATED, binding=game). Treat exit 2 as a regression if Services is removed from project.godot. Runner includes new `test_services_m8.gd` (launch/resume reconcile, no-fill cooldown). Isolated test dirs are now per-process (`user://svc_*_test_<pid>`) so parallel runs no longer collide: one flaky `process_death` failure on 2026-10-31 ~15:40 matched another Godot run started at the same second.

# Update M9 (2026-10-31) — QUEUED
Real-purchase test cases T1–T16 with expected service signals/codes: docs/services/BILLING_SANDBOX_TEST_PLAN.md §3. They can only run after the user creates the Play account, license testers and internal track (steps marked [USER]). Not runnable today.

# Update M10 (2026-10-31) — QUEUED
Runner now includes `test_services_m10.gd` (multi-quantity consumables: q=1, q=3, duplicate callbacks, invalid/over-limit quantities, crash during grant and sink-saves-then-fails on the autoload Save in an isolated dir). Expected: OVERALL exit 0. New state-table row P7; real-device case T17 in BILLING_SANDBOX_TEST_PLAN.md.

# 2026-10-31 17:25 KST — QUEUED: 7 untracked Godot .uid files in tests/acceptance (06 did not commit them)
Godot 4.4+ says `.uid` files must be committed (https://godotengine.org/article/uid-changes-coming-to-godot-4-4/). Audit: docs/services/GODOT_UID_AUDIT.md.
- Scripts tracked, `.uid` missing: capture_crowd, capture_m8, capture_narrow, capture_visual, cvd_sim, probe_r01_risk (`tests/acceptance/<name>.gd.uid`).
- `tests/acceptance/probe_balance.gd` and its `.uid` are both untracked. Commit them together, or delete both if it is a scratch file.
- No tracked file uses these UIDs yet, so nothing is broken today.
- The runner now has 9 suites: new `test_services_android.gd` (permissions, backup values, 06 `.uid` tracking) and `test_services_upgrade.gd` (coin upgrades stay separate from monetization). Expected: OVERALL exit 0.

# 2026-10-31 ~18:05 KST — FYI: automatic launcher-label check for your "real APK label" step (Q4)
After 02 rebuilds, `pwsh -File tests/services/run_services_suites.ps1` prints `launcher_label=VERIFIED` when the APK's ko label is `빵집 기사단` and its en/default label is `Bakery Knights`. It prints WAITING while APKs still say `Lane Defence`, and fails on any other label. It reads APKs in build/qa/apk_head, build/android and build/release with aapt2. A launcher screenshot on a device or emulator is still your evidence; this check covers only the manifest.
