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

## 18:05 A11 reply: edge marker written; icon request + A10 colours applied (commit after 18:30)
- **Markers (src/ui/threat_marker.gd):** a 44×34 plate at the left/right edge, just above the lane row (bottom 34 px above the ground). Top row: 16×16 icon on the inner side, arrow on the outer side. Below: distance "57m" (Galmuri11 12 px). Never takes touches. Shown when the nest has < 24 px on screen (your contrast limit) or when an enemy is off screen. Inert until 02 publishes the snapshot field (R16).
- **Icon request (your offer):** please draw in ui_main, 16×16, no padding inside the frame:
  - `icon_nest`: the mould nest silhouette, readable on the dark plate `C_TOAST_BG` (rgba 0.05,0.05,0.08,0.82).
  - `icon_enemy_near`: a generic mould-army head or emblem (not a specific unit), same plate.
  Until they exist the UI draws vector stand-ins: a green-grey dome with dark spots (nest) and a red diamond with "!" (enemy). The two differ by shape, so colour-blind players can tell them apart.
  **Update 18:36 (31164c8):** your `icon_nest` (A12) is used as is. For enemies I use the existing `icon_skull`, so `icon_enemy_near` is NOT needed; request withdrawn. Vector stand-ins remain only if a frame is missing.
- **A10 chrome colours applied in ui_style.gd:** C_BG #2a1a12, C_PANEL #3d2519 (alpha 0.92 kept), C_PANEL_LIGHT #6e4528 (0.95), C_DISABLED #2f3140 (0.92). TouchButton's default fill now follows C_PANEL_LIGHT (it was a hard-coded copy of the old blue). I re-computed your ratios (opaque): 14.65 / 12.45 / 9.45 / 7.22 / 5.49 / 5.76. They match yours, and a new test pins them (±0.1). Composited over the battlefield the alpha panels give e.g. C_GOLD on C_PANEL_LIGHT 5.00–5.73.
- Observation, not changed: the unmet hollow star outline `C_STAR_OFF` on C_PANEL is 1.70:1 (it was 1.80 on the old panel). It is read by shape (hollow vs filled), but it is faint. Your call whether to propose a lighter outline.
- Captures of menu, HUD, card row and result with the new colours: after 08's window (18:30), not done yet.
  **Done 18:34 (DISPLAY2, HEAD fca9346 snapshot + 31164c8 files):** real engine ko/en at 640+notch, 1280+notch, 1600+notch (integration 48/48 ×4): build/qa/chrome_threat_fca9346/*_{1_menu,2_round_select,3_hud,5_result}.png. Brown panels and buttons, locked tiles stay blue-grey (C_DISABLED), text readable. Markers (mock threat data, 640 / 640+notch / 800+notch): build/qa/chrome_threat_fca9346/mock/*_{3_hud (nest 29m), 3t_threat_enemy_ahead (skull 50m), 3u_threat_enemy_behind (left, skull 28m)}.png. On the real engine the markers stay hidden until 02 R16.

## 19:25 Unit size request (07 QA-J1; numbers in docs/qa/LANE_OCCLUSION.md §2)
- Measured from your atlases (alpha bounding box, idle + walk frames) and converted for 1080×2400 phones at 360/393/412 dp (k=3, 0.159/0.173/0.181 mm per view px). Soldier bodies are 19–21 px = 3.0–3.8 mm, e_swarm 15 px = 2.4–2.7 mm, hero 32 px = 5.1–5.8 mm. Only siege (40 px) and the bosses reach 6 mm. The line I used is 6 mm body height (about 1° at 33 cm), a working criterion and not a standard. Tell me if you prefer another.
- **Request (option A):** soldier and regular enemy bodies at ~32 px. That is 48 px frames like the hero and e_brute, pivot at the feet (same contract), and body ≥ 30 px for e_swarm. Alone this gives 5.1–5.8 mm. With 02's proposed pixel-exact world zoom 4/3 (option B, asked in R17) it gives 6.8–7.7 mm. The budget impact is yours to judge: char pages roughly double in area.
- The bottom HUD no longer covers sprites (45c05f0, 0 px in all measured conditions). Your art is not clipped by the UI.
