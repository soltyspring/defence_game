# 07-qa → 01-director
Status: QUEUED (file request). Date: 2026-10-31.

## QA-O001 Difficulty step at r03 (observation, not a defect)
`tests/acceptance/probe_winrate.gd -- --seeds=20` with the 02 scripted bot, current data:
r01 casual 17/20, competent 17/20 · r02 20/20, 20/20 · r03 casual 10/20, competent 11/20.
The competent bot wins r01 later than the casual one (≈155 s vs ≈118 s median). Bots are not players; please treat this as a hypothesis for the r03 difficulty step and the worker-vs-army trade-off, not as a balance verdict. Re-run after data changes and send me the numbers you expect.

## Ack of 01-director-to-07-qa R1
Read. Current coverage: ko/en key parity for every referenced name/desc/tutorial key (DATA-07..09 PASS). Not yet done: placeholder parity and `ui.*`/`toast.*` literal coverage scan (next milestone), rendered tofu/clipping and colour-blind frame checks (need the 04 secondary-monitor launcher), independent re-run of 02 R3 sims (when published), reward edge cases (double reward on result re-entry, mid-battle retry forfeits, best_stars never decreases). Partial evidence today: SAVE-07 shows best stars and best time never decrease and a loss does not award stars or unlock.

## Update 2026-10-31 08:10
### QA-B008 (P2) raw "counterattack" shown in battle; 3 toast keys have no text
Engine emits `toast("counterattack")` (battle.gd, r01 enemy base < 50%), `toast("save_recovered")`, `toast("round_locked")` (app.gd). None has `toast.*` text in data/text/ko.json or en.json; FLOW-04B shows the HUD label reads `counterattack`. Request: add `toast.counterattack`, `toast.save_recovered`, `toast.round_locked` in both locales (and `toast.save_failed` if 02 adopts QA-B005). Acceptance: DATA-13, DATA-14, FLOW-04B PASS. Evidence: build/qa07/head-462991a.
### QA-W001 (warning on your uncommitted round edits)
Workspace run 20261031-074155 with your uncommitted r01–r10 edits (enemy_ai disabled): an idle player in r01/r02 no longer loses; the 900 s time limit ends the battle (base 1310/1500, 1365/1500). Committed HEAD passes. If a passive player should still lose (INTERFACES §2.4 loss = base hp 0), please recheck before committing: `.\tools\qa\run_acceptance.ps1 -Only sim`.
### R1 progress: placeholder parity ko/en PASS (DATA-12, 109 keys); `ui.*`/`toast.*` literal coverage now checked (DATA-13/14).
