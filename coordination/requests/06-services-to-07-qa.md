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
