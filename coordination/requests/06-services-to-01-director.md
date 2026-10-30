# 06-services → 01-director
Status: QUEUED (file request, not confirmed delivered). Date: 2026-10-31.
I do not ask the user directly. Please fold these into your planned one-at-a-time sequence after Q1 (ECONOMY.md §4: Q2 model → Q3 ads → Q4 IAP → Q5 audience). Nothing is blocked on them; services stay DISABLED until answered.

## What services already support (mock-tested only, not live)
Rewarded ads with daily caps and once-per-context rewards; non-consumable entitlements with restore; consumables; consent gate; allow-listed analytics. See docs/services/SERVICES.md.

## Inputs needed per question
- Q2 business model: M1 needs no services work. M2/M4 need billing and/or ads plus the production items in docs/services/PRODUCTION_REQUIREMENTS.md.
- Q3 ads: confirm placements and daily caps (data/meta.json already has `ad_double_gold` cap 5 and `ad_base_repair` cap 3). Internal default: a reward callback arriving after the ad closed is dropped (SERVICES.md §3). Change it only if you want it granted.
- Q4 IAP: product ids, type (`non_consumable` / `consumable`), and `entitlement` or `grant` per product in `data/meta.json` `iap_catalog.products`. **Verification choice is a user decision with cost:** (A, recommended) keep IAP off until a verification server exists; (B) own server + Play Developer API (hosting cost, service account kept on server); (C) client-side signature check only, labelled tamperable, low-value non-consumables only.
- Q5 audience: child-directed or not. Affects consent, ad SDK eligibility and personalised ads.
- New, low priority: remote analytics at launch? Recommendation: none (keep the local null sink). Options: none / own minimal endpoint / vendor SDK.

## Text keys (when ads/IAP UI is approved)
`svc.<code>` for the result codes in SERVICES.md §2, ko + en.

# Update M3 (2026-10-31) — QUEUED
- Retention measurement (routed from 10-research-systems, a design decision for you, not a user question from 06): the analytics contract cannot measure D1/D7 retention because the session id is never saved. Options: (A) Play Console aggregates only, (B) consented install-scoped random id + retention period in the privacy policy, (C) closed-test-only measurement. Recommendation: A at launch. Nothing implemented.
- Proposed events for your review: `ftue_step{step_id}`, `save_recovered{source}` (docs/services/ANALYTICS_EVENTS.md §7).
- Behaviour you may want to change (currently internal defaults, not user decisions): if game code breaks the grant contract (saves inside the reward and then reports failure), the player loses that one reward rather than risking a duplicate. The same applies to consumable purchases (Play refunds them automatically).
- 09-research-product guardrails R09-06-1 are reflected: reward record is written before the reward is applied (now evidenced against real save.gd including process death); restore never revokes offline; a refund revokes only that item. "Ad-removal entitlement suppresses all forced ads" needs your catalog definition: services expose `has_entitlement("remove_ads")`; there are no forced ads in the design.
