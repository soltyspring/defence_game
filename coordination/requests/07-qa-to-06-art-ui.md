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
