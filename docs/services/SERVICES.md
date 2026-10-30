# Services architecture: rewarded ads, purchases, entitlements, consent, analytics (owner: 06-services)
Version: 0.3 (2026-10-31, M3). Godot 4.7.2 / GDScript. Status: boundaries + DISABLED/MOCK adapters only.

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
  service_diagnostics.gd   read-only diagnostics snapshot (§9)
  save_bridge.gd           binds service state to 02's real Save node (§7.1)
  consent/  consent_provider.gd (interface), disabled_consent_provider.gd, mock_consent_provider.gd,
            consent_flow.gd (platform consent state machine, §5.1)
  ads/      ad_provider.gd (interface), disabled_ad_provider.gd, mock_ad_provider.gd, rewarded_ad_service.gd,
            reward_policy.gd (offer rules, §3.1)
  billing/  billing_provider.gd (interface), disabled_billing_provider.gd, mock_billing_provider.gd,
            receipt_verifier.gd (interface), unavailable_receipt_verifier.gd, mock_receipt_verifier.gd,
            purchase_service.gd
  analytics/ event_schema.gd, analytics_service.gd, analytics_sink.gd (null), memory_sink.gd,
             service_telemetry.gd (bounded service events, §8.1)
tests/services/test_services.gd      M1 contract tests
tests/services/test_services_m2.gd   M2 crash/persistence, duplicate, corrupt-state, policy, telemetry, diagnostics tests
tests/services/test_services_m3.gd   M3 tests against the REAL src/core/save.gd (isolated paths), process death, consent flow, billing transitions
tests/services/m3_child.gd           child process used by the process-death cases (not standalone)
docs/services/                    this file, ANALYTICS_EVENTS.md, PRODUCTION_REQUIREMENTS.md
```
Run tests (each exit 0 = pass): `tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd` (report `user://services_test_report.json`) and the same with `test_services_m2.gd` (report `user://services_m2_test_report.json`, optional `-- --only=group1,group2`). A group that aborts on a script error is reported as a failure.

## 2. Result codes (`service_result.gd`)
`ok, disabled, unsupported, unknown_id, consent_required, offline, timeout, cancelled, no_fill, busy, cap_reached, already_granted, already_owned, pending, invalid_receipt, verification_unavailable, revoked, grant_failed, not_eligible, error`. `not_eligible` = the offer policy (§3.1) says no in this situation.
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
- Grant (ledger-first, changed in M2): the service writes the ledger entry and daily count into the store, THEN calls `grant_sink(placement_id, reward, context_id) -> bool` (02-provided), THEN `store.commit()`. `false` from the sink → ledger and daily count are rolled back in memory, result `grant_failed`, the player can retry. Because the ledger is already in memory, any save that runs while the sink runs (even one the sink triggers itself) carries reward and ledger together. If the commit fails, `reward_granted(..., persisted=false)` fires and both stay in memory for the next successful save. **This holds only if the store's data lives inside the same atomic save as the reward (02 request S2). Not integrated yet; tested against a save double, not the real Save.**
- Before granting, the ledger is re-checked. A second service instance on the same store (e.g. `setup()` called twice) finishes with `already_granted` instead of granting again.
- Damaged service state (non-dictionary ledger entries, bad dates, non-numeric counts) is repaired at construction: corrupt ledger entries are kept (they still block their context) and re-dated to today so they age out.
- `reward` is opaque config from 01 data (`{"effect": "gold_mult_2", "where": "results_win"}`). The service does not interpret it.
- Personalised ads are requested only when `consent.personalized_ads_allowed()` (§5).
- Daily caps use the device's local calendar day. Clock changes can reset caps. This is an accepted exploit because there is no server (RELEASE_DESIGN_REVIEW.md §3).
- Lifecycle: the ad covers the app, so Godot gets focus-out/pause while SHOWING. Timeouts count `tick(dt)` time only. The service never pauses the battle; 02 already auto-pauses on focus loss.

### 3.1 Offer policy (`reward_policy.gd`)
Turns 01's placement rule (`reward.where` in data/meta.json) and the game situation into eligible/not plus a context id. Fail-closed: unknown rule, malformed data or missing `battle_uid` → not eligible.

