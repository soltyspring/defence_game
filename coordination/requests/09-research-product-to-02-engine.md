# 09-research-product → 02-engine
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §11, §15. Proposals only.

## R09-02-1 Interruption resume (E3)
- Observation: Random Dice 2 Play reviews (2026-08-29, 2026-09-15): home button/phone call resets the run; slow reconnect ejects the player and the ticket is lost. Data-loss complaints also in Random Dice and Archer Forest samples.
- Ask: on app pause/background the round pauses and survives 30 s and 5 min; after force-kill, loss is limited to the current round and meta progress (gold/stars/upgrades) is intact.
- Acceptance: device run by 07 (desktop not sufficient), same state or pause screen on return; save file valid after kill. 10-research-systems covers schema side (R09-10-1).

## R09-02-2 Peak readability caps (E5, with 08)
- Observation: Random Dice co-op store screenshots show damage numbers/FX covering the board at late waves. Our art mock (docs/art/evidence/battle_cap_1x.png) already shows bursts/smoke overlapping the front line.
- Ask: keep popup cap 24 / FX cap 48; expose a setting to disable damage numbers (default decision with 01/04).
- Acceptance: 08 peak-frame count within caps; 07 E2 readability passes.

## R09-02-3 E4 sim (deferred)
After r04+ balance is fixed (01 checkpoint), run baseline vs "pick 1 of 3 boost between waves" over seeds; report worst-seed outcome.

## R09-02-4 Review-derived risks in 02 scope (2026-10-31 ~10:15 KST, SUCCESS_ANALYSIS.md §22)
- Progress loss is the most damaging complaint in competitor samples (Random Dice: 3 years of data reset 2026-10-17; device migration lost 90%). Our matching defect: backup rotation (10 SV-1 reproduced, 07 B004 P1). Ask: fix it and have 07 re-run the same fault sequence; acceptance = unlocked_round unchanged after two consecutive corruptions, and a user-visible notice when recovery happens.
- 04's capture log godot_20261031_085555.log shows `Failed loading resource: res://assets/atlases/char_player_adv.png` and `char_enemy_adv.png` (import missing). Please re-import with 03; acceptance = no Failed loading in a real r05 run.
- 2x speed: 04 reports no engine command exists. If 01 decides on free 2x, expose a sim time-scale command (headless-testable).
