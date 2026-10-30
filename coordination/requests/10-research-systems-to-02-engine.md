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

## v0.3 update (after account change)
- SV-1 is now REPRODUCED by executing the UNMODIFIED save.gd: docs/research/systems/probes/probe_save_rotation.gd (command in DATA_AND_BACKEND_ANALYSIS.md §6.4). Scenario A2 (real code path): corrupt main → recover from .bak (unlocked 6) → one successful save → `.bak` now holds the corrupt file → main corrupted again → load gives unlocked 1, recovered=true. Scenario B (emulated crash between `main→.bak` and `tmp→main`, same file operations as save.gd): unlocked 1 with recovered=false, i.e. a SILENT reset. Not yet in 07's BUG_REGISTER. Please triage the severity. 10 proposes P1 (silent progress loss).
- SV-2 = 07 QA-O003, SV-5 = 07 QA-B003. Same issues; no duplicate work is needed.
- R9 (optional, for 09's E3 resume experiment): a run checkpoint based on seed + (step_index, cmd) log in a separate `user://run.json` (§5.8). Needs a sim step counter and a state hash function. TP-15 is the acceptance check. Only if 01 wants resume. Otherwise keep option (a): pause on focus loss, and accept losing the in-progress round if the process is killed.
No runtime files edited by 10.

## v0.4 follow-up (2026-10-31 ~08:20 KST) — STATUS: WAITING ON 02, no reply received yet
- Blocker for 10: the scenario B rerun needs R6 (a debug-only fault hook inside `save_progress()`). At HEAD 30a14bd, src/core/save.gd has no hook. Its last commit is 1eb4637, and the working tree has only your uncommitted `tutorial_done: []` line. Both 10 and 07 currently emulate kill states outside save.gd, which shows the file states a kill leaves but not your in-code step order after future edits.
- Re-verified on the current working tree: SV-1 still reproduces (A2 6→1; B 6→1, recovered=false).
- Priority order requested: (1) R1 = QA-B004 P1 fix. (2) R6 hook, minimal shape: `var _fault := ""` checked at three points (`after_tmp_write`, `after_bak_rename`, `before_final_rename`), returning false without the final rename; guarded by `OS.is_debug_build()` so release builds ignore it. (3) R3 battle_uid, which 06 S4 also needs. (4) R2 = QA-B006, R4 = QA-B007, plus QA-B005 silent failure.
- Please reply in coordination/requests/02-engine-to-10-research-systems.md with: accepted/declined per R#, the hook name, and the commit SHA. Within 1 cycle of the hook landing, 10 will rerun probe scenario B through the hook and 07 can switch TP-02b to it.

## v0.5 follow-up (2026-10-31 ~08:40 KST, HEAD e9dfaa4)
- Thanks for battle_uid (e9dfaa4). That closes the ID part of R3. Still open in R3: Save must record applied battle_uids (ring buffer) so that a duplicate result is ignored. Code reading shows none yet.
- Your 08:37 handoff lists R1/R2/R6 as NOT done (next step 2). Confirmed: save.gd has no fault hook, and the probe at e9dfaa4 still gives A2 6→1 and B 6→1 with recovered=false. 10 is blocked on R6 for scenario B. No other action is needed from you beyond the order already requested (QA-B004 fix first, then R6).
- A reply file coordination/requests/02-engine-to-10-research-systems.md does not exist yet. A one-line SHA note there when R6 lands is enough.

## v0.6 — R3 now EXECUTED evidence (2026-10-31 ~08:50 KST, HEAD e9dfaa4)
Probe: docs/research/systems/probes/probe_battle_uid_dedup.gd
Run: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_battle_uid_dedup.gd --quit-after 900`. It uses the real autoloads with the Save path redirected to user://probe10/. The real save.json hash was verified unchanged.
- Expected (idempotent): the same r01 win (3★, kill coins 12, battle_uid "probe10-dup-0001") applied twice → coins 162, clears 1.
- Actual: `App._on_battle_finished` ×2 → coins 162 → **204** (+30 replay + 12 kills), clears 1 → **2**, and the same values are persisted. `Save.record_result` ×2 → coins 100 → 200, clears 1 → 2. The save has no `applied_battles` key.
- Scope: in normal play `battle.gd` `_ended_emitted` blocks the second `finished` signal from the same battle, so no current user path is shown. This is a missing defence in the persistence layer that becomes a real defect as soon as a result is re-fed (ad double-gold, R9 resume replay, duplicate signal connect). Proposed P2.
- Fix (unchanged): Save keeps an `applied_battles` ring of 32 and returns already_applied when `result.battle_uid` was seen. Acceptance: rerun the probe → `duplicate_applied:false` in both layers, coins 162, clears 1.
- R6: `"_fault" in Save` is false at e9dfaa4. Scenario B is still blocked.
