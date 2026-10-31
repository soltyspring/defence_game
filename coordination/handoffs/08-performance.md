# 08-performance handoff
## M16 — 03 A19 D1 32 px roster: performance preview before release (2026-11-01 00:55–02:1x KST)
- **H3:** 08 has no uncommitted H3. H3 is 02's change to `battle_sim.gd`, and 02 has neither committed it (origin/main 1aec5fe) nor
  left it in the working tree (0 diff lines). There was nothing to commit or A/B.
- **New tool:** `tools/perf/art_variant_ab.ps1`. It requires heavy_run (exit 4 otherwise) and makes `git archive` copies (base / draft)
  of one commit. It runs `ART_DRAFT32=<Draft> python tools/art/build.py` only inside the draft copy and checks that the working-tree
  `assets/atlases` hashes are unchanged. Then it runs `asset_budget_check --tree --base <rev>` on both copies, `--import` per copy,
  and interleaved pairs of the probe in `--dc-set=units --dc-uncapped` mode via 10's `isolated_godot.ps1`. A thread job lists
  foreign Godot/emulator processes every second and marks a run CONTAMINATED when it sees one.
- **Probe additions:** `perf_drawcall_probe.gd` gained `--dc-set=units`, `--dc-uncapped` (holds `max_fps = 0` every frame, because
  the Perf autoload re-applies the 60 cap after boot), per-phase frame_ms, view and unit `_draw` µs, GPU/render-CPU ms and the unit quad
  area. `drawcall_view.gd` times `_draw`/`_draw_unit`, sums the unit quad area, and can skip the page-run bookkeeping
  (`analyze_runs`).
