# BASELINE_DESKTOP.md — desktop proxy measurements and bottleneck analysis (owner: 08-performance)
Updated: 2026-10-31 07:20 +09:00. Evidence class of every number here: **CONTENDED_DESKTOP_PROXY** — Windows 11 PC,
Intel i7-9700K (8 threads), RTX 2070 SUPER, 32 GB, Godot 4.7.2 **debug editor binary** (`Godot_v4.7.2-stable_win64_console.exe`),
with 2–8 other Godot processes and seven other CLI workers running. These numbers show relative cost, scaling and where time
goes. They are **not** phone numbers and not an isolated baseline. No phone has been measured (no device attached).

## 1. How to reproduce
```powershell
.\tools\perf\run_perf.ps1                 # static inventory + full headless bench (~2–3 min), output build/perf/<stamp>/ and build/perf/latest/
.\tools\perf\run_perf.ps1 -Quick          # ~30 s
.\tools\perf\run_perf.ps1 -Frame          # + visible frame probes, opened on the SECONDARY monitor via --screen <index>, window rect verified
.\tools\perf\run_perf.ps1 -Strict         # exit 1 if any provisional budget check fails (default: exit 0 = harness ran)
.\tests\performance\test_bench_semantics.ps1   # regression test of the exit/verdict semantics (5 cases)
python tools/perf/budget_inventory.py --write-doc   # regenerates docs/performance/RESOURCE_INVENTORY.md
```
The bench prints `PERF_BENCH harness=OK budgets=FAIL fails=N [ids] class=... strict=... exit=...`. `harness=OK budgets=FAIL`
means the measurement ran and provisional budgets were violated; it is not a pass.
Harness files: `tests/performance/perf_bench.gd` (headless CPU/memory), `tests/performance/perf_frame_probe.gd` (windowed
render/frame), `tools/perf/budget_inventory.py` (static textures/audio/APK), `tools/perf/android_capture.ps1` (phone),
`tools/perf/run_perf.ps1` (runner). The bench never imports, never opens the editor and saves only under `user://perf/`.

Runs cited: bench `build/perf/20261031-070413` (git 067c594 + 63 dirty runtime files, 4 other Godot processes);
frame probes `build/perf/20261031-071525` (git e4aa059 + 34 dirty files, 2 other Godot processes, window on `\\.\DISPLAY2`
at (-1608,299)-(-312,1058), 1280×720). Earlier runs between 06:43 and 07:13 agree within the noise noted below.
Noise floor (constant 2000×sqrt workload): p50 0.058 ms, p99 0.52 ms, max 22.8 ms → single-step maxima are dominated by OS preemption.

## 2. Battle simulation CPU (headless, fixed step 1/60 s)
### 2.1 Real rounds, scripted competent bot, seeds 11/22/33 (309 557 steps)
All steps: avg 0.25 ms, p50 0.17, p95 0.54, p99 1.49 ms. Per round avg 0.15–0.34 ms; peak units 27–44.
Max-step values of 9–109 ms occur at steps with no events and ordinary unit counts (e.g. r05 t=39.9 s, 20 units) and are
attributed to preemption, not sim work (see noise floor). Refused enemy spawns at cap: r06 146, r08 137, r09 234 → rounds 6–9
reach the enemy cap regularly, so the cap case below is a real gameplay case, not a synthetic extreme.
Balance note (02/01 already know): the competent bot loses r04–r10 in all three seeds.

