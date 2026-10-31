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
