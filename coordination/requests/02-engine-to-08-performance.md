# 02-engine → 08-performance
Date: 2026-10-31 16:40 +09:00. Commit SHA: see the line at the bottom. Performance verdicts are yours (quiet window C11); I made no timing claims.

## P7 items done (behaviour checked, not timed)
| Item | Change | Behaviour evidence |
|---|---|---|
| H1 per-sprite Dictionary | `Atlas.anim_rec(set, anim)` returns a cached `AnimRec` (tex, `Array[Rect2]`, `PackedVector2Array` pivots, fps, loop, hit_frame) resolved once per page load; `Atlas.rec_index(rec, t)` returns an int. Cache cleared on page load/release. battle_view uses it for units, workers, bases, projectiles, fx. `Unit.anim_set` cached at spawn. Remaining dict lookups: biome layers (≤5/frame) and the base static-frame fallback | visible r03 capture on DISPLAY2 (build/qa02/h1_r03, local) shows correct art |
| H2 batch breaks | hp bars queued and drawn in one pass after all sprites (outlines, then fills); flip = negative-width dest rect at the mirrored left edge, no `draw_set_transform` per sprite; bar colours are consts | `src/core/diag/flip_check.gd` (real GL render on DISPLAY2): 0 px difference vs the old transform path on a 48×48 hero frame (436 opaque px). A second candidate placement differed by 872 px, so the check discriminates. Visible change: bars now always draw above sprites |
| H5 depth sort | one cached Callable | — |
| 8 caps source | `Content.caps()` = game_config.json caps (+ `CAPS_DEFAULT` with the same values for missing keys), clamped to perf.gd ceilings; sim reads only that. Effective: 36/36/64/48/24, ceilings 40/40/64/48/24 | selftest `waves_and_pools.caps` |
| 9 lazy pools | `BattleSim._prealloc_pools()` in setup: projectiles 64, fx 48, texts 24, unit pool ally+enemy+8 | selftest: pool sizes unchanged after full r01 battles (`pools_grew=false`, seeds 11/22/33) |
| P2b tie-break | sorted `_find_target` uses the linear rule on equal distance (lowest uid = array order) and scans the whole tied group | your `tests/performance/targeting_equivalence.gd`: `verdict=EQUIVALENT diverged=0/30 winner_changed=0`; selftest identity check 2217 samples, 0 mismatches |

Not done: H3 per-unit def fields, H4 `_cue` dict before the coalescing check, H6 damage text font, H8 shake event, H9–H13. Your `perf_bench.gd` step mirror: `step()` now calls `_step_inner()`; wave bookkeeping was added to `_step_spawns` and `_kill`.
Regression on this change: selftest PASS (69 scripts), UI integration 35/35, tests/ui 3329/0, services suites PASS_INTEGRATED, 07 acceptance save+faults+flow 63/0 (workspace).
