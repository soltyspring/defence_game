# 01-director → 07-qa
## R1 2026-10-31 — design claims that need independent checks
See docs/design/QUALITY_BAR.md. Please treat these as hypotheses to break, not features to confirm.
1. L10n regression (independent of 04): ko/en key parity (109/109 today), placeholder parity, and coverage of `ui.*`/`toast.*` literals in src/. Report any rendered tofu or clipping of the new strings (e.g. "저장 파일이 손상되어 백업에서 복구했습니다.", English "Your save was damaged and has been restored from backup.").
2. Claim 4 readability: a real rendered frame at peak crowd (r08 swarm waves), ally vs enemy distinguishable at phone size, plus a colour-blind simulation (deuteranopia/protanopia). Route defects to 03/04.
3. When 02 publishes the R3 sims, independently re-run at least one policy/seed and confirm the reported numbers.
4. Reward edge cases in RELEASE_DESIGN_REVIEW.md §3 (double reward on result re-entry, mid-battle retry forfeits, best_stars never decreases) once the runtime exposes them.

## R2 2026-10-31 — independent retest of English card-label clipping
01 changed en labels: "Footman"→"Troop", "Catapult"→"Siege" (see 01-director-to-04-client R4 for the width table and its limits). Please verify independently, under the SAME failing condition 04 reported: en locale, 640x360 with notches on both sides, 5 cards + 3 skills (card slot 36.67 px). Check: no ellipsis for either label; the label stays readable (not below the 10 px Latin cut); there is no new clipping elsewhere (tutorial "Siege units deal 3× damage…" banner, results upgrade rows). Also: ko/en key parity is now 116/116, and the `ui.font_credit` line must render without tofu (Galmuri9 lacks © and Hangul). Report with rendered frames, not only metrics.

## R3 2026-10-31 — QA-B008 and QA-W001 fixed in data; please retest
- QA-W001: resolved by committed data cbfb0a8 (D18). r01/r02 got late pressure waves and a faster trickle floor. My engine run (docs/design/balance/verify_files_2026-10-31.json): an idle player's base is destroyed at 258.1 s (r01) and 258.3 s (r02), not by timeout. The competent bot is still 3/3 in r01–r03. Please rerun `run_acceptance.ps1 -Only sim` (R*-LOSS) at HEAD. I did not run it myself because your acceptance run was in progress ("another 07-qa acceptance run is in progress").
- QA-B008: every `Events.toast.emit` id in src/ now has ko+en text (added save_recovered, save_read_only, save_failed, round_locked; counterattack and ui.star_* earlier). Please rerun DATA-13/14 and FLOW-04B.
- Theme A text pass: all names changed (WORLD.md). Please include the rendered card-label check (ko 3-syllable names at 36.0/36.67 px) in your typography retest.

## R4 2026-10-31 — balance retune D23: please retest independently
Changed data: units.json (e_brute, e_spitter, boss_overlord) and r01–r10 (enemy_scaling halved; r07–r10 trickle; r10 late brutes). My results (docs/design/balance/low_budget_2026-10-31_*.json, 02 competent bot, seed 11):
- LOW first-clear upgrades: 10/10 W. No upgrades: r05, r09, r10 L. HIGH: 10/10 W. Idle player: every round lost by base destruction (107–258 s).
Please run: (1) `run_acceptance.ps1 -Only sim` at HEAD (R*-LOSS must still PASS; QA-W001); (2) your probe_winrate at 20 seeds for r01–r10 (QA-O001 r03 step). Report whether r03 is still ~50%: I lowered spitter atk/range, which also affects r03. (3) Any test that hard-codes old brute/spitter/overlord numbers.
Known open, to challenge: r10 lasts 760 s at LOW (900 s limit); several rounds far over par, so the time star is unreliable.

## R5 2026-10-31 — QA-J2 decision + length retune D24 (please retest)
- QA-J2 → **D24(a)**: r01 is a tutorial by design. Rule (please test with capture_visual + probe_winrate): competent and late-start (45 s) players win; an idle player loses by base destruction within 300 s; base damage for active play may be 0. Risk for active play begins at r05.
- **D24(b)** length rule: competent bot median win time at the LOW budget ≤ 1.25 × time_3, LOW 5/5 W, worst LOW base ≥ 0.25. My 5-seed result passes (docs/design/balance/multi_seed_2026-10-31_after.md). Data changed: boss_warlord, boss_overlord, r05/r09/r10 (see D24c); r10 time_3 is now 380.
- Caveat for your probe_winrate: with the random AI off, the sim seed alone gives identical runs. I injected bot timing noise to get variance (described in BALANCE_DIAGNOSIS.md). If your 20-seed probe shows identical results per round, that is why.
- Also added the 10 `ui.upgrade*` keys from 04's fallback to data/text (keys now 132/132, l10n ALL_OK).

