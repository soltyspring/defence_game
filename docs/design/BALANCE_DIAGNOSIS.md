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

## Update 2026-10-31 (2) — multi-seed check and length retune (D24)
Script docs/design/balance/multi_seed_sim.gd.txt + summarize_multi_seed.py. Seeds 1–5, budgets none/LOW/HIGH, plus an idle player and a late starter (r01).
**The sim is deterministic with the AI off.** Varying the sim seed alone gives identical runs (F5). Seed variance is therefore injected as bot timing noise (start U(0,3) s, per-decision U(0,0.35) s). This stands in for human reaction variance; it is not a human model.
Before (multi_seed_2026-10-31_before.md): r10 LOW only 3/5 W (worst base 0) and HIGH 4/5. The single-seed D23 claim "10/10 W" was fragile. r05 LOW 5/5 but worst base 0.14 and median 368 s; r09 LOW 410 s; r10 681 s.
After (multi_seed_2026-10-31_after.md): every round LOW 5/5 W and median ≤ 1.25 × par (r10 par now 380). Worst LOW base: r05 0.40, r10 0.67, others 1.00. Without upgrades: r10 1/5, everything else 5/5. Idle loses everywhere (107–260 s). r01 late starter (45 s): 5/5 W, no base damage (tutorial, D24a).
Still weak evidence: one bot policy; timing noise only; the "none" budget wins most rounds, so upgrades are only proven necessary for r10. r02–r04 put almost no pressure on an active bot's base. Human pilot needed (D11).

## Update 2026-10-31 (3) — r01 opening, L5 costs, r10 (D25, D26)
r01 variants (5 seeds, no upgrades, plus an idle player and a 45 s late starter; data in memory):
| variant | change | competent | late45 | base hit before 90 s |
|---|---|---|---|---|
| P (applied) | lane 1100, wave 1 at 12 s ×3, wave 2 40 s ×4, wave 3 75 s ×4, trickle 6 s | 5/5 W, wave-1 clear 37–47 s | 5/5 W | 0/5 |
| Q | wave 2 35 s ×6 | 5/5 W | 5/5 W | 1/5 (late) |
| R | lane 1000, earlier waves | 5/5 W | 5/5 W | 0/5 |
| S | wave 2 45 s ×9 | **1/5 L** | **5/5 L** | when hit, collapse |
| T | wave 2 ×12 | **4/5 L** | 4/5 L | collapse |
| U | wave 2 ×7 | 1/5 L | 4/5 L | collapse |
| V | S + enemy atk ×0.5 | 5/5 W | 5/5 W | 0/5 |
Reading: once grunts reach the base, the base falls; there is no small-hit middle state in data. X11 R1 is not met.
Full check after D25/D26 (multi_seed_2026-10-31_d25.md + _d25_r10.md for r10 with enemy base 2000): every round LOW 5/5 W, every LOW median ≤ 1.25 × par. Worst LOW base: r02 1.00, r03 1.00, r04 1.00, r05 0.40, r10 0.69. r02–r04 never hit an active bot's base: pressure there is low (open). Without upgrades only r10 loses (1/5 W). Upgrades matter weakly (open, Codex finding a).