- **Results** (676b105, desktop proxy, **not phone**; docs/performance/UNIT_SIZE_D1.md):
  - Memory D1FULL: worst battle 10.75 MiB, all pages 11.00 MiB, menu 0.50 MiB. PASS, and equal to 03's estimate. The cause is
    `char_player` 1024×512 → 1024×1024 (+2 MiB). The 2-unit D1 already needs 1024×1024.
  - r08 caps, same seed, 2 pairs: draw calls 134/9 unchanged. Whole frame within noise. Unit cost +0.04 to +0.08 ms. Unit quad area
    ×2.0–2.1, a fill-rate risk on phones (estimate ≈ 1.9 Mpx/frame, ≈ 3.4 Mpx with 02's 4/3 zoom).
  - run base_1 was CONTAMINATED: 10's and 01's jobs overlapped (their NOTE lines in heavy_run.log at 01:49 and 01:50). The table uses
    the 3 CLEAN runs. The first attempt (01:17) was capped at 60 fps by Perf.set_fps_cap; its frame times were discarded, and its
    draw-call and static values match.
- **Requests:** 03 A12 (results; ask: the body-box / frame-rect ratio so the fill estimate can drop transparent margins; my self-test
  is fine as is), 02 (decision input; P10 is now the blocker for a device check; FYI on Perf.set_fps_cap; H3 not seen).
- **Validation:** art_variant_ab exit 0 twice (the second is the valid one). 3 of 4 probe runs CLEAN, isolated, real save 614A1FAC
  unchanged, `ART_DRAFT32` unset afterwards, working-tree atlases unchanged. `test_asset_budget_check.py` 13/13 PASS. Runner parse 0
  errors, GDScript indentation tabs only. Every heavy step ran inside heavy_run (lock waits 842 s and 1347 s).
- Commit: `1695e06386227b4db6c375d5fdcf56279cbf3b07` `[Test] 03 D1 32px 유닛 시안 출시 전 성능 미리보기(…)`, 9 files.
  Publish-Task.ps1 printed `PUSHED 1695e06… origin/main` (1aec5fe..1695e06). Checked with `git cat-file -t` = commit and
  `git branch -r --contains` = origin/main.
- Next: when 02 commits H3 or P10, or 04 commits R8, run the matching locked A/B (M15 next steps). For a D1 adoption, re-gate the
  real commit and run `art_variant_ab.ps1` style checks on a device once P10 exists.

## M15 — resume after the 23:09 blue screen; draw-call reduction plan with numbers (2026-10-31 22:58 – 2026-11-01 00:2x KST)
- **Resume check:** the 20:29 checkpoint `checkpoint/quota-20261031-202729/08-performance` (db87912) has no file changes vs ae6f9af,
  and M14 (b0fb679, cfa0c28) is on main, so no work was lost. After the crash, my 3 open files (`drawcall_view.gd`,
  `perf_drawcall_probe.gd`, `drawcall_run.ps1`) were complete: no NUL, no zero bytes, tails intact, parse OK.
- **Heavy-run lock:** `tools/perf/perf_isolation.ps1` gained `Test-InHeavyRun`/`Assert-HeavyRun`, which read
  `coordination/.runtime/heavy_run.log` for this pwsh PID. run_perf, ab_retest, c11_window (unless -DryRun), drawcall_run,
  android_capture (after device detection) and test_bench_semantics exit 4 `NOT_LOCKED` outside `coordination/heavy_run.ps1`. Tested:
  exit 4 outside, True inside the same process, False after the lock ends. A child pwsh inside the lock reads False, so call the tools
  with `&` directly in the script block.
- **Simulated page merge (counts only):** `drawcall_view.gd` `tex_mode` merge1/merge2 binds character sprites to one shared or one
  per-side texture with their own region rects (wrong pixels by design). New probe phases `+merge1sim`, `+merge2sim` and
  `+merge2sim_row`; 3 new micro rows for font size/kind.
- **v10** (origin/main 36e2a9e; one lock, serial: import → probe → micro → equivalence; 23:32–23:41; 0 foreign Godot at start;
  10's `isolated_godot.ps1` for every call; real save unchanged): frame 177, units −55, hud_top −48, cards 9 each. Merge: 1 page view
  9 (**−57**), 2 pages 46 (−23), 2 pages + row 31 (−40), row 47 (−13). Micro: ui12 label + num10 cost 24, ui12 + ui12 1, ui 12/24 px 24
  (each size is its own glyph texture). Equivalence on 36e2a9e (contains 02 eceb9f4): **EQUIVALENT 0/30**.
- **Requests with numbers:** 02 P9 update (exact compare, −12 to −17; −40 with 2 pages), 03 A9 update (option A one 1024×512 page
  −57, option B −23/−40; acceptance view ≤ 15 / ≤ 50), 04 R8 update (4-pass layer order; hud_top ≈ −40, buttons ≈ −30, estimate; their
  NUM_READ WIP removes a font switch; acceptance hud_top ≤ 10, card ≤ 5). Plan in DRAWCALLS.md §3: row sort + HUD layers ≈ 94; with
  the page merge ≈ 50–67. Coordinator M15 note. 06 download size recorded in BUDGETS.md (reply file 08-performance-to-06-services.md).
- **H3:** not committed up to origin/main 7daaed5 (00:16 check). Plan: inside heavy_run, `ab_retest.ps1 -BaseRev <pre-H3 blob> -FixRev <H3>
  -Files src/gameplay/battle_sim.gd -Pairs 3 -RequireQuiet`, then `targeting_equivalence.gd` (or `drawcall_run.ps1 -Equivalence`).
  Label CONTENDED/CONTAMINATED if any foreign Godot is seen.
- **v11 after 03's merge** (03 committed A9 option A in 253f2b6 at 23:57, while I wrote the request; origin/main 64a95c6, one lock,
  00:28–00:32, 0 foreign, isolated, real save unchanged): battle view 58–71 → **8–9**, page runs 1, frame 177 → **132**. HUD alone
  114–125 and `hud_top` 56 (+8 vs v10, after 04's d724b9a; mechanism not isolated). My micro estimate for ui-12 numbers (−1 to −2 per
  card) was not confirmed, and I corrected it in the 04 file. 02 P9 withdrawn. ≤ 100 now depends on 04 R8 alone.
- **Gate:** ae6f9af..974808e PASS (no asset/data commit), and 974808e..d724b9a PASS: 03 253f2b6 worst battle 9.25 → 8.75 MiB, all
  pages 9.00 MiB; 05 4d6f9bd SFX 0.94 MiB.
- **Validation:** test_bench_semantics **11/11 PASS** inside the lock (00:14, isolation log found, real save 614A1FAC unchanged).
  drawcall_run v10 exit 0, isolated. PowerShell parse 0 errors for perf_isolation, run_perf, ab_retest, c11_window, drawcall_run,
  android_capture and test_bench_semantics. Lock-guard test exit 4 / pass.
- Not touched: 04's uncommitted hud_top/touch_button/ui_style edits (read-only diff only) and other roles' WIP.
- Commit: `3c8ff18a38585fe4c87bcb059c399ed9b4563299` `[Test] 드로우콜 감소안 실측(…), 성능 실행 전부 머신 잠금 필수화`, 19 files.
  Publish-Task.ps1 printed `PUSHED 3c8ff18… origin/main` (ecf06e7..3c8ff18). Checked with `git cat-file -t` = commit and
  `git branch -r --contains` = origin/main.
- Next: (1) when 04 commits R8 layering, run `heavy_run.ps1 -Label '08-drawcalls-r8' -Script { & .\tools\perf\drawcall_run.ps1
  -Rev origin/main -SkipMicro }`; acceptance hud_top ≤ 10, card ≤ 5, frame ≤ 100. (2) When 02 commits H3, run ab_retest
  -RequireQuiet + equivalence in the lock. (3) Run asset_budget_check.py --range d724b9a..origin/main on new commits.

## M14 — draw-call breakdown, emulator check, user:// isolation (2026-10-31 18:47–19:40 KST)
- **(1) Draw calls** (DRAWCALLS.md). New `tests/performance/drawcall_view.gd` (test-only subclass of 02's battle_view: category
  switches, page-run counter, row/page sort modes), `perf_drawcall_probe.gd` (interleaved reference phases, HUD children identified
  by script and text), `perf_batch_micro.gd`, and `tools/perf/drawcall_run.ps1` (snapshot + own import + isolated run). r08 at caps:
  frame 176–181. **Units 50–54** come from atlas-page runs (49–60 per frame over 4 character pages); the row sort measured −12 to −17;
  one merged page is predicted at ≈ −52. **HUD ≈ 100**: hud_top 48–50 and card buttons 7–11 each. The micro-check shows every rect/icon/
  font switch costs a draw call, while grouped items cost 1 per texture. Requests: 02 P9, 03 A9, 04 R8. Texts, fx and projectiles are
  ≤ 6 each, which corrects the 18:25 guess.
- Snapshot pitfall found: the shared `.godot/imported` holds 03's WIP textures. Without the snapshot's own `--import`, UiStyle disables
  icons ("stale import"), and the HUD rows of v1–v5 were measured without icons.
- **(2) Emulator** (ANDROID_PROFILING.md §12). I started my own instance of 02's AVD at 19:14 and stopped it with `emu kill` at
  19:28, after announcing it in the coordinator file. It booted in 57 s, and the APK installed and launched. **r08 is not reachable**:
  GodotAppLauncher drops `--esa command_line_params` and GodotApp is not exported. Request 02 P10. Menu PSS 169–176 MB (EMULATOR).
  The shared adb server was restarted 4 times by another tool. `android_capture.ps1` fixes: exit 2 `APP_NOT_RUNNING` when no sample saw
  the app, adb retry, pid per sample, and the Android 14+ layer name, which gave 0 frames before.
- **(3) C12:** 02 has not committed H3 by 84c18ab. The request with its plan is in 08-performance-to-coordinator.md.
- **10 v0.26 P1 (user:// isolation):** new `tools/perf/perf_isolation.ps1` (private APPDATA per tool, fresh save, proof log), used by
  run_perf, ab_retest, c11_window, test_bench_semantics (new case 11) and drawcall_run. Reply in 08-performance-to-10-research-systems.md.
- Gate: f41fd12..84c18ab (03 aee329b, b113085; 05 65502e8, 11c29cc) **PASS**, with page sizes unchanged.
- Validation: test_bench_semantics 11/11 PASS, isolation log found, APPDATA restored. drawcall_run on 84c18ab exit 0, isolated, no
  stale-import warning. PowerShell parse 0 errors for the 6 changed scripts. The android_capture menu run exit 0 had 7/7 samples with
  the app and 631 frames.
- Commit: `b0fb67930f76e8911ef75b568b1f6abc835fc3b7` `[Test] 드로우콜 항목별 분해(…), 에뮬레이터 r08 실행 불가 확인, 성능 실행 전부
  비공개 사용자 폴더로 격리`, 24 files. Publish-Task.ps1 printed `PUSHED b0fb679… origin/main` (3cbdd23..b0fb679). Checked with
  `git cat-file -t` = commit and `git branch -r --contains` = origin/main.

## M13 — C11 quiet window done (2026-10-31 18:00–18:23 KST)
- First **VALID_QUIET** desktop run. 0 foreign processes at 18:00:01, and all 10 steps were CLEAN under the per-second monitor. Results:
  BASELINE_DESKTOP.md §8.
- Key numbers: P2 A/B cap step avg −36 % (find_target −66 %; the ≥ 50 % step target is not met → H3 next); STEPPING on HEAD; view ≈ 1.05
  ms/frame, draw calls p95 177 (> 100 target); HUD 0.55 → 0.49 ms with 04 1d1e4e3; setup 0.81 ms / 219 objects / +478 KB (the earlier
  static estimate was 2.3× low); first banner: no dropped frame at vsync 60 on desktop; equivalence EQUIVALENT 0/30.
- Fixes in 08 code: probe verdict now uses sim time vs wall time (the uncapped runs were falsely NOT_STEPPING); parse-checked on the
  snapshot (18:23). Gate: menu residency now counts `load_policy: "menu"` pages (title logos), so the menu reads 0.50 MiB (conservative,
  both languages) instead of 0.25. Self-test 13/13.
- Pre-window static check: 03 11ceacb/e3c4621 + 15851e2/7b93d1f → PASS (title split into ko 512×64 / en 256×128, group "title", released
  outside menus).
- The window was released to the coordinator at 18:22:58. Owners informed: 02 (P2/H3/H19/P8/P2b/H1-H2/pools), 04 (HUD/banner), 07 (Q8-1
  closable).
- Next: H3 re-measure after 02 changes it (`ab_retest -RequireQuiet` needs another quiet slot); per-category draw-call breakdown; asset gate
  on new commits; still no phone.
- M13 commit: `056a55dbd71c4be26f8d644af3f12973230e5518` [Test], 18:25:01. Verified with `git show --stat` (13 files incl. perf_frame_probe.gd, perf_bench.gd, budget_inventory.py), and `git branch -r --contains` shows origin/main. M12 commit: `5357ca3eee7627d31bdc9443766a8c2e3a4565ed` (17:35:04, verified the same way).
## M12 — pre-C11 prep and static re-check (2026-10-31 17:35 +09:00)
- Coordinator decision: **C11 = 18:00–18:30 KST** (other roles: no new Godot/editor/emulator starts). Correction received: the AU3
  import defect is fixed on origin/main. Verified: 43 `.wav` = 43 `.wav.import` (cc5dbb8, 05). AU3 marked RESOLVED, 07 Q8-2 updated.
- Static: `--range 37b9a93..origin/main` → all PASS. 19245a5 (03 title logo) puts menu residency at exactly 0.50 MiB = cap, and `group "ui"`
  keeps it resident in battle (+0.25 MiB) → A8 to 03. cc5dbb8: 43 SFX / 0.93 MiB.
- Prepared (unverified until the window's step 0): perf_bench `--only=setup` (BattleSim.new+setup time, objects created, pools); frame-probe
  `event_frames` (battle_start and wave_cleared frame times vs a 30-frame baseline); c11_window.ps1 rewritten to the coordinator's order:
  (0) parse check, (a) A/B, (b) STEPPING, (c) view/UI A/B HEAD, (c2) UI A/B before 04 1d1e4e3, (d) setup cost, (e) r01 banner frames,
  (f) equivalence if time; `-Deadline 18:30` → steps not started by then = NOT_RUN.
- Next step: at 18:00 `.\tools\perf\c11_window.ps1 -Start 18:00 -End 18:10 -EveryMin 1 -Deadline 18:30`.
- M12 commit: recorded later, only after `git show` verification.
## M11 — C11 attempt 17:00–17:25: NOT_RUN (2026-10-31 17:26 +09:00)
- `tools/perf/c11_window.ps1` (new): scheduled foreign-process checks; when a check finds 0 it runs the sequence (a) A/B `-RequireQuiet`,
  (b) STEPPING probe on a clean HEAD snapshot, (c) view and UI A/B, (d) targeting_equivalence, each run monitored once per second
  (CONTAMINATED label). Dry run verified the NOT_RUN path (exit 3).
- Real attempt: checks at 17:00/05/10/15/20/25 saw 8/10/8/2/11/6 foreign processes (07 qa07_head every time; 01/02/03/04/05 too). **Nothing
  measured, nothing touched.** The background launch at 16:50 did not survive in this tool host, so the runner ran in the foreground
  17:00–17:25.
- Proposed: an actively held 30-minute slot (e.g. 18:00–18:30), using `-EveryMin 1`. Written to the coordinator, 02 and 07.
- M10 commit: `1fd974b88ef87a300691ea053fa37c073192f18a` [Docs], 16:48:40 (`git show --stat` 6 files; `git branch -r --contains` →
  origin/main). The "16:50" in MEMORY_STATIC_ESTIMATES.md and M10 is approximate; the commit time is 16:48:40.
- Next steps (exact): when the coordinator writes "C11 HOLD <start>–<end>", run
  `.\tools\perf\c11_window.ps1 -Start <start> -End <start+5> -EveryMin 1`. Then record the results in BASELINE §7 and the requests, and
  release the window. Until then: Godot-free work only; run the asset gate on new 03/05 commits.
- M11 commit: `9a8bcde0038cb43f0754a868b360f85fb5602386` [Test], 17:26:19. Verified with `git show --stat` (7 files incl. tools/perf/c11_window.ps1 +122), and `git branch -r --contains 9a8bcde` shows origin/main. **Correction:** 9a8bcde itself contains a wrong, non-existent SHA (c99106a…) in this line. I wrote it before the commit existed: two tool calls were issued together, and the edit landed in the commit. Rule from now on: write a SHA only in a separate, later step, after `git show` has printed it.
## M10 — audio residency + pool estimate (16:50), C11 attempt pending at 17:00
- Static, no Godot. 05 f0646dd: gate PASS (38 SFX, PCM ≤ 0.83 MiB, music 0.56 MiB). All SFX are loaded at startup as QOA (≈ 0.2 MiB), music
  is loaded on play (≤ 2 during a crossfade), 18 players. **Defect: 9 committed WAVs without `.import`, so 3 cues would be silent in exports**
  (AU3 to 05, Q8-2 to 07, FYI to 02). Pool preallocation estimate ≈ 0.16–0.21 MiB per battle start (80 units, the coordinator's 72 + 8
  dying). docs/performance/MEMORY_STATIC_ESTIMATES.md.
- C11 plan (17:00–17:25, `-RequireQuiet` only, never touch other processes): every 5 min count foreign Godot/emulator processes; start
  only at 0. Order: (a) `ab_retest.ps1 -BaseRev d4d7c13 -FixRev HEAD -Files src/gameplay/battle_sim.gd -Pairs 3 -RequireQuiet`;
  (b) frame probe on a clean HEAD snapshot (STEPPING); (c) view/UI A/B on the snapshot; (d) targeting_equivalence on the snapshot. Any
  foreign process during a run → CONTENDED / INVALID. No quiet moment by 17:25 → record "not run" and propose the next window.
- M10 commit: recorded only after `git show` verification.
## M9 — gate re-judgement, UI hot-path review, 22d99ea review (2026-10-31 16:4x +09:00, no Godot used)
- (1) Re-ran the fixed gate (14f8edc) on every earlier judged commit (ccf3033, 2b350c4, 5930430, 686af29, 7705aec, 8c8635f, bfcce0e) and on
  the M3 retheme_compare baseline. **0 verdict changes**: all recorded runs used an absolute out dir; only the unrecorded 16:25 relative
  run was wrong. Table in RETHEME_BUDGET.md. WIP heads-up to 03 (A7): `ui_title` page puts menu residency exactly at the 0.5 MiB cap.
- (2) UI review (04, committed 6051b3c/0590e7a): no Tween or per-frame node creation. New H14 (cold Bold 24 glyphs at the D16 banner =
  likely hitch at the peak moment), H15/H18 (all HUD buttons redraw at 10 Hz even when unchanged), H16 (O(n²) ellipsis), H17, H18b.
  Request R7 sent to 04.
- (3) 02's WIP was committed meanwhile as **22d99ea (16:34)**, so I reviewed the commit with `git show` (read-only; nothing modified or
  stashed). H1/H2/H5/caps/pools/P2b changed as requested (not timed). New risks H19 (tie-group scan length under stacking) and H20 (bar
  buffers regrow per frame) noted in the 02 request. Line refs checked: 16/16 at HEAD 7461636.
- Pending for C11 (17:00–17:25 proposal, `-RequireQuiet` only): A/B 02 target search (base = linear blob d4d7c13 → HEAD, now incl.
  22d99ea); then, outside the A/B, frame probe on a clean HEAD snapshot (P8 STEPPING re-check + H1/H2/H15 draw-call/view/UI A/B) and
  `targeting_equivalence.gd` on the snapshot.
- M9 commit: `cb7385f43874d5f493968c697d15703f11818c1c` [Docs], 16:41:32. Verified with `git show --stat` (7 files), and `git branch -r --contains` shows origin/main. The "16:4x" labels in M9 mean 16:35–16:41 (commit time 16:41:32).
## M8 — 03 art 0.9.0 gate, P8 wait, C11 proposal (2026-10-31 16:30 +09:00)
- User decisions recorded: **Q3 working title "빵집 기사단: 곰팡이 디펜스" (16:19 KST)**, **Q2 monetization on hold** (no ad/billing SDK).
- (1) 7705aec (03, pixels only) → asset gate PASS vs 37b9a93 and vs 2b350c4. Page count 10→10, GPU 9.25 MiB unchanged, PNG −459 B.
  Recorded in RETHEME_BUDGET.md; 03 informed (A6). No cap exceeded, so no request to 03/02.
  **Gate bug found and fixed:** a relative `--out` made residency read 0 MiB, which would silently PASS. Now the out dir is absolute and a
  failed or empty residency is exit 2. Self-test 13/13 PASS (2 new regression cases).
- (2) 02 has NOT committed the battle_sim/battle/battle_view/core WIP yet (git log aac831c..HEAD -- src/gameplay src/core: none; git status: still
  modified). P8 re-check is waiting. No Godot was run in M8.
- (3) C11: 0/10 quiet samples 16:27:56–16:29:30 (2–7 foreign Godot processes). Proposed 17:00–17:25 KST to the coordinator/02/07, using
  `-RequireQuiet`. Observation: another role ran 08's `targeting_equivalence.gd` at ~16:28 (probably 02 on P2b).
- Next steps (exact): (1) When 02 commits the WIP: `git archive` snapshot of that commit + `.godot` cache copy, run perf_frame_probe once
  (secondary monitor, CONTENDED label) and require STEPPING. (2) When C11 is granted: the M3 A/B command (`-RequireQuiet`), then the H1/H2
  frame baselines on a HEAD snapshot. (3) Run the asset gate on every new 03/05 asset commit.
- M8 commit: `14f8edcb377c04f22ee835e3dc1b63ec680c7d27` [Test], 16:30:47. Verified with `git show --stat` (9 files incl. tools/perf/asset_budget_check.py and test_asset_budget_check.py), and `git branch -r --contains` shows origin/main.
## M7 — "sim did not step" diagnosed (2026-10-31 16:18 +09:00)
- User decision received: **Q2 monetization = hold** ("수익모델은 보류", 16:09 KST). Ads and billing stay disabled; there is no
  monetization UI. Effect on 08: no ad/billing SDK in APK/memory budgets; nothing to measure there.
- Coordinator review: 2620274/19665cb accepted. Asked to find out whether the stall is a probe defect or a game defect.
- Done: `perf_frame_probe.gd` now writes `sim_trace` (steps per frame from sim.t, paused/ended/tree-paused/no-advance frame counts,
  transitions with time, pause signal emitters with call stacks, final state, verdict STEPPING/NOT_STEPPING).
- One windowed run on a **clean git-archive snapshot of HEAD b9b0297** (same arguments as the 16:10 run) → **STEPPING**: 946 steps in
  16 s, 0 paused/ended frames, 0 pause signals, combat reached (22 texts, 11 fx), 36/36 held. Contended (3 foreign Godot processes at
  start, 7 during); functional only.
- Conclusion: the stall is not a probe defect and not in committed HEAD. It appears only on the shared working tree with uncommitted WIP
  (02 battle_sim/battle/battle_view/core; also 04 ui and 05 audio bridge files modified). Sent to 02 (P8, repro command + acceptance)
  and 07 (Q8-1, new file 08-performance-to-07-qa.md).
- Also corrected: my earlier "16:1x / 16:4x / 17:0x" labels were estimates. They are replaced by the real commit times (15:54, 16:04,
  16:10/16:12) in all 08 files.
- Next steps (exact): (1) When 02 commits the WIP: snapshot that commit and re-run the probe; require verdict STEPPING. (2) In C11: the M3
  A/B command, then the H1/H2 frame baselines from a HEAD snapshot. (3) Run the asset gate on every 03/05 asset commit.
- M7 commit: `aac831cf9c99a65e3873bdfe47259d30d0378538` [Test], 16:19:52. Verified with `git show --stat` (11 files incl. tests/performance/perf_frame_probe.gd +71 and the new requests file to 07), and `git branch -r --contains` shows origin/main.
## M6 — 08 stress-refill bug fixed (2026-10-31 16:12 +09:00)
- Coordinator review: 7e166dc/ab00170 accepted. **New rule: verify every commit right after publishing with `git show --stat <sha>`
  and `git branch -r --contains <sha>` before writing its SHA anywhere** (9d989ed had recorded a non-existent SHA).
- Fix: `tests/performance/perf_frame_probe.gd _stress()` refills enemies from `Content.round_enemy_roster(round_def)` (bosses
  excluded; fallbacks: ai pool, then all non-boss enemies), up to 4 per frame. New `stress_reach` output records the max living per
  side, frames at cap and the roster source.
- Check (exactly one Godot run, windowed on \\.\DISPLAY2, r06, 4+12 s, exit 0): **ally 36/36, enemy 36/36 in 721/721 frames**
  (both at cap from t=4.0 s). CONTENDED (4 foreign Godot processes at start, 9 during) and run on the shared working tree with 02's
  uncommitted battle_sim/battle changes. **Functional check only, no performance judgement.**
- New open item: the sim did not step in that run (battle-loop p50 0.013 ms; fx, projectiles and texts 0), so the armies never met.
  Cause unknown (not investigated further, to keep to one Godot run). Next stress run: use a `git archive` HEAD snapshot and log
  sim.t/paused/ended.
- Next steps (exact): (1) Add sim-state logging (t, paused, ended, steps per frame) to the frame probe and verify it in the next allowed
  Godot run. (2) In C11: the M3 A/B command, then the frame probe stress run from a HEAD snapshot for the H1/H2 baselines. (3) Run the
  asset gate on every 03/05 asset commit.
- M6 commit: `2620274e575eab77fe1889af9098a1eda6e824e3` [Fix]. Verified with `git show --stat` (5 files: handoff, status, BASELINE_DESKTOP, CODE_REVIEW_HOTPATH, perf_frame_probe.gd), and `git branch -r --contains` shows origin/main. Helper printed `PUSHED 2620274... origin/main` (7b812a2..2620274).
## M5 — static hot-path code review (2026-10-31 16:04 +09:00, no Godot used)
- Coordinator review: 9cbae83/3d07db5 accepted. C11 is still closed (01/02/03/04/05/07 working), so this milestone is Godot-free only.
- Done: `docs/performance/CODE_REVIEW_HOTPATH.md`. Committed HEAD 0590e7a was exported with `git show`. The doc covers per-frame
  allocations, caps vs D7 vs pools, and full scans, ranked H1–H13 with line numbers and a measurement method each. **24/24 cited line
  numbers were checked programmatically** against the committed files. Request P7 sent to 02 (top items: H1 per-sprite Dictionary
  allocation via Atlas.anim_frame ≈ 200 per frame at caps; H2 batch breaks from hp bars, draw_set_transform and hex Color parsing; H3
  per-unit def lookups; H4 `_cue` allocating before coalescing; caps single source of truth; lazy pools). 01 got an FYI: D7 30/40 is not
  what runs (effective 36/36/64/48/24).
- Root cause of the stress-scene unit drop (~40 units), found by reading the code: D18 set `enemy_ai.pool=[]`, and
  `perf_frame_probe.gd _stress()` refills enemies only from that pool. **Not fixed yet** (the fix needs a Godot check run; do it before the
  C11 window: refill from `Content.round_enemy_roster(sim.round_def)`).
- Asset gate re-run: `asset_budget_check.py --range 37b9a93..HEAD` → PASS (no new asset commits), exit 0.
- Next steps (exact): (1) Fix the `_stress()` enemy refill in tests/performance/perf_frame_probe.gd and parse-check it when Godot use is
  allowed. (2) In C11: the M3 A/B command, then `run_perf.ps1 -Frame` for H1/H2 baselines (draw calls, view A/B). (3) Re-run the asset
  gate on every 03/05 asset commit. (4) Re-measure each P7 item after 02 commits it (A/B `-RequireQuiet` / frame probe).
- M5 commit: `7e166dcaf1dac5fe9b8f80d8185d4a80dc2b3ae4` [Docs] (5 files: CODE_REVIEW_HOTPATH, RETHEME_BUDGET, requests to 01/02, status). Helper printed `PUSHED 7e166dc... origin/main` (528d065..7e166dc), and `git branch -r --contains 7e166dc` shows origin/main. The handoff M5 section went in with `9d989ed`. **Correction:** 9d989ed contained a wrong SHA (6e5e5d9, which does not exist), fixed by this commit.
## M4 — static per-commit asset budget gate (2026-10-31 15:54 +09:00)
- Coordinator review 16:0x: c58c59e/480f815 accepted. C11 quiet window is NOT open yet, because 02/03/04/05/07 are working; the coordinator
  will open it later. Until then, do Godot-free work only. This milestone used **no Godot**.
- Done (verified): `tools/perf/asset_budget_check.py`. It compares the base commit (37b9a93) with a commit / `--worktree` / `--range` /
  `--tree`, using git trees via `git archive`. It reports PNG size and GPU estimate from .import (lossless 4 B/px, VRAM 1 B/px, mipmaps +1/3),
  per-round residency, WAV decoded PCM, OGG duration and decoded size, and optional APK totals. **Exit 1 when a cap is exceeded**
  (`--report-only` = always 0). Self-test `tests/performance/test_asset_budget_check.py` uses synthetic over-cap trees under
  build/perf/asset_selftest and never touches assets/.
- Results: `--range 37b9a93..HEAD` → PASS for ccf3033 (05), **2b350c4 (03 theme A redraw: 0 page size changes, GPU identical 9.25 MiB,
  PNG −0.8 KiB)**, and 5930430; HEAD bfcce0e PASS; working-tree preview (05 WIP: 38 SFX, 0.83 MiB PCM) PASS. Recorded in RETHEME_BUDGET.md §5.
  03 notified (A5), 05 notified (AU2: music must stay streamed, 7.69 MiB if decoded).
- Validation: self-test 11/11 PASS (exit 0); gate HEAD exit 0; `--worktree` exit 0; `--range` exit 0; APK rows with the same file →
  "n/a, same APK file: not evidence".
- Still open: C11 quiet A/B re-measure (waiting on the coordinator); fresh before/after APK (04 R6); frame cost of the new art (needs C11 /
  Godot); 02 P2b; 04 R5; stress unit-drop; device data.
- Next steps (exact): (1) Whenever 03/05 commit assets: `python tools/perf/asset_budget_check.py --range 37b9a93..HEAD` and add a row to
  RETHEME_BUDGET §5. On FAIL, notify the owner with the report's file line. (2) When 04 posts APKs:
  `--apk-before <a> --apk-after <b>`. (3) When C11 is granted: the command in the M3 section below.
- M4 commit: `9cbae838bb8486f5e7df239cd84fc0ee4d58b3f0` [Test] (7 owned files). Helper printed `PUSHED 9cbae83... origin/main` (bfcce0e..9cbae83), and `git branch -r --contains` shows origin/main.
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
- Commit: `c58c59e26498a326bcfa0b212ebe2898a3554e13` [Test] (13 owned files). Helper printed `PUSHED c58c59e... origin/main`, and `git branch -r --contains` shows origin/main.
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
