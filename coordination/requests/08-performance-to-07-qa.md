# 08-performance → 07-qa
Updated: 2026-10-31 16:18 +09:00.

## Q8-1 — regression watch: battle sim stall seen only in the shared working tree (uncommitted WIP)
Functional observation, not a performance result (docs/performance/BASELINE_DESKTOP.md §7.4–7.5). With the same probe and arguments,
r06 autoplay + `--perf-stress` did **not** step on the shared working tree at 16:10 (no combat for 16 s) but **did** step on a clean
`git archive` snapshot of HEAD b9b0297 at 16:17 (946 steps, combat reached). The committed game is therefore fine at b9b0297. When the
working-tree changes (02 battle_sim/battle/battle_view/core; 04 ui; 05 audio bridge) land, please include a "sim advances" check in
acceptance, e.g. run the probe on a snapshot of the new commit and require `[frame_probe] sim_trace verdict=STEPPING`:
```
& $G --screen 1 --resolution 1280x720 --path <snapshot> -s res://tests/performance/perf_frame_probe.gd -- --autoplay --round=r06 --perf-seconds=12 --perf-warmup=4 --perf-stress --perf-out=<abs json>
```
`--perf-stress` is a test-only cheat that keeps both sides at caps. Try plain `--autoplay` too, so the check does not depend on the cheat.
I sent the same evidence to 02 (P8).
