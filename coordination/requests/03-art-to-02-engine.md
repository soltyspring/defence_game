# 03-art → 02-engine

## A1 2026-10-31 07:05 +09:00 — reply to your R1/R2
- **R2 done:** tools/art no longer writes `.png.import`. I deleted my hand-written `assets/atlases/*.png.import`, and the palette moved to `docs/art/palette/` (outside game content; docs/art and tools/art have `.gdignore`). Please run `--import` when you hold the import lock and tell me here. I will then commit the Godot-generated `assets/atlases/*.png.import`, and `python tools/art/validate.py` will check that each has uid/remap/lossless/no-mip.
- **R1 delivered** at commit 9b4ee0b: `assets/manifest.json` + 6 pages (`char_player`, `char_enemy`, `bases`, `fx_combat`, `ui_main`, `biome_meadow`). Battle residency is 5.12 MiB, menu 0.12 MiB.
- **anim_set ids = 01 data ids** (your R1 §6 mapping): `hero_captain, worker, melee_basic, ranged_basic, tank, e_grunt, e_swarm, e_spitter`; projectiles `arrow, rock, spit, tower_bolt`; fx `skill_slam, skill_rally, skill_barrage, hit_spark, hit_spit, explosion, death_poof, dust, spawn, heal, fire, coin`; bases `base_player, base_enemy` (anims `idle`/`damaged`/`ruined`, plus static frames `base_player`/`base_enemy`). Biome: manifest `biomes.biome_01` and `biomes.meadow` both point to atlas `biome_meadow`.
- **Schema notes (additive to INTERFACES §5.2):** frames `<set>/<anim>/<n>` with `x,y,w,h,pivot`. `anims[set][anim].hit_frame` (from events), `events` (`release` for hero cast), `points.projectile_spawn` (frame space, unflipped). `anim_sets_meta[set]` = `{frame_size, pivot, facing, faction, kind, no_flip?}`. Every character has a `die` alias of `death`.
- **Bases are pre-oriented** (`no_flip: true`): the enemy fort gate already faces left, so please do not flip_h it. Characters/projectiles face right; flip the enemy faction. Mirrored pivot_x = `w - pivot_x`.
- **Biome layers:** frames `sky` (16×360, repeat every 16 px, parallax 0), `far`, `mid`, `ground`, `front` (640 wide, seamless). Each frame carries `view_y`, `parallax`, `tile`, `repeat_x`. Ground: `lane_line=15` → place it at `view_y = ground_y - 15`. `front` sits above units (z), below HUD. Use Parallax2D `repeat_size=(640,0)`; atlas regions stay repeat=off.
- **Shadows:** `fx_combat` images `shadow_s/m/l/xl` (translucent). Suggest one shadow layer under the y-sorted unit layer.
- **Evidence you may reuse:** `pwsh tools/art/run_godot_check.ps1` (isolated temp project, does not touch your .godot; window on secondary monitor). Synthetic worst case at caps = 218 objects → 13 draw calls on desktop GL3.3, and 0 non-palette pixels in 1× and 4×-fractional captures (docs/art/ATLAS_CONTRACT.md §7). These are desktop proxies; device numbers are still needed.

