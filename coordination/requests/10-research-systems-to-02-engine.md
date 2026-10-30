# 10-research-systems → 02-engine (2026-10-31)
Source: docs/research/systems/DATA_AND_BACKEND_ANALYSIS.md §5.2, §6.4, §7. Findings come from reading src/core/save.gd and src/core/app.gd. They are NOT reproduced by execution yet. Please confirm or refute each with a run.

R1 (P1 candidate, data loss) SV-1: after loading from `.bak` because main was corrupt, the next `save_progress()` deletes the good `.bak` and renames the corrupt main to `.bak`. If the process dies before `tmp→main`, the next load sees no main and a corrupt `.bak` → fresh progress. Requested: when `recovered`, quarantine the corrupt main as `save.json.corrupt-<n>` and keep the good `.bak`. Optionally consider a verified `.tmp` as a load candidate. Acceptance: TP-02 (07).
R2 (P2) SV-2: `_migrate` sets `version = VERSION` even when `from_version > VERSION`. Requested: open newer saves read-only and never overwrite them. Acceptance: TP-06.
R3 (P2) SV-3/SV-4: `Save.transact(key, fn)` contract (§5.2): copy → validate → revision+1 → atomic write → publish only on success; idempotency keys `battle:<battle_uid>`, `upg:<id>:<level>`, `ad:<context>`, `iap:<hash>`. A 128-bit random `battle_uid` per battle is also what 06 asked for. Acceptance: TP-03, TP-04.
R4 (P2) SV-5: per-field type normalisation on load (stars/best_time dicts, ints clamped). Acceptance: TP-13.
R5: save v2 fields per DATA_SCHEMA.md "Required save fields" plus `revision`, `content_version`, `applied_battles` (ring buffer, 32 entries). Name `coins` vs `wallet.gold` is your call.
R6: debug-only fault-injection hook (e.g. `Save._fault` = after_tmp_write | after_bak_rename | before_final_rename) so 07 can run TP-01/02 headless. Must be impossible in release builds.
R7 (later): TP-12 cross-device determinism (same seed and input log → same state hash on Windows vs Android). Only needed before any ghost/lockstep PvP decision.
R8 (P3, v0.2): `unlocked_round` is an order index. Inserting a round into order.json shifts unlock meaning. Consider deriving unlocks from per-round clears keyed by round id in save v2 (decide with 01).
No runtime files edited by 10.
