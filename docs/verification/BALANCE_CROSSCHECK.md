# Independent balance cross-check after c15e43a (owner: 07-qa)
2026-10-31 17:20 +09:00. Probe `tests/acceptance/probe_balance.gd`: seeds 101–110, reaction noise U(0,0.6) s on 25 % of decisions, start U(0,5) s (01 used seeds 1–5, U(0,0.35) / U(0,3)); LOW/HIGH levels read from 01's `docs/design/balance/upgrade_budgets.json`. Data and sim are identical between the probe snapshot 16ea2c2 and HEAD 97c8b9c (`git diff` empty for data/, battle_sim.gd, bot_player.gd). These are bot results, not human results.

| Round | Budget | 07 competent (10): wins · median t · worst base | 01 competent (5): wins · median t · worst base | 07 casual (10): wins · worst base | Agreement |
|---|---|---|---|---|---|
| r05 | LOW | 10/10 · 259 s · 0.57 | 5/5 · 267 s · 0.40 | **0/10** · 0.00 | competent agrees (07 slightly safer) |
| r05 | none | 10/10 · 363 s · **0.03** | 5/5 · 263 s · **1.00** | 0/10 | **disagrees**: 07's worst run ends at 3 % base HP and median is 100 s longer |
| r09 | LOW | 10/10 · 184 s · 1.00 | 5/5 · 226 s · 1.00 | 10/10 · 0.51 | agrees |
| r09 | none | 10/10 · 349 s · 0.59 | 5/5 · 361 s · 0.88 | 8/10 · 0.31 | agrees on wins; 07 lower worst base |
| r10 | LOW | 10/10 · 436 s · 0.92 | 5/5 · 454 s · 0.67 | **0/10** · 0.00 | competent agrees |
| r10 | none | 1/10 | 1/5 | 0/10 | agrees |

Readings:
1. 01's LOW-budget claims (r05/r09/r10 5/5, worst base r05 0.40, r10 0.67) hold under a different noise model and different seeds: 10/10 each, worst 0.57 / 1.00 / 0.92.
2. r05 without upgrades is not as safe as 01's table shows (worst base 1.00): with 07's noise the worst run ends at 3 % base HP. Upgrade dependence at r05 is stronger than reported.
3. The casual policy loses r05 and r10 **every** time even with LOW upgrades (0/10), while it wins r01–r04 and r09. If "risk for active play begins at r05" (D24a) is the intent, r05 is a cliff for casual play rather than a ramp. A hypothesis for the D11 pilot, not a human verdict.
4. Time stars: competent LOW medians are within 1.25 × par in all three rounds (259 ≤ 325, 184 ≤ 375, 436 ≤ 475).
Reproduce: `Godot_console --headless --path <HEAD snapshot> -s res://tests/acceptance/probe_balance.gd -- --rounds=r05,r09,r10 --seeds=10`.

## r01 rule D24(a) (QA-J2) — PASS
`probe_r01_risk.gd --seeds=20` at 97c8b9c: competent 20/20 W, late start at 45 s 20/20 W (median 138 s), casual 20/20 W, idle 0/20 W with **20/20 losses by base destruction, the latest at 258.1 s** (≤ 300 s). Base damage for active play is 0 %, which D24(a) allows. J2 is closed as a design decision; the risk-ramp question moves to r05 (reading 3).

## Re-run after a262640 (D25), HEAD 09508b1 snapshot, 17:38
Same probe, same seeds. `git diff a262640 09508b1` touches only battle_sim.gd (02) in sim/data.
| Round | Budget | 07 competent (10) | 01 D25 competent (5) | 07 casual (10) |
|---|---|---|---|---|
| r05 | LOW | 10/10 · 259 s · worst 0.57 | 5/5 · 267 s · 0.40 | **0/10** |
| r05 | none | 10/10 · 363 s · worst **0.03** | 5/5 · 263 s · 1.00 | 0/10 |
| r09 | LOW | 10/10 · 184 s · 1.00 | 5/5 · 226 s · 1.00 | 10/10 · 0.51 |
| r10 | LOW | 10/10 · 445 s · 0.92 | 5/5 · 464 s · 0.69 (d25_r10) | **0/10** |
| r10 | none | 1/10 | 1/5 | 0/10 |
Result: unchanged by D25 for r05/r09; r10 median 436 -> 445 s. **Casual still loses r05 and r10 0/10 at LOW.** The r05 'none' disagreement (0.03 vs 1.00) remains. Note 01's own D25 r10 HIGH worst base 0.18 (lower than LOW 0.69), a non-monotonic budget effect 07 did not test.

