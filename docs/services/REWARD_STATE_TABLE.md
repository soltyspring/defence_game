# Reward duplicate / loss state table (owner: 06-services)
Version: 1 (2026-10-31). Machine-checked: `tests/services/test_services_integration.gd` group `state_table_sync` requires every row ID below to exist in its table and vice versa.

Legend
- Disk = what the save file holds after the event: `coins` reward applied (+1 = 100 coins in tests), `ledger` = "already granted" record. Invariant for every row: **never coins without ledger** (that would allow a duplicate).
- Outcome: `once` = granted exactly once; `retry` = lost now, the same occasion can be granted once later; `lost` = lost for good (by design, never duplicated); `none` = never granted (correct).
- Isolated evidence = suite:group that passes today against mocks / the real save.gd **in isolation**.
- Game binding = `test_services_integration.gd` against the game's own Save/Services wiring. **BLOCKED until 02 completes S1/S2** (coordination/requests/06-services-to-02-engine.md). Rows marked `sim` are re-run in that suite on the autoload Save through save_bridge (simulated binding) so 02/07 can see the expected result before integration.

## Rewarded ads
| ID | Event | Disk after (coins, ledger) | Outcome | Isolated evidence | Game binding |
|---|---|---|---|---|---|
| R1 | Ad completed, save ok | 1, 1 | once | test_services_m3:real_save_roundtrip | sim |
| R2 | Ad completed, save fails, app keeps running, next routine save ok | 1, 1 | once | test_services_m3:real_save_failed_commit | sim |
| R3 | Ad completed, save fails, then crash/reload | 0, 0 | retry | test_services_m3:real_save_failed_commit | sim |
| R4 | Process killed after reward applied, before save | 0, 0 | retry | test_services_m3:process_death | sim |
| R5 | Process killed right after successful save | 1, 1 | once | test_services_m3:process_death | sim |
| R6 | Grant sink saves by itself and succeeds (contract violation) | 1, 1 | once, flagged | test_services_m3:sink_saves_then_fails | sim |
| R7 | Grant sink saves by itself, then process killed | 1, 1 | once | test_services_m3:process_death | sim |
| R8 | Grant sink saves by itself, then returns false | 1 or 0, 1 (`grant_unknown`) | lost (never duplicate), flagged | test_services_m3:sink_saves_then_fails | sim |
| R9 | Grant sink returns false without saving | 0, 0 | retry | test_services_m3:sink_saves_then_fails | sim |
| R10 | SDK sends reward/close callbacks twice | 1, 1 | once | test_services:ads_happy_and_once_only | — |
| R11 | Reward callback arrives after ad closed | 0, 0 | none (01 default, reversible) | test_services:ads_failures_timeouts | — |
| R12 | Two service instances on one store, same occasion | 1, 1 | once | test_services_m2:duplicate_two_instances | — |
| R13 | Two Save instances on one file | consistent | one grant lost (last writer wins) | test_services_m3:two_save_instances | 02 must keep one Save |
| R14 | Save reloaded while an ad is showing (stale store) | 0, 0 | retry (grant refused) | test_services_m3:stale_store_after_reload | sim |
| R15 | Main save corrupt, `.bak` restored | as in `.bak` (consistent) | grants after `.bak` → retry | test_services_m3:bak_and_checksum_recovery | sim |
| R16 | Restart / services set up again after grant | 1, 1 | once | test_services:ads_gates_caps_restart | — |

## Purchases (mock store only; no real billing exists)
| ID | Event | Disk after | Outcome | Isolated evidence | Game binding |
|---|---|---|---|---|---|
| P1 | Consumable verified, save fails, crash, restore | 1, 1 after restore | once (via restore) | test_services_m3:consumable_real_save | sim |
| P2 | Consumable sink saves, then returns false | ledger `grant_unknown`, never consumed | lost in game; store refunds | test_services_m3:consumable_real_save | — |
| P3 | Non-consumable, crash before save, restore | entitlement after restore | once | test_services_m2:crash_iap | — |
| P4 | Pending payment cancelled (silent or notified) | nothing | none | test_services_m3:billing_transitions | — |
| P5 | Purchase acknowledged on another device, restore | entitlement, acknowledged | once, no re-ack | test_services_m3:billing_transitions | — |
| P6 | Real-money purchase with no trusted verifier | nothing | none (never fake-verified) | test_services:purchase_verification | — |

## Disabled mode (must hold in every shipped build until the user approves monetization)
| ID | Check | Expected | Isolated evidence | Game binding |
|---|---|---|---|---|
| D1 | Default factory / Services node | mode `disabled`, all adapters disabled, `live.*` false | test_services:factory_config | integration:disabled_mode |
| D2 | 01 data flags turned on while mode is disabled | ads/purchases still `disabled` | test_services_integration:disabled_mode | integration:disabled_mode |
| D3 | Release build or `production` request | falls back to `disabled` | test_services:factory_config | integration:disabled_mode |
| D4 | Consent flow in default build | `unsupported`, no choice changed | test_services_m3:consent_flow | integration:disabled_mode |
| D5 | No production adapter, key or ID in src/services | none present | test_services:static_guards | integration:disabled_mode |
| D6 | Android export INTERNET permission (04/02 file, read-only check) | `false` while services are disabled | — | integration:disabled_mode |
