# 09-research-product handoff
Updated: 2026-10-31 (resumed after the 09:18–09:19 user checkpoint; window reopened once mid-resume)
Session ID: sess_6ce8ebb1-4e45-454d-a561-e0bad09a8be5 · claude-opus-5.5 / trust-all
Status: MILESTONE DONE — waiting for 01/02/04/07 replies
Read on resume: this handoff, coordinator-to-09-research-product.md (incl. 09:03 USER DECISION Q1 = theme A; the QUOTA CHECKPOINT/HISTORICAL notes are past records, not a stop), replies 01-director-to-09 (D16), 04-client-to-09, 08-performance-to-09.

## Checkpoint comparison (no work lost)
- At 09:19:04 the last 09 commit was 2572352 (checkpoint handoff). The quota guard branch checkpoint/quota-20261031-092323/09-research-product = 3550a81 (09:24:05) has an EMPTY diff against its parent, and an empty diff against HEAD on all 09 paths.
- The 09 working tree was clean on resume (git status on docs/research/product, own handoff/status/requests = 0 entries). Nothing to recover.

## Commits this resume (helper output, PUSHED origin/main)
- 71993fcfee80f5caaf962863285d05a1af8307fe: SUCCESS_ANALYSIS §24 (reply reconciliation), E1_PILOT_SHEET.md, requests R09-01-7, R09-02-5, R09-04-7, 07 pilot-sheet note.
Earlier: a2b62c9, cdaea7f, b1ceee4, 0b8bef2, 424ca47, 82a3ed2, a4250bb, 9ca4a43, 5185e34, 2572352 (+ handoff/status commits).

## Findings this resume
- 01 adopted G1 as D16 ("first wave broken" banner 25–45 s, pass = ≥3/5 within 60 s). The banner CANNOT fire yet: the engine emits only wave start (battle_sim.gd:417), with no wave-cleared event. The definition of "broken" is ambiguous because the wave overlaps trickle grunts.
- D18 changed r01 to 6 waves (25/55/90/160/210/260 s). The 160 s pressure wave arrives right after the 150 s 3-star time. Intent was asked of 01.
- DECISIONS.md still shows Q1 PENDING (asked of 01 twice).
- 08 has peak-frame counters (r06: popups 16/24, FX 8/48), but this is not an r08 peak, so E2/E5 remain unjudged.

## Validation
battle_sim.gd:417 re-read; git diff --check clean; working tree clean after commit; only 09 paths changed. No pilot was run. No 10 or other owner's file was touched.

## Next steps
1. When 02 adds wave_cleared and 04 adds the banner: verify in a visible r01 capture and in the event log, then close P1 in E1_PILOT_SHEET.
2. When 01 defines "broken" (R09-01-7): close P2. 07 then schedules E1.
3. Still open: 04 1x top-bar capture (R09-04-5), 07 r08 real-HUD frame (E2), 03 icon test (R09-03-4), 06 KIPRIS (R09-06-3).
4. Stop and checkpoint at ≥97% of a new quota trigger.
09 runs no Godot or emulator processes.

## v8 (2026-10-31 ~15:55 KST): WORLD.md identity check
Commit 747e0e22d000f18c2010e9e98e5e10c825a9e8ee PUSHED (helper output). Files: SUCCESS_ANALYSIS.md, reviews evidence JSON, and the requests to 01/02/03/04/06.
- Q1 confirmed DECIDED in DECISIONS.md (14b01e2). The Q1 items in R09-01-6/7 are closed.
- §25: 16 KR/US Play name searches found no title containing our names. Low-overlap indies exist (itch.io Food Knight, Steam Toast & Toaster). Risks are first-impression ones: chef-hat hero looks like a tycoon game, card short names 통식빵/프레첼 lose their role, title is still provisional. Child aversion has no direct evidence; comparable mold/food games are rated 전체이용가 on Play KR, PvZ 7+.
- Correction: my earlier "no 오븐 in unit names" rule was too broad (fixed in the 01/06 requests).
- Correction: the "~10:xx KST" times in §22/§23 and in the requests were wrong estimates. Actual times are before 09:06/09:18 (commit times). Fixed in place.
- Requests: R09-01-8, R09-03-5, R09-06-4.

