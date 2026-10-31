# 02-engine handoff
Updated: 2026-11-01 08:30 +09:00
Status: ACTIVE. Codex order 2026-11-01 07:1x: (1) 10 v0.34 round re-lock (release-blocker candidate), (2) 07 QA-B025 / QA-O006 animation display,
(3) 08 P11 hidden clear rect, (4) zoom 3/2 odd-run cause, (5) 04 R16 / R17-2 / R19. All code is in a PRIVATE copy build/wip02/** (not committed, not in
the shared tree); one verification job `02-anim-p11` is queued (08:26). Nothing of this round is committed yet.
Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL / QUOTA CHECKPOINT notices are previous-account records; not acted on.
Rules in force: heavy runs only via `coordination/heavy_run_detached.ps1` (poll HEAVY_JOB_DONE in short calls), headless unless a capture is needed,
private APPDATA, one job per task. **Codex 07:1x: never leave src/gameplay/**, src/core/**, data changes uncommitted in the shared tree; experiment in
a copy, put only verified changes into the tree and commit at once.** (07:35 I moved a 3-minute battle_sim.gd edit out of the tree into build/wip02.)
Last processed: DECISIONS up to D37; 10→02 v0.34 (in work); 07→02 QA-B025/QA-O006 (in work); 08→02 P11 (in work); 04→02 R16–R19 (in work);
03→02 A17–A19 (import deferred); 01→02 R10–R12 (answered in 780c30a: bot conclusions + R12 feasibility; r05 decision is 01's).

## User decisions
Q1 theme A "빵집 기사단 vs 곰팡이 군단". Q2 monetization ON HOLD (no ads/billing/shop UI). Q3 work title "빵집 기사단: 곰팡이 디펜스" (store name after KIPRIS).
Q4 home-screen name ko "빵집 기사단", en "Bakery Knights". Q5 difficulty unanswered; D28 is a default, not approval.

## This round (in build/wip02, verification pending)
1. save.gd (10 v0.34): id-based `is_unlocked`, `open_rounds`, `_unlock_state`, `round_reach`, `upgrade_locked`; migration step 5 from the old playable ids.
   First run of 10's relock cases on the WIP save.gd (08:2x): U1 0 cleared-but-locked in 17 boots, U2/U4/U5 met
   (docs/architecture/evidence/relock_fix_20261101.md). 04 must switch round_select/upgrade_panel to Save.is_unlocked / Save.upgrade_locked.
2. battle_sim.gd: DEATH_TIME 1.5 (was 0.7), HIT_REARM 0.6, visual-only hit_t / cast_t, hero death drawn. battle_view.gd: anim_for(), death_alpha()
   (alpha 1 for the whole death, then 0.3 s fade), hit / cast drawn. Pass conditions written first: docs/architecture/evidence/anim_display_20261101.md.
   Selftest bot round times identical to before (r01 101.8 … r10 851.6), i.e. no gameplay change.
3. battle_view.gd P11: `_draw_clear` skips rows covered by a layer flagged `opaque: true` (03's data); `clear_segments()` pure; selftest checks flags
   vs PNG alpha. Pixel check: 07 fixed set A/B (flag off/on in a test copy), one visible run pair in the job.
4. Zoom 3/2 odd runs: cause = HUD rows inside 03's units band; world part 0.0 % odd (world_zoom_20261101.md last section). No engine change.
5. battle.gd: R16 `snapshot.threat` (+ `ground_screen_y`), R17-2 bottom safe inset; battle_view R19 damage numbers Galmuri11 12 px.
- Mistake: my first job run had a parse error in battle_view.gd (dropped `_biome_palette` header); the gate stopped the visible part, but the
  text probe waited its 300 s timeout. Logged as a NOTE in heavy_run.log; fixed and requeued once.

## Commits (PUSHED, verified with git ls-remote)
… 52f9fa3, 2944cc0, 780c30a (bot + zoom flag + AC1), d8e4753 (SHA record). This round: none yet.

## Next
1. Read `02-anim-p11` results (log build/heavy/02-anim-p11-20261101-082622.log; outputs build/save_evidence/anim02/). If all pass: copy the
   build/wip02 files into the tree and commit at once (save.gd, battle_sim.gd, battle_view.gd, battle.gd, selftest.gd, wave_clear_probe.gd,
   text_overlap_probe.gd, anim_display_probe.gd, INTERFACES.md, evidence docs, requests to 03/04/07/08/10).
2. Then: 03 to add `opaque: true`; 04 to use Save.is_unlocked / upgrade_locked and the threat field; 07 to update its death fade model; 10 to rerun.
