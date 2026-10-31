# Open defects: owner and blocking condition (owner: 07-qa)
Updated 2026-10-31 19:35 +09:00 after executing RETEST_PLAN_1830 at clean HEAD fca9346 (run 20261031-183232 PASS 152 / FAIL 0; captures visual7-fca9346; balance rows 19:10–19:33). Desktop only; not Android certification.

| ID | Sev | Owner | State now | Blocks what | Closing condition (same check, HEAD condition) | Next 07 action |
|---|---|---|---|---|---|---|
| QA-J1 | P2 | 01 (target) · 04/02 (framing) | IDENTITY PART CLOSED (sky 17 %, village + nest readable); enemy-visibility part OPEN | first 3 minutes acceptance | an agreed number for enemy visibility (today 0 enemies on screen at r01 t = 7–22 s, 1–4 at 27–32 s) | wait for 01/04 target |
| QA-B012 | P3 | 02 | REOPENED (1 133 overlapping pairs in 185 s; step 10 px < rect 11 px; low contrast on light walls) | readability | `damage_number_overlaps == 0` over 180 s r08 and legible numbers in the zoom | retest on 02 fix |
| QA-B013 | P3 | 02 (world bars) | PARTIAL: HUD PASS; world bars same olive under deutan at fca9346 | CVD readability | world unit + enemy-base bars separable in deutan/protan frames | retest on 02 fix |
| QA-B017 | P3 | 01 (decide) · 04 (HUD) | OPEN (code reading): pressure waves arrive after "wave 3/3" without a cue | clarity only | either a HUD/announcement cue for pressure waves, or a written 01 decision that the surprise is intended | read 01 reply; capture r01 at t ≥ 160 s idle |
| QA-B018 | P3 | 01 | OPEN: `upgrade.supply_regen` = "보급 증가" / "Supply Boost" after rename to 밀가루/Flour | wording consistency | one resource word in ko and en on HUD, cards, upgrades, tutorial, toasts | V10 (data scan, no Godot needed) |
| QA-W004 | — | 02 (export) · 04 (build pipeline) | WAITING: label PASS on a debug APK built 17:37 from a work tree before 4b5926d | Q4 sign-off | `check_apk_label.ps1` exit 0 on an APK exported from a named committed SHA | V8 when a HEAD APK exists |
| QA-R-balance / D28 | — | 01 | D28 (DEFAULT, pending Q5) now executable: **5 of 9 rows FAIL** at fca9346 (casual LOW r02 0/10, r03 6/10, r04 0/10, r05 0/10 incl. low2r, r06 1/10) | judging difficulty | every D28 row PASS in `probe_balance.gd --d28` | rerun after 01's retune |
Closed today (for reference): B001–B011, B014, B015, B016, J2 (D24a), J3, W001–W003. Details: BUG_REGISTER.md.
