extends SceneTree
## Probe for 01/09 (D16 "first wave broken at 25–45 s"): when does wave_cleared(1) fire in r01 for different
## player policies? Run: tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/wave_clear_probe.gd
## with a PRIVATE APPDATA (Save boots as an autoload): & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @(<same args>)
## Policies: competent bot (selftest bot); hero_rush (bot + hero always advances to its leash); deploy_only
## (bot deploys/buys workers, hero stays home). Owner: 02-engine.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")

func _initialize() -> void:
	var c = ContentS.new()
	c.load_all("res://data")
	var rid: String = c.round_order[0]
	var rows := []
	for policy in ["competent", "hero_rush", "deploy_only"]:
		var sim = SimS.new()
		sim.setup(c, rid, 11)
		var bot = BotS.new(2, 11)
		var dt := 1.0 / 60.0
		var t_clear := -1.0
		var first_contact := -1.0
		var w1_death_x := []
		while not sim.ended and sim.t < 300.0 and t_clear < 0.0:
			bot.act(sim, dt)
			if policy == "hero_rush": sim.set_hero_dir(1)
			elif policy == "deploy_only": sim.set_hero_dir(0)
			sim.step(dt)
			for e in sim.enemies:
				if e.wave_tag == 1 and first_contact < 0.0 and sim._find_target(e) != null and absf(sim._find_target(e).x - e.x) <= 30.0:
					first_contact = sim.t
				if e.wave_tag == 1 and e.dying and e.dead_t > SimS.DEATH_TIME - 0.02:
					w1_death_x.append(int(e.x))
			for ev in sim.events:
				if ev[0] == "wave_cleared" and int(ev[1].index) == 1: t_clear = float(ev[1].t)
			sim.events.clear()
			sim.cues.clear()
		rows.append({"policy": policy, "wave1_at": float(sim.wave_times[0]), "first_contact_t": snappedf(first_contact, 0.01),
			"wave_cleared_1_t": snappedf(t_clear, 0.01), "wave1_death_x": w1_death_x, "lane": sim.L, "hero_x_at_clear": int(sim.hero.x)})
	print("WAVE_CLEAR_PROBE ", JSON.stringify(rows))
	c.free()
	quit(0)
