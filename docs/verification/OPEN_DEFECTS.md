# Open defects: owner and blocking condition (owner: 07-qa)
Updated 2026-10-31 18:10 +09:00 from static reading (no Godot run in 08's 18:00–18:30 window). Last executed evidence: HEAD 09508b1, run 20261031-173017 (PASS 152 / FAIL 0) and captures visual6-09508b1. Desktop only; not Android certification.

| ID | Sev | Owner | State now | Blocks what | Closing condition (same check, HEAD condition) | Next 07 action |
|---|---|---|---|---|---|---|
| QA-J1 | P2 | 03 (art) · 04/02 (framing) · 01 (target) | OPEN. 03 11ceacb + e3c4621 claim village/nest and sky 24.7 % (Python); no game frame yet | "first 3 minutes" acceptance; store screenshots | (a) a real HEAD frame with sky share ≤ 35 % and visible village/nest; (b) an agreed number for enemy visibility (today 0 enemies on screen at r01 t = 7–32 s) — **target missing, 01/03/04 must set it** | RETEST_PLAN V1–V3 after 18:30 |
| QA-B012 | P3 | 02 | **FIX_CLAIMED** 09508b1 (Galmuri9 10 px, merge, stagger) — not yet retested in a crowd frame | readability only | `damage_number_overlaps == 0` over a 180 s r08 real-time run and no number on an HP bar in the zoom | V4 |
| QA-B013 | P3 | 02 (world bars) · 04 (HUD bars, done) | PARTIAL: HUD bars PASS (97c8b9c); world bars hue-only by code at c6d0e9e | CVD readability | unit + enemy-base world bars separable in deutan/protan frames | V5 |
| QA-B017 | P3 | 01 (decide) · 04 (HUD) | OPEN (code reading): pressure waves arrive after "wave 3/3" without a cue | clarity only | either a HUD/announcement cue for pressure waves, or a written 01 decision that the surprise is intended | read 01 reply; capture r01 at t ≥ 160 s idle |
| QA-B018 | P3 | 01 | OPEN: `upgrade.supply_regen` = "보급 증가" / "Supply Boost" after rename to 밀가루/Flour | wording consistency | one resource word in ko and en on HUD, cards, upgrades, tutorial, toasts | V10 (data scan, no Godot needed) |
| QA-W004 | — | 02 (export) · 04 (build pipeline) | WAITING: label PASS on a debug APK built 17:37 from a work tree before 4b5926d | Q4 sign-off | `check_apk_label.ps1` exit 0 on an APK exported from a named committed SHA | V8 when a HEAD APK exists |
| QA-R-balance | — | 01 | QUESTION (see 07-qa-to-01-director.md, 18:10) | judging difficulty for non-expert players | 01 states a casual-policy target (or declares it out of scope) | rerun probe_balance after the answer |
Closed today (for reference): B001–B011, B014, B015, B016, J2 (D24a), J3, W001–W003. Details: BUG_REGISTER.md.
