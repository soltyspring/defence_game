# 02-engine handoff
Updated: 2026-10-31 08:40 +09:00
Status: ACTIVE (resumed after account change; the 08:21–08:22 requests failed with authExpiryRetry, work was recovered from the working tree).
Model: claude-opus-5.5, trust-all. Session ID: not exposed inside the session; do not guess.
HISTORICAL QUOTA CHECKPOINT notices in coordinator-to-02-engine.md are from the previous account and were not acted on.

## User decisions
None answered. Q1 theme still PENDING; D1–D12 are reversible DEFAULTs (not user approvals).

## Processed requests (this milestone)
- 04 R6: tutorial step signal (`Events.tutorial_step`, `HudSnapshot.tutorial`). 04 R8 acknowledged (integration test still 29/29).
- 01 R1 §10 tutorial, R2 C2 (`round.skills: []` = no skills; r01 now has none), R2 §3 "both bases 0 in the same tick = player win".
- 05 A1 (`Audio` autoload after Save), A2 (`Events.sfx`), A3 (semantic cues, coalesced ≤1 per cue+kind per step), A6 (audio snapshot in `--quit-after` print).
- 06 S4 (`battle_uid` in BattleInfo/BattleResult, 128 random bits). 10 R3 battle_uid part.
- 08 P2 (sorted-lane `_find_target`), P3 partial (no per-step arrays in `_reap`/towers, event buffer swap), P6 (roster-based atlas residency).
- 03 A1/A2 acknowledged (Godot-generated .import files are theirs).
- Coordinator typography correction 08:12 (integer scaling at 2.5×): READ, QUEUED as next task; not started.

## Completed in this milestone (files)
src/core/events.gd, src/core/content.gd (round_enemy_roster, explicit skills gating), src/core/save.gd (tutorial_done), src/core/app.gd (tutorial_done persisted, battle_uid via battle.battle_info(), audio snapshot print), src/core/diag/selftest.gd (find_target equivalence, rules, tutorial + audio-cue checks), src/gameplay/battle_sim.gd, src/gameplay/battle.gd, src/gameplay/tutorial_director.gd (new), project.godot (Audio autoload), docs/contracts/INTERFACES.md (v1.2 notes), docs/architecture/evidence/.gdignore, coordination/requests/02-engine-to-04-client.md R3.

## Validation actually run (08:25–08:38, desktop, other Godot processes running = contended)
- selftest: SELFTEST PASS, exit 0, scripts 65/65 compile. find_target sorted vs linear: 2221 samples, 0 mismatches. Rules: same-tick both bases → player win; skills r01 [] / r02 slam / r04 slam+rally / r08 +barrage. Tutorial r01 (competent bot): tut_move_hero@0.0 s → tut_deploy_unit@0.1 → tut_buy_worker@2.5 → tut_destroy_base@18.5, all done; cues in one battle hit 229 / death 31 / base_hit 26. Cap stress step avg 0.39 ms, p99 0.89 ms, worst 0.96 ms (earlier same day: avg 0.79–1.36 ms, worst 8.8–28.9 ms under contention; not a clean A/B).
- Targeting micro-benchmark (frozen 73 units, same process, local build/bench_target2.gd): sorted incl. sort / linear = 0.52–0.72 (≈30–50 % less). Below 08's ≥50 % acceptance in 3 of 4 runs → 08 should re-measure with their tool.
- 04 tests/integration/test_ui_integration.gd: passed=29 failed=0 (includes tutorial hint shown from the engine signal, battle_uid in result).
- 05 tools/audio/audio_selftest.gd: `audio_autoload: true`, AUDIO SELFTEST PASS. Autoplay 60 s: played 95, peak_voices 4, missing 0, load_errors [].
- Headless autoplay: all 6 atlas pages `"source":"import"`, resident 5.25 MiB GPU estimate.
- NOT re-run this milestone: Android APK export/emulator (last verified at fdd4d86, 07:26).

## Balance (unchanged, sent to 01)
r01–r03 competent bot 3/3; r04–r10 0/3. Passive player never loses r01/r02 within 900 s (enemy pressure too low there) — new observation, to report to 01.

## Commits
- 1eb4637 engine foundation — PUSHED. fdd4d86 Android export + atlas import verification — PUSHED.
- This milestone: see coordination/status/02-engine.md (SHA recorded after the helper runs).

## Known failures / open
1. 07 QA-B003 save migration wrong-typed fields; 10 R1/R2/R6 save `.bak` quarantine, newer-version read-only, fault-injection hook — NOT done (07/10 are waiting on the fault hook).
2. 08 P1 battle_view per-frame Dictionary allocations / draw batching; P4 save latency; P5 perf hooks — NOT done.
3. 03 A3: shadows, unit markers, prop_mine, white vertical seam lines (03/04 report rounding seam in parallax tiles) — NOT done.
4. Typography integer scaling (coordinator 08:12) — NOT started; must coordinate with 04.
5. hit_frame timing, cast_time, 2× speed command; 06 S1–S3/S5 Services autoload; 07 QA-R1 hooks; 01 R3 falsification sims — open.

## Exact next steps
1. Fix the parallax seam (battle_view tile x rounding) and add 03 A3 shadows/markers/prop_mine; secondary-monitor capture via tools/build/visible_launch.ps1.
2. Save hardening: QA-B003 type normalisation, `.bak` quarantine, newer-version read-only, debug-only fault hook (07/10).
3. Integer-scale evaluation with 04 (2.5× case evidence), then 07 visual check.
4. 08 P1 battle_view allocation/batching work, then ask 08 to re-measure.
5. Re-export APK and re-run emulator smoke after these.
