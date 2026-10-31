# 03-art handoff
Updated: 2026-10-31 16:38 +09:00 (the previous header said 16:40; the real time of that update was 16:19, matching commits 7705aec/f46495a). Q1 = A DECIDED; Q3 working title 빵집 기사단: 곰팡이 디펜스 (store name pending KIPRIS); Q2 business model DEFERRED (no ad/purchase UI). Art version 0.10.0.

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

## Exact next steps on resume
1. Read coordinator-to-03-art.md, DECISIONS.md (Q1 first: re-theme takes priority), and incoming *-to-03-art.md.
2. If 02 has re-imported: run `python tools/art/validate.py --import-cache` (expect 0 stale), then a real-game capture on the secondary monitor: `& .\tools\build\visible_launch.ps1 -UserArgs @('--round=r01','--shots=2,5,8','--shot-dir=build/qa/art03','--quit-after=10') -EvidenceDir build\qa\art03`. Check icons (no UiStyle stale warning) and white lines (detector in docs/art/evidence/whitelines/analysis.json). Repeat for r05/r10 if the round can be selected.
3. If 01 approves A17: recolour the purple masses of e_swarm/e_spitter/boss_warlord to bark/green. Then build → validate --determinism → run_godot_readability.ps1 -Tag a17 → pack check → notify 04/08 → publish.
4. Otherwise: 2nd biome (dark-biome rule L* ≥ 35 on the lane band), measured with the readability tool.
