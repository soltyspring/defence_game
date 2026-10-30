# Rounds 1–10 (chapter 1) — PROVISIONAL, unvalidated until 02 headless sim / playtest
Data: data/rounds.json. P0 = rounds 1–3.

| # | New for player | New enemy | Enemy base HP | Scaling | Workers cap | Par | First-clear gold | Intent |
|---|---|---|---|---|---|---|---|---|
| 1 | hero move, melee, worker | grunt | 800 | 1.00 | 4 | 150 s | 100 | Tutorial; hero alone can hold, impossible to lose if player deploys anything |
| 2 | ranged, Slam | swarm | 1000 | 1.00 | 5 | 170 s | 140 | Learn Slam on swarm clumps; ranged behind melee |
| 3 | tank | spitter | 1200 | 1.05 | 6 | 200 s | 180 | First real composition check: tank front vs spitters; two base triggers |
| 4 | fast, Rally | brute | 1400 | 1.10 | 6 | 220 s | 220 | Armored enemy; melee spam stops working |
| 5 | — | boss_warlord (t=95) | 1800 | 1.15 | 6 | 260 s | 300 | Boss check; upgrade spending gate |
| 6 | siege | — | 2000 | 1.20 | 7 | 260 s | 340 | Brute-heavy; siege ×3 vs base |
| 7 | — | bomber | 2200 | 1.28 | 7 | 270 s | 380 | Kill bombers with ranged/fast before contact |
| 8 | Barrage | — | 2400 | 1.36 | 8 | 280 s | 420 | Swarm floods; AoE value |
| 9 | — | — | 2700 | 1.45 | 8 | 300 s | 460 | Endurance mix, 5 waves |
| 10 | — | boss_overlord (summons) + warlord at 50% | 3200 | 1.55/1.50 | 8 | 330 s | 600 | Chapter finale |

## R1–R3 detail (P0)
R1 tutorial order: tut_move_hero (t=0) → tut_deploy_unit (after first hero move or t=4) → tut_buy_worker (when supply ≥ 40 after first deploy) → tut_destroy_base (when any ally reaches 50% lane). Tutorial never pauses enemy trickle after step 2. Expected: greedy 3 workers by t≈17 s reaches 8.5 supply/s ≈ one melee per 3.5 s; enemy output ≈ 25 grunts / 120 s. Comfortable win.
R2: first swarm wave at t=20 bunches 3 swarms; Slam unlocked with 30 start energy + 3/s so it is ready at t≈4 s.
R3: spitter range 100 < ranged 110 so our archers out-range them; tank absorbs volleys. Base triggers at 60% and 25% create a comeback spike.

## Balance assumptions to verify (02 headless sim requested)
1. R1 win rate ~100% with any reasonable play; R2 ≥ 90%; R3 70–85% first try without upgrades, ~95% with 2 upgrades.
2. Round durations within ±25% of par for a competent bot (deploy cheapest affordable + 3 workers + Slam on cooldown).
3. Enemy alive count stays under cap 40 (queue policy otherwise); R8/R9 swarm floods are the stress cases.
Baseline unit economy (L1): melee 40 DPS/100 supply, fast 36, ranged 29, siege 17 (+splash, ×3 vs base), tank 600 HP/100 supply + armor 30.
