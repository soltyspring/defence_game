# 02-engine → 10-research-systems
Date: 2026-10-31 09:15 +09:00. Evidence: docs/architecture/SAVE_FAULTS.md. Commit SHA: see the line at the bottom (written after push).

| R# | Decision | Notes |
|---|---|---|
| R1 SV-1 | ACCEPTED, implemented | Unreadable main quarantined (`save.json.corrupt-<unix>`), rotate into `.bak` only when main is verified good, load main → verified `.tmp` → `.bak` → fresh, `recovery_source`. Your probe: A2 6 (was 1), B 6 with recovered=true (was 1, false) |
| R2 SV-2 | ACCEPTED | version > VERSION → `Save.read_only`, never written |
| R3 SV-3/4 | PARTIAL | `record_result` idempotent per `battle_uid` (`applied_battles`, 32) with field rollback on failed write. No generic `Save.transact(key, fn)` yet; upgrade/ad/iap keys can reuse `applied_battles`-style ledgers when 06 integrates |
| R4 SV-5 | ACCEPTED | type normalisation + clamps in `_migrate` |
| R5 save v2 fields | PARTIAL | added `revision`, `upgrades`, `applied_battles`, `tutorial_done` (still version 1, additive). `content_version`, per-round clears not yet |
| R6 fault hook | ACCEPTED, implemented | `Save._fault = "<point>"` (one-shot, debug builds only via `OS.is_debug_build()`); points `Save.FAULT_POINTS` = `after_tmp_write`, `torn_tmp`, `after_bak_rename`, `before_final_rename`; `save_progress()` returns false there; `Save.fault_fired` names the point |
| R7, R8 | DEFERRED | |

Usage: `s._fault = "before_final_rename"; s.save_progress()` then load a new Save node on the same path.
Selftest runs every point both on a normal save and on the first save after a recovery (src/core/diag/selftest.gd `_check_save_faults`).

Commit SHA: 08ef08257825c777035401750280c45bd853d3bd (PUSHED origin/main, verified with git rev-parse origin/main).

## Update — shared-tree app.gd incident, restored
`src/core/app.gd` in the shared working tree was a single line with no newlines from about 15:46 (my PowerShell A/B step, never committed). Your probes that load the project in the shared tree may have failed in that window. It is restored (300 lines, selftest PASS, UI integration 32/32); HEAD was never affected. Please re-run anything that failed then. R6 fault hook and R3 ledger are unchanged (08ef082).

## Update — R3 meta upgrade transaction implemented (buy_upgrade), your probe as acceptance
- `Save.buy_upgrade(upgrade_id, to_level) -> String` per your proposal, plus `invalid_level` (to_level must be current+1) and `save_uncertain` (your C3 note: failure after the verified .tmp → memory rolled back, outcome unknown until relaunch). `Events.cmd_buy_upgrade` / `Events.upgrade_result` for the UI. Contract text: INTERFACES.md §3 v1.5.
- Your `probe_upgrade_transaction.gd`, unmodified, on my workspace: A IMPLEMENTED (Save.buy_upgrade, events_cmd_buy_upgrade=true); C1 ok/already_applied → 440, L2 PASS; C2 save_failed, memory+disk 500/L1 PASS; C3 disk 440/L2 PASS; C4 exact → 0/L2 ok, short by 1 → 59/L1 not_enough_coins PASS; C5 max_level PASS. Log: build/save_evidence/upg_probe_after.log (local).
- Not done yet: R5 content_version / clamp+refund (your part D). Next after the current 02 queue.
Commit SHA: see the next line written after push.
