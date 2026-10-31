# 08-performance handoff
## M3 — resumed 2026-10-31 15:35 (user restart), updated 15:55 +09:00
- Recovery check: owned paths showed no diff between HEAD and `checkpoint/quota-20261031-092323/08-performance` (86c00f7), and the owned
  working tree was clean, so no work was lost. The HISTORICAL QUOTA CHECKPOINT text was ignored as instructed. Session ID: not exposed.
- User decision processed: **Q1 = A "빵집 기사단 vs 곰팡이 군단" (DECIDED by user, 09:03)**. Coordinator contamination notice
  (08:53) processed. 03 replies A1–A3 processed (boss pages, LA8 font note, pixel-only changes).
- Done (verified, see Validation):
  1. All 08:08–09:00 A/B timing sets are marked **INVALID (contaminated)** in BASELINE_DESKTOP.md §7, BUDGETS.md and the 02 request.
     The P2 acceptance is not judged. The deterministic tie-break finding (P2b) stays valid.
  2. `tools/perf/ab_retest.ps1`: per-second foreign Godot/emulator monitor, CLEAN/CONTAMINATED per run, `validity` in the summary,
     `-RequireQuiet` (waits ≤ `-QuietWaitSec`, exit 2 without numbers). Functional check 15:39 (quick, 1 pair): it correctly reported
     INVALID_CONTAMINATED (48 and 21 foreign processes from 07/06). Its timings are not used.
  3. Quiet-window request **C11** in `coordination/requests/08-performance-to-coordinator.md` (25 min, exact command listed).
  4. Re-theme baseline: `docs/performance/baselines/retheme_before_37b9a93.json` (git-archive of committed tree, so 03/05 WIP excluded),
     `docs/performance/RETHEME_BUDGET.md`, new gate `tools/perf/retheme_compare.py [--strict]`. Caps sent to 03 (A4), 05 (AU1, new file);
     before/after APK build requested from 04 (R6). The existing APK (07:23) is stale and labelled as such.
- Not done / waiting: the quiet A/B re-run (needs C11 grant); after-retheme numbers (03/05 have not committed theme A yet); a fresh APK
  (04); P2b fix (02); 04 R5 font pre-warm; stress-scene unit drop (~40 units) investigation; device data (no phone).
- Next steps (exact): (1) Read C11 in the coordinator file. When it is granted:
  `.\tools\perf\ab_retest.ps1 -BaseRev d4d7c13 -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs 3 -RequireQuiet`. Record the summary
  validity and numbers in BASELINE §7 and the 02 request, then release the window in the coordinator file. (2) When 03/05 commit theme A:
  `python tools/perf/retheme_compare.py --strict`, fill RETHEME_BUDGET §5, then run the frame probe for draw cost. (3) The remaining items from
  the M2 "Next steps" below.
## (history) FINAL CHECKPOINT (user stop order, 2026-10-31 09:18 +09:00 by system clock)
- Stopped at a safe point: there is no measurement or implementation in progress. No new work was started.
- Processes: I left no Godot or emulator processes running. The three Godot processes running at 09:18 belong to 06-services
  (`tests/services/test_services_m3.gd`, `m3_child.gd`), so I did not touch them. I never started an emulator.
- Session ID: not exposed to this agent (no ID visible in the CLI context). Model claude-opus-5.5, trust-all.
- Commit/push: M2 `c635ce8eb20abdb4ca932ca3c02b9c231ef4a027` and SHA record `ae311efcd22934a3d7d632853a19b454a3bb0415`, both pushed and
  confirmed on origin/main. This checkpoint is committed only as a handoff update (SHA in the result report below; on helper failure: PUSH_PENDING).
- Unverified/uncommitted work: none. No owned file except this handoff has changes outside git.
- Time correction: the "09:20/09:25" timestamps in this file, the status file and the M2 docs were estimates. By the system clock, M2
  finished before 09:18. The numbers themselves are unchanged.
- Exact next steps after restart: "Next steps (exact)" below, in order 1–5 (re-run equivalence after the 02 P2b tie-break fix, find the
  cause of the stress unit-count drop, then redo the P1 cap A/B and the R09 r08 dense run, add the 04 R5 pre-warm case, run device capture once a phone is attached).
  Before running Godot, check that `build/.godot-import.lock` is free and how many other Godot processes are running. Call Publish-Task.ps1 without `2>&1 |`.
