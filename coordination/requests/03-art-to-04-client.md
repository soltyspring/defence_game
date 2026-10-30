# 03-art → 04-client

## A1 2026-10-31 07:05 +09:00 — UI art available (commit 9b4ee0b)
Page `ui_main` (256×128, load policy `always`, 0.12 MiB GPU). Frames are listed in `assets/atlases/ui_main.json`; use them via `Atlas.get_frame_texture("ui_main", name)`.
- Icons 16×16: icon_gold (alias icon_supply), icon_mana (alias icon_energy), icon_worker, icon_gem, icon_star, icon_star_empty, icon_heart, icon_lock, icon_pause, icon_play, icon_speed_1x, icon_speed_2x, icon_settings, icon_home, icon_retry, icon_close, icon_sound, icon_sound_off, icon_skull, icon_crown, icon_army.
- Cards 24×24: card_worker, card_melee_basic, card_ranged_basic, card_tank, card_hero_captain. Enemy portraits: portrait_e_grunt/e_swarm/e_spitter. Skills 24×24: icon_skill_slam/rally/barrage (also `skill_skill_*`).
- 9-slice (`nine_slice: [l,t,r,b]` in the frame entry; use NinePatchRect or StyleBoxTexture): btn, btn_pressed, btn_disabled, btn_gold (16×16, margin 5), panel, panel_dark (24×24, margin 8), card_frame, card_frame_disabled, card_frame_selected (20×24, margin 6), bar_frame (12×8, margin 3). Fills 4×6 (margin 1): bar_fill_ally, bar_fill_enemy, bar_fill_mana, bar_fill_gold, bar_fill_cooldown.
- Hero move buttons 32×32: btn_move_left, btn_move_right. At 2×/3× integer scale they are 64/96 device px, which meets your ≥56 dp target on most phones; please verify on device.
- Digits 5×7 (outlined): digit_0..9, digit_plus/minus/slash/x; gold variant digit_gold_*, red variant digit_red_*.
- Keep scaling integer and the filter nearest. For a non-integer UI scale, please tell me which frames shimmer (attach a screenshot).
- Font: QUALITY_REVIEW makes 03 the owner of font assets and licences. I will publish a candidate comparison (Korean + Latin + numerals, OFL) under docs/art/TYPOGRAPHY.md and the font files under assets/fonts/. Until then please use the Godot default font only as a fallback.
- HUD layout in docs/art/previews/battle_mock_*.png is a sketch, not a layout spec.
