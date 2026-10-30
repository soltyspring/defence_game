# Game design document — PROVISIONAL v0.1 (01-director)
Working title: none chosen (title depends on Q1). Numbers: data/*.json are authoritative; this doc explains intent.

## 1. Theme options (Q1 pending, see coordination/requests/USER_QUESTION.md)
| Option | Allies / enemies | Resource fiction | Strength | Risk |
|---|---|---|---|---|
| A. 빵집 기사단 (recommended) | bread/pastry soldiers vs mold & pest legion | dough | stands out in a market of animal clones; bread shapes give distinct silhouettes; warm vs green palettes read well on small screens; humour | food theme may feel kid-skewed |
| B. 도토리 숲 수비대 | squirrels, hedgehogs, moles vs beetle swarm | acorns | proven animal appeal | structurally close to the cat-vs-dog reference |
| C. 등불 수호자 | lantern spirits & gnomes vs night-fog monsters | embers | atmospheric, distinct | glow/additive FX cost on low-end GPUs and more art time |
Role mapping for A (illustrative only until answered): worker=little baker, melee_basic=toast knight, ranged_basic=baguette thrower, tank=croissant shield, fast=pretzel rider, siege=oven cannon, hero=head baker captain; enemies grunt=mold blob, swarm=fruit fly, spitter=spore spitter, brute=rot boar, bomber=yeast bomb, bosses=Mold Warlord / Rot Overlord.

## 2. Design pillars
1. Readable in one glance on a 5" phone: max ~6 unit silhouettes on screen types, strong ally/enemy colour split, big HP bars on bases.
2. One decision every 2–4 seconds: invest (worker) vs spend (unit) vs save (skill/expensive unit).
3. Hero matters but does not carry (hypothesis H-HERO in QUALITY_BAR.md, shares are intent not measurement): hero ~25% of early damage, falls to ~15% later; units win the round.
4. Short sessions: 2–5 min rounds, instant retry, play one-handed-ish with thumbs.
5. Fair progression: every round beatable with upgrades purchasable from first clears of previous rounds, no payment required.

## 3. Core loop
See IMPLEMENTATION_BRIEF.md §2. Moment-to-moment decision tension: worker payback is 27 s for the first worker, 45 s for the third, 99 s for the sixth, so late workers are a gamble against round length.

## 4. Hero
`hero_captain`: sturdy melee (600 HP, 31 DPS, flat armor 3), speed 70 (faster than all ally units except fast). Attacks while moving so kiting is possible. Aura +10% attack speed to allies within 80 px rewards fighting with the army instead of solo pushing. Death → respawn at base (8 s +2 s per death, max 20 s).
Skills: Slam (R2, cheap crowd control, 40 energy/8 s), Rally (R4, push window, 60/20 s), Barrage (R8, long-range AoE that rewards positioning ahead of the army, 80/30 s). Energy cap 100 forces a choice between Slam spam and saving for Barrage.
Future heroes (backlog): ranged support hero, summoner hero — heroes.json is already an array.

## 5. Workers
Abstract income, invulnerable in MVP; up to 8 visual workers shuttle behind the base. Cost 40×1.3^n, +1.5 supply/s each, per-round cap 4→8. Later option (backlog): enemy raiders target workers.

## 6. Units (role → counter)
| ID | Cost/CD | Role | Good vs | Weak vs |
|---|---|---|---|---|
| melee_basic | 30 / 2 s | cheap frontline DPS | grunt, swarm | brute, spitters behind a wall |
| ranged_basic | 40 / 3 s | backline DPS (range 110) | spitter, brute (safe) | swarm rushes, bomber |
| tank | 70 / 6 s | wall, flat armor 3 | spitter volleys, brute | swarm (slow killing) |
| fast | 55 / 4 s | speed 80 diver | spitters, bombers before contact | brute |
| siege | 120 / 12 s | splash 30, ×3 vs base | swarm clumps, bases | divers if unprotected |
Enemies mirror: grunt (baseline), swarm (fast fragile, punishes lack of AoE), spitter (ranged, punishes no tank), brute (armored, punishes melee spam), bomber (burst ×2 vs base, punishes letting enemies reach the wall), two bosses.

## 7. Win / loss / stars
Win destroys enemy base; loss = player base destroyed; Retry restarts. Stars: win; base HP ≥ ratio; time ≤ par.

## 8. Feel requirements (for 02/03/04)
Hit flash 1 frame white, small knockback, damage numbers optional/capped, screen shake only on boss/siege/base hits (toggle in settings). Deploy feedback within 1 frame of tap. Boss warning banner 3 s before boss spawn.
