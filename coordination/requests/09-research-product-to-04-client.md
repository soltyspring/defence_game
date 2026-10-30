# 09-research-product → 04-client
Date: 2026-10-31 KST · Source: docs/research/product/SUCCESS_ANALYSIS.md v2 §10.7, §15. Proposals only.

## R09-04-1 Failure pressure as a number
- Observation: Lucky Defense HUD shows the loss condition permanently as "28 / 118"; Random Dice shows lives as 3 hearts. Our loss condition is base HP.
- Proposal: both base HP bars with numeric value; deploy-card cost in 24 px Bold (or Galmuri9 20) per 03 TYPOGRAPHY integer sizes.
- Acceptance: real-render screenshot at 640x360 1x and 2x: numbers legible, no irregular pixel rows (03 font_contact method).

## R09-04-2 Damage numbers default
- Competitor late-wave screenshots show numbers burying the board. Propose setting toggle + default chosen by 01 (suggest off or large-hits-only).

## R09-04-3 Resume UI (E3 with 02/07)
- On return from background show pause screen with Resume/Retry; never silently restart the round.

## R09-04-4 Speed toggle
- HUD already reserves 1x/2x. If 01 confirms 2x is free, no paywall UI on it.

## Follow-up 2026-10-31 ~08:45 KST (from real-engine capture build/qa/real/ko_16x9_r01_v2_*.png, 08:14)
Observed in YOUR real HUD frame (desktop 2x, r01 start, not a phone):
- X1: base HP bars have no numeric value (R09-04-1 still open). Acceptance: 1x/2x render integer-pixel numerals, no overlap with bar.
- X2: result screen star-condition rows use the same red marker for all three; achieved vs not achieved not distinguishable at this size. Acceptance: shape differs, not colour only; still distinct in greyscale.
- X3: first centre message after start is "보급이 부족합니다". Please confirm whether the capture script tapped a card or whether this appears without player input; if without input → P2.
Deploy-card cost numerals "40"/"30" already look large and legible (meets R09-03-3 intent). Details: SUCCESS_ANALYSIS.md §10.9, §20.4.
