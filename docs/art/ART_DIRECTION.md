# ART_DIRECTION.md — visual identity and asset contract (owner: 03-art)
Art version 0.3.0 · 2026-10-31 · Status: **initial production pack, theme still PROVISIONAL** (Q1 pending in coordination/requests/USER_QUESTION.md). The default theme below is a reversible working assumption. The user has not approved it.

## 1. How the art is made (provenance)
- Tool inventory on this machine: Python 3.11.9, Pillow 11.2.1, numpy 2.2.4. There are **no** image-generation, Aseprite or ImageMagick tools. Godot 4.7.2 is in tools/engine (owned by 02).
- Every pixel comes from hand-written deterministic code in `tools/art/`. Characters are ASCII pixel maps (heads/torsos/shields) on a chibi rig with Bresenham-drawn limbs and weapons. Buildings, backgrounds and FX are procedural, using seeded RNG. No AI image generation, stock art, reference graphics or fonts were used.
- Rebuild with `python tools/art/build.py` and verify with `python tools/art/validate.py [--determinism]`. Two builds produce byte-identical pages.
- Licence: original work made for this project and owned by the project owner. It contains no third-party assets.

## 2. Visual identity (default theme: "Lantern Kingdom vs Bramble Horde")
- **Style:** chibi pixel art, side view facing right, 1 px dark outline (`outline #1b1325`) on every character/prop. Light comes from the upper left. Each material has a 2–4 step ramp, and anti-aliasing is used only inside shapes.
- **Faction colour coding (mobile readability):** the player side uses blue `#2f5fb3` / gold `#e5a826` / steel / warm skin. The enemy side uses green `#2f6d3a` skin with purple `#5b3488` cloth and crude wood. Hero = red plume and red cape (the only red on the player side) so it stands out in a crowd.
- **Silhouette rule:** every unit class has a unique silhouette at 1× (spear line, bow arc, tower shield, pickaxe, club, hood + gourd, low beetle).
- **Palette:** Hearth-48 = 47 opaque colours + 1 translucent shadow (alpha 96). Files: `docs/art/palette/hearth48.gpl` (GIMP/Aseprite), `.hex`, `hearth48_swatch.png` (outside game content, so they are never packed). validate.py fails any texel outside the palette.
- **Re-theming:** IDs follow 01's data (`melee_basic`, `e_grunt`, ...). If Q1 picks another theme (e.g. bakery knights vs mould), only the ASCII heads/torsos, weapon functions and palette assignments change. Rig, animation timing, pivots, frame sizes, atlas layout and the manifest schema stay stable.

## 3. Scale and display
- Reference view 640×360, `canvas_items` stretch, `expand` aspect, **integer scaling**, nearest filter, pixel snap on (project.godot already sets these).
- Sizes in reference pixels: infantry figures 22–24 px tall in 32×32 frames, hero ~33 px in a 48×48 frame, swarm beetle 28×24, bases 96×128, HUD icons 16×16, skill/card icons 24×24, move buttons 32×32.
- Lane: the feet line is row 15 of the `ground` layer. Place the ground layer at `view_y = ground_y − 15`. The previews use ground_y = 295.

## 4. Frame and pivot conventions (matches INTERFACES.md §5.2)
- Characters: `pivot = [px, H−1]` = the ground point under the feet. The feet outline is on row H−1. Units, projectiles and FX are drawn **facing right**. The engine mirrors the enemy faction with `flip_h`, and the mirrored pivot_x is `W − pivot_x`.
- Bases are pre-oriented: `base_player` gate faces right, `base_enemy` gate faces left. Their `anim_sets_meta.no_flip=true`, so do not flip them.
- FX/projectiles: pivot is the centre unless the atlas JSON says otherwise. Ground FX (`skill_slam`, `skill_rally`, `skill_barrage`, `spawn`, `heal`, `fire`) use bottom-centre.
- `hit_frame` is the frame where damage applies. `events` holds other named frames (`release` for hero cast). `points.projectile_spawn` is a frame-space offset (archer, spitter).

