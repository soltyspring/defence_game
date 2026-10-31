# 09-research-product → 06-services
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §9, §11. Guardrails for whichever model 01/user picks (D9 still disabled). Review samples are biased (default sort, 20/app) and show complaint types, not rates.

## R09-06-1 Monetization guardrails from observed complaints
| Observed complaint (Play KO samples) | Guardrail / test |
|---|---|
| Rewarded ad watched, reward randomly not granted (Archero 2026-05-21) | Reward grant is idempotent and recorded before ad callback returns; test: kill app right after ad completion → reward present once |
| Ads still shown after paying VIP (Random Dice 2 2026-08-26) | Ad-removal entitlement suppresses ALL interstitial/forced ads incl. after restore |
| Package contents misunderstood (Archer Forest 2022-07-03) | Product text = exact granted items/quantities, shown before purchase |
| Refund → account suspended, re-pay demanded (Archer Forest 2022-09-21, 2023-01-05) | Voided purchase → revoke that item only; no account ban policy without 01/user decision |
| Reinstall lost paid ad-removal (Archer Forest 2022-12-26) | Restore purchases works offline-first from store entitlement |
Coordinate with 10 (R09-10-1) for ledger/schema side.

## R09-06-2 Newest-review payment/ad incidents (2026-10-31 ~10:15 KST, SUCCESS_ANALYSIS.md §22)
New cases in the newest Archer Forest KO reviews: a paid pass bought twice with no reward delivered (2025-04-21), and an account suspended after refunding a mistaken purchase (2025-02-02). Your reply says reward-before-apply and refund-revokes-item-only are in place (not re-verified by 09). Remaining asks:
1. A test where the store reports a purchase but delivery fails mid-way, then on relaunch the item is delivered exactly once.
2. When no rewarded ad fills, the UI offers no dead end (pairs with R09-01-5 item 3).

## R09-06-3 Title/name clearance before store listing (2026-10-31 ~10:40 KST, SUCCESS_ANALYSIS.md §23)
- Theme A is decided (user, 09:03). 09 found no Play app with the name 빵집 기사단 / Bakery Knights (top search results only). The **trademark status is UNVERIFIED.**
- Ask: before any store listing/metadata, run KIPRIS (Korea) for the final Korean and English titles in classes 9 and 41, and record the result in the release config docs. Do not use "쿠키" or "오븐" marks (Devsisters' Cookie Run family) or real brands (곰표, bakery chains) in titles, IAP names or store text.
- Content rating questionnaire: mold enemies may be counted as disgust/horror imagery; answer according to 03's final art.
