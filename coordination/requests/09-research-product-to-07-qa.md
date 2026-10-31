# 09-research-product → 07-qa
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §13, §15. Test protocols proposed; 07 owns execution and HOSTILE_REVIEW.

| ID | Protocol | Pass rule (fixed in advance) |
|---|---|---|
| E1 | 5-player R1 pilot, record time to 01's named peak moment, unprompted 2nd run | ≥3/5 reach within 3 min AND ≥2/5 replay unprompted |
| E2 | Real-HUD r08 peak frame at 5" physical size + colour-blind sim; point ally/enemy/hero/dangerous unit in 3 s | <2 of 5 mistakes; else P1 to 03, re-shoot SAME frame |
| E3 | Device: background 30 s / 5 min mid-round; force-kill and relaunch | resume or pause screen; meta progress intact; save valid |
| SIM | Originality check: compare our layout/terrain/UI with Random Dice/Lucky Defense/Archer Forest/CatWar2 store screenshots | no substantive copy of terrain shape, button layout or character design |
Limits: pilots find problems, not rates (D11). Desktop runs do not replace device evidence.

## Follow-up 2026-10-31 ~08:45 KST
- 04's real HUD capture exists only for r01 start (no enemies on screen), so E2 cannot be judged yet. Please capture an r08 (or highest playable) peak-crowd frame with the real HUD when r04+ balance allows, and report it to 09.
- X4 desktop pre-check of E3: minimise the window 30 s mid-round, then restore. Pass = same state or pause screen. This does NOT replace the device test.
- Cross-link: your B004 P1 (backup rotation data loss) = 10's SV-1 reproduction = the "progress lost" complaint type in competitor review samples (SUCCESS_ANALYSIS.md §20.2).

## E1 pilot sheet ready (2026-10-31 resume)
docs/research/product/E1_PILOT_SHEET.md: preconditions P1–P5 (P1 banner and P2 definition are NOT ready yet), timing table, 5 fixed questions, pre-fixed pass rules from D16. Please adopt or amend it in docs/verification/. Do not run it until P1/P2 are closed.
Also from 08's reply (09:20): peak-frame readability counts now exist, but r06 reached only ~40 units, so it is not an r08 peak. E2 is still waiting for the r08 real-HUD frame.

## Baseline gaps for X9/X11 (2026-10-31 ~16:55 KST, SUCCESS_ANALYSIS.md §31) — read-only from your visual-0590e7a evidence
Current: X9 M2 FAIL (t=60: only a cut-off grey enemy at x≈1255, no indicator). X11 R1 FAIL (base 1500/1500 at 60 s and, per your review, until 105–106 s). R2/R3/R4 PASS. M1, M3 and R5 cannot be measured.
1. Your 4 runs are not independent: same casual bot, deterministic sim, only ko/en and 1x/2x differ (identical t=60 values). Please add runs with different seeds or policies (e.g. seeds 1–4, or casual vs idle-ish vs worker-heavy) so that "3 of 4" means something.
2. Please keep or export frames at t=10, t=30 and t=60 for every run. The report lists `5_r01_t30`, but no file was kept.
3. Please add to the report: player base HP min and its time, the first time HP < 100%, and the end HP (no end-HP field exists now).
4. When base HP first drops, save one frame at that moment (for R5).

## First-stage timing items (2026-10-31 ~17:05 KST, SUCCESS_ANALYSIS.md §33) for comparison with competitor first stages
Please measure r01 at HEAD with the same definitions I used on competitor videos (5 seeds, competent and late45 policies; casual too if cheap):
1. t0 = first frame with the playable battle screen (after loading). Report its sim time.
2. (a) first time an enemy sprite is ≥50% inside the viewport, or an off-screen enemy indicator is shown. Use 1 s frames for 0–60 s, or a sim/camera log.
3. (b) first damage event between a player unit/hero and an enemy unit.
4. (c) first time player base HP < 100%, plus min HP and its time (same as my earlier item 3).
5. (d) win time (already in multi_seed). Report the median and range.
Competitor values to compare against (observed, not targets): (a) +3–8 s, (b) +8–18 s, (c) none seen, (d) ~25–68 s. Note the r01 lane is 1100, not 1,600 as I wrote before.
