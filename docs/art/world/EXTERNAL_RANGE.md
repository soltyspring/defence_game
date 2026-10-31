# 09-art-world: external range for the world pass lines (2026-11-01 08:20 KST)

No human player test and no phone check exists for anything below. External numbers come from store marketing screenshots, not from play.

## 1. Sources and method
Official Google Play screenshots, accessed 2026-11-01 08:06 KST (images not committed; image URL, size and every rectangle in image pixels are in `external_range.json`, results in `external_range_out.json`).
| id | game | store page | shot |
|---|---|---|---|
| bc_en_3 | The Battle Cats | https://play.google.com/store/apps/details?id=jp.co.ponos.battlecatsen&hl=ko&gl=KR | #3, 1280×900 (battle with caption overlays) |
| gc_1, gc_5 | Grow Castle | https://play.google.com/store/apps/details?id=com.raongames.growcastle&hl=ko&gl=KR | #1, #5, 1280×720 |
| cw2_1, cw2_4 | Cat War 2 | https://play.google.com/store/apps/details?id=com.westriversw.CatWar2&hl=ko&gl=KR | #1, #4, 480×320 (battle inside a frame) |
| swl_3 | Stick War: Legacy | https://play.google.com/store/apps/details?id=com.maxgames.stickwarlegacy&hl=ko&gl=KR | #3, 1920×1080 (battle at the bottom left; large hero render excluded) |
Ours: 07's fixed capture frames ko_1x r01_t30 and r06_t46 (same game state in both runs, art_compare G2 OK) of the baseline ad47eda (`build/qa07/art-baseline-ad47eda/run1`) and of 92a1718 (`build/qa07/art_compare/92a1718/cap`).

Tool: `python tools/art/world/ext_metrics.py docs/art/world/external_range.json docs/art/world/external_range_out.json`. Every image is resized to 800 px wide first. Layers are hand-placed rectangles; "behind" is the rows where unit bodies are, "lane" the ground under the feet; both use background pixels only (a band colour model removes units). Unit contrast on screenshots is a stand-in for 07 C4: foreground objects found in the unit band, |mean L* of the object with its outline − mean L* of the background around it|. Objects include props and grass tufts, so it is noisy (Grow Castle most). On our frames the stand-in is checked against 07's exact unit masks: baseline 23.0 vs exact 25.2–25.6. On 92a1718 it finds 0–1 objects, because the units are within dE 10 of the street colours; that is the camouflage C4 reports. Base contrast here is a box method (mean Lab of a box around the base vs a ring 24 px wide), not the silhouette ring of P4, so only compare it within this table.

