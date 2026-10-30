# 06-services handoff
Updated: 2026-10-31 (M2)
Status: M2 COMPLETE. **No real ad network, store billing, verification server or remote analytics is integrated. Nothing is live.** Every build runs in `disabled` mode; `production` mode falls back to disabled. Monetization decisions remain pending with the user (via 01).

## Ownership acknowledged (OWNERSHIP.md "Eight-worker expansion")
Own only: src/services/**, docs/services/**, tests/services/**, coordination/status/06-services.md, coordination/handoffs/06-services.md, coordination/requests/06-services-to-*.md. Not mine: save/progression core (02), UI (04), economy/catalog/text data (01), Android export (04/02). User questions only via 01, one at a time.

## Instructions read / processed (M2)
coordinator-to-06-services.md: all 4 sections (eight-worker expansion, completion review gate, window stability, quota checkpoint) re-read at M2 start; unchanged since M1. coordination/QUALITY_REVIEW.md (findings must be observable → owner fix → recheck; 02/05/06 fix measured problems in owned paths). docs/design/QUALITY_BAR.md row 10 (rewarded ads must deliver the promised reward, opt-in). DECISIONS.md D1–D12 DEFAULT, Q1 PENDING (no monetization decision). Quota usage.json 85.85% at 07:18:33, no triggered.json. Window: work continued in the same window, nothing closed or restarted.
Replies to my requests: none found (no 02/04/01/07 → 06 files).

## M2 review of pushed M1 tests: gaps found
1. No crash/persistence model: M1 never reloaded state from a saved copy between grant and commit.
2. **Defect (fixed):** the ad grant wrote the ledger AFTER calling the grant sink. If the sink (or anything during it) saved, the reward reached disk without the ledger, and after a crash the same context could be rewarded again. Same order for consumables. Reproduced by `crash_ads` B (got ledger 0, want 1; second grant `ok`, want `already_granted`).
3. **Defect (fixed):** two service instances on one store (e.g. `setup()` twice) could both grant the same consumable token (got 2, want 1). Fixed with a prior-grant check in `purchase_service._grant`; ads gained an `already_granted` finish.
4. **Defect (fixed):** damaged service data (non-dictionary ledger/entitlement entries, non-numeric counts) caused script errors ("Nonexistent function 'get' in base 'String'") and a corrupt entitlement was trusted. Fixed with `_sanitize()` on construction and ledger-backed `has_entitlement()`.
5. No JSON round-trip check (ints come back as floats from the real JSON save). Added; it passed without code changes.
6. Test runner weakness: a group that crashed mid-way was still reported PASS. Both runners now require each group to reach its end (`group aborted` failure otherwise).
Same failing scenarios re-run after fixes: all pass (see validation).

## Completed (M2)
- `src/services/ads/reward_policy.gd`: fail-closed offer rules for 01's `results_win` and `in_round_once_below_30pct` (exact 30% not eligible, needs `battle_uid`, rescue reports `max_stars: 2`). `ads.offer_for()` / `request_for()` combine policy and all service gates without SDK calls. New result code `not_eligible`.
- `src/services/analytics/service_telemetry.gd`: emits ad_result / purchase_result / restore_result from service signals and ad_offer via `offer_shown()` (de-duplicated). Caps: 30 per event, 100 total per session. Still gated by analytics enabled + consent; disabled by default.
- `src/services/service_diagnostics.gd` + `Services.diagnostics()`: detached JSON-safe snapshot, `live.*` flags (all false), no tokens/ledger keys/context ids/session id, never saves.
- tests/services/test_services_m2.gd: crash_ads (incl. seeded 40-context property run with save failures and crash/reloads), crash_iap, duplicate_two_instances, corrupt_store, json_roundtrip_types, reward_policy, telemetry, diagnostics.
- Docs: SERVICES.md v0.2 (§3 ledger-first, §3.1 policy, §4 entitlement trust, §8 coverage incl. M2, §8.1 telemetry, §9 diagnostics, §10 known limits); ANALYTICS_EVENTS.md (telemetry bridge, `not_eligible`).
- Requests: 02 update (S2 ledger-first + requested real-Save crash acceptance test; S6 offer situations), 04 update (offer_for, offer_shown, diagnostics; after approval), new 06-services-to-07-qa.md (Q1 regressions, Q2 non-proofs, Q3 diagnostics). All QUEUED.

## Validation evidence (actual)
- `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd` → EXIT=0, passes=462 failures=0 (14 groups; static_guards now scans 25 service scripts).
- `... -s res://tests/services/test_services_m2.gd` → EXIT=0, passes=129 failures=0: crash_ads 11, crash_iap 9, duplicate_two_instances 6, corrupt_store 8, json_roundtrip_types 5, reward_policy 42, telemetry 26, diagnostics 22. No ERROR/WARNING lines. Property run: seed 6061, 40 contexts, coins on disk == 100 × ledger entries. Reports: user://services_test_report.json, user://services_m2_test_report.json.
- Mutation checks (each made test_services_m2 EXIT=1; file restored, hash identical): ads without ledger-first (2 failures in crash_ads), ads without ledger re-check (2 in duplicate_two_instances), IAP without prior-grant check (1), rescue threshold 0.31 (1 boundary failure), telemetry cap removed (3), diagnostics leaking ledger (1).
- Readback: after `git fetch`, `git diff origin/main -- src/services tests/services` is empty; `git cat-file -p origin/main:src/services/ads/reward_policy.gd` shows `RESCUE_HP_RATIO := 0.30`.

## Strongest reasons to reject / untested claims
- Cross-save atomicity is NOT proven. Crash tests use a save double (progress + services in one JSON string). The real src/core/save.gd has no `services` section and Services is not registered (02 S1/S2 unanswered). I requested a real-Save crash acceptance test from 02.
- `battle_uid` does not exist (02 S4), so in a real build every policy check returns `missing_battle_uid`. Policy rules are 01 DEFAULT design, not user decisions.
- Only mock adapters. No real SDK callback order, Android lifecycle during a full-screen ad, Play Billing behaviour or server verification has been observed.
- Accepted risks: device clock changes reset daily caps; a damaged ledger can let restore regrant one unconsumed consumable; `setup()` during an active session drops that session (no double grant).
- If a consumable grant sink saves and then returns false, the rollback removes the ledger in memory but a ledger-less save could already be on disk. Contract says sinks must not save; not separately tested.

## Git
- M1: 17623c14e1b054d024e8029049b58d5fc373a93b, 9c207630e2049befa9a0e7aec2269f88dedf4620, b7fa3c094a5128aa0a695f80128980d9b71b200e (all PUSHED).
- M2 code+tests: 0f8446199154e3ee0d916a10e019b069f3e18414 `[Feat] 광고 보상 정책·서비스 텔레메트리·읽기 전용 진단 추가와 크래시·중복 지급·손상 상태 결함 수정` (27 files) → PUSHED origin/main (`git ls-remote` = 0f84461…).
- M2 docs/requests/handoff: next commit (SHA recorded in status after push).
- Helper note: call Publish-Task.ps1 without stderr redirection.

## Next task (06) — M3
1. When 02 answers S1/S2: integration test against the real `src/core/save.gd` with a temp `user://` path (failed save between sink and commit, `.bak` recovery), then update the claim.
2. Otherwise (no dependency): consent state machine for a UMP-like platform flow (`consent_provider.gd` interface + disabled/mock adapters: info update, form required/not required, form error, offline), with tests.
3. Billing: model Play's "pending purchase cancelled" and "purchase acknowledged elsewhere" updates in the mock and verify the state machine.
Dependencies: 02 S1/S2/S4/S6; 01 Q2–Q5 + analytics decision before any production adapter.
