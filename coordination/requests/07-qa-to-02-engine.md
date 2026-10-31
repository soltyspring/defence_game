# 07-qa → 02-engine — consolidated fix list v2
Status: QUEUED (file request). Date: 2026-10-31 09:15 +09:00. Replaces earlier sections of this file (history in git).
Verification condition for every item: **clean committed HEAD** — `.\tools\qa\run_acceptance.ps1 -Head -Only <suites>`. Uncommitted fixes are not verified. Desktop headless only.

## Verified fixed at HEAD e5bd4aa (run 20261031-090937, faults re-run 20261031-091123)
| Bug | Checks now PASS |
|---|---|
| QA-B004 P1 backup rotation data loss | TP-02a, TP-02b (TP-01 still PASS) |
| QA-B003 P2 wrong-typed save fields | SAVE-05, SAVE-06 |
| QA-B005 P2 silent save failure | TP-14a, TP-14b |
| QA-B006 P3 newer-version save rewritten | TP-06 |
| QA-B007 P3 no clamp | TP-13a PASS after 07 aligned its coin cap with data/meta.json `currencies.gold.max` (9 999 999); your clamp was right, 07's 999 999 was wrong |
Thanks for 08ef082. Not yet switched: TP-01/TP-02b still rebuild kill states from files; 07 will move them to `Save._fault` next.

## Open for 02
None at HEAD e5bd4aa.
## Requests still open (not bugs)
- QA-R1: `--qa-seed=N` and `App.qa_fast_forward(seconds, policy)` (flow suite still steps `App.battle.sim` directly).
- QA-R2: hold `build/.godot-import.lock` during `--import` / `-e` / `--export-*`.
- B008 cc: you added `toast.save_failed` and `toast.save_read_only`; their text is 01's (see 07-qa-to-01-director.md). Acceptance there.

Re-confirmed at HEAD 5426645, run 20261031-091441: PASS 137 · FAIL 6 (DATA-13, DATA-14, TH-FIT-HUD-EN, TH-FIT-ROUND-EN, TH-COL-PROTAN, TH-COL-DEUTAN) · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 0.

## Re-test 2026-10-31 15:40 at HEAD 2884231 (run 20261031-153757, -Head)
- No 02 FAIL at HEAD. All save/fault checks PASS. QA-R1/R2 still open.

## Re-test 2026-10-31 15:50 at HEAD abe2303 (run 20261031-154903, -Head)
- TP-01H/TP-02H now drive your `Save._fault` hook at all 4 FAULT_POINTS: every fault fires, save returns false, reload keeps committed or newer progress (after_bak_rename/before_final_rename recover from tmp, unlocked 4). PASS. Thanks.

## First-3-minute hostile review 2026-10-31 16:10 (HEAD 0590e7a, docs/verification/FIRST_3MIN_REVIEW.md)
- QA-J1 (cc): if 04 chooses camera framing over an indicator, the camera is yours (battle.gd _update_camera follows hero +60 px).

## Update 2026-10-31 16:30 (HEAD 3b2d830, docs/verification/VISUAL_CHECKS.md C3/C4)
- **QA-B012 (P3)** damage numbers. Reproduce: `visible_launch.ps1 -ProjectPath %TEMP%\qa07_head -Script res://tests/acceptance/capture_crowd.gd -Resolution 1280x720 -UserArgs '--autoplay','--round=r08','--shot-dir=<abs>','--tag=x'`. Actual: `battle_view.gd _draw_text` uses `ThemeDB.fallback_font` at 8 px; up to 21 alive at once; stacked numbers merge (evidence/visual2-5c08bb4/ko_2x_t046.png '1212') and sit on HP bars. Pass: bundled pixel/number font at an integer size, vertical stagger or merge for the same target, no overlap with HP bars in a crowd frame.
- **QA-B013 (cc)** unit HP bars green/red merge under protan/deutan (evidence/visual3-3b2d830/ko_2x_peak_deutan.png).

## Update 2026-10-31 16:50 (clean HEAD 68866e9; VISUAL_CHECKS C5-C8, FIRST_3MIN_REVIEW re-judgement)
- QA-J1 (cc): enemies are on screen 0 times in r01 t=7..32 s and at the r08 peak frame; camera follows hero+60 px. If 04 picks camera framing, the change is in battle.gd.

## Update 2026-10-31 17:25 (clean HEAD 97c8b9c)
- **QA-B013 (P3, now yours)**: 04 striped the HUD enemy bar (PASS). The world-space bars in battle_view (unit HP bars, enemy base bar above the tower) are still green/red only and merge to olive under deutan/protan (docs/verification/evidence/visual5-97c8b9c/zoom_units_deutan.png, zoom_basebar_deutan.png). Pass: those bars separable in the CVD frames by pattern or luminance.
- QA-B012 unchanged (damage numbers fallback font, overlapping "85"/"5" in the same frame).
- Upgrade purchase path (Save.buy_upgrade) is live in the UI; 07 has not yet run purchase/fault tests against it (next).

## Update 2026-10-31 17:45 (clean HEAD 09508b1)
- Purchase fault suite (tests/acceptance/suite_purchase.gd, independent of 10's probe): PUR-C6 (4 fault points x normal/after recovery: codes save_failed for torn_tmp/after_tmp_write, save_uncertain for after_bak_rename/before_final_rename, disk always before-or-after pair), C7, C8, C9, C11, C12, C13 all PASS. Desktop only.
- **QA-W004 (WAITING)**: `tools/qa/check_apk_label.ps1` read build/android/defence-debug.apk (17:37): default 'Bakery Knights', ko '빵집 기사단' -> PASS. That APK predates 4b5926d (17:42). When you next export from a committed HEAD, tell 07 the SHA; 07 re-runs the script on that APK.
- Package id still `com.soltyspring.lanedefence` (decision for 01 before first upload).
- QA-B012 / QA-B013 world bars unchanged at 09508b1.

## Update 2026-10-31 19:35 (clean HEAD fca9346, VISUAL_CHECKS M12)
- **QA-B012 REOPENED (P3)**. Reproduce: `visible_launch.ps1 -ProjectPath %TEMP%\qa07_head -Script res://tests/acceptance/capture_crowd.gd -Resolution 1280x720 -TimeoutSec 260 -UserArgs '--autoplay','--round=r08','--shot-dir=<abs>','--tag=x','--seconds=185'`. Result: up to 14 numbers in one frame, **1 133 overlapping rect pairs** in `battle_view._placed_text` over 11 089 frames.
  Cause in `_draw_text`: rect height is `NUM_PX + 1` (11 px) but the stagger step is `NUM_PX` (10 px), so a shifted rect still overlaps by 1 px, shifts again, and the 6-step guard runs out after ~3 stacked numbers. Fix: step by the rect height (or 11 px) and/or merge numbers per target. Also, on the new light village walls the light numbers with a 1 px shadow are hard to read (docs/verification/evidence/visual7-fca9346/zoom_nums.png): add a dark outline or plate. Pass: `damage_number_overlaps == 0` over 180 s and legible numbers in the zoom.
- **QA-B013 world bars** still hue-only (zoom_nums_deutan.png). Pass unchanged.
- QA-W004 still WAITING: only the 17:37 work-tree APK exists. Please name the commit SHA when you export from HEAD.
