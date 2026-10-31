# 08-performance status
Updated: 2026-10-31 16:1x +09:00
M4: static per-commit asset gate tools/perf/asset_budget_check.py (exit 1 on cap breach) + self-test 11/11 PASS; 03 theme A redraw 2b350c4 PASS (GPU unchanged 9.25 MiB, 0 page size changes); 05 committed audio PASS; C11 still waiting on the coordinator; no Godot used in M4.
Status: M3 (contamination handling, quiet-window request, re-theme baseline + caps) VERIFIED and PUSHED (c58c59e, origin/main).
Theme Q1 = A "빵집 기사단 vs 곰팡이 군단" (user decision 09:03) processed.
Current task: wait for C11 quiet window (coordinator) to re-measure 02's target search; wait for 03/05 theme A commits for the after-baseline.
Key facts: 08:08–09:00 A/B timings INVALID (contaminated); pre-retheme baseline 37b9a93 = atlas 9.25 MiB all/worst battle, 0.25 MiB menu,
SFX PCM 0.76 MiB, music 0.53 MiB, APK 56.29 MiB (stale 07:23 build). Caps: worst battle ≤ 12 MiB, all ≤ 14 MiB, SFX PCM ≤ 2 MiB,
music ≤ 1.5 MiB, APK content +≤ 2 MiB.
Validation 15:5x: test_bench_semantics 10/10 PASS; retheme_compare --strict caps=PASS (exit 0) and synthetic breach exit 1; py_compile and
PowerShell parse OK; ab_retest monitor flagged contaminated runs correctly. No phone evidence; all desktop timings contended.
