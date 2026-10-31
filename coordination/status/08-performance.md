# 08-performance status
Updated: 2026-10-31 09:25 +09:00
Status: M2 (font cost benchmark, A/B retests of committed engine fixes, adopted/provisional strict mode) VERIFIED LOCALLY, publishing.
All timings are CONTENDED_DESKTOP_PROXY (0–8 other Godot processes, debug editor binary). No phone evidence exists (no device attached).

Current task: publish M2; next = re-run targeting equivalence when 02 answers P2b; font pre-warm case when 04 answers R5; investigate why the
frame stress reaches only ~40 units now.

M2 files: tests/performance/perf_font_probe.gd (new), tests/performance/targeting_equivalence.gd (new), tools/perf/ab_retest.ps1 (new),
tests/performance/perf_bench.gd (adopted/provisional checks, --strict / --strict-all, version-aware step mirror incl. sort_lanes, same-build
targeting A/B), tests/performance/perf_frame_probe.gd (R09 readability counts), tests/performance/test_bench_semantics.ps1 (10 cases),
tools/perf/budget_inventory.py (fonts, adopted page-size checks, strict modes, engine residency follows battle.gd), tools/perf/run_perf.ps1
(-Font, import-lock wait), docs/performance/FONT_COST.md (new), BASELINE_DESKTOP.md §7, BUDGETS.md, RESOURCE_INVENTORY.md (regenerated),
requests to 02/03/04/09.

Key results: sorted targeting (02 e9dfaa4) cap step −46 % avg / −68 % p95, but changes winners in 3/30 runs (x-tie tie-break; P2b to 02).
fdd4d86 duplicate removal: no measurable change. Glyph cache ≤ 2.25 MiB (LA8, 128 KiB per 256² page); first-use hitch +9.4 ms desktop
for a 12 px toast (pre-warm requested from 04). Atlas residency 5.25–9.25 MiB per round, roster-based (02 P6 done).

Validation: test_bench_semantics.ps1 ALL PASS (10/10, exit 0); Godot --check-only of the 4 .gd files exit 0; PowerShell parse 0 errors;
font probe 3 reps exit 0 on \\.\DISPLAY2 (rect verified); A/B runs exit 0 (3 pairs each); targeting_equivalence ran on clean snapshot cd76358.
Quota at 09:25: usage.json 4.3 %.
