# 04-client → 03-art
Date: 2026-10-31 07:20 +09:00

## R1 Bundled UI font (P1 release risk)
The runtime currently uses Godot's fallback font. 127 of the 131 Korean UI characters are missing from it and render only through OS fallback (`build/qa/typography_report.json`). Android is unverified. Please add an OFL Korean+Latin font with a licence file under `assets/fonts/`, and a manifest entry `"fonts": {"ui": "res://assets/fonts/<file>.ttf"}` (or `{"path": ...}`). `src/ui/ui_style.gd` picks it up automatically. `tests/ui/test_ui.gd` then fails if any UI character is missing from that font. My sizes are 9–12 logical px for body text and 18–36 px for titles, on a 640×360 base with 2–3× device scale. If the pixel font's grid needs specific sizes (e.g. multiples of 11/12), tell me and I will snap FONT_* constants to them.

## R2 Visual observation from the real game (secondary-monitor capture 07:13)
`build/qa/visible/screen_20261031_071349_008s.png`: two thin vertical white lines appear in the sky/hills at about x=440 and x=578 (1280×720 window, i.e. ~220 and ~289 logical). This could be a biome layer seam/bleed or 02 drawing. Please check the meadow layers. I sent the same note to 02.

## R3 Consumed
`ui_main` icons are used now: icon_supply/energy/gold/pause/lock/star/star_empty, btn_move_left/right, card_<unit>, icon_<skill_id>. Missing card art (fast, siege) falls back to drawn glyphs.

## R4 (08:20) Stale ui_main import gives wrong icons in every visible run (03 + 02)
- Observed: in visible runs at 08:14, card, star and coin icons showed the wrong art (red ribbons in star slots, blank worker card). Cause: `assets/atlases/ui_main.png/json` were re-packed at 08:14 (uncommitted, your WIP), but `.godot/imported/ui_main.png-b8d0…md5` still has `source_md5=224f322f…` while the PNG is now `f16e31cf…`. The size is the same (256×256), so frame rects point at old art.
- 04 mitigation (183e4a6): `UiStyle` compares the source PNG md5 with the import md5. If they differ, it disables atlas icons (vector glyph fallbacks) and prints `[UiStyle] atlas ui_main import is stale`. This only works in the dev tree, not in exports.
- Please commit the png+json together and ask 02 to re-import under the import lock. I will then re-capture the icon screens. The result screen now has 3 star rows with reason text (★ win / base HP / time); if you drew new result ribbons for it, tell me the frame names.

## 17:45 Reply to A10: per-locale title pages wired (a6369ba)
- title_block.gd uses `"ui_title_%s" % locale`. The main menu acquires only the current locale's page (and switches if the language changes) and releases it in `_exit_tree`, so it is freed in battle.
- Real engine on DISPLAY2, HEAD 0f3dfc8 snapshot + a6369ba files, ko/en at 640+notch and 1280+notch: logo drawn (mode=logo); `ui_title_<loc>` refs=1 on the menu and the other locale's page not loaded; refs=0 and unloaded in battle. Integration 48/48 ×4. Evidence: build/qa/title_v011_0f3dfc8/{ko,en}_{640x360,1280x720}_notch_{1_menu,3_hud,5_result}.png. The new village background and bakery card art show in HUD and result.
- Chrome colour proposal (C_BG/C_PANEL/…): not done yet. It changes every 04 screen and the contrast tests, so it is a separate change; I will do it after 08's quiet window.
