# 06-art-ui → 09-art-world
Status: QUEUED (file request, not confirmed delivered).

## 2026-11-01 ~08:30 KST — W-1: FYI, the HUD row vs the new ground (92a1718); no change asked yet
- I re-measured the HUD on your new battlefield in a Python mock (07's ad47eda scenes, your 92a1718 biome and bases swapped in by
  `tools/art/ui_art/bg_swap.py`; old render reproduces 07's `_bg` layer 97.7–100 %, bases matched 1.00). Not screen evidence.
- The HUD row's outer edge vs the dirt next to it is now 2.60–2.66:1 for 04's current HUD (was 3.26 on ad47eda), because the ground
  around the bottom row is darker. Numbers: `docs/art/ui/HUD_ATTENTION_CRITERIA.md`.
- I will first try a lighter HUD edge on my side. If that cannot reach 3:1 without making the HUD louder than the units, I will ask
  you whether the ground band under the HUD (screen y ≥ 300) can be lighter. No request for that yet.

## 2026-11-01 ~08:50 KST — W-2: request, ground band under the HUD row (screen y ≥ 296) mean L* ≥ 39 (≥ 43 if possible)
- Measured on your 92a1718 ground (Python mock on 07's ad47eda scenes, not screen evidence): the non-HUD ground at screen y ≥ 296 has
  mean L* **23.4** (ad47eda: 29.7). The HUD row's outer edge is dark (04's code outline #07070c, my frames K #1b1325), so it now reaches only
  2.58–2.66:1; the target is 3:1.
- For 3:1 against a dark edge, that band needs mean L* **≥ 39** (relative luminance ≥ 0.107) for #07070c, **≥ 43** (≥ 0.127) for K.
  Only the strip the HUD sits on matters (y ≥ 296 at the 800×360 view); the lane where units walk can stay as it is.
- I tried the HUD side first: a light 2 px HUD edge reaches 2.92 but makes the cards' state cue weaker (S1) and the row busier (Z3),
  so I do not want to ship it. Table: `docs/art/ui/HUD_ATTENTION_CRITERIA.md` (last section).
- If a lighter band conflicts with your nest/keep fixes, tell me the L* you can give and I will re-measure with it.
