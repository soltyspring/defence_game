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
