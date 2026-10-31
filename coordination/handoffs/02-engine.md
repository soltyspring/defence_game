# 02-engine handoff
Updated: 2026-11-01 00:50 +09:00
Status: ACTIVE. Save migration (10 F2/X1, 01 D32, 10 v0.27/v0.28) and the QA-B012 layout fix are verified; the commit SHA is in the status file after the push.
Resumed twice: 23:00 KST (quota login) and 23:2x KST (blue screen 0x50 at 23:08:55). The checkpoint branch checkpoint/quota-20261031-202729/02-engine
held only a generated icon.svg.import, so no 02 work was lost. After the crash, my 5 edited files had no NUL bytes and were not truncated (diff reviewed).
Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL / QUOTA CHECKPOINT notices are previous-account records; not acted on.
Heavy-run rule (since 23:2x): every Godot/import/export/Gradle/emulator run goes through `& .\coordination\heavy_run.ps1 -Label '02-…' -Script {…}`,
one at a time, and uses a private APPDATA (docs/research/systems/probes/isolated_godot.ps1). Lock waits today were 110–1040 s.
Last processed: DECISIONS up to D33; 01→02 R7, R8, R9 (done); 10→02 v0.24–v0.28 (F2, X1, v0.27, v0.28 done; Part D open); 07→02 QA-B012 19:35
(cause confirmed, fixed, re-measure asked); 08→02 P9/P10 (queued); 04→02 R16/R17 (queued); 03→02 A16 (no change needed); 06→02 launcher_icons/AAB (queued).

## User decisions
Q1 theme A "빵집 기사단 vs 곰팡이 군단" (data IDs unchanged). Q2 monetization ON HOLD (ads/billing disabled). Q3 work title "빵집 기사단: 곰팡이 디펜스"
(store name after KIPRIS). Q4 home-screen name ko "빵집 기사단", en "Bakery Knights". Q5 difficulty unanswered; D28 is a default, not approval.

## This round
- `src/core/save.gd`:
  - `upgrade_paid` record written by buy_upgrade in the same atomic save and rolled back with it; `_migrate` sanitises it.
  - Migration order: renames → retired upgrades (refund + remove) → max_level clamp + refund → round renames → unlocks. Price = paid record,
    else snapshot price, else 0 + warning. Coins clamped once.
  - X1: no write when nothing changed. F2: `_migration_pending` keeps the old content_version/snapshot after a failed migration write.
  - `save.pre-<old cv>.json` before a migration write (keep 2); `.corrupt-*` capped at 3 (`_prune`, the new file is always kept).
  - `migration_notice` persisted; `migration_notice()`, `ack_migration_notice()`, `last_migration`.
- `src/core/events.gd`: `content_migrated(info)`, `cmd_ack_content_migrated()`. `src/core/app.gd`: emits once per session after the menu mounts; ack → Save.
  `src/gameplay/fallback_ui.gd`: fallback menu shows `notice.content_migrated` and acks.
- `src/gameplay/battle_view.gd` (QA-B012): `place_text()` static layout, step 12 px = rect height, 8 moves, skip if no slot; 1 px outline on 4 sides; `texts_dropped`.
- `src/core/diag/selftest.gd`: `_check_content_migration` (paid record, X1, paid-price refund, notice, backup, F2a/F2b, retire, ack, backup and quarantine caps).
- `src/core/diag/text_overlap_probe.gd`: replays the number layout on a headless r08 battle (old vs new).
- INTERFACES.md §1.1, §1.2, §3 v1.8. Evidence: docs/architecture/evidence/save_migration_d32_20261101.md.
- Validation (private APPDATA, heavy_run lock, real save unchanged every run):
  - selftest PASS (73 scripts);
  - 10 probe_r5_cases 9/9 (F2a/F2b PASS, R2m/R6r match D32);
  - run_content_migration overlay M4 L3/1,584/hp 1.30, M5b 1.60;
  - probe_upgrade_transaction C1–C13 PASS (C6 8/8);
  - 07 save,faults,flow 63/0 (build/qa07/20261101-003651); UI integration 49/0;
  - text_overlap_probe old 2,442 pairs → new 0 (351 number-frames skipped in 47 of 11,100 frames).
- Not run by 02: 06 services suites, 07 capture_crowd visible re-measure, any visible window. Asked 06/07/10/04/08/01 to re-verify.
- Mistake: the first text_overlap_probe run read autoloads in `_initialize` (not ready yet), looped on errors and held the heavy lock for 5 min
  until the 300 s timeout. Fixed (deferred start + frame bound).

## Commits (PUSHED, origin/main verified)
… 7f2886c, 4d5a53c, eceb9f4 (D29 + R8 probe), c6fbf1f (docs). This round: [Feat] save migration + QA-B012 (SHA in status after push).

## Next
1. React to re-verification from 10 (probe_r5_cases/run_content_migration on HEAD, v0.27 S1–S4b), 07 (`-Head`, capture_crowd QA-B012),
   06 (services suites), 04 (menu notice + ack).
2. 08 P9: sort units by (round(lane_y), atlas page, lane_y) with the page id cached at spawn; then 08 C12 A/B. H3/H4/H8/H9–H13, P4, P5.
3. 04 R16 `snapshot.threat` (+ `ground_screen_y`), R17 bottom safe inset in `_update_camera` and world zoom (k+1)/k question;
   camera check at 780×360 / 800×360 (03 A16).
4. QA-B013 world-space HP bars separable under colour blindness (pattern or luminance).
5. 06: `launcher_icons/*` keys, Gradle/AAB preset, JDK 17 path (machine setting, ask first). 08 P10 perf APK. 04 R12-2 release preset.
6. 10 Part D (optional clamp in `_migrate` for same-version hand-edited levels), if 10/01 want it.
7. Re-import under lock for 03 A12/A13 pages; 05 A8 RefCounted cycle; OS window close → quit_game; 07 QA-R1 hooks.
