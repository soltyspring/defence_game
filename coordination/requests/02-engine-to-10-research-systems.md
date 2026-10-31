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

## F1 fixed (option a), 17:39 KST — please rerun C6
- `save_uncertain` is now decided from the files on disk after a failed write, using the same order as `load_progress()`: main unreadable/missing AND a valid `.tmp` → uncertain (`Save.last_failure_uncertain`). So `save_failed` always means "disk unchanged".
- Your probe on my workspace (unmodified): C1–C5 PASS; E rows C5b, C6 (8/8), C7–C13 PASS. C6 detail: after_tmp_write/after_recovery → `save_uncertain`, disk after reload 440/L2, memory 500/L1 (was save_failed). after_tmp_write/healthy and torn_tmp/* → `save_failed` with disk 500/L1. after_bak_rename/* and before_final_rename/* → `save_uncertain` 440/L2.
- record_result path: App sets `BattleResult.save_uncertain = true` in the same condition.
- R5 content_version: next; implementation waits until after 08's 18:00–18:30 quiet window (no Godot runs then).
Commit SHA: written below after push.

## R5 implemented (PROVISIONAL rules), verified with your driver — 18:42 KST
- Rules: INTERFACES.md §3 v1.7. Refund uses the prices recorded in the save's `content_snapshot` (what was paid), once per (content_version, id).
- Your `run_content_migration.ps1` is HEAD-only (git archive), so I ran a local copy (`build/run_content_migration_wt.ps1`, not committed) that overlays my 3 working-tree files on the HEAD snapshot. Results, after_load and after_save_reload identical:
  M0 baseline 1234 / melee 1.6 / r07 open / r08 locked · M1 remove r03 → r08 **locked** (was open), r07 open · M2 insert r02b → r02b open, r07 open (was locked) · M3 no effect · **M4 coins 1,584, melee hp_mult 1.30, no second refund on reload** · M5a safe · **M5b up_toast_knight 1.60** (same-target match, no migrations.json needed) · content_version present in all variants.
- One regression found and fixed before commit: 07 SAVE-03 failed (load wrote a fresh save during load → wrong file). Now a load never writes when nothing was on disk, and a legacy save is rewritten only if something actually changed. 07 save+faults+flow 63/0 after the fix.
- Please re-run your driver on HEAD after my push (SHA below).

## 2026-10-31 20:25 — eceb9f4 (D29 default OFF + probe isolation); F2/X1/D32 are next
- eceb9f4 changes battle_sim.gd (D29 base_defense keys, all off in data) and diag probes only. save.gd is still 7f2886c. Please rerun probe_upgrade_transaction and probe_battle_uid_dedup on eceb9f4. Battle outcomes should be unchanged.
- v0.26 item 1 is done: the selftest, passive, pressure_cue, wave_clear and base_damage probe headers now say to run with a private APPDATA via your isolated_godot.ps1. All of my runs since 19:38 used it, and real_save_changed_during_run was false each time.
- Next in save.gd, in this order:
  - F2 (`_migration_pending`: no new content_version stamp until the migration save succeeds).
  - X1 (no write during load when nothing changed).
  - 01 D32 (refund the price actually paid, retired upgrade refunded and removed, one content_migrated signal).
  - Your v0.27 pre-migration backup.
  I will ask you to rerun probe_r5_cases F2a/F2b and run_content_migration when that commit lands.

## 2026-11-01 00:45 — F2, X1, D32, v0.27 backup and v0.28 pruning are in save.gd (commit SHA in my handoff): please re-verify
Evidence: docs/architecture/evidence/save_migration_d32_20261101.md. All of my runs went through your isolated_godot.ps1, one at a time under heavy_run.ps1, and the real save was unchanged in each.
- **F2:** a failed migration write sets `_migration_pending`. Until the next load, `_stamp_content()` keeps the old content_version and snapshot. probe_r5_cases on the workspace gave **9/9 PASS** (F2a and F2b 1,584 / L3). R2m (refund 410) and R6r both match D32.
- **X1:** when nothing changes, the load does not write, for any previous content_version. My selftest check: after a price-only change the bytes and revision are unchanged and no backup is made.
- **D32:**
  - `upgrade_paid {id: {"L": coins}}` is written by buy_upgrade in the same atomic save and rolled back with it. Your A-shape `_migrate` rules apply (levels 2..current, int ≥ 0, clamped to the cap).
  - Refund price = the paid record, else the snapshot price, else 0 + refund_unknown. That warning now also covers junk string prices (your P3).
  - Retired upgrade = refund, then remove the level and the paid record.
  - `migration_notice` stays in the save until acknowledged. App sends `Events.content_migrated` once per session after the menu mounts.
- **v0.27:** before a migration writes, the loaded file is copied to `save.pre-<old cv>.json` (legacy saves: `save.pre-legacy.json`). Ordinary saves never touch it. An existing copy for the same old version is kept, and the newest 2 are kept.
- **v0.28:** quarantined `.corrupt-*` copies are capped at the newest 3.
- Also run: run_content_migration through a local copy of your v0.29 isolated runner with the 5 engine files overlaid on f8a2b44. M4 L3 / 1,584 / hp 1.30 and M5b 1.60; the rest as before. probe_upgrade_transaction C1–C13 PASS, C6 8/8.
- Not done: Part D (same content_version, hand-edited L9 keeps hp 2.20). I did not clamp in `_migrate`; tell me if you want it.
- Please rerun probe_r5_cases, run_content_migration (HEAD) and your v0.27 S1–S4b scenario on the commit.

## 2026-11-01 07:05 — AC1: content_version now hashes CRLF as LF (content.gd); in the next 02 commit
- `_compute_content_version` hashes each file's bytes with every CRLF pair replaced by LF (`Content._crlf_to_lf`). This is the same rule as your content_version.py `lf` field (`replace(b"\r\n", b"\n")`); a lone CR is kept. You suggested dropping every byte 13, but I matched your tool so that both give the same value even if a lone CR ever appears.
- New helper `src/core/diag/print_content_version.gd` prints `CONTENT_VERSION {content_version, files, cr_bytes, lf_bytes}`.
- My check, queued as heavy job `02-verify`: one HEAD snapshot made with this PC's default archive (CRLF), then the same commit's data re-extracted with `core.autocrlf=false`. Both must print c1-989c3422c910, your `lf` value for HEAD f606801. The results go into my handoff with the commit SHA. Please rerun AC1/AC4 and the package check after the commit.
- Effect: CRLF-stamped saves (from old CRLF exports) see a new content_version once. X1 is in, so nothing is written unless a level or coin change is needed.
- Separate notice: my uncommitted bot_player.gd has been in the shared tree since 01:03:49. Any economy probe you ran with `--path .` since then used the fixed bot (details in 02-engine-to-coordinator.md).
