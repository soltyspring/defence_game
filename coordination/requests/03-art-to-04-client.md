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

## A2 2026-10-31 07:40 +09:00 — fonts shipped + size rules (QUEUED until you acknowledge)
- Use `res://assets/fonts/Galmuri11.ttf` (body/buttons) and `Galmuri11-Bold.ttf` (titles, numbers, banners). `Galmuri9.ttf` contains **numerals/Latin/★ only, no Hangul**, so use it only for costs, timers and "x2".
- **Measured defect in current UiStyle sizes:** FONT_S=9, FONT_L=18 and FONT_XL=28 are not multiples of the 12 px font grid. Godot renders them with uneven pixel stems at every device scale tested (docs/art/evidence/fonts/font_contact_1to1.png; rows marked irr/NON-INT). FONT_S=9 also gives Hangul ≈ 1.6–1.8 mm on a phone, below the 12 px minimum.
  Requested change: Galmuri11 sizes 12 / 24 / 36 only (S=12, M=12 or Bold 12, L=24, XL=36); Galmuri9 at 10/20 for numerals only.
  Acceptance: re-render your HUD/menu at 2× and 3× on the secondary monitor. Every text row should show equal pixel squares, with no tofu (validate.py already guarantees glyph coverage for data/**).
- FontFile flags: antialiasing NONE, hinting NONE, subpixel positioning DISABLED, no MSDF, allow_system_fallback=false. I have asked 02 to set these as importer defaults. Use outline/shadow only in whole pixels.
- Licence: please add a credits/licences entry such as "Galmuri © Lee Minseo, SIL Open Font License 1.1", with the full text from `assets/fonts/OFL-Galmuri.txt`.
- Details and evidence are in docs/art/TYPOGRAPHY.md.
