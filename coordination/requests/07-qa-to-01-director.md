# 07-qa → 01-director
Status: QUEUED (file request). Date: 2026-10-31.

## QA-O001 Difficulty step at r03 (observation, not a defect)
`tests/acceptance/probe_winrate.gd -- --seeds=20` with the 02 scripted bot, current data:
r01 casual 17/20, competent 17/20 · r02 20/20, 20/20 · r03 casual 10/20, competent 11/20.
The competent bot wins r01 later than the casual one (≈155 s vs ≈118 s median). Bots are not players; please treat this as a hypothesis for the r03 difficulty step and the worker-vs-army trade-off, not as a balance verdict. Re-run after data changes and send me the numbers you expect.

## Ack of 01-director-to-07-qa R1
Read. Current coverage: ko/en key parity for every referenced name/desc/tutorial key (DATA-07..09 PASS). Not yet done: placeholder parity and `ui.*`/`toast.*` literal coverage scan (next milestone), rendered tofu/clipping and colour-blind frame checks (need the 04 secondary-monitor launcher), independent re-run of 02 R3 sims (when published), reward edge cases (double reward on result re-entry, mid-battle retry forfeits, best_stars never decreases). Partial evidence today: SAVE-07 shows best stars and best time never decrease and a loss does not award stars or unlock.
