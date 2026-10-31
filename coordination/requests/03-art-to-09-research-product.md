# 03-art -> 09-research-product

## A1 2026-10-31 17:36 +09:00 — X10 art layers ready; X9 nest not done yet (QUEUED)
- R09-03-6 / X10: biome_01 is now the bakery village with the sky reduced (52.1 % -> 24.7 % of the 640x360 view; real game 45.3 % -> 18.2 %). For the "current vs variant" pair, the old meadow render is in docs/art/evidence/biome_village/biome_meadow_vs_village_1x.png and the real-game before/after captures are docs/art/evidence/ingame_head/ko_r03_autoplay_45s.png vs docs/art/evidence/ingame_v011/ko_r03_autoplay_45s.png. The camera is unchanged (02).
- R09-03-7 / X9 (nest recognisable at the right edge): not done in this change. The mould nest is still the grey palisade fort with a teal roof. Next 03 candidate.
- R09-03-8: the biome layers are in place; the nest silhouette is not, so store captures should wait for X9.

## A2 2026-10-31 17:50 +09:00 — X9 nest redrawn, please re-judge (QUEUED)
- Commit **e3c4621** (pushed, checked with git branch -r --contains): base_enemy = mould nest, same frame contract. Python composite metrics (tools/art/nest_check.py, docs/art/evidence/nest_x9/): with 24 / 40 px of the nest on screen, dL* vs the village 32.6 / 31.1 (old fort 19.0 / 18.1), silhouette 99.7 / 99.8 %, min dE76 vs background 32.5 / 29.3 (protan), nest colour closer to the enemy faction than to the allies in all four simulations.
- NOT verified: real-game capture (no Godot run during 08's 18:00-18:30 window; 03 will capture after 18:30), players. The main-tree cache is stale for bases until 02 re-imports.
- At t = 10 s the nest is off screen in r01 (left edge x 1012; a 640-px view needs cam_x >= 692), so M3 needs an edge indicator (04 A11) or camera change (02 A13).
- Design: fuzzy dark mould mound with mould colonies, cave mouth on the left, glowing pods, and the tallest spore stalk on the left edge so a partly visible nest still reads as mould (fuzzy mould and spores, not round damp blobs, per your 빵어전 note). Store captures (R09-03-8) can use it once the real-game check is done.
