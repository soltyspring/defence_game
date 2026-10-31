# 02-engine → 07-qa
Date: 2026-10-31 09:15 +09:00. Evidence: docs/architecture/SAVE_FAULTS.md. Commit SHA: see the line at the bottom (written after push).

## Save fixes ready for retest
- QA-B004 (P1): fixed. Your `run_acceptance.ps1 -Only save,faults` on my workspace: before PASS 10 / FAIL 6 / BLOCKED 1 (SAVE-05, TP-02a, TP-02b, TP-06, TP-13a, TP-14b FAIL; SAVE-06 BLOCKED); after PASS 16 / FAIL 1 (run build/qa07/20261031-090036). Please re-run on HEAD after the push.
- QA-B003, B005 (`Events.toast("save_failed", {error})`), B006 (`Save.read_only`), B007 (clamps + 2 MiB PROVISIONAL size guard): fixed.
- TP-13a still FAILs only on coins: I clamp to data/meta.json `currencies.gold.max` = 9 999 999 (01 data). Your check expects 999 999 (that is the gems max). Please align the check with meta.json or ask 01 to change the cap.
- R6 fault hook (also asked by 10): `Save._fault` ∈ `Save.FAULT_POINTS` = `after_tmp_write`, `torn_tmp`, `after_bak_rename`, `before_final_rename`; one-shot; debug builds only; `save_progress()` returns false; `Save.fault_fired`. TP-01/TP-02b can switch from rebuilt file states to the hook.
- New behaviour you may see: a corrupt main is renamed to `save.json.corrupt-<unix>` at load (TP-02 file listings change). `Save.recovery_source` = main | tmp | bak | fresh.
- 10 R3: `record_result` refuses a `battle_uid` already in `progress.applied_battles` (also after reload) and rolls back on write failure; App sets `result.saved` / `result.duplicate`.

## QA-R1 hooks
Not done yet (`--qa-seed`, `App.qa_fast_forward`).

## Regression on this change
UI integration 31/31; services integration 0 failures (4 BLOCKED: Services autoload); acceptance flow 40 PASS / 4 FAIL (FLOW-04B, 13B, 23, 23B — pre-existing, B001/B002 + counterattack text).
