extends SceneTree
## Balance probe for 01: a player who does nothing (no workers, no deploys, hero never moved).
## Run: tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/passive_probe.gd
##   with a PRIVATE APPDATA (Save boots as an autoload): & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(<same args>)
## The engine time limit is disabled so the run shows whether the enemy can ever destroy the base (cut at 1800 s).
## Attribution variants for r01/r02: no_player_tower (player base tower never fires), no_hero (hero removed).
## Owner: 02-engine.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")

func _initialize() -> void:
	var c = ContentS.new()
	c.load_all("res://data")
	var rows := []
	for rid in c.round_order:
		for variant in ["standard", "no_player_tower", "no_hero"]:
			if variant != "standard" and c.round_order.find(rid) > 1:
				continue
			for seed_v in ([1, 2, 3, 4, 5] if variant == "standard" else [1]):
				rows.append(_run(c, rid, variant, seed_v))
	print("PASSIVE_PROBE ", JSON.stringify(rows))
	c.free()
	quit(0)

func _run(c, rid: String, variant: String, seed_v: int) -> Dictionary:
	var sim = SimS.new()
	sim.setup(c, rid, seed_v)
	sim.time_limit = 0.0
	var peak_enemy := 0
	var hp_at := {}
	var dt := 1.0 / 60.0
	while not sim.ended and sim.t < 1800.0:
		if variant == "no_player_tower":
			sim.player_base.tower_cd = 1e9
		if variant == "no_hero" and sim.hero_respawn <= 0.0:
			sim._kill(sim.hero, false)
			sim.hero_respawn = 1e9
		sim.step(dt)
		sim.events.clear()
		sim.cues.clear()
		peak_enemy = maxi(peak_enemy, sim.army_count(-1))
		for mark in [120, 300, 600, 900]:
			if not hp_at.has(str(mark)) and sim.t >= mark:
				hp_at[str(mark)] = int(sim.player_base.hp)
	return {"round": rid, "variant": variant, "seed": seed_v, "player_base_destroyed": sim.ended and not sim.won,
		"t_end": snappedf(sim.t, 0.1), "player_base_hp_max": int(sim.player_base.hp_max),
		"player_base_hp_at": hp_at, "player_base_hp_end": int(sim.player_base.hp),
		"hero_deaths": sim.hero_deaths, "enemy_spawned": sim.stats.enemy_spawned, "peak_enemy_alive": peak_enemy}
