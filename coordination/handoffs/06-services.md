# 06-services handoff
Updated: 2026-10-31
Status: M1 COMPLETE. Service boundaries, state machines and DISABLED/MOCK adapters exist and pass headless contract tests. **No real ad network, store billing, verification server or remote analytics is integrated. Nothing is live.** Every build runs in `disabled` mode.

## Ownership acknowledged (OWNERSHIP.md "Eight-worker expansion")
Own only: src/services/**, docs/services/**, tests/services/**, coordination/status/06-services.md, coordination/handoffs/06-services.md, coordination/requests/06-services-to-*.md. Not mine: save/progression core (02), UI (04), economy/catalog/text data (01), Android export (04/02). User questions only via 01, one at a time.

## Instructions read / processed
BRIEF.md (all sections), OWNERSHIP.md, GIT_WORKFLOW.md (Publish-Task.ps1 only, explicit paths, Korean subject, no add ./-A/reset/rebase/stash/force), ENGINE.md v1.0, INTERFACES.md v1.0, DECISIONS.md, ECONOMY.md, RELEASE_DESIGN_REVIEW.md §3–4, data/meta.json, WINDOW_STABILITY.md, QUOTA_POLICY.md.
coordinator-to-06-services.md sections processed: (1) eight-worker expansion, (2) completion review gate, (3) window stability override, (4) 97% quota checkpoint/CPU guidance.
Last processed decisions: D1–D12 (all DEFAULT), Q1 PENDING. Monetization: D9 DEFAULT disabled, Q2 not asked → all adapters disabled/mock.

## Completed (M1)
- src/services/: result codes, clock/store/network boundaries, consent gate, config (reads 01's meta.json read-only), factory (modes disabled/mock/production→disabled), `services.gd` facade node (NOT registered as autoload).
- ads/: provider interface, disabled + scripted mock adapters, `rewarded_ad_service.gd` state machine (once per request and per context id, daily caps per local day, consent/offline gates before SDK, load/show timeouts, duplicate/late/stray callbacks ignored, grant sink + atomic commit contract).
- billing/: provider interface, disabled + mock adapters, verifier interface, `unavailable_receipt_verifier.gd` (production default, never approves), `mock_receipt_verifier.gd` (approves only environment "mock"), `purchase_service.gd` (purchase/pending/verify/grant/ack, restore, revoke on refund, ack retry, consumables, ledger keyed by token hash).
- analytics/: allow-listed schema v1, consent-gated bounded queue, null sink (default) and memory sink.
- tests/services/test_services.gd: 14 groups, 438 checks.
- docs/services/: SERVICES.md (architecture, state machines, coverage map), PRODUCTION_REQUIREMENTS.md (SDK/server/secret/permission requirements and the evidence gate), ANALYTICS_EVENTS.md (event contract + whole-game data inventory).
- Requests: 06-services-to-02-engine.md (S1 autoload, S2 save integration, S3 grant sinks, S4 battle_uid, S5 analytics producers), 06-services-to-04-client.md (U1–U5, after approval except U4), 06-services-to-01-director.md (inputs for Q2–Q5 + analytics question). All QUEUED, not confirmed delivered.

## Validation evidence (actual)
- `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd` → EXIT=0, `passes=438 failures=0 time_ms=79`; groups: factory_config 26, consent 13, ads_happy_and_once_only 16, ads_failures_timeouts 17, ads_gates_caps_restart 18, ads_grant_persistence 8, purchase_flows 38, purchase_verification 16, purchase_restore 21, purchase_consumable 11, analytics 32, analytics_doc_sync 32, static_guards 187, services_node 3. No WARNING/ERROR lines. Report: user://services_test_report.json.
- Mutation check: replaced the mock verifier's `environment != "mock"` gate with `false` → EXIT=1 with failures "production purchase not verifiable by mock" and "mock verifier gates on mock environment". Restored from backup; suite green again (run above).
- 02 `selftest.gd` → EXIT=1 caused only by foreign files (src/audio/audio_manager.gd missing preload, src/ui/hud_top.gd parse error); no errors in src/services. Reported FYI to 02.
- Two real bugs found and fixed by the tests during M1: duplicate store updates triggered a second acknowledge (fixed with an in-flight ack set, cleared on restore); a test dropped its grant-sink object and the service correctly refused to grant (test fixed).

## Strongest reasons to reject / untested claims
- Only mock adapters are tested. No real SDK callback ordering, Android lifecycle during a full-screen ad, Play Billing edge cases or device behaviour has been observed.
- "Reward once across restarts" depends on 02 integrating the store into the atomic save (S2). Until then service state is memory-only (factory warns `store_memory_only`).
- Late reward after ad dismissal is dropped by default (design trade-off, 01 may change).
- Daily caps can be reset by changing the device clock (accepted, no server).
- No production verification path exists, so IAP cannot go live without a user decision on verification (A/B/C in request to 01).
- `services.gd` lifecycle flush and `_process` ticking are only smoke-tested (no running main loop in tests).

## Git
- 17623c14e1b054d024e8029049b58d5fc373a93b `[Feat] 광고 보상·결제·복원·분석 서비스 경계와 비활성/모의 어댑터, 상태 머신 계약 테스트 추가` (32 files: src/services/**, tests/services/test_services.gd) → PUSHED origin/main; `git ls-remote origin main` = 17623c1…. A first helper invocation piped through `2>&1 | Select-Object` exited 1 right after fetch with no commit/staging; the identical second call succeeded.
- Docs/coordination commit: see status file / next handoff update (this file is part of it). First attempt was refused by the helper's `git diff --check` (trailing space in this file, line 41); I fixed it and unstaged only my 8 files (`git restore --staged`, no foreign files were staged), then retried.

## Next task (06)
M2 (owned, no external dependency):
1. `src/services/ads/rewarded_flow_policy.gd` helpers that turn 01's placement rules (`results_win`, `in_round_once_below_30pct`) into availability checks given a HudSnapshot/BattleResult, with tests, so 02/04 do not re-implement them.
2. Service-level analytics emission (`ad_result`, `purchase_result`, `restore_result`) wired inside 06 services, with tests.
3. A local debug panel data provider (read-only diagnostics dictionary) for 04/07.
4. On 02 reply to S1/S2: integration test using the real `Save` script with a temp `user://` path (crash between grant and save, `.bak` recovery keeps ledger consistent).
Dependencies: 01 decisions before any production adapter; 02 S2 before persistence claims.
