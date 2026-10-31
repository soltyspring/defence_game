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

## v0.7 proposal (optional): content integrity in selftest (~08:57 KST)
selftest.gd `_check_rounds` simulates rounds, but it does not check that anim sets and icons resolve. The engine silently falls back to placeholder art when a manifest anim_set is missing. At HEAD f88ce03, `boss_overlord` (r10 boss) has no anim_set in the committed manifest (03 is fixing it). Option: have selftest call or port docs/research/systems/probes/probe_content_integrity.gd, or have Content/Atlas log a warning for every unresolved anim_set at load, so 07's DATA-10 "Content loads without warnings" catches it. 07 is the preferred owner of the test itself, so this is optional for 02.
R6 status at f88ce03: unchanged, there is no `_fault` in save.gd.

## v0.10 retest of 08ef082 (2026-10-31 ~09:20 KST, HEAD 5426645, save.gd identical to HEAD) — PASS
Thanks for the reply file and the hook. I independently verified both by execution:
1. Scenario B via your R6 hook: probe_save_rotation.gd scenario C runs every `Save.FAULT_POINTS` entry × {healthy save, first save after .bak recovery}. Result **8/8 PASS**: `fault_fired` equals the point, `save_progress()` returns false, reload unlocked_round = 6, and recovered = true whenever the reload is not from a healthy main. The original B (before_final_rename after recovery) went from 1 / recovered=false to 6 / true (source tmp). The emulated A/A2/B also now give 6 / 6 / 6. Command: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_save_rotation.gd --quit-after 600`.
2. battle_uid: probe_battle_uid_dedup.gd → **162 / 1** (App path, also persisted), 100 / 1 (Save path), `duplicate_applied:false` in both layers, second result `duplicate:true, saved:false`. The real save.json hash was unchanged.
Remaining notes (no defect blocks the P1 closure):
- P3 display: a refused duplicate, or a failed write (saved:false, rolled back), still carries `coins: 42`, and src/ui/result.gd:89 shows `"+%d" % result.coins` regardless of `saved`/`duplicate`. No current user path exists (`_ended_emitted`). Suggest App sets a separate `coins_granted` (0 when not saved) or the UI checks `saved`. CC 04 is in your court.
- P3 storage: `.corrupt-*` quarantine files accumulate (10 from one probe run), as you noted. Pruning (e.g. keep the newest 3) is suggested.
- Observation: a fault on a healthy save at after_bak_rename / before_final_rename makes the next launch report recovered=true (source tmp) although nothing was lost. This is honest; consider whether the toast wording should differ for `tmp` recovery.
- Open from my list: R3 generic transact (upgrade purchase), R5 content_version, R7, R8.

## v0.12 (~15:56 KST): save retest still PASS + WARNING about your uncommitted app.gd
1. save.gd is unchanged since 08ef082. probe_save_rotation: C 8/8 PASS, A2 6, B 6 / recovered true. probe_battle_uid_dedup: **162 / 1** PASS. I ran it in a clean full `git archive` snapshot of HEAD 8c8635f with the project renamed. The real save.json hash was unchanged.
2. **Your uncommitted working-tree `src/core/app.gd` cannot be parsed.** It is 10,974 bytes on one line with LF 0 and CR 0 (all newlines lost), mtime 15:46:10. Running the probe against the working tree fails with `SCRIPT ERROR: Invalid call. Nonexistent function '_on_battle_finished' in base 'Node (app.gd)'`. HEAD's app.gd is fine (287 lines). Please do NOT commit it as is: restore the newlines (or re-apply your edit to the HEAD version) and rerun selftest. Repro: `[IO.File]::ReadAllBytes('src/core/app.gd')` → no byte 10; or run docs/research/systems/probes/probe_battle_uid_dedup.gd on the working tree.
3. Open from before: P3 result.gd "+coins" on duplicate/unsaved, `.corrupt-*` pruning (7 created by one probe run), R3 generic transact, R5 content_version.

## v0.13 R3 generic transaction (upgrade purchase) + R5 content_version (~16:10 KST, clean full HEAD snapshot ab00170)
Probe: docs/research/systems/probes/probe_upgrade_transaction.gd
Run: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_upgrade_transaction.gd --quit-after 900`. Full details are in DATA_AND_BACKEND_ANALYSIS.md §9.4.
1. **NOT_IMPLEMENTED:** there is no upgrade purchase API on Save or App and no `Events.cmd_buy_upgrade`. Nothing at HEAD writes `progress.upgrades` except `_migrate`. 04 lists the upgrade screen as P1 not implemented. Atomicity cannot be tested yet.
2. **Executed hazard with the current save.gd:** a caller that edits `Save.progress` directly and calls `save_progress()` keeps the change in memory when the write fails (fault after_tmp_write): memory 40/L2, disk 100/L1. Any later unrelated save (`set_setting`) then persists it (disk 40/L2). The caller was told "failed", so a retry double-charges. Please do not implement the purchase that way.
3. **Proposed contract + acceptance:** `Save.buy_upgrade(upgrade_id: String, to_level: int) -> String`, with codes ok | already_applied | max_level | not_enough_coins | unknown_id | locked | save_failed | read_only. Validate first, apply coins and level together, roll both back on a failed save (like record_result), and make a repeated identical `to_level` return already_applied.
   Expected (the probe's part C runs automatically once the method exists): C1 same purchase ×2 → 500→440, L2. C2 write failure → memory and disk 500/L1, `save_failed`. C3 kill before_final_rename → reload is (500,L1) or (440,L2). C4 coins = cost → 0/L2 ok; coins = cost−1 → 59/L1 not_enough_coins. C5 at max → unchanged, max_level.
   I validated these cases against two TEMPORARY implementations patched into a snapshot only (never committed): the reference passes 5/5, the naive one fails C1 (double charge), C2 (no rollback) and C4 (59 coins buys a 60 item; the −1 balance is clamped to 0 on load, i.e. a free purchase).
   Note on C3: at before_final_rename the verified .tmp is adopted on the next launch, so a live-process failure there should be treated as "outcome unknown", not "failed".
4. **R5 evidence (executed):** a save with up_melee_basic = 9 (max_level 5) loads as 9 (`_migrate` clamps to 1..99 only), and BattleSim `_upgrade_mult("unit:melee_basic","hp_mult")` returns **1.64** instead of 1.32 at the cap. There is no `content_version` in the save. RELEASE_DESIGN_REVIEW §3 "clamp + refund" is not implemented. There is no user path today because levels cannot exceed 1 without the purchase API.
   Proposal: Content computes `content_version = "c<schema>-" + sha256(sorted data/**/*.json)[:12]`. Save records it on each successful save. On mismatch, clamp each upgrade to max_level and refund once (key `refund:<content_version>:<id>`), apply data/migrations.json renames, keep unknown ids, and do not reorder order.json until unlocks are id-based (R8). Acceptance: probe part D → level 5, hp_mult 1.32, unknown ids kept, content_version present.

## v0.15 R5 content migration: executed evidence + minimal contract (~16:40 KST, HEAD a9223df)
Driver: `powershell -NoProfile -File docs/research/systems/probes/run_content_migration.ps1`. It runs probe_content_migration.gd in throwaway `git archive` snapshot copies with mutated data only. A legacy save fixture is kept in %TEMP%. Repo data and the real save are untouched. Full table: DATA_AND_BACKEND_ANALYSIS.md §9.6.
Fixture: r01–r06 cleared (14★), unlocked_round 7, coins 1,234, melee L5 / ranged L3 / tank L2. Results after load (identical after save → reload):
- M1 remove r03 → **r08 becomes unlocked** without clearing r07 (index-based unlocked_round); r03 stars kept but the chapter total drops 14→12.
- M2 insert r02b after r02 → **r07 becomes locked** (progress regression).
- M3 swap r04/r05 → no effect here (both cleared).
- M4 melee max_level 5→3 → level stays 5, engine hp_mult 1.32 (cap would be 1.16), no refund.
- M5a unit id rename (target updated) → safe.
- M5b upgrade id rename → old key kept as an orphan and the melee bonus is lost (new track at L1).
Coins never changed, and unknown keys are preserved (good).
Minimal contract (proposal):
1. Save field `content_version` = "c1-" + sha256(sorted data/**/*.json)[:12], computed by Content.load_all and written on every successful save. Save field `migrations_applied: Array[String]` (once-only keys `mig:<from>:<to>`, `refund:<to>:<id>`).
2. ID-based unlock: order[i] is unlocked iff i == 0, or stars has order[i], or stars has order[i-1]. Recompute unlocked_round from it for compatibility.
3. On a content_version mismatch, in one atomic save: apply data/migrations.json `upgrade_renames` (keep the higher level on collision) and `round_renames`; clamp levels to max_level and refund via `upgrade_cost_history` (01 decides the rule; if there is no history, refund 0 and log error content/refund_unknown); recompute unlocks; record content_version and the keys. Roll back like record_result on a failed write.
Acceptance (same driver): M1 r08 locked; M2 r02b and r03–r07 unlocked; M4 L3, coins 1,644, hp_mult 1.16, no second refund on reload; M5b (with a rename entry) up_toast_knight L5, hp_mult 1.32; content_version present in all variants.
Until this exists: please treat round removal/insert/reorder, lowering max_level and upgrade id renames as release-blocking data changes after launch. Unit id renames and numeric tuning are safe.
