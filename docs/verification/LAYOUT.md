# UI layout rules for independent judgement (owner: 07-qa)
Written 2026-11-01, before 04's genre-referenced layout overhaul (user 02:24: "ui배치도 다른 게임 참고해서 진행해"). 07 judges 04's result with these rules; 04's own reference table is 04's evidence, not 07's yardstick. Desktop measurement only: not Android certification, and **no human play test has been run**.

## Condition and conversion
- Same fixed set and harness as [ART_BASELINE.md](ART_BASELINE.md): `tests/acceptance/capture_art_baseline.gd`, baseline SHA ad47eda, 393×873 dp phone in landscape, 800×360 logical view, notches 34/0/34/0, touch target setting 44.
- **Conversion (assumption, stated):** the 360 view px of the screen height span the 393 dp short side of the phone, so 1 view px = 393 / 360 = 1.092 dp. 1 dp = 1/160 inch = 0.15875 mm, so 1 view px = 0.173 mm. Real phones round dp and add system bars. This is a model of one common phone (1080×2400 at density 2.75), not a device measurement.
- **Sources:**
  - The scene node dump: every visible Control under the UI layer, with global rect, role (card / move / skill / worker / pause), text, font size and the two threat markers. This is `_layout_dump()` in the capture script, written to `<tag>_art_report.json`.
  - The HUD pixel mask: full frame vs the UI layer hidden.
  - The sim state: the nearest enemy beyond the right camera edge.
- Runs only through `tools/qa/art_compare.ps1` (detached, PC-wide lock, private APPDATA, secondary monitor). The table includes rows L1–L8.