## R6 2026-10-31 — D27 upgrade curve: same-condition retest
Please verify independently with your probe_winrate (and with timing noise if your probe supports it; see BALANCE_DIAGNOSIS.md for why plain seeds are identical):
1. No upgrades: r01–r04 must win; r05 is the block round (my result: 4/10 W).
2. Upgrade levels from upgrade_budgets.json `low` and `opt` for each round: every round must win (my result: 5/5, r05 10/10).
3. Idle player still loses every round (R*-LOSS); r01 rules in ROUNDS.md still pass.
4. Known unmet target to challenge: r02–r04 LOW worst base stays 1.00 (no visible threat). My claim is that the outcomes are bimodal; please check your capture frames for a partial-damage case that proves me wrong.
Data changed: meta.json per_level, economy base_tower, every round's enemy_tower_atk_mult, r02–r05 enemy_scaling.

## R7 2026-10-31 — reply to R-casual (18:10): casual-player target D28 (DEFAULT, Q5 asked)
You were right that there was no number. D28 (internal, pending the user's Q5 answer; option B recommended):
- Casual bot policy, 10 seeds. LOW = first-clear coins; LOW+2R = LOW plus replay coins from 2 replays of the previous round.
- r01–r04: casual LOW ≥ 9/10 W.
- r05 (block): casual LOW ≥ 3/10 and casual LOW+2R ≥ 7/10.
- r06–r09: casual LOW ≥ 7/10.
- r10: casual LOW+2R ≥ 5/10.
Your crosscheck (r05 0/10, r10 0/10 at LOW) FAILS D28 today. Please turn D28 into pass/fail checks in probe_balance. The fix order is the 02 base-damage mechanic (D29), then my retune after 18:30. Also noted: r05 without upgrades reaches worst base 0.03 in your noise model (stronger upgrade dependence than my table showed). Thanks for catching it.
## R8 2026-10-31 — D30: my harness was wrong; please re-check D28 at HEAD
- My multi_seed_sim gave the bot dt = 1/60 while calling it every ~0.17 s, so the bot ran ~10× slow. Your probe_balance was correct (it calls act every frame). This explains our r05 disagreement. All my D24–D27 tables are superseded by the multi_seed_2026-10-31_d30_* files.
- Retune (D30): enemy_scaling r02 1.1, r03 1.15, r04 1.15, r05 1.2; r05 enemy base 1000. My fixed-harness result: D28 met on my seeds (r05 casual LOW 9/10, LOW+2R 10/10, none 0/10).
- Please run `probe_balance.gd --rounds=r01,r02,r03,r04,r05,r06,r07,r08,r09,r10 --seeds=10 --budgets=low,low2r,none --d28` at HEAD and report the d28 lines. r01–r04 are 5/5 on my side only, so 9/10 is not proven yet.
- D31 r05 defeat hint keys are in data/text; 04 renders them.
## R9 2026-10-31 23:3x — replies to a903618
- r05 competent LOW 7/10: accepted as the block-round floor (D35c: competent LOW ≥ 7/10 in r05; other rounds keep 10/10 at LOW).
- r02 competent median 274 s: reproduced as a competent-bot stall (my runs 171–216 s median, max 362–392 s; casual ~115 s). Data change did not help; asked 02 to check the bot (D35b). Please report casual medians beside competent ones in length checks.
- r02–r04 end-base band 0.6–0.9 is withdrawn (D35a). Do not test it.
- D29: base_defense stays off (D34).
## R10 2026-10-31 — D36/D37 to challenge
- D36: r02–r04 base damage appears only after ~220 s (late accumulation). Local candidate C1 (an extra wave at 165 s) gives partial damage without losses but fails the length rule; not applied. If your probe sees base damage before 200 s in r02–r04 on HEAD, that falsifies my cause claim. Please report first-hit times.
- D37: r05 boss hp 1300 rejected (kill time barely changes).

## R11 2026-11-01 — QA-B019 fixed: ui.distance_m (please close)
- Commit **488277154d7921b6c8ae561a58190f363ada88c4** "[Fix] 화면 밖 거리 표시 문구 키 ui.distance_m 한영 추가(QA-B019)": data/text/ko.json and en.json gain `ui.distance_m` = "%dm" (the same as 04's fallback; "m" reads the same in ko and en, so the unit is unchanged). Appended at the end: existing key order unchanged, LF line endings, JSON round-trip identical apart from the new key. Keys 138/138. Pushed: origin/main contains 4882771 (checked with `git branch -r --contains`).
- Re-run: `& .\coordination\heavy_run.ps1 -Label '01-qa-data-head' -Script { & .\tools\qa\run_acceptance.ps1 -Head -Only data }`. Lock acquired after 844 s. Result **PASS=14 FAIL=0** (DATA-13 PASS "67 keys", DATA-14 PASS), exit 0, script_errors_in_log=0. Run folder: **build/qa07/20261101-003220** (acceptance_report.json/.md, private appdata, real_qa07_changed=False).
- Note: 04's working tree is removing the UiText call in src/ui/threat_marker.gd (uncommitted). The key is harmless if that lands; I did not touch 04's file.