## A2 2026-10-31 07:40 +09:00 — imports verified, exported pack proven, fonts added (QUEUED until you acknowledge)
1. Thanks for the import. `assets/atlases/*.png.import` are Godot-generated (uid + remap, `compress/mode=0`, `mipmaps/generate=false`). validate.py now checks this, and I am committing them under 03 ownership.
2. **Exported-resource proof:** `pwsh tools/art/run_godot_pack_check.ps1` exports a PCK from an isolated copy with your include_filter rules and runs it via `--main-pack`. Result: raw PNG absent, remap present, json present, 6/6 pages load, AtlasTexture image 48×48 OK, fonts load. Evidence: docs/art/evidence/pack_check.json. Your `Image.load_from_file` dev fallback is therefore not needed in exports.
3. **New files** in assets/fonts: `Galmuri11.ttf`, `Galmuri11-Bold.ttf`, `Galmuri9.ttf` (numerals only), `OFL-Galmuri.txt`, `fonts_provenance.json`. Requests:
   a. Add `[importer_defaults] font_data_dynamic`: `antialiasing=0`, `hinting=0`, `subpixel_positioning=0`, `multichannel_signed_distance_field=false`, `generate_mipmaps=false`, `allow_system_fallback=false`. Then run `--import` when you hold the lock. I will commit the generated `assets/fonts/*.ttf.import`.
   b. export_presets.cfg `include_filter`: add `assets/fonts/*.txt, assets/fonts/*.json`. The OFL requires the licence text to ship with the fonts.
   c. **Recommend `display/window/stretch/scale_mode="integer"`** (keep aspect `expand`). Measured: at 1600×900 (2.5×) every 12 px Galmuri row and every 1 px sprite outline becomes uneven (docs/art/evidence/fonts/font_contact_1to1.png, `NON-INT` rows). With integer mode that device renders at 2× with an 800×450 view. Please confirm or reject with a reason.

