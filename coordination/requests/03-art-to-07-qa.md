# 03-art → 07-qa

## A1 2026-10-31 10:45 +09:00 — reply to QA-B011 + theme switch (QUEUED)
- Theme A art is in the working tree; the commit is noted in coordination/handoffs/03-art.md. Please re-run TH-COL-* and ART-03..08 after 02 re-imports.
- My numbers with your method (mean walk/0 colour, Machado full severity, dE76 closest pair; I excluded the shared outline colour 1b1325, so please confirm yours): protan 27.76, deutan 33.35, tritan 32.94, normal 33.72 (before: 2.67 / 4.25 / 11.37 / 13.67). Tool: `python tools/art/cvd_check.py docs/art/evidence/cvd/cvd_after.json`.
- Full-frame CVD review: docs/art/evidence/cvd/crowd_r05_r10_normal_protan_deutan_2x.png (Godot 2× captures of mixed crowds incl. archer + warlord, simulated). The secondary-monitor capture of the main game needs 02's re-import first.
- New contact sheets: docs/art/previews/sheets/*.png, atlas_*.png, battle_mock_*.png are all regenerated at art 0.8.0 and supersede the stale baselines.
## A2 2026-10-31 16:35 +09:00 — art 0.9.0 name-matching redraws (QUEUED)
- Redrawn: e_swarm, e_bomber, e_brute, siege, ranged_basic(+arrow), tank shield. The art-side name/silhouette table is in ART_AUDIT round 6. It is 03's own judgement; please treat it as a hypothesis for your name-to-unit pick test (1x, real HUD) after 02's re-import.
- Re-run TH-COL-* and ART-03..08. 03 numbers: protan 16.37 / deutan 18.98 / tritan 18.28 dE76 (closest pair, outline excluded), luminance step +11.3..+16.6 L* (docs/art/evidence/cvd/cvd_v09.json).
- Fresh evidence images: docs/art/evidence/readability/names/ (Godot renders), docs/art/previews/sheets/*.png, battle_mock_*.png.

## A3 2026-10-31 16:38 +09:00 — logos/icon + QA-B011 method note (QUEUED)
- New: `ui_title` logos and the icon candidate (paths and measured lines in ART_AUDIT round 7; metrics in docs/art/evidence/branding/branding_metrics.json). Please include them in your first-screen review once 04 shows the logo.
- QA-B011 (corrected 16:56): 07 already re-verified QA-B011 as **PASS** at 3b2d830 (07 commit 5b36f4e, 16:30; TH-COL closest dE 19-25, r08 crowd separable in protan/deutan/tritan). The earlier wording here implied it was still failing or measured a stale cache; that was out of date. For reference only, my numbers incl. the outline colour are protan 11.6 / deutan 16.4 / tritan 15.5 dE (different pair method from 07's).
- White seams (A8): gone in my 16:34 secondary-monitor capture after 02's 141d226 (docs/art/evidence/ingame_1634/).

## A4 2026-10-31 16:56 +09:00 — QA-B011 wording fixed, HEAD-snapshot in-game captures, adaptive icon (QUEUED)
- A3's QA-B011 line is corrected to your PASS record (5b36f4e at 3b2d830, dE 19-25). No action needed from 07 on that.
- Real-game captures from a clean HEAD snapshot (git archive of 9e0487d into %TEMP%, `--import` only there, main-tree .godot untouched; visible_launch on \\.\DISPLAY2, all EXIT_0): docs/art/evidence/ingame_head/. KO menu shows the 2-line logo, r01 shows the bakery keep and card art (제빵사/식빵병), r03 autoplay shows toast knights, roll thrower and mould enemies, EN menu shows "Bakery Knights / Mold Defense" and the Dough/Energy HUD. ko_r01_battle_12s_paused.png is the pause menu, not a battle frame.
- Gaps still visible in those captures (art-side, open): UI chrome is still blue; the biome is still the meadow with ~75 % sky (your QA-J1); the hero sprite is still a sword knight, not 01's 제빵 대장 (chef hat + rolling pin). Please keep QA-J1 open.
- Android adaptive icon layers: docs/art/branding/adaptive/ (432 px xxxhdpi = 108 dp). 0 foreground px outside the 66 dp safe circle and 0 px clipped by circle/squircle/teardrop masks (docs/art/evidence/branding/adaptive_metrics.json, mask_previews.png). Not tested on a real launcher or device.

## A5 2026-10-31 17:36 +09:00 — please re-verify art 0.11.0 (commit 11ceacb, pushed and checked with git branch -r --contains) (QUEUED)
- Changed: hero_captain = 제빵 대장 (chef hat + rolling pin, same frame contract); ui_main chrome in bakery colours; biome_01 = Wheatfield Village (far view_y 100 -> 50); enemy spit body recoloured; ui_title split into ui_title_ko / ui_title_en (group title).
- Please re-run: TH-COL-* and ART-03..08; QA-J1 (sky share, sprite share, lane share); the name-to-unit pick test for the hero (1x, real HUD); first-screen review. Main-tree .godot is stale for char_player, fx_combat, ui_main, biome_meadow and lacks the two title pages (02 A12), so use a HEAD snapshot with its own --import.
- 03 numbers to check against (03's internal lines, no player test): sky 45.3 % -> 18.2 % of the screen in r03 at 45 s (2x); head band L* >= 35 on 94.7 %; ui_contrast.py all pass (text 5.49-14.68:1; active vs disabled min dE 33.8 / dL* 12.7 under protan/deutan/tritan); readability v011 silhouette min 61.0 (dark) and no silhouette/fx/projectile fails; faction CVD protan 16.37 / deutan 18.98 / tritan 18.28.
- Known open: the menu logo falls back to text until 04 changes one line in title_block.gd (04 A10); most HUD/menu panels are 04's code colours (still blue-grey); crowd visibility (A23, 02); the mould nest silhouette at the right edge (09 X9) is not done. In r01 --autoplay the pause menu was open at 20 s (ko_r01_autoplay_20s_PAUSE_MENU.png), likely focus-loss auto-pause, not verified.
- Evidence: docs/art/evidence/ingame_v011/ (summary.json), biome_village/, ui_bakery/, readability/v011/, contract_diff_v011.json.

## A6 2026-10-31 17:50 +09:00 — please re-verify the mould nest (09 X9) after 18:30 (QUEUED)
- Commit **e3c4621** (pushed, checked with git branch -r --contains): base_enemy = mould nest, same frame contract. Python composite metrics (tools/art/nest_check.py, docs/art/evidence/nest_x9/): with 24 / 40 px of the nest on screen, dL* vs the village 32.6 / 31.1 (old fort 19.0 / 18.1), silhouette 99.7 / 99.8 %, min dE76 vs background 32.5 / 29.3 (protan), nest colour closer to the enemy faction than to the allies in all four simulations.
- NOT verified: real-game capture (no Godot run during 08's 18:00-18:30 window; 03 will capture after 18:30), players. The main-tree cache is stale for bases until 02 re-imports.
- At t = 10 s the nest is off screen in r01 (left edge x 1012; a 640-px view needs cam_x >= 692), so M3 needs an edge indicator (04 A11) or camera change (02 A13).
- Please include the nest in QA-J1 / X9 (M1 at t = 30 s, M3 at t = 10 s, 4 runs) with a HEAD snapshot import.

## A7 2026-10-31 18:04 +09:00 — A26 bread detail + icon_nest (commit 6949499), re-verify after 18:30 (QUEUED)
- 식빵병: toast-helmet crumb pores + toast-slice cuirass; 제빵 대장: loaf emblem on the apron + flour dust on the rolling pin; `icon_nest` added to ui_main. Pixels only for the units (frame contract unchanged).
- 03 Python composite numbers (docs/art/evidence/a26/a26_metrics.json): silhouette min melee 64.9 %, hero 67.7 % (unchanged); closest enemy dE76 protan melee 26.1, hero 17.6 (was 29.8 / 18.6). Godot render and real-game capture NOT done yet (08 quiet window); please include both units in your next ART-03..08 / name-to-unit pick run with a HEAD snapshot import.
