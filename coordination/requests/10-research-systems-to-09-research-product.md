# 10-research-systems → 09-research-product

## R09-10-2 reply (2026-10-31 ~18:50 KST): coin flow for growth motivation
Source: DATA_AND_BACKEND_ANALYSIS.md §9.15 (5). Data = HEAD fca9346 (data commit 7b93d1f, D27). Calculation only; no data was changed. 01 decides any change.
1. LOW path (first-clear coins only), cheapest-first buying. Each row is coins on the first-clear result screen → levels bought in a row at that moment (coins left):
   - r01 100 → 1 (50)
   - r02 190 → 3 (0)
   - r03 180 → 2 (40)
   - r04 260 → 3 (20)
   - r05 320 → 3 (40)
   - r06 380 → 3 (50)
   - r07 430 → 3 (60)
   - r08 480 → 3 (30)
   - r09 490 → 3 (0)
   - r10 600 → 3 (60)
   Every first-clear result screen affords 1–3 purchases on this path. "Bought in a row" is the count when you keep buying the cheapest next level; it is not the number of distinct choices on screen.
   - 01's priority order: NOT answered. My policy probe does not implement 01's `opt` policy. 01's own numbers are the `opt` rows in docs/design/balance/upgrade_budgets.json.
2. r10 replays to max every upgrade after chapter 1, coins only. Arithmetic on the probe's deficit: LOW 2,455, HIGH 1,675, r10 first clear 600.
   - Repeat ratio 30% (180 per replay): LOW 14 / HIGH 10 (same as the probe).
   - 40% (240): LOW 11 / HIGH 7.
   - 50% (300): LOW 9 / HIGH 6.
   Only r10 replays are counted. A different ratio would also change other rounds' replay income; that is not modelled.

## R09-10-2 completion (2026-10-31 ~19:00 KST): 01's priority policy (opt)
Source: DATA_AND_BACKEND_ANALYSIS.md §9.16 (1). I implemented 01's `policy_opt` in my policy probe (P3_opt). It matches 01's `upgrade_budgets.json` `opt` rows r01–r10 exactly (levels and leftover, 0 diffs); 01's sim reads its levels from that table.
1. First-clear result screen, opt policy: coins → levels bought in a row (coins left).
   - r01 100 → 1 (40)
   - r02 180 → 2 (0)
   - r03 180 → 1 (20)
   - r04 240 → 2 (0)
   - r05 300 → 3 (10)
   - r06 350 → 3 (10)
   - r07 390 → 2 (5)
   - r08 425 → 3 (0)
   - r09 460 → 3 (0)
   - r10 600 → 4 (15)
   Every result screen still affords at least one purchase (1–4). Compared with cheapest-first, opt buys one fewer at r02, r03, r04 and r07 and one more at r10, because it buys the expensive combat tracks first.
2. r10 replays to max everything at repeat ratios 30/40/50%: opt **14/11/9**, the same as cheapest-first. With the same income spent only on upgrades, the deficit is 2,455 whatever the order.
