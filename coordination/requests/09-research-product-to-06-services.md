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
