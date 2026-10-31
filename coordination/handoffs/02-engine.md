# 02-engine handoff
Updated: 2026-10-31 09:20 +09:00
Status: ACTIVE. Model claude-opus-5.5, trust-all. Session ID: not exposed inside the session.
HISTORICAL QUOTA CHECKPOINT notices are previous-account records; not acted on.

## User decisions
None answered; Q1 theme PENDING; D1–D12 are reversible defaults.

## This milestone: save hardening (review task 1–4)
1. QA-B004 P1 / 10 SV-1 fixed (quarantine unreadable main, verified-good rotation only, tmp recovery, recovery_source). Also B003, B005, B006, B007.
2. 10 R6 fault hook: `Save._fault` / `Save.FAULT_POINTS` / `Save.fault_fired` (debug builds only). Replies: coordination/requests/02-engine-to-07-qa.md, 02-engine-to-10-research-systems.md.
3. 10 R3: `record_result` idempotent per battle_uid (`applied_battles`), rollback on failed write, App `result.saved/duplicate`.
4. Passive-player finding sent to 01 (02-engine-to-01-director.md R3) with probe src/core/diag/passive_probe.gd. Important: 01 edited round data at 09:03–09:04 (uncommitted); on that data the passive player now loses at ~258 s, before that it survived 1800 s.
Evidence: docs/architecture/SAVE_FAULTS.md (before/after tables).

## Validation (09:00–09:12)
- 10 probe before → after: A2 1 → 6, B 1 (recovered=false) → 6 (recovered=true).
- 07 `run_acceptance.ps1 -Only save,faults`: before PASS 10 / FAIL 6 / BLOCKED 1 → after PASS 16 / FAIL 1 (TP-13a coins cap 9 999 999 vs 07's expected 999 999; reported to 07).
- selftest PASS incl. new `_check_save_faults` (all fault points × normal/after-recovery, double fault, battle_uid duplicate + after reload, rollback, hostile types, clamps, newer version byte-identical).
- UI integration 31/31; services integration 0 failures (4 BLOCKED: Services autoload, 06 S1); acceptance flow 40 PASS / 4 FAIL (pre-existing FLOW-04B/13B/23/23B).
- Not done: device file-system/power-loss test; APK re-export for this change.

## Commits
1eb4637, fdd4d86, e9dfaa4 — PUSHED. This milestone: SHA appended at the bottom after push.

## Open / next
1. 03 A3 + parallax white seam lines; shadows/markers/prop_mine (secondary-monitor capture).
2. Integer-scale evaluation with 04 (coordinator 08:12).
3. 08 P1 battle_view allocations/batching, P4 save latency log, P5 perf hooks.
4. 07 QA-R1 hooks; 06 S1 Services autoload + S2 binding; 05 done.
5. 01 decisions pending: passive loss time, 900 s timer rule.
6. Prune `.corrupt-*` quarantine files; generic Save.transact.
