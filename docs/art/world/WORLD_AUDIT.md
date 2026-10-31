# WORLD_AUDIT.md — background, bases and FX (owner: 09-art-world)
Started 2026-11-01 01:40 KST after the user's request ("그래픽이 너무 별로야"). Scope: biome_meadow (biome_01), bases, fx_combat.
Characters, palette, UI and build.py belong to 03 and are not changed here. No player test and no phone check exists for anything below.

## 1. Inputs read
- docs/art/ART_DIRECTION.md §3, §5, §7, §10; docs/art/ATLAS_CONTRACT.md; docs/art/ART_AUDIT.md rounds 9–17.
- docs/verification/FIRST_3MIN_REVIEW.md J1 ("I can't see the fight or tell who is who": thin lane band, 75 % sky/hills, enemy off screen) and HOSTILE_REVIEW.md R8 (thin battlefield strip) / R9 (seams).
- docs/research/product/SUCCESS_ANALYSIS.md §10 (09's own store-screenshot notes): compared games carry decisions by colour + number contrast; late-game FX in Random Dice covers the board.
- Engine draw code (read only): src/gameplay/battle_view.gd `_draw_biome_layers`, `_draw_base`, `_draw_fx`; battle.gd `_update_camera`; battle_sim.gd `_fx` calls (hit_spark at y −12 on every melee/projectile hit, explosion at y −6 on splash). ground_y = 290 (data/game_config.json).

## 2. Method (measured, not judged by eye)
Tool: `tools/art/world/world_metrics.py` (new). Colours in CIE L*a*b* and dE76 with 03's `cvd_check.lab`.
- **Committed captures, camera matched:** docs/art/evidence/merge_0130/ko_r03_autoplay_30s.png and _45s.png (r03, 2×) and docs/qa/zoom_preview/zoom_preview_current.png (r06, 800×360 view, 2×). The background is rebuilt from the atlas with battle_view.gd's exact layer placement; the camera is found by matching the cobble rows and then the far/mid layers. Rebuilt background equals the capture on 98.9 / 99.1 / 94.3 % of rows 70–283 (the r06 frame has a wave banner over the hills). Pixels that differ from the rebuilt background are split into bread side / mould side by palette key (an orange bomber fuse counts as bread side: known error).
- **Atlas composites:** each FX frame placed exactly as `_draw_fx` does over each unit's attack frame; bases placed at ground_y over the rebuilt background.
- Ring contrast = mean L* (and mean Lab) of a unit's own pixels (outline excluded) against the mean of the true background 1–3 px outside the unit.

## 3. The three largest causes (baseline numbers)
Files: docs/art/world/evidence/baseline/ (committed_captures.json, atlas_fx_bases.json, mask_r03_45s.png, mask_r06_46s.png).

**C1. The bread soldiers have the same lightness as the street behind them.**
| capture | bread side: unit L* / ring L* / ring dL* / ring dE | mould side: unit L* / ring L* / ring dL* / ring dE |
|---|---|---|
| r03 30 s | 71.9 / 62.5 / **9.4** / 16.6 | 48.9 / 62.0 / 13.1 / 24.5 |
| r03 45 s | 72.1 / 63.1 / **9.0** / 16.0 | 49.3 / 63.6 / 14.3 / 28.6 |
| r06 46 s | 67.8 / 62.9 / **4.9** / 19.6 | 48.5 / 63.7 / 15.2 / 25.6 |
The band behind the heads (y 255–285) has mean L* 72.3: cream walls, pale stone plinth and lit shop windows. Bread units are crust/cream/egg-wash (mean L* 66.7 over all ally walk frames, heads 70–97), so their mass differs from the wall by only 5–9 L*. Only the 1 px outline separates them. The mould side is darker (mean L* 47.7) and reads 13–15 L* away.

**C2. The far wheat hills are the most saturated area on screen, so depth is inverted.**
| band (background only, r03 45 s) | L* mean | L* std | C*ab mean | pixels with C* ≥ 35 | edge density |
|---|---|---|---|---|---|
| far hills y 70–175 (29 % of the view height) | 71.3 | 10.6 | **41.3** | **82.6 %** | 18.4 % |
| street upper y 180–250 | 71.6 | 21.6 | 27.2 | 38.4 % | 17.4 % |
| behind heads y 255–285 | 72.3 | 17.7 | 22.6 | 29.7 % | 22.4 % |
| lane y 284–297 | 49.1 | 7.4 | 38.2 | 86.6 % | 19.9 % |
The farthest layer is more saturated (C* 41) than the bread soldiers (mean C* 33) and the mould soldiers (C* 13). There is no atmospheric step: far, middle and head band all sit at L* 71–72. The lane is a saturated brown (C* 38) in the same hue as the soldiers' crust. Edge density behind the heads (22 %) is about half of the units' own (39–51 %), so detail density is not the main cause; value and saturation are.

**C3. The player keep disappears into the street, and the damaged state barely changes.**
| base | idle mass vs background ring: dL* / dE | damaged: pixels changed vs idle | damaged silhouette area / idle | damage cue dE to body |
|---|---|---|---|---|
| base_player (bakery keep) | **2.5 / 7.0** | **4.4 %** | 0.99 | 26.4 |
| base_enemy (mould nest) | 33.4 / 47.0 | **3.5 %** | 1.00 | **14.5** |
The keep is tan/cream brick (theme.BAKERY_KEEP maps its stone to T/U), the same colours as the village houses. The engine shows `damaged` at ≤ 50 % HP and `ruined` only at 0 HP (battle_view.gd `_draw_base`), so during play a player sees two states that differ in 3.5–4.4 % of the pixels with an unchanged outline. The nest's damage fire is drawn in E/e/R/Z, which theme.ENEMY remaps to greys, so its cue is only 14.5 dE from the mould body.

**Measured but not a top cause: FX cover.** hit_spark covers 6.9–20.3 % of a target at its peak frame (mean 3.3–9.8 %); explosion 16.5–36.1 % (mean 6.5–13.9 %). On the worker 13.8 % of the spark pixels are within dE 20 of the cream body under them. readability.py (03) passes FX at ≤ 35 %; only the explosion on e_swarm and ranged_basic touches that line.

## 4. Pass lines, fixed before the redraw (09 internal, not validated with players)
Measured on before/after captures of the same seed and time (world_cam.gd, exact masks from the atlas) and on atlas composites.
| # | line | baseline |
|---|---|---|
| P1 | bread side ring dL* ≥ 20 **and** ring dE ≥ 30 in every r01/r06/r10 capture | 4.9–9.4 / 16.0–19.6 |
| P2 | mould side ring dL* ≥ 13 and ring dE ≥ 24 (no regression) | 13.1–15.2 / 24.5–28.6 |
| P3 | far band (y 60–175): C* mean ≤ 20, pixels with C* ≥ 35 ≤ 20 %, L* std ≤ 8; band behind heads: pixels with C* ≥ 35 ≤ 15 %, edge density ≤ 15 % | 41.3 / 82.6 % / 10.6; 29.7 % / 22.4 % |
| P4 | keep idle ring dE ≥ 25; nest idle ring dE ≥ 25; damaged: ≥ 15 % of pixels changed, silhouette area ≤ 0.92 of idle, cue dE to body ≥ 25 (both bases); ruined area ≤ 0.5 | 7.0; 47.0; 4.4/3.5 %, 0.99/1.00, 26.4/14.5; 0.41/0.36 |
| P5 | hit_spark peak cover ≤ 10 % and spark-on-unit same-colour share ≤ 5 % for every target; explosion peak cover ≤ 20 %; FX cover of units in the real captures not above the before value | 6.9–20.3 %, ≤ 13.8 %; 16.5–36.1 % |
| P6 | no regression in 03's tools: readability.py sil_min ≥ 60 in every scene and variant, fx ≤ 35, proj_sep ≥ 60; cvd_check PASS; validate.py --determinism PASS; 08 asset_budget_check PASS; contract_diff 0 changes to frame names, sizes, pivots, anim names, frame counts, fps | sil_min 85.5/75.5/85.5 (village), ≥ 61.0 (dark) |
| P7 | sky share ≤ 35 % (biome_check.py, kept) | 24.7 % |
The old biome_check line "head/lane band L* ≥ 35 on ≥ 90 %" (03, dark-biome rule) is replaced by P1/P2, which measure both sides directly. It is still printed for comparison.

## 5. What was redrawn (art-world 1, 2026-11-01)
Same frames, sizes, pivots, anim names, frame counts, fps and page sizes (`contract_diff.py --rev HEAD`: contract_changed false, 0 moved rects). Sources: tools/art/biome.py `VILLAGE2` (shipped as `BIOME_01`), tools/art/bases.py `keep_v2` / `nest_v2` (bound to `player_keep` / `mould_nest`, which build.py calls), tools/art/fx.py `hit_spark_v2` / `explosion_v2` (in `fx.SETS`). The previous versions stay in the same files for comparison (`VILLAGE`, `player_keep_v1`, `mould_nest_v1`, `hit_spark_v1`, `explosion_v1`).
- **Far (far layer, y 50–200):** pale haze. Pale-blue hills with a grey ridge, a grey nearer range, a flat cream wheat plain with sparse sunlit/sage marks, the distant village and windmills in pale greys. No saturated tan field any more.
- **Middle (mid layer, y 180–300):** a cool blue-grey back row of roofs (depth step), then the bakery street: lit plaster upper storeys with dark windows and a warm glint, jam-red / crust roofs, awnings. **From y 244 down (behind every unit) the street level is in warm shadow**: crust-brown fronts (L* ~33), dim shop windows and doors one step lighter, one small lantern per front.
- **Near and lane (ground layer, y 275–355):** dark pavement, a kerb line, a packed-earth lane in the same brown, dark soil under the HUD. Feet line row 15 unchanged. Front wheat layer unchanged.
- **Value search behind the units:** the wall/lane colours were chosen by measuring every palette pair against all regular unit walk frames for three things at once: bread-side ring contrast, mould-side ring contrast, and 03's outline rule (readability.py silhouette ≥ 60 %). Darker walls (L* 17–22) gave the best ring contrast but failed the outline rule (50–56 %); L* ~33 crust passed it (73–90 %). The search script output is summarised here; the chosen value costs the mould side some ring dL* (see P2).
- **Bakery keep:** cream-grouted tan bricks (L* ~72) above the unit band, a **dark crust lower course** behind the units (the bottom 40 px, where units spawn and walk) with a cream string course on top, a cream stone arch around a lit plank gate, a cream gate tower, a red cone roof with a flag, a scored-loaf sign and oven-lit windows. Damaged: the tower top and roof are gone (jagged), crenels knocked out, holes, cracks, three fires with smoke. Ruined: a low wall stub with rubble and two fires. The lower course was chosen after the 03:10 capture showed the hero in front of the all-tan keep at ring dL* 0.6 (tools/art/world/keep_plinth_ab.py: units in front of the keep min dL* 2.4 all-tan → 20.6 dark crust; grey stone gave 12.3).
- **Mould nest:** dark mould mass (D) with grey-green and sage sheen on the upper left, a few spore-white highlights, fuzzy light rim, light colony rings, cave mouth facing left, the tallest spore stalk on the left edge (as in art 0.12). A lighter sage mass was tried first and lost contrast against the lit plaster above it (nest_check dL* 4.3–8.5). Damaged: a black split through the mound, burst pods, dried grey crust, broken stalks, escaping spore puffs. Ruined: a flattened mound with stumps.
- **hit_spark:** hollow burst, no filled centre and no rays straight up/down (they lay on the body), orange inner end and pale-gold tip. **explosion:** one dashed 1 px ring with short rays outside, a 3 px flash only in frame 0, rim-only smoke.

## 6. Results against the pass lines (2026-11-01 07:20 KST)
Build: `python tools/art/build.py` on a clean `git archive` of HEAD 3f70d8f plus my four source files (the shared tree holds other roles' uncommitted tools/art sources, so building there would not be "HEAD"). Only my three pages, their atlas previews, 03's battle_mock/sheets previews and my rows of the shared manifest/budget changed; no char_* or ui_* file changed.
Real captures: `tools/art/world/world_cam.gd` (same seed, same sim time; units, frame indices and camera identical before/after, `same_state` in the pair JSON), 640×360 on DISPLAY2, isolated APPDATA, inside heavy_run (03:10 KST). **The "after" captures are the art-world 1 draft of 02:58: the keep's dark lower course and gate arch (§5) were added after them.** Everything else in the captures equals the committed pages. Units under engine hit-flash or dying tint are excluded (`pair_rounds_tint_excluded.json`). Composite = world_preview.py from the source modules (no HUD).

| # | line | before | after | verdict |
|---|---|---|---|---|
| P1 | bread side ring dL* ≥ 20 and dE ≥ 30, every capture | dL* 5.9–13.6, dE 9.6–16.6 | r01 30/60 s 40.6/41.2, 39.4/40.3; r06 75 s 36.8/37.7; r10 60 s 41.2/41.8; **r06 46 s 19.4/20.7; r10 110 s 24.2/25.0** | **4/6 PASS.** r06 46 s: two 식빵병 whose visible pixels are mostly their dark crust side (unit L* 42) read 12.8–13.8 dL*. r10 110 s: the hero in front of the draft keep (0.6); with the final keep the composite gives units in front of it ≥ 20.6 dL* / 22.6 dE |
| P2 | mould side ring dL* ≥ 13 and dE ≥ 24 | 5.7–13.9 / 22.4–32.1 | 19.4–23.7 / 37.0–42.7 | PASS in the captures. **Exception: e_brute** (L* 28.7) on the shadowed street: composite 11.2 dL*, r06 75 s 2.0 dL* when not flashing. Request to 03 (rim light) |
| P3 | far: C* ≤ 20, C* ≥ 35 ≤ 20 %, L* std ≤ 8; behind heads: C* ≥ 35 ≤ 15 %, edges ≤ 15 % | far 41.3 / 82.6 % / 10.6; heads 29.7 % / 22.4 % | composite far 16.7 / 2.8 % / 7.7; heads 1.4 % / 13.6 % (captures: far C* 16.3–16.6, 4.0–4.8 %; their L* std 20–24 includes HUD text) | PASS |
| P4 | keep idle ring dE ≥ 25; nest ≥ 25; damaged ≥ 15 % changed, area ≤ 0.92, cue dE ≥ 25; ruined area ≤ 0.5 | keep 7.0, nest 47.0; damaged 4.4/3.5 %, 0.99/1.00, 26.4/14.5; ruined 0.41/0.36 | keep **12.6** (upper part alone 23.6), nest 36.2; damaged keep 16.8 %, 0.91, 37.4; nest 27.2 %, 0.86, 27.1; ruined 0.47 / 0.44 | **Keep ring line FAIL** (12.6 < 25; it was 26.0 before the dark lower course: I traded it for units in front of the keep, P1). All other P4 lines PASS |
| P5 | hit_spark peak ≤ 10 %, same-colour ≤ 5 %; explosion peak ≤ 20 %; capture FX cover not above before | 20.3 %, 13.8 %; 36.1 % | 6.8 %, 2.1 %; 12.8 %; captures 1.3 → 0.4 %, 1.2 → 0.4 % | PASS |
| P6 | 03 readability sil ≥ 60, fx ≤ 35, proj_sep ≥ 60; cvd PASS; determinism; budget; contract | sil_min 85.5/75.5/85.5 | real biome sil_min 74.5 / 70.5 / 65.5, fx 1.8–5.9 %, proj_sep 72.7–100; **dark variant sil_min 48.1–57.3, spit 58.0–59.2; bright variant arrow 45.0**; cvd unchanged (protan 16.37 / deutan 18.98 / tritan 18.28); validate --determinism PASS; 08 asset_budget_check PASS (worst battle 8.75 MiB, unchanged); contract_diff 0 changes | **PASS on the shipped biome, FAIL on 03's dark/bright stress variants** (cause in 09-art-world-to-03-art.md W1 §4) |
| P7 | sky ≤ 35 % | 24.7 % | 26.1 % | PASS |

**03's nest_check.py lines** (dL* ≥ 25, protan dE ≥ 20 against the background at the screen edge) now fail: new nest 17.7–19.0 dL*, protan dE 16.8–17.9 (silhouette 94–95 %, reads as mould: PASS). The 0.12.0 nest on the new background gives 16.4–19.7, so the drop comes from the new background (dark street under, light plaster above the nest), not from the nest drawing. It passed (30.4–32.6) on the old cream street.
**07's judgement:** `tools/qa/art_compare.ps1 -Sha <this commit>` against the ad47eda baseline (docs/verification/ART_BASELINE.md). Result is recorded in coordination/handoffs/09-art-world.md when it is in.

## 7. Not done / limits
- No human player test and no real-phone check. All numbers are desktop renders and composites; the lines are 09's internal lines, fixed before the redraw, not validated with players.
- One seed, one bot policy for the real captures. The keep's final lower course is only in composites until 07's art_compare run.
- The second biome and night/dark variants are not drawn.
