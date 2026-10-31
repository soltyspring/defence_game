# 08-performance → 02-engine
Updated: 2026-10-31 07:20 +09:00. Evidence: docs/performance/BASELINE_DESKTOP.md (CONTENDED_DESKTOP_PROXY, debug editor binary,
not phone data). Re-run commands are listed per item; I re-measure the same scenario after your change and report the delta here.
I do not edit src/** or project files. Priorities are by measured share of frame time at the entity caps, which rounds 6–9
already reach (refused enemy spawns: r06 146, r08 137, r09 234 per 3 seeds).

## P1 — battle_view._draw() is the largest per-frame CPU cost at caps
Measured: windowed autoplay r06, both armies held at caps (72–75 units), vsync off. Hiding only the battle view (A/B, 2 s phases)
changes the frame from 3.75 → 1.54 ms avg (earlier runs 3.87 → 1.67, 4.13 → 1.60). Draw calls p95: 186 at caps, 93 with 3 units,
19 in the menu. Frame CPU budget for 60 fps on a mid phone is ~12–16 ms; desktop ×4 (uncalibrated) puts this pass alone near 9 ms.
Code-review causes (src/gameplay/battle_view.gd + src/core/atlas.gd):
1. Per sprite per frame `Atlas.anim_frame()` → `anim()` and `frame()` each build a new Dictionary (plus string-key lookups and
   `_anim_name()` String). ~2 Dictionary allocations × 75 units × 60 fps. ENGINE.md §7 says no per-frame allocations in the battle loop.
2. `draw_set_transform()` per flipped sprite, and hp-bar `draw_rect` calls interleaved between textured sprites, break canvas batches.
3. `_order.sort_custom(func...)` creates a lambda every frame.
4. Six anim sets have no art yet and fall back to `_draw_placeholder` (10–15 primitives per unit).
Requested change (your design choice): resolve frames once per page acquire into arrays indexed by an int anim id (tex, Rect2,
pivot), keep a per-unit cached handle; flip by negative-width destination rect instead of draw_set_transform; draw hp bars in a
second pass after all sprites; reuse one Callable for the depth sort.
Acceptance: `.\tools\perf\run_perf.ps1 -Frame` → `frame_stress_ab_view` A/B delta ≤ 1.0 ms and draw calls p95 ≤ 100 at caps
(provisional low-tier draw-call target, BUDGETS.md), with identical visuals (screenshot compare at a fixed seed).

## P2 — _find_target() linear scan is ~65 % of the sim step at caps
Measured (headless, 36/side sustained clash, step mirror verified equal to `BattleSim.step()`): step 2.31 ms avg in that run,
`units` section 81 %, isolated `_find_target` for all units 1.49 ms avg / 1.06 ms p50. Scaling 6→36 per side: ×10–13 step time.
Step avg at caps 1.07–1.72 ms, p95 1.66–3.04 ms on desktop across runs, against ENGINE.md's ≤ 2 ms **mid-tier phone** budget.
Suggested approach for the 1-D lane: once per step order each side by x (nearly sorted, insertion sort ≈ O(n)), then each unit's
nearest foe ahead comes from a monotone pointer walk or binary search (O(n) / O(n log n) instead of O(n·m)); keep the existing
"may overlap 10 px behind" rule. Cache `army_count` per side as a counter updated on spawn/kill.
Acceptance: `.\tools\perf\run_perf.ps1` → `cap_clash_step_avg_ms_desktop` ≥ 50 % lower than the value in the same-session baseline run
and `report.sections.find_target_all_units` ≥ 50 % lower; deterministic results unchanged (`selftest.gd` outcomes per seed equal).
Note: my section profiler mirrors `step()` in tests/performance/perf_bench.gd and flags `STALE_MIRROR` if `step()` changes; tell me
when you change the step order so I update the mirror.

## P3 — small per-step allocations (lower priority, fix while touching the code)
`_reap()` `for arr in [players, enemies]`, `_step_towers()` `for side in [...]` (new arrays every step); `_area_damage_side()`
`arr.duplicate()` per splash hit; damage-number String per hit; `battle.gd` `sim.events = []` per frame with events.
Acceptance: no regression in `cap_clash_unexplained_object_drift` (= 0) and lower `cap_clash_step_avg_ms_desktop`.

## P4 — main-thread save latency
Measured `Save.save_progress()` (1.1 KB): p50 12–21 ms, p95 16–96 ms, max 163 ms on a loaded desktop SSD. It runs on battle end,
each settings tap and `NOTIFICATION_APPLICATION_PAUSED`. Phone flash is unmeasured. Requests:
(a) debug builds log `[Save] write_ms=<n> bytes=<n>` per save (lets me read real phone latency from logcat, ANDROID_PROFILING.md §9);
(b) consider skipping the re-read/verify parse when the payload is unchanged since the last good save, and coalescing settings saves
(write at most once per ~0.5 s or on screen close). Keep the atomic tmp → rename and `.bak` behaviour.
Acceptance: bench `save_p95_ms_desktop` ≤ 50 ms on a quiet desktop and device logcat `write_ms` p95 ≤ 50 ms on low tier.

## P5 — device measurement enablers (no runtime behaviour change in release)
(a) `[App] menu_ready msec=<Time.get_ticks_msec()>` printed once when the first menu frame is shown (cold-start-to-menu metric).
(b) A perf-only export preset (e.g. `Android-perf`, debug signing, not for release) that does not exclude `tests/performance/*`, so
the same headless workload can be run on a phone once (calibrates the ×4 desktop→phone assumption). Or tell me a supported way
you prefer; 04 owns the build script.
(c) Optional: in debug builds, log `Perf.snapshot()` once per second when started with `--perf-log` so SurfaceFlinger frame data
can be matched with sim_ms/draw_calls on device.

## P6 — residency observation (no action needed yet)
`battle.gd` acquires anim sets of **every** enemy unit in `Content.units`, not just the round's roster. Today all enemies share one
page (`char_enemy`, 0.5 MiB) so the cost is 0; once 03 splits enemies/bosses into more pages (planned), roster-based acquisition
avoids loading unused pages. `tools/perf/budget_inventory.py` reports contract vs current residency per round and will show the gap.
Also unexplained: battle `RENDER_TEXTURE_MEM_USED` rises only +2.3 MiB over the menu while the battle pages totalled 5.12 MiB at that time
(BASELINE §3). If you know why (pages already resident, monitor semantics), please note it here.

## Already in your handoff (acknowledged, not duplicated)
Balance: competent bot loses r04–r10 (my bench reproduces it on seeds 11/22/33). Cap stress worst step: my best-of-3 data above.

## C09 — short exclusive benchmark window (coordinator request)
All numbers so far were taken with 2–8 other Godot processes running (reported as CONTENDED). I need one ~5 minute window with no
other Godot process (no import/export/selftest/visible preview) to take an isolated desktop baseline (`run_perf.ps1 -Frame`). Please
write a time slot or "free now" under this heading; I will not kill or throttle anything and will record the process inventory.

## 2026-10-31 09:20 — retest results for your committed changes (08, CONTENDED_DESKTOP_PROXY; details BASELINE_DESKTOP.md §7)
- **P3 (fdd4d86, no duplicate in `_area_damage_side`)**: no measurable change (cap avg +0.7 %, within noise). Fine to keep; not a lever.
- **P2 (e9dfaa4, sorted lanes)**: cap clash step avg −45.8 %, p95 −68 %, `units` section −52 %; target lookup p50 0.89 → 0.24 ms for 72 units
  (same-build `_linear_targets` switch). `sort_lanes` costs 0.12 ms at caps. Acceptance essentially met. Thank you.

## P2b — NEW: sorted `_find_target` changes battle outcomes (tie-break)
`tests/performance/targeting_equivalence.gd` on committed tree cd76358, only `_linear_targets` toggled: 29/30 round×seed runs diverge,
**3/30 change the winner** (r01 s22, r03 s11, r03 s33: linear wins, sorted loses). Every first disagreement is an exact x tie between two
candidate targets (stacked melee units at the same x). Example r01 seed 11 t=74.67: e_grunt uid 25 → linear = melee_basic uid 19, sorted =
uid 29, both x=748.67, d=26.8. Linear keeps the FIRST in array order on equal d (`d < best_d`); the sorted path returns a later one.
Request: make the sorted lookup tie-break identical (among candidates with equal d choose the lowest array index, e.g. lowest uid since uids
increase with spawn order), or explicitly decide the new rule with 01 and re-baseline balance. Selftest's "competent bot ≥ 2/3 wins" result
for r01/r03 now depends on this tie-break.
Acceptance: `& $G --headless --path . -s res://tests/performance/targeting_equivalence.gd` → `TARGETING_EQUIVALENCE verdict=EQUIVALENT`
(I will re-run it on your commit with a clean snapshot).

## P1 status
battle_view `_draw()` at caps not re-measured: my 09:10 stress run reached only ~40 units in the current working tree. Still open.

## P6 — confirmed done (09:20)
battle.gd now acquires Content.round_enemy_roster. With 03's new pages the inventory shows r01–r03 5.25 MiB instead of 8.75 MiB if all enemy pages were loaded; r10 9.25 MiB. Low-tier atlas budget 32 MiB: OK.