### 2.2 Scaling: N living units per side held constant (refilled every step), best-of-3 by p95, 1200 measured steps
| Mode | N/side | Units incl. dying | Respawns/s | avg ms | p50 ms | p95 ms | p95 of 3 runs |
|---|---|---|---|---|---|---|---|
| walk | 6 | 14 | 0.1 | 0.124 | 0.102 | 0.217 | 0.229 / 0.242 / 0.217 |
| walk | 18 | 39 | 0.5 | 0.391 | 0.367 | 0.524 | 0.524 / 1.109 / 1.009 |
| walk | 36 | 82 | 1.3 | 1.657 | 1.288 | 3.556 | 4.485 / 3.556 / 3.796 |
| clash | 6 | 19 | 1.7 | 0.213 | 0.132 | 0.416 | 0.416 / 0.444 / 0.591 |
| clash | 12 | 38 | 5.9 | 0.434 | 0.285 | 1.129 | 1.565 / 1.351 / 1.129 |
| clash | 18 | 59 | 8.8 | 0.524 | 0.427 | 0.993 | 0.993 / 1.101 / 2.099 |
| clash | 24 | 77 | 12.2 | 1.019 | 0.723 | 2.103 | 2.103 / 3.430 / 2.933 |
| clash | 30 | 88 | 14.4 | 1.328 | 1.054 | 2.627 | 3.172 / 3.090 / 2.627 |
| clash | 36 | 126 | 22.0 | 1.409 | 1.134 | 2.559 | 3.429 / 3.406 / 2.559 |
Cost grows faster than linearly: ×6 units → ×10–13 step time. At the caps the desktop step already sits around the 2 ms
mid-tier **phone** budget of ENGINE.md §7.

### 2.3 Where the step goes at caps (36/side clash, mirror of `BattleSim.step()` verified identical to the real step)
| Section | avg ms | share |
|---|---|---|
| units (`_step_unit` ×all) | 1.875 | 81.0 % |
| reap | 0.105 | 4.5 % |
| economy/waves/AI | 0.096 | 4.2 % |
| towers | 0.082 | 3.5 % |
| hero | 0.056 | 2.4 % |
| aura | 0.042 | 1.8 % |
| projectiles | 0.033 | 1.4 % |
| fx/text | 0.027 | 1.1 % |
| **total** | **2.315** | |
Isolated `_find_target()` for every unit on the same states: avg 1.49 ms, p50 1.06 ms → **target scanning is about 65 % of the
step**. It is an O(units × foes) linear scan per unit per step (`battle_sim.gd` `_find_target`), with the hero added for enemies.
`army_count()` is 4 µs per call (minor).

### 2.4 Pooling, leaks, allocations
- Steady state at caps: 0 objects created that are not held by sim pools (`object_drift_unexplained = 0`); pools stop growing at
  the caps (projectiles 64, fx 48, text 24). Unit objects are recycled through `_unit_pool`.
- 5 back-to-back full battles: 0 objects retained after release (no RefCounted cycles leaked).
- Remaining GDScript temporaries per step (code review, not counted by the engine monitors): `for arr in [players, enemies]` in
  `_reap()` and `for side in [...]` in `_step_towers()` allocate arrays every step; `_area_damage_side()` duplicates the victim array
  on every splash hit; `_damage()` formats a damage String per hit; `events.append([...])` per event and `battle.gd` replaces
  `sim.events` with a new array each frame with events. `snapshot()` builds ~10 Dictionaries at 10 Hz (0.04 ms p50, fine).

## 3. Frame cost in the real game (windowed, secondary monitor, autoplay r06)
| Scenario | frame ms p50 / p95 | GPU ms p95 | Draw calls p95 | Units | Texture mem peak |
|---|---|---|---|---|---|
| Menu, uncapped | 0.80 / 1.39 | 0.77 | 19 | 0 | 13.06 MiB |
| Battle start, vsync 60 | 16.67 / 16.67 (0 frames > 16.7 ms) | 1.18 | 93 | 3 | 15.39 MiB |
| Caps (stress), uncapped, view drawn | avg 3.75 | 1.09 | 186 | 72 | 15.39 MiB |
| Caps (stress), uncapped, view hidden | avg 1.54 | — | — | 72 | — |
- **A/B attribution**: hiding only `battle_view` at caps drops the frame from 3.75 to 1.54 ms → its `_draw()` costs **~2.2 ms per
  frame**, more than the sim step. Earlier runs: 3.87 vs 1.67, 4.13 vs 1.60 ms. The UI layer A/B (HUD hidden + disabled) changed the
  frame by ~0.2 ms, so the HUD is not a bottleneck.
- Frame CPU at caps ≈ engine base ~1.0 + sim ~1.0–1.4 (one step per 60 Hz frame) + battle_view ~2.2 ms ≈ 4.3–4.7 ms on this desktop.
  With the uncalibrated ×4 phone assumption that is ~17–19 ms on a mid-tier phone: 60 fps at caps is at risk; low tier would need
  the 30 fps mode.