## Rules
| ID | Player-side rejection reason | Measure | Pass rule | Basis |
|---|---|---|---|---|
| L1 | "the HUD takes the battlefield away" | battlefield visible % = 100 − HUD pixel % (battle scenes) | no scene loses more than 0.5 pp against the baseline | no public standard; baseline no-worse |
| L2 | "the HUD covers the lane where my units stand" | HUD pixels in the lane band (ground − 34 … ground + 6 view px) | no more than the baseline (per scene) | 04 measured 0 px lane occlusion after 45c05f0; baseline no-worse |
| L3 | "a button is too small for my thumb" | smallest side of every touch target (all 7 scenes) | ≥ 44 view px (= 48 dp = 7.6 mm) | Android: touch targets at least 48×48 dp ([Android Accessibility Help](https://support.google.com/accessibility/android/answer/7101858), [Android Developers](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views)) |
| L4 | "I hit the wrong button" | smallest edge gap between two touch targets; overlapping pairs | gap ≥ 7.3 view px (= 8 dp = 1.3 mm) and 0 overlaps | Android: targets separated by 8 dp or more (same Help page) |
| L5 | "I have to let go of the phone to reach it" | frequent controls (move, cards, skills, worker) with their centre in the top half | 0 | two-hand landscape grip: thumbs rest at the bottom corners (07 assumption; no human reach data) |
| L5m / L5c / L5s | same, by distance | worst centre distance to the nearest bottom screen corner, mm, for move / cards / skills | no more than baseline + 3 mm | baseline no-worse; 07 assumption |
| L5p | pause placement | pause distance to a bottom corner | **info only** (far from the thumbs avoids accidental pauses) | — |
| L6 | "an enemy is coming and nothing tells me" | battle scenes with an alive enemy beyond the right camera edge while the right threat marker is not shown | 0 | 01 D39 keeps the off-screen markers as the mitigation for the zoom's shorter warning time |
| L6o | "the warning is under other HUD" | overlap area of the right threat marker with other HUD nodes | 0 | — |
| L7 | "I can't read the text" | smallest font size of any visible text node (Label, TouchButton) | ≥ 11 view px (= 12 sp at font scale 1.0) | Android: do not make body text smaller than 12 sp ([Android design: accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility)) |
| L8 | "a button sits under the notch" | touch targets outside the safe area | 0 | — |
| — | "does it look good", "does it follow the genre's conventions" | — | **NOT MEASURABLE** by tools; needs people (and 04's reference table checked against official sources, below) | — |

Limits of the measure:
- Text drawn directly with `draw_string` is not a node, so L7 does not see it. This covers the HUD top bar numbers, card costs drawn inside TouchButton, and world damage numbers. 04's own text-height test (d724b9a: Galmuri11 12 px, 1.75–2.00 mm) covers those.
- Thumb distance is geometry only. It says nothing about comfort for real hands.

## Baseline values (ad47eda, ko_1x, layout run 2026-11-01 07:14)
Table: [art_compare/ad47eda-layout.md](art_compare/ad47eda-layout.md). Frames are pixel-identical to the graphics baseline.
| Rule | Menu | r01 t10 | r01 t30 | r06 t46 | r08 peak | r10 boss | Result | Verdict |
|---|---|---|---|---|---|---|---|---|
| L1 battlefield visible % | — | 89.95 | 89.88 | 84.72 | 83.82 | 81.45 | — | baseline |
| L2 HUD px in the lane band | — | 0 | 0 | 0 | 0 | 0 | — | PASS (stay 0) |
| L3 smallest touch side px (mm) | 44 (7.6) | 44 | 44 | 44 | 44 | 44 | 44 | PASS, exactly on the line |
| L4 smallest gap px (mm, dp) | **6** (1.04, 6.6 dp) round select / upgrades | **4** (0.69, 4.4 dp) worker / card | 4 | 4 | 4 | 4 | 8 (1.39) | **FAIL now** (QA-B027) |
| L4o overlapping targets | 0 | 0 | 0 | 0 | 0 | 0 | 0 | PASS |
| L5 frequent controls in the top half | — | 0 | 0 | 0 | 0 | 0 | — | PASS |
| L5m / L5c / L5s worst distance to a bottom corner, mm | — | 22.1 / 54.2 / — | 22.1 / 54.2 / — | 22.1 / 65.9 / 20.3 | 22.1 / 68.3 / 29.2 | 22.1 / 68.3 / 29.2 | — | baseline |
| L5p pause, mm (info) | — | 58.8 | 58.8 | 58.8 | 58.8 | 58.8 | — | info |
| L6 marker missing while an enemy is off screen right | — | not exercised | not exercised | not exercised | not exercised | not exercised | — | **n/a in the set; FAIL by code** (QA-B026) |
| L7 smallest node font px | 12 | 12 | 12 | 12 | 12 | 12 | 12 | PASS (12 px = 13.1 dp) |
| L8 targets outside the safe area | 0 | 0 | 0 | 0 | 0 | 0 | 0 | PASS |

Notes:
- **Top screen only:** the result screen dump also holds the HUD buttons under the result panel. Targets under a later full-screen top-level layer (here `/Result`) are left out, because the player cannot reach them.
- **L6 in the fixed set:** no alive enemy is beyond the right camera edge at the 5 capture times, so the set does not exercise L6. The code makes the answer clear anyway. `hud.gd` reads `snapshot.threat` (line 250), but nothing in src/gameplay, src/core or INTERFACES.md publishes a `threat` field, so both markers are never shown (QA-B026). 01 D39 names "keep the off-screen markers" as the mitigation for the zoom's shorter enemy warning time, but the markers do not exist in the game.
- 07 will add a frame with an off-screen enemy (r01 before the first contact) when the capture script changes next. That needs a new render-identity proof.

## 04's genre reference table: 07 sample check
When 04 commits its genre layout reference, 07 picks 2 rows at random and checks the source and the measured value against the official store page or developer material. Status: **waiting**. No 04 reference table on origin/main at f606801. 06's docs/art/ui/GENRE_HUD_REFERENCE.md (02ec60f) is 06's art reference, not 04's layout table.
