# 12-text-review handoff
Updated: 2026-11-01 09:32 KST — USER STOP (user 09:17 KST: "이제 그만만들고 멈춰", "푸시하고 끝내"). Stopped at a safe boundary; no new work after this.
Session: sess_6eca99a3-2f07-454b-8a7c-c62e723b7bb2 (Kiro CLI, claude-opus-5.5, trust-all)
Owner paths: docs/review/text/**, coordination/status|handoffs/12-text-review.md, coordination/requests/12-text-review-to-*.
Never ran Godot, editor, import, export, emulator, adb, Gradle or heavy_run. No heavy_run job queued or running from 12.

## Current task
TEXT_REVIEW_02 (coordinator dispatch after 3f70e92/3e9ba2e): re-measure 01's 140daeb text; static timing of the new r01 tutorial order. Written and verified; published in the commit recorded below.

## Done
- TEXT_REVIEW_01 (earlier): 3f70e92eeab7916a6fe5fe3e2a47d60032a10331, handoff 3e9ba2e9ce2e022210c5f2d09d0b57456bf49507 (both checked with git ls-remote at the time).
- TEXT_REVIEW_02: docs/review/text/TEXT_REVIEW_02.md; measure_text.py (+ `--out`, `--before <rev>` per-key before/after, tightest-row print); new tutorial_timing.py (pure-Python model of tutorial_director.gd + battle.gd frame order); evidence text_width_report_02.json, measure_text_stdout_02.txt, tutorial_timing_02.json, tutorial_timing_02_stdout.txt; requests appended: to-01 R2, to-02 R3, to-04 R2.
- evidence/text_width_report.json restored to its committed TEXT_REVIEW_01 version (01 had regenerated it in the working tree; content was identical to my 140daeb run, which is kept as text_width_report_02.json).

## Actual validation
- `python docs/review/text/measure_text.py --out text_width_report_02.json --before 3f70e92`: exit 0; calibration still 106/106 vs Godot-measured widths; data/text and r01.json equal to HEAD (`git diff --quiet` 0).
- Result vs 01's report: screens 990 rows, 0 not ok = same. Different: HUD wave line still truncated in 6 layouts (en r06 286 > 283.4 px, 640×360/400/480 + notch 34/34, min target 48; HEAD layout and 04 WIP alike); tightest single-line slot is HUD ko card names 1 px, not the en defeat hint 2 px. All 23 changed key/locale rows fit.
- `python docs/review/text/tutorial_timing.py`: exit 0. Confirmed from tutorial_director.gd:67 (`moved or sim.t >= 4.0`): with the new order the deploy hint shows at sim 4.0 s (4.017 s) for a player who does not move the hero, not at 0 s as 01 R15 said. Non-movers get the worker hint after the 20 s move step (24.1–26.1 s, 4 s later than the old order). Deploying before 4 s makes the deploy hint flash for one frame (same cause as 11 CR-007).
- Limits: model calculation, not a Godot run; 2 s reaction time is an assumption; tut_destroy_base depends on combat (not modelled). 04 hud_layout.gd WIP (blob 41b02f1) is still uncommitted.

## Not done
- No re-check of 04's integration test by running it (prediction only: test_ui_integration.gd:237–240 likely fails because it waits ~3.4 s and the first hint now comes at 4.0 s).
- Pending items waiting on others: 01 #10 ui.menu (04 answer), #16 ui.upgrade_error (04 removes `% code` first); 04 A1–A9; 02 CR-007 / deploy trigger choice.

## Next steps (exact)
1. Read replies under coordination/requests/12-text-review-to-{01-director,02-engine,04-client}.md and 01-director-to-12-text-review.md.
2. When 04 commits hud_layout.gd/hud_top.gd or 01 changes data/text or r01 tutorial order: `python docs/review/text/measure_text.py --out text_width_report_03.json --before 140daeb` and `python docs/review/text/tutorial_timing.py`, then write TEXT_REVIEW_03.md (before/after per key, HUD wave line A1, tutorial table) and publish with Publish-Task.ps1 -Role 12-text-review.

## Commit / push state
See coordination/status/12-text-review.md for the SHA of this stop commit (filled in after git ls-remote). Unverified files kept out of main: none.

## Errors
None.
