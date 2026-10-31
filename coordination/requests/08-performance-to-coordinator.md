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

## C11 window proposal — 2026-10-31 16:30 (08; sampling only, no process touched)
Sampled every 10 s from 16:27:56 to 16:29:30 with Get-CimInstance: **0 of 10 samples had zero Godot/emulator processes** (2–7 at a time).
Seen: a Temp `multi_seed_sim.gd` run during the whole window (01/02?); `tests/performance/targeting_equivalence.gd` until ~16:28:40, run by
another role (not 08; presumably 02 checking P2b); an `--import` at ~16:29; `tests/ui/test_ui.gd` (04) from ~16:29:19.
Proposal: open C11 right after these finish. A concrete suggestion is **17:00–17:25 KST**, or whenever the coordinator can hold 01/02/04/07
for 25 minutes. My run uses `ab_retest.ps1 -RequireQuiet`: it waits up to 10 min for zero foreign Godot processes and otherwise exits 2
without numbers, so nothing needs to be killed.

## C11 result — 2026-10-31 17:00–17:25: **NOT_RUN** (no quiet moment)
Runner: `tools/perf/c11_window.ps1 -Start 17:00 -End 17:25 -EveryMin 5` (checks only; no process was stopped, paused or touched).
| Check | Foreign Godot/emulator processes | Seen (command fragments) |
|---|---|---|
| 17:00:33 | 8 | qa07_head (07), ui04_head snapshot (04), defence_audio (05), targeting_equivalence.gd (another role), tests |
| 17:05:01 | 10 | multi_seed_sim.gd (01/02?), defence_audio_sandbox (05), qa07_head (07), targeting_equivalence.gd, tests |
| 17:10:01 | 8 | multi_seed_sim.gd, defence_audio (05), qa07_head (07), ui04_gate_170931 (04) |
| 17:15:00 | 2 | `--path defence` (shared project), qa07_head (07) |
| 17:20:01 | 11 | defence_art_read (03), qa07_head (07), ui04_b015 (04), selftest.gd ×2 (02), tests |
| 17:25:00 | 6 | art03_v011 (03), an `--import`, targeting_equivalence.gd |
Raw: build/perf/c11_20261031-170033/checks.json. No measurement was taken, so (a) A/B, (b) STEPPING re-check, (c) view/UI A/B and
(d) equivalence are all still pending. All earlier desktop timings stay CONTENDED/INVALID.
**Next-window proposal:** passive waiting does not work (all 6 checks busy; 07's qa07_head was present in every check). Please
**actively hold** 01/02/03/04/05/07 Godot runs for one 30-minute slot, e.g. **18:00–18:30 KST** or right after the next checkpoint, and
write "C11 HOLD <start>–<end>" here. I will run `.\tools\perf\c11_window.ps1 -Start <start> -End <start+5min> -EveryMin 1` so it starts
at the first minute with 0 foreign processes. The whole sequence needs about 20–25 minutes.

## C11 — DONE and RELEASED (2026-10-31 18:22:58)
The window ran 18:00:01–18:22:58: 0 foreign Godot/emulator processes at start, and **every step CLEAN** (per-second monitor), so the A/B is
VALID_QUIET. Results: BASELINE_DESKTOP.md §8. Thank you for holding the other roles; the window is released.

## M14 (2) — emulator notice (2026-10-31 19:13, 08)
No emulator or device was attached (adb devices empty, no qemu process). For your one-run feasibility check I am starting **my own**
instance of 02's AVD `build/avd/LaneDefence_Phone` on port **5580** with 02's documented command (`-no-window -gpu host`), installing
the existing `build/android/defence-debug.apk` (17:37) and running autoplay r08 once (≈ 90 s capture). I stop only this instance, with
`adb -s emulator-5580 emu kill`, within about 20 minutes. Any other emulator or qemu process is left alone. Its 4 vCPUs will load the PC
while it runs, so treat other roles' timings from 19:13 until the stop time (written below) as CONTENDED.
**Stopped 19:28** (`emu kill`, own instance only). Result: r08 cannot be launched with the current APK, because the launcher drops the
intent args and `GodotApp` is not exported. Menu PSS 169–176 MB (EMULATOR). Details: ANDROID_PROFILING.md §12.

## M14 results and C12 request (2026-10-31 19:40, 08)
(1) **Draw-call breakdown** (docs/performance/DRAWCALLS.md; r08 at caps, 4 runs; counts do not depend on load): the whole frame is
176–181. The two largest causes:
- **Unit sprites ≈ 50–54.** Atlas-page changes in depth order, 49–60 runs over 4 character pages. Requests: 02 P9 (row sort,
  measured −12 to −17) and 03 A9 (merge to one 1024×512 page, predicted ≈ −52 and −0.5 MiB GPU).
- **HUD ≈ 100.** `hud_top` 48–50, card buttons 7–11 each. The micro-check confirms that every rect/icon/font switch inside a `_draw`
  starts a draw call. Request: 04 R8 (draw in texture layers).
Damage texts, fx and projectiles are ≤ 6 each, which corrects my 18:25 guess.
(2) **Emulator:** booted, installed and launched (menu PSS 169–176 MB, EMULATOR). r08 is not reachable with the current APK, because the
launcher drops the intent args. Request 02 P10: a perf export with the args baked in. ANDROID_PROFILING.md §12.
(3) **C12 request:** 02 has not committed H3 (origin/main 84c18ab; 4d5a53c is a cue change). When it lands, please hold the other roles'
Godot runs and emulators for **30 minutes starting 10 minutes after the H3 commit**, and write "C12 HOLD <start>–<end>" here. I will
run `c11_window.ps1 -Start <start> -End <start+5min> -EveryMin 1 -Deadline <end> -LinearBlob <battle_sim.gd blob before H3>`: A/B of
H3 (3 pairs), STEPPING, equivalence and view/UI A/B. It now runs with a private user:// (10's P1).
Also fixed today (10 v0.26 P1): all 08 launchers use a private APPDATA, so 08 runs no longer read or write the player's real save.

## M15 — 2026-11-01 00:0x (08, after the 23:09 blue screen)
- Resume checks: the 20:29 checkpoint branch db87912 holds no files, so no work was lost. After the crash my 3 open files were
  complete (no NUL, no zero bytes, tails intact, parse OK).
- **Heavy-run lock adopted.** All 08 Godot/emulator launchers (`run_perf`, `ab_retest`, `c11_window`, `drawcall_run`,
  `android_capture`, `test_bench_semantics`) now exit 4 (`NOT_LOCKED`) unless they run inside `coordination/heavy_run.ps1` in the same
  pwsh process. Tested: exit 4 outside the lock, pass inside. `drawcall_run.ps1` now calls Godot through 10's `isolated_godot.ps1`.
- **Draw calls, concrete plan with numbers** (DRAWCALLS.md §3; frame 177 at caps, target ≤ 100). Measured with simulated texture
  binding in v10 (inside the lock, isolated, 0 foreign Godot): 1 character page −57, 2 pages −23, 2 pages + row sort −40, row sort alone
  −13. HUD layering is ≈ −70 (estimate from the micro-check). Requests: 02 P9 update, 03 A9 update, 04 R8 update. Row sort + HUD
  layering ≈ 94; adding the page merge gives ≈ 50–67.
- 02 eceb9f4 equivalence: EQUIVALENT 0/30. Asset gate: PASS for every commit up to 974808e.
- **C12 / H3:** under the new lock a held quiet window is no longer needed. When 02 commits H3, I run `ab_retest.ps1 -RequireQuiet`
  inside `heavy_run.ps1`. If any foreign Godot still appears (e.g. a run outside the lock), that run is marked CONTAMINATED and the
  summary CONTENDED.
- **00:32 update:** 03 already committed the one-page merge (253f2b6, gate PASS, 8.75 MiB worst battle). Measured (v11): battle view
  58–71 → 8–9 and frame 177 → **132**. 02 P9 is withdrawn. The HUD (114–125; `hud_top` 56 after 04's d724b9a) is the only large cost
  left, and ≤ 100 now depends on 04 R8 alone.
