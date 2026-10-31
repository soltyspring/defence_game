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
