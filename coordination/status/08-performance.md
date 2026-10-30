# 08-performance status
Updated: 2026-10-31 07:25 +09:00
Status: MILESTONE 1 (perf harness + budget inventory + desktop proxy baseline) VERIFIED LOCALLY and PUSHED (3c1719a, origin/main). No phone evidence exists.
Current task: wait for owner responses (02 P1/P2, 04 R1, exclusive bench window C09) and re-measure; meanwhile font glyph-cache cost prep.

Completed files (owned):
- tests/performance/perf_bench.gd — headless CPU/memory bench (content load, bot rounds, N/side scaling walk+clash best-of-3, verified step-section mirror, HUD snapshot, leak, save/load).
- tests/performance/perf_frame_probe.gd — windowed real-game probe (frame/render CPU/GPU ms, draw calls, texture/static mem, caps stress, A/B view/UI attribution).
- tests/performance/test_bench_semantics.ps1 — exit/verdict regression test (5 cases).
- tools/perf/run_perf.ps1 — runner; records concurrent Godot processes (CONTENDED class); visible probes on secondary monitor via `--screen <idx>` with HWND rect verification.
- tools/perf/budget_inventory.py — STATIC atlas/residency/audio/font/APK inventory; writes docs/performance/RESOURCE_INVENTORY.md.
- tools/perf/android_capture.ps1 — phone capture (PSS, CPU, thermal, battery, SurfaceFlinger frames, cold start); exits 2 with no device.
- docs/performance/BUDGETS.md, BASELINE_DESKTOP.md, ANDROID_PROFILING.md, RESOURCE_INVENTORY.md.
- coordination/requests/08-performance-to-01-director.md, -to-02-engine.md, -to-03-art.md, -to-04-client.md.

Validation evidence (actual, this session):
- `.\tests\performance\test_bench_semantics.ps1` → ALL PASS (pass/fail × default/strict + inventory strict), exit 0.
- `.\tools\perf\run_perf.ps1 -Quick` (07:20, git 0f84461) → `PERF_BENCH harness=OK budgets=FAIL fails=4 [round_step_p99_ms_desktop, cap_clash_step_p95_ms_desktop, cap_clash_step_avg_ms_desktop, save_p95_ms_desktop] class=CONTENDED_DESKTOP_PROXY` (6 other Godot processes). Harness completed; PROVISIONAL budgets FAILED — not a pass.
- Full run build/perf/20261031-070413 and visible probes build/perf/20261031-071525 (window rect (-1608,299)-(-312,1058) on \\.\DISPLAY2).
- `budget_inventory.py --write-doc` → atlas 5.25 MiB GPU battle, 0.25 MiB menu, fonts 3.09 MiB disk, debug APK 55.30 MiB.
- `android_capture.ps1` → `NO_DEVICE` exit 2 (no phone attached). PowerShell parse check of both .ps1: 0 errors. Godot `--check-only` of both .gd: exit 0.

Dependencies: 02 (P1 draw cost, P2 targeting, P4 save, P5 device enablers, C09 window), 03 (A1 page plan, A3 font sizes), 04 (R1 ABI/APK, R2 gfxinfo correction, R4 device install), 01 (phone question for the user queue).
Outstanding questions: none to the user directly; phone availability question queued via 01.
