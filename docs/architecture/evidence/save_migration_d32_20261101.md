# Save content migration (01 D32, 10 F2/X1/v0.27/v0.28) and QA-B012 damage numbers (2026-11-01)

Owner: 02-engine. All runs headless, one at a time under `coordination/heavy_run.ps1`, with a private APPDATA
(`docs/research/systems/probes/isolated_godot.ps1`; `real_save_changed_during_run=false` in every run).
Code: origin/main f8a2b44 (00:30 KST) + this change (save.gd, events.gd, app.gd, fallback_ui.gd, battle_view.gd). Data: balance/meta as of f01e9d5 (D33); 4882771 (00:18) only added a text key, before the 00:21–00:40 runs.

## Save changes
| item | behaviour |
|---|---|
| D32 (1) refund on a max_level cut | price per removed level = `upgrade_paid[id][L]` (written by buy_upgrade in the same atomic save), else the snapshot price, else 0 + `content/refund_unknown` |
| D32 (2) retired upgrade | refund every level at those prices, then remove the level and the paid record |
| D32 (3) notice | `progress.migration_notice {levels, coins, from, to}` persists until `Events.cmd_ack_content_migrated`; App emits `Events.content_migrated` once per session after the menu mounts |
| 10 F2 | a failed migration write sets `_migration_pending`; later saves keep the OLD content_version + snapshot, so the next load migrates again |
| 10 X1 | nothing to change → no write during load (any previous content_version) |
| 10 v0.27 | `save.pre-<old cv>.json` copy of the loaded file before a migration writes; never rotated; newest 2 kept |
| 10 v0.28 | `save.json.corrupt-*` copies: newest 3 kept |

## Results
- **selftest** PASS (73 scripts). New `content_migration` check (data changes emulated in memory):
  - purchases record paid prices `{2: 60, 3: 100, 4: 160}`;
  - X1: L4 price change only → file bytes unchanged, revision unchanged, no backup;
  - cap 4 → 3 after that price change refunds the PAID 160 (snapshot said 237): coins 4,440 → 4,600, once (4,600 after reload); paid "4" removed; notice {levels 1, coins 160}; `mig.pre-<cv_b>.json` equals the pre-migration file byte for byte;
  - F2a (after_tmp_write, ordinary save, relaunch) → 4,600 / L3; F2b (before_final_rename, ordinary save, relaunch) → 4,600 / L3;
  - retire up_worker L3 → +240 (paid 90 + 150), level and record removed; unseen notices add up to {levels 3, coins 400};
  - ack clears the notice across a relaunch; 2 pre-migration backups kept; 5 corruptions in a row leave 3 quarantine copies.
  - buy_upgrade C1–C5, save_faults, rules unchanged.
- **10 probe_r5_cases.gd** (workspace, isolated): **9/9 PASS** incl. F2a and F2b; R2m (price change then cap) refund 410 = D26/D32 "actually paid" (true); R6r (retired up_worker L4) = D32 refund (true).
- **10 run_content_migration** (local copy of 10's isolated runner with the 5 working-tree engine files overlaid on HEAD f8a2b44):
  M0 1,234 unchanged; M1 unlocked 6; M2 unlocked 8; M3 unlocked 7; **M4 L3 / 1,584 / hp 1.30** (1,584 after save + reload);
  M5a unchanged; **M5b up_toast_knight L5 / hp 1.60**; content_version present after save in every variant.
- **10 probe_upgrade_transaction.gd**: C1–C5, C5b, C6 8/8, C7–C13 PASS. Part D (same content_version, L9 hand-edited) still keeps L9 / hp 2.20 (not in scope).
- **07 run_acceptance -Only save,faults,flow** (workspace mode, private APPDATA): PASS 63 / FAIL 0 (build/qa07/20261101-003651).
- **04 test_ui_integration.gd**: passed 49 / failed 0.

## QA-B012 damage numbers: cause confirmed, layout fixed
Cause (07's diagnosis confirmed in code): `_draw_text` used an 11 px rect (`NUM_PX + 1`) but moved it by 10 px (`NUM_PX`).
A moved rect still overlapped its neighbour by 1 px, so each stacked number used two moves; after the 6-move guard the
number was drawn anyway, overlapping.
Fix (battle_view.gd): `place_text()` (pure, static) moves by `TEXT_STEP` = rect height (12 px: 10 px glyph cell + 1 px outline
above and below), up to `TEXT_MAX_STEPS` = 8 moves; if no slot is free the number is skipped for that frame. Numbers get
a 1 px dark outline (4 neighbours) instead of the single (1,1) shadow (07 visual7 zoom_nums: light walls).
Replay probe `src/core/diag/text_overlap_probe.gd` (same layout code on a real headless r08 battle, App autoplay seed 12352,
competent bot, 11,100 frames = 185 s; widths from Galmuri9, anchor heights from atlas frames):
| layout | overlapping rect pairs | frames with an overlap | max numbers drawn | skipped |
|---|---|---|---|---|
| old (10 px step, 11 px rect, 6 tries) | 2,442 | 148 | — | 0 |
| new (12 px step = rect, 8 tries) | **0** | 0 | 12 | 351 number-frames in 47 frames (0.4 % of frames) |
Max live numbers 20 (cap 24). The replay is not 07's rendered run (different frame pacing), so 07's capture_crowd re-measure
on the commit is the acceptance check. Legibility on the village walls is not checked by 02 (no visible run).
