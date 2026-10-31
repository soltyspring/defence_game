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

## Update 2026-10-31 17:25 (clean HEAD 97c8b9c, import-guarded run 20261031-171211)
- QA-B014 VERIFIED for your 10 keys. **QA-B016 (P3)**: one more key `ui.upgrade_save_uncertain` (04 upgrade_panel.gd) missing in ko+en. Pass: DATA-13/14 PASS.
- QA-J2 **CLOSED** under your D24(a) rule: probe_r01_risk 20 seeds: competent / late-45 s / casual 20/20 W; idle 20/20 lost by base destruction, latest 258.1 s (<= 300 s).
- Balance cross-check (docs/verification/BALANCE_CROSSCHECK.md, 10 seeds, different noise): your LOW claims hold (r05 10/10 worst 0.57, r09 10/10 1.00, r10 10/10 0.92). Two differences to answer:
  1. r05 with **no** upgrades: your worst base 1.00, mine **0.03** (median 0.41, median time 363 s vs your 263 s).
  2. Casual policy loses r05 and r10 **0/10 even at LOW**, after winning r01-r04 and r09. Is r05 meant to be a cliff for casual play? Please state a casual-policy target or say casual is out of scope.
- QA-O004: "wave 0/3" vs 6 waves is by contract (D21, INTERFACES v1.4). **QA-B017 (P3, with 04)**: after the last counted wave the HUD has no announcement or timer while pressure waves still arrive (code reading). Decide whether the player should be warned.
- Q3: menu logo shows the working title correctly (QA-B015 VERIFIED); `ui.title` text and project `config/name` still "Lane Defence".

## Update 2026-10-31 17:45 (clean HEAD 09508b1, run 20261031-173017 PASS 152 / FAIL 0)
- QA-B016 VERIFIED (DATA-13/14 PASS).
- **QA-B018 (P3)**: after the rename to 밀가루/Flour, `upgrade.supply_regen` still reads "보급 증가" / "Supply Boost" on the upgrade screen (docs/verification/evidence/visual6-09508b1/*_notch_text_2_upgrades.png). Pass: the upgrade row uses the same resource word as the HUD in ko and en.
- Title (Q3) text fallback forced: en 2 lines 312/174 px, ko 1 line 456 px, all <= 572 px at 34+34 notch. PASS.
- Balance after D25 (docs/verification/BALANCE_CROSSCHECK.md): unchanged for r05/r09; casual policy still 0/10 at r05 and r10 with LOW; r05 no-upgrade worst base 0.03 (yours 1.00). Please answer the casual target question from the previous update.
- Q4: debug APK label ko '빵집 기사단', en 'Bakery Knights' (PASS, APK pre-dates the commit). Package id is still `com.soltyspring.lanedefence`; it cannot change after the first store upload. Decide before any upload (with 02/06).

## 2026-10-31 18:10 — rejection reason + one user-question candidate (01 decides whether to ask)
Static write-up, no new runs (08 quiet window). Evidence: docs/verification/BALANCE_CROSSCHECK.md (two runs, before and after D25).
**Rejection reason (hostile review R-casual):** "We cannot say whether this game is fair for ordinary players." With LOW upgrades, 02's casual bot policy wins r01–r04 and r09 but loses **r05 0/10 and r10 0/10** (both runs, seeds 101–110); the competent policy wins 10/10. Without a stated target for non-expert play, a 0/10 is neither a defect nor acceptable, so 07 can only report it. A reviewer would ask "who is this difficulty for?" and the documents give no number.
**What is missing:** a target such as "a casual-policy bot with the LOW budget wins each chapter-1 round in at least N of 10 seeds", or an explicit statement that casual play is not a design target and that upgrades/replays are the intended route.
**User-question candidate (one, for 01 to decide; only 01 asks the user):**
> 일반 플레이어(전략을 깊게 쓰지 않는 사람)가 강화를 조금만 했을 때, 5라운드와 10라운드를 처음 몇 번 시도 안에 깰 수 있어야 하나요?
> A) 대부분 첫 시도에 깬다(쉬움) · B) 2~3번 시도하고 강화를 사면 깬다(권장 후보: 현재 '강화가 중요' 설계와 맞음) · C) 숙련 플레이어만 깬다(어려움)
If 01 answers it from design instead (D24-style default), please record the number so 07 can turn it into a pass/fail check.

## Update 2026-10-31 19:35 — D27 cross-check and D28 as pass/fail (HEAD fca9346)
probe_balance.gd now has `--d28` (summary per D28 row). Run per round with a 200 s cap; details docs/verification/BALANCE_CROSSCHECK.md (last section).
- **D28: 5 of 9 executed rows FAIL** — casual LOW r02 0/10, r03 6/10, r04 0/10, r05 0/10 (low2r also 0/10), r06 1/10. PASS: r01 9/10, r07–r09 10/10. r10 low2r NOT_RUN (cap).
- D27 changed this: before D27 casual won r01–r04 and r09; the enemy_scaling raise for r02–r05 removed that.
- Competent vs your D27 table: r05 LOW **8/10, worst base 0.00** (yours 10/10); r05 none **0/10** (yours 4/10); r02 LOW has one full loss.
- Your bimodality challenge: r04 LOW worst 0.99 and an r02 loss; not strictly bimodal with my noise.
- QA-J1: identity part now PASS (village/nest, sky 17 % at r01); enemy-visibility target still missing (0 enemies on screen t = 7–22 s, 1–4 at 27–32 s).
- QA-B018 still open (`upgrade.supply_regen` = 보급 증가 / Supply Boost).

## R-casual follow-up 2026-10-31 19:58 — 07 re-check of D30 at HEAD d5f145a (data tree 8c7b0a3)
**Result:** your r05 casual LOW 9/10 is confirmed (07: 8/10; low2r 10/10). r02 casual LOW 10/10, r04 10/10. All three D28 rows PASS. My earlier 0/10 rows (fca9346) were caused by a timing defect in **07's own** probe, the same class as your D30 bug; fixed and withdrawn (docs/verification/BALANCE_CROSSCHECK.md "Correction").
| Item | 01 multi_seed_sim.gd.txt (after d09d740) | 07 probe_balance.gd (before fix) | 07 probe_balance.gd (now) |
|---|---|---|---|
| Bot | 02 `bot_player.gd`, skill 2 / 1 | same | same |
| dt passed to `bot.act` | real time since last call (`since_act`) | always 1/60 s while calls were ~0.09 s apart (think timer ~5× slow) | real time since last call (`since_act`); `--legacy-dt` = old |
| First action | U(0,3) s | U(0,5) s | U(0,5) s |
| Per-decision delay | U(0,0.35) s every call | U(0,0.6) s on 25 % of calls | same |
| Seeds | 1–5 (D30 tables) | 101–110 | 101–110 |
| Budgets | upgrade_budgets.json low / low2r / opt / high | low / low2r / none | same |
| Sim step | 1/60 | 1/60 | 1/60 |
Control: same build, `--legacy-dt`: r05 casual LOW 0/10 → the harness, not the data, explained the conflict.
Still for you to judge: competent LOW r05 **7/10, worst base 0.00** (your earlier rule "every round must win at LOW"); r02 competent median 274 s > 1.25 × par 170 s = 212 s. Not re-run with the fixed probe: r01, r03, r06–r10.
