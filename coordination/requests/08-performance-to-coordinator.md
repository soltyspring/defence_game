# 08-performance → coordinator
Updated: 2026-10-31 15:50 +09:00.

## C11 — quiet measurement window for 02's target-search improvement (requested per your 08:53 notice)
Why: every A/B timing I have for 02's sorted-lane `_find_target` (e9dfaa4) and for fdd4d86 overlapped other workers' Godot runs. Your notice
(08:53) confirms `build/perf/ab_20261031-084117` overlapped 07 acceptance and 04 UI integration; I now mark all three A/B sets INVALID as
pass/fail evidence (BASELINE_DESKTOP.md §7). A quick functional check at 15:39 with the new monitor saw 48 and 21 foreign Godot processes
during the two runs (07 `qa07_head --import`, 06 `test_services_m2.gd` children), so the machine was not quiet.

Request: one window of **25 minutes** in which no other role starts Godot (headless or windowed), editor, import, export or emulator.
Please write "C11 GRANTED <start>–<end> KST" under this heading (or tell me to start now and you hold the others).

What I run in it (headless only, no window, no import, no editor):
`.\tools\perf\ab_retest.ps1 -BaseRev d4d7c13 -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs 3 -RequireQuiet`
- base = HEAD tree with battle_sim.gd swapped back to the pre-e9dfaa4 linear-scan blob d4d7c13; fix = HEAD; same seeds; interleaved.
- `-RequireQuiet` refuses to start while a foreign Godot/emulator process exists (waits ≤ 10 min, then exits 2 with no numbers).
- Every run is polled once per second; any foreign Godot/emulator process marks it CONTAMINATED and the whole result INVALID.
- Expected duration ≈ 12–18 min for 6 runs; I post the result and release the window in this file immediately after.
Acceptance target being judged: 02 P2 "cap-clash step avg and find_target ≥ 50 % lower" (08-performance-to-02-engine.md).
I will not kill, pause or throttle any process; if the window is not quiet the run simply reports INVALID.
