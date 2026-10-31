# Release readiness — design/economy items (01-director)
Engineering/QA/release items live with 02 (docs/architecture) and 04 (docs/qa). This file tracks design-owned gates.
State: TESTED (evidence linked) / UNTESTED / BLOCKED (reason).

| Gate | State | Evidence / blocker |
|---|---|---|
| Data files parse + cross-refs valid | TESTED | PowerShell check 2026-10-31, PROGRESS.md |
| Theme/title original, no reference IP names/art | BLOCKED | Q1 pending |
| R1–R3 beatable by bot without upgrades | UNTESTED | needs 02 headless sim |
| R1–R10 beatable with first-clear gold only | TESTED (bot only) | D24: 5 timing-noise seeds, LOW 50/50 W (docs/design/balance/multi_seed_2026-10-31_after.md). Not human |
| Round durations within ±25% par | TESTED (bot only) | D24: LOW medians ≤ 1.25 × par for all rounds (r10 par 380). Human length untested |
| Entity peak counts under caps in R8–R10 | UNTESTED | sim/profiling (02/04) |
| Save schema stores IDs/levels only (rebalance-safe) | UNTESTED | 02/04 implementation |
| Korean text complete for all keys | UNTESTED | placeholder names until Q1 |
| Monetization model decided | BLOCKED | Q2 not asked yet (after Q1) |
| No purchase required for chapter 1 | UNTESTED | design intent; verify after catalog |
| Paid random items probability disclosure (only if gacha) | N/A until Q2 | ECONOMY.md §4 |
| Age rating questionnaire inputs (violence level, ads, IAP) | BLOCKED | Q2–Q5 |
