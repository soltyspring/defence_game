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

## R2 2026-10-31 — replies to A2/A3 (DEFAULT decisions, theme Q1 still unanswered)
- A17 → **D14 APPROVED**: recolour the purple masses on existing enemies (swarm shells, warlord cape, spitter hood) away from ally blue. Keep ids, frames, pivots and timing unchanged. Acceptance: deuteranopia + protanopia simulated frames of a mixed crowd, distinguishable by hue AND a luminance step. Send the frames to 07.
- A19 → **D15**: `summon.summon_frame: 3` added to boss_overlord in data/units/units.json. 02 is asked to implement it.
- Heights (A2): current heights are accepted, because bulk carries the threat at 1×. Revisit only if 07's readability check fails.
- Font/title lettering: no brand requirement yet. The title is provisional until Q1.

## R3 2026-10-31 — Q1 DECIDED by user: Theme A 빵집 기사단 vs 곰팡이 군단
User's words: "모두 고치고 A) 빵집 기사단 vs 곰팡이 군단이걸로" (DECISIONS.md Q1). Please retheme from "Lantern Kingdom vs Bramble Horde" to this theme. **Keep all ids, frame sizes, pivots, hit frames and timing** (D1).
World, name table and silhouette direction: docs/design/WORLD.md. Summary by id: worker 꼬마 제빵사; melee_basic 식빵 기사; ranged_basic 롤빵 투척병 (projectile `arrow` → thrown bread roll); tank 통식빵 방패병; fast 프레첼 돌격병; siege 화덕 대포 (projectile `rock` → bread-crumb shell); hero_captain 제빵 대장 (chef hat + rolling pin, the Slam weapon); e_grunt 곰팡이 졸개; e_swarm 초파리 떼; e_spitter 포자 뱉개 (projectile `spit` → spore); e_brute 썩은 멧돼지; e_bomber 부푼 효모; boss_warlord 곰팡이 장군; boss_overlord 부패 대군주 (rot nest/hive, summon frame 3 kept); biome_01 밀밭 빵집 마을; player base = bakery, enemy base = mold nest.
Palette: allies warm crust brown/cream/yellow; enemies murky green/purple/grey, separated by hue AND luminance (D14 still applies). No gore.
Card/skill icons: same ids. Please also send the updated docs/art budget numbers to 08.

## R4 2026-10-31 — Q3 DECIDED: working title
User chose the working title "빵집 기사단: 곰팡이 디펜스" / "Bakery Knights: Mold Defense" (16:19). Logo lettering can start (ui_title frames). The final store name waits for a KIPRIS check, so keep the logo easy to change. The resource is renamed to 밀가루/Flour (was 반죽/Dough): please make the supply icon read as flour (a sack or a flour pile), not dough.
