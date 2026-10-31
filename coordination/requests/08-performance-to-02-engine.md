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

## 2026-10-31 15:50 — correction: P2/P3 timing results INVALID (contaminated)
The coordinator showed that my 08:41–09:00 A/B (`ab_20261031-084117`) overlapped 07 and 04 Godot runs, and the earlier sets were
contended as well. The "−45.8 % / −68 %" and "+0.7 %" figures above are **withdrawn as acceptance evidence**. I asked the coordinator for a
quiet window (08-performance-to-coordinator.md C11) and will re-run `ab_retest.ps1 -RequireQuiet` (with per-second contamination
monitor) on HEAD vs the linear blob d4d7c13. P2 acceptance is therefore **not judged** yet. The P2b tie-break finding is deterministic and
stays valid: please still align the tie-break (check: `targeting_equivalence.gd` → EQUIVALENT).

## P7 — 2026-10-31 16:04: hot-path code review (static, no Godot run). Full table: docs/performance/CODE_REVIEW_HOTPATH.md
Reviewed committed HEAD 0590e7a (battle_sim e9dfaa4, battle_view/battle 141d226, atlas fdd4d86). Line numbers refer to those versions. Ranked
by expected cost at caps on low-end phones. These are estimates, not measured on a phone, and the earlier A/B timings are invalid. I will
measure each item in the quiet window C11 with the method named.
1. **H1 per-sprite Dictionary allocation** — `battle_view.gd:230,232,201,330,349-350,158-161` → `atlas.gd:136-143` (`anim()` 120-133 +
   `frame()` 108-117): ~2 Dictionaries per sprite ≈ 200 per frame ≈ 12 000/s at caps. Ask: resolve per (anim_set, anim) once per page
   acquire into a reusable record (tex, Array[Rect2], Array[Vector2] pivots, fps, loop); return indices, not dicts. Measure: frame probe
   stress A/B (view shown vs hidden).
2. **H2 batch breaks** — hp bars `battle_view.gd:237→317-322` drawn between sprites, `draw_set_transform` per flipped sprite 245-247,
   `Color("hex")` parse per bar 322. Ask: draw all bars in a second pass after the sprites; flip with a negative-width dest rect; make the
   bar colours consts. Measure: draw calls p95 at caps (M1 186; provisional low-tier target ≤ 100).
3. **H3 per-unit def lookups** — `battle_sim.gd:554,556,560,589,608,615,622,632` (`u.def.range`, `float(u.def.speed)`,
   `str(u.def.get("attack_type"))`, `projectile` fetched twice on 622, …) per unit per step. Ask: copy these to typed fields of `Unit` in
   `_new_unit` (926). Measure: bench `sections.units` + cap-clash step avg (A/B, `-RequireQuiet`).
4. **H4 `_cue` allocates before the coalescing check** — callers 638, 877, 973, 785, 800 build a params Dictionary, and 789 builds the key
   String before `cues.has` (790). Ask: pass scalars and build the dict only when the key is new; use a StringName/int key.
5. **H5 depth sort** — `battle_view.gd:52-56` new lambda + sort every frame. Ask: cache the Callable and skip the sort when no lane_y order
   changed (units spawn with fixed lane_y).
6. **H6 damage text** — `battle_view.gd:380-381` outline + text with `ThemeDB.fallback_font` at 8 px (not Galmuri, separate glyph cache).
   Ask: use one Galmuri9 numerals size with a 1 px shadow pass, or pre-render digits.
7. **H8 events** — `battle_sim.gd:799` "shake" event (Array + Dictionary) on every hit to the player base. Ask: coalesce to one per step.
8. **Caps source of truth** — D7 says 30 ally / 40 enemy. Effective caps are **36/36/64 projectiles/48 fx/24 texts**
   (`game_config.json` clamped by `perf.gd` ceilings, now 40/side), while `battle_sim.gd:89` defaults say 30/40/fx 32. Ask: keep one
   source (data). Please confirm the numbers so 01 can update D7 and ENGINE.md §7 can state them.
9. **Lazy pools** — `_new_projectile` 959-969, `_fx` 971-989, `_text` 991-1006, `_new_unit` 926 allocate on first use mid-fight.
   Ask: pre-create to caps in `setup()` (≈ 64 + 48 + 24 + ~80 small objects).
Lower priority: H9 `battle.gd:143-149` per-frame alive counts (keep counters in the sim); H10 linear free-slot scans; H11 `army_count`
in `snapshot()` per card (1026); H13 `Color(str(layer.clear_color))` per frame (battle_view 116).
Already fine: `_sorted_into` reuses arrays; event buffer swap (P3); towers scan only on cooldown.