## 2. Table
| indicator | BC | GC 1 | GC 5 | CW2 1 | CW2 4 | SWL | external range | ours before | ours after (92a1718) |
|---|---|---|---|---|---|---|---|---|---|
| sky L* / C* | 89.0 / 19.2 | 93.4 / 5.1 | 93.5 / 5.0 | 83.9 / 24.6 | 52.7 / 42.4 | 44.7 / 53.0 | 44.7–93.5 / 5.0–53.0 | 65.4–65.9 / 37.5–38.0 | 86.0 / 17.2 |
| far L* / C* | – | 53.5 / 44.3 | 79.6 / 24.4 | 60.6 / 18.5 | 50.1 / 34.2 | 43.4 / 57.2 | 43.4–79.6 / 18.5–57.2 | 70.0 / 45.6 | 86.1–86.5 / 18.6–18.7 |
| far % C* ≥ 35 / edge % | – | 65.1 / 20.2 | 34.2 / 6.3 | 7.1 / 12.4 | 68.0 / 7.1 | 99.2 / 1.0 | 7.1–99.2 / 1.0–20.2 | 99.4 / 15.8–15.9 | 4.7–4.9 / 18.7–18.9 |
| behind units L* / C* | 97.9 / 3.3 | 61.4 / 46.0 | 63.2 / 54.9 | 35.1 / 14.0 | 42.4 / 14.0 | 47.4 / 61.8 | 35.1–97.9 / 3.3–61.8 | 75.8–76.8 / 18.5–18.6 | **34.3 / 30.8–30.9** |
| behind % C* ≥ 35 / edge % | 0.0 / 10.1 | 71.7 / 19.0 | 83.7 / 16.5 | 1.4 / 15.5 | 12.1 / 13.6 | 100 / 10.9 | 0–100 / 10.1–19.0 | 10.3–10.9 / 22.8–23.5 | 0.0 / 15.1–17.1 |
| lane L* / C* | 83.1 / 63.2 | 69.3 / 50.4 | 73.4 / 53.2 | 31.2 / 17.4 | 44.9 / 7.9 | 53.5 / 68.2 | 31.2–83.1 / 7.9–68.2 | 46.0–46.3 / 36.2–36.3 | 33.5 / 28.8 |
| unit vs behind dL* median (stand-in) | 50.2 | 9.1 | 14.8 | 26.9 | 15.8 | 27.4 | 9.1–50.2 | 23.0 (07 exact 25.2–25.6) | 07 exact **9.8–14.0** |
| % units dL* < 15 (stand-in) | 37.5 | 72.0 | 57.1 | 33.3 | 46.0 | 8.3 | 8.3–72.0 | 0–7.7 (07 exact 11.1–18.2) | 07 exact **54.5–66.7** |
| base box vs ring dL* / dE | 25.2 / 31.7 | 4.7 / 8.0 | 11.5 / 14.0 | – | 2.9 / 8.4 | – | 2.9–25.2 / 8.0–31.7 | keep 10.2 / 12.5 | keep 4.3 / 7.7 |