## 5. Animation set (current)
| anim_set | atlas | frame | anims (frames @fps) |
|---|---|---|---|
| hero_captain | char_player | 48×48 | idle 4@5, walk 6@10, attack 6@14 (hit 3), cast 6@12 (release 4), hit 2@10, death 6@8 |
| worker | char_player | 32×32 | idle 4@4, walk 6@10, work 4@8 (hit 3), carry 6@9, death 6@8 |
| melee_basic (spearman) | char_player | 32×32 | idle 4, walk 6, attack 5@12 (hit 2), hit 2, death 6 |
| ranged_basic (archer) | char_player | 32×32 | idle 4, walk 6, attack 4@10 (hit 2, projectile_spawn), hit 2, death 6 |
| tank (shieldbearer) | char_player | 32×32 | idle 3@3, walk 6@8, attack 4@9 (hit 2), hit 2, death 6 |
| e_grunt | char_enemy | 32×32 | idle 4, walk 6@11, attack 4@10 (hit 2), hit 2, death 6 |
| e_spitter | char_enemy | 32×32 | idle 4, walk 6, attack 4@10 (hit 2, projectile_spawn), hit 2, death 6 |
| e_swarm (beetle) | char_enemy | 28×24 | idle 2, walk 4@14, attack 3@10 (hit 1), hit 2, death 5 |
| base_player / base_enemy | bases | 96×128 | idle 2@3, damaged 2@5, ruined 2@5 (+ static frame `base_player` / `base_enemy`) |
| arrow, tower_bolt, spit, rock | fx_combat | small | fly |
| hit_spark, hit_spit, explosion, death_poof, dust, spawn | fx_combat | | play |
| skill_slam, skill_barrage / skill_rally, heal, fire, coin | fx_combat | | play / loop |

Every character also has `die`, an alias of `death` that shares its frames (01 data uses `die`). Death = hurt → kneel → lying (a lossless 90° rotation) → ordered-dither dissolve, so it needs no alpha fade.

Missing (backlog, in roster order): fast, siege, e_brute, e_bomber, boss_warlord, boss_overlord, 2nd/3rd biome. The engine draws fallbacks until they exist.

## 6. UI art (`ui_main`, always resident)
Icons: `icon_gold` (alias `icon_supply`), `icon_mana` (alias `icon_energy`), `icon_worker`, `icon_gem` (meta-currency candidate), `icon_star`, `icon_star_empty`, `icon_heart`, `icon_lock`, `icon_pause`, `icon_play`, `icon_speed_1x/2x`, `icon_settings`, `icon_home`, `icon_retry`, `icon_close`, `icon_sound`, `icon_sound_off`, `icon_skull`, `icon_crown`, `icon_army`.
Cards: `card_<unit_id>` for worker, melee_basic, ranged_basic, tank, hero_captain. These are 24×24 portraits cropped automatically from idle frame 0, so they stay in sync with the sprites. Enemy portraits are `portrait_<enemy_id>`. Skills are `icon_<skill_id>` and `skill_<skill_id>`, both 24×24.
9-slice (frame JSON has `nine_slice: [l,t,r,b]`): `btn`, `btn_pressed`, `btn_disabled`, `btn_gold`, `panel`, `panel_dark`, `card_frame`, `card_frame_disabled`, `card_frame_selected`, `bar_frame`. Bar fills (4×6, 9-slice 1): `bar_fill_ally`, `bar_fill_enemy`, `bar_fill_mana`, `bar_fill_gold`, `bar_fill_cooldown`.
Digits 5×7 incl. outline: `digit_0..9`, `digit_plus/minus/slash/x` in white, plus `digit_gold_*` and `digit_red_*` variants (for damage and income popups).
Text font: no font is bundled. Korean needs a full Hangul pixel font. Recommendation for 04: an OFL-licensed pixel font such as Galmuri, verified by 04, with its licence file shipped. 03 can supply a Latin/digit bitmap font if needed.

## 7. Backgrounds (`biome_meadow` = data `biome_01`)
Layers (back to front) with view_y and parallax: `sky` 16×360 (repeat every 16 px horizontally, parallax 0, clear colour `#3b5aa8`), `far` 640×150 mountains + clouds (y 100, 0.15), `mid` 640×120 hills/trees (y 180, 0.45), `ground` 640×80 lane (y = ground_y − 15, 1.0, tile), `front` 640×18 grass tufts (y 342, 1.15, drawn above units but below the HUD). Every layer is seamless at 640 px, which validate.py checks. Use Parallax2D `repeat_size=(640,0)` (or 16 for sky). The atlas regions keep repeat off.

## 8. Readability review
`docs/art/previews/battle_mock_1x.png` and `battle_mock_2x.png` compose the real atlas frames as the engine would (the HUD in them is only a sketch, since 04 owns the real layout). At 1× the factions separate by colour, and every class is identifiable by silhouette. The hero is the tallest figure and has the only red cape. Contact sheets: `docs/art/previews/sheets/<anim_set>.png` (every anim, pink pivot marker), and `docs/art/previews/atlas_<id>.png` (the packed pages at 2×).

## 9. Atlases, memory and import → see docs/art/ATLAS_CONTRACT.md and the generated docs/art/ATLAS_BUDGET.md.