Updated: 2026-10-31 09:25 +09:00
Status: **M2 verified and pushed (c635ce8, origin/main).** M1 pushed earlier (3c1719a, 65fa163); the
07:32 account-change checkpoint was pushed as e7cc8ba. Session resumed on the new account at 07:37 and again at 08:06 and 08:38
(the 08:21–08:22 requests failed on authExpiryRetry; no work was lost, since every file below was on disk).
Session ID: not exposed to this agent. Model claude-opus-5.5, trust-all. HISTORICAL QUOTA CHECKPOINT lines in coordinator-to-08 belong to
the previous account and were not acted on (user instruction 08:38). Quota at 09:25: usage.json 4.3 %.
User decisions: none affect 08 (D1–D12 DEFAULT, Q1 PENDING); none edited.

## M2 — what was done (all CONTENDED_DESKTOP_PROXY unless stated; no phone evidence)
1. **Font cost** (`tests/performance/perf_font_probe.gd`, `run_perf.ps1 -Font`, secondary monitor, 3 reps, docs/performance/FONT_COST.md):
   cache pages are LA8 (128 KiB per 256², 512 KiB per 512² at 36 px). All ko.json text in every used size ≈ 2.25 MiB. First-use glyph
   hitch: +9.4 ms for a 12 px Korean toast, +9–18 ms per cold screen and size; Galmuri9 numerals ≈ 0. Forbidden 18 px = extra 256 KiB.
2. **Controlled A/B retests** (`tools/perf/ab_retest.ps1`: git-archive snapshots, only battle_sim.gd swapped, same seeds, interleaved):
   fdd4d86 duplicate removal → no measurable change (+0.7 %); e9dfaa4 sorted lanes → cap step avg −45.8 %, p95 −68.2 %, `units` −52 %.
3. **Behaviour check** (`tests/performance/targeting_equivalence.gd`, clean snapshot cd76358): sorted vs linear targeting DIVERGES in
   29/30 runs, winner changes in 3/30 (r01 s22, r03 s11/s33); the cause is the tie-break on exact x ties. Requested as P2b from 02.
4. **Strict semantics** (C10): checks tagged adopted|provisional. Adopted: leak = 0, unexplained pool drift = 0, page ≤ 2048 px.
   Default exit 0 = harness ran; `--strict` → exit 1 only on adopted failures; `--strict-all` → any failure. Same in budget_inventory.py.
   `tests/performance/test_bench_semantics.ps1` covers 7 bench + 3 inventory cases.
5. **Inventory**: fonts section; engine residency model now reads battle.gd (02 P6 roster acquisition confirmed). Per round 5.25–9.25 MiB.
6. **R09-08-1** readability counts added to the frame probe (popups/fx/projectiles per frame vs caps, busiest frame).
7. Bench step mirror updated for e9dfaa4 (`_step_inner`, `_sort_lanes`; `mirror_matches_step=True` on both old and new sim).

## Validation (commands → results)
- `.\tests\performance\test_bench_semantics.ps1` → 10/10 PASS, exit 0 (09:20).
- Godot `--check-only` on perf_bench, perf_frame_probe, perf_font_probe, targeting_equivalence → exit 0; PowerShell parse of
  ab_retest/run_perf/test_bench_semantics → 0 errors.
- `.\tools\perf\run_perf.ps1 -Font -Frame -SkipBench -FontReps 3` (09:10, 6 other Godot processes) → all exits 0, every window verified on
  \\.\DISPLAY2 (-1608,299)-(-312,1058). Output build/perf/20261031-091015.
- `ab_retest.ps1` runs: build/perf/ab_20261031-081107 (fdd4d86) and ab_20261031-084117 (e9dfaa4), 3 pairs each, exit 0.
- `targeting_equivalence.gd` on snapshot cd76358 → `verdict=DIVERGES diverged=29/30 winner_changed=3`.
- Quick bench at HEAD (08:4x) → `harness=OK budgets=FAIL adopted_fails=0 provisional_fails=4` (provisional numeric gates; not a pass).

## Known failures / open / untested
- No phone data (adb lists no device); the ×4 desktop→phone factor is uncalibrated; all runs contended (no C09 exclusive window granted).
- Frame stress at 09:10 reached only ~40 units (M1: 72–75) and 1 projectile in the current working tree (which includes uncommitted 01 data),
  so the battle_view P1 cost at caps was NOT re-measured and R09 dense-scene counts are not representative. Cause not investigated yet.