## Re-run after 7b93d1f (D27) with D28 targets — HEAD fca9346, 2026-10-31 19:10–19:33
07 casual + competent policies, 10 seeds each (101–110, same noise as above), budgets from 01's `upgrade_budgets.json` (`low`, `low2r`, none). Each round ran in its own process with a **200 s cap** (08 may measure again; a single 10-round process exceeded 28 min and was stopped). r04, r08 and r10 hit the cap, so some rows are missing. Raw rows: `evidence/visual7-fca9346/balance_rows.json`.
| Round | competent LOW | competent none | casual LOW | casual low2r | D28 target (casual) | D28 |
|---|---|---|---|---|---|---|
| r01 | 10/10 · 104 s · 1.00 | 10/10 | **9/10** | – | LOW ≥ 9/10 | PASS |
| r02 | 9/10 · 159 s · **0.00** (one loss) | 9/10 | **0/10** | – | LOW ≥ 9/10 | **FAIL** |
| r03 | 10/10 · 218 s | 9/10 | **6/10** | – | LOW ≥ 9/10 | **FAIL** |
| r04 | 10/10 · 211 s · 0.99 | 8/10 | **0/10** | – | LOW ≥ 9/10 | **FAIL** |
| r05 | **8/10** · 339 s · 0.00 | **0/10** | **0/10** | **0/10** | LOW ≥ 3/10 and low2r ≥ 7/10 | **FAIL** |
| r06 | 10/10 · 156 s | 9/10 | **1/10** | – | LOW ≥ 7/10 | **FAIL** |
| r07 | 10/10 · 158 s | 10/10 | 10/10 · 0.22 | – | LOW ≥ 7/10 | PASS |
| r08 | 10/10 · 191 s | 10/10 | 10/10 · 0.51 | – | LOW ≥ 7/10 | PASS |
| r09 | 10/10 · 155 s | 10/10 | 10/10 · 0.81 | – | LOW ≥ 7/10 | PASS |
| r10 | 10/10 · 312 s · 0.82 | not run (cap) | 7/10 | not run (cap) | low2r ≥ 5/10 | NOT_RUN |
Readings:
1. **D27 made chapter-1 rounds r02–r06 much harder for the casual policy**: before D27 (BALANCE_CROSSCHECK first table) casual won r01–r04 and r09; now it loses r02 0/10, r04 0/10, r05 0/10 (even with 2 replays of coins), r06 1/10. 5 of 9 executed D28 rows FAIL.
2. Competent disagreements with 01's D27 table: **r05 LOW 8/10 with worst base 0.00** (01: 10/10); r05 no-upgrade **0/10** (01: 4/10, "block round"); r02 LOW one loss (worst 0.00).
3. 01's challenge "r02–r04 LOW worst base stays 1.00": with 07's noise r04 LOW worst is 0.99 and r02 has a full loss, so damage is not strictly bimodal for the competent policy.
4. Bots are not people. These rows only check 01's own numeric targets.

## Correction 2026-10-31 19:58 — 07's own harness had the same timing defect (supersedes the D28 table above)
Measured builds: previous table = HEAD **fca9346**, data tree **a3aaf55**; this re-run = clean `git archive` of origin/main **d5f145a**, data tree **8c7b0a3** (includes 01 d09d740/D30 retune and f01e9d5/D33). Godot run through 10's `isolated_godot.ps1` (private APPDATA; `isolated: true`, real save unchanged), 420 s cap per round.
**Defect in 07 probe_balance.gd (fixed now):** the bot was called only on non-waiting frames but always with `dt = STEP` (1/60 s); with the noise model (25 % of calls followed by a U(0,0.6) s wait) calls were ~0.09 s apart, so the bot's internal think timer ran ~5× slow. Same class as 01's D30 harness bug. Fixed: pass the real time since the last call; `--legacy-dt` reproduces the old behaviour.
| Round | casual LOW (fixed) | casual low2r (fixed) | competent LOW (fixed) | competent none (fixed) | D28 casual target | D28 |
|---|---|---|---|---|---|---|
| r02 | **10/10** · worst 1.00 | – | 10/10 · worst 0.86 · median 274 s | 10/10 | LOW ≥ 9/10 | PASS |
| r04 | **10/10** · worst 1.00 | – | 10/10 · worst 1.00 | 9/10 | LOW ≥ 9/10 | PASS |
| r05 | **8/10** · worst 0.00 | **10/10** · worst 0.08 | **7/10** · worst 0.00 | 0/10 | LOW ≥ 3/10, low2r ≥ 7/10 | PASS |
Control at the same build (`--legacy-dt`, r05 LOW): casual **0/10**, competent 10/10. So the earlier casual 0/10 results were produced mainly by 07's slowed bot, not by the data.
Verdict on the 01 vs 07 conflict: **01's D30 claim for r05 casual LOW (9/10) is confirmed within one seed (07: 8/10)**; 07's previous D28 FAIL rows are withdrawn as a harness artefact. Still open: competent LOW r05 **7/10, worst base 0.00** and r02 competent median 274 s (> 1.25 × par); not re-run: r01, r03, r06–r10 with the fixed probe.

