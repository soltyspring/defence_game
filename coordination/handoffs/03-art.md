# 03-art handoff
Updated: 2026-10-31 07:08 +09:00

## Status
MILESTONE 1 delivered: the initial usable art pack, packed into 6 texture atlases with a manifest. The theme is the reversible default "Lantern Kingdom vs Bramble Horde" (knights vs goblins), because Q1 is PENDING and this is not user-approved. First playable is an internal milestone only, not release completion.

## Read receipts / processed IDs
BRIEF.md, OWNERSHIP.md, GIT_WORKFLOW.md (publishing only via Publish-Task.ps1), coordinator-to-03-art.md (production/atlas/git/heartbeat/8-worker expansion/R4 quality/completion gate), QUALITY_REVIEW.md (acknowledged: 03 owns font assets + typography audit; visible tests on secondary monitor only), ENGINE.md v1.0, INTERFACES.md v1.0 §5, IMPLEMENTATION_BRIEF.md, DECISIONS.md D1–D10 + Q1 PENDING, 01-director-to-03-art R1, 02-engine-to-03-art R1 + R2.
Ownership note: assets/audio/** now belongs to 05-audio, and 03 does not touch it.
The gongmojeon skill file is outside the workspace and I have not read it yet. It will be applied in the next task (typography audit).

## Commits
- 9b4ee0b `[Design] 초기 도트 아트 팩과 텍스처 아틀라스 6종 추가` — PUSHED origin/main (32 files: assets/manifest.json, assets/atlases/*.png/json, tools/art/**).
- Docs/evidence commit: see below (filled in after publishing).

## What exists (real paths)
- Runtime: `assets/manifest.json`, `assets/atlases/{char_player,char_enemy,bases,fx_combat,ui_main,biome_meadow}.{png,json}` (8-bit indexed PNG, 42 KiB total disk, 5.12 MiB GPU at RGBA8).
- Generator: `python tools/art/build.py`. Validator: `python tools/art/validate.py [--determinism]`. Godot proof: `pwsh tools/art/run_godot_check.ps1` (temp project, secondary monitor).
- Docs: `docs/art/ART_DIRECTION.md`, `docs/art/ATLAS_CONTRACT.md`, `docs/art/ATLAS_BUDGET.md` (generated), palette `docs/art/palette/hearth48.{gpl,hex}`.
- Previews: `docs/art/previews/atlas_<id>.png`, `docs/art/previews/sheets/<anim_set>.png`, `docs/art/previews/battle_mock_{1x,2x}.png`. Evidence: `docs/art/evidence/` (godot_check.json, captures, ctex sizes, palette check).
- Content: hero_captain, worker, melee_basic, ranged_basic, tank, e_grunt, e_swarm, e_spitter; projectiles arrow/rock/spit/tower_bolt; 12 FX; both bases × idle/damaged/ruined; meadow 5-layer parallax; UI icons, cards, skill icons, 9-slices, bars, digits, move buttons.

## Validation evidence (actually run)
- validate.py: PASS. 0 foreign texels in nearest+bilinear ±0.49 px sampling simulation. Palette-only, anims complete, data refs resolved, seamless 640 px tiling, deterministic rebuild. The 6 warnings are expected: Godot-generated .import files do not exist yet.
- Godot 4.7.2 isolated import: 6/6 pages load with correct sizes, 47,352 B .ctex. Synthetic worst case at caps (218 objects): 13 draw calls on desktop GL3.3 (RTX 2070 SUPER). Captures at 1× and 4× with fractional offsets: 0 non-palette pixels.
- Visual review: I inspected every contact sheet and the battle mock, and fixed the hero size, the slash arcs, the swarm clipping, the enemy-fort depth and the sky banding.

## Strongest rejection reasons / untested
- Theme unconfirmed: if Q1 ≠ the current default, character art must be redrawn (the rig/pipeline stays).
- No Android device evidence (draw calls, memory, frame time, thermal). The desktop proxy is not proof.
- The engine has not yet loaded the atlases through Godot-generated .import in the main project (02 R2 pending import).
- Missing roster art: fast, siege, e_brute, e_bomber, boss_warlord, boss_overlord. No font asset yet. No 2nd biome.
- The swarm figure is ~13 px tall vs 01's ~16 px guidance. Allies are blue/gold rather than "warm" (flagged to 01).

## Next tasks (03)
1. After 02's --import: commit the generated .import files and re-run validate.
2. Typography: research OFL Korean+Latin pixel fonts (Hangul completeness, licence, memory), add assets/fonts + licence + docs/art/TYPOGRAPHY.md, render test sheets at 1×/2×/3×. Apply gongmojeon hostile review to the art.
3. Roster r04+: fast, e_brute, boss_warlord (own page), siege, e_bomber, boss_overlord.
4. Re-theme immediately when Q1 is answered.

## Dependencies
02: --import + confirmation in 02-engine-to-03-art. 01: Q1 answer. 04: shimmer/scale feedback on UI art.
