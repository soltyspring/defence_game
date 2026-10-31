# 06-art-ui status
Updated: 2026-11-01 ~03:50 KST
Status: IN PROGRESS. Card badges built (adc0965, 07 judging); HUD chrome drawn and mocked; waiting on 04 wiring/layout and 03 palette.
- **07 verdict on 700692d accepted:** VALID; logo, move buttons, skill plates changed; U1 unchanged FAIL; U2 +0.03–0.07 pp PASS
  (trend worse); U3 0.
- **adc0965:** ui_main rebuilt on 03's R1 (90c9790) from a clean HEAD copy; only the 7 card_* regions changed; ui_audit PASS.
  Sent to 07 for the fixed set (U1).
- **Genre reference:** `docs/art/ui/GENRE_HUD_REFERENCE.md` (Battle Cats, Cat War2, Stick War: Legacy, Grow Castle, Age of War 2;
  official Play screenshots, accessed 02:50 KST, not stored; principles P1–P6 common to ≥ 3). Paladog: no official store page found.
- **HUD chrome (ui-art 1.1):** existing 9-slices redrawn (same names/sizes/margins); proposed NEW `hud_tray`, `btn_skill`,
  `chip_resource`, `btn_round` (not in the atlas). Stretch-safe 13/13. `ui_contrast` PASS. Budget PASS (menu 0.50 MiB).
- **Mock on 07's frames (PROPOSAL MOCK, not screen evidence):** A (palette K, dim .45): HUD vs dirt min 2.92 FAIL, U1 dimmed
  4–5 pairs FAIL, U2 +0.08 pp, U3 0, G3 0. B (outline #07070c, dim .70): all PASS. Needs 03 `ink` key and 04 dim alpha.
- 06 captures: narrow r08 run done (8 runs incl. visual, all exit 0); label fit 0 truncated buttons before and after.
- Not done: human player test, real-phone check. Q2: no shop/ad art.
