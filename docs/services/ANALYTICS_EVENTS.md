# Analytics event contract and data inventory (owner: 06-services)
Schema version: 1
Code: `src/services/analytics/event_schema.gd` (allow-list), `analytics_service.gd` (gates). Tests: `tests/services/test_services.gd` (groups `analytics`, `analytics_doc_sync`).

Status: DRAFT. Analytics is DISABLED in every build. No remote sink exists, nothing leaves the device. Turning on remote analytics requires a user decision through 01 (vendor or own endpoint), a published privacy policy, Play Data safety answers and the INTERNET permission (04). See PRODUCTION_REQUIREMENTS.md §4.

## 1. Principles
- Collect only what answers a design question in ECONOMY.md §5 (round attempts/wins, duration, stars, upgrade choices, monetization funnel health).
- No identifiers that outlive the app process. No advertising ID, Android ID, device model, IP, account, name, email, free text or precise timestamps.
- Every parameter is a bounded int, bool, enum or short ID matching a strict pattern. Undeclared params reject the whole event.
- Gates in order: feature enabled → analytics consent `granted` (or `not_required` from a regional consent adapter) → schema validation → bounded queue (100, drop oldest).
- Events blocked by consent are dropped, not held for later. Withdrawing consent purges the queue.
- Durations are bucketed to 10 s and counts are clamped so rare values cannot single out a player.

## 2. Envelope
| Key | Type | Notes |
|---|---|---|
| `v` | int | schema version |
| `name` | enum | event name below |
| `params` | object | validated params only |
| `session` | 16 hex chars | random per app launch, never saved to disk, cannot link sessions |
| `seq` | int | order within session |
| `t_s` | int | whole seconds since session start (no wall-clock time) |

## 3. Events
| Event | Params | Question it answers | Producer (integration owner) |
|---|---|---|---|
| `session_start` | `app_version` (`^\d+\.\d+\.\d+$`), `build` (debug/release), `lang` (ko/en/other) | version adoption, locale split | 02 bootstrap |
| `round_start` | `round_id` (`^r\d{2}$`), `attempt` (1–99, clamped) | where players retry | 02 battle |
| `round_end` | `round_id`, `won` (bool), `stars` (0–3), `duration_s` (0–3600, clamped, 10 s buckets), `kills` (0–999, clamped) | difficulty curve vs ROUNDS.md par times | 02 battle |
| `upgrade_buy` | `upgrade_id` (`^up_[a-z_]{1,32}$`), `level` (1–10) | sink choices (ECONOMY.md §2) | 02 meta / 04 upgrades UI |
| `ad_offer` | `placement_id` (`^ad_[a-z_]{1,32}$`) | offer exposure (only if ads approved) | 04 UI |
| `ad_result` | `placement_id`, `result` (service result code) | fill/cancel/timeout rates | 06 RewardedAdService |
| `purchase_result` | `product_id` (`^[a-z0-9_.]{1,64}$`), `result` (service result code) | purchase funnel failures | 06 PurchaseService |
| `restore_result` | `result`, `restored` (0–50, clamped) | restore health | 06 PurchaseService |
| `error` | `area` (save/ads/billing/analytics/content/other), `code` (`^[a-z_]{1,32}$`) | crash-free error rates without stack traces | any owner |

Service result codes accepted by `result`: ok, disabled, unsupported, unknown_id, consent_required, offline, timeout, cancelled, no_fill, busy, cap_reached, already_granted, already_owned, pending, invalid_receipt, verification_unavailable, revoked, grant_failed, not_eligible, error.

No purchase amounts, currencies, order IDs or purchase tokens are ever sent.

`ad_result`, `purchase_result` and `restore_result` are emitted by `src/services/analytics/service_telemetry.gd` from service signals. `ad_offer` is emitted when 04 calls `Services.telemetry.offer_shown(placement_id, context_id)`, once per placement and context. Per app session the bridge sends at most 30 events of each name and 100 in total. The context id is used only for that de-duplication and never leaves the process.

## 4. Data inventory (whole game, as of this draft)
"Stored" = on device in the 02-owned save. "Sent" = leaves the device.

| Data | Where | Purpose | Sent? | Retention | Personal data? |
|---|---|---|---|---|---|
| Progress (unlocked round, stars, best times, coins, settings) | `user://save.json` (02) | gameplay | No | until uninstall | No |
| Consent choices + policy version | save `services.consent` (after 02 integration) | honour choices | No | until withdrawn / policy change | Choice record only |
| Rewarded-ad ledger: context id, placement id, local day | save `services.ads` | reward once only, daily caps | No | 7 days rolling | No |
| Purchase ledger: sha256(token) prefix, product id, state | save `services.iap` | one grant per purchase, restore | No | until uninstall | Pseudonymous purchase reference; raw token not stored |
| Entitlements (e.g. remove_ads) | save `services.iap` | unlock features | No | until revoked/uninstall | No |
| Analytics queue | memory only | batching | Not today (null sink) | process lifetime | No (see §1) |
| Ad SDK data (advertising ID, IP, device info) | ad SDK, NOT integrated | ad serving | Would be, by SDK | SDK policy | YES. Must be declared before any ad SDK ships |
| Store purchase data (order ID, token, account) | Google Play, NOT integrated | billing | Would be, by store/server | store policy | YES for server verification. Declare before billing ships |

## 5. Not yet decided (questions go through 01, one at a time)
1. Remote analytics at all? Options: none (keep local), own minimal endpoint, vendor SDK. Recommendation: none until after launch metrics are needed; ship with the null sink.
2. Child-directed audience (affects consent and ad SDK choice, ECONOMY.md Q5).

## 6. Known limitation: retention cannot be measured (recorded M3, from 10-research-systems request)
The session id is random per launch and never saved, so D1/D7 retention and return visits cannot be computed from these events. This is a deliberate privacy choice, not a bug. Options are routed to 01 as a design decision (coordination/requests/06-services-to-01-director.md, M3 update): (A) Play Console aggregate retention only, (B) consented install-scoped random id with a published retention period, (C) retention measured in a closed test only. No option is implemented.

## 7. Proposed events (NOT in the schema, not emitted)
- `ftue_step` with `step_id` (enum of tutorial steps defined by 01).
- `save_recovered` with `source` (`bak` | `fresh`), emitted by 02 when save.gd sets `recovered`.
Both follow §1 rules. They are added to `event_schema.gd` only after 01 accepts them and 02/04 own the emit points.