| Rule | Situation (built by 02/04) | Eligible when | Context id | Constraint |
|---|---|---|---|---|
| `results_win` | `{kind:"result", result: BattleResult}` | `won` is bool true, `coins` > 0, valid `battle_uid` | `result:<battle_uid>` | none |
| `in_round_once_below_30pct` | `{kind:"battle", battle_uid, snapshot: HudSnapshot, ended: bool}` | battle not ended, 0 < base hp / hp_max < 0.30 | `rescue:<battle_uid>` | `max_stars: 2` (RELEASE_DESIGN_REVIEW.md §3; 02 applies it) |
API: `ads.offer_for(placement_id, situation)` → `{code, context_id, reason, constraints}` (policy then all §3 gates, no SDK call); `ads.request_for(placement_id, situation)` starts the ad. `battle_uid` must match `^[A-Za-z0-9_.:-]{1,64}$` and does not exist yet (02 request S4), so today every policy check returns `missing_battle_uid`. Rule semantics are 01's DEFAULT design, not a user decision.

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
- Consumables are ledger-first too: the ledger entry is written before `grant_sink` and removed again if the sink refuses.
- Before granting, an existing `granted` ledger entry for the token is honoured (second instance on the same store, or a duplicate update racing a verification): no second grant, only entitlement repair + acknowledge.
- `has_entitlement()` trusts an entitlement only when its ledger entry is `granted`. Malformed entitlement or ledger entries are dropped at construction and rebuilt by restore. Accepted risk: if the ledger itself is damaged, a still-unconsumed consumable can be granted again by restore. Local saves are not tamper-proof; this rejects damaged state, not a determined local editor.
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

## 7. Integration points (requests sent, not done; no replies as of M2)
- 02: register `Services` autoload after `Save`; call `Services.setup({"store": ServiceStore.new(Save.progress["services"], Save.save_progress)})` after every load; keep the `services` key through migrations; provide grant sinks, `battle_uid` and offer situations. See coordination/requests/06-services-to-02-engine.md (S1–S6).
- 07: add both service suites to regressions; `Services.diagnostics()` for reports. See coordination/requests/06-services-to-07-qa.md.
- 04: consent/settings UI, "watch ad"/"restore purchases" UI states per result code, Android plugins and export config when approved. See coordination/requests/06-services-to-04-client.md.
- 01: decisions listed in coordination/requests/06-services-to-01-director.md (one question at a time to the user).

## 8. Test coverage map
tests/services/test_services.gd (M1):

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

tests/services/test_services_m2.gd (M2). Persistence uses `SaveDouble`: game progress and the `services` section in one dictionary saved as one JSON string, mirroring INTERFACES.md §3. "Crash" = drop memory and reload the last saved string. This shows the service ordering is safe under that model; it is **not** evidence about the real `src/core/save.gd`.

| Requirement | Test group |
|---|---|
| Save fails during grant → neither reward nor ledger on disk, retry grants once; sink saving inside grant still persists ledger (ledger-first); 40-context randomised run (seed 6061, 30% save failures, 40% crash/reload, 5 ad scenarios) ends with coins == 100 × ledger entries | `crash_ads` |
| Consumable crash before commit → restore regrants once; committed-but-unconsumed → consumed, not regranted; sink-save + failed commit → no regrant; non-consumable rebuilt once by restore | `crash_iap` |
| Two live instances on one store: one ad grant per context, one consumable grant per token | `duplicate_two_instances` |
| Corrupt consent/ledger/daily/entitlement data: no crash, conservative blocking, untrusted entitlement, repair by purchase | `corrupt_store` |
| JSON reload (ints become floats): consent, caps, entitlements, already-owned survive | `json_roundtrip_types` |
| Offer policy rules, boundaries (exactly 30% not eligible), malformed input fail-closed, service integration, once per battle | `reward_policy` |
| Telemetry gated by default/consent, correct params, schema-valid, no ids/tokens, per-event (30) and total (100) caps, duplicate offer suppressed, does not change outcomes | `telemetry` |
| Diagnostics: nothing live by default, no tokens/keys/context/session ids, detached copy, read-only (no save) | `diagnostics` |

Mutation evidence (M2): six deliberate defects were each caught by these groups (no ledger-first, no ledger re-check, no IAP prior-grant check, policy threshold 0.31, telemetry uncapped, diagnostics leaking the ledger). Files were restored byte-identical afterwards.

### 8.1 Service telemetry (`analytics/service_telemetry.gd`)
Listens to `ads.finished`, `purchases.purchase_finished`, `purchases.restore_finished` and emits `ad_result`, `purchase_result`, `restore_result`. UI calls `telemetry.offer_shown(placement_id, context_id)` for `ad_offer` (once per placement+context). Caps per app session: 30 per event name, 100 total. Every event still passes the analytics gates, so with analytics disabled (default) nothing is recorded.

## 9. Diagnostics (`service_diagnostics.gd`, `Services.diagnostics()`)
Detached deep copy for debug overlays, QA and bug reports: mode, warnings, adapter kinds, `live` flags (`real_ads`, `real_billing`, `trusted_verifier`, `remote_analytics`; all false today), store persistence and commit counts, consent choices, per-placement granted-today vs cap, ledger size, entitlements, ledger counts by state, analytics/telemetry counters. Excludes purchase tokens, ledger keys, context ids and the analytics session id. Taking a snapshot never writes or saves.

