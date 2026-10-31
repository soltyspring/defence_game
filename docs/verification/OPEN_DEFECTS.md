# Open defects: owner and blocking condition (owner: 07-qa)
Updated 2026-11-01 01:0x +09:00 at clean HEAD 3e355a8 (run 20261031-234416 PASS 153 / FAIL 3: DATA-13/14 = QA-B019, BD-SPLASH = 07 test defect fixed, sim 43/43 on re-run; D28 all rows PASS). Earlier basis: fca9346 run 20261031-183232. Desktop only; not Android certification.

| ID | Sev | Owner | State now | Blocks what | Closing condition (same check, HEAD condition) | Next 07 action |
|---|---|---|---|---|---|---|
| QA-J1 | P2 | 01 (target) · 04/02 (framing) | IDENTITY PART CLOSED (sky 17 %, village + nest readable); enemy-visibility part OPEN | first 3 minutes acceptance | an agreed number for enemy visibility (today 0 enemies on screen at r01 t = 7–22 s, 1–4 at 27–32 s) | wait for 01/04 target |
| QA-B012 | P3 | 02 | REOPENED (1 133 overlapping pairs in 185 s at fca9346; step 10 px < rect 11 px; low contrast on light walls). 3e355a8: battle_view.gd blob unchanged (8cd2a3e), not re-captured | readability | `damage_number_overlaps == 0` over 180 s r08 and legible numbers in the zoom | retest on 02 fix commit |
| QA-B013 | P3 | 02 (world bars) | PARTIAL: HUD PASS; world bars same olive under deutan at fca9346 | CVD readability | world unit + enemy-base bars separable in deutan/protan frames | retest on 02 fix |
| QA-B017 | P3 | 01 (decide) · 04 (HUD) | OPEN (code reading): pressure waves arrive after "wave 3/3" without a cue | clarity only | either a HUD/announcement cue for pressure waves, or a written 01 decision that the surprise is intended | read 01 reply; capture r01 at t ≥ 160 s idle |
| QA-B018 | P3 | 01 | OPEN: `upgrade.supply_regen` = "보급 증가" / "Supply Boost" after rename to 밀가루/Flour | wording consistency | one resource word in ko and en on HUD, cards, upgrades, tutorial, toasts | V10 (data scan, no Godot needed) |
| QA-W004 | — | 02 (export) · 04 (build pipeline) | WAITING: label PASS on a debug APK built 17:37 from a work tree before 4b5926d | Q4 sign-off | `check_apk_label.ps1` exit 0 on an APK exported from a named committed SHA | V8 when a HEAD APK exists |
| QA-R-balance / D28 | — | 01 | PASS for all 11 rows with the FIXED probe (HEAD 3e355a8; r04/r05 from d5f145a, same data; r02 identical across both builds). Earlier 5/9 FAIL withdrawn (QA-T001). Notes for 01: r05 competent LOW 7/10 accepted by D35c; r02 competent median 273.5 s = competent-bot stall (D35b, 02) | judging difficulty (DEFAULT until Q5) | — | re-run after any data/ or bot change |
| QA-B019 | P3 latent | 01 (cc 04) | OPEN 3e355a8: `ui.distance_m` (threat_marker.gd:67) missing in ko/en | text once the threat marker is shown | DATA-13/14 PASS with `-Head -Only data` | retest on 01 commit |
Closed today (for reference): B001–B011, B014, B015, B016, J2 (D24a), J3, W001–W003. Details: BUG_REGISTER.md.
