# 06-services → 04-client
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.
Context: docs/services/SERVICES.md, PRODUCTION_REQUIREMENTS.md, ANALYTICS_EVENTS.md. Ownership note: tests/services/** is 06-owned (eight-worker expansion).
01 asked for no visible ad/IAP UI until the user decides (01-director-to-04-client). Everything below is for AFTER approval, except U4 which is input you can use now.

## U1 UI states from service result codes (after approval)
- Show a "watch ad" button only when `Services.ads.availability(placement_id, context_id) == "ok"`. Call `request()` and wait for `Services.ads.finished(request_id, placement_id, code)`.
- Purchases: `Services.purchases.availability(product_id)`, `purchase()`, then `purchase_finished(product_id, code)`. Required: a "Restore purchases" button calling `restore()` and showing `restore_finished(summary)`.
- Map codes to text keys `svc.<code>` (01 owns data/text). `pending` needs a "payment pending" message; `verification_unavailable` needs "could not confirm purchase, try Restore later"; `already_owned` should suggest Restore.

## U2 Privacy settings (after ads or analytics approval)
A settings entry that calls `Services.consent.set_choice(purpose, "granted"|"denied")` and `withdraw_all()`. Purposes: `ads`, `ads_personalized`, `analytics`. Defaults are `unknown` = blocked.

## U3 Android export (after approval only)
Plugin install (ads/billing candidates in PRODUCTION_REQUIREMENTS.md §1–2), INTERNET and AD_ID permissions, app/ad unit IDs and licence key in git-ignored export config handed to 02's boot `Services.setup()`. Not before approval; INTERNET stays off.

## U4 Privacy disclosure input (usable now)
ANALYTICS_EVENTS.md §4 is a data inventory for the Play Data safety form and privacy policy draft. Current honest answer: the game collects and shares no data. That changes the moment an ad SDK, billing or remote analytics ships.

## U5 Optional
A native connectivity check could back `src/services/network_probe.gd` (today it reports `unknown`). Low priority.

# Update M2 (2026-10-31) — still QUEUED, after approval only
- Offer buttons: prefer `Services.ads.offer_for(placement_id, situation)` (policy + gates, no SDK call). Show only on `code == "ok"`. Treat `not_eligible` as "do not show". The `reason` field is for logs, not players.
- When an offer becomes visible, call `Services.telemetry.offer_shown(placement_id, context_id)`. It is de-duplicated and gated by analytics consent.
- Debug overlay: `Services.diagnostics()` returns a detached, JSON-safe snapshot without tokens or ids.

# Update M5 (2026-10-31) — QUEUED, input only (no work until the user decides)
docs/services/RELEASE_READINESS_SERVICES.md §2 lists items in your area: B8 purchase-received UI, B9 Gradle build for billing plugins (export_presets.cfg:25 is false), A1 reward disclosure/opt-in UI, A2 privacy-options button, V2 in-app privacy policy link (required for every release, even with no data collected), C1 confirm exported targetSdk ≥ 36 (export_presets.cfg:31 is empty, engine default unverified).

# Update M6 (2026-10-31) — QUEUED
- Privacy policy template: docs/services/PRIVACY_POLICY_DRAFT.md. Play requires a link or the text inside the app (V2). Suggest a "개인정보처리방침 / Privacy Policy" entry in settings opening `{{PRIVACY_POLICY_URL}}` once the user supplies hosting (OPEN_DECISIONS.md U3).
- Store listing draft for screenshots/feature graphic captions: docs/services/STORE_LISTING_DRAFT.md. Screenshots must show the real build (Metadata policy).

# Update M9 (2026-10-31) — QUEUED, input only (no install before user approval)
Billing plugin candidates (checked 2026-10-31, both MIT, both Billing 9.1.0): GodotGooglePlayBilling 3.3.0 (the plugin the Godot docs link) and AndroidIAPP v2.2. Both need the Android Gradle build (export_presets.cfg:25 is false today). When approved, please verify on a real export: merged manifest contains com.android.vending.BILLING and com.google.android.play.billingclient.version, and which purchase fields (signature, original JSON, quantity) the plugin exposes. Details: docs/services/BILLING_PLUGIN_CANDIDATES.md, setup steps S7/S10 in BILLING_SANDBOX_TEST_PLAN.md.
