# Open defects: owner and blocking condition (owner: 07-qa)

## Windows update, 2026-11-03

The table below is the historical November 1 snapshot. Current Windows fixes and evidence are in
[WINDOWS_POLISH_20261103](../qa/WINDOWS_POLISH_20261103.md), source `45a4d25`.
B020 (hero contrast), B021 (dimmed cards), B023 (unit/faction contrast), B026 (live off-screen markers),
and B027 (touch gaps) were corrected and rechecked. The final fixed art set also has boss ΔL* 19.6 ≥ 15.
CR-001/003/004/006/007 and the round-relocking migration defects were corrected; a 600-level extension-data
case and failed-migration rollback now preserve the original data. Acceptance 156, UI 3414, integration 49,
and targeted regression 29 pass with no failed checks.

B022/J1's phone and human-perception claims remain outside this Windows verification: the default gameplay
now uses integer-pixel world zoom and live warnings, but desktop geometry is not a physical-phone playtest.
W004 still concerns Android APK verification. AUD-03/PLAT-03 remain explicitly untested in the acceptance suite.

## Historical November 1 snapshot

Updated 2026-11-01 07:3x +09:00. Last full -Head: e2404af run 20261101-070302 PASS 156 / FAIL 0 / NOT_TESTED 2, exit 0. Graphics/layout baseline ad47eda (ART_BASELINE.md, LAYOUT.md). Desktop only; not Android certification; no human play test.

| ID | Sev | Owner | State now | Blocks what | Closing condition (same check, HEAD condition) | Next 07 action |
|---|---|---|---|---|---|---|
| QA-J1 | P2 | 01 (target) · 04/02 (framing) | IDENTITY PART CLOSED (sky 17 %, village + nest readable); enemy-visibility part OPEN | first 3 minutes acceptance | an agreed number for enemy visibility (today 0 enemies on screen at r01 t = 7–22 s, 1–4 at 27–32 s) | wait for 01/04 target |
| QA-B013 | P3 | 02 (world bars) | PARTIAL: HUD PASS; world bars same olive under deutan at fca9346 | CVD readability | world unit + enemy-base bars separable in deutan/protan frames | retest on 02 fix |
| QA-B017 | P3 | 01 (decide) · 04 (HUD) | OPEN (code reading): pressure waves arrive after "wave 3/3" without a cue | clarity only | either a HUD/announcement cue for pressure waves, or a written 01 decision that the surprise is intended | read 01 reply; capture r01 at t ≥ 160 s idle |
| QA-B018 | P3 | 01 | OPEN: `upgrade.supply_regen` = "보급 증가" / "Supply Boost" after rename to 밀가루/Flour | wording consistency | one resource word in ko and en on HUD, cards, upgrades, tutorial, toasts | V10 (data scan, no Godot needed) |
| QA-W004 | — | 02 (export) · 04 (build pipeline) | WAITING: label PASS on a debug APK built 17:37 from a work tree before 4b5926d | Q4 sign-off | `check_apk_label.ps1` exit 0 on an APK exported from a named committed SHA | V8 when a HEAD APK exists |
| QA-R-balance / D28 | — | 01 | PASS for all 11 rows with the FIXED probe (HEAD 3e355a8; r04/r05 from d5f145a, same data; r02 identical across both builds). Earlier 5/9 FAIL withdrawn (QA-T001). Notes for 01: r05 competent LOW 7/10 accepted by D35c; r02 competent median 273.5 s = competent-bot stall (D35b, 02) | judging difficulty (DEFAULT until Q5) | — | re-run after any data/ or bot change |
| QA-B020 | P2 | 03 + 09-art-world | OPEN ad47eda: hero ΔL* 5.1–15.8 vs the street (4 of 5 scenes < 15) | finding the hero | ART_BASELINE C3/W2: hero ΔL* ≥ 15 in all 5 battle scenes of the fixed set | re-run the set on a 03/09 commit |
| QA-B022 | P2 (provisional) | 03 (cc 01 J1, 02 camera) | OPEN ad47eda: soldiers 3.5–4.4 mm on a 393 dp phone | first 3 minutes (J1) | C1: ≥ 5.0 mm in r06/r08, or 01's J1 target once set | re-run on a 03 commit; replace the line when 01 sets J1 |
| QA-B023 | P3 | 03 (+ 09) | OPEN ad47eda: 11–67 % of units ΔL* < 15; r08 deutan pair 11.9; boss over nest 11.0 | readability | C2, C4, C5 | re-run on a 03/09 commit |
| QA-B021 | P2 | 06-art-ui | REOPENED: all-dimmed cards fail U1 (2/10 pairs) in r08/r10 since 780c30a | telling cards apart when poor | U1 on every pair, dimmed included | art_compare on a 06 commit |
| QA-B026 | P2 | 02 + 04 (cc 01) | OPEN e2404af: threat markers never shown (no `threat` field in the snapshot) | enemy warning (D39 mitigation) | LAYOUT L6/L6o with an off-screen enemy | art_compare on a 02/04 commit; add an off-screen-enemy frame |
| QA-B027 | P3 | 04 | OPEN ad47eda: worker–card gap 4 px (4.4 dp), menu 6 px | mis-taps | LAYOUT L4 ≥ 7.3 px (8 dp) | art_compare on a 04 commit |
Closed (for reference): B001–B012, B014, B015, B016, B019, J2 (D24a), J3, W001–W003, W005; B024 and B025 VERIFIED at e8c6d96 (03 side). B012 and B019 VERIFIED at 278d52b (run 20261101-012951, VISUAL_CHECKS M14). Details: BUG_REGISTER.md.