- `RENDER_TEXTURE_MEM_USED` = 13.1 MiB in the menu with only the UI atlas resident (0.12 MiB then, 0.25 MiB after 03's ~07:15 update) → ~13 MiB is engine defaults, fonts
  and the 1280×720 render targets. Battle peak is 15.4 MiB, i.e. +2.3 MiB over the menu, while the atlas inventory says the battle
  pages totalled 5.12 MiB at the time. This gap is **not explained yet** (open question: whether some pages were already counted before the
  battle, or the monitor counts differently); it must be reconciled with `Atlas.texture_report()` timing and on device with
  `dumpsys meminfo` Graphics before any texture-memory claim.
- `Performance.TIME_PROCESS` is the worst process time of the previous second (engine updates it once per second), so it is
  reported as `process_ms_worst_per_second`, not as a per-frame value.

## 4. Load, save, content
- Content (all data/** JSON) first load 16–103 ms, p50 22–40 ms.
- Save (`Save.save_progress`: stringify ×2, sha256, write, flush, re-read+verify, rename ×2), 1.1 KB file: p50 12–21 ms, p95 16–96 ms,
  max 163 ms under load. It runs on the main thread on battle end, settings taps and app pause. Load p50 0.9–1.1 ms.

## 5. Static inventory (exact)
See docs/performance/RESOURCE_INVENTORY.md. Atlas pages 5.25 MiB GPU (RGBA8) for any current battle, 0.25 MiB in menus,
2.65 MiB of that unused page area (07:20 regeneration; 5.12/0.12/2.54 MiB before 03 grew `ui_main`). Fonts: 3.09 MiB of Galmuri TTF
on disk, runtime glyph-cache cost unmeasured. Six anim sets referenced by data have no art yet (`fast`, `siege`, `e_brute`, `e_bomber`,
`boss_warlord`, `boss_overlord`) and draw as procedural placeholders, which costs extra draw commands. Audio: 0.76 MiB PCM upper
bound (Godot imported the WAVs to `.sample` files of ~1/5 the size). Debug APK (04, 07:07): **55.30 MiB**, 54.6 MB of it native
libraries for two ABIs (x86_64 28.2 MB, arm64-v8a 25.5 MB); game content ~1 MB.

## 6. Bottlenecks ranked toward release targets, with owner requests
| # | Finding (measured) | Owner | Request file |
|---|---|---|---|
| 1 | battle_view `_draw()` ~2.2 ms/frame at caps, 186 draw calls (93 with 3 units) | 02 | 08-performance-to-02-engine.md P1 |
| 2 | `_find_target()` linear scans ≈ 65 % of a 1.4–2.3 ms step at caps | 02 | P2 |
| 3 | universal APK carries x86_64 native libs (+28.2 MB compressed) | 04 (release pipeline) / 02 (preset) | 08-performance-to-04-client.md |
| 4 | main-thread save p95 up to 96 ms on a busy desktop; phone flash unknown | 02 | P4 |
| 5 | no on-device data at all; ×4 slowdown assumption uncalibrated | user (device) via 01, 04 build, 02 perf preset | P5, 04 request |
| 6 | missing art pages for six anim sets → placeholder draw cost; page plan for bosses | 03 | 08-performance-to-03-art.md |
Each request names the acceptance check in this harness, so the same scenario is re-run after the owner's change.

## 7. Retests of committed engine fixes (2026-10-31 08:08–09:00) — **INVALID as pass/fail evidence (contaminated)**
> **15:50 correction.** The coordinator's notice (08:53 KST) shows that run `ab_20261031-084117` (pair 2: base ended 08:52:41, fix
> 08:52:43–08:55:08) overlapped 07 acceptance (PIDs 31764/46152, from 08:53:10) and 04 UI integration (PIDs 32816/36208, from
> 08:53:11). The other two sets (`ab_20261031-080826`, `ab_20261031-081107`) also ran with 2–7 other Godot processes, and the tool
> counted those only at start. **All three A/B sets in §7.1–7.2 are therefore INVALID for judging 02's targets.** The percentages below stay as
> history only. Do not quote them as results. `tools/perf/ab_retest.ps1` now polls foreign Godot/emulator processes once per second and
> labels any overlap `INVALID_CONTAMINATED`. A quiet 25-minute window was requested (coordination/requests/08-performance-to-coordinator.md
> C11). The re-measurement is pending.
> Still valid: §7.2's **behaviour** finding (`targeting_equivalence.gd`). It is deterministic and does not depend on timing.
Method: `tools/perf/ab_retest.ps1` builds two read-only git snapshots (no checkout; other workers' uncommitted WIP is never measured):
"fix" = the commit's tree, "base" = the same tree with only `src/gameplay/battle_sim.gd` swapped back to the pre-fix blob. Same harness,
same seeds (rounds 11/22/33, scaling seed 77), base/fix runs interleaved, other Godot processes counted per run.

### 7.1 fdd4d86 — `_area_damage_side` no longer duplicates the victim array (P3 item)
Base blob a4a549e vs fix (HEAD c1bf13d), 3 pairs, 2–7 other Godot processes (`build/perf/ab_20261031-081107`):
cap clash avg 1.139 → 1.147 ms (+0.7 %), p95 1.73 → 1.91 ms; bot rounds avg 0.175 → 0.195 ms. Outcomes per seed identical.
**Verdict (INVALID, contaminated): no measurable change was seen** — within run-to-run noise (noise-floor p99 0.13 vs 0.30 ms between the two sides). Correct cleanup,
not a performance lever. (A single quick pair at 08:08 had shown −23 %; the 3-pair run did not reproduce it, so that number is withdrawn.)

### 7.2 e9dfaa4 — sorted-lane `_find_target` (P2 item)
Base blob d4d7c13 (linear scan) vs fix (HEAD 2aa6d28), 3 pairs, 0–8 other Godot processes (`build/perf/ab_20261031-084117`):
| metric (median of 3) | base | fix | Δ |
|---|---|---|---|
| cap clash 36/side step avg | 1.659 ms | 0.899 ms | −45.8 % |
| cap clash p50 | 1.090 ms | 0.626 ms | −42.6 % |
| cap clash p95 | 4.385 ms | 1.394 ms | −68.2 % |
| section `units` avg | 1.931 ms | 0.918 ms | −52.4 % |
| mirrored step total avg | 2.355 ms | 1.353 ms | −42.5 % |
| bot rounds step avg | 0.279 ms | 0.284 ms | +1.8 % (few units; sort overhead ≈ saving) |
New `sort_lanes` section: 0.12 ms of 1.35 ms at caps. Same-build switch (02's `_linear_targets`): target lookup for all 72 units
p50 0.89 ms linear vs 0.24 ms sorted. **The P2 acceptance (≥ 50 % lower cap step avg and find_target) is met for find_target and close
for the step avg (−46 %).** → **WITHDRAWN 15:50: contaminated run, see the correction above; acceptance is NOT judged.**

**Behaviour regression found:** `tests/performance/targeting_equivalence.gd` (same build, only `_linear_targets` differs, committed tree
cd76358) reports `DIVERGES` in 29/30 round×seed runs and a **different winner in 3/30** (r01 seed 22, r03 seeds 11 and 33: linear wins,
sorted loses). Every first disagreement is an **exact x tie**: two candidate targets at the same x (stacked blocked melee units), e.g.
r01 seed 11 t=74.67 s: e_grunt uid 25 → linear picks melee_basic uid 19, sorted picks uid 29, both at x=748.67, d=26.8. The linear scan
keeps the first unit in array order on ties; the sorted lookup returns a later one. The change concentrates or spreads damage
differently on stacked units and shifts balance. Requested from 02 (P2b): deterministic tie-break identical to the linear scan
(lowest array index / lowest uid among equal d). Acceptance: `targeting_equivalence.gd` verdict `EQUIVALENT` (30/30).

### 7.3 Frame stress after these changes (09:10, `build/perf/20261031-091015`)
The stress probe reached only 37–40 units (M1: 72–75) with at most 1 projectile, in a working tree that also contains uncommitted
01 data changes (data/rounds/*, data/heroes/*). So its view A/B (1.76 vs 0.85 ms) is **not comparable** with §3 and the battle_view
P1 cost at caps is **not re-measured**. Cause of the lower unit count not yet investigated (open item).
R09-08-1 readability counts in that run: max simultaneous damage popups 16/24, fx 8/48, projectiles 1/64, 0 frames at any cap.
These do not cover a dense late-wave scene yet.

### 7.4 Stress refill fix (08 bug) and cap-reach check (2026-10-31 16:10, FUNCTIONAL CHECK ONLY — not a performance result)
Cause of the ~40-unit stress scene (§7.3): `perf_frame_probe.gd _stress()` refilled enemies only from `round_def.enemy_ai.pool`, which D18
emptied in r01–r10. Fixed: enemies now come from `Content.round_enemy_roster(round_def)` (bosses excluded; fallbacks: ai pool, then all
non-boss enemies), up to 4 per frame. The probe now writes `stress_reach` (max living per side, frames at each cap, first time both at
cap, roster source).
Single windowed run: r06 autoplay with `--perf-stress`, 4 s warm-up + 12 s, `--screen 1` on `\\.\DISPLAY2`, window rect
(-1608,299)-(-312,1058) verified, exit 0. Output: `build/perf/stress_reach_check.json`. Result: **ally 36/36 and enemy 36/36 in 721/721
measured frames** (both at cap from t = 4.0 s); roster e_brute, e_grunt, e_spitter, e_swarm. Classification: CONTENDED_DESKTOP_PROXY (4
foreign Godot processes at start, 9 seen during the run) and run on the shared working tree, which contains 02's uncommitted
battle_sim.gd/battle.gd changes. The timings from it (frame p95 16.67 ms vsync, draw calls p95 191, texture 17.18 MiB) are **not used for any
judgement**.
New open item: in this run the battle sim did not step. The battle-loop time p50 was 0.013 ms (≈ 1 ms is expected at 72 units), and fx,
projectiles and damage texts stayed at 0 for 16 s, so the armies never met. The cause is not determined: either the sim is paused or not
stepping in this mode. A suspect is the working tree's uncommitted 02 changes, but this is unverified. The next stress run (C11) will use a
`git archive` snapshot of HEAD and record sim.t/paused/ended at the end before any draw-cost number is taken.

### 7.5 "Sim did not step" (§7.4): diagnosed (2026-10-31 16:17, FUNCTIONAL CHECK ONLY — no performance judgement)
Instrumentation: the frame probe now writes `sim_trace` from frame 1 (including warm-up): steps = sim.t advance / step, frames with
sim paused / ended / SceneTree paused / running-without-advance, state transitions with probe time, every `cmd_set_paused` and
`battle_paused` emission with its call stack, and the final sim state. It prints `[frame_probe] sim_trace verdict=STEPPING|NOT_STEPPING ...`.
Run: exactly one windowed run, identical arguments to §7.4 (r06, `--autoplay --perf-stress`, 4 + 12 s, `--screen 1` on `\\.\DISPLAY2`,
rect verified, exit 0), but on a **clean `git archive` snapshot of HEAD b9b0297** (`build/perf/simstall_b9b0297`, project files +
the probe + a copy of the `.godot` import cache, no working-tree WIP). Foreign Godot processes: 3 at start, 7 during (contended).
Result: **verdict STEPPING**. 946 steps in 947 frames (≈ 960 expected for 16 s at 60 Hz, max 4 steps in one frame), 0 paused / ended /
tree-paused frames, 3 frames without advance (normal accumulator jitter), 0 pause signals. Final sim t = 15.77 s. Battle loop p50 0.67 ms.
The armies met: up to 22 damage texts and 11 fx at once. Both sides stayed at 36/36 in 721/721 measured frames.
Conclusion: **not a probe defect and not a defect of the committed game.** The §7.4 stall (battle-loop p50 0.013 ms, no combat for 16 s)
happened with the same probe, round and arguments on the **shared working tree**, which at 16:10–16:18 held uncommitted changes in
src/gameplay/battle_sim.gd, battle.gd, battle_view.gd, src/core/{atlas,content,events}.gd, src/ui/* and src/audio/audio_event_bridge.gd.
So the stall comes from uncommitted WIP (owner most likely 02, not proven). It is reported to 02 and 07 with the repro command, to be
checked before those changes are committed. The §7.4 sentence "the battle sim did not step" applies to that working tree only.

### 7.6 C11 result — 2026-10-31 17:00–17:25: **NOT_RUN** (no quiet moment)
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

### 8. C11 quiet-window results — 2026-10-31 18:00–18:23 KST, **VALID_QUIET** (first uncontended desktop run)
Runner `tools/perf/c11_window.ps1 -Start 18:00 -End 18:10 -EveryMin 1 -Deadline 18:30`: the 18:00:01 check found **0 foreign processes**.
Every step was polled once per second and stayed **CLEAN**: 0 foreign Godot/emulator processes in any step, including all 6 A/B runs.
Code: HEAD 8d026d2 (git-archive snapshot + import cache copy). Machine: i7-9700K / RTX 2070 SUPER, Godot 4.7.2 **debug** editor binary.
Evidence class: **DESKTOP_PROXY (quiet)**, still not phone evidence. Raw: build/perf/c11_20261031-175743/ and build/perf/ab_20261031-180018/.
| Step | Result |
|---|---|
| (0) parse check of the 08 probes in the snapshot | exit 0 / 0 |
| (a) A/B 02 target search: base = linear blob d4d7c13, fix = HEAD 8d026d2, 3 interleaved pairs, same seeds | cap clash 36/side step avg **0.927 → 0.591 ms (−36.2 %)**, p50 −37.4 %, p95 −31.2 %; `units` section −48.5 %; mirrored step −40.1 %; same-build target lookup for 72 units p50 **0.712 → 0.242 ms (−66 %)**, 72/72 same targets; `sort_lanes` 0.06 ms; bot rounds avg 0.124 → 0.151 ms (+21 %, few units, sort overhead); deterministic outcomes identical (won + end time per seed) |
| (b) STEPPING re-check on HEAD (r06, stress) | STEPPING, 947 steps / 16 s (ratio 0.986), 0 paused frames, 36/36 held; frame p50 16.67 ms (vsync), draw calls p50/p95 175/182 |
| (c) view A/B (uncapped, stress, 36/36) | frame avg view shown **2.05 ms** vs hidden **1.00 ms** → battle_view ≈ 1.05 ms per frame; draw calls p95 177 |
| (c) UI A/B HEAD (after 04 1d1e4e3) | shown 2.005 vs hidden 1.511 ms → HUD ≈ **0.49 ms** |
| (c2) UI A/B before 1d1e4e3 (08dc2ec) | shown 2.24 vs hidden 1.693 ms → HUD ≈ **0.55 ms** (so 1d1e4e3 saved ≈ 0.06 ms; small) |
| (d) battle start: `BattleSim.new()+setup()` ×20 (r01, r10) | setup p50 **0.81 / 0.74 ms**, max 1.09 / 2.86 ms; 219 objects created per setup (pools 64/48/24 + 79 units + sim); static memory **+478 KB** |
| (e) first wave-cleared banner (r01 plain autoplay, vsync 60) | wave_cleared at 38.0 s; the 4 following frames were all 16.67 ms (paced), so **no dropped frame on this desktop**. 04's 1d1e4e3 pre-renders banner/toast text; any remaining cost fits inside one 60 Hz frame here |
| (f) targeting_equivalence on HEAD | **EQUIVALENT**, diverged 0/30, winner changed 0 |
Judgements (desktop quiet, provisional targets):
- 02 P2 acceptance "≥ 50 % lower cap-clash step avg **and** find_target": find_target −66 % → met. Step avg −36 % → **not met**. The rest of
  the unit loop (H3 per-unit def lookups etc.) now dominates.
- H1/H2 effect: battle_view ≈ 1.05 ms/frame at caps, compared with ≈ 2.2 ms in M1. **M1 was contended, so the delta is indicative only.**
  Draw calls p95 177 are still above the provisional low-tier target of 100. H2 has not closed that gap.
- Probe correction: the frame probe's first verdict said NOT_STEPPING for the uncapped runs because it counted frames without a step (at
  ~500 fps most frames have none). Recomputed from sim time vs wall time, all 5 runs are STEPPING (ratio 0.986–0.996). The verdict formula is
  fixed (steps vs 60 Hz × elapsed ≥ 0.9) and parse-checked.
- The battle_start event frames in (b)–(e) are not interpretable: `--autoplay` starts the battle during boot, so the 30-frame baseline is boot
  time (~145 ms). The battle-start cost comes from (d).
- Still not measured: phone anything; release-template timings; CPU of 12 audio voices.
