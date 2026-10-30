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

## Correction + concrete requests 2026-10-31 ~09:00 KST (supersedes X1–X3 above)
Evidence: build/qa/real/ko_16x9_r01_v2_*.png and godot_20261031_081441.log (your 08:14 run), code read only.

**X3 CLOSED — not a defect.** The "보급이 부족합니다" toast in 3_hud comes from tests/integration/test_ui_integration.gd:193 `events.toast.emit("not_enough_gold", {})`, 2 frames before `shot("3_hud")`. Optional: call `shot("3_hud")` before line 193 (or hide the toast first), so the screenshot shows a normal start state and reviewers are not misled.

### R09-04-5 Base HP numbers (was X1) — P2 readability
- Repro: any battle, e.g. r01 via test_ui_integration visible run. src/ui/hud_top.gd `_draw_bases` draws bars + "VS" only; HudSnapshot already carries player_base/enemy_base hp and hp_max; your boss bar already draws hp numbers.
- Competitor basis (Play KO store screenshots, 2026-10-31): Lucky Defense shows the loss counter "28 / 118" permanently; 궁수키우기 RPG (com.ohm1004.Defense) shows wall HP "1484/2020" on the bar; Random Dice shows lives as 3 hearts. All show the loss condition as an exact count. Correlation only, not proof of effect.
- Ask: numeric HP for both bases (e.g. "800" or "800/800", your choice), Galmuri9 10/20 or Galmuri11 12/24 only.
- Acceptance: (1) 640x360 1x and 1280x720 2x real captures: number legible, integer-pixel (03 font_contact method, irregular=0), not overlapping the bar edge or "VS". (2) Value equals snapshot hp after a scripted damage call (test assert). (3) Worst layout (640 + notches) does not overflow (HudLayout.validate empty).

### R09-04-6 Result-screen star icon wrong (was X2) — P2
- Repro: same run, 5_result.png. Log: all three reasons met=true, stars=3, so three identical markers are expected, but the drawn sprite is a red book-like shape (4x zoom), not a star. Consistent with your note that the ui_main import is stale (02 R11).
- Ask: after 02 re-imports, re-capture; plus one capture with mixed results (e.g. win, base <50%, over time).
- Acceptance: met rows show icon_star, unmet rows show icon_star_empty + dim text (result.gd 98–103); in greyscale the met and unmet rows are still distinguishable by shape; the stale-import warning is absent in the log.
