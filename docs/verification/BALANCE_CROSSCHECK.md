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
