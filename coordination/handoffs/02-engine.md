# 02-engine handoff
Updated: 2026-11-01 09:25 +09:00
Status: **STOPPED by the user (09:17 KST: "이제 그만만들고 멈춰", "푸시하고 끝내").** No new work, no new heavy_run job. Windows stay open.
Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.

## Task at the stop (Codex order 2026-11-01 07:1x)
1. 10 v0.34: content updates re-lock cleared rounds (release-blocker candidate).
2. 07 QA-B025 (deaths fade before they play) and QA-O006 (hit / hero cast animations never drawn).
3. 08 P11: skip the clear-colour rows hidden by an opaque sky layer (pixel-identical, check with 07's fixed set).
4. World zoom 3/2 odd pixel runs: cause only. 5. 04 R16 threat field, R17-2 bottom safe inset, R19 damage-number size.

## Heavy job still queued (NOT killed, per the stop order)
- Label `02-anim-p11`, detached pid 42804, queued 2026-11-01 08:26:25, log `build/heavy/02-anim-p11-20261101-082622.log`.
- It has not reached START (lock queue ~60–80 min). If it runs, it builds a HEAD snapshot + `build/wip02/**`, runs headless selftest, anim_display_probe,
  text_overlap_probe, UI integration, 07 sim/flow/save/faults, 10's relock cases, run_content_migration, and — only if the headless gate passes — two
  visible 07 fixed-set runs on DISPLAY2 (800×360, A = no flag, B = sky `opaque: true` in the test copy) + a PNG diff. Outputs: `build/save_evidence/anim02/`.
  Its results are NOT reviewed by me and nothing from it is committed.

## Done and pushed this round (verified with git ls-remote)
- bd66288 [Docs]: pass conditions for the animation fix written before the change (docs/architecture/evidence/anim_display_20261101.md); zoom 3/2
  odd-run cause = 03's units band includes 19 HUD rows at k = 2, world part 0.0 % odd (world_zoom_20261101.md + world_zoom/odd_runs_split.py,
  measured on the committed t046 frames, no Godot); relock fix design + first-run results (relock_fix_20261101.md, relock/relock_run1_20261101.log);
  engine animation values and the `opaque` flag request sent to 03 (02-engine-to-03-art.md).
- Earlier: 780c30a (bot stall fix + world zoom flag + AC1), d8e4753 (SHA record).

## NOT verified, NOT committed (left in the working tree, untracked)
Code lives in `build/wip02/**` (git-ignored) and a copy for the coordinator's checkpoint in
`docs/architecture/evidence/wip02_unverified_20261101/` (untracked; the folder is under evidence/.gdignore, so Godot never loads it):
- `src/core/save.gd` — 10 v0.34: `is_unlocked()` id-based (prefix or i == 0 or starred or previous starred or `open_rounds`), `_unlock_state()`,
  `_set_unlock_state()`, `round_reach()`, `upgrade_locked()`, migration step 5 from the old playable ids (`content_snapshot.order[0:unlocked_round]`
  + `round_renames`), `record_result` hole wins, `_migrate` sanitises `open_rounds`. **Partly measured:** 10's probe_relock.gd cases on HEAD 52cf31a +
  this file (run 1, 08:2x, job `02-anim-p11` first run): U1 cleared-but-locked = [] in 17/17 boots, U2/U4/U5 met, no write for bytes/cap-only updates
  incl. the all-cleared save. Selftest's `unlock_rules` check passed in the same run. NOT run: M1/M2 (run_content_migration), 07 save/faults suites.
- `src/gameplay/battle_sim.gd` — `DEATH_TIME` 1.5 (was 0.7), `HIT_REARM` 0.6, visual-only `hit_t`/`cast_t`, hero dead_t/anim_t advance during respawn.
  In run 1 the selftest bot round times were identical to before (r01 101.8 … r10 851.6 s) → no gameplay change seen; 07 sim suite not run on it.
- `src/gameplay/battle_view.gd` — `anim_for()`, `death_alpha()`, hit/cast/hero-death drawing, P11 `_draw_clear` + `clear_segments()` + `opaque`
  layers, `base_draw_rect()`, damage numbers Galmuri11 12 px. **Run 1 failed to parse** (my edit dropped the `_biome_palette()` header); fixed in
  build/wip02 at 08:24 but never compiled since.
- `src/gameplay/battle.gd` — R16 `_threat()` in the HUD snapshot, R17-2 `_bottom_inset()` / `ground_screen_y`. Not compiled since the change.
- `src/core/diag/selftest.gd` (+ `_check_view_rules`, `_check_unlock_rules`), `anim_display_probe.gd` (new), `text_overlap_probe.gd`, `wave_clear_probe.gd`.
- `docs/contracts/INTERFACES.md` — modified in the shared tree (v2.0 section + HudSnapshot `threat` example) describing the unverified code. Not committed.
- Drafts: request to 04 (`draft_02-engine-to-04-client.md`), job file, `png_diff.py`, `set_opaque.py`, `run_content_migration_wt.ps1` (same folder).

## Exact next steps when work resumes
1. Read `build/heavy/02-anim-p11-20261101-082622.log` and `build/save_evidence/anim02/` if the job ran. If not, re-queue it ONCE (it already contains
   every check). Gate: selftest PASS, UI failed=0, 07 FAIL=0, relock cleared_but_locked = [] everywhere, content_migration M1 r08 locked / M2 r02b
   + r03–r07 open / M4 1,584, anim probe death frames at alpha 1 = 100 %, hit/cast frames > 0, PNG_DIFF diff_px_total = 0.
2. If it passes: copy `build/wip02/**` into the tree and commit at once (no long uncommitted gameplay files in the shared tree), together with
   INTERFACES.md v2.0 and the evidence; then send the 04 draft (switch round_select.gd:60 / upgrade_panel.gd:87 to Save.is_unlocked / upgrade_locked),
   ask 10 to rerun v0.34 U1–U5, 07 to update capture_art_baseline's death fade (it hardcodes dead_t/0.7; use `BattleView.death_alpha` and
   `BattleSim.DEATH_TIME`), 08 to re-measure P11 after 03 adds `opaque: true`.
3. Open after that: 08 P9 row/page sort, QA-B013 world HP bars, 06 AAB/launcher icons, 10 Part D, R12 only if 01 confirms.

## User decisions
Q1 theme A. Q2 monetization ON HOLD (no ads/billing/shop UI). Q3 work title "빵집 기사단: 곰팡이 디펜스". Q4 home-screen name ko "빵집 기사단",
en "Bakery Knights". Q5 unanswered; D28 is a default.
