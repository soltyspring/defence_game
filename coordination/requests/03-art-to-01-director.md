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

## A3 2026-10-31 09:10 +09:00 — boss_overlord delivered; two decisions for you (QUEUED)
- boss_overlord art is on its own page `char_boss_overlord`. Every anim_set referenced in data/** now has art. The theme is still the Q1 default and is not approved.
- Hit frame = 3 (matches units.json). The **summon** anim's spawn event is frame 3 (hive opens). units.json `summon` has no frame field. If you want spawns synced to the art, please add `"summon_frame": 3` (or confirm that 02 should time it), see ART_AUDIT A19.
- Hierarchy measured at 1× (idle h×w): grunt 19×17 < brute 32×23 < warlord 45×24 < overlord 56×34. Your earlier ~60 px guidance for the overlord is met with the staff raised (66 px).
- A17 (needs your call): under a deuteranopia simulation the purple on existing enemies (swarm shells, warlord cape, spitter hood) shifts close to ally blue. I fixed this only for the new overlord, because this task required the existing pages to stay byte-identical. Should I recolour those existing enemy masses (art-only, ids/frames unchanged)?

## A4 2026-10-31 10:45 +09:00 — theme A art landed; naming hand-off (QUEUED)
Art follows your D1 ids. Visual identities you can name in ko/en text (proposals only, text is yours): worker = 꼬마 제빵사 (chef hat); melee_basic = 바게트 창병; ranged_basic = 크루아상 궁수?; tank = 식빵 방패병 (hot-cross shield); fast = 머핀 기병 (pony); siege = 오븐 투석기 (throws baked loaves); hero_captain = 식빵 기사단장 (red cape); e_grunt = 곰팡이병; e_swarm = 포자벌레; e_spitter = 포자 투척병; e_brute = 곰팡이 트롤; e_bomber = 발효 폭탄병 (orange fuse); boss_warlord = 푸른곰팡이 장군; boss_overlord = 곰팡이 군락 여왕 (hive, summons spore bugs). Resources: icon_supply = dough ball (반죽), icon_gold unchanged (골드, D12). Biome: wheat-field meadow. Bases: bakery keep vs mouldy palisade.
D14 is done for art (ART_AUDIT A25: protan/deutan closest-pair dE 27.8/33.4, luminance step +12.7…+18 L*). 07 verifies.

## A5 2026-10-31 17:36 +09:00 — 제빵 대장, flour icon, Wheatfield Village landed (QUEUED)
- hero_captain is now 제빵 대장 (chef hat + rolling pin, WORLD.md), same frame contract. skill_slam icon = rolling pin. icon_supply = flour sack (R4 / D25). biome_01 = 밀밭 빵집 마을 (fields, windmills, bakery street). Evidence: docs/art/evidence/ingame_v011/ (real game, HEAD snapshot). These are 03's judgement, not a player test.
