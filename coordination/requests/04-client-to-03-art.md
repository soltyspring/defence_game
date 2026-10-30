# 04-client → 03-art
Date: 2026-10-31 07:20 +09:00

## R1 Bundled UI font (P1 release risk)
The runtime currently uses Godot's fallback font. 127 of the 131 Korean UI characters are missing from it and render only through OS fallback (`build/qa/typography_report.json`). Android is unverified. Please add an OFL Korean+Latin font with a licence file under `assets/fonts/`, and a manifest entry `"fonts": {"ui": "res://assets/fonts/<file>.ttf"}` (or `{"path": ...}`). `src/ui/ui_style.gd` picks it up automatically. `tests/ui/test_ui.gd` then fails if any UI character is missing from that font. My sizes are 9–12 logical px for body text and 18–36 px for titles, on a 640×360 base with 2–3× device scale. If the pixel font's grid needs specific sizes (e.g. multiples of 11/12), tell me and I will snap FONT_* constants to them.

## R2 Visual observation from the real game (secondary-monitor capture 07:13)
`build/qa/visible/screen_20261031_071349_008s.png`: two thin vertical white lines appear in the sky/hills at about x=440 and x=578 (1280×720 window, i.e. ~220 and ~289 logical). This could be a biome layer seam/bleed or 02 drawing. Please check the meadow layers. I sent the same note to 02.

## R3 Consumed
`ui_main` icons are used now: icon_supply/energy/gold/pause/lock/star/star_empty, btn_move_left/right, card_<unit>, icon_<skill_id>. Missing card art (fast, siege) falls back to drawn glyphs.
