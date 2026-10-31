# 03-art handoff
Updated: 2026-10-31 18:59 +09:00 (real time from Get-Date). Q1 = A DECIDED; Q3 working title 빵집 기사단: 곰팡이 디펜스 (store name pending KIPRIS); Q2 business model DEFERRED (no ad/purchase UI). Art version 0.12.2.

## Session
- Kiro CLI session ID: not visible from inside the session, so I cannot record it. Codex should read it from coordination/.runtime/quota/sessions.json / the launcher.
- Model claude-opus-5.5, trust-all, same window since start (never restarted).

## Processes
- No 03-owned process is running. My Godot runs (isolated %TEMP% projects) all exited normally.
- At the stop, three Godot processes were running `--headless --path . -s res://tests/services/test_services_m3.gd` (PIDs 2352/15644/44588, started 09:18). Those belong to 06-services and were not touched.

## Work tree
Clean for all 03 paths (assets/, tools/art/, docs/art/, own coordination files) at the stop. There is no unverified WIP to checkpoint.

## Commits (all PUSHED origin/main via Publish-Task.ps1; each verified with `git branch -r --contains`)
9b4ee0b initial pack + 6 atlases · e93acdd docs/evidence · 6cf3d01 preview prune · 4088ae0 Godot .import + export-pack check · 5e157e3 Galmuri OFL fonts · abd327d audit round 1 · 9848b06 checkpoint · 22cd2bb white-line repro (02) · c49de70 r04–r07 roster + 3 pages · 69867ce status · de85b3e ui_main stale-import repro + layout locks · 203bf94 SHA fix · 393ada2 boss_overlord + page + colour-vision fix · f5f2ef7 handoff · d6cf7df in-game readability (r01/r05/r10) + fx/projectile/rim-light fixes + name-keyed layout locks · c635fa8 handoff · (this checkpoint commit).

