extends SceneTree
## 07-qa QA-J2 probe: does r01 put the player at any risk? Headless, deterministic seeds.
##   Godot_console --headless --path . -s res://tests/acceptance/probe_r01_risk.gd -- [--seeds=20] [--round=r01]
## For casual (1) and competent (2) bot policies: clear time, stars, player-base damage taken, first time
## the player base is hit, waves reached. One JSON line per policy. Not a human measure. Owner: 07-qa.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")

func _initialize() -> void:
	var seeds := 20
	var rid := "r01"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=", 1))
		if a.begins_with("--round="): rid = a.get_slice("=", 1)
	var c = ContentS.new()
	c.load_all("res://data")
	for pol in [1, 2, 3, 0]:   # 1 casual, 2 competent, 3 competent starting at 45 s (D24a), 0 idle
		var rows := []
		for s in seeds:
			var sim = SimS.new()
			sim.setup(c, rid, 500 + s)
			var bot = BotS.new(2 if pol == 3 else pol, 500 + s)
			var first_hit := -1.0
			var hp0: float = sim.player_base.hp
			while not sim.ended and sim.t < 900.0:
				if pol != 0 and (pol != 3 or sim.t >= 45.0): bot.act(sim, 1.0 / 60.0)
				sim.step(1.0 / 60.0)
				if first_hit < 0.0 and sim.player_base.hp < hp0: first_hit = sim.t
			var r: Dictionary = sim.result()
			rows.append({"won": sim.won, "t": snappedf(sim.t, 0.1), "stars": int(r.stars), "base_dmg_pct": snappedf(100.0 * (1.0 - sim.player_base.hp / sim.player_base.hp_max), 0.1),
				"first_hit_s": snappedf(first_hit, 0.1), "waves_reached": sim.current_wave().index, "waves_total": sim.waves_total})
		var wins := rows.filter(func(x): return x.won)
		var three := rows.filter(func(x): return x.stars == 3)
		var hit := rows.filter(func(x): return x.first_hit_s >= 0.0)
		var ts := wins.map(func(x): return x.t); ts.sort()
		var dm := rows.map(func(x): return x.base_dmg_pct); dm.sort()
		print("[r01risk] ", JSON.stringify({"round": rid, "policy": ["idle", "casual", "competent", "late45"][pol], "seeds": seeds,
			"wins": wins.size(), "loss_by_base": rows.filter(func(x): return not x.won and x.base_dmg_pct >= 100.0).size(), "max_loss_t": rows.filter(func(x): return not x.won).map(func(x): return x.t).max() if rows.any(func(x): return not x.won) else null, "three_star": three.size(), "base_hit_runs": hit.size(),
			"median_clear_s": ts[ts.size() / 2] if ts.size() > 0 else null, "max_base_dmg_pct": dm.back(), "median_base_dmg_pct": dm[dm.size() / 2],
			"waves_reached_max": rows.map(func(x): return x.waves_reached).max(), "waves_total": rows[0].waves_total}))
	c.free()
	quit(0)
