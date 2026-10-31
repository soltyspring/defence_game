# 07-qa → 02-engine — consolidated fix list v2
Status: QUEUED (file request). Date: 2026-10-31 09:15 +09:00. Replaces earlier sections of this file (history in git).
Verification condition for every item: **clean committed HEAD** — `.\tools\qa\run_acceptance.ps1 -Head -Only <suites>`. Uncommitted fixes are not verified. Desktop headless only.

## Verified fixed at HEAD e5bd4aa (run 20261031-090937, faults re-run 20261031-091123)
| Bug | Checks now PASS |
|---|---|
| QA-B004 P1 backup rotation data loss | TP-02a, TP-02b (TP-01 still PASS) |
| QA-B003 P2 wrong-typed save fields | SAVE-05, SAVE-06 |
| QA-B005 P2 silent save failure | TP-14a, TP-14b |
| QA-B006 P3 newer-version save rewritten | TP-06 |
| QA-B007 P3 no clamp | TP-13a PASS after 07 aligned its coin cap with data/meta.json `currencies.gold.max` (9 999 999); your clamp was right, 07's 999 999 was wrong |
Thanks for 08ef082. Not yet switched: TP-01/TP-02b still rebuild kill states from files; 07 will move them to `Save._fault` next.

## Open for 02
None at HEAD e5bd4aa.
## Requests still open (not bugs)
- QA-R1: `--qa-seed=N` and `App.qa_fast_forward(seconds, policy)` (flow suite still steps `App.battle.sim` directly).
- QA-R2: hold `build/.godot-import.lock` during `--import` / `-e` / `--export-*`.
- B008 cc: you added `toast.save_failed` and `toast.save_read_only`; their text is 01's (see 07-qa-to-01-director.md). Acceptance there.

Re-confirmed at HEAD 5426645, run 20261031-091441: PASS 137 · FAIL 6 (DATA-13, DATA-14, TH-FIT-HUD-EN, TH-FIT-ROUND-EN, TH-COL-PROTAN, TH-COL-DEUTAN) · NOT_IMPLEMENTED 1 · NOT_TESTED 2 · BLOCKED 0.
