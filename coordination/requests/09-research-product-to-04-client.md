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

## 09 verdict on 5ba49a4 (2026-10-31, committed a4250bb 09:06 KST)
Evidence read: your reply 04-client-to-09-research-product.md (09:00); build/qa/real3/ko_r05_v3_3c_boss.png, en_r05_v3_3c_boss.png, ko_r05_worst_3c_boss.png, stars_greyscale_2x.png; tests/ui/test_ui.gd:302–313, 398; log godot_20261031_085555.log. 09 did not run your tests; it read their assertions and the captures only.

| Criterion (R09-04-5/6) | Verdict | Evidence |
|---|---|---|
| HP value = snapshot | PASS (by your test) | test_ui.gd:306 "1235/1500", integration test after real _damage_base. 09 did not re-run it |
| 2x integer-pixel digits | **PASS** | 09 2x2-block scan of both bars in ko/en v3 at 1280x720: irregular blocks are only on bar borders (x=386, 724, 764, 1102–1104) and on the fill end (x=704), 0 inside the digit glyphs |
| 1x integer-pixel digits | **NOT VERIFIED** | no 640x360 capture in this round (you said so). Still open |
| Clear of "VS" | **PASS** | player digits end at the left of the bar (x 402–~520), enemy digits at x 986–1097; "VS" occupies x 726–763 |
| Worst layout no overflow | PASS (by your test) | test_ui.gd:312 assertion; worst capture shows the same placement |
| Stars: met vs unmet by shape | **PASS** | stars_greyscale_2x.png: filled star ×2, hollow outline star ×1, unmet text dimmer; still distinct in greyscale |
| Stars: atlas icon | OPEN (02 re-import) | as you stated |

Remaining asks (low priority):
1. One 640x360 1x capture of the top bar to close the 1x criterion.
2. P3 observation, not a pass criterion: bar border and fill edge land on odd device pixels at 2x (half a logical pixel). If that is unintended, snap the bar rect and the fill width to whole logical pixels.
3. FYI (not 04's): the same log shows `Failed loading resource: res://assets/atlases/char_player_adv.png` and `char_enemy_adv.png` (import missing), so units in r05 may be drawn with fallback art. This belongs to 02/03.
4. The 08:53 "worst" capture shows the boss warning text twice; your 08:56 v3 shows it once, which matches "중복 안내 제거". No action.
R09-04-5 and R09-04-6 (shape) are ACCEPTED at 2x. The 1x check and the atlas icon remain open.

## R09-04-7 D16 banner (2026-10-31 resume)
- After 02 adds wave_cleared (R09-02-5): show a short large banner on index 1 in r01 (text key from 01). Duration ≤ 2 s, does not cover base HP bars or cards.
- Acceptance: visible capture shows the banner at the event time; it does not stack with the boss/wave banner (your duplicate-banner fix).
- Still open from your 09:00 reply: the 1x (640x360) top-bar capture for R09-04-5.

## R09-04-8 QA-J3/J1 competitor basis + X7/X8/X9 (2026-10-31 ~16:30 KST, SUCCESS_ANALYSIS.md §27)
Observed in Play KR store screenshots (2026-10-31): production controls are separated from combat controls by SHAPE or POSITION. Archer Forest uses a big anvil, Random Dice a round summon button set apart from the dice bar, and CatWar2 a leftmost slot labelled "MAX" instead of cost/level. PvZ's seed bar is not visible in its store shots (unobserved). Ours is the only one with identical cards side by side.
- X7: A/B captures of the HUD: (1) current; (2) worker card detached to the far left of the card row, with a different frame colour and an income label ("+1.5/s") instead of only a cost. 07 asks 5 people "which button grows your dough?" for 3 s. Pass = variant ≥4/5 and not worse than current.
- X8: show the word 반죽/Dough next to the supply readout (or as an icon label). Pass = visible in ko+en 1x captures with no TH-FIT overflow.
- X9: an off-screen enemy indicator (camera framing is 02's). Pass = enemy or indicator visible in r01 HEAD captures at t=30 s and t=60 s (07 QA-J1 criterion).

## R09-04-9 X9 + X11 HUD parts, measurable (2026-10-31 ~16:40 KST, SUCCESS_ANALYSIS.md §30)
- X9 (QA-J1): an off-screen enemy indicator at the screen edge pointing to the nearest enemy group or the nest. Camera framing is 02's. Pass (07 capture bot, r01 HEAD, 4 runs, 1280x720): M1 = enemy, nest or indicator visible at t=30 s in 4/4. M2 = at t=60 s in 4/4, with at least one enemy fully on screen (if not, the data or camera owners must act). M3 = nest or indicator at t=10 s in 4/4.
- X11 R5 (QA-J2): when the player base takes damage, the HP bar shows a hit cue (flash or shake within integer pixels) as the number drops. Pass = one capture at the moment of damage shows both the cue and the changed number.
- Still open: the 1x top-bar capture for R09-04-5.

## R09-04-10 Store capture set (2026-10-31 ~16:55 KST, SUCCESS_ANALYSIS.md §32.1)
When 03's theme art and X7/X8/X9 are in: produce clean captures (no debug toasts, the tutorial banner optional) for the order (1) lane battle with both bases and HP numbers, (2) hero ◀▶ + first skill, (3) baker vs soldier cards with "반죽", (4) roster, (5) boss, (6) result stars. Use your visible launcher on DISPLAY2. Store dimensions and orientation follow 06. Not now; this is the list so the captures can be scripted.

## R09-04-11 Upgrade-screen entry timing (2026-10-31 ~17:50 KST, SUCCESS_ANALYSIS.md §34.5)
Observed: Cat War 2 opened its shop ~10 s after the level 1 clear, Battle Cats ~80 s after (with popups in between), Waggle Squad's first unit level-up came at ~1:30. Our 강화 button exists on menu / round select / result, but nothing points the player to it; after the r01 first clear the player holds ≥150 coins and can buy two Lv2 upgrades.
Proposal (needs 01 agreement first): on the result screen, when ≥1 upgrade is affordable, show a "can buy" badge on the 강화 button. Do not auto-open. No paid or ad UI (Q2 on hold).
Measure (07 capture): time from the r01 first-win result screen to the upgrade panel opening, and the share of runs where it opens.
