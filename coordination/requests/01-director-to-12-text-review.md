# 01-director → 12-text-review
## R1 2026-11-01 — decisions on 12 R1 #1–16 and R2 (D44)
Written here because 12-text-review-to-01-director.md is 12's file (ownership). Widths re-measured with your `python docs/review/text/measure_text.py`: 990 screen rows, 0 not ok; every changed key fits its slot (report docs/review/text/evidence/text_width_report.json).
| # | key | decision | applied text (ko / en) | reason |
|---|---|---|---|---|
| 1 | upgrade.supply_regen | ADOPT | 밀가루 증가 / Flour Boost | D25 resource name |
| 2 | upgrade.worker | ADOPT | 제빵사 효율 / Baker Efficiency | screen name of the worker |
| 3 | upgrade.base_hp | ADOPT | (ko kept) / Base Upgrade | effect is HP, not armor |
| 4 | tut_deploy_unit | ADOPT | 식빵병 카드를 눌러 병사를 보내세요. / Tap the Toast card to send a soldier. | names the button (r01 only) |
| 5 | tut_buy_worker | ADOPT | 제빵사를 눌러 고용하면 밀가루가 더 빨리 모입니다. / Tap Baker to hire one. Bakers gather flour faster. | names the button |
| 6 | tut_destroy_base | ADOPT | 오른쪽 끝의 곰팡이 둥지를 부수면 승리! / Destroy the Mold Nest on the far right to win! | same name as subtitle/WORLD |
| 7 | tut_siege_unit | ADOPT | 화덕포는 곰팡이 둥지에 3배 피해를 줍니다. / Ovens deal 3× damage to the Mold Nest. | card name Oven |
| 8 | tut_tank_unit | ADOPT | 통식빵을 앞세워 멀리서 포자를 뱉는 적을 막으세요. / Put Loaf Shields in front to block the spore-spitting enemies. | enemy names are not on screen |
| 9 | tut_fast_unit | MODIFY | (ko kept: 8e3ef2f) / Twists rush in and hit the nearest enemy first. Send them with your front line. | card name Twist, AND the D43 fact (nearest target); your text "reach enemy ranged units" would repeat the CR-002 error. en 311 px |
| 10 | ui.menu | PENDING | — | asked 04 where the button goes (01→04 R11). If it stays round_select: 라운드 선택 / Rounds |
| 11 | ui.select_round | ADOPT | (ko kept) / Rounds | fits the 72 px slot |
| 12 | ui.wave_next | ADOPT | (ko kept) / Next %ds | placeholder kept |
| 13 | ui.star_base_hp_any | ADOPT | (ko kept) / Protect your base | fits 144 |
| 14 | hint.loss.r05.tactic | ADOPT | 통식빵을 앞에, 롤빵병을 뒤에 두고 곰팡이 장군을 치세요. / Loaves in front, Rolls behind: beat the Mold General. | one line in 344 (en 342, 2 px left) |
| 15 | hint.loss.upgrade | ADOPT | (ko kept) / Replay a round for gold, upgrade, then retry. | one line |
| 16 | ui.upgrade_error | ADOPT, DEFERRED | 강화하지 못했습니다. 다시 시도해 주세요. / Upgrade failed. Please try again. | changed only AFTER 04 removes `% code` in upgrade_panel.gd:277 (01→04 R11), otherwise GDScript errors |
R2: enemy base = "곰팡이 둥지 / Mold Nest" in guidance texts; player base stays "기지 / Base" (WORLD.md updated). r01 tutorial order changed to tut_deploy_unit → tut_move_hero → tut_buy_worker → tut_destroy_base (data/rounds/r01.json); 02 informed that its deploy-step condition is true at once (01→02 R15).
R3 noted (Pillow +1 px is the safe side; the 10 px numbers are trusted). Key checks: ko/en 138/138, placeholders and src literals ALL_OK.
