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

## v0.17 save atomicity check before buy_upgrade (~17:05 KST, HEAD c15e43a, save.gd last changed 08ef082) — read-only, no device test
Probe: docs/research/systems/probes/probe_save_load_cases.gd. Run inside a renamed `git archive` snapshot with `--quit-after 600`; it has a 60 s watchdog and actually took 1.6 s. Table in DATA_AND_BACKEND_ANALYSIS.md §9.8.
- PASS, no progress lost: zero-byte main, truncated main, stale checksum, payload not an object, missing main with a newer verified .tmp (adopted), torn .tmp (falls back to .bak), oversize >2 MiB (falls back to .bak), envelope-less JSON, legacy save without a version field (migrated), UTF-8 BOM (loads). Payload version 99 → read_only, save refused, bytes unchanged.
- Observations (P3, your call):
  (a) only the payload `version` is read; the envelope `version` is write-only;
  (b) after L07 (all three corrupt → fresh, recovered=true) the corrupt .bak survives the first save until the next rotation;
  (c) a torn .tmp is left in place, not quarantined, and the next save overwrites it;
  (d) the 2 MiB guard sends a legitimately large save to .bak (current saves are a few KB).
- Android partial-write risk (source reading, UNKNOWN on device): Godot master FileAccessUnix::flush() is fflush() only and there is no fsync in file_access_unix.cpp. Android's AtomicFile syncs before rename. A process kill is covered by the rename order. A power loss may leave the new main empty or stale, and then the load chain falls back to .bak, so the expected loss is the last save or two. I could not find a GDScript fsync. Please confirm the FileAccess implementation used for user:// on Android in 4.7.2 if you can.
Additional acceptance cases for buy_upgrade, beyond C1–C5:
- C6: kill at each of the 4 FAULT_POINTS during a purchase × {healthy, first save after recovery} → reload always shows the matching (coins, level) pair, before or after the purchase, never mixed.
- C7: read_only save → `read_only` returned, memory and bytes unchanged.
- C8: first purchase after a .bak/.tmp recovery → .bak afterwards is not the corrupt file, and the purchase persists.
- C9: coins never negative in memory or on disk (balance = cost, cost−1, near the cap).
- C10: on `save_failed`, no success UI; at before_final_rename, re-read Save state ("outcome unknown").
- C11: double tap on the same to_level charges once.
- C12: a failed purchase followed by a successful record_result in the same session → disk has the result and not the purchase, and each rollback touches only its own fields.
- C13: purchase followed by app pause → the extra save does not double-apply (device test still pending).

## v0.18 durability verdict on our exact engine (4.7.2-stable = commit ed1daf0bf001b6…, same as `--version`) (~17:20 KST)
Source citations with line numbers are in DATA_AND_BACKEND_ANALYSIS.md §9.9 (S23). Device test NOT done.
- Q1 sync before rename: **No.** FileAccessUnix::flush = fflush (file_access_unix.cpp L329–332), _close = fclose (L198–220), DirAccessUnix::rename = ::rename (dir_access_unix.cpp L420). There are 0 fsync/fdatasync hits in the 8 files read.
- Q2 Android user://: **FileAccessUnix / DirAccessUnix** (os_android.cpp L120, L133; user:// → ACCESS_USERDATA in core/io/file_access.cpp L72–73).
- Q3 GDScript: **flush yes (it is fflush, not durable), fsync no.** OS.set_use_file_access_save_and_swap only adds temp+rename on close without sync; it is off by default and unused in src. Do not enable it.
Your current order (flush/close → verify → rotate only a good main → rename) needs no change. Minimal proposals (your decision):
- A. Time-spaced .bak rotation: if the last rotation was less than T s ago (provisional; 08/02 pick T), keep .bak, delete main, then rename tmp→main. Main-missing plus a verified tmp is already handled by the load order (L05). This keeps .bak at least T s old, so it is more likely already written back when power is lost. Acceptance: a second save within T leaves .bak bytes equal to the pre-first-save main; after T it rotates; R6 8/8 and the 14 load cases still pass.
- B. Coalesce back-to-back saves (record_result followed immediately by the PAUSED save).
- C. (Not recommended now) a native fsync plugin (Android AtomicFile style).
Power-loss outcome remains an inference until a device test: two saves inside the kernel writeback window could leave both main and .bak unwritten.

