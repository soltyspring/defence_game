# 06-services handoff
Updated: 2026-10-31 (M3 complete, new account session)
Status: M3 COMPLETE. **No real ad network, store billing, verification server, consent SDK or remote analytics is integrated. Nothing is live.** Every build runs in `disabled` mode; `production` falls back to disabled. No user monetization decision exists (D9 DEFAULT, Q1 PENDING, Q2–Q5 not asked). No approvals invented.
Session: same Kiro window, resumed after the account change (new account quota verified by coordinator). Session ID not exposed to the agent. Window never closed/restarted.

## Ownership (unchanged)
src/services/**, docs/services/**, tests/services/**, coordination/status/06-services.md, coordination/handoffs/06-services.md, coordination/requests/06-services-to-*.md.

## Read / processed at M3 resume
This handoff (checkpoint), coordinator-to-06-services.md (incl. 3× QUOTA CHECKPOINT sections and the 97% handoff rule), QUOTA_POLICY.md, usage.json (0.1% → 2.05% of 10000; triggered.json present but dated 07:44 at 0%, treated as a leftover marker since the user explicitly resumed), DECISIONS.md D1–D12 DEFAULT + Q1 PENDING, 10-research-systems-to-06-services.md (TP-08, retention, events, idempotency keys), 09-research-product-to-06-services.md (R09-06-1 guardrails). 02 reply to S1/S2: NONE (no 02→06 file; no `services` in src/core/** or project.godot).

## Checkpoint WIP verified
The pre-account-change WIP (save epoch, save_bridge, sink enforcement, ack-elsewhere, unknown-state, mock billing additions) was reviewed and re-run: M1 and M2 stayed green before any further edits. Two WIP decisions were then corrected:
- WIP "sink saved then failed → remove ledger + repair commit" was unsafe (could leave reward-without-ledger on disk). Replaced by "keep ledger, mark `grant_unknown`, commit": never duplicate; player may lose that one reward.
- WIP bridge connected the epoch to any Events node; save.gd only emits on /root/Events, so the epoch is now counted only when events IS /root/Events, otherwise unknown (conservative handling).

## Completed (M3)
- `src/services/save_bridge.gd`: binds `Save.progress["services"]` + `Save.save_progress` + save epoch; stale-store guard (refuses after Save reload).
- `service_store.gd`: `save_epoch()`, `on_game_saved()`, `is_usable()`.
- Ads + purchases: grant-sink contract enforced (`contract_violation` signal, push_warning, counters; saved-then-failed / epoch-unknown → `grant_unknown`, never duplicate, consumable never consumed); stale store refused.
- Purchases: unknown/unspecified state never granted (flow → cancelled); acknowledged-elsewhere recorded without re-ack; still-owned granted consumable consumed on restore.
- Mock billing: `cancel_pending(product_id, notify)`, `acknowledge_elsewhere()`, owned query returns pending too.
- `src/services/consent/`: provider interface, disabled + mock adapters, `consent_flow.gd` state machine; wired into factory, Services node (`consent_flow`, ticked) and diagnostics.
- Tests: `tests/services/test_services_m3.gd` (11 groups) + `m3_child.gd` (process-death child). Fixed a vacuous M2 check (crash_iap B captured store ownership after the mock had consumed it).
- Docs: SERVICES.md v0.3 §11 (contract enforcement, billing transitions, consent flow, real-Save evidence table); ANALYTICS_EVENTS.md §6 retention limitation, §7 proposed events.
- Requests: 02 (S2 concrete wiring, single Save instance, optional S7), 01 (retention options A/B/C, proposed events, lost-reward default, 09 guardrails), new reply 06-services-to-10-research-systems.md. All QUEUED.

## Validation evidence (actual, this session)
- `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd` → EXIT=0, passes=502 failures=0.
- `... test_services_m2.gd` → EXIT=0, passes=130 failures=0.
- `... test_services_m3.gd` → EXIT=0, passes=161 failures=0: real_save_roundtrip 9, real_save_failed_commit 8, sink_saves_then_fails 21, bak_and_checksum_recovery 10, two_save_instances 2, migrate_keeps_services 6, stale_store_after_reload 6, consumable_real_save 12, process_death 18, consent_flow 41, billing_transitions 28. Events source: autoload. Isolated dir user://svc_m3_test removed after the run (verified absent).
- Process death report (user://services_m3_test_report.json): kill_before_commit → exit 0 (OS.kill), marker before_commit, coins 0 / ledger 0; kill_after_commit → coins 100 / ledger 1; sink_saves_then_kill → coins 100 / ledger 1.
- Mutations (each EXIT=1, file hash restored): ads saved-then-failed handling removed (8 failures), iap same (2), stale guard removed (5), not_required overriding denial (2), unknown state not rejected (3), ack-elsewhere re-acks (3), ads ledger written after sink (process_death sink_saves_then_kill → [100, 0]).
- Readback: after fetch, `git diff origin/main -- src/services tests/services` empty; no untracked owned files.

## Strongest reasons to reject / untested
- Game integration is NOT done: 02 has not registered Services or wired save_bridge (S1/S2), so the game itself still has no persisted service state. Evidence is against save.gd in isolation, Windows desktop.
- Android process death, storage failures and lifecycle are untested; OS.kill on Windows exits 0 (TerminateProcess), which the test accounts for.
- Two Save instances on one file lose one grant (last writer wins). Consistent, but a real loss; relies on 02 keeping one Save.
- Contract-violation path deliberately loses one reward instead of risking a duplicate (internal default, routed to 01).
- Mock adapters only (ads, billing, consent). battle_uid still missing (S4).

## Git
- M1: 17623c1, 9c20763, b7fa3c0. M2: 0f84461, 708bdb0, 7c43ebd. All PUSHED.
- Account-change checkpoint: handoff was PUSH_PENDING (01's staged files blocked the helper); superseded by this handoff.
- M3 code+tests: 5d61d0d44dd3522501f1a197d33921afe57770b8 `[Feat] 실제 Save 기반 보상 원자성·프로세스 종료 검증, 지급 계약 위반 차단, 동의 흐름과 결제 대기 취소·외부 확인 처리 추가` (20 files) → PUSHED origin/main (ls-remote = 5d61d0d…).
- M3 docs/requests/handoff: 078df2ecaa6b3f7b5f3157516f634c42b5c27b67 `[Docs] 서비스 M3 문서·연동 요청·리서치 회신과 상태 인수인계 갱신` (8 files) → PUSHED origin/main (ls-remote = 078df2e…).

## Next task (06) — M4
1. On 02 reply to S1/S2: rerun test_services_m3 against the integrated game boot (real autoload Save + Services), then change the claim from "isolated" to "integrated".
2. Service-level `save_recovered` / `ftue_step` only if 01 accepts them.
3. Restore UX contract for 04: per-result-code copy keys and a restore summary mapping (docs only + schema test), after approval.
4. Ask 07 to include test_services_m3 in regressions (process-death group takes ~5–10 s).
Dependencies: 02 S1/S2/S4/S6; 01 Q2–Q5 + retention decision.