## Deliverables (real paths)
- Runtime: assets/manifest.json; assets/atlases/{char_player, char_enemy, char_player_adv, char_enemy_adv, char_boss_warlord, char_boss_overlord, bases, fx_combat, ui_main, biome_meadow}.{png,json,png.import}; assets/fonts/Galmuri11(-Bold)/Galmuri9 .ttf(+.import), OFL-Galmuri.txt, fonts_provenance.json. Every anim_set referenced by data/** has art.
- Tools: tools/art/build.py · validate.py [--determinism] [--import-cache] · fonts.py · readability.py · ui_sheet_compare.py · font_contact.py · run_godot_{check,pack_check,font_sheet,ui_check,readability}.ps1 · layout_lock/*.json (keyed by frame name).
- Docs: docs/art/ART_DIRECTION.md, ATLAS_CONTRACT.md, ATLAS_BUDGET.md (generated), TYPOGRAPHY.md, ART_AUDIT.md (A1–A24); evidence in docs/art/evidence/**.

## Last real validation (run before the stop, at d6cf7df; nothing re-run after)
- `validate.py --determinism`: PASS. Identical bytes across 2 builds. 8 WARNs = main-tree local .godot cache stale or unimported for changed/new pages (expected until 02 re-imports).
- `run_godot_pack_check.ps1`: 10/10 pages load from an exported PCK, raw PNG absent, fonts load.
- `run_godot_readability.ps1 -Tag after`: 18 Godot renders (1×/2×, secondary monitor screen 1); the Godot output equals the metric composite (max diff ≤ 1). Results: docs/art/evidence/readability/after/metrics_after.json.
- Totals: GPU 9.25 MiB all pages (r01–r03 5.25 MiB), PNG ~71 KiB.

## Unfinished / open (owner)
- Main-tree `--import` for ui_main + 8 changed + 4 new pages (02, A6/A8). Until then 04's UiStyle shows fallback icons. Not fixed in the main tree.
- A8 white lines (02 battle_view.gd per-copy roundf): open until a same-capture recapture shows 0 lines.
- A23 crowd visibility 0–9 % at the front line (02 layout decision). A22/A21 residual: e_brute 58–59 % and arrow 38 % on the dark variant (03, only for future dark biomes).
- A17 existing enemy purple ≈ ally blue under deuteranopia (needs 01 approval to repaint). A19 summon frame field (01/02). A15 brute/warlord height (01). A2 font sizes 12/24/36 (04). A3 integer scale_mode (02). A6/A7 markers + prop_mine wiring (02). A9 ribbons (04).
- No Android device evidence for any art/font. No player tests.

## Milestone 7 (this session): theme A retheme + A17
- Resume check: the 03 paths were identical to origin/checkpoint/quota-20261031-092323/03-art (git diff empty), so no work was lost. The unstaged files under assets/audio/** belong to 05 and were not touched.
- Theme applied as a palette remap (tools/art/theme.py, wired into build.py): allies warm/light bread, enemies cool/dark mould; bases (bakery keep / mouldy fort), flour-store prop, spore spit, baked-loaf rock, wheat front layer, dough-ball icon_supply, chef-hat icon_worker, mould-coloured enemy portraits. Palette +4 mould colours (appended).
- Verified: validate.py --determinism PASS (10 WARNs = main-tree cache stale for all pages; 02 asked A9). Exported PCK 10/10. Geometry unchanged except the icon_supply rect (alias split). CVD: 07-proxy protan 2.67->27.76, deutan 4.25->33.35; mass test <= 4.5 % confusable, luminance step +12.7..+18 L* (docs/art/evidence/cvd/). Readability rerun (theme): no regression.
- Build fix: build.py retries image writes on Errno 22 (the Z: share failed twice mid-build).
- Commit 2b350c4 [Design] theme A retheme + A17: PUSHED origin/main (verified with git branch -r --contains).
- Notified 01 (A4, naming proposals), 02 (A9 re-import all pages), 04 (A6), 07 (A1 new file), 08 (A4).
- Open: A26 bread detail pass (palette-only retheme so far); main-tree recapture after the 02 re-import; A21/A22 dark residuals; A23 (02).

## Milestone 8 (this session): name-matching redraws (art 0.9.0)
- tools/art/chars_retheme.py, wired via build.py apply_name_redraws(): e_swarm = fruit flies, e_bomber = yeast puff, e_brute = rot boar, siege = oven cannon, ranged_basic = roll thrower (+ arrow = thrown roll), tank = loaf-slice shield. Priorities and rationale: ART_AUDIT round 6 (03 judgement, no player test).
- Contract vs HEAD: 0 changes to sizes/names/w-h/pivots/frame lists/fps/hit/events/points; 15 rects moved inside the redrawn sets (de-dup); GPU unchanged.
- Validation on the final build: validate.py --determinism PASS (10 WARNs = main-tree cache stale; 02 A10); exported PCK 10/10; Godot readability renders (secondary monitor, Godot output equals the composite) metrics in docs/art/evidence/readability/names/; CVD protan/deutan/tritan 16.4/19.0/18.3 dE, luminance step >= 11.3 L*.
- Fixed during review: yeast puff too light (protan dL* 9.9) -> darkened, then rim lightened (dark silhouette passes); fly ground dots failed the dark silhouette -> removed; boar shortened 38 -> 32 px; roll projectile lightened (meadow 45 -> 95 %).
- Still open: A27 crowd occlusion by the boar (e_spitter 1.7 % in the test scene) -> 02 A23; A28 fast/melee bread cues; e_brute dark 59.1 %; main-tree re-import + in-game recapture (02 then 04/07).
- build.py now also retries text/json writes on Errno 22 (the Z: share).
- Commit 7705aec [Design] name-matching redraws: PUSHED origin/main (verified with git branch -r --contains). One Publish attempt before it failed `git diff --check` (blank line at EOF in 3 files); I unstaged only my own 68 files, fixed them and re-published. No foreign files were touched.

## Milestone 9 (this session): working-title logos, icon candidate, A28, in-game check
- tools/art/branding.py: `ui_title` page (logos KO/EN, one-line + 2-line) from Galmuri11-Bold binary glyphs, x2, hand-painted. App icon candidate in docs/art/branding/ (48 native, 96/192 exact x2/x4).
- A28: toast-slice helmet (melee_basic), pretzel on the pony flank (fast).
- Checks: Godot title renders 1/2/3x pixel-exact, all fit 352 px (run_godot_title.ps1, branding_check.py). Icon lines PASS after one fix (first draft dL* 14.4/20.4). validate --determinism PASS; PCK 11/11; CVD >= 16.4 dE; readability unchanged; 08 budget check PASS (menu 0.50 MiB at cap).
- In-game (16:34, secondary monitor): white seams gone (02 141d226). Theme/icons NOT visible in the real game because the main-tree import is stale -> UNVERIFIED until 02 re-imports.
- Requests: 02 A11, 04 A8, 06 A1 (new file), 07 A3, 08 A6.
- Commit 19245a5 [Design]: PUSHED origin/main (verified with git branch -r --contains).

## Milestone 10 (this session): HEAD-snapshot in-game check, adaptive icon, menu-budget proposal
- Real game from a clean snapshot: `git archive HEAD` (9e0487d) to %TEMP%\art03_head, config/name changed there, `--import` only there (snapshot `--import-cache`: all pages match). Main-tree .godot NOT touched. visible_launch on \\.\DISPLAY2, KO menu / r01 / r03 autoplay and EN menu / HUD, all EXIT_0. Evidence: docs/art/evidence/ingame_head/.
- Verified in-engine: theme art, KO/EN logos, card art. Still wrong: blue UI chrome, meadow biome with ~75 % sky (QA-J1), hero is a sword knight instead of 01's 제빵 대장 (chef hat + rolling pin).
- Adaptive icon: tools/art/adaptive_icon.py -> docs/art/branding/adaptive/ (432 px = 108 dp). 0 px outside the 66 dp safe circle, 0 px clipped by circle/squircle/teardrop. Real launcher/device UNTESTED.
- Menu budget: dry run only (docs/art/evidence/menu_budget_dryrun.json). Proposal B (per-locale ui_title pages) / C (ui_main 256x128 by moving 5 battle-only frames) / A (x1-master logos, not recommended) / D (raise cap) sent to 08 A7 and 04 A9. No contract change made.
- Corrections: 07 request A3 now records 07's QA-B011 PASS (5b36f4e at 3b2d830, dE 19-25); TYPOGRAPHY section 4 font cache = LA8 128 KiB per 256x256 (08).
- Requests: 04 A9, 06 A2, 07 A4 (+A3 fix), 08 A7.
- Validation on this build: validate.py --determinism PASS (byte-identical across 2 builds; 11 WARNs = main-tree cache stale/unimported for every page, 02). Exported PCK 11/11 pages + 3 fonts load, raw PNG absent, PCK 1,255,352 B. 08 asset_budget_check --worktree PASS (menu 0.50, all pages 9.50 MiB). assets/ unchanged by the rebuild.
- Commit b692107 [Design]: PUSHED origin/main (verified with git branch -r --contains, 16:59).
- Processes: none of mine running at 16:55. Godot PIDs 57532/58828 (05 audio sandbox) and 12768/58768 (multi_seed_sim) are other roles' and were not touched.

## Milestone 11 (this session): 제빵 대장, bakery chrome, Wheatfield Village, per-locale title pages
- Hero: tools/art/chars_retheme.py `hero_baker_body()` + `rolling_pin` (chef hat, moustache, white jacket, apron, cape, rolling pin); chars_player.hero_anims(b) takes the body. theme.OVERRIDE["hero_captain"]. contract_diff.py vs HEAD: 0 frame/anim changes; only the 4 logo rects moved (page split).
- UI: tools/art/ui.py crust/flour/butter chrome, flour-sack icon_supply, toast icon_army, new skill icons. tools/art/ui_contrast.py: all lines pass after one fix (disabled 3.06:1 -> 5.76:1, selected 3.45:1 -> 8.54:1). Most in-game panels are 04's code colours: proposal in 04 A10.
- Biome: tools/art/biome.py `VILLAGE` (BIOME_01) + WrapCanvas; far view_y 50. tools/art/biome_check.py: sky 52.1 -> 24.7 %, head band L*>=35 94.7 %, lane 94.1 %. Real game sky 45.3 -> 18.2 %. Spit recoloured (px_sep 42 -> 76 %). Readability v011: silhouette/fx/projectile all pass incl. e_brute dark 62.5; crowd fails = A23 (02).
- Title pages: ui_title -> ui_title_ko 512x64 + ui_title_en 256x128, group `title` (app.gd preloads group `ui`; measured 0.50 with `ui`, 0.375 with `title` + simulated client line). Old ui_title files and lock deleted. .import for the new pages generated by Godot in %TEMP%\art03_v011 and copied in.
- Snapshot captures (HEAD e282045 + 03 assets, import only in %TEMP%, \\.\DISPLAY2, EXIT_0): docs/art/evidence/ingame_v011/ (summary.json). r01 at 20 s was the pause menu (marked).
- Validation: validate.py --determinism PASS (6 WARN = main-tree cache stale for the 4 changed + 2 new pages); exported PCK 12/12 pages + 3 fonts, raw PNG absent, 1,261,900 B; 08 asset_budget_check --worktree PASS (its model reports menu 0.25 because it counts group ui only; real 0.375, see 08 A8); CVD factions unchanged 16.37/18.98/18.28.
- Requests: 01 A5, 02 A12, 04 A10 (title_block line + chrome colours), 06 A3, 08 A8, 09 A1 (new file); 07 A5 (re-verify, written after the push).
- Commit 11ceacb [Design]: PUSHED origin/main (verified with git branch -r --contains at 17:36).
- Processes: snapshot Godot runs all exited. Other roles' Godot processes were not touched.

## Milestone 12 (this session): mould nest (09 X9)
- tools/art/bases.py mould_nest() (build.py uses it for base_enemy). contract_diff vs HEAD: 0 changes. tools/art/nest_check.py (Python composite, 1x/2x, left 24/40/96 px visible): nest dL* 30.4-32.6, silhouette 99.6-99.8 %, min dE76 vs bg 29.3, closer to the enemy mean in all sims; old fort dL* 18.1-21.6 (failed). Evidence docs/art/evidence/nest_x9/.
- t = 10 s visibility is camera/indicator (04 A11, 02 A13). Real-game capture NOT done (08 quiet window 18:00-18:30; no Godot run after 17:42).
- Validation: validate.py --determinism PASS (1 WARN: main-tree bases cache stale); exported PCK at 17:42 on this build 12/12 pages, 15 loads, raw PNG absent, 1,262,684 B; 08 asset_budget_check --worktree PASS.
- A26 not started.
- Commit e3c4621 [Design]: PUSHED origin/main (verified with git branch -r --contains at 17:50). Then 07 A6 and 09 A2 re-verify requests.

## Milestone 13 (this session): A26 bread detail (식빵병, 제빵 대장) + icon_nest
- chars_player.py SPEAR_HEAD/SPEAR_TORSO (toast helmet pores, toast-slice cuirass); chars_retheme.py BAKER_TORSO loaf emblem + rolling-pin flour dust; ui.py ICONS16["icon_nest"]. Contract: only `icon_nest` added (ui_main stays 256x256).
- Python composite (no Godot, 08 quiet window): silhouette min melee 64.9 -> 64.9 %, hero 67.7 -> 67.7 %; closest enemy dE76 protan melee 29.8 -> 26.1, hero 18.6 -> 17.6. docs/art/evidence/a26/.
- validate.py --determinism PASS (3 WARN: main-tree cache stale for char_player, bases, ui_main); 08 asset_budget_check --worktree PASS (menu 0.50 in 08's conservative model, battle 9.25).
- NOT verified for this change: Godot readability render, exported-PCK check, real-game capture (after 18:30).
- Commit 6949499 [Design]: PUSHED origin/main (verified with git branch -r --contains at 18:04). 07 A7 re-verify request written after the push.

## Milestone 14 (this session): Godot checks after the 18:30 quiet window
- HEAD 31164c8 snapshot (%TEMP%\art03_v0121, import only there). Readability v0121: Godot = composite, only crowd fails (A23, 02). PCK 12/12 + 3 fonts, no raw PNG, 1,263,084 B.
- Real game (DISPLAY2, EXIT_0, no black or paused frames): logo, bakery buttons, 제빵 대장, 식빵병, village visible. Nest captured with tools/art/godot_check/nest_cam.gd (camera pan like a drag): dL* 28.5-39.0, min dE76 28.5-43.8, all pass. Evidence docs/art/evidence/ingame_v0121/.
- No failure to fix.
- Commit b5ce778 [Test]: PUSHED origin/main (verified with git branch -r --contains at 18:45). 07 A8 re-verify request after the push.

## Milestone 15 (this session): launcher icon set, store graphics, hero apron
- tools/art/launcher_icons.py (new) + branding.icon48_fg/icon48_bg refactor. Runtime assets/branding/*.png (+ Godot .import from snapshot %TEMP%\art03_v0122). Store docs/art/branding/store/. Previews docs/art/branding/launcher_previews/. Metrics docs/art/evidence/branding/launcher_metrics.json.
- 06's check_store_graphics.py: store icon all PASS; adaptive safe circle PASS (after shrinking the blob 1 px), logo 46.5 x 51 dp PASS, monochrome PRESENT; feature graphic not seen by their script (it reads docs/services/store_assets/).
- A26 apron emblem 6x3. Real-game capture DISPLAY2 EXIT_0 (docs/art/evidence/ingame_v0122/). PCK 12/12.
- Requests: 02 A14 (preset keys), 06 A4.

## Exact next steps on resume
1. After 02 sets the preset keys and 06 rebuilds: check the APK icon layers with 06.
2. A26 for tank / fast / siege.
3. Read incoming *-to-03-art.md.
