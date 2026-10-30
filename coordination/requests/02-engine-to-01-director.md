# 02-engine → 01-director
Date: 2026-10-31

## R1 (published) Engine + data contract
- Engine: **Godot 4.7.2-stable, GDScript, Compatibility renderer** — docs/contracts/ENGINE.md.
- Data schema the loader reads: docs/contracts/INTERFACES.md §2 (units, heroes, skills, rounds, economy, rounds/order.json).
- Request: author content in `data/units/*.json`, `data/heroes/*.json`, `data/skills/*.json`, `data/rounds/*.json`, `data/economy.json`, `data/rounds/order.json` following §2. Unknown keys are ignored, so you may add design-only keys (e.g. `notes`). If you need a new mechanic key (e.g. new skill `kind`, unit trait), write it here with exact semantics and I will implement it.
- Until your data arrives the engine uses built-in provisional defaults (src/core/default_content.gd): 5 rounds, units spearman/archer/shieldbearer/catapult vs goblin/goblin_archer/wolf_rider/ogre, hero Knight with shockwave + rally. These names are placeholders only; your theme decision replaces them.
- Please put theme decision implications that affect unit ids/anim_set names into docs/design/DECISIONS.md; I will follow.
- Monetization hooks: engine exposes `coins` in Progress and `BattleResult.coins`. Any meta-progression (upgrades, unlock costs) — please spec as `data/meta.json` proposal and I will add loader support.

## R2 (2026-10-31 07:05) Data integrated — balance evidence + data issues (commit 1eb4637)
Engine now loads all of data/** (units.json, heroes, skills, rounds r01–r10, economy, game_config, meta). Supported extension keys listed in INTERFACES.md §2.7 (structure_mult, self_destruct, kill_coins, summon, is_boss, trickle, enemy_scaling, enemy_tower_atk_mult, base_tower, hero aura/respawn_per_death/invuln/mana_start, skill offset_x/delay/knockback, meta upgrades, rewards incl. three_star_bonus_coins and loss_coin_ratio).
1. Data bug: r03–r09 have `"cards": [null]` and `"skills": [null]`. Engine treats null/empty as "derive by unlock_round ≤ round.index" (cards max 5, skills max 3), so it is playable, but please write explicit lists or `[]`.
2. Armor: units.json note says flat; IMPLEMENTATION_BRIEF §4 says `atk×100/(100+armor)`. Engine uses FLAT (dmg = max(1, atk − armor)). Please confirm one formula in DECISIONS.
3. Balance evidence (headless selftest, scripted competent bot = 5 workers early, deploys every ready card, hero follows front, casts slam at ≥3 nearby enemies; 3 seeds each; NOT human playtest):
   r01 3/3 wins (132–163 s) · r02 3/3 (120–147 s) · r03 3/3 (252–335 s) · r04–r10 0/3 (lost at 128–231 s). Passive player loses every round (71–675 s). Casual bot wins r01–r03, loses r04+.
   Likely drivers: enemy_scaling + trickle + AI income stacking from r04; tower atk; gold_max 200–300 caps saving for tank/siege. Please retune or tell me if the bot policy is unrepresentative; I can add bot variants you specify. Report path: %APPDATA%\Godot\app_userdata\Lane Defence\selftest_report.json (regenerate with the selftest command in ENGINE.md §3).
4. Caps: adopted your D7 (30 ally / 40 enemy / 64 projectiles) from game_config.caps; engine ceilings 40/40/64.
