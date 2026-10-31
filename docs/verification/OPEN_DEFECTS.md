# Open defects: owner and blocking condition (owner: 07-qa)
Updated 2026-11-01 01:4x +09:00 at clean HEAD 278d52b (run 20261101-012951 PASS 156 / FAIL 0 / NOT_TESTED 2, exit 0; QA-B012 crowd retest 0 overlaps; D28 all rows PASS at 3e355a8). Desktop only; not Android certification.

| ID | Sev | Owner | State now | Blocks what | Closing condition (same check, HEAD condition) | Next 07 action |
|---|---|---|---|---|---|---|
| QA-J1 | P2 | 01 (target) · 04/02 (framing) | IDENTITY PART CLOSED (sky 17 %, village + nest readable); enemy-visibility part OPEN | first 3 minutes acceptance | an agreed number for enemy visibility (today 0 enemies on screen at r01 t = 7–22 s, 1–4 at 27–32 s) | wait for 01/04 target |
| QA-B013 | P3 | 02 (world bars) | PARTIAL: HUD PASS; world bars same olive under deutan at fca9346 | CVD readability | world unit + enemy-base bars separable in deutan/protan frames | retest on 02 fix |
| QA-B017 | P3 | 01 (decide) · 04 (HUD) | OPEN (code reading): pressure waves arrive after "wave 3/3" without a cue | clarity only | either a HUD/announcement cue for pressure waves, or a written 01 decision that the surprise is intended | read 01 reply; capture r01 at t ≥ 160 s idle |
| QA-B018 | P3 | 01 | OPEN: `upgrade.supply_regen` = "보급 증가" / "Supply Boost" after rename to 밀가루/Flour | wording consistency | one resource word in ko and en on HUD, cards, upgrades, tutorial, toasts | V10 (data scan, no Godot needed) |
| QA-W004 | — | 02 (export) · 04 (build pipeline) | WAITING: label PASS on a debug APK built 17:37 from a work tree before 4b5926d | Q4 sign-off | `check_apk_label.ps1` exit 0 on an APK exported from a named committed SHA | V8 when a HEAD APK exists |
| QA-R-balance / D28 | — | 01 | PASS for all 11 rows with the FIXED probe (HEAD 3e355a8; r04/r05 from d5f145a, same data; r02 identical across both builds). Earlier 5/9 FAIL withdrawn (QA-T001). Notes for 01: r05 competent LOW 7/10 accepted by D35c; r02 competent median 273.5 s = competent-bot stall (D35b, 02) | judging difficulty (DEFAULT until Q5) | — | re-run after any data/ or bot change |
| QA-B020 | P2 | 03 + 09-art-world | OPEN ad47eda: hero ΔL* 5.1–15.8 vs the street (4 of 5 scenes < 15) | finding the hero | ART_BASELINE C3/W2: hero ΔL* ≥ 15 in all 5 battle scenes of the fixed set | re-run the set on a 03/09 commit |
| QA-B021 | P2 | 06-art-ui | OPEN ad47eda: card icons closest pair ΔE 0.6, shape 5.0–9.2 | telling cards apart | ART_BASELINE U1 on every on-screen pair | re-run on a 06 commit |
| QA-B022 | P2 (provisional) | 03 (cc 01 J1, 02 camera) | OPEN ad47eda: soldiers 3.5–4.4 mm on a 393 dp phone | first 3 minutes (J1) | C1: ≥ 5.0 mm in r06/r08, or 01's J1 target once set | re-run on a 03 commit; replace the line when 01 sets J1 |
| QA-B023 | P3 | 03 (+ 09) | OPEN ad47eda: 11–67 % of units ΔL* < 15; r08 deutan pair 11.9; boss over nest 11.0 | readability | C2, C4, C5 | re-run on a 03/09 commit |
Closed (for reference): B001–B012, B014, B015, B016, B019, J2 (D24a), J3, W001–W003, W005. B012 and B019 VERIFIED at 278d52b (run 20261101-012951, VISUAL_CHECKS M14). Details: BUG_REGISTER.md.
