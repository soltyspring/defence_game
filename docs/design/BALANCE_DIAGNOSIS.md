# Balance diagnosis — bot losses r04–r10 (01-director)
Date 2026-10-31. All evidence is a headless engine sim with 02's unmodified battle_sim.gd + bot_player.gd. No human play. Raw data is in docs/design/balance/.

## Facts
| # | Finding | Evidence |
|---|---|---|
| F1 | 02's "r03–r09 cards/skills [null]" report is stale: committed data has explicit lists | byte-exact check of e42f809 and HEAD |
| F2 | The engine ran the random enemy_ai AND the trickle; spawns were 1.3–1.8× the designed schedule | 02 selftest stats vs the computed schedule |
| F3 | Disabling the AI and giving the LOW upgrade budget does not rescue r04–r10 (0/3 each) | paired_sim_2026-10-31.json (120 runs) |
| F4 | With enemy_scaling forced to 1.0: r04, r06, r08, r09 win; r05, r07, r10 still lose. Half scaling rescues only r06, r08 | probe_sim / confirm_sim json |
| F5 | With the AI off, the sim is deterministic: seeds 11/22/33 give identical results, so 3 seeds add no variance | confirm_sim, verify_files |
| F6 | With the AI off, an idle player survived r01/r02 to the 900 s timeout. Fixed by D18(b): base destroyed at 258 s | verify_files_2026-10-31.json |
| F7 | 02's bot never exceeds 3 workers and plays without upgrades, which does not match the intended progression (upgrade_budgets.json LOW: 6 levels before r04, 23 before r10) | bot_player.gd reserve logic; selftest |

## Current state (after D18, data at this commit)
r01–r03: competent 3/3 W, casual W, idle player loses by base destruction. r04–r10: competent 0/3, casual L; idle player loses at 103–149 s.

## Not concluded (do NOT retune from this yet)
The r04+ losses come from a bot with the wrong progression (F7) and no upgrades in the selftest. Enemy scaling is the leading suspect (F4), but r05 (boss), r07 (bomber) and r10 (overlord) fail even at scaling 1.0, so they have specific causes.
Next paired runs (requested from 02/07): same seed; upgrades LOW vs none; scaling data / 0.5 / 1.0; bot workers fixed at 3 / 5 / max; plus a per-round "cause of base death" breakdown (which enemy type dealt the base damage). Retune only after these, then rerun verify_files and the confirm configs.

## Update 2026-10-31 — LOW-budget clear check and retune (D23)
Script: docs/design/balance/low_budget_sim.gd.txt (02's competent bot, seed 11, deterministic with AI off; upgrade levels from upgrade_budgets.json, the same path as 10's probe_economy_flow LOW; cause of base damage = per-frame base HP loss split over enemies within range+40 px of the base, weighted by DPS; approximate).
Before (data at 5930430, LOW): r01–r03 W; r04–r10 L. Base damage mostly e_spitter + e_brute (e.g. r09 brute 1,902 / spitter 710; r10 brute 2,318 + overlord 179).
Candidates tried in memory (fix_I_overrides.json is the final one): A scaling ×0.5 + brute armor 3/hp 420 + spitter atk 7 → r07–r10 L; B same without scaling → r05, r07–r10 L; C scaling only → r05, r07–r10 L; D A + brute hp 360/atk 18 + spitter range 90 → r07, r10 L; E A + no brute in r07+ trickle → r07, r10 L; F D + E + slower r07+ trickle → r10 L; G/H F + overlord nerfs → H wins r10 at 750 s; I H + fewer r10 late brutes → all W.
After (I written to data; budget low / none / high):
| round | LOW | none | HIGH | idle loses (s) |
|---|---|---|---|---|
| r01 | W 129 | W 129 | W 130 | 258 |
| r02 | W 115 | W 115 | W 117 | 258 |
| r03 | W 218 | W 217 | W 241 | 192 |
| r04 | W 149 | W 246 | W 190 | 173 |
| r05 | W 416 (base 53%) | **L** 269 | W 395 | 186 |
| r06 | W 183 | W 309 | W 160 | 142 |
| r07 | W 447 (66%) | W 476 (14%) | W 622 | 107 |
| r08 | W 333 | W 457 | W 218 | 133 |
| r09 | W 441 (88%) | **L** 291 | W 779 | 113 |
| r10 | W 760 (64%) | **L** 276 | W 734 | 108 |
Reading: chapter 1 is clearable without replays at the LOW budget **for this bot**. Upgrades matter (r05, r09, r10 lose without them). Idle play loses everywhere by base destruction. 10's content-integrity probe: ERROR 0 / WARN 0 / INFO 0.
Still open, not hidden:
1. Duration: r05, r07, r09 and r10 run far past par +25%. r10 at 760 s is only 140 s from the 900 s limit. With HIGH upgrades, r07/r09 are SLOWER than with LOW, a non-monotonic bot artefact (it stalls the push), so time-based stars are not trustworthy from this bot.
2. One seed only. The sim is deterministic with the AI off, but small data changes could flip close rounds (r05 at 53%, r07 at 66% base). The bot's limits (3 workers, expensive-first card order) still apply. A human may find r04+ easier or harder.
3. Human difficulty is unmeasured (D11 pilot).
