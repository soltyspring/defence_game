# 09-research-product → 10-research-systems
Date: 2026-10-31 KST · ID: R09-10-1 · Type: boundary + evidence hand-off (no file edits requested in 09 paths)

## Boundary (proposal)
- 09 owns: what players see/feel, design, graphics/UI, monetization incentives, complaint taxonomy (docs/research/product/**).
- 10 owns: what data/server/transaction structure a feature needs, save/DB/LiveOps schema for OUR game (docs/research/systems/**).
- Neither claims competitor private DB/backend. 09 will not propose schemas; 10 please do not duplicate the design/visual analysis.
- Shared identity assumption: "궁수키우기" = com.GameDuo.MadArcher (Play KO title "아처키우기 : 방치형 디펜스"), PROVISIONAL, not user-confirmed. Q1 pending, no user questions.

## Server/persistence symptoms observed in Play KO review samples (2026-10-31, default sort, 20/app, NOT representative)
| Symptom | App (review date) | Possible systems implication for 10 to evaluate |
|---|---|---|
| Device migration lost ~90% items | royaldice (2026-08-24) | account link / cloud save scope |
| Reinstall → account reset incl. paid ad-removal | MadArcher (2022-12-26) | purchase restore independent of server save |
| "Data sync" prompt then chapter progress missing | archero (2019-07-12) | conflict resolution / monotonic progress |
| Home button / phone call resets run; slow reconnect kicks player, ticket lost | randomdice2 (2026-08-29, 2026-09-15) | in-run checkpoint, lifecycle resume |
| Refund → account suspension; double charge | MadArcher (2022-09-21, 2023-01-05, 2023-08-08) | purchase ledger, refund/voided purchase handling policy (06 too) |
| Rewarded ad watched, reward randomly not granted | archero (2026-05-21) | reward grant idempotency / server-side verification |
| Unannounced maintenance; server merge broke contested content economy | MadArcher (2023-09-18, 2024-06-15) | offline-first avoids; document if any online feature added |
| Cheats/macros unchecked in PvP/co-op | royaldice (2026-08-10) | out of scope offline; note risk if leaderboards ever added |

Full context: docs/research/product/SUCCESS_ANALYSIS.md §8, §11, §15 (E3).
Experiment E3 (resume after interruption) needs 02/04/07; 10 may add the save-schema side. Please acknowledge in your handoff.

## R09-10-2 Coin-flow experiment for growth motivation (2026-10-31 ~17:50 KST, SUCCESS_ANALYSIS.md §34.5)
Context: competitors show a growth screen after nearly every stage (§34.2). We give 100–600 first clear, 30% on repeat, a one-time 3★ bonus, and Lv2 costs 50–90 (HEAD 3343199).
Ask (calculation only, no data change):
1. On the LOW path, for each round's result screen: coins held and the number of upgrades affordable right now, under two buying policies (cheapest-first; 01's priority order).
2. r10 replays needed for max-out (D26: ~14 LOW / ~9 HIGH) if the repeat ratio were 30% / 40% / 50%.
Output: one table per policy in DATA_AND_BACKEND_ANALYSIS.md. 01 decides any change.
