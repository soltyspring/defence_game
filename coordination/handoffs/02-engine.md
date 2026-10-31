# 02-engine handoff
Updated: 2026-10-31 20:22 +09:00
Status: ACTIVE — D29 base defence + 01 R8 F0 comparison done and being committed; next R9/D32 + 10 F2/X1 save work.
Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL QUOTA CHECKPOINT notices are previous-account records; not acted on.
Last processed: DECISIONS up to D33; 01→02 R7, R8, R9 (read; R9 queued); 10→02 v0.24–v0.27 (F2 + X1 queued); 08→02 P9/P10 (queued);
04→02 R16/R17 (queued); 03→02 A16 (integer settings kept, no change needed); 06→02 18:46/19:06/19:33 (launcher_icons, AAB preset queued).

## User decisions
Q1 theme A "빵집 기사단 vs 곰팡이 군단" (data IDs unchanged). Q3 work title "빵집 기사단: 곰팡이 디펜스" (store name after KIPRIS).
Q4 home-screen name ko "빵집 기사단", en "Bakery Knights". Q2 monetization ON HOLD (no paid currency/ad-reward paths).

## This round (D29 + R8)
- `src/gameplay/battle_sim.gd`: `economy.base_defense{dps_cap, push_px, stagger_s, tower_splash}`, player base only, every key
  missing/0 = off. B = 1 s sliding-window cap (`_cap_player_base_damage`, `base_dmg_capped`); A = knock-back on non-boss enemy
  base hits; C = extra attack delay; D = player tower bolt splash. INTERFACES.md §2.7 v1.5.
- `src/core/diag/base_damage_probe.gd`: 01 R8 grid (OFF, F0, B25, A30, B25+A30; budgets none/low/low2r; seeds 1–5, r05 1–10;
  01's D30 bot timing noise; peak base loss %/s; max enemies at base; idle time to loss), `--configs=` shards, `--merge=`.
- `src/core/diag/selftest.gd`: new base_defense check (cap 25: 980/975/975/955, capped 35, 3 shakes, enemy base uncapped).
  Header of selftest/passive/pressure_cue/wave_clear probes: run with a private APPDATA (10 v0.26 item 1).
- Result (data f01e9d5, hash 0e824716c8f9): docs/architecture/evidence/base_damage_r8_20261031.md. r02–r04 competent LOW end
  1.000 in every config (base never hit), so 01's band is met by none; B breaks the r05 block (none 0/10 → 10/10), r10 none
  runs to 900 s, idle r03 847–1019 s. Recommendation to 01: keep base_defense off (data has no key today).
- Validation on this tree (all with private APPDATA, real save.json unchanged): selftest PASS (73 scripts); UI integration
  48/0; 07 run_acceptance save,faults,flow 63/0 (build/qa07/20261031-195027); 08 targeting_equivalence EQUIVALENT 0/30;
  wave_clear_probe r01 competent 41.07 s / hero_rush 23.55 s / deploy_only 63.52 s.
- Note: running 07's runner from a pwsh pipe started the adb daemon, which kept the pipe open (my call timed out after the
  run had finished). Use Start-Process or read build/qa07/latest.txt.

## Commits (PUSHED, origin/main verified)
… 4b5926d (Q4 + F1), 653188e, 2a6dac5, 7f2886c (R5 content_version + window title), 4d5a53c (QA-B017 + fallback title).
This round: [Feat] D29 commit — SHA recorded in the status file after the push.

## Next
1. 10 F2 (P2): failed migration save must keep the OLD content_version/snapshot until the migration succeeds
   (`_migration_pending`; `_stamp_content` skips while set). Acceptance: 10 probe_r5_cases F2a/F2b 1,584 / L3 after reload.
2. 10 X1 (P1): no write during load when nothing changed (`if not changed: return` for any prev_cv); optional `-s` guard.
3. 01 R9 / D32: refund at the price actually paid (new per-save `paid` record, snapshot fallback); retired upgrade =
   refund + remove; one `content_migrated {levels, coins}` signal (04 notice, key `notice.content_migrated`); 10 v0.27
   pre-migration backup `save.pre-<cv>.json` (keep 2). Re-run 10 run_content_migration + probe_r5_cases, 07 save/faults.
4. 08 P9: sort units by (round(lane_y), atlas page, lane_y) with the page id cached at spawn; then 08 C12 A/B. H3/H4/H8/H9–H13, P4, P5.
5. 04 R16 `snapshot.threat` (+ `ground_screen_y`), R17 bottom safe inset in `_update_camera` and world zoom (k+1)/k question;
   03 A16: keep `App._apply_pixel_scale` + integer mode (no change); camera check at 780×360 / 800×360.
6. 06: `launcher_icons/*` keys in export_presets.cfg, Gradle/AAB preset, JDK 17 path (machine setting, ask before changing).
   08 P10 perf APK with baked args. 04 R12-2 release preset (exclude src/ui/mock, src/core/diag, bot_player; arm64).
7. Re-import under lock for 03 A12/A13 pages; tell 03. 05 A8 RefCounted cycle; OS window close → quit_game. 07 QA-R1 hooks.
