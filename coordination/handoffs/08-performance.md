# 08-performance handoff
Updated: 2026-10-31 07:32 +09:00
Status: **STOPPED FOR ACCOUNT CHANGE (user request 07:32).** M1 delivered and pushed (3c1719a, 65fa163). M2 was only started (reading inputs); no M2 code or result exists.

## ACCOUNT-CHANGE CHECKPOINT (07:32)
- Session ID: not exposed to this agent (no session id visible in the CLI context). Model claude-opus-5.5, trust-all. No ACCOUNT_REQUIRED.md was written by 08, because no quota/auth error was observed; the stop came from the user.
- User decisions: none of them concern 08. DECISIONS.md D1–D10 are DEFAULT and Q1 is PENDING. They are preserved unchanged, and 08 never edits them.
- Current task when stopped: **M2**. User instruction 07:29: (1) read 03's typography evidence and 02/04 replies; (2) build and run an isolated benchmark of Galmuri glyph-cache memory and first-use hitch at the real UI sizes (Galmuri11/Bold 12/24/36, Galmuri9 10/20), with a baseline and recorded conditions, coordinated with other Godot runs; (3) re-test only the engine fixes that are available, using identical seeds; (4) label contended results and missing device evidence; (5) check budget_fails against exit semantics and add strict mode for adopted thresholds; (6) commit/push; (7) send fix requests to owners.
- Done in M2 before the stop (reading only, nothing written):
  - TYPOGRAPHY.md: 03 measured a glyph cache of one 256×256 L8 page (64 KiB) per (font, size), 0.56 MiB for 9 caches. Allowed sizes are 12/24/36 and 10/20.
  - src/ui/ui_style.gd: FONT_S/M=12, L=24, XL=36, NUM 10/20. Pixel flags are forced at load. Galmuri9 falls back to Galmuri11.
  - assets/fonts/*.ttf.import: dynamic fontdata, `compress=true`, `antialiasing=0`.
  - Replies: none yet from 02, 03 or 04 in their requests sections (no C09 slot either).
  - 02 has **uncommitted** WIP in src/gameplay/battle_sim.gd (`_area_damage_side` no longer duplicates the array, i.e. my P3 item), src/core/atlas.gd, app.gd and selftest.gd. These are not committed, so there is no committed engine fix to re-test yet.
  - Shared lock convention found: hold or wait on `build/.godot-import.lock` (07 QA-R2). 07 uses `<base>/.run.lock`. 04 has `tools/build/visible_launch.ps1`, a secondary-monitor launcher with MonitorFromWindow verification.
  - At 07:29, 3 other Godot pairs were running, so the machine was not isolated.
- Unfinished files: none. No M2 file was created, so there is no WIP for the checkpoint branches. The only uncommitted 08 change is this handoff file.
- Checkpoint commit: **PUSH_PENDING / NOT COMMITTED.** At 07:33, `Publish-Task.ps1 -Type Docs -Paths coordination/handoffs/08-performance.md` refused with "Index is not empty. Ask coordinator; do not modify other staged files." Another role had files staged in the shared index, and I did not touch the index. This handoff is saved on disk. Please commit it via the coordinator checkpoint branch or by re-running the same helper command once the index is empty. Last pushed 08 commits: 3c1719a, 65fa163 (both `PUSHED ... origin/main`).
- Known failures and open issues (unchanged from M1): with PROVISIONAL budgets the bench reports `harness=OK budgets=FAIL` (4 checks: round_step_p99, cap_clash_step_p95, cap_clash_step_avg, save_p95), and all runs are CONTENDED. There is no phone evidence (adb lists no devices). The texture-memory gap (+2.3 MiB measured vs 5.1 MiB of pages) is unexplained. android_capture.ps1 has only been verified on the no-device path.
- Validation state: M1 validation is the last valid one (see Validation below). Nothing was run in M2.

## Exact next steps after login (M2)
1. Reread coordinator-to-08-performance.md, DECISIONS.md, the 02/03/04 handoffs and the replies in 08-performance-to-*.md.
2. Add `tests/performance/perf_font_probe.gd`. For each font (Galmuri11, Bold, Galmuri9) at each allowed size, plus the forbidden sizes as a control, measure on a cold start: font load time; first-draw hitch of an ASCII string, a 20–40-syllable Korean UI string and a full ko.json text pass; RENDER_TEXTURE_MEM_USED and static memory before and after; and the cache page count/size via FontFile.get_texture_count/get_texture_image per size. Run it windowed on the secondary monitor (04's visible_launch.ps1 or my --screen path), because glyph rasterisation needs a real renderer, and record the baseline (fallback-font run) and the conditions.
3. Before any Godot run: wait while `build/.godot-import.lock` is held or another heavy Godot run is active. Record the process inventory and label the class CONTENDED or isolated.
4. Strict mode for adopted thresholds: in perf_bench.gd and budget_inventory.py, tag each check `adopted|provisional`. `--strict` fails only adopted checks (`--strict-all` fails all). Extend test_bench_semantics.ps1 with an adopted-vs-provisional case. Adopted candidates: object leak = 0, unexplained drift = 0, page-size hard limit, APK ≤ 60 MB.
5. Re-test only engine fixes that 02 has committed, with seeds 11/22/33 and the r06 stress A/B, against the M1 runs (build/perf/20261031-070413, -071525).
6. Publish with Publish-Task.ps1, then update requests (02 font/cache or batching findings; 03/04 font sizes) and this handoff.

## Previous status line
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
