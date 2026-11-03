extends RefCounted
## Built-in PROVISIONAL content used when data/** is missing or invalid.
## Names are placeholders until 01-director's theme decision. Owner: 02-engine.

static func economy() -> Dictionary:
	return {
		"gold_max": 999, "base_income": 5.0, "worker_income": 2.5,
		"workers_start": 1, "workers_max": 8,
		"worker_cost_base": 60, "worker_cost_growth": 1.35, "mana_on_kill": 2,
	}

static func units() -> Array:
	return [
		# player
		{"id": "spearman", "name": "Toast", "faction": "player", "cost": 40, "cooldown": 2.5,
		 "hp": 110, "atk": 12, "atk_interval": 0.9, "range": 18, "speed": 36, "attack_type": "melee", "anim_set": "spearman"},
		{"id": "archer", "name": "Roll", "faction": "player", "cost": 60, "cooldown": 3.5,
		 "hp": 70, "atk": 11, "atk_interval": 1.2, "range": 110, "speed": 30, "attack_type": "ranged", "projectile": "arrow", "anim_set": "archer"},
		{"id": "shieldbearer", "name": "Loaf", "faction": "player", "cost": 80, "cooldown": 6.0,
		 "hp": 330, "atk": 8, "atk_interval": 1.2, "range": 16, "speed": 24, "armor": 3, "attack_type": "melee", "anim_set": "shieldbearer", "size": 1.2},
		{"id": "catapult", "name": "Oven", "faction": "player", "cost": 150, "cooldown": 12.0,
		 "hp": 150, "atk": 45, "atk_interval": 3.0, "range": 170, "speed": 18, "attack_type": "siege", "projectile": "rock", "splash": 30, "anim_set": "catapult", "size": 1.4},
		# enemy
		{"id": "goblin", "name": "Goblin", "faction": "enemy", "cost": 25, "hp": 80, "atk": 9, "atk_interval": 0.9,
		 "range": 16, "speed": 40, "attack_type": "melee", "bounty": 6, "anim_set": "goblin", "size": 0.9},
		{"id": "goblin_archer", "name": "Goblin Archer", "faction": "enemy", "cost": 40, "hp": 55, "atk": 8, "atk_interval": 1.3,
		 "range": 100, "speed": 32, "attack_type": "ranged", "projectile": "arrow", "bounty": 8, "anim_set": "goblin_archer", "size": 0.9},
		{"id": "wolf_rider", "name": "Wolf Rider", "faction": "enemy", "cost": 60, "hp": 150, "atk": 14, "atk_interval": 0.8,
		 "range": 18, "speed": 62, "attack_type": "melee", "bounty": 12, "anim_set": "wolf_rider", "size": 1.1},
		{"id": "ogre", "name": "Ogre", "faction": "enemy", "cost": 200, "hp": 900, "atk": 40, "atk_interval": 1.8,
		 "range": 24, "speed": 18, "armor": 2, "attack_type": "melee", "splash": 22, "bounty": 60, "anim_set": "ogre", "size": 1.8},
	]

static func heroes() -> Array:
	return [
		{"id": "hero_knight", "name": "Knight", "hp": 600, "atk": 28, "atk_interval": 0.8, "range": 22,
		 "speed": 70, "armor": 2, "respawn": 10.0, "mana_max": 100, "mana_regen": 4.0,
		 "skills": ["shockwave", "rally"], "anim_set": "hero_knight", "leash": 0.6},
	]

static func skills() -> Array:
	return [
		{"id": "shockwave", "name": "Shockwave", "mana": 40, "cooldown": 8.0, "kind": "aoe_damage", "radius": 90, "power": 90, "fx": "shockwave"},
		{"id": "rally", "name": "Rally", "mana": 30, "cooldown": 15.0, "kind": "rally", "radius": 2000, "power": 40, "duration": 6.0, "fx": "rally"},
	]

