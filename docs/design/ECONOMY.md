# Economy, retention and monetization design — PROVISIONAL (01-director)
Data: data/economy.json, data/rounds.json rewards. Monetization is NOT decided; all hooks are `enabled:false`.

## 1. In-round economy (L1, no upgrades)
- Supply start 60–100 (by round), regen 4/s, cap 200→500 by round. Worker n (0-based) costs 40×1.3^n (40, 52, 68, 88, 114, 148), +1.5/s. Payback 27 s (1st), 45 s (3rd), 99 s (6th).
- Kill bounty: grunt 3, swarm 1, spitter 3, brute 10, bomber 4, bosses 60/100 supply. Keeps winners snowballing modestly; comeback comes from base triggers spawning in the enemy's late game, not rubber-banding the player.
- Energy start 30, regen 3/s, cap 100.

## 2. Meta economy (gold)
Faucets (chapter 1): first clears 3,140; first 3-star bonuses 780; replay wins 30% of first clear; kill gold ≈ 20–60 per round (50% on loss).
Sinks: 10 upgrade tracks, total 6,280 gold to max everything. First-clear + 3-star income ≈ 3,920 = 62% of the total upgrade cost, so a non-grinding player can afford only about 62% of all upgrade spending by R10, forcing choices (arithmetic on data, not measured behaviour); grinding replays or chapter 2 income covers the rest.
Intended spend checkpoints: before R3 ≈ 240 gold (2–3 upgrades); before R5 ≈ 640 (≈9 levels on the LOW path; D22); before R10 ≈ 2,500.
Upgrade curve: +8%/level units, +10% hero/base, cost ×~1.6 per level. Fully upgraded L5 unit = +32%. Enemy scaling reaches +55% by R10, so the gap is closed by roster breadth and skills, not stats alone.

## 3. Retention design (backlog order)
1. Stars per round + chapter star total (MVP).
2. Unlock cadence: something new in R1–R4, R6–R8, boss R5/R10 (MVP).
3. Instant retry and "next round" from results (MVP).
4. Daily first-win ×2 gold (disabled hook).
5. Chapter 2 biome + new hero at 30 stars (post-MVP).
6. Endless survival mode with leaderboard-free personal best (post-MVP, offline-friendly).
7. Achievements / collection codex (post-MVP).
No energy/stamina system planned: it hurts short-session replay and conflicts with the "fair progression" pillar. Reversible.

## 4. Monetization options (to be asked ONE decision at a time after Q1)
| Model | Fit | Notes |
|---|---|---|
| M1 Paid upfront (premium) | simple, no ads/IAP SDK | low install volume on Android Korea; no live ops revenue |
| M2 Free + optional rewarded ads + one-time "remove ads / supporter pack" IAP (provisional default for design) | best match for short-session offline defence | needs ad SDK + consent (UMP/GDPR, Korean privacy notice), billing library, restore purchases; 04 owns adapter |
| M3 Free + premium currency + random hero summons (gacha) | highest ceiling | Korean Game Industry Promotion Act amendment (enforced 2024-03-22) requires publishing probability info for paid random items; heavier balance/live-ops and legal/QA burden; conflicts with fair-progression pillar |
Planned question order: Q2 business model (M1/M2/M3) → Q3 ads allowed? which placements → Q4 IAP catalog/prices → Q5 target age rating / child audience (affects ad SDK and consent).
Design constraints regardless of model: no forced interstitials mid-round; rewarded ads only at results or once-per-round rescue; nothing purchasable that is required to clear chapter 1; purchases must be restorable (non-consumables) and server-free verification limitations disclosed by 04.

## 5. Economy telemetry needed later (privacy permitting)
Round attempts/wins, duration, stars, gold balance at round start, upgrade levels at loss. Local-only debug log first; any remote analytics requires user decision + privacy disclosure (04).

## 6. Max-out and L5 (D22)
L5 levels are a replay-only mastery tier (2,740 coins for all last levels). Chapter 1 must be clearable at the LOW first-clear budget. After every track is maxed, coins have no sink in MVP; a sink arrives with chapter 2 or cosmetics (B29).
