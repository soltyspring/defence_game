# 09-research-product handoff
Updated: 2026-11-01 ~00:25 KST
Session ID: sess_6ce8ebb1-4e45-454d-a561-e0bad09a8be5 · claude-opus-5.5 / trust-all
Status: MILESTONE DONE (v19 resume check): waiting for 01 (R09-01-16, R09-01-17), 07 (R09-07-2, R09-07-3), 04 (D31 rendering)

## v19 (2026-10-31 22:59 – 2026-11-01 00:25 KST): resume after the quota stop (20:27) and the blue screen (23:08)
Commit d7926633e68cece72f9989eae0de1238eb96cf91 PUSHED (helper output; verified with git show --stat and git branch -r --contains = origin/main). It contains SUCCESS_ANALYSIS §38, the E1_PILOT_SHEET P1/P3 rows and a closing note to 04.
- Loss check: 20 tracked 09 files, 0 empty or NUL-filled; the 09 work tree was clean. checkpoint/quota-20261031-202729/09-research-product (3291e59) is an empty commit with no diff on 09 paths against HEAD. Nothing lost. The temp notes %TEMP%\r09\fs\obs.md are intact (no NUL).
- Heavy runs (coordination/heavy_run.ps1, one at a time, waits are normal): (1) '09-import-head07b90c5', waited 689 s: import of a clean git-archive snapshot of HEAD 07b90c5 (%TEMP%\r09\head_07b90c5) through 10's isolated_godot.ps1; exit 0, isolated, real save unchanged, 64 imports, 0 missing. The 5 "Unexpected NUL character" lines at the end of the log also appear in pre-crash imports (09:02, 17:35, 04 gate 23:02), and no text file in the snapshot has NUL, so this is not crash damage. (2) '09-p1-r01-banner-1x', waited 1041 s: 04's visible_launch.ps1 on \\.\DISPLAY2 (placement verified), 640×360, APPDATA isolated, `--round=r01 --autoplay --shots=25..58 --quit-after=60`, EXIT_0. No other Godot run by 09.
- P1 CLOSED: "첫 웨이브 격파!" is in the 38 s and 39 s frames (HUD wave 1/3, next in 3 s → sim ≈37–38 s, inside D16 25–45 s) and gone at 40 s. At 41 s the same label shows "웨이브 2/3" with no stacking. One seed, competent bot, desktop. The game log has no wave_cleared line; the banner text is only set by hud._on_wave_cleared(1). The banner path files are unchanged up to 4882771.
- R09-04-5 1×: PASS at 07b90c5 (old Galmuri9 10 digits: crisp, clear of VS and the bar end). 04's d724b9a (00:10) then enlarged the digits to Galmuri11 12; for that I only read 04's committed docs/qa/readable_numbers/ko_640_notch_r05_3_hud.png (clear of VS) and asked 04 for one 640×360 top-bar frame on their next visible run (low priority).
- Tracking (§38.3): R09-01-17 L1 and R09-01-16 K1 have no 01 reply; D31 rendering is not in src/tests (no `hint.loss` reference at 4882771). D34/D35 reflect R09-01-15 (B/A rejected, F0 kept as a hint candidate, 0.60–0.90 withdrawn). R09-07-2/3 are queued at 07 (not started). E2 r08 peak frame still has no enemy on screen (07 C8). R09-03-4: icon exists (b113085; chef hat + baguette + mold blob, no crown/shield), the 5-person test has not been run. R09-06-3 KIPRIS NOT_CHECKED (person only). The 01 "broken" definition is closed (D21), P2 = yes.
- Decisions unchanged: Q1 theme A, Q2 보류 (ads/IAP disabled), Q3 title, Q4 home label. Q5 unanswered; D28 is a default, not approval.
- Validation: table column counts (§38: 1 table, 0 mismatches; E1 sheet: 2 tables, 0 mismatches); git diff --check clean; only 09 paths committed (other roles' uncommitted src/tests/tools edits in the shared tree were not touched or used).
- Local only (not committed): %TEMP%\r09\head_07b90c5 (snapshot), %TEMP%\r09\p1_07b90c5 (34 frames, sheet.png, top-bar zooms, launch JSON, godot log), %TEMP%\r09\import_07b90c5.log.

## Next
1. When 01 answers R09-01-17 (L1) or R09-01-16 (K1): update §37.5/§36.7 and, only then, the 04 request file.
2. When 04 commits the D31 rendering: read the code and 04/07 frames; check the r05-loss-only rule and the fit at 1× (R09-07-3 items 1–2).
3. When 07 delivers R09-07-2/R09-07-3: fill §36/§37 our-side rows with measured values.
4. Still open: E2 (07 r08 peak frame with enemies), R09-03-4 (icon test, people), R09-06-3 (KIPRIS, person), E1 pilot P4 (phone) and P5 (recording).
5. Any Godot/visible run: only inside coordination/heavy_run.ps1, one at a time, isolated APPDATA, DISPLAY2 only, from a clean HEAD snapshot.

## v18 (2026-10-31 19:10–20:05 KST): first-defeat comparison
Commit db1bb9b9e060e5d6c8bea6dd55a56bc6615602fb PUSHED (helper output; SHA copied after publish, verified with git show --stat and git branch -r --contains). It contains SUCCESS_ANALYSIS §37, R09-07-3 and R09-01-17.
- The session context was summarized mid-task; all frames were re-viewed and recorded in %TEMP%\r09\fs\obs.md ("# defeat task" block) before writing.
- Sources (§37.1): Battle Cats B1 k-LmII5inLA (stage 1, deliberate loss), B3 CtyF0JF20Ls (Japan, 2022); Random Dice D1 TjC0wbIsU6o, D2 _mF4t9KF8Qw (1:1, experienced player); Archer Forest A1 rapaA7QaK2I (56×90). Seen but not used: Waggle 9-VgTLT1GoQ, nukEuDqLZvM, FczlWnaZm8o (no result frame); Archer -n1XIRoLjJo (a win); Battle Cats Z_C2d-DJkuA, Vo81hBWXrW4 (not a first defeat).
- Table (§37.2): cause hint only at BC Japan; upgrade routing optional (BC text + pictures, close X, back to the map); no progress shown anywhere; taps to retry BC ≥3 (stage 1, via the title) and ≥2 (Japan, via the map), ours 1; BC energy "통솔력" box; monetization only flagged (Random Dice trophy boosting, Archer yellow box, both [U]).
- Ours [F] at d5f145a: result.gd loss branch, app.gd 1.2 s delay and cmd_retry, battle_sim.result() (no enemy base/boss/wave fields), economy loss_coin_ratio 0.5, r05.json (D33 scaling 1.25). D31 adopted by 01 (d09d740), keys in ko/en, 04 rendering not committed.
- Calc: 1× panel free space about 86 px; D31 lines may need 3–4 rows of 22 px; `UiStyle.fit_text` truncates with "…". Glyph width assumed (12 px), so 04/07 must measure.
- Candidate L1 → 01 (R09-01-17): on the r05 loss screen only, drop the always-empty star rows so D31 fits. Alternative: raise the 260 px panel cap. D31 text and no-forced-route kept. Excluded: energy cost, progress display (log only via 07), back-to-map/title, modal hint window, deck comparison, monetization.
- 07 R09-07-3: r05 loss frame 1×/2×, D31 fit/show rules after 04 renders, timings and tap counts, loss-moment enemy base/boss HP ratios (log only).
- Validation: table column counts checked (3 tables, 0 mismatches); git diff --check clean. Only 09 paths were changed (the untracked coordinator-to-* files and other roles' working-tree edits were not touched). The 04 request file was not edited. No Godot was run by 09.

## v17 (2026-10-31 18:35–19:10 KST): first-session comparison
Commit 3a8c340546b8ccb2315044e12a236a705055877d PUSHED (helper output; SHA copied after publish). It contains SUCCESS_ANALYSIS §36, R09-07-2 and R09-01-16.
- Sources (§36.1): Battle Cats F1 LVI8CNUGnC8 (EN fresh install, PONOS logo at 0:00), F2 7HHzOegdN1c (KR 15.7.0, from title), F3 qYHrq53ondg (KR 15.6.1, edited), S2 kb6u-IRIDFw; Waggle W3 h52yfbelEnE (KR, from title), W4 M3kjYM0UIsw (KR, 2 s step), W5 gZ53Ynwh21c, W6 MPv5uSd53G4, S5 dMlfFTrUx20, W1 QOi2v7jyZFU. 2KMHPReIsZM excluded (not a first launch). 몽글뭉치: none.
- (a) BC EN 6 screens, about 3:00 (about 2:20 if the story is skipped [calc]). Waggle 3 screens, about 15–20 s from the title. Ours: boot splash (default, duration [U]) → menu → 1 tap → r01 (app.gd boot, main_menu.gd _on_play).
- (b) Counting rule: one prompt block = 1, from the first battle frame to the second battle start; minimum counts. BC EN 3 modal arrow tips + 1 mascot bubble; Waggle W4 3 + 2, W3 2 + 3 (hand pointer + "TOUCH" at 1:05 on the party screen); ours 4 non-blocking gold text strips, 0 after the result (tutorial_director.gd, hud.gd).
- (c) BC: XP only, Ok + SNS, then about 8 popups incl. a Start-Up pack offer [monetization]. Waggle: WIN + LV bar + 1 reward, no buttons seen in 5 sources. Ours: result.gd stars/time/kills/reward/first-clear line, 4 buttons; the 4-button version was never captured (07 0590e7a shows 3 buttons, before 6051b3c).
- Readings: our path is shortest; prompt count is similar but competitors point at targets; competitor results are thin and route to growth screens (already R09-04-11). RELEASE_DESIGN_REVIEW §2.1's 30 s internal target now has observed brackets but no measurement.
- Design/code gaps [F]: §2.1 item 1 (single Play button, round select hidden until r01 clear) and item 5 (first-upgrade nudge after r02) are not in main_menu.gd/result.gd. Sent to 01.
- Validation: git diff --check clean; table column counts checked; sources read at 13aade1 are unchanged at 65502e8. Only 09 paths were changed (the untracked coordinator-to-* files are not 09's and were not touched). No Godot was run by 09.
- Temp files (not committed): %TEMP%\r09\fs\ obs.md ("# first-session task" block), sb_/pg_/crop_ images for the IDs above.

## v16 (2026-10-31 18:05–18:30 KST): D27 verdict + competitor base damage
Commit 620472c302ba9f07ca1d1e6b5dc01d826e11bd7d PUSHED (helper output; SHA copied after publish). It contains SUCCESS_ANALYSIS §35, the §34 corrections, R09-01-15 (plus the R09-01-14 correction) and R09-02-6.
- Interrupted by a rate limit at 18:02 and resumed. The working tree was checked first. No work was duplicated; the temp notes in %TEMP%\r09\fs\obs.md were reused.
- D27 = MODIFY: keep r05.
  - Measure = round index. Minutes and attempts are [U].
  - Battle Cats KR guide S2 order: Korea → Mongolia → China → Philippines → Japan (the first "2× harder" stage, 5th shown; skipped stages [U]).
  - The stuck BC player had upgraded after each clear, so the block pass line belongs in D28 casual (currently failing, 0/10).
  - BC shows a stage hint on defeat (CtyF0JF20Ls 0:48–0:53). Our result screen has no per-round hint. A 2-line r05 hint is proposed to 01/04.
- Base damage (§35.4):
  - BC: numeric x/max HP and smoke on each hit.
  - k-LmII5inLA (no units deployed): 984→0 in about 13 s, 3% then 21%/s.
  - 6mij7-xSrqU (late game): 192k → about 6k in about 26 s, 1.6% then 11%/s, held at about 3% and won.
  - No visible cap or base push-back. The cannon is the recovery tool (CtyF0JF20Ls 1:06).
  - Waggle (QOi2v7jyZFU, PLNIJnylJtw): a green bar per base; the player castle was never hit in about 10 min.
  - Cat War 2: the enemy castle tints red. 몽글뭉치: none.
  - [I] D29 B (25 HP/s on 1500) caps at 1.7%/s, below every observed rate. Our uncapped cascade (02 estimate, 2.6–6.7%/s) is in BC's range, so the gap may be the recovery tool.
  - D29 acceptance 1 (0.60–0.90) has no competitor basis.
- 02 R09-02-6 asks for:
  - columns for time-to-destroy and peak %/s;
  - a no-mechanic control F0, where the bot returns the hero to the base and casts skill_slam when ≥3 enemies are within 60 px of it.
- Correction: Japan is NOT the chapter-1 end (in S2 the Moon is). §34.2, §34.4(2) and R09-01-14 are corrected. The "r10 = BC spike position" reading is withdrawn.
- Not verified (needs Godot, owners after 18:30): the D29/F0 probe, minutes of play to reach our r05, and whether the base flash is visible at 1x.
- Validation: git diff --check clean. Only 09 paths were changed (the coordinator-to-* untracked files and the 04 request edits in the tree are not 09's and were not touched). No Godot was run.
- Temp files (not committed): %TEMP%\r09\fs\ sb_*.png, pg_*.png, crop_*.png, sb_meta3.json, obs.md, crop.py.

## Older (v14, 17:00–17:10 KST)
- 175ddc0d88c1cc890818b4f40606fc5352048e38 PUSHED: SUCCESS_ANALYSIS §33, first-stage timing from YouTube public storyboards.
  - Battle Cats KR st.1 (adRHiLSa2Os): (a) +3–4 s, (b) +18 s, (c) none seen, (d) ~68 s.
  - Cat War 2 st.1 (dzR0IMIFxvU): +8 s, +12–16 s, unreadable, ~62 s. A second video (2pZm2OXNEeU) runs >100 s.
  - Waggle Squad st.1 (M3kjYM0UIsw): +6 s, +8–14 s, none seen, ~34–38 s. dMlfFTrUx20 gives ~25 s ±5.
  - 몽글뭉치: no video or guide found.
- R09-01-13 gives candidate ranges: (a) ≤10 s, (b) ≤23 s, (c) 0 allowed, (d) 34–88 s. The rule is observed max × 1.3, an arbitrary 09 choice. X11 R1 is withdrawn. The 07 request adds the (a)–(d) measurement items.
- A follow-up commit corrects the data basis. The committed HEAD r01 has lane 1600 and waves 25/55/90. An uncommitted r01.json edit (lane 1100, waves 12/40/75) sits in the shared working tree. Its owner is unknown and 09 did not touch it.
- Local working files (not committed): %TEMP%\r09\fs\ (sb_*.png, zoom_*.png, sb_meta.json, yt.json, ys2.py).
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

## v13 (2026-10-31 ~17:00 KST): X9/X11 baseline + store first-3
Commit 9e0487d1011d407c42b91092fef4d55788502442 PUSHED (helper output; SHA copied after publish): SUCCESS_ANALYSIS §31, §32, §32.1; evidence/store_first3_2026-10-31.json (metadata only, no images); requests to 03 (R09-03-8), 04 (R09-04-10), 06 (R09-06-5), 07 (baseline gaps).
- Baseline from 07's visual-0590e7a reports and frames only (no Godot run): M2 FAIL, R1 FAIL, R2/R3/R4 PASS, M1/M3/R5 not measurable. The 4 runs are NOT independent (deterministic, identical t=60 values), so 07 was asked for varied seeds/policies, t=10/30/60 frames, HP min/first-drop/end fields, and a frame at the first drop. Data drift since the capture: only e_spitter/e_brute/boss_overlord and an r01 note changed (git diff), so the r01 baseline is presumed unchanged [inference].
- Store first-3 (Play KR, fetched 16:38): 7 listings. 6 of 7 show real battle within the first 3 images. Proposed our order: real lane battle → hero control → economy choice → roster → boss → result. Monetization excluded. No download/rank claims.
- Correction before publish: the fetch time was wrongly written as 16:52 and was fixed to 16:38.
- Validation: 5 listing URLs returned 200; JSON parses; diff --check clean; 09 paths only.

## v15 (2026-10-31 ~17:55 KST): growth motivation
Commit c6d0e9eda74825c850b27ecf84f2dc3962d43178 PUSHED (helper output; SHA copied after publish): SUCCESS_ANALYSIS §34; R09-01-14, R09-10-2, R09-04-11.
- Sources: 7 YouTube storyboards (S1–S7, dates/URLs/±step in §34.1) and Play KR descriptions for MadArcher, Battle Cats KR, Cat War 2, Waggle Squad (fetched 17:47). No images or raw captions committed.
- Findings [O]: the growth screen appears right after the first clear (1:30–4:40 into play) in all 4 games and reopens after nearly every stage (Cat War 2 player skipped it for L8–10 and still won). No defeat in any beginner video (10–25 min). The KR Battle Cats guide flags the chapter-1 end as the first spike (corrected in v16: the spike is Japan, which is not the chapter end) and solves it with levels + tactic + unit swap.
- Reading [I]: r10-only need sits where Battle Cats' first spike sits (withdrawn in v16); the gap is entry habit and small repeat rewards. Counter-explanations (monetization coupling, skilled YouTubers, old/EN versions, idle model of 아처키우기) are recorded.
- Basis update: D25 (a262640) committed r01 lane 1100; §33.2 basis superseded. D26 max-out ≈14 LOW / 9 HIGH r10 replays.
- Validation: diff --check clean; 09 paths only.