static func rounds() -> Array:
	return [
		{"id": "r01", "index": 1, "name": "Meadow Gate", "biome": "meadow", "lane_length": 1000,
		 "player_base_hp": 1500, "enemy_base_hp": 900, "start_gold": 100, "hero": "hero_knight",
		 "cards": ["spearman", "archer"],
		 "waves": [
			{"at": 6, "spawns": [{"unit": "goblin", "count": 3, "interval": 1.5}]},
			{"at": 30, "spawns": [{"unit": "goblin", "count": 4, "interval": 1.2}, {"unit": "goblin_archer", "count": 1}]},
			{"at": 60, "spawns": [{"unit": "goblin", "count": 5, "interval": 1.0}, {"unit": "goblin_archer", "count": 2, "interval": 2.0}]}],
		 "enemy_ai": {"income": 3.0, "start_gold": 0, "pool": ["goblin"], "think": 3.0, "ramp": 0.02},
		 "enemy_base_spawns_on_hp": [{"below": 0.4, "spawns": [{"unit": "goblin", "count": 4, "interval": 0.6}]}],
		 "reward": {"coins": 30, "first_clear_coins": 60}, "stars": {"time_3": 150, "base_hp_2": 0.6}},
		{"id": "r02", "index": 2, "name": "Old Bridge", "biome": "meadow", "lane_length": 1100,
		 "player_base_hp": 1500, "enemy_base_hp": 1200, "start_gold": 100, "hero": "hero_knight",
		 "cards": ["spearman", "archer", "shieldbearer"],
		 "waves": [
			{"at": 5, "spawns": [{"unit": "goblin", "count": 4, "interval": 1.2}]},
			{"at": 35, "spawns": [{"unit": "wolf_rider", "count": 2, "interval": 2.0}, {"unit": "goblin_archer", "count": 2, "interval": 1.5}]},
			{"at": 70, "spawns": [{"unit": "goblin", "count": 6, "interval": 0.8}, {"unit": "wolf_rider", "count": 2, "interval": 2.0}]}],
		 "enemy_ai": {"income": 4.0, "start_gold": 20, "pool": ["goblin", "goblin_archer"], "think": 2.8, "ramp": 0.025},
		 "enemy_base_spawns_on_hp": [{"below": 0.5, "spawns": [{"unit": "wolf_rider", "count": 2, "interval": 1.0}]}],
		 "reward": {"coins": 40, "first_clear_coins": 80}, "stars": {"time_3": 170, "base_hp_2": 0.5}},
		{"id": "r03", "index": 3, "name": "Pine Hollow", "biome": "forest", "lane_length": 1200,
		 "player_base_hp": 1600, "enemy_base_hp": 1500, "start_gold": 120, "hero": "hero_knight",
		 "cards": ["spearman", "archer", "shieldbearer", "catapult"],
		 "waves": [
			{"at": 5, "spawns": [{"unit": "goblin", "count": 4, "interval": 1.0}, {"unit": "goblin_archer", "count": 2, "interval": 1.5}]},
			{"at": 40, "spawns": [{"unit": "wolf_rider", "count": 4, "interval": 1.5}]},
			{"at": 80, "boss": true, "spawns": [{"unit": "ogre", "count": 1}, {"unit": "goblin", "count": 4, "interval": 1.0}]}],
		 "enemy_ai": {"income": 5.0, "start_gold": 40, "pool": ["goblin", "goblin_archer", "wolf_rider"], "think": 2.6, "ramp": 0.03},
		 "enemy_base_spawns_on_hp": [{"below": 0.5, "spawns": [{"unit": "goblin", "count": 5, "interval": 0.5}]}],
		 "reward": {"coins": 50, "first_clear_coins": 100}, "stars": {"time_3": 200, "base_hp_2": 0.5}},
		{"id": "r04", "index": 4, "name": "Thorn Road", "biome": "forest", "lane_length": 1300,
		 "player_base_hp": 1700, "enemy_base_hp": 1800, "start_gold": 120, "hero": "hero_knight",
		 "cards": ["spearman", "archer", "shieldbearer", "catapult"],
		 "waves": [
			{"at": 5, "spawns": [{"unit": "wolf_rider", "count": 2, "interval": 1.0}, {"unit": "goblin", "count": 4, "interval": 0.8}]},
			{"at": 45, "spawns": [{"unit": "goblin_archer", "count": 4, "interval": 1.0}, {"unit": "wolf_rider", "count": 3, "interval": 1.2}]},
			{"at": 90, "boss": true, "spawns": [{"unit": "ogre", "count": 2, "interval": 6.0}, {"unit": "goblin", "count": 6, "interval": 0.8}]}],
		 "enemy_ai": {"income": 6.0, "start_gold": 60, "pool": ["goblin", "goblin_archer", "wolf_rider"], "think": 2.4, "ramp": 0.035},
		 "enemy_base_spawns_on_hp": [{"below": 0.5, "spawns": [{"unit": "wolf_rider", "count": 3, "interval": 0.8}]}, {"below": 0.2, "spawns": [{"unit": "ogre", "count": 1}]}],
		 "reward": {"coins": 60, "first_clear_coins": 120}, "stars": {"time_3": 230, "base_hp_2": 0.5}},
		{"id": "r05", "index": 5, "name": "Ogre Keep", "biome": "desert", "lane_length": 1400,
		 "player_base_hp": 1800, "enemy_base_hp": 2400, "start_gold": 150, "hero": "hero_knight",
		 "cards": ["spearman", "archer", "shieldbearer", "catapult"],
		 "waves": [
			{"at": 5, "spawns": [{"unit": "goblin", "count": 6, "interval": 0.7}, {"unit": "goblin_archer", "count": 3, "interval": 1.0}]},
			{"at": 50, "spawns": [{"unit": "ogre", "count": 1}, {"unit": "wolf_rider", "count": 4, "interval": 1.0}]},
			{"at": 100, "boss": true, "spawns": [{"unit": "ogre", "count": 3, "interval": 5.0}, {"unit": "wolf_rider", "count": 4, "interval": 1.0}]}],
		 "enemy_ai": {"income": 7.0, "start_gold": 80, "pool": ["goblin", "goblin_archer", "wolf_rider", "ogre"], "think": 2.2, "ramp": 0.04},
		 "enemy_base_spawns_on_hp": [{"below": 0.6, "spawns": [{"unit": "wolf_rider", "count": 4, "interval": 0.6}]}, {"below": 0.25, "spawns": [{"unit": "ogre", "count": 2, "interval": 3.0}]}],
		 "reward": {"coins": 80, "first_clear_coins": 200}, "stars": {"time_3": 260, "base_hp_2": 0.5}},
	]