- Font probe uses plain Labels (not 04's shadow double-draw); phone rasterisation/upload unmeasured.
- Texture-memory monitor gap (M1 §3) still unexplained. android_capture.ps1 only exercised on the no-device path.
- A 08:08 single quick A/B pair showed −23 % for fdd4d86; the 3-pair run did not reproduce it, so the figure is withdrawn (BASELINE §7.1).

## Requests sent (acceptance in each file)
02: P2b tie-break (targeting_equivalence → EQUIVALENT), P1 still open, P4/P5/C09 open, P6 confirmed done. 03: A3 reply (LA8 128 KiB
correction; no bitmap font needed for memory). 04: R5 glyph pre-warm at boot/loading. 09: R09-08-1 status.

## Next steps (exact)
1. Read replies in 08-performance-to-{02,03,04,09} and coordinator-to-08 before each run.
2. When 02 commits a P2b fix: `ab_retest.ps1 -BaseRev <prev blob> -Files src/gameplay/battle_sim.gd -Pairs 3` and re-run
   targeting_equivalence on a clean snapshot (copy the script into the snapshot as done for cd76358).
3. Find why the stress probe now reaches ~40 units (inspect `_stress()` against the current deploy rules / tutorial gating on a clean
   HEAD snapshot), then redo the `-Frame` cap A/B for P1 and an r08 dense run for R09.
4. When 04 names the pre-warm function: add a pre-warmed case to perf_font_probe.gd and confirm hitch ≤ 1 ms desktop.
5. Device runs with android_capture.ps1 once a phone is attached (01 queued the question).

## Commits / push (M2)
- `c635ce8eb20abdb4ca932ca3c02b9c231ef4a027` `[Test] 글꼴 캐시·첫 사용 지연 측정, 엔진 수정 A/B 재측정과 채택 기준 엄격 모드 추가` — 20 owned files; helper output `PUSHED c635ce8... origin/main` (c635fa8..c635ce8); `git branch -r --contains c635ce8` → origin/main. This SHA line was pushed as `ae311ef` ([Docs], origin/main confirmed by fetch).
- Helper note: calling Publish-Task.ps1 with `2>&1 |` makes git fetch's stderr a terminating error (ErrorActionPreference=Stop) and the call aborts before staging. Call it without stderr redirection.
## M1 history (07:25, kept for reference)
M1 delivered and pushed (3c1719a): harness, inventory, desktop proxy baseline, phone procedures, owner requests.
Evidence classes: STATIC (files), DESKTOP_PROXY / CONTENDED_DESKTOP_PROXY (this PC, debug editor binary), DEVICE (none yet), EMULATOR (not phone evidence).

## Ownership (acknowledged, exact)
Own ONLY: tools/perf/**, tests/performance/**, docs/performance/**, coordination/status/08-performance.md,
coordination/handoffs/08-performance.md, coordination/requests/08-performance-to-*.md. tests/performance/** is excluded from 04.
Runtime fixes belong to 02, atlases/fonts to 03, UI/build/export to 04, audio to 05. I measure and request; I edited no foreign file.

## Read receipts / processed
BRIEF.md (all sections), OWNERSHIP.md (eight-worker overrides), GIT_WORKFLOW.md (Publish-Task.ps1 only, explicit owned paths,
[Type] Korean subject, no add ./-A/reset/rebase/stash/force, PUSH_PENDING on failure), ENGINE.md v1.0, INTERFACES.md v1.0,
QUALITY_REVIEW.md (08 profiles fonts/effects/atlases; visible tests on SECONDARY monitor only), WINDOW_STABILITY.md (never close/kill
worker windows — I never did), QUOTA_POLICY.md (97 % checkpoint; serialize heavy Godot runs; do not compare contaminated benchmarks as clean),
DECISIONS.md D1–D10 DEFAULT + Q1 PENDING (no user answers affect perf yet), coordinator-to-08-performance.md: eight-worker block,
Dispatch R4, completion review gate, window stability, quota note, **C09** (contended runs labelled CONTENDED_DESKTOP_PROXY, exclusive
window requested from 02/04), **C10** (harness vs budget verdict split; `--strict`; regression test added).
Other handoffs read: 02 (balance r04–r10, atlas import, cap stress), 03 (roster art plan, fonts), BUILD_PLAN.md (04 device plan).

## Rule violation acknowledged and fixed
Before reading QUALITY_REVIEW.md I ran visible frame probes (06:54–07:13) that opened on the PRIMARY monitor. Since 07:15 every visible
run goes through `tools/perf/run_perf.ps1 -Frame`, which launches with `--screen <secondary index>` and verifies the game HWND rect lies
on the secondary monitor (`--position` with negative X was ignored by Godot here; verified window landed at x=0 on primary).

## Changes (files)
tests/performance/perf_bench.gd, perf_frame_probe.gd, test_bench_semantics.ps1 (+ Godot .uid files); tools/perf/run_perf.ps1,
budget_inventory.py, android_capture.ps1; docs/performance/BUDGETS.md, BASELINE_DESKTOP.md, ANDROID_PROFILING.md, RESOURCE_INVENTORY.md
(generated); requests to 01/02/03/04. Profiling output only under build/perf/ (git-ignored).

## Validation (commands → results)
- `.\tests\performance\test_bench_semantics.ps1` → 5/5 PASS, exit 0.
- `.\tools\perf\run_perf.ps1 -Quick` (07:20, git 0f84461, 6 other Godot procs) → harness=OK budgets=FAIL (4: round_step_p99 2.89 ms,
  cap_clash_step_p95 4.82 ms, cap_clash_step_avg 1.81 ms vs 0.5 ms desktop gates; save_p95 134 ms vs 50 ms). Exit 0 by design; `-Strict` exits 1.
- Full: build/perf/20261031-070413 (cap clash 36/side avg 1.41 ms, `_find_target` ≈ 65 % of step, 0 leaked/unexplained objects).
- Visible: build/perf/20261031-071525 on \\.\DISPLAY2 — caps A/B battle_view 3.75 → 1.54 ms/frame; draw calls p95 186 at caps, 93 at 3 units, 19 menu.
- `python tools/perf/budget_inventory.py --write-doc` → atlases 5.25 MiB battle / 0.25 MiB menu; APK 55.30 MiB (x86_64 28.2 MB + arm64 25.5 MB libs).
- `.\tools\perf\android_capture.ps1` → NO_DEVICE, exit 2 (no fabricated readings).

## Strongest rejection reasons / untested claims
- Zero phone data. Every phone budget (PSS, frame pacing, thermal, battery, cold start, flash save latency) is UNMEASURED.
- The ×4 desktop→phone slowdown used for proxy gates is an uncalibrated assumption.
- All desktop runs were CONTENDED (2–8 other Godot processes; noise p99/p50 up to 53×). No isolated baseline yet (C09 window requested).
- Debug editor binary only; release-template numbers missing (templates directory empty on this PC at 07:00).
- `RENDER_TEXTURE_MEM_USED` battle delta (+2.3 MiB) does not match atlas pages (5.1 MiB): unexplained.
- android_capture.ps1 has only been exercised on the no-device path; its parsing of dumpsys/top/SurfaceFlinger is unverified on a real phone.
- Frame-probe stress mode mutates the live sim (test-only cheat); A/B hides nodes. Both are attribution tools, not gameplay scenarios.

## Owner fixes requested (same scenario retest = the acceptance line in each request)
02: P1 battle_view draw cost/batching, P2 targeting O(n·m), P3 per-step temporaries, P4 save latency + debug log, P5 menu_ready marker /
perf export preset / perf log, P6 residency note, C09 window. 04: R1 x86_64 in universal APK, R2 gfxinfo ≠ Godot frames, R3 shared launcher,
R4 device install info, C09 window. 03: A1 page plan for 6 missing anim sets, A2 occupancy (no action), A3 font sizes for glyph-cache test.
01: queue one user question about a physical low-tier phone.

## Commits / push
- `3c1719aae18dc8bf353e90ccabcf2fd056bc919d` `[Test] 성능 측정 하네스와 리소스 예산 인벤토리, 데스크톱 기준선 추가` — 18 owned files,
  Publish-Task.ps1 output `PUSHED 3c1719aae18dc8bf353e90ccabcf2fd056bc919d origin/main` (7c43ebd..3c1719a HEAD -> main), 2026-10-31 07:26.
- This SHA-record update is a follow-up [Docs] commit of status/handoff only: `65fa163a54e214bddd78acde582b3cd4d32e8af8`
  `[Docs] 08 성능 상태·인수인계에 커밋과 푸시 기록 반영`, output `PUSHED 65fa163... origin/main` (3c1719a..65fa163). Two earlier attempts
  exited 1 before committing (error text not captured by my output filter; the third attempt succeeded unchanged). This line itself is
  recorded locally and will ride with the next 08 commit.

## Next task (08)
1. Read replies in 02/03/04/01 request files; on 02 P1/P2 changes re-run `run_perf.ps1 -Frame` (same seeds, same r06 stress) and post deltas.
2. Exclusive-window isolated baseline when 02/04 confirm a slot (C09).
3. Font cost: measure glyph-cache texture memory and first-use hitch for Galmuri 9/11 at the UI sizes (needs 03 A3 answer).
4. When a phone is attached: `android_capture.ps1` for menu_idle, r06_caps, soak20_caps; fill BUDGETS.md DEVICE column.