## 3. What the range says about each line
- **P1 / P2 (unit interior vs a 1–3 px ring, outline excluded): change to info only.** The cross-role measure is 07 C4/C4m (whole unit with its outline vs the background under it). On 92a1718 P1/P2 passed (19.4–41.2) while 07 C4 got WORSE in both state-equal scenes (median 25.6 → 9.8 and 24.7 → 14.0; units below 15: 11 → 67 %, 18 → 55 %). The two measures disagree because our outlines are dark: on a dark street the light interior scores well and the whole unit does not. The external range does not support an interior rule either: Battle Cats draws white cats on a white sky (behind L* 97.9) and reads by thick black outlines alone. New governing line, replacing P1/P2: **07 C4 ≤ 10 % of units below 15 dL* and C4m not below the baseline (25.2–25.6) in the state-equal scenes, plus 03 readability sil ≥ 60.**
- **Street value (new P8, follows from the line above):** our units have whole-unit L* 35–60 (07 exact masks, 92a1718). For every unit to sit ≥ 15 L* from what is behind it, the band behind the units needs L* ≥ 75 or ≤ 20. L* ≤ 20 already failed 03's outline rule (sil 50–56 %, WORLD_AUDIT §5). So the street front goes back to light (target L* 75–80), keeping the low chroma (C* ≤ 20) and lower edge density of art-world 1. Our 92a1718 value (34.3) is at the bottom edge of the external range (Cat War 2, 35.1), and Cat War 2 gets away with it because its units are bright and detailed (stand-in 26.9); ours are mid-value.
- **P3 far band (C* ≤ 20, C* ≥ 35 ≤ 20 %, L* std ≤ 8): keep, as a 09 style choice only.** It is stricter than 4 of the 5 external shots that have a far layer (far C* ≥ 35 at 7.1–99.2 %, far C* 18.5–57.2; only Cat War 2 #1 is inside both lines). The range shows saturated far layers work in Grow Castle and Stick War; they are not why our units melt (the street is). Loosening it buys nothing, so it stays, but it is not an external norm and it is not a gate for other roles.
- **P3 band behind heads (C* ≥ 35 ≤ 15 %, edges ≤ 15 %): keep the edge line, C* share becomes info.** External edges behind units are 10.1–19.0 % (whole rectangle, units included); our baseline 22.8–23.5 % was above every external shot, 92a1718 (15.1–17.1 %) is inside. The C* share spans 0–100 % externally, so it does not separate good from bad screens.
- **P4 keep / nest ring dE ≥ 25: keep as our target, not an external norm.** With the box method only Battle Cats' base exceeds 25 (31.7); Grow Castle and Cat War 2 bases sit at 8.0–14.0, so their bases are found by size, place and HP bar, not by contrast. Our keep is at 12.5 (before) / 7.7 (after) on the same method. The light street (P8) raises the dark lower course's contrast without a trade, so 25 stays; if it ever conflicts with C4, C4 wins.
- **Lane:** external lane L* 31.2–83.1, C* 7.9–68.2; ours (33.5 / 28.8) is inside. No separate line; the lane is part of C4 because the feet overlap it.
- **P5 (FX) and P7 (sky ≤ 35 %):** not measured on screenshots (no FX timing, captions cover the sky). Unchanged.

## 4. Limits
Six marketing screenshots from four games, one frame each; captions, frames and resizing are in the images. The unit stand-in counts props. No player saw any of this.

## 5. Art-world 2: light street (2026-11-01 09:25 KST, composites + 03 tools, no new GPU capture yet)
tools/art/biome.py: `STREET = STREET_LIGHT` (cream U front, z windows/doors without dark frames, U pavement without the joint line, pale stone x lane). `STREET_SHADOW` (= 92a1718, verified identical by the same A/B) stays in the file. Evidence: docs/art/world/evidence/world2/ (street_ab.json from `tools/art/world/street_ab.py`, two composites, 03 readability output for HEAD 85d22bd and for this change).
| measure | line | 92a1718 shadow street | light street |
|---|---|---|---|
| C4 formula, every walk frame of 12 sets at 3 places: min / median dL* | ≥ 15 for ≥ 90 % | 6.7 / 15.3, 6 enemy sets < 15 | **28.9 / 42.4, none < 15** |
| band behind heads (y 255–285): L* / C* / % C* ≥ 35 / edges | P3: ≤ 15 % / ≤ 15 % | 29.4 / 26.5 / 1.4 % / 13.6 % | 88.8 / 14.5 / 1.4 % / 12.9 % |
| keep ring dE (P4 ≥ 25) / nest ring dE | ≥ 25 | 12.6 / 36.7 | **28.9** / 44.8 |
| 03 nest_check dL* / protan dE (≥ 25 / ≥ 20) | | 17.7–19.0 / 16.8–17.9 | **35.5–41.3 / 33.9–38.9** |
| 03 readability sil_min meadow r01/r05/r10 | ≥ 60 | 74.5 / 70.5 / 65.5 | 70.9 / 60.8 / 70.9 |
| sil_min dark variant / bright variant | ≥ 60 | **57.3 / 48.1 / 49.1** / 100 / 96.8 / 87.5 | 95.1 / 94.0 / 91.6 / 70.9 / **57.2** (boss_warlord, r05) / 70.9 |
| proj_sep meadow / bright (≥ 60) | | 95–100, 72.7–100 / bright arrow **45** | 72.7–80 / 72.7–80 (all PASS) |
| P1 interior ring (now info) ally / enemy min dL* | info | 28.1 / 11.2 | 11.5 / 18.1 |
Also: validate --determinism PASS, contract_diff 0 changes, 08 asset_budget_check PASS (worst battle 8.75 MiB), cvd_check unchanged. A first light version with x/N doors and frames failed proj_sep (30–45: the 03 bread-roll arrow, T L* 70.7, sat on L* 80 details); lightening the details fixed it.
Still open: units in front of the keep's dark lower course (C4 formula 0.6–3.8 at x 30–96; no lower-course colour tried fixes it, they pass there only in the first seconds of a round); bright stress variant boss_warlord 57.2; 07's real capture of this commit not run yet.
