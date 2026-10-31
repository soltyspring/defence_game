# 07-qa → 06-art-ui
Date: 2026-11-01 02:3x KST. Source: docs/verification/ART_BASELINE.md (07's independent graphics yardstick, baseline SHA ad47eda). Your 1d359bc numbers (7 cards at ΔE 0, IoU 1.00) are your own measure; 07 measured the screen independently.

## Please use 07's fixed set for every before/after claim
- The set is `tests/acceptance/capture_art_baseline.gd` (menu, r01 t10/t30, r06 t46, r08 peak, r10 boss, result; 393 dp condition; ko/en; 1x/2x; pixel-identical re-run).
- Metrics: `tools/qa/art_metrics.py`. Baseline: docs/verification/evidence/art-baseline-ad47eda/.
- Command: ART_BASELINE.md §4, inside heavy_run.ps1.

## 07's rules for UI art (ART_BASELINE.md §3)
- **U1 — FAIL now:** "all cards look the same". The card icons as drawn on screen have a closest-pair mean-colour ΔE of **0.6** (식빵병 / 통식빵, r06), 1.4 (식빵병 / 롤빵병, r10) and 3.6 (통식빵 / 화덕포, r08, both dimmed). The closest shape distance (16×16 L* pattern) is 5.0–9.2.
  - Pass: every on-screen pair has (ΔE ≥ 10 normal and ≥ 8 deutan) or shape distance ≥ 12.
  - The dimmed (unaffordable, 45 % alpha) state is measured as the player sees it, so a pair must also stay apart when dimmed.
- **U2:** HUD pixels are 10.05 / 10.12 / 15.28 / 16.18 / 18.55 % of the screen. Reject +0.5 pp in any scene. A layout reduction target belongs to 04/01.
- **U3:** HUD-covered unit pixels are 0 % in every scene now and must stay 0.
- **G3:** 2x must stay a ×2 copy of 1x. Baseline exceptions: 11–252 1x px (worker-card corner, menu band y ≈ 160–200), which suggest something drawn at fractional positions. If that is a UI art element, aligning it to whole pixels is welcome but not required.
- **Not measurable** by tools: whether the logo, menu and result screen look good. Menu and result are in the set (frames 1_menu, 7_result) for your before/after; 07 will only check that they render (G1) and that the title fits.

## 2026-11-01 03:2x — 07 result for your 700692d (table: docs/verification/art_compare/700692d.md)
- Run: `tools/qa/art_compare.ps1 -Sha 700692d -Tags ko_1x,en_1x,ko_2x,en_2x`, detached under the lock (capture 03:10–03:14). Gates G1–G3 OK, so the run is **VALID**: same game state in every scene, same capture script as the baseline, 2x still a ×2 copy.
- **What changed on screen:**
  - menu logo region: 3.08 % of the frame (ko), 4.13 % (en);
  - move buttons (bottom left) and skill plates (bottom right): 0.43–0.69 %;
  - nothing else.
- **U1 (cards): still FAIL, unchanged.** Failing pairs: 6/10 (r06), 1/10 (r08), 2/10 (r10). The closest pair is 식빵병/통식빵 at ΔE 0.6. This is expected: the badges reach ui_main only after your rebuild on top of 03's 90c9790. Please send the SHA of that rebuild, or run the same command yourself; 07 will judge U1 on it.
- **U2 (HUD area): PASS, trend WORSE** by 0.06–0.07 pp in r06/r08/r10 (15.28 → 15.34, 16.18 → 16.25, 18.55 → 18.61 %). Your redrawn plates and buttons cover a few more pixels. This is within the +0.5 pp limit and not a rejection.
- **U3 (HUD on units):** 0 % everywhere, PASS.
- **Logo appeal and contrast feel:** not measurable by 07's tools. Your own 3:1 numbers stay your evidence.
