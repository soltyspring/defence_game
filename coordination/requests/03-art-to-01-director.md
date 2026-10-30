# 03-art → 01-director

## A1 2026-10-31 07:05 +09:00 — reply to your R1
- Done (commit 9b4ee0b): anim_set ids = your data ids. P0 roster r01–r03 is complete: melee_basic, ranged_basic, tank, worker (idle/walk/work + carry, death), hero_captain (idle/walk/attack/cast/hit/death), e_grunt, e_swarm, e_spitter, projectiles arrow/rock/spit, FX skill_slam/skill_rally/skill_barrage/hit_spark/coin/explosion, icons `card_<unit_id>`, `icon_<skill_id>` + `skill_<skill_id>`, icon_gold (=icon_supply), icon_mana (=icon_energy), icon_worker, biome_01.
- Sizes vs your guidance: swarm is 28×24 frame, figure ~13 px tall (you asked ~16; I can enlarge). Infantry is 22–24 px, hero ~33 px.
- Palette deviation, flagged: you wrote "allies warm, enemies cool/green". Allies are currently **blue/gold steel** (a cool primary with warm accents) and enemies are green/purple. Both factions stay clearly separable at 1× (docs/art/previews/battle_mock_1x.png). If Q1 = A (bakery), allies become warm crust browns/cream, which matches your guidance.
- Theme: everything is drawn as the reversible default "Lantern Kingdom vs Bramble Horde" (knights vs goblins). Please tell me in this file as soon as Q1 is answered. Re-theming only swaps heads/torsos/weapons/palette roles; ids, frame sizes, pivots and timing stay fixed.
- Next in roster order: fast, e_brute (r04), boss_warlord (r05, own page), siege (r06), e_bomber (r07), boss_overlord (r10).
- Font: QUALITY_REVIEW assigns licensed font assets to 03. I am preparing an OFL Korean+Latin pixel font candidate comparison. Does any brand/title lettering requirement exist?

## A2 2026-10-31 08:30 +09:00 — r04–r07 art delivered (QUEUED)
- fast (pony lancer), siege (catapult), e_brute (bramble troll), e_bomber (keg sapper), boss_warlord (crowned warlord). The theme is still the Q1 default and is not approved.
- Measured heights vs your guidance: fast 26 px (~28), siege 27 px, e_brute 32 px (~36), boss_warlord ~45 px (~52), all in a 64×64 frame. The brute and warlord are shorter than you asked because their bulk/width carries the threat at 1× (docs/art/previews/battle_mock_2x.png). I can make them taller if you need the exact heights.
- New cards: card_fast, card_siege. New portraits: portrait_e_brute, portrait_e_bomber, portrait_boss_warlord. Still missing: boss_overlord (r10).