## v0.18 addendum: buy_upgrade (4d77225) retest — C1–C5 PASS (clean full snapshot of HEAD 0478edd)
Command: probe_upgrade_transaction.gd. Results:
- C1: `ok` then `already_applied`, 440/L2.
- C2 (after_tmp_write): `save_failed`, memory and disk 500/L1.
- C3 (before_final_rename): reload 440/L2, a consistent pair.
- C4: exact coins → ok 0/L2; one short → not_enough_coins 59/L1.
- C5: max_level.
Still open: R5 part D (level 9 kept, hp ×1.64, no content_version). C6–C13 are not automated yet; 10 will extend the probe next.

## v0.19 buy_upgrade C1–C13: all PASS at clean origin/main ed7218a (+1 semantic finding) (~17:20 KST)
Command (inside a renamed `git archive` snapshot, after `--import`): `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path <snapshot> -s res://docs/research/systems/probes/probe_upgrade_transaction.gd --quit-after 900`. It has a 120 s watchdog and ran in 2.0 s; the real save.json hash was unchanged. Full table: DATA_AND_BACKEND_ANALYSIS.md §9.10.
PASS: C1–C5, C5b locked, C6 (8/8 fault cases), C7 read_only, C8 after recovery, C9 never negative, C10 App signal + save_failed toast, C11 double tap, C12 cross rollback, C13 pause after purchase (desktop emulation via App._notification; no device test).
F1 (P3, your call): in the after-recovery state (main quarantined, main missing), `_fault = "after_tmp_write"` makes buy_upgrade return **save_failed**, yet the complete .tmp stays on disk and is adopted on the next load, so the purchase is applied (reload 440/L2).
- Repro: write a corrupt main and a valid .bak with 500 coins → load_progress → `_fault = "after_tmp_write"` → `buy_upgrade("up_melee_basic", 2)`.
- Expected per the `UPG_SAVE_FAILED` comment: disk stays 500/L1. Actual: 440/L2 with source tmp.
- Fix options: (a) return save_uncertain whenever a full .tmp was written while main is missing; or (b) remove the .tmp before returning save_failed. The same path probably affects the record_result rollback.
- No coins are lost without the item.
Still failing: R5 part D (level 9 kept, hp ×1.64, no content_version). Proposed to 01 as a temporary rule: no max_level decrease after launch.

## v0.20 (~17:35 KST): F1 still open (waiting)
save.gd is unchanged since 4d77225 and your reply file has no F1 entry. I will rerun C6 `after_tmp_write/after_recovery` when a fix lands; expected disk 500/L1, or the code `save_uncertain`. Extra context from the screen check (§9.11): the 04 panel shows "저장하지 못했습니다. 골드와 레벨은 그대로입니다" for save_failed. That is true in the healthy state but false in the F1 state, where the purchase appears after restart.

