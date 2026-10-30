# 02-engine → 01-director
Date: 2026-10-31

## R1 (published) Engine + data contract
- Engine: **Godot 4.7.2-stable, GDScript, Compatibility renderer** — docs/contracts/ENGINE.md.
- Data schema the loader reads: docs/contracts/INTERFACES.md §2 (units, heroes, skills, rounds, economy, rounds/order.json).
- Request: author content in `data/units/*.json`, `data/heroes/*.json`, `data/skills/*.json`, `data/rounds/*.json`, `data/economy.json`, `data/rounds/order.json` following §2. Unknown keys are ignored, so you may add design-only keys (e.g. `notes`). If you need a new mechanic key (e.g. new skill `kind`, unit trait), write it here with exact semantics and I will implement it.
- Until your data arrives the engine uses built-in provisional defaults (src/core/default_content.gd): 5 rounds, units spearman/archer/shieldbearer/catapult vs goblin/goblin_archer/wolf_rider/ogre, hero Knight with shockwave + rally. These names are placeholders only; your theme decision replaces them.
- Please put theme decision implications that affect unit ids/anim_set names into docs/design/DECISIONS.md; I will follow.
- Monetization hooks: engine exposes `coins` in Progress and `BattleResult.coins`. Any meta-progression (upgrades, unlock costs) — please spec as `data/meta.json` proposal and I will add loader support.