## Update 2026-10-31 (4) — upgrade-meaning curve (D27)
Policies: none; LOW = first-clear coins, cheapest first (10's path); opt = first-clear coins, combat priority (melee > hero > ranged > tank > supply > fast > siege > worker > energy > base; upgrade_budgets.json `opt`).
Sweep (r02–r05, 5 seeds; candidate overrides in memory):
| cand | change | r02–r04 LOW worst base | r05 none | r05 LOW | r05 opt |
|---|---|---|---|---|---|
| A | scaling 1.2/1.25/1.25/1.3 | 1.00 | 2/5 | **1/5** | 4/5 |
| B | 1.35–1.5 | r02 0.00 (a loss) | 0/5 | 0/5 | 0/5 |
| C | 1.5–1.7 | losses | 0/5 | 0/5 | 0/5 |
| D | A + upgrades +15%/L | 1.00 | 0/5 | 3/5 | 4/5 |
| E | D + tower 30 (enemy mult ×0.5), r02–r04 1.4–1.45 | 1.00 | 2/5 | 3/5 | 5/5 |
| F (applied) | E + r05 1.25 | 1.00 | 3/5 | 5/5 | 5/5 |
| G | F + r02–r04 1.65–1.7 | losses (r02 2/5) | 5/5 | 5/5 | 5/5 |
| H | F + r02–r04 1.5–1.55, r05 1.3 | r02 0.00 (a loss) | 3/5 | 5/5 | 5/5 |
r05 10 seeds: scaling 1.25 → none 5/10, LOW 10/10 (worst 0.38); **1.3 (applied) → none 4/10, LOW 10/10 (worst 0.11), opt 10/10 (worst 0.62)**; 1.3 + player base 2200 → none 5/10.
Full run on the final data (multi_seed_2026-10-31_d27.md, r05 at 1.25 in that run; r05 1.3 in _d27_r05_10seeds.md): none r01–r04 5/5 W; LOW and opt 5/5 W in every round; LOW medians ≤ 1.25 × par everywhere except r05, which is at 325 s = 1.25 × par in the 10-seed run.
Root cause of the unmet r02–r04 target: in this sim, base contact cascades. Once enemies reach the base, the bot's freshly deployed units and the tower cannot stop the pile, so outcomes are either no hit (1.00) or a loss. A 0.6–0.9 band needs a mechanic (for example a base that pushes enemies back, or a capped damage-per-second on the base), not a number change. Not requested yet.
## Update 2026-10-31 (5) — HARNESS DEFECT and re-measurement (D30)
**Defect in my own tool:** multi_seed_sim.gd.txt called `bot.act(sim, 1/60)` only every U(0, 0.35) s. bot_player.gd counts its think timer down by the dt it is given, so the bot decided about 10× less often than designed (competent every ~2.5 s instead of 0.25 s; casual every ~9 s instead of 0.9 s). Every table in Updates (2)–(4) and D24–D27 used this slowed bot. In the first D30 run the casual bot lost even r01 0/5, which exposed the bug (07's probe_balance gives casual r01 20/20). Fix: pass the real elapsed time since the last call. 07's harness was not affected.
Re-measurement with the fixed harness (files multi_seed_2026-10-31_d30_*.md; 5 seeds, r05 10 seeds):
| round | before retune (D27 data) | after retune (D30 data) |
|---|---|---|
| r02 | competent LOW 4/5, opt 3/5 | all policies with upgrades 5/5 |
| r03 | competent LOW 4/5, casual LOW 4/5 | 5/5 (casual LOW worst 0.48) |
| r04 | competent none 1/5, casual LOW 3/5 | 5/5 (competent none 5/5, worst 0.79) |
| r05 (10 seeds) | none 0/10; competent LOW **3/10**; casual LOW 6/10, LOW+2R 8/10 | none 0/10; competent LOW 10/10; casual LOW 9/10, LOW+2R 10/10 |
| r06–r10 | casual LOW 5/5 every round; r10 casual LOW+2R 5/5 | unchanged (rounds not retuned) |
D28 (casual targets) is met on these seeds: r01–r04 5/5 (5 seeds, so ≥ 9/10 is not yet shown at 10 seeds), r05 9/10 and 10/10, r06–r09 5/5, r10 5/5.
Corrections to earlier claims: (1) "bimodal, no middle state" was measured on the slowed bot. With the fixed bot, partial end states exist, so D29's premise is weaker (02/09 informed). (2) D27's "upgrades shorten r07–r09" also needs a re-read on the d30 tables.
Still open: r05 lengths 347–374 s exceed 1.25 × par; the r06 "none" row and the D24 length rule for other rounds were not fully re-checked with the fixed bot at 5 seeds for all budgets (the r01–r04/r06 and r07–r10 files have them).
## Update 2026-10-31 (6) — r05 bounds and length cause (D33)
Run in an isolated user:// (10's isolated_godot.ps1). Data: r05 scaling 1.25 + ranged hp 0.18. 10 seeds.
| policy | budget | wins | end base median | boss spawn (s) | boss dead median (s) | boss kill time (s) | after boss (s) | total median (s) |
|---|---|---|---|---|---|---|---|---|
| casual | LOW | 7/10 | 0.16 | 95 | 312 | 217 | 59 | 368 |
| casual | LOW+2R | 8/10 | 0.35 | 95 | 318 | 223 | 57 | 373 |
| competent | LOW | 8/10 | 0.08 | 95 | 297 | 202 | 75 | 370 |
| competent | LOW+2R | 10/10 | 0.45 | 95 | 296 | 201 | 60 | 361 |
| both | none | 0/10 | 0.00 | 95 | — | — | — | — |
Length cause: about 60% of the round is the boss fight (95 s → ~300 s). Proposal (not applied): boss_warlord hp 1800→1300 (−28%); expected kill time ~150 s and total ~300 s ≤ 325 s. Raising boss atk may be needed to keep the block (to verify with the same 10-seed run).
## Update 2026-10-31 (7) — r02–r04 pressure sweep and D29 outcome (D34, D35)
All runs isolated (sweep.ps1 → isolated_godot.ps1), under heavy_run.ps1, 5 seeds, competent and casual bots, fixed dt.
End base per seed, LOW budget (band 0.6–0.9 hits / 5):
| data | r02 competent | r03 competent | r04 competent | casual worst case |
|---|---|---|---|---|
| D30 (current) | 1,1,1,1,1 (0) | 1,1,1,1,1 (0) | 1,1,1,1,1 (0) | r03 0.48 |
| p120 (+0.1) | 0.89,0.53,1,1,1 (1) | 1,1,0.22,1,1 (0) | 1,1,1,1,0.60 (1) | r04 0.19, r04 none 3/5 W |
| p130 (+0.2) | 0.22,0.00,0.94,1,0.57 (0) | 1,1,1,0.47,0.71 (1) | 1,0,1,0.21,0 (0) | r04 casual LOW 3/5 W |
Conclusion: raising pressure jumps from "untouched" to "heavy damage or loss" without a stable band. The target is withdrawn (D35a). 02's mechanic options did not produce it either (D34).
r02 length: enemy base 800 → competent median 216 s (max 362), casual 115 s. The competent bot stalls in some seeds; the cause is in the bot, not the round.
## Update 2026-10-31 (8) — cliff cause and local candidates (D36), r05 boss hp (D37)
All runs: isolated sweep.ps1 under heavy_run.ps1, one candidate per run, 02 bots (competent skill 2, casual skill 1), seeds 1–5, LOW budget. Attribution: base damage split by the wave tag of the enemies within range+40 px of the base ("other" = trickle/trigger/pressure).
Cause (p130 data, 12 base-hit cases): first base hit at 222–372 s; damage 67% other, 24% wave 4, 9% wave 3; r02 hits are all grunts from the pressure waves/trickle; r03/r04 are spitter piles plus the r04 brute.
| data | round | competent LOW: seeds end<1.00 / wins | competent end base per seed | competent t median | casual LOW wins | casual worst end | idle loss (s) |
|---|---|---|---|---|---|---|---|
| D30 current | r02 | 0/5 · 5/5 W | 1.00,1.00,1.00,1.00,1.00 | 171 | 5/5 | 1.00 | 277 |
| D30 current | r03 | 0/5 · 5/5 W | 1.00,1.00,1.00,1.00,1.00 | 212 | 5/5 | 0.48 | 221 |
| D30 current | r04 | 0/5 · 5/5 W | 1.00,1.00,1.00,1.00,1.00 | 221 | 5/5 | 1.00 | 181 |
| global +0.1 (p120) | r02 | 2/5 · 5/5 W | 0.89,0.53,1.00,1.00,1.00 | 367 | 5/5 | 1.00 | 256 |
| global +0.1 (p120) | r03 | 1/5 · 5/5 W | 1.00,1.00,0.22,1.00,1.00 | 238 | 5/5 | 1.00 | 202 |
| global +0.1 (p120) | r04 | 1/5 · 5/5 W | 1.00,1.00,1.00,1.00,0.60 | 211 | 5/5 | 0.19 | 179 |
| global +0.2 (p130) | r02 | 4/5 · 4/5 W | 0.22,0.00,0.94,1.00,0.57 | 368 | 5/5 | 0.05 | 252 |
| global +0.2 (p130) | r03 | 2/5 · 5/5 W | 1.00,1.00,1.00,0.47,0.71 | 218 | 5/5 | 1.00 | 206 |
| global +0.2 (p130) | r04 | 3/5 · 3/5 W | 1.00,0.00,1.00,0.21,0.00 | 269 | 3/5 | 0.00 | 175 |
| C1 local wave 165 s | r02 | 1/5 · 5/5 W | 1.00,1.00,0.73,1.00,1.00 | 273 | 5/5 | 1.00 | 246 |
| C1 local wave 165 s | r03 | 1/5 · 5/5 W | 1.00,1.00,0.75,1.00,1.00 | 258 | 5/5 | 1.00 | 212 |
| C1 local wave 165 s | r04 | 3/5 · 5/5 W | 0.78,0.63,0.70,1.00,1.00 | 430 | 5/5 | 1.00 | 181 |
| C2 C1 + late softening | r02 | 0/5 · 5/5 W | 1.00,1.00,1.00,1.00,1.00 | 161 | 5/5 | 1.00 | 277 |
| C2 C1 + late softening | r03 | 0/5 · 5/5 W | 1.00,1.00,1.00,1.00,1.00 | 239 | 5/5 | 0.64 | 214 |
| C2 C1 + late softening | r04 | 0/5 · 5/5 W | 1.00,1.00,1.00,1.00,1.00 | 235 | 5/5 | 1.00 | 184 |
Reading: damage exists only in rounds that last past ~220 s. C1 turns some long rounds into partial damage without losses (milder cliff than global scaling), but lengthens them. C2's late softening removes the damage, which confirms that the late phase is the source.
r05 boss hp 1300 (10 seeds): kill time 202/184 s (was 217/202), medians 356/344 s; not enough (D37).
## Update 2026-11-01 (9) — r05 length vs boss splash/knockback (D38)
Same 2 bots, seeds 1–10, budgets none/LOW, isolated, one run per variant under heavy_run.ps1 (c ran partly unlocked after a tool time-out, see heavy_run.log NOTE; results are deterministic in sim time). Criteria: LOW median ≤ 325 s, casual LOW ≥ 7/10, none 0/10.
| variant | casual LOW wins | competent LOW wins | none wins (casual / competent) | LOW median t casual / competent (s) | boss dead median LOW (s) | meets all 3 |
|---|---|---|---|---|---|---|
| (a) current splash 40 / knockback 40 | 7/10 | 8/10 | 0/10 / 0/10 | 368 / 370 | 305 | no |
| (b) splash 20 | 10/10 | 10/10 | 6/10 / 10/10 | 358 / 338 | 276 | no |
| (c) knockback 20 | 10/10 | 10/10 | 9/10 / 10/10 | 379 / 371 | 304 | no |
| (d) splash 20 + knockback 20 | 10/10 | 10/10 | 9/10 / 10/10 | 397 / 236 | 284 | no |
| (e) extra: boss speed 18→30 | 10/10 | 10/10 | 7/10 / 9/10 | 350 / 322 | 265 | no |
Reading: splash and knockback are what make r05 a block. Halving either one lets the no-upgrade bots win (b: 6/10 and 10/10; c: 9/10 and 10/10). They do not set the length: the boss dies at ~260–320 s and LOW medians stay 322–397 s in every variant (D37 showed the same for boss HP). A faster boss (e) also removes the block (none 7/10, 9/10). No variant meets all three criteria.
Cause (D38): r05's length is set by the round structure (boss spawn at 95 s, then the wave at 150 s, the HP triggers and the push to the enemy base), not by boss combat values. The block and the length pull against each other through the same boss values.
## Update 2026-11-01 (10) — r05 structure experiment: pass criteria fixed BEFORE the runs
time_3 stays 260 (D38's par change is NOT adopted: about 6 minutes for one round conflicts with the 2–5 min session pillar). Bot sims are not human playtests.
Pass criteria (all must hold; 10 seeds, 02 bots competent skill 2 and casual skill 1, budgets none/LOW, isolated runs):
1. LOW median win time ≤ 325 s (1.25 × 260) for BOTH bots.
2. Casual LOW ≥ 7/10 wins.
3. none (no upgrades) 0/10 wins for BOTH bots (the block stays).
4. Not too easy for the competent bot at LOW (reported, threshold): median end base ≤ 0.80, and median time after the boss dies ≥ 30 s. If the boss dies and the round ends almost at once with a full base, the boss is no longer the fight.
5. Losses before the boss dies (reported): the share of LOW losses that happen while the boss is still alive. Lower means the block is the boss itself, not the adds.
Variants (data only, one Godot run each, queued in one detached job):
- s1: boss wave 95 → 60 s (the old 60 s wave moves to 95 s).
- s2: the 150 s wave is reduced from brute 2 + spitter 3 to brute 1 + spitter 2.
- s3: the 40% HP trigger (brute 2 + swarm 6) is removed.
- s4: s1 + s2.
Engine-only variants (requested from 02, not run): cancel the remaining waves/triggers when the boss dies; damage the enemy base when the boss dies.