## v9 (2026-10-31 ~16:15 KST): Q2 decision material
Commit 8ad912fc0e2df56f4fbf50a846299900e873325d PUSHED (helper output): SUCCESS_ANALYSIS §26, E1_PILOT_SHEET (P2 met, pressure-wave row), R09-01-9.
- R09-01-7 CLOSED (D21; pressure tags verified in the committed r01).
- §26: monetization facts for 6 comparison games plus Kingdom Rush (paid example), from Play KR and App Store KR pages on 2026-10-31. No chapter-purchase example found. No public rewarded-ad placement or frequency data. No revenue or conversion estimate. Risks per option use only the complaint types from §22, the Play Families policy text, and 06's existing test plan.
- Neutral by design: the material does not recommend A/B/C; it notes that USER_QUESTION marks A as 01's recommendation.
- Validation: 6 cited App Store/Google pages returned 200; diff --check clean. App Store ratings in the table use page values, not iTunes API values (the two differ; noted).
- Next: as before (01/02/03/04/06/07 replies).

## v10 (2026-10-31 ~16:35 KST): QA-J1..J3 competitor basis
Commit 44be5c8fb3095d8c0498001b9b2c43601f5e6e08 PUSHED (helper output): SUCCESS_ANALYSIS §27, R09-01-10, R09-03-6, R09-04-8. (An earlier draft of this line had a wrong placeholder SHA, corrected here.)
- (a) Battle-band share (eyeballed, ±5 pp, Play KR store shots): Archer Forest ~37%, Random Dice ~65%, 궁수키우기 RPG ~68%, PvZ ~whole game view, CatWar2 ~45%; ours ~8% band (07: ~75% sky). Every compared shot shows enemies already on screen.
- (b) Risk is shown as objects or numbers (PvZ mowers, RD hearts, wall HP, LD counter). Whether competitors' first levels can be lost is UNOBSERVED, so there is no basis for "make r01 hard".
- (c) Production controls are separated by shape or position (anvil, round summon button, CatWar2 leftmost MAX slot). PvZ's seed bar is not visible in its store shots.
- Experiments X7–X11 with owners and pre-fixed rules. No causal claim.
- Validation: 07 figures re-read from FIRST_3MIN_REVIEW.md; diff --check clean; 09 paths only.

## v11 (search 2026-10-31 16:16 KST): Q3 title material
Commit fd49cf23950a2b3c0e59aa9da985ea1429623510 PUSHED (helper output, SHA copied after publish): SUCCESS_ANALYSIS §28, evidence/title_search_2026-10-31.json, R09-01-11.
- User decision recorded: Q2 = 보류 ("수익모델은 보류", 16:09). Ads/IAP stay disabled, no monetization UI. §26 is reference only.
- Q3: lengths ko 6/15/15, en 14/28/29 (all ≤30, the Play/App Store limit; home label can be shorter and set separately). No same-titled app in Play/App Store KR/US top 5. Only B has a genre word.
- NEW: "Bread Defense / 빵어전" (ETERNAXCODE, iOS KR 2026-09-02, Play com.eternaxcode.bbangeojeon 10+) overlaps the concept (bread cards, "Dough", damp "Moisties", spores, pixel, hearth duels). Sent to 01; the decision on telling the user is 01's.
- Neutral: no recommendation. KIPRIS still required by a person.
- Validation: 6 cited URLs returned 200; JSON parses; diff --check clean; 09 paths only.

## v12 (2026-10-31 ~16:40 KST): 빵어전 comparison + QA-J1/J2 metrics
Commit 6e7758344883b7cbff812d4a5d5deba47f4f6038 PUSHED (helper output; SHA copied after publish): SUCCESS_ANALYSIS §28.6, §29, §30; R09-01-12, R09-03-7, R09-04-9.
- Q3 DECIDED recorded: B "빵집 기사단: 곰팡이 디펜스" (user, 16:19) is the working title; the final store name comes after KIPRIS 9/41. Counter-note recorded: a top-5 search is not trademark evidence. The title task is closed.
- 빵어전 (store page and 4 screenshots only, no internal or performance claims): genre differs (portrait path TD vs our landscape lane + hero). The main overlap is the Korean words 반죽/제빵사/화덕 (they released 2026-09-02). Their damp/spore enemies and pixel bakers also overlap. Sent to 01 (word decision) and 03 (keep mold visually distinct).
- Chosen experiments: X9 (J1: enemy, nest or indicator visible at t=10/30/60 s, 4/4 runs) and X11 (J2: base HP drops before 90 s in ≥3/4, still 4/4 wins, ≥50% HP, ≤150 s in ≥3/4). Measurable with 07's capture bot, no people needed. X10 was dropped as the less discriminating test (n=5, needs new art). Enlarging the 8% band needs 02 camera/scale, which is noted.
- Validation: diff --check clean; 09 paths only.
