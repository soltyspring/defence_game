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

## C11 window proposal — 2026-10-31 16:30 (08; sampling only, no process touched)
Sampled every 10 s from 16:27:56 to 16:29:30 with Get-CimInstance: **0 of 10 samples had zero Godot/emulator processes** (2–7 at a time).
Seen: a Temp `multi_seed_sim.gd` run during the whole window (01/02?); `tests/performance/targeting_equivalence.gd` until ~16:28:40, run by
another role (not 08; presumably 02 checking P2b); an `--import` at ~16:29; `tests/ui/test_ui.gd` (04) from ~16:29:19.
Proposal: open C11 right after these finish. A concrete suggestion is **17:00–17:25 KST**, or whenever the coordinator can hold 01/02/04/07
for 25 minutes. My run uses `ab_retest.ps1 -RequireQuiet`: it waits up to 10 min for zero foreign Godot processes and otherwise exits 2
without numbers, so nothing needs to be killed.
If your suites run in that slot, please pause them or tell me another slot here.

## Q8-2 — 2026-10-31 16:50: export check request for 05's new SFX (static finding)
f0646dd adds 9 WAVs without `.wav.import` (hit_base_mold, hit_bread_1–3, hit_mold_1–3, hit_melee_4–5). The raw-file fallback in
`audio_manager.gd:132-141` does not work in exported builds, so cues `hit_bread`, `hit_mold` and `hit_base_mold` are expected to be
silent in an APK/PCK. Please add an exported-build check: `Audio.load_errors` empty and these cues play. Sent to 05 as AU3.
