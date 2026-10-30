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
