# 08-performance handoff
Updated: 2026-10-31 07:25 +09:00
Status: M1 delivered locally (harness, inventory, desktop proxy baseline, phone procedures, owner requests). Publishing now; SHA below.
Evidence classes: STATIC (files), DESKTOP_PROXY / CONTENDED_DESKTOP_PROXY (this PC, debug editor binary), DEVICE (none yet), EMULATOR (not phone evidence).

## Ownership (acknowledged, exact)
Own ONLY: tools/perf/**, tests/performance/**, docs/performance/**, coordination/status/08-performance.md,
coordination/handoffs/08-performance.md, coordination/requests/08-performance-to-*.md. tests/performance/** is excluded from 04.
Runtime fixes belong to 02, atlases/fonts to 03, UI/build/export to 04, audio to 05. I measure and request; I edited no foreign file.

## Read receipts / processed
BRIEF.md (all sections), OWNERSHIP.md (eight-worker overrides), GIT_WORKFLOW.md (Publish-Task.ps1 only, explicit owned paths,
[Type] Korean subject, no add ./-A/reset/rebase/stash/force, PUSH_PENDING on failure), ENGINE.md v1.0, INTERFACES.md v1.0,
QUALITY_REVIEW.md (08 profiles fonts/effects/atlases; visible tests on SECONDARY monitor only), WINDOW_STABILITY.md (never close/kill
worker windows — I never did), QUOTA_POLICY.md (97 % checkpoint; serialize heavy Godot runs; do not compare contaminated benchmarks as clean),
DECISIONS.md D1–D10 DEFAULT + Q1 PENDING (no user answers affect perf yet), coordinator-to-08-performance.md: eight-worker block,
Dispatch R4, completion review gate, window stability, quota note, **C09** (contended runs labelled CONTENDED_DESKTOP_PROXY, exclusive
window requested from 02/04), **C10** (harness vs budget verdict split; `--strict`; regression test added).
Other handoffs read: 02 (balance r04–r10, atlas import, cap stress), 03 (roster art plan, fonts), BUILD_PLAN.md (04 device plan).

## Rule violation acknowledged and fixed
Before reading QUALITY_REVIEW.md I ran visible frame probes (06:54–07:13) that opened on the PRIMARY monitor. Since 07:15 every visible
run goes through `tools/perf/run_perf.ps1 -Frame`, which launches with `--screen <secondary index>` and verifies the game HWND rect lies
on the secondary monitor (`--position` with negative X was ignored by Godot here; verified window landed at x=0 on primary).

## Changes (files)
tests/performance/perf_bench.gd, perf_frame_probe.gd, test_bench_semantics.ps1 (+ Godot .uid files); tools/perf/run_perf.ps1,
budget_inventory.py, android_capture.ps1; docs/performance/BUDGETS.md, BASELINE_DESKTOP.md, ANDROID_PROFILING.md, RESOURCE_INVENTORY.md
(generated); requests to 01/02/03/04. Profiling output only under build/perf/ (git-ignored).

## Validation (commands → results)
- `.\tests\performance\test_bench_semantics.ps1` → 5/5 PASS, exit 0.
- `.\tools\perf\run_perf.ps1 -Quick` (07:20, git 0f84461, 6 other Godot procs) → harness=OK budgets=FAIL (4: round_step_p99 2.89 ms,
  cap_clash_step_p95 4.82 ms, cap_clash_step_avg 1.81 ms vs 0.5 ms desktop gates; save_p95 134 ms vs 50 ms). Exit 0 by design; `-Strict` exits 1.
- Full: build/perf/20261031-070413 (cap clash 36/side avg 1.41 ms, `_find_target` ≈ 65 % of step, 0 leaked/unexplained objects).
- Visible: build/perf/20261031-071525 on \\.\DISPLAY2 — caps A/B battle_view 3.75 → 1.54 ms/frame; draw calls p95 186 at caps, 93 at 3 units, 19 menu.
- `python tools/perf/budget_inventory.py --write-doc` → atlases 5.25 MiB battle / 0.25 MiB menu; APK 55.30 MiB (x86_64 28.2 MB + arm64 25.5 MB libs).
- `.\tools\perf\android_capture.ps1` → NO_DEVICE, exit 2 (no fabricated readings).

## Strongest rejection reasons / untested claims
- Zero phone data. Every phone budget (PSS, frame pacing, thermal, battery, cold start, flash save latency) is UNMEASURED.
- The ×4 desktop→phone slowdown used for proxy gates is an uncalibrated assumption.
- All desktop runs were CONTENDED (2–8 other Godot processes; noise p99/p50 up to 53×). No isolated baseline yet (C09 window requested).
- Debug editor binary only; release-template numbers missing (templates directory empty on this PC at 07:00).
- `RENDER_TEXTURE_MEM_USED` battle delta (+2.3 MiB) does not match atlas pages (5.1 MiB): unexplained.
- android_capture.ps1 has only been exercised on the no-device path; its parsing of dumpsys/top/SurfaceFlinger is unverified on a real phone.
- Frame-probe stress mode mutates the live sim (test-only cheat); A/B hides nodes. Both are attribution tools, not gameplay scenarios.

## Owner fixes requested (same scenario retest = the acceptance line in each request)
02: P1 battle_view draw cost/batching, P2 targeting O(n·m), P3 per-step temporaries, P4 save latency + debug log, P5 menu_ready marker /
perf export preset / perf log, P6 residency note, C09 window. 04: R1 x86_64 in universal APK, R2 gfxinfo ≠ Godot frames, R3 shared launcher,
R4 device install info, C09 window. 03: A1 page plan for 6 missing anim sets, A2 occupancy (no action), A3 font sizes for glyph-cache test.
01: queue one user question about a physical low-tier phone.

## Commits / push
(filled after Publish-Task.ps1)

## Next task (08)
1. Read replies in 02/03/04/01 request files; on 02 P1/P2 changes re-run `run_perf.ps1 -Frame` (same seeds, same r06 stress) and post deltas.
2. Exclusive-window isolated baseline when 02/04 confirm a slot (C09).
3. Font cost: measure glyph-cache texture memory and first-use hitch for Galmuri 9/11 at the UI sizes (needs 03 A3 answer).
4. When a phone is attached: `android_capture.ps1` for menu_idle, r06_caps, soak20_caps; fill BUDGETS.md DEVICE column.
