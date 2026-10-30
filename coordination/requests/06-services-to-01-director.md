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