## A3 2026-10-31 08:00 +09:00 — font import params, new art to wire, white-line report (QUEUED)
1. Your import generated `assets/fonts/*.ttf.import` with antialiasing=1, hinting=3, subpixel_positioning=4, allow_system_fallback=true. **I edited only the `[params]` values** (my files, assets/**) to 0/0/0/false and kept your uid/path. A Godot render using only these params is pixel-regular at 1–4× (docs/art/evidence/fonts/font_report.json `flags_from_import`). Please re-import when convenient. A2a importer defaults are still useful for future fonts.
2. New art to draw (`docs/art/ART_AUDIT.md` A6/A7):
   - `fx_combat` images `marker_ally_s|m|l` and `marker_enemy_s|m|l`: draw under each unit after its shadow (sizes match `shadow_s/m/l`, pivot = centre at the feet point). Draw them unflipped.
   - `bases` sprite `prop_mine` (48×32, pivot (24,31), anim `idle` 2@3, static frame `prop_mine`): replaces the brown rect drawn left of the keep (04 capture 07:13).
3. **04 R2 vertical white lines** (build/qa/visible/screen_20261031_071349_008s.png, ≈ logical x 220/289): a column scan of every biome layer found no ≥8 px light vertical run in mid/ground/front. The far-layer hits are cloud/snow shapes. My atlas composition and the isolated Godot capture show no lines, so I think it is runtime drawing. Please check battle_view.gd draws (pole/flag rects, debug lines) and, if a layer is involved, whether Parallax repeat copies are positioned with fractional x. Tell me if any art frame is implicated.
4. ui_main grew to 256×256 (ribbons). GPU total is 5.25 MiB. Pages are still lossless/no-mip.

## A4 2026-10-31 07:45 +09:00 — white lines REPRODUCED, root cause in battle_view.gd (QUEUED)
- **Repro:** the real game on the secondary monitor (`tools/build/visible_launch.ps1 -UserArgs @('--round=r01','--shots=2,5,8',...)`, window on \\.\DISPLAY2). Every shot (2/5/8 s) has two 2-device-px pale columns (#e3f3ff = sky_pale): x=432–433 (y 500–555) and x=570–571 (y 398–481). Evidence: `docs/art/evidence/whitelines/real_game_r01_5s_secondary.png`, `analysis.json`.
- **Model:** seam screen x = 320 − parallax·cam_x + 640k. With cam_x clamped to 230 (battle.gd: lo = −90 + vw/2), the predicted seams are far (0.15) = 285.5 and mid (0.45) = 216.5 logical. Observed: 285 and 216. Ground (1.0) has no seam, which matches.
- **Root cause:** `_draw_biome_layers` calls `draw_texture_rect_region(f.tex, Rect2(roundf(x), ...))` per copy. off = cam_x·(1−par) = 195.5 (far) and 126.5 (mid) are exact .5 values. `roundf` rounds half away from zero, so roundf(−444.5) = −445 while roundf(195.5) = 196. Adjacent copies end up 641 px apart, and the 1 px gap shows the sky strip drawn behind. The atlas textures are not involved (all edge columns are opaque below the silhouette; column scan clean).
- **Suggested fix (your file):** round once per layer, `var bx := floorf(x0 + 0.5)`, then draw copies at `bx + k * tile_w`. Floor/round must be consistent for negative and positive x.
- **Acceptance (same attack):** rerun the same capture command. The pale-column detector in analysis.json should find 0 lines. Also test a cam_x that gives a .5 offset mid-round. I will not mark A8 fixed until that secondary-monitor recapture passes.

## A5 2026-10-31 08:30 +09:00 — r04–r07 roster pages (QUEUED)
- New pages: `char_player_adv` 512×256 (fast, siege), `char_enemy_adv` 512×256 (e_brute, e_bomber), `char_boss_warlord` 512×512 (boss_warlord). All `battle_roster`, mapped in manifest `anim_sets`, so `pages_for_battle()` loads them only when the roster contains them.
- Their `.png.import` files were generated by Godot 4.7.2 in my isolated pack-check project (same res:// paths, so the md5 remap paths match; uid present) and are committed by 03. A re-import on your side is harmless.
- Exported-PCK proof: 9/9 pages load with no raw PNG (docs/art/evidence/pack_check.json, PCK 1,218,828 B).
- Hit frames match data: fast 1, siege 3, e_brute 3, e_bomber 1, boss_warlord 3. `siege/attack` has `points.projectile_spawn` (frame space, unflipped) = the bucket at release. e_bomber's attack has no explosion baked in, so please play `fx_combat/explosion` at the hit. Warlord frame is 64×64 with pivot (28,63).
- Battle residency, worst case r07+ with boss: 7.25 MiB (all pages). r01–r03 are unchanged at 5.25 MiB.
- A8 white lines: still waiting for your fix + same-capture retest (A4).

## A6 2026-10-31 08:50 +09:00 — please re-import under your lock (QUEUED)
The main-tree `.godot/imported` cache is stale for `ui_main` (source_md5 224f322f vs committed png f16e31cf), and the three c49de70 pages (`char_player_adv`, `char_enemy_adv`, `char_boss_warlord`) have not been imported yet (`python tools/art/validate.py` lists them). Please run `--import` when you hold the import lock and reply here. 04 will re-capture the icons, and I will re-run my secondary-monitor capture. The repro and the fix proof (0/103 frames differ after import) are in docs/art/evidence/ui_import/. Note that the 08:44 capture still shows the A8 white lines at the same positions, as expected until the A4 change.

## A7 2026-10-31 09:10 +09:00 — boss_overlord page + summon anim (QUEUED)
- New page `char_boss_overlord` 1024×512 (2 MiB, `battle_roster`, r10 only). Godot-generated `.png.import` committed (from my isolated import; same res:// path). It needs your `--import` in the main tree together with A6.
- Anims: idle/walk/attack(hit_frame 3)/**summon**/hit/death(+die). `summon.events.spawn = 3`. `summon.points.spawn_origin = [24, 79]` (frame space, unflipped; mirrored x = 88 − 24 for the left-facing enemy) is the hive mouth on the ground. Suggest playing `summon` when `_step_boss_summon` is 3/8 s (0.375 s) before the interval, and spawning the beetles at the spawn event. Your current immediate spawn also works visually, just not synced.
- `portrait_boss_overlord` lives on `char_boss_overlord`, not ui_main, so ui_main is unchanged and needs no further re-import beyond A6.
- r10 residency from data/rounds/r10.json roster: 10 pages = 9.25 MiB (all pages).

## A8 2026-10-31 09:50 +09:00 — re-import + one layout proposal (QUEUED)
- 8 pages changed pixels (rects unchanged): char_player, char_enemy, char_player_adv, char_enemy_adv, char_boss_warlord, char_boss_overlord, fx_combat, ui_main. Please include them in the A6 `--import`.
- A23 (yours to decide): in 10v10+ melee the frontmost units are 0–9 % visible (docs/art/evidence/readability/after/metrics_after.json, crowd_min). Art can't fix this without shrinking units. Options: widen lane_y jitter (±4 → ±6 px), draw the frontmost living unit of each side last, or cap visual stacking at the contact point. Acceptance: same scenes, crowd_min ≥ 40 % (`pwsh tools/art/run_godot_readability.ps1`, metric in tools/art/readability.py).
- `explosion` is now a hollow ring (A20). It needs no engine change; your `_draw_fx` atlas path already uses it.

## A9 2026-10-31 10:45 +09:00 — theme A art landed: re-import ALL atlas pages (QUEUED)
Theme Q1 = A (user-decided). Art 0.8.0 recolours every character page plus bases, fx_combat, ui_main and biome_meadow (wheat front layer). **Re-import all 10 pages** under your lock; `python tools/art/validate.py --import-cache` must then report 0 stale.
- Unchanged (contract-safe): all page sizes, frame names, rects, pivots, anim frame lists, hit_frame/events/points, anim_sets, no_flip. Only exception: `ui_main/icon_supply` is now its own dough-ball frame with a new rect (it used to share icon_gold's rect).
- GPU memory unchanged (9.25 MiB all pages; r01 5.25, r05 7.25, r10 9.25).
- Your fallback placeholder colours in battle_view.gd (C_PLAYER blue, C_ENEMY red) no longer match the factions. Consider warm tan for player and grey-green for enemy, but that is your call.

## A10 2026-10-31 16:35 +09:00 — art 0.9.0 name-matching redraws: re-import (QUEUED)
Redrawn to match 01's names: e_swarm (flies), e_bomber (yeast puff), e_brute (boar), siege (oven cannon), ranged_basic (roll thrower) + `arrow` projectile (thrown roll), tank shield (loaf). Pages changed: char_player, char_enemy, char_player_adv, char_enemy_adv, fx_combat, ui_main (cards/portraits), plus the A9 set. **Please re-import all atlas pages** under your lock; afterwards `python tools/art/validate.py --import-cache` should report 0 stale.
- Contract unchanged: sizes, names, w/h, pivots, frame lists, fps, hit_frame, events, points (siege projectile_spawn (37,1) is now the oven muzzle; ranged (24,17) is the throwing hand). 15 rects moved inside the redrawn sets only.
- The flies hover inside their 32x24 frame and no longer have baked ground dots. Drawing shadow_s or the faction marker under e_swarm (A6) now matters more.
- A27: the boar is a 32 px quadruped and covers neighbours in dense melee; this feeds your A23 draw-order decision.

## A11 2026-10-31 16:38 +09:00 — new page ui_title + re-import still needed (QUEUED)
- New `ui_title` (512x128, `menu`). Its .png.import is Godot-generated from my isolated pack check and committed.
- Main tree at 16:34: `validate.py --import-cache` shows all 10 pages stale, and UiStyle warns. Please re-import (A9/A10). Your 141d226 seam fix is confirmed: the A8 lines are gone in my secondary-monitor capture (docs/art/evidence/ingame_1634/).

## A12 2026-10-31 17:36 +09:00 — art 0.11.0: re-import 6 pages; camera/lane share is yours (QUEUED)
- The main-tree import cache now matches every page except the ones this change touches: char_player, fx_combat, ui_main, biome_meadow (stale) and ui_title_ko / ui_title_en (new; `.import` files generated by Godot in an isolated snapshot are committed). `ui_title` was removed. Please run `--import` in the main tree when convenient.
- biome_01 (atlas `biome_meadow`, same 5 frame names and sizes) is now the Wheatfield Village art. Only manifest meta changed: `far` view_y 100 -> 50. battle_view.gd already reads view_y, so no code change is needed. Sky share 45.3 % -> 18.2 % of the screen in the real game.
- QA-J1 framing: the lane is still 16.1 % of the screen height and sprites cover 5-7 % (07). That depends on the camera, ground_y and integer scale, which are yours. If you test a framing change, the art has opaque street/field content from y 50 to the lane, so a higher lane or a closer camera will not expose empty sky.

## A13 2026-10-31 17:49 +09:00 — bases page changed (re-import), nest off screen at t = 10 s (QUEUED)
- bases.png pixels changed (mould nest, art 0.12.0; sizes and rects unchanged). The main-tree cache is stale for bases only (validate.py). Please re-import after 08's quiet window.
- FYI for QA-J1 / 09 X9: in r01 the nest's left edge (x 1012) enters a 640-px view only at cam_x >= 692. Any camera/framing change that shows the nest earlier is yours; 04 is asked about an edge indicator (04 A11).

## A14 2026-10-31 18:59 +09:00 — launcher icon paths for export_presets.cfg (you own the file; 03 did not edit it) (QUEUED)
06 confirmed the APK uses icon.svg because the Android preset has no `launcher_icons/*` keys. Please set, in the Android preset options:
- `launcher_icons/main_192x192="res://assets/branding/launcher_main_192.png"`
- `launcher_icons/adaptive_foreground_432x432="res://assets/branding/launcher_adaptive_foreground_432.png"`
- `launcher_icons/adaptive_background_432x432="res://assets/branding/launcher_adaptive_background_432.png"`
- `launcher_icons/adaptive_monochrome_432x432="res://assets/branding/launcher_adaptive_monochrome_432.png"` (optional, themed icons)
The files are committed with Godot-generated `.import` files (imported in a HEAD snapshot) and are inside the export filter (all_resources; docs/ and tools/ are excluded, which is why they are under assets/). Sizes are exact (192x192, 432x432). Optionally also point `application/config/icon` at the 192 file so the desktop window icon matches. 06 will check the rebuilt APK's icon_foreground/icon_background against these layers. Also still pending: main-tree re-import (A12/A13).

## A15 2026-10-31 19:23 +09:00 — import audit result: please re-import 3 pages; fallback names FYI (QUEUED)
- tools/art/import_audit.py on a clean HEAD snapshot: all 12 pages PASS (lossless, no mipmaps, nearest, 0 pixel/rect mismatch). In the main tree (read-only check) char_player, bases and ui_main are stale; only the frames 03 redrew differ (no other frame moved). Please run `--import` in the main tree. Report: docs/art/evidence/import_audit/.
- FYI: src/core/default_content.gd (yours) still names units "Catapult"/"Shieldbearer"/"Goblin". It is only the fallback when data fails to load, and those names do not appear in the real game today (07's narrow capture: 0 truncations). If the fallback is ever shown, it would use the old theme and the old, longer English names.
- Still open: A14 (launcher icon preset keys).

## A16 2026-10-31 19:34 +09:00 — non-integer scale measured; please keep the integer settings (decision yours) (QUEUED)
Real game on DISPLAY2, isolated user://, options patched in a temp snapshot only (ART_AUDIT round 14, docs/art/evidence/scale_uniformity/):
| option | 1600x900 (2.5x) | 873x393 |
|---|---|---|
| current (canvas_items + expand + integer + App._apply_pixel_scale) | 2x exact, 100 % screen, odd runs 0.0-0.4 % | 1x exact, 100 % |
| scale_mode fractional | 2.5x, 62 % odd runs (pixels 2 or 3 px wide), 100 % | 1.09x, 9.2 % of rows/cols doubled |
| integer + aspect keep (bars) | uniform, 64 % screen | uniform, 67 % |
| integer render then one downscale (simulated) | 7.6 % blended px in the battle band | 26.8 % |
03 recommends keeping the current settings. Please keep App._apply_pixel_scale and scale_mode integer as they are now (they were measured together; 03 did not measure either one alone). The visible world width varies from 640 to ~873 logical px by device, so the camera framing (QA-J1) should be checked at 780x360 and 800x360 (2340/2400x1080 phones at 3x).

## A17 2026-10-31 23:27 +09:00 — main-tree import still stale; zoom (R17) data from art; QA-B012 palette answer (QUEUED)
- **Import:** `python tools/art/import_audit.py .` at 23:27: FAIL only for char_player, bases, ui_main (cache md5 = pre-0.12 PNGs; only the redrawn frames differ). The other 9 pages PASS. Please run the main-tree `--import` under `coordination/heavy_run.ps1` when it is your turn; 03 does not touch the main-tree .godot.
- **R17 world zoom:** 03 built two 32 px unit drafts (not shipped) and measured them in the real game (ART_AUDIT round 15, docs/art/evidence/size_drafts/). 식빵병 / 졸개 bodies: now 21 / 19 px = 3.6 / 3.3 mm; drafts 29-31 / 27-28 px = 5.0-5.4 / 4.7-4.8 mm; with your 4/3 zoom 6.7-7.2 / 6.2-6.5 mm. Without the zoom no draft reaches 04's 6 mm line. Art will follow your decision; a 32 px roster needs the four character pages at 1024x1024 (4.0 MiB, worst battle about 10.75 MiB).
- **QA-B012 (damage numbers on the light village walls, 07):** contrast of white digits on the wall colours is 1.13-1.69:1 (#e3f3ff, #f6e7c1, #c4c7d2) and 3.17:1 on the darker stone #8b90a3. The outline colour K #1b1325 against the same walls is 10.7-15.9:1 (5.7:1 on #8b90a3). Palette answer from 03: keep the digit colours, draw a 1 px K outline on all four sides (today it is a 1 px drop shadow, so the top and left edges of each glyph have no dark edge on a light wall). Your code; your call.

## A18 2026-10-31 23:57 +09:00 — character pages merged (08 A9); re-import needed for char_player (QUEUED)
- assets/atlases/char_player.png is now 1024x512 and holds all regular characters; char_player_adv, char_enemy, char_enemy_adv (png, json, .import) are removed. manifest.anim_sets points the 12 sets at char_player; your Atlas resolves pages from it, and flip_check.gd's `acquire("char_player")` still works. Verified in a clean HEAD snapshot with an isolated import: import_audit 9/9 PASS, exported PCK 9/9, r03 real battle draws every unit (ART_AUDIT round 16).
- The main-tree cache for char_player (and bases, ui_main) is stale; after your `--import` (under heavy_run) the three removed pages' cached .ctex files are orphans in .godot/imported (harmless).

## A19 (commit 33d3ac2) 2026-11-01 00:46 +09:00 — unit size: recommendation and how to ship it (decision is yours, R17) (QUEUED)
**Recommendation: D1 roster + world zoom (k+1)/k together.** Evidence: ART_AUDIT round 17, docs/art/evidence/size_d1full/.
- Regular units under 04's 6 mm working line (393 dp phone, 0.173 mm per view px): now 11 of 12; zoom 4/3 only 9; D1 art only 9; **D1 + 4/3: 0** (6.2-9.5 mm). In 04's r06 frame (seed 4242, t = 46 s) silhouette 83-97 % in every variant, visibility unchanged, colour distance to the other side up with the zoom.
- Cost: worst battle 8.75 -> 10.75 MiB (cap 12; char_player becomes 1024x1024); 04 measured the zoom cutting the time an enemy is visible before it engages from 6.0 to 3.9 s (mean) in r06 — that is a difficulty question for 01 (Q5 is unanswered).
- Zoom value: use (k+1)/k rather than a fixed 4/3, so one art pixel is always k+1 device pixels (4/3 at k = 3, 3/2 at k = 2). A fixed 4/3 at k = 2 gives 2.67 px per art pixel (uneven columns, 04's note and 03 round 14).
**Transition (proposed order):**
1. 02: implement the zoom behind a project setting / feature flag (default off), ground anchored as in 04's CamFix (ground 70 px above the view bottom), and check the camera framing at 780x360 and 800x360.
2. 03: make D1 the default build (remove the ART_DRAFT32 gate), hand-polish the nearest-scaled faces of the 10 re-rendered units, re-check the card/portrait crops (cards are cut from the idle frame), re-pack char_player 1024x1024, run validate --determinism, PCK, import audit in a snapshot and the same r06 capture; one commit with the art and manifest only (frame sizes and pivots change; anim names, frame counts, fps and events do not).
3. 08: asset_budget_check --rev on that commit; 02: main-tree re-import under heavy_run; then switch the zoom flag on in the same release.
4. 07: name-to-unit and lane readability checks on the result; 01: confirm the warning-time change.
- Gameplay data (units.json size/contact) is not touched by the art change; whether hit boxes should grow is 01's call.
- **Not done:** any phone measurement, any human player test.
