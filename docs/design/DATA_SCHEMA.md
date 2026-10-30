# Data schema — aligned to docs/contracts/INTERFACES.md v1.0 §2 (PROVISIONAL)
Owner: 01-director. Updated 2026-10-31 06:50 +09:00. Engine contract keys are authoritative; this doc lists the files 01 ships plus **design keys** (★) that 02 does not read yet. ★ keys are formally requested in coordination/requests/01-director-to-02-engine.md (R1). Unknown keys are ignored by the loader, so the data is safe today.
Terminology map: engine `gold` (in-round) = design "supply" (ko: 보급); engine `mana` = design "energy" (ko: 기력); engine `coins` = design persistent "gold" (ko: 골드).
IDs: permanent, theme-neutral snake_case. Display text: `name` is a ko fallback; ★`name_key`/`desc_key` → data/text/<locale>.json.

## Files
| File | Contract § | Notes |
|---|---|---|
| data/units/units.json `{units:[...]}` | 2.1 | 5 player units + 7 enemies (incl. 2 bosses) |
| data/heroes/hero_captain.json | 2.2 | single hero |
| data/skills/skill_slam.json, skill_rally.json, skill_barrage.json | 2.3 | kinds aoe_damage, rally, meteor |
| data/rounds/r01..r10.json + order.json | 2.4, 2.6 | chapter 1 |
| data/economy.json | 2.5 | in-round economy |
| data/meta.json | proposal (02 asked for it) | coins currencies, upgrades, retention/IAP placeholders (disabled) |
| data/game_config.json | ★ none yet | caps (aligned to ENGINE §7: 36/side, 64 proj, 48 fx, 24 popups), camera, hero respawn, lane jitter |
| data/text/ko.json, en.json | ★ | `{strings:{key:text}}`, fallback ko → key |

## Units (2.1) — ★ extras
★`unlock_round` (player) / `first_round` (enemy, info). ★`structure_mult` multiplier vs bases (replaces fixed siege ×2: siege 3.0, brute 1.5, bomber 2.0, bosses 2.0). ★`hit_frame` fallback when atlas has none. ★`kill_coins` persistent coins per kill. ★`is_boss` (boss HP bar, warning). ★`self_destruct` true: on first attack deal splash damage then die (e_bomber). ★`summon {unit,count,interval,max_alive}` (boss_overlord). ★`tags` holds design role.
Armor is flat per contract: `dmg = max(1, atk − armor)`. Values: tank 3, siege 2, e_brute 5, boss_warlord 6, boss_overlord 8, hero 3.
`bounty` = in-round gold (supply) on kill.

## Hero (2.2) — ★ extras
★`mana_start` 30, ★`respawn_per_death` 2, ★`respawn_max` 20, ★`invuln_on_spawn` 1.5, ★`attack_while_moving` true, ★`aura {radius 80, atk_speed_mult 1.10}`. `leash` 0.85.

## Skills (2.3) — ★ extras
★`unlock_round`; hero lists all skills, round `skills` lists the ones usable that round (★ gating). ★`offset_x` (aoe centre ahead of hero), ★`knockback`, ★`delay` (meteor), ★`cast_time`. `rally.power` 30 ⇒ ×1.30 atk and speed for `duration` (design wanted speed ×1.20; accept contract's single power).
Meteor target: contract = frontmost enemy. Design intent was hero_front+200; contract behaviour accepted.

## Rounds (2.4) — ★ extras
★`skills[]` gating, ★`trickle {start, pattern[], interval, interval_min, ramp_per_min}` deterministic cycle (interval_now = max(min, interval − ramp × minutes)); `enemy_ai` kept as fallback with income ≈ trickle value. ★`enemy_scaling {hp, atk}` multipliers on all enemy stats. ★`enemy_tower_atk_mult`. ★`gold_max`, ★`workers_max` per-round overrides of economy. ★`reward.three_star_bonus_coins` (first time 3 stars). ★`tutorial[]` step keys for 04. ★`boss_round`. `stars.time_3`, `stars.base_hp_2` per contract.

## Economy (2.5) — ★ extras
`worker_cost_base 40`, `worker_cost_growth 1.3` (40, 52, 68, 88, 114, 148…), `worker_income 1.5`, `base_income 4`, `workers_start 0`. ★`base_tower {atk 15, atk_interval 1.5, range 130}` both bases. ★`loss_coin_ratio 0.5` of kill_coins kept on loss.

## Meta (data/meta.json, proposal)
currencies[{id,name_key,persistent,start,max,enabled}]; upgrades[{id, target "unit:<id>"|"hero:<id>"|"resource:supply|energy"|"worker"|"base:player", max_level, costs[max_level−1], per_level{hp_mult|atk_mult|regen_add|cap_add|income_add}}]. Level starts 1. `*_mult`: stat × (1 + v × (level−1)); `*_add`: stat + v × (level−1). Visible only when target unlocked. retention_hooks / iap_catalog: disabled placeholders; engine ignores while `enabled:false`.

## Source-of-truth rule (C3)
Engine values come from economy.json, heroes/*, rounds/*. game_config.json is authoritative ONLY for caps, camera, lane, hero_respawn and speed_options; its resources/worker/bases blocks are design mirrors and must be kept equal when editing.

## Required save fields (design requirement for 02 Save)
Progress v1 (contract) + ★ per round `{best_stars, best_time, clears}`, ★`upgrades{<upgrade_id>: level}`, ★`three_star_claimed[round_id]`, ★`tutorial_done[keys]`, ★`stats{kills, rounds_played}`. Store IDs + levels only, never computed stats, so rebalance is save-safe. Unknown IDs after a content update must be ignored and refunded per migration rule (02).
