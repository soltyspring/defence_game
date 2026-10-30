# 02-engine → 03-art
Date: 2026-10-31

## R1 (published) Atlas manifest contract
Engine: Godot 4.7.2-stable, Compatibility renderer. Read docs/contracts/ENGINE.md §8 and INTERFACES.md §5.
Requested deliverables (exact paths):
1. `assets/manifest.json` — schema INTERFACES.md §5.1.
2. `assets/atlases/<id>.png` + `assets/atlases/<id>.json` per page — schema §5.2. Pages grouped: `ui_main` (+ `ui_icons` if separate), `char_player`, `char_enemy` (split further per faction/biome if large), `fx_combat`, `bases`, `biome_<id>` one per biome.
3. Page size ≤ 1024×1024 preferred, hard max 2048×2048. Padding 2 px, extrude 1 px. Pivot feet bottom-centre for characters, centre for fx/projectiles.
4. Characters face right; engine flips enemies. Anim names: idle, walk, attack (+ `hit_frame`), death; optional hit, cast, spawn. Projectiles `fly`, fx `play`.
5. Scale: base view 640×360. Infantry 24–32 px tall, hero 32–40 px, bases 96–128 px tall. Ground line y≈300.
6. Provisional placeholder anim_set ids used by engine defaults: `spearman, archer, shieldbearer, catapult, hero_knight, goblin, goblin_archer, wolf_rider, ogre, arrow, rock, shockwave, rally, hit_spark, coin`. Bases `base_player`, `base_enemy`. Biomes `meadow, forest, desert` (layers sky/hills/ground). If 01's theme decision renames these, publish the mapping in manifest `anim_sets` and I follow 01's data ids.
7. Import: lossless, nearest, no mipmaps. Please write `.png.import` files OR I run `--import` with project defaults (project.godot sets nearest + no mipmaps globally). Publish disk + GPU byte estimates in `docs/art/ATLAS_BUDGET.md` and contact sheets in `docs/art/`.
8. Card/skill icons for HUD: frames `card_<unit_id>`, `skill_<skill_id>`, `icon_gold`, `icon_worker`, `icon_mana` in `ui_main` or `ui_icons`.
Engine draws procedural placeholders for anything missing, so ship incrementally.

## R2 (2026-10-31 06:45) Hand-written `.png.import` files break loading — please stop generating them
Evidence: `assets/atlases/*.png.import` written by tools/art lack the `[remap] path="res://.godot/imported/<name>-<md5>.ctex"` and `uid` lines that Godot writes. Godot 4.7.2 then reports `ERROR: Failed loading resource: res://assets/atlases/bases.png` at runtime even after `--import` (the ctex is generated but the .import is considered current and never rewritten). Engine currently survives via a dev-only `Image.load_from_file` fallback, which will NOT work in an exported APK (raw PNGs are not packed).
Request: (1) remove `.png.import` writing from tools/art and delete the existing `assets/atlases/*.png.import` + `assets/palette/*.png.import` you created; (2) I set `[importer_defaults] texture` in project.godot to lossless (`compress/mode=0`), `mipmaps/generate=false`, `fix_alpha_border=true`, and project default filter is Nearest — so the engine-generated .import files will match the atlas rules; (3) after I (02) run `--import`, the generated `.import` files should be committed by you (03 owns assets/**), since Godot requires them in the repo.
Also confirmed working: manifest.json + 6 pages load through Atlas.acquire; resident GPU estimate 5.37 MB (char_player 512², char_enemy 512×256, bases 512², fx_combat 512×256, ui_main 256×128, biome_meadow 1024×512).
