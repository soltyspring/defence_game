# 07-qa → 01-director — consolidated fix list v2
Status: QUEUED (file request). Date: 2026-10-31 09:15 +09:00. Replaces earlier sections (history in git).
Verification condition: clean committed HEAD, `.\tools\qa\run_acceptance.ps1 -Head -Only <suites>`. Desktop headless only.

## D0 Record the theme decision
The coordinator relayed Q1 = A "빵집 기사단 vs 곰팡이 군단" and the instruction "모두 고치라". `docs/design/DECISIONS.md` at HEAD still shows Q1 PENDING. Please record the literal answer and implications so other roles can cite it.

## Open for 01
### QA-B008 (P2) toast keys without text — DATA-13, DATA-14, FLOW-04B
- Reproduce: `.\tools\qa\run_acceptance.ps1 -Head -Only data,flow`
- Missing in both ko.json and en.json at HEAD 5426645 (run 20261031-091441; FLOW-04B now PASS, DATA-13/14 still FAIL): `toast.counterattack` (battle.gd, shown raw in battle), `toast.save_recovered`, `toast.round_locked`, `toast.save_failed`, `toast.save_read_only` (app.gd / save.gd).
- Pass criterion: DATA-13, DATA-14 PASS (FLOW-04B must stay PASS).
### QA-B009/B010 (P2, with 04) English labels too long — TH-FIT-HUD-EN, TH-FIT-ROUND-EN
- Card slot at r08–r10 worst layout is 36.7 px; round tile 83 px (details in 07-qa-to-04-client.md). When writing theme names, keep EN card names ≤ 36 px and round names ≤ 83 px at 12 px in the bundled font, or agree a layout change with 04.
- Pass criterion: all TH-FIT-* PASS.
### Theme rename guard
After renaming, TH-TEXT-KO/EN must stay PASS: every card/skill/round/hero/enemy name exists in both locales, non-empty, not equal to its key or id. Run `-Head -Only theme,data`.

## Warnings (work tree only, not product bugs)
- QA-W001: your uncommitted round edits (enemy AI disabled) make an idle player in r01/r02 survive to the 900 s time limit (R1-LOSS, R2-LOSS FAIL in workspace runs; HEAD PASS). Before committing: `.\tools\qa\run_acceptance.ps1 -Only sim` must keep R*-LOSS PASS, or change the loss rule explicitly in INTERFACES/DATA_SCHEMA.
- QA-W003 resolved (ui.star_* keys committed).

## Observation
QA-O001 bot win rate at HEAD e9dfaa4 (20 seeds, casual/competent): r01 18/15, r02 20/20, r03 14/10.

Re-confirmed at HEAD 5426645, run 20261031-091441: PASS 137 · FAIL 6 (DATA-13, DATA-14, TH-FIT-HUD-EN, TH-FIT-ROUND-EN, TH-COL-PROTAN, TH-COL-DEUTAN) · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 0.

## Re-test 2026-10-31 15:40 at HEAD 2884231 (run 20261031-153757, -Head)
- QA-B008 still FAIL (DATA-13/14): missing `toast.save_recovered`, `toast.save_read_only`, `toast.round_locked`, `toast.save_failed` in ko+en. `toast.counterattack` now present. Pass: DATA-13, DATA-14 PASS.
- QA-W001 RESOLVED (D18 committed; R1/R2-LOSS PASS).
- Q1 = A is in coordinator-to-07-qa.md (09:03) but `DECISIONS.md` row Q1 still says PENDING at HEAD: please change it to DECIDED with the literal answer.
- Theme names not renamed at HEAD; TH-TEXT-* and TH-FIT-* will be re-run on your rename commit.

## Re-test 2026-10-31 15:50 at HEAD abe2303 (run 20261031-154903, -Head)
- QA-B008 VERIFIED (DATA-13/14 PASS). Theme A names pass TH-TEXT-KO/EN and both fit checks. Q1 DECIDED recorded - thanks.

## First-3-minute hostile review 2026-10-31 16:10 (HEAD 0590e7a, docs/verification/FIRST_3MIN_REVIEW.md)
- **QA-J2 (P2)**: r01 has no risk. Casual bot, 4/4 capture runs: won at 105-106 s, 3 stars, player base 1500/1500 untouched; waves 4-6 (160/210/260 s) never spawn. Decide r01 intent (tutorial vs challenge) and write a numeric rule in ROUNDS.md; 07 checks it with capture_visual.gd r01 report + probe_winrate.
- **QA-J3 (cc)**: tut_buy_worker says '반죽' but the HUD never names the resource; add the word to the HUD/first hint copy with 04.

## Update 2026-10-31 16:50 (clean HEAD 68866e9; VISUAL_CHECKS C5-C8, FIRST_3MIN_REVIEW re-judgement)
- **QA-B014 (P3)**: 10 `ui.upgrade*` keys (ui.upgrades, ui.upgrade_unavailable, ui.upgrade_buy, ui.upgrade_ok, ui.upgrade_not_enough, ui.upgrade_max, ui.upgrade_save_failed, ui.upgrade_locked, ui.upgrade_error, ui.upgrade_none) missing in data/text ko+en; DATA-13/14 FAIL. Pass: DATA-13/14 PASS.
- **QA-B015 (cc)**: Q3 English title 588 px > 572 px notch safe width at the current title font; coordinate with 04 before setting ui.title.
- **QA-J2 still OPEN**: probe_r01_risk 20 seeds: casual and competent 20/20 wins, 20/20 three stars, base never hit, median clear 108 s / 130 s, waves reached 3/6. Please write the r01 rule (tutorial or challenge) as numbers; 07 re-runs `tests/acceptance/probe_r01_risk.gd`.
- Observation: r01 HUD 'wave 0/3' vs 6 waves in data.
