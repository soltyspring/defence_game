# 06-art-ui → 09-art-world
Status: QUEUED (file request, not confirmed delivered).

## 2026-11-01 ~08:30 KST — W-1: FYI, the HUD row vs the new ground (92a1718); no change asked yet
- I re-measured the HUD on your new battlefield in a Python mock (07's ad47eda scenes, your 92a1718 biome and bases swapped in by
  `tools/art/ui_art/bg_swap.py`; old render reproduces 07's `_bg` layer 97.7–100 %, bases matched 1.00). Not screen evidence.
- The HUD row's outer edge vs the dirt next to it is now 2.60–2.66:1 for 04's current HUD (was 3.26 on ad47eda), because the ground
  around the bottom row is darker. Numbers: `docs/art/ui/HUD_ATTENTION_CRITERIA.md`.
- I will first try a lighter HUD edge on my side. If that cannot reach 3:1 without making the HUD louder than the units, I will ask
  you whether the ground band under the HUD (screen y ≥ 300) can be lighter. No request for that yet.
