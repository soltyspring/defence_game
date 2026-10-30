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
