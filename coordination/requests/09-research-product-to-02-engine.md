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
