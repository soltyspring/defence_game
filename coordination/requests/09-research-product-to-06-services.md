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

## R09-06-2 Newest-review payment/ad incidents (2026-10-31, committed a4250bb 09:06 KST, SUCCESS_ANALYSIS.md §22)
New cases in the newest Archer Forest KO reviews: a paid pass bought twice with no reward delivered (2025-04-21), and an account suspended after refunding a mistaken purchase (2025-02-02). Your reply says reward-before-apply and refund-revokes-item-only are in place (not re-verified by 09). Remaining asks:
1. A test where the store reports a purchase but delivery fails mid-way, then on relaunch the item is delivered exactly once.
2. When no rewarded ad fills, the UI offers no dead end (pairs with R09-01-5 item 3).

## R09-06-3 Title/name clearance before store listing (2026-10-31, committed 5185e34 09:18 KST, SUCCESS_ANALYSIS.md §23)
- Theme A is decided (user, 09:03). 09 found no Play app with the name 빵집 기사단 / Bakery Knights (top search results only). The **trademark status is UNVERIFIED.**
- Ask: before any store listing/metadata, run KIPRIS (Korea) for the final Korean and English titles in classes 9 and 41, and record the result in the release config docs. Do not use "쿠키" or "오븐" marks (Devsisters' Cookie Run family) or real brands (곰표, bakery chains) in titles, IAP names or store text.
- Content rating questionnaire: mold enemies may be counted as disgust/horror imagery; answer according to 03's final art.

## R09-06-4 Store copy and rating inputs for theme A (2026-10-31 ~15:55 KST, §25)
- The first line of the store description should name the genre (e.g. "디펜스") because "빵" mostly signals tycoon games in the KR store.
- Name collision: none of 16 KR/US Play searches for our names found a title containing them (top 10, 2026-10-31). KIPRIS is still required for the final title (R09-06-3).
- Correction to R09-06-3: "Oven" in a unit name is fine. Avoid "OvenBreak/OvenSmash"-style marks and Cookie Run marks in titles and IAP names.
- Rating reference (Play KR display, 2026-10-31): Cookie Run Kingdom 전체이용가, 곰팡이 키우기 전체이용가, Food Fight TD 전체이용가, Plants vs. Zombies 7+, PvZ 2 12+, CatWar2 7+, Lucky Defense 12+. Answer the questionnaire from 03's final art (cartoon violence, no blood).

## R09-06-5 Store image order and first line (2026-10-31 ~16:55 KST, SUCCESS_ANALYSIS.md §32) — monetization excluded (Q2 보류)
Observed on 7 Play KR listings (5 lane/line defence, 2 food/bread, 2026-10-31, fetched 16:38 KST): 6 of 7 show real battle within the first 3 images; 3 put real play first; caption users state one mechanic per image. Apple's product-page doc says the first 1–3 screenshots appear in search results when there is no preview video.
Proposed order (yours to own in store metadata; captions and the first line need 01's wording):
1. real lane battle with both bases and HP numbers;
2. hero control + first skill;
3. economy choice (baker vs soldier card, "반죽");
4. roster;
5. boss;
6. result stars/upgrades (no shop).
First line of the short description: genre word + goal + both factions.
Do not use download or rank claims. Do not show prices or a shop.
Dependencies: X9 (03/04), X7/X8 (04), 03 retheme art. No store listing is to be created now.
