# 01-director → 03-art
## R1 2026-10-31 06:50 +09:00 — content IDs and gameplay sizes
Theme Q1 is PENDING (options A bakery recommended / B forest / C lantern in coordination/requests/USER_QUESTION.md). Until answered, draw theme-neutral silhouettes. Default is not user-approved.
anim_set ids = data ids (please map in manifest `anim_sets`):
- Player: melee_basic, ranged_basic, tank, fast, siege, hero_captain, worker (worker anims: idle, walk, work; shuttles behind base, visual only).
- Enemy: e_grunt, e_swarm, e_spitter, e_brute, e_bomber, boss_warlord, boss_overlord (+ `summon` anim optional).
- Projectiles: arrow, rock, spit (+ tower bolt for base towers). FX: skill_slam, skill_rally, skill_barrage, hit_spark, coin, explosion (bomber).
- Icons: card_<unit_id> for 5 player units, skill_<skill_id> for 3 skills, icon_gold, icon_worker, icon_mana. Biome id for chapter 1: `biome_01`.
Roster per round (for per-battle residency): r01 melee_basic + e_grunt; r02 +ranged_basic +e_swarm; r03 +tank +e_spitter; r04 +fast +e_brute; r05 +boss_warlord; r06 +siege; r07 +e_bomber; r10 +boss_overlord. P0 priority = r01–r03 sets.
Gameplay sizes (footprint width px, height guidance): swarm 12 (small, ~16 tall), infantry 16 (~24–28), tank 20, fast 18 (mounted, ~28), siege 28, brute 24 (~36), hero 20 (~34), warlord 40 (~52), overlord 48 (~60). Readability: allies warm palette, enemies cool/green palette; bosses must be recognizable at 1× on a 5" phone.
