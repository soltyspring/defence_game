# 02-engine handoff
Updated: 2026-10-31 16:40 +09:00
Status: ACTIVE. Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL QUOTA CHECKPOINT notices are previous-account records; not acted on.

## User decisions
Q1 theme DECIDED: A "빵집 기사단 vs 곰팡이 군단". Data IDs unchanged (D1). User: fix all reported defects.

## This step (review priorities 1–2)
1. `Events.wave_cleared({index,t})` (01 D21): units carry `wave_tag`; per scripted wave pending/alive counters; fired in `_kill` when a wave has fully spawned and all its units are dead; not after a loss. `pressure: true` waves spawn but are excluded from waves_total, HudSnapshot.wave, wave/boss toasts and wave_cleared.
   - r01 headless, competent bot, seeds 11/22/33: once each, at 56.65 s; order 1→2→3 (56.65 / 79.55 / 104.38 s); HUD total 3 (was 6).
   - **25–45 s NOT met with current data**: probe `src/core/diag/wave_clear_probe.gd` → hero push 34.67 s, hero home 59.4 s. Lane/speed cause; options sent to 01 (R4) and 09. Selftest keeps this as a BALANCE flag, not a failure.
2. 08 P7: H1 cached `Atlas.AnimRec` (no per-sprite dicts), H2 bars second pass + negative-width flip (flip_check.gd: 0 px diff) + const colours, H5 cached sort Callable, item 8 caps single source `Content.caps()`, item 9 preallocated pools; also P2b tie-break (08 equivalence `EQUIVALENT 0/30`, was 29/30 diverged, 3 winner changes).

## Validation (16:20–16:38, workspace)
selftest PASS (69 scripts; find_target identity 2217/0; waves_and_pools; pools_grew=false); 08 targeting_equivalence EQUIVALENT 0/30; tests/ui 3329/0; UI integration 35/35; services suites PASS_INTEGRATED; 07 `run_acceptance.ps1 -Only save,faults,flow` PASS 63 / FAIL 0; visible r03 capture on DISPLAY2 correct (enemies mirrored, bars on top, HUD 웨이브 2/4). `-Head` run: after the push, see the bottom.

## Commits this session (all PUSHED)
… 08ef082, d660311, 141d226, 2884231, abb1809 (Services), f92f9f6 (A7 quit). This step: bottom.

## Next steps
1. 07 `-Head -Only save,faults,flow` on this commit (result appended below if run).
2. 08 remaining: H3 def fields, H4 _cue alloc, H6 damage-text font, H8 shake coalescing, H9–H13; P4 save latency log; P5 perf hooks.
3. 01 decisions: D16 window vs r01 data, D7 caps text, passive loss time, 900 s timer rule.
4. 05 A8 RefCounted cycle; OS window close → quit_game. 04 R12-2 release preset, R12-3 emulator slot. 07 QA-R1 hooks.

## Commit for this step
22d99eada99a82c840e8e90f675507f704193d19 [Feat] 웨이브 격파 이벤트와 압박 웨이브 제외, 렌더 할당·배치 개선과 타깃 동률 규칙 통일 — PUSHED origin/main.
07 `-Head -Only save,faults,flow` (16:38, out build/qa07/20261031-163837): PASS 63 / FAIL 0 / BLOCKED 0 on HEAD snapshot e551fa9, which contains 22d99ea (ancestor; snapshot events.gd has wave_cleared). The runner logged a Remove-Item lock error on %TEMP%\qa07_head (07's own run held it), so the snapshot was probably reused rather than rebuilt; it was at e551fa9 either way.