## v0.22 (~17:55 KST): R5 refund source + competitor policy check (no Godot run)
1. F1: read 4b5926d (`last_failure_uncertain` = main unreadable AND valid .tmp, the same order as load_progress). The logic matches what I expected. I have NOT rerun C6 independently yet because this task runs no Godot. I will rerun it in a clean snapshot after 18:30 KST.
2. Your R5 PROVISIONAL refund "sum of current costs of removed levels": when 01 lowers max_level, the removed levels' entries also leave meta.json `costs`, so there is nothing to sum. 01's D26 says "coins actually paid". Proposed contract (01 decides; see 10→01 v0.22 #1):
   - (i) On `buy_upgrade` success, write `upgrade_paid[id][str(level)] = cost` in the same atomic save (covered by the checksum, normalised on load like other ints).
   - (ii) For levels without a record, use `migrations.json` `retired_costs[id]` (the cost list before the change). If neither exists, cap the level without a refund and log it (never invent coins).
3. Migration once per content_version: compute → validate → one atomic save; idempotency key `refund:<content_version>:<id>`. On save_failed/save_uncertain, retry on the next launch, like buy_upgrade. Never lower coins, and never delete unknown ids.
4. Data errors that over-granted coins: no clawback (no ledger offline). This is proposed to 01 as a rule; nothing for you to build.
5. Keep `read_only` for a newer save version. No maintenance or forced update is needed (offline).
Acceptance after your R5 lands (I rerun after 18:30): run_content_migration.ps1 M1–M5b and probe part D, plus one new case: a lowered max_level with a recorded paid cost refunds exactly that recorded sum once, and a second launch refunds 0.
Competitor basis (§9.13): both companies' public terms keep the right to change data by patch without restoring it, and to reclaim mis-grants. No dated case was reachable.

## v0.23 (~18:05 KST): refund source formats A/B + tests for R5 (static only, no Godot)
Full text: DATA_AND_BACKEND_ANALYSIS.md §9.14. 01 decides A, B or AB. I recommend AB: A first, B as the fallback.
- A (yours), extra payload keys; the envelope is unchanged and VERSION stays 1, because `_migrate` fills missing keys from `fresh()`:
  `"upgrade_paid": {"up_siege": {"2": 90, "3": 150, "4": 230, "5": 350}}, "migrations_applied": ["m001_siege_cap4"], "content_version": "c1-…"`
  - Keys are the level reached as a string "2".."99"; values are int coins paid ≥ 0. Write them only in the `buy_upgrade` success path, inside the same `save_progress()` as coins and level, and erase them on rollback.
  - `_migrate` drops: non-dict per id, keys that are not ints 2..99 or are above the current level, values that are not ints or are negative (the string "60" too, like stars). Values are clamped to the coins cap, and empty dicts are removed. `migrations_applied` keeps strings only, deduplicated.
- B (01's `data/migrations.json`): `{"schema_version":1,"migrations":[{"id":"m001_siege_cap4","upgrade_renames":{},"round_renames":{},"upgrade_caps":{"up_siege":{"max_level":4,"retired_costs":[90,150,230,260]}},"retired_upgrades":{"up_worker":{"retired_costs":[90,150,180]}}}]}`.
  - Append-only; array order is the apply order. Apply renames → caps → retired_upgrades.
  - Per removed level k: A record → else `retired_costs[k-2]` → else 0 plus a `refund_unknown` log.
  - A retired upgrade is refunded and then removed from `upgrades` and `upgrade_paid`.
  - Clamp coins once, append the id to `migrations_applied`, then do ONE atomic save. Idempotency comes from `migrations_applied`; do not put a data hash inside migrations.json (it would be circular).
- Your PROVISIONAL "sum of current costs" has no entries left after a max_level cut. Use `retired_costs` from the migration entry instead.
- Static reference model: `python docs/research/systems/probes/refund_reference.py --rev origin/main` gives 10/10 PASS, and every second run changes nothing. Key numbers: R1 cap 5→4 with a record → 1,234 + 260 = 1,494. R2 (bought L5 at the pre-D26 price 350) → A gives 1,584, B gives 1,494. R6 retire up_worker L4 → 1,654. R8 chain → 1,914.
- Engine acceptance, which I run with Godot after your R5 lands (after 18:30). All UNCONFIRMED now:
  - E1 buy L2 → disk 440 / L2 / paid "2" = 60.
  - E2 after_tmp_write healthy → save_failed, and the record is absent on disk and in memory.
  - E3 after_bak_rename → save_uncertain, and the record appears together with the level after reload.
  - E4 junk `upgrade_paid` → {}.
  - E5 M4 → L3, coins 1,584.
  - E6 and E7: a fault during the migration save → refunded once only.
  - E8 read_only save → no migration and no write.
- Fix the expected value you quoted in d8dd1a8: M4 is now **1,584** (1,234 + 160 + 190 at current costs), not 1,644 (old costs 160 + 250). hp at L3 = 1.30 and M5b = 1.60 with D27 per_level 0.15. This is data arithmetic, not yet run.
- F1 independent C6 rerun: after 18:30 in a clean snapshot (unconfirmed now).

## v0.24 (~18:50 KST): F1 independently confirmed; R5 still waiting
- Clean full `git archive` snapshot of HEAD b4b33a7 (autoloads kept, project renamed; save.gd = 4b5926d). probe_upgrade_transaction: **C6 8/8 PASS**, plus C1–C5, C5b and C7–C13 PASS.
  - F1 row `after_tmp_write/after_recovery` → `save_uncertain`, memory 500/L1, disk after reload 440/L2.
  - `after_tmp_write/healthy` and `torn_tmp/*` → `save_failed` with disk 500/L1.
  - So `save_failed` now always means "disk unchanged". **F1 closed** from my side.
- Same snapshot regression: probe_save_rotation C 8/8 PASS (A2 6); probe_battle_uid_dedup 162 / 1 PASS. The real save.json hash was unchanged.
- R5: `git grep content_version -- src` = 0 at b4b33a7. run_content_migration M1/M2/M4/M5b and E1–E8 are NOT run (waiting).
  - Part D now shows level 9 kept and hp ×**2.20** (D27 per_level 0.15; cap value 1.60), with no content_version.
  - Expected values when you land it: M4 L3 / coins 1,584 / hp 1.30, M5b 1.60, plus E1–E8 (§9.14).

## v0.25 (~19:00 KST): R5 (7f2886c) acceptance on a clean HEAD f41fd12 snapshot — 1 new defect (F2)
Source: DATA_AND_BACKEND_ANALYSIS.md §9.16 (3). New probe: docs/research/systems/probes/probe_r5_cases.gd. Data changes are emulated in memory on the Content autoload, and the save goes to an isolated path.
- run_content_migration.ps1: everything matches the corrected expectations.
  - M1: r08 locked, r03 stars kept.
  - M2: r02b and r03–r07 open.
  - M3, M5a: unchanged.
  - **M4: L3 / 1,584 / hp 1.30**, with no second refund on reload.
  - **M5b: up_toast_knight L5 / 1.60**, no orphan.
  - content_version is present in every variant.
- probe_r5_cases: 7/9 PASS.
  - E1 stamp on buy, E4j junk snapshot (no crash), E5 cap 5→3 refunded once: PASS.
  - E6 after_tmp_write: disk unchanged, retried once on the next load: PASS.
  - E7 before_final_rename: .tmp adopted, no second refund: PASS.
  - E8 read_only: no migration, bytes unchanged: PASS.
  - DL legacy L9 → L5, refund 0 with a refund_unknown warning: PASS.
- **F2 (P2): a failed migration save is lost after any later ordinary save in the same session.**
  - Repro: make a save under data A with melee L5, load it under data B (max_level 3) with `_fault = after_tmp_write`, clear the fault, call `save_progress()` once (any settings, result or buy save), then reload.
  - Result: disk shows 1,234 / L5 with content_version = B. The next load sees "same version" and never migrates, so a level above max stays and no refund is made.
  - With `before_final_rename` (F2b) it is worse: the ordinary save overwrites the migrated .tmp.
  - Cause: after the rollback (`progress = before`), `_stamp_content()` in the next save stamps the NEW version on un-migrated data.
  - Fix options: (a) set `_migration_pending` when the migration save fails, and while it is set `_stamp_content()` keeps the old content_version and snapshot (the next load retries); or (b) at the start of `save_progress()`, re-run the migration if one is pending.
  - Acceptance: rerun probe_r5_cases F2a/F2b; expected 1,584 / L3 after reload.
- Differences from 01's D26 (not defects while your rules are PROVISIONAL; 01 decides):
  - R2m: a price change (L5 250→190) followed by a cap refunds the snapshot price 350, not the 410 actually paid. The snapshot is B-like, but automatic, so 01 never copies costs by hand.
  - R6r: an upgrade removed from meta.json (no same-target replacement) is kept as an unknown id: L4 stays and the refund is 0 (D26 says +420).
- P3:
  - String prices in a junk snapshot refund 0 silently, without the refund_unknown warning.
  - The old part D shape (same content_version, L9 → hp 2.20) only happens by editing the file; clamping to max_level in `_migrate` would close it.
- Regression in the same snapshot: transaction C1–C13/C5b PASS (C6 8/8), rotation C 8/8, dedup 162/1, 14 load cases the same as v0.17.

## v0.26 (~19:12 KST): boot-time rewrite of the real save by every test run (P1) + F2 still waiting
Evidence: DATA_AND_BACKEND_ANALYSIS.md §9.17. Experiments X1–X3 used a private APPDATA, an unrenamed HEAD snapshot and a no-op `-s` script:
- X1: a boot on a save with an older content_version rewrites it (revision 5→6, new content_version, new .bak), even though nothing needed migrating (`prev_cv != ""` always saves).
- X2: the same save booted again is not written.
- X3: with edited data (melee max 3), a no-op boot clamps L5→L3 and refunds 350.
So every Godot run on the shared tree, or on an unrenamed snapshot, rewrites the real `%APPDATA%\Godot\app_userdata\Lane Defence\save.json`. With in-progress data edits it applies that data's caps for good. The real save.json changed at 18:47, 18:50, 19:06 and 19:07 today.
Requests (your files):
1. Run instructions in `src/core/diag/selftest.gd` line 3, `pressure_cue_probe.gd` line 4, `passive_probe.gd` line 3 and `wave_clear_probe.gd` line 3: use a private APPDATA, via `& docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @('--headless','--path','.','-s','res://src/core/diag/selftest.gd')` or `$env:APPDATA=<private>` for that process.
2. Optional engine guard (your decision): when the main loop is a `-s`/`--script` SceneTree, or the user args contain `--isolated-save`, Save must not rewrite the default `user://save.json` during `_ready()`. That is, skip `_apply_content_migration` writes, or point the default path to `user://test_boot_save.json`. Cost: R5 checks must then run in a private folder, which they already should.
3. Optional: when nothing changed (`prev_cv != cur_cv` but `changed == false`), consider stamping on the next normal save instead of writing during load. That removes X1 for the common case.
F2: save.gd is still 7f2886c, so I am waiting. When it lands I rerun probe_r5_cases F2a/F2b and expect 9/9.

## v0.27 (~19:20 KST): keep a pre-migration backup + emit a migration notice (P1); F2 still waiting
Evidence: DATA_AND_BACKEND_ANALYSIS.md §9.18 (2). Real boots, private APPDATA; v2 caps melee/ranged at 3 and removes up_worker.
- On the v2 first boot the only pre-update copy is `.bak` (rev 11, v1 state).
- It is overwritten by the next ordinary save (S3), and also by a v1 "rollback" boot (S4b), because that boot migrates and rotates again.
- No signal or toast tells the player anything happened.
Concrete defenses (your files; I did not edit them):
1. Pre-migration backup that normal saves never rotate. In `_apply_content_migration()`, before `save_progress()` on a migration that changes levels or coins, copy the current main to `user://save.pre-<old_content_version>.json`. Keep the newest 2 and delete older ones.
   - Acceptance: after S2 and S3 a file with the S1 payload still exists, and a v1 rollback boot does not delete it.
2. Notice data: keep the last migration summary (e.g. `Save.last_migration = {"from": prev_cv, "to": cur_cv, "clamped": {id: [from, to]}, "refunded": coins, "dormant": [ids]}`).
   - Let App emit `Events.toast("content_migrated", {...})`, or a menu notice, once after boot.
   - 01 owns the text (proposed key `notice.content_migrated`); 04 owns the display, since menus show no toasts today.
3. Do not write during load when nothing changed (X1). This also stops the downgrade boot from destroying the pre-update `.bak` when no clamp is needed.
4. After 01 decides retired upgrades: today they are kept dormant with no refund (R6r, S2). Implement 01's choice.
5. F2 (P2): save.gd is still 7f2886c. I will rerun probe_r5_cases F2a/F2b when it lands (expect 9/9).

## v0.28 (~20:15 KST): watch result for your runs + F2 still waiting
- 19:41–20:11 (read-only watch, §9.19): your `base_damage_probe.gd` (19:41, 20:05, 20:06) and `selftest.gd` (19:42, `--path .`) did not touch the real user folder. The selftest.gd run instruction now mentions APPDATA (eceb9f4). Thanks.
- F2: save.gd is still 7f2886c; probe_r5_cases F2a/F2b rerun is waiting.
- P3: Save never prunes `.corrupt-*`. 07's TP-13 left 19 × 50 MiB quarantine copies (996 MB) in the real folder. A cap (keep newest N per base name) in save.gd would bound this for players too.

## v0.29 (~23:35 KST): eceb9f4 rerun PASS; content_version depends on line endings (P3); F2/X1 still waiting
- Your 20:25 request: clean isolated full snapshot 29d31be (same src/data as 07b90c5).
  - probe_upgrade_transaction: C1–C13 and C5b PASS, **C6 8/8**.
  - probe_battle_uid_dedup: **162 / 1**.
  - Battle and save behaviour are unchanged by D29 (off in data).
- **P3, new:** `Content._compute_content_version` hashes on-disk bytes, so the value depends on the checkout's line endings. Static re-implementation `docs/research/systems/probes/content_version.py`: data 7b93d1f is LF `c1-a7b265ce4f6f` but CRLF `c1-ea9c929ba40e`. The CRLF value is the one Godot reported, because this PC has `core.autocrlf=true`, so working trees and `git archive` copies are CRLF.
  - If one release is built from a CRLF checkout and the next from LF (CI or another PC), every player's save is treated as "data changed" although nothing changed. It is rewritten at boot (X1), unlocks are recomputed, and `.bak` rotates, so the pre-update copy is lost (§9.18).
  - Options: (a) strip `\r` before hashing, or hash canonical parsed JSON; (b) a build rule that releases are exported only from one line-ending mode. I prefer (a). Your call.
- Real-folder canary: the real save.json is still dated 19:35:09 (content_version = d09d740 CRLF). No non-isolated boot of the current data has happened since 19:37. This check depends on X1 rewriting; keep that in mind when you remove X1.
- F2/X1/D32/backup: save.gd is still 7f2886c. I will rerun probe_r5_cases F2a/F2b and the update scenario inside `heavy_run.ps1`, one at a time, when it lands.

## v0.30 (~23:55 KST): line endings vs content_version — measured; recommendation: strip \r before hashing (your decision)
Full evidence: DATA_AND_BACKEND_ANALYSIS.md §9.21. One heavy_run (`10-eol-update-scenario`), private APPDATA, HEAD 3e355a8 (content.gd/save.gd 7f2886c).
1. Same commit, two checkouts. The engine values come from your real `_compute_content_version` (as reported by the booted Content autoload); the static re-implementation gives identical values.
   - CRLF data: **c1-1a1d45c2fd91**.
   - LF data: **c1-e8790a4f2e85**.
2. Release bytes: both 04 APKs (`build/qa/apk_q4probe` 17:36 and `apk_head` 09:03) store data as `assets/data/**.json`, 21 files, all CRLF.
   - The 17:36 APK's bytes hash to exactly a262640's CRLF value (c1-bfe92b11d6e3).
   - So exports from this PC's `git archive` (core.autocrlf=true) carry CRLF.
   - This PC's working tree data is LF today (`git ls-files --eol`), so dev runs (`--path .`) and exports already disagree.
   - 06's AAB is deleted after each run, so I could not read it.
3. Update reproduced (desktop, real boots): release N CRLF → N+1 LF with the same data.
   - The first boot rewrites the save (rev 11→12), stamps the LF value and rotates `.bak` (= N state).
   - Levels, coins and unlocks are unchanged, `migration_log` is empty and there is no toast.
   - The second boot does not write. Going back to CRLF rewrites again (rev 13).
   - Cause: X1 (save during load although nothing changed). Device not tested.
4. Recommendation, one place: in `content.gd`, drop byte 13 from each file's bytes before `h.update`.
   - Why not `.gitattributes eol=lf`: it only fixes git checkouts and archives. It does not cover PowerShell-written JSON (pwsh 7 `ConvertTo-Json` writes CRLF; tested), exports straight from a working tree, or another machine's settings.
   - JSON cannot contain a raw CR inside strings, so meaning is unchanged.
   - Do it before the first release: now it changes only dev saves once; after launch the change itself would trigger E2 for every player.
   - Also fix X1, and tie the pre-migration backup and the `content_migrated` notice to actual level/coin changes, not to a version change alone.
   - When you change the hash, tell me and I will update `probes/content_version.py` and `userdata_canary.ps1` to match.
F2/X1: save.gd is still 7f2886c. The rerun is waiting.

## v0.31 (~00:35 KST): compatibility cases for a normalised content_version, measured BEFORE your change + acceptance AC1–AC9
Full table: DATA_AND_BACKEND_ANALYSIS.md §9.22; step log in docs/research/systems/evidence/norm_hash_compat_20261101/steps.txt.
Method: I did not edit your code. The normalised hash (drop byte 13 before `h.update`, content.gd line 77) existed only in throwaway snapshot copies. One heavy_run, real boots, private APPDATA, HEAD 1f34d87 (content.gd/save.gd 7f2886c).
- The normalised engine value is identical for CRLF and LF data (c1-989c3422c910), and equals the static norm value and today's LF raw value. So saves stamped by LF builds (06's LF AAB, working-tree runs) are unaffected; only CRLF-stamped saves change once.
- N2, first boot of the normalised build on a CRLF-stamped save: exactly 1 write. Levels, coins and unlocks unchanged, empty migration_log, no notice; `.bak` is byte-identical to the pre-update main. N3, the next boot: no write.
- **N4, line-endings-only build: no write.** This fixes §9.21 E2.
- N5, a non-cap value change: 1 write, no refund. N6, cap 5→3: refund +350 once; N7, next boot: no second refund. No notice anywhere.
- **Remaining attack, N8:** a formatting-only data change (same values, new indentation) still counts as "changed". X1 rewrites, and `.bak` rotation deletes the only pre-cap (L5) copy. N9, rollback build: rewrites, no level restore.
Acceptance I will run after your change (one heavy_run; all UNCONFIRMED now):
- AC1: CRLF and LF engine values are equal, and equal `content_version.py`'s normalised value.
- AC2: a raw-CRLF save on the first normalised boot keeps levels, coins, stars and unlocks, with no log and no notice. With X1 fixed: file bytes unchanged. Without it: exactly 1 write with `.bak` = previous main.
- AC3: the next boot leaves bytes unchanged.
- AC4: a CRLF↔LF-only build leaves bytes and rev unchanged.
- AC5: a non-cap value change gives no refund and no notice, and with X1 fixed no write during load.
- AC6: a cap lowered gives a paid-amount refund once (D32), 0 on the next boot, the notice once, and `save.pre-<old>.json` written.
- AC7: after AC6, a formatting-only build, two ordinary saves and a rollback boot all leave `save.pre-<old>.json` intact (= pre-migration main), with no notice and no refund. With X1 fixed: no load writes.
- AC8: rollback build: no crash, no level restore (as designed), no load write unless something needs clamping.
- AC9: an APK/AAB with the normalised code: packed-bytes norm value = repo value, and the same value on a device or emulator. Real APK/AAB behaviour is NOT verified by me: no install, no device boot.
Recommended order: normalisation + X1 in one commit, before release. Then AC2 costs 0 writes. Canonical-JSON hashing for N8 is optional if X1 + AC7 hold.
Today the build paths disagree: 06 AAB is LF-pinned (4bf8f74) and 04's `build_android_debug.ps1` is CRLF. Until normalisation lands, shipping from both paths would trigger §9.21 E2 for every player.
F2/X1: save.gd is still 7f2886c.

## v0.32 (~02:50 KST): 52f9fa3 re-verified — 8 of 9 acceptance items met; 1 FAIL (AC1, normalisation), AC9 unverified
Evidence: DATA_AND_BACKEND_ANALYSIS.md §9.24, docs/research/systems/evidence/save_d32_verify_20261101/results.txt. Each run: heavy_run, clean archive copy, private APPDATA; the real save was unchanged.
- (a) probe_r5_cases **9/9 PASS** (F2a/F2b fixed). R2m now refunds the paid 410 and R6r retires +420, both matching D32. probe_upgrade_transaction C1–C13 PASS, C6 8/8.
- (b) v0.27 scenario S1–S4b:
  - Retire + refund (worker +420) and paid refunds (+350/+160) work.
  - `save.pre-<old cv>.json` = the pre-update file, kept through an ordinary save and both rollback boots.
  - Rollback boots no longer write (X1).
  - `migration_notice` is stored and cleared by ack.
- (c) run_content_migration: M1/M2/M4 (1,584 / 1.30)/M5b (1.60) all match.
- (d) AC1–AC9 against your real code (builds differ only in data bytes):
  - **AC1 FAIL.** Repro: export the same commit with `git -c core.autocrlf=true archive` and `-c core.autocrlf=false archive`, boot each (any probe that prints `Content.content_version`).
    - Got: CRLF `c1-40bde75d24c2`, LF `c1-989c3422c910`.
    - Pass criterion: equal values, also equal to `python docs/research/systems/probes/content_version.py <rev>`'s `lf` field.
    - Cause: content.gd is still 7f2886c (no `\r` strip before `h.update`).
    - Impact now that X1 is in: no writes or refunds result from it (AC2/AC4 PASS). But backup file names, notice `from/to` and `refund:<cv>` keys differ per build path. One line fixes it; please do it before release.
  - AC2–AC8 **PASS** (table in §9.24). AC2 was measured on the closest available transition (CRLF→LF build), because no normalised build exists yet.
  - **AC9 UNVERIFIED:** I did not build, install or boot an APK/AAB with 52f9fa3.
- Not covered by my headless runs: `Events.content_migrated` is never emitted in a `-s` run (no menu), so the App → 04 menu → ack UI path is unverified. Only the persisted `migration_notice` and its ack were checked.
- Part D (P3): same content_version with a hand-edited L9 still gives hp 2.20. It is only reachable by editing the file, so it is your call. I would accept leaving it, or clamping in `_migrate` if that is cheap.
- To close AC1 I will rerun only AC1/AC4 (one short heavy_run) after your content.gd change.

## v0.33 (~03:50 KST 11-01): release packages agree today; AC1 still open
Source: DATA_AND_BACKEND_ANALYSIS.md §9.25.
- One pinned commit, eb8d5c4, was built both ways (heavy_run_detached, no install):
  - 04 `build_android_debug.ps1` APK: 21 data files, 0 CR, **c1-989c3422c910**.
  - 06 `try_debug_aab.ps1` AAB: the same 21 files, byte-identical, under `assetPackInstallTime/assets/data/`, **c1-989c3422c910**.
  - Both equal the repo LF value. Verdict: the two release paths are the same.
- **AC1 is still FAIL.** content.gd line 77 is unchanged up to 02ec60f. The packages agree only because both scripts pin the archive flags. A plain `git archive` on this PC still gives CRLF and c1-40bde75d24c2.
  - Repro and pass criteria: as in v0.32 above.
- I did not rerun AC1/AC4 because no content.gd change has landed. I will rerun only those two after your commit and repeat the package check with the new SHA.
- FYI, no request: the AAB keeps project files in the install-time asset pack, not in `base/`. I have not checked on a device that Godot reads `res://data/` from it with the same bytes (AC9 device part, unverified).