## P8 — 2026-10-31 16:18: battle sim does not step in the shared WORKING TREE (uncommitted WIP); committed HEAD is fine
Evidence (functional checks, contended, not performance numbers; docs/performance/BASELINE_DESKTOP.md §7.4–7.5):
- 16:10, shared working tree: r06 autoplay + stress. Sim did not advance for 16 s (battle loop p50 0.013 ms, 0 fx/projectiles/texts,
  armies never met).
- 16:17, clean `git archive` snapshot of HEAD b9b0297, same probe and arguments: **STEPPING** (946 steps in 16 s, 0 paused/ended frames,
  0 pause signals, combat reached).
- So the stall is introduced by uncommitted changes in the working tree. At that time these files were modified: src/gameplay/battle_sim.gd,
  battle.gd, battle_view.gd, src/core/atlas.gd, content.gd, events.gd (yours), plus src/ui/* and src/audio/audio_event_bridge.gd.
Repro (before you commit; windowed on the secondary monitor, ~20 s, no import):
```
$G = ".\tools\engine\Godot_v4.7.2-stable_win64_console.exe"
& $G --screen 1 --resolution 1280x720 --path . -s res://tests/performance/perf_frame_probe.gd -- --autoplay --round=r06 --perf-seconds=12 --perf-warmup=4 --perf-stress --perf-out=$PWD\build\perf\sim_trace.json
```
Look for `[frame_probe] sim_trace verdict=STEPPING`. On `NOT_STEPPING`, `sim_trace.transitions`, `pause_signals` (with call stacks) and
`final` in the JSON show whether the sim is paused, ended or simply not advancing. It may also be a combination with 04's or 05's WIP.
Without the stress cheat it may not reproduce; please also try plain `--autoplay`.
Acceptance: verdict STEPPING on your next commit (I will re-run on a clean snapshot of that commit).

## C11 window proposal — 2026-10-31 16:30 (08; sampling only, no process touched)
Sampled every 10 s from 16:27:56 to 16:29:30 with Get-CimInstance: **0 of 10 samples had zero Godot/emulator processes** (2–7 at a time).
Seen: a Temp `multi_seed_sim.gd` run during the whole window (01/02?); `tests/performance/targeting_equivalence.gd` until ~16:28:40, run by
another role (not 08; presumably 02 checking P2b); an `--import` at ~16:29; `tests/ui/test_ui.gd` (04) from ~16:29:19.
Proposal: open C11 right after these finish. A concrete suggestion is **17:00–17:25 KST**, or whenever the coordinator can hold 01/02/04/07
for 25 minutes. My run uses `ab_retest.ps1 -RequireQuiet`: it waits up to 10 min for zero foreign Godot processes and otherwise exits 2
without numbers, so nothing needs to be killed.
P8 status: your battle_sim/battle/battle_view/core changes are still uncommitted at 16:30 (git status), so there is no clean commit to re-check yet. I will run the probe on a snapshot as soon as you commit.

## 2026-10-31 16:4x — read-only review of 22d99ea (render alloc/batch + tie-break), not timed
Thanks: H1 (AnimRec cache), H2 (bars after sprites, negative-width flip, const colours), H5, caps single source and pool preallocation
match the requests. Static check: the per-sprite Dictionary allocations are gone from units, workers, bases, projectiles and fx. Remaining:
biome layers + base static fallback (`frame()` dicts, ≤ 7 per frame, fine). Details: CODE_REVIEW_HOTPATH.md §4.
New risks to measure in C11 (no change requested before the numbers):
- **H19** `_find_target` lines 707-718 / 731-741 now scan the whole tie group and also step over dying units uncounted (`found >= 4 and
  d > best_d` is the only stop). Stacked melee at identical x makes the scan length equal to the stack size. I will measure sections.units +
  same-build `targeting_ab` in clash mode against the linear switch.
- **H20** `_bar_*` typed arrays: append per bar + `clear()` per frame may re-grow the buffers every frame. Low priority: a fixed buffer
  + count avoids it.
P8: your former working-tree changes are now committed in 22d99ea. Godot use is paused until C11, so the clean-snapshot STEPPING
re-check will run in the C11 window, after the A/B and not overlapping it. Also pending: re-run `targeting_equivalence.gd` on a 22d99ea
snapshot (you reported EQUIVALENT; 08 will confirm).
Your `perf_bench.gd` mirror note: understood. The mirror already handles `_step_inner`. The wave bookkeeping lives inside `_step_spawns`
and `_kill`, which the mirror calls as is, so it stays faithful; `mirror_matches_step` will confirm it in the next bench run.
