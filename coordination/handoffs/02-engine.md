# 02-engine handoff
Updated: 2026-10-31 17:25 +09:00
Status: ACTIVE. Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL QUOTA CHECKPOINT notices are previous-account records; not acted on.

## User decisions
Q1 theme DECIDED: A "빵집 기사단 vs 곰팡이 군단" (data IDs unchanged, D1). Q3 work title DECIDED (16:19 KST, verbatim "빵집 기사단: 곰팡이 디펜스"); final store name after KIPRIS; ui.title text is 01's. Q2 monetization ON HOLD: no paid currency, no ad-reward paths (02 adds none).

## This round (Codex priorities 1–4)
1. `Save.buy_upgrade(id, to_level)` (4d77225, PUSHED): one atomic save for coins + level, rollback on failure, codes ok/already_applied/max_level/not_enough_coins/unknown_id/locked/invalid_level/save_failed/save_uncertain/read_only; `Events.cmd_buy_upgrade` → `Events.upgrade_result`. 10's probe_upgrade_transaction.gd unmodified: C1–C5 all PASS. selftest `buy_upgrade` PASS. 04 told (R7).
2. 03 A11: main-tree `--import` under lock; validate.py --import-cache PASS (all pages match). Local `build/.gdignore` stops the UID-duplicate scan of 08's build/perf trees (0 warnings now). DISPLAY2 captures: title logo + themed battle art. 03 and 07 asked to re-capture.
3. 05 A9: `target_side` in hit cues + coalescing key. 05's runner uses committed HEAD, so its counts need a re-run after this push.
4. QA-B012: Galmuri9 10 px numbers, same-target merge (0.35 s), placement above frame + bar, vertical stagger; separate text RNG (bot outcomes shifted once; noted to 07).

## Validation (17:00–17:22, workspace)
selftest PASS (70 scripts); targeting_equivalence EQUIVALENT 0/30; tests/ui 3354/0; UI integration 44/0; services PASS_INTEGRATED (earlier this round); 07 acceptance save+faults+flow 63/0; audio checks PASS (sandbox from HEAD); 07 capture_crowd on r08: overlaps {}.
Balance (selftest, current data): competent bot 3/3 r01–r04, r08, r09; 0/3 r05, r06, r07, r10. r01 wave_cleared(1) still outside D16 25–45 s (01 decision pending).

## Commits this session (PUSHED)
… 22d99ea, 6e93682, 4d77225 (buy_upgrade). This step: bottom.

## Next steps
1. 07 -Head re-verify (save,faults,flow + B012 crowd) on this HEAD; 05 re-run -Integration; 03 re-capture.
2. 10 R5 content_version + clamp/refund (probe part D).
3. 08 remaining H3/H4/H6-done/H8/H9–H13; P4 save latency log; P5 perf hooks.
4. QA-J1 camera framing (enemies off-screen r01 t=7..32) — coordinate with 04.
5. 01 decisions: D16 window vs r01 data, D7 caps text, 900 s timer rule. 05 A8 cycle; OS close → quit_game; 04 R12 release preset.
