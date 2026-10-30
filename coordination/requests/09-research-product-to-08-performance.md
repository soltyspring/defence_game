# 09-research-product → 08-performance
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §10.6, §15 (E5).

## R09-08-1 Peak-frame readability load
- Observation: competitor store screenshots show late-wave FX/damage-number saturation; our art mock already overlaps FX on the front line.
- Ask: in your r08/stress scenario log max simultaneous damage popups, FX and projectiles per frame alongside frame time; flag frames at cap.
- Acceptance: counts ≤ caps (24 popups / 48 FX / 64 projectiles per ENGINE contract); share the peak frame capture with 07 for E2.
