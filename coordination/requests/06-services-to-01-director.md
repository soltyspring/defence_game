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

# Update M5 (2026-10-31) — release decision queue, QUEUED
docs/services/OPEN_DECISIONS.md lists the user decisions needed before any ads/billing release, in the order 06 suggests: U1 business model (your Q2) → U2 Play account personal/organisation → U3 privacy contact + policy URL → U4 audience/children (your Q5) → U5 ad network + EEA serving (if ads) → U6 products + verification A/B/C (your Q4, if purchases) → U7 remote analytics → U8 Korean legal review. Please ask **one at a time** and skip those made irrelevant by earlier answers. Each has the source requirement ID in docs/services/RELEASE_READINESS_SERVICES.md (official URLs, checked 2026-10-31).
Design decision for you (no user question): DD1 — a reward callback that arrives after the ad closed is currently dropped, but AdMob's rewarded policy requires delivering the promised reward on completion. 06 recommends granting when the occasion is still valid. Please decide before ads go live.
New facts worth knowing for planning: Play Billing v7 is past its 2026-08-31 deadline (v8 supported to 2027-08-31, latest 9.1.0); new apps must target API 36 since 2026-08-31; personal accounts created after 2023-11-13 need a 12-tester, 14-day closed test before production.

# Update M6 (2026-10-31) — QUEUED
- Theme A (빵집 기사단 vs 곰팡이 군단) was relayed to 06 as a user decision (coordinator-to-06-services.md, 2026-10-31 09:03 KST). DECISIONS.md still shows Q1 PENDING at the time of writing; please record it so every role reads the same source.
- docs/services/STORE_LISTING_DRAFT.md: ko/en title candidates (≤30 chars), short (≤80) and full descriptions, lint-checked. Unit names in it are your GDD §1 illustrative names, marked [이름 확정 대기]; please replace with your final themed names. Title choice added as OPEN_DECISIONS.md U9 (needs a trademark/name search first; one question at a time).
- docs/services/PRIVACY_POLICY_DRAFT.md: ko/en template for the current no-data build, with [광고/결제 활성화 시] blocks and [법률 확인 필요] marks; placeholders need U2/U3 answers.

# Update M9 (2026-10-31) — QUEUED
For U6 (purchase verification), 06 prepared: docs/services/NO_SERVER_MINIMUM.md (when client-only purchases are acceptable: single-player offline, nothing needed to finish chapter 1, low-value items, no gacha; risks table). 06 recommendation if the user wants purchases without a server: ONE non-consumable (supporter / remove ads) only, no consumables until a server exists. Sandbox test steps with user-only steps marked: docs/services/BILLING_SANDBOX_TEST_PLAN.md. Still one question at a time, after U1.

# Update M10 (2026-10-31) — QUEUED, data field for later
Consumable products in `data/meta.json` `iap_catalog.products` may carry `max_quantity` (int, default 1 = multi-quantity off). Purchases above it are refused and refunded by Play. Only relevant once a catalog exists (Q4).
