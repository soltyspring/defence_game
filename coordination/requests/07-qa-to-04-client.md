# 07-qa → 04-client — consolidated fix list v2
Status: QUEUED (file request). Date: 2026-10-31 09:15 +09:00. Replaces earlier sections (history in git).
Verification condition: clean committed HEAD, `.\tools\qa\run_acceptance.ps1 -Head -Only <suites>`. Desktop headless only.

## Verified fixed at HEAD e5bd4aa (run 20261031-090937)
- QA-B001 Android back handled twice → FLOW-23, FLOW-23B PASS.
- QA-B002 pause overlay under result → FLOW-13B PASS.
- QA-W003 `ui.star_*` text → DATA-13/14 no longer list them.

## Open for 04 (with 01 for text)
### QA-B009 (P2) English card labels ellipsised at the narrowest HUD — TH-FIT-HUD-EN
- Reproduce: `.\tools\qa\run_acceptance.ps1 -Head -Only theme`
- Configuration: view 640×360, safe area x 34..606 (34 px notches both sides), round's own card/skill count, 40 px min target. r08–r10 (5 cards) give a 36.7 px label slot.
- Actual: "Troop" 37 px, "Archer" 42, "Shield" 39, "Raider" 41 → ellipsis.
- Expected / pass criterion: TH-FIT-HUD-EN and TH-FIT-HUD-KO PASS: every drawn card/skill label fits `width − 6` at 12 px with no ellipsis. Either layout (wider cards, icon-only cards like the skills, or a second line) or shorter text (01). The theme rename will change these names, so a layout fix is more durable.
### QA-B010 (P2) English round names ellipsised in round select — TH-FIT-ROUND-EN
- Reproduce: same command. Tile label width 83 px at the same safe area.
- Actual: 7 of 10 (e.g. "Heavy Footsteps" → "Heavy Foo…").
- Pass criterion: TH-FIT-ROUND-EN and -KO PASS (wrap to 2 lines or shorter names).
### R5 visible launcher `-ProjectPath`
Needed so 07 can capture the clean HEAD snapshot (`%TEMP%\qa07_head`) on the secondary monitor for theme screenshots. Pass criterion: `visible_launch.ps1 -ProjectPath <dir> -ListOnly` documented and a capture placed on the non-primary monitor.

## Theme switch notes (Q1 = A)
New names must keep QA-B009/B010 checks PASS; 07 re-runs `-Head -Only theme,data,flow` after each text/layout commit. 40 of 69 committed docs images predate the newest art/text commit d6cf7df (runner `stale_baselines.txt`); do not use them as baselines for theme verdicts.

Re-confirmed at HEAD 5426645, run 20261031-091441: PASS 137 · FAIL 6 (DATA-13, DATA-14, TH-FIT-HUD-EN, TH-FIT-ROUND-EN, TH-COL-PROTAN, TH-COL-DEUTAN) · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 0.

## Re-test 2026-10-31 15:40 at HEAD 2884231 (run 20261031-153757, -Head)
- QA-B009 (TH-FIT-HUD-EN) and QA-B010 (TH-FIT-ROUND-EN) unchanged, still FAIL. Same pass criteria. R5 (-ProjectPath) still open.

## Re-test 2026-10-31 15:50 at HEAD abe2303 (run 20261031-154903, -Head)
- QA-B009 VERIFIED (TH-FIT-HUD-EN PASS). QA-B010 VERIFIED by layout logic: TH-FIT-ROUND-* now mirror `wrap_lines=2` via `UiStyle.fit_lines`; 3 KO and 7 EN names wrap. Not verified: that 2 lines fit vertically in the tile on screen (needs R5 capture). R5 (-ProjectPath) still open.
