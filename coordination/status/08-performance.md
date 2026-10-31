# 08-performance status
Updated: 2026-11-01 00:35 +09:00
M15: resume OK (checkpoint db87912 empty, files intact after the blue screen). All 08 launchers require coordination/heavy_run.ps1 (exit 4 otherwise). Draw calls r08 caps: 03 one-page merge 253f2b6 measured: battle view 58-71 -> 8-9, frame 177 -> 132; HUD 114-125 (hud_top 56) is what is left -> 04 R8 layering (~-70 est.). 02 P9 withdrawn; eceb9f4 EQUIVALENT 0/30. Gate PASS to d724b9a (worst battle 8.75 MiB). H3 not committed yet. Desktop proxy only.
M14: draw calls r08 caps 176-181 = units 50-54 (atlas-page runs; row sort -12..-17 measured, 1 page ~-52 predicted) + HUD ~100 (hud_top 48-50, cards 7-11 each; texture switches) -> 02 P9, 03 A9, 04 R8. Emulator: r08 not launchable (launcher drops args) -> 02 P10; menu PSS 169-176 MB EMULATOR. user:// isolation for all 08 launchers (10 P1). Gate PASS to 84c18ab. C12 requested for after 02 H3. Pushed b0fb679 (verified on origin/main).
M13: C11 VALID_QUIET 18:00-18:23 (all steps CLEAN): P2 step avg -36% (find_target -66%), STEPPING, EQUIVALENT, view 1.05 ms, draw calls p95 177, HUD 0.49 ms, setup 0.81 ms/+478 KB. Desktop only.
M12: AU3 resolved (43/43 imports); range gate PASS to cc5dbb8 (menu exactly at cap after 19245a5, A8 to 03); C11 18:00-18:30 runner + setup/banner measurements prepared.
M11: C11 17:00-17:25 NOT_RUN (8/10/8/2/11/6 foreign Godot processes; nothing touched); next: actively held 30-min slot proposed (e.g. 18:00-18:30).
M10: f0646dd audio gate PASS; 9 WAVs lack .import (3 cues silent in exports, AU3/Q8-2); pool prealloc ~0.16-0.21 MiB; C11 attempt 17:00-17:25 with -RequireQuiet.
M9: gate re-judgement 0 changes; UI review H14-H18 (R7 to 04); 22d99ea reviewed read-only (H1/H2/H5/caps/pools done, new H19/H20); C11 pending; no Godot.
M8: 7705aec asset gate PASS (GPU 9.25 MiB unchanged, PNG -459 B); gate silent-zero bug fixed (self-test 13/13); P8 waiting for the 02 commit; C11 proposed 17:00-17:25 (0/10 quiet samples). Q3 title and Q2 hold recorded.
M7: sim_trace added; clean HEAD b9b0297 snapshot = STEPPING (946 steps/16 s, combat); stall only on the shared working tree with uncommitted WIP -> P8 to 02, Q8-1 to 07. Q2 = hold (no monetization) recorded.
M6: stress refill fixed (round roster); single contended functional run reached 36/36 for 721/721 frames; sim did not step in that run (open, cause unknown); not a performance result.
M5: static hot-path review docs/performance/CODE_REVIEW_HOTPATH.md (H1–H13, 24/24 line refs verified), P7 request to 02, D7 caps FYI to 01; stress unit-drop root cause = D18 empty enemy_ai.pool vs probe refill (fix pending); asset gate PASS; no Godot used.
M4: static per-commit asset gate tools/perf/asset_budget_check.py (exit 1 on cap breach) + self-test 11/11 PASS; 03 theme A redraw 2b350c4 PASS (GPU unchanged 9.25 MiB, 0 page size changes); 05 committed audio PASS; C11 still waiting on the coordinator; no Godot used in M4.
Status: M3 (contamination handling, quiet-window request, re-theme baseline + caps) VERIFIED and PUSHED (c58c59e, origin/main).
Theme Q1 = A "빵집 기사단 vs 곰팡이 군단" (user decision 09:03) processed.
Current task: wait for C11 quiet window (coordinator) to re-measure 02's target search; wait for 03/05 theme A commits for the after-baseline.
Key facts: 08:08–09:00 A/B timings INVALID (contaminated); pre-retheme baseline 37b9a93 = atlas 9.25 MiB all/worst battle, 0.25 MiB menu,
SFX PCM 0.76 MiB, music 0.53 MiB, APK 56.29 MiB (stale 07:23 build). Caps: worst battle ≤ 12 MiB, all ≤ 14 MiB, SFX PCM ≤ 2 MiB,
music ≤ 1.5 MiB, APK content +≤ 2 MiB.
Validation 15:5x: test_bench_semantics 10/10 PASS; retheme_compare --strict caps=PASS (exit 0) and synthetic breach exit 1; py_compile and
PowerShell parse OK; ab_retest monitor flagged contaminated runs correctly. No phone evidence; all desktop timings contended.