## D28 with the fixed probe, all rounds — HEAD 3e355a8, 2026-11-01 00:09–01:04
Measured build: clean `git archive` snapshot of HEAD **3e355a8** (run 20261031-234416, import guard 0). Data tree **8c7b0a3**, `upgrade_budgets.json` blob **b0d29c2**. Both equal d5f145a's; the only runtime change since d5f145a is 02 eceb9f4 (base_defense, off by default).
Method: `tools/qa/run_d28.ps1` runs one round per `coordination/heavy_run.ps1` lock and one `isolated_godot.ps1` process (private APPDATA, `isolated: true` for every round, real save unchanged), with a 420 s cap. No round hit the cap. Seeds 101–110, probe_balance.gd with the QA-T001 fix. Only the D28 budget was run for each round (heavy-run rule), so there are no 'none' rows this time.
- **Base defence off = unchanged results:** r02 LOW at 3e355a8 matches d5f145a on every field both outputs have. Competent: 10/10, 141.3/273.5/403.1 s, worst base 0.86. Casual: 10/10, 111.8/115.8/385.5 s, worst 1.00.
- **r04 and r05 were not re-run.** They are taken from d5f145a (same data, same budgets, base_defense off proven by the r02 identity).

| Round | casual D28 budget: wins · time min/median/max · worst base | competent same budget: wins · median · worst | par × 1.25 | D28 target | D28 |
|---|---|---|---|---|---|
| r01 | LOW 10/10 · 84.9/91.4/110.3 s · 1.00 | 10/10 · 104.9 s · 1.00 | 187.5 | LOW ≥ 9/10 | PASS |
| r02 | LOW 10/10 · 111.8/115.8/385.5 s · 1.00 | 10/10 · **273.5 s** · 0.86 | 212.5 | LOW ≥ 9/10 | PASS |
| r03 | LOW 10/10 · 123.0/148.6/484.3 s · 0.54 | 10/10 · 222.2 s · 1.00 | 250 | LOW ≥ 9/10 | PASS |
| r04 (d5f145a) | LOW 10/10 · worst 1.00 | 10/10 · worst 1.00 | — | LOW ≥ 9/10 | PASS |
| r05 (d5f145a) | LOW 8/10 · 0.00; low2r 10/10 · 0.08 | LOW 7/10 · 0.00 | — | LOW ≥ 3/10, low2r ≥ 7/10 | PASS |
| r06 | LOW 10/10 · 118.3/130.6/141.2 s · 1.00 | 10/10 · 145.7 s · 1.00 | 325 | LOW ≥ 7/10 | PASS |
| r07 | LOW 10/10 · 155.0/208.9/237.1 s · 1.00 | 10/10 · 199.0 s · 0.94 | 337.5 | LOW ≥ 7/10 | PASS |
| r08 | LOW 10/10 · 196.5/227.8/280.1 s · 1.00 | 10/10 · 253.0 s · 1.00 | 350 | LOW ≥ 7/10 | PASS |
| r09 | LOW 10/10 · 169.1/178.8/184.2 s · 1.00 | 10/10 · 194.1 s · 1.00 | 375 | LOW ≥ 7/10 | PASS |
| r10 | low2r 10/10 · 296.8/422.6/428.3 s · 0.87 (LOW 10/10 · 462.4 s · 0.61) | low2r 10/10 · 341.1 s · 1.00 | 475 | low2r ≥ 5/10 | PASS |

Readings:
1. **All 11 D28 rows PASS** with the fixed probe. 07's earlier 5/9 FAIL table (fca9346) stays withdrawn (QA-T001).
2. Casual wins 10/10 in every round except r05 (8/10). D28 only sets lower bounds, so this table cannot show that a round is too easy. Apart from r05 the casual policy never comes close to losing (worst base below 0.9 only in r03 0.54, r10 0.61/0.87). Whether that is the intended feel is for the user's Q5 answer and for human pilots, not for bots.
3. r02 competent median 273.5 s is above 1.25 × par (212.5 s), while casual takes 115.8 s. This matches 01's R9 finding (competent-bot stall, D35b to 02). It is a bot behaviour, not a data finding.
4. Process note: the first r10 run had only 'low' because of a variable-name bug in run_d28.ps1. PowerShell names are case-insensitive, so the local `$budgets` overwrote the `-Budgets` parameter. The bug is fixed and r10 low2r was re-run separately (01:02–01:04). r01–r09 needed only 'low', so their rows are unaffected.
5. Bots are not people. These rows check 01's own numeric targets only; D28 is a DEFAULT until the user answers Q5.
Raw output: `build/qa07/d28_3e355a8_<round>.txt` and `d28_3e355a8_low2r_r10.txt` (local, git-ignored; each has `[rows]` per-seed lines including the enemy base ratio at the end).