## 10. Known limits (not solved by 06 alone)
- No real persistence until 02 S2. Factory warns `store_memory_only`; diagnostics shows `store.persistent=false`.
- `Services.setup()` during an active ad or purchase drops that in-memory session. The ledger prevents double grants; a lost session may need restore (IAP) or a new offer (ads).
- Mock adapters only. No real SDK callback order, Android lifecycle or Play Billing behaviour is observed.

## 11. M3 additions
### 11.1 Grant-sink contract: enforced, not just documented
Contract: a grant sink applies the reward **in memory** and returns true, or changes nothing and returns false. It must not save. Enforcement:
- The store exposes a save epoch (`ServiceStore.save_epoch()`), fed by `Events.progress_changed`, which save.gd emits after every successful save. A sink that saved is detected by an epoch change.
- Sink saved and returned true: safe (ledger-first). Flagged `ads_sink_saved` / `iap_sink_saved` (`contract_violation` signal, `push_warning`, `diagnostics.contract_violation`).
- Sink saved and returned false, **or** the store is persistent but has no epoch source: the outcome on disk is unknown. The service keeps the ledger entry (ads: `grant_unknown: true`; consumables: ledger state `grant_unknown`) and commits it. Never reward-without-ledger, so never a duplicate; the player may lose that one reward. A `grant_unknown` consumable is never regranted and never consumed, so Play refunds it after the acknowledgement window. Flagged `*_sink_saved_then_failed` / `*_failed_epoch_unknown`.
- Sink returned false without saving (epoch known): normal rollback, retry allowed.
- Stale store (Save.progress replaced by a reload after binding): `availability()` returns `error`, an in-flight grant is refused before the sink runs (`ads_stale_store` / `iap_stale_store`), and commits through the stale store return false.

### 11.2 Billing transitions
- Purchases whose state is neither `pending` nor `purchased` (e.g. a cancelled pending payment reported with an unspecified state) are never granted (`diagnostics.unknown_state`); a waiting flow finishes `cancelled`.
- A pending payment that is cancelled silently just stops being reported; nothing was recorded, so the product can be bought again. The mock owned-query now also returns pending purchases, as Play does.
- Non-consumable already `acknowledged` by the store (another device or a server): recorded as acknowledged, no redundant acknowledge (`diagnostics.ack_elsewhere`).
- A consumable that is already granted but still reported owned is consumed (the earlier consume did not complete).

### 11.3 Consent flow (`consent/consent_flow.gd`) — §5.1
```
IDLE --start()--> CHECKING --required--> FORM_REQUIRED --show_form()--> SHOWING_FORM --ok--> DONE
                     | not_required / obtained -> DONE        | dismissed / error / timeout -> FORM_REQUIRED
                     | offline / error / timeout -> DONE (nothing changed, ads stay blocked)
DONE --show_privacy_options()--> SHOWING_FORM;  any --withdraw()--> IDLE (all denied + platform reset)
```
The platform form covers ads purposes only; analytics consent stays with our own UI (04). `not_required` turns only `unknown` ads purposes into `not_required`; an explicit `denied` (including after withdrawal) is never overridden. Late or stray callbacks are ignored. Default build uses `disabled_consent_provider.gd` → `start()` returns `unsupported`. No UMP plugin is installed or approved.

### 11.4 Evidence against the real save.gd (`test_services_m3.gd`)
Uses `src/core/save.gd` unchanged, at `user://svc_m3_test/<case>/`, through `save_bridge.gd`.
| Case | Result |
|---|---|
| Round trip | one service commit = one real save; reloaded save blocks the context |
| Real save failure (directory blocks `save.json.tmp`) | `persisted=false`; disk has neither reward nor ledger; after reload the grant is retryable and lands once; without a crash the next routine save writes both |
| Sink saves then fails (with and without epoch) | disk has reward + ledger (`grant_unknown`); no retry, no duplicate after restart |
| Corrupt main file / checksum tamper | save.gd recovers `.bak`; recovered state satisfies coins == 100 × ledger; contexts lost with the main file are retryable once |
| v0 payload migration, pre-06 save | `services` survives `_migrate`; bridge adds an empty section |
| Two Save instances on one file | last writer wins; disk stays consistent but one instance's grant is lost entirely (02 must keep a single Save) |
| Reload during an ad | grant refused, disk consistent, fresh store works |
| Consumable: failed real save + crash; sink saves then fails | restore grants once / never regrants a `grant_unknown`, never consumes it |
| **Process death** (child Godot process killed with `OS.kill(own pid)`) | kill before commit → disk `[coins 0, ledger 0]`; kill after commit → `[100, 1]`; sink saved then kill → `[100, 1]`. Same test with ledger written after the sink (mutation) → `[100, 0]`, i.e. a duplicate on retry |
Not proven: that the game wires `save_bridge` this way (02 S2 unanswered), Android process death and storage behaviour, real SDK/billing. Windows desktop only.
