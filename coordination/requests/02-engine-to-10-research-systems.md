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
