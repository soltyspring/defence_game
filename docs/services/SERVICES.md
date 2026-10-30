# Services architecture: rewarded ads, purchases, entitlements, consent, analytics (owner: 06-services)
Version: 0.1 (2026-10-31). Godot 4.7.2 / GDScript. Status: boundaries + DISABLED/MOCK adapters only.

**Nothing here is live.** No ad network, store billing, verification server or remote analytics is integrated. The user has not approved a business model, products or placements (DECISIONS.md D9 DEFAULT, Q2 not asked). Every build runs in `disabled` mode. `mock` mode exists for tests and debug builds and contacts nothing. The tests prove the state machines and gates. They do not prove that any real SDK or store works.

## 1. Layout
```
src/services/
  service_result.gd        result codes (§2)
  service_clock.gd         clock boundary (local day for caps)
  service_store.gd         persistence boundary (02 integrates into the save, §7)
  network_probe.gd         reachability boundary (unknown by default)
  consent_service.gd       consent gate (§5)
  service_config.gd        reads 01's data/meta.json -> configs; modes (§6)
  services_factory.gd      builds a bundle for a mode
  services.gd              Node facade, intended autoload `Services` (02 decides)
  ads/      ad_provider.gd (interface), disabled_ad_provider.gd, mock_ad_provider.gd, rewarded_ad_service.gd
  billing/  billing_provider.gd (interface), disabled_billing_provider.gd, mock_billing_provider.gd,
            receipt_verifier.gd (interface), unavailable_receipt_verifier.gd, mock_receipt_verifier.gd,
            purchase_service.gd
  analytics/ event_schema.gd, analytics_service.gd, analytics_sink.gd (null), memory_sink.gd
tests/services/test_services.gd   headless contract tests
docs/services/                    this file, ANALYTICS_EVENTS.md, PRODUCTION_REQUIREMENTS.md
```
Run tests: `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd` (exit 0 = pass, report at `user://services_test_report.json`).

## 2. Result codes (`service_result.gd`)
`ok, disabled, unsupported, unknown_id, consent_required, offline, timeout, cancelled, no_fill, busy, cap_reached, already_granted, already_owned, pending, invalid_receipt, verification_unavailable, revoked, grant_failed, error`.
UI (04) maps each code to a text key. Suggested keys: `svc.<code>` in data/text (01 owns text).

## 3. Rewarded ads (`rewarded_ad_service.gd`)
```
IDLE --request(placement, context)--> LOADING --load ok--> SHOWING --closed--> IDLE
                                         | no_fill/offline/error        | show_failed -> error
                                         | load timeout (15 s) -> timeout | show timeout (120 s) -> timeout (ok if already earned)
```
- `availability(placement_id, context_id)` is cheap and makes no SDK call. UI shows the button only when it returns `ok`.
- Gate order: enabled → adapter supported → placement known → context non-empty → context not already rewarded → consent `ads` → known offline → daily cap → busy.
- `context_id` identifies one eligible occasion and makes the reward idempotent. Examples: `result:<battle_uid>` for results double-gold, `rescue:<battle_uid>` for base repair. 02 must supply a battle uid unique for at least 7 days (ledger is pruned after 7 local days).
- The reward is granted on the SDK `reward_earned` callback inside the active session, once. A second `reward_earned`, a second `closed`, callbacks after timeout and stray callbacks while idle are counted in `diagnostics` and ignored.
- `reward_earned` arriving after `closed` is dropped (result `cancelled`). Design trade-off: granting late rewards would need the original context to still be valid (e.g. the battle may be over). Reversible; 01 may choose otherwise.
- Grant: the service calls `grant_sink(placement_id, reward, context_id) -> bool` (02-provided). `false` → `grant_failed`, nothing recorded, the player can retry. `true` → ledger + daily count written into the store, then `store.commit()`. If the commit fails, `reward_granted(..., persisted=false)` fires. Reward and ledger stay together in memory and are written together by the next successful save, so on-disk state never has one without the other.
- `reward` is opaque config from 01 data (`{"effect": "gold_mult_2", "where": "results_win"}`). The service does not interpret it.
- Personalised ads are requested only when `consent.personalized_ads_allowed()` (§5).
- Daily caps use the device's local calendar day. Clock changes can reset caps. This is an accepted exploit because there is no server (RELEASE_DESIGN_REVIEW.md §3).
- Lifecycle: the ad covers the app, so Godot gets focus-out/pause while SHOWING. Timeouts count `tick(dt)` time only. The service never pauses the battle; 02 already auto-pauses on focus loss.

## 4. Purchases, entitlements, restore (`purchase_service.gd`)
### 4.1 Catalog
From `data/meta.json` `iap_catalog.products` (01-owned): `{"id", "type": "non_consumable"|"consumable", "entitlement" (non-consumable), "grant" (consumable)}`. Subscriptions are out of scope. The catalog is empty and disabled today, so every purchase returns `disabled`.

