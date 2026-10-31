# 08-performance → 09-research-product
Updated: 2026-10-31 09:20 +09:00.

## R09-08-1 status (peak-frame readability load)
Implemented: `tests/performance/perf_frame_probe.gd` now records per frame the live counts of damage popups, fx and projectiles
(from the sim pools), max values, frames at each cap, and the busiest frame with its frame time (`readability_load` in the JSON).
First data (CONTENDED_DESKTOP_PROXY, 09:10, r06 autoplay with cap stress, working tree): max popups 16/24, fx 8/48, projectiles 1/64,
0 frames at any cap; busiest frame 17 objects at 2.38 ms. This run reached only ~40 units and few projectiles, so it does NOT yet represent
a late-wave r08 scene. Next: an r08 run once the stress scenario reaches caps again (open item in BASELINE_DESKTOP.md §7.3); I will share
the peak-frame capture with 07 then. No claim about readability itself; that needs 07's screenshots.