### 4.2 Purchase flow
```
IDLE --purchase(id)--> PURCHASING --store update(purchased)--> VERIFYING --ok--> grant + commit -> acknowledge/consume -> IDLE (ok)
PURCHASING: cancelled | offline | error | unknown_id | already_owned | pending | timeout (180 s)
VERIFYING : invalid_receipt | revoked | verification_unavailable (incl. 30 s timeout) | grant_failed
RESTORING : restore() -> query owned -> verify each -> rebuild entitlements -> restore_finished(summary)
```
- `pending` (slow payment methods) is never granted. When the store later reports it as purchased, the unsolicited update goes through the same path and is granted once.
- A purchase that completes after our timeout (store answered late) is also processed by that path.
- Duplicate store updates: one grant, one acknowledge (an in-flight set prevents double ack within a session).
- Ledger key = first 32 hex chars of sha256(purchase token). Raw tokens are never stored by 06.
- Non-consumable → entitlement `{product_id, key, granted_at}`, then acknowledge. Consumable → `grant_sink(product_id, grant, key) -> bool` (02), then consume. `grant_failed` → not consumed or acknowledged, so the store keeps it and a later restore retries the grant.
- Acknowledge failure keeps the entitlement. The next restore retries the acknowledgement because the store reports the purchase as unacknowledged.

### 4.3 Restore
- `restore()` queries currently owned purchases and verifies any not in the ledger.
- A failed or offline query, or a timeout, never revokes anything (cached entitlements stay).
- A successful query that no longer lists a granted entitlement revokes it (refund). Config `revoke_missing_on_restore` (default true).
- Summary: `{code, restored, already, invalid, unverified, revoked, pending}`.

### 4.4 Verification: honest limits
- `unavailable_receipt_verifier.gd` is the production default. It always answers `verification_unavailable`, so **no real-money purchase can be granted until a trusted verifier exists**. An unacknowledged Play purchase is refunded automatically after the acknowledgement window (3 days per Google's docs at time of writing), so the user is not charged for nothing.
- `mock_receipt_verifier.gd` approves only purchases whose `environment` is `"mock"` and whose token matches the mock derivation. It answers `verification_unavailable` for any `"production"` purchase. A static test guards this.
- No local "signature check passes = verified" shortcut is provided. On-device checks of Play's signed data need the app's public licence key and are weaker than server checks. If 01/user chooses that trade-off it must be labelled as client-side verification. See PRODUCTION_REQUIREMENTS.md §2.

## 5. Consent (`consent_service.gd`)
- Purposes: `ads`, `ads_personalized`, `analytics`. Values: `unknown` (default, blocks), `granted`, `denied`, `not_required` (only a regional consent adapter may set it).
- Audience: `unknown` (default) | `general` | `child`. Personalised ads need audience `general` + ads + ads_personalized consent. `child` blocks all ads unless `child_ads_allowed` (off; needs a Families-certified SDK and a user decision).
- Choices are stored with a privacy policy version. A version bump resets all choices to `unknown`.
- `withdraw_all()` for the settings "reset privacy choices" action. Analytics withdrawal purges the queue.
- No consent UI exists. 04 owns it (request sent). A UMP-style platform adapter would call `apply_external()`.

## 6. Modes and release configuration (`service_config.gd`, `services_factory.gd`)
| Mode | When | Adapters | Features |
|---|---|---|---|
| `disabled` | default, every build | disabled ads/billing, unavailable verifier, null sink | all off |
| `mock` | debug build AND `allow_mock=true` | mock ads/billing/verifier, memory sink | follow 01 data flags (currently all false); tests inject overrides |
| `production` | requested | not implemented | falls back to `disabled` with warning `production_unavailable` |
Release builds (`OS.is_debug_build() == false`) refuse mock mode. No production config keys, ad unit IDs, licence keys or server URLs exist in source; when they exist they come from export-time configuration owned by 04 (never committed).

## 7. Integration points (requests sent, not done)
- 02: register `Services` autoload after `Save`; call `Services.setup({"store": ServiceStore.new(Save.progress["services"], Save.save_progress)})`; keep the `services` key through migrations; provide grant sinks and a battle uid. See coordination/requests/06-services-to-02-engine.md.
- 04: consent/settings UI, "watch ad"/"restore purchases" UI states per result code, Android plugins and export config when approved. See coordination/requests/06-services-to-04-client.md.
- 01: decisions listed in coordination/requests/06-services-to-01-director.md (one question at a time to the user).

## 8. Test coverage map (tests/services/test_services.gd)
| Requirement | Test group |
|---|---|
| Disabled by default, mock refused in release, production falls back, follows 01 flags | `factory_config` |
| Consent unknown blocks, audience, policy version reset, withdrawal | `consent`, `analytics` |
| Reward once only (duplicate earned/closed, same context, stray callbacks) | `ads_happy_and_once_only` |
| Cancel, no fill, SDK offline, show fail, load/show timeouts, late reward, busy | `ads_failures_timeouts` |
| Consent/offline gates before SDK, daily cap per placement and day, restart, pruning | `ads_gates_caps_restart` |
| Grant sink refusal, commit failure keeps memory consistency | `ads_grant_persistence` |
| Purchase cancel/offline/error/unavailable item/already owned/pending/duplicate/timeout+late success | `purchase_flows` |
| Invalid receipt, production purchase never approved, unavailable verifier, verifier timeout, revoked | `purchase_verification` |
| Restore after reinstall, idempotent, offline/timeout keep, refund revokes, ack retry, forged owned | `purchase_restore` |
| Consumable grant once, consume, sink failure retry | `purchase_consumable` |
| Analytics gates, schema rejects, bucketing, bounded queue, send failure, session id not persisted | `analytics` |
| Doc lists every event/param | `analytics_doc_sync` |
| No device IDs, ad unit IDs, keys or URLs in src/services; verifier gate present | `static_guards` |
