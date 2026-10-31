extends SceneTree
## 07-qa independent balance probe (cross-check of 01's multi_seed_sim, not a copy of it).
##   Godot_console --headless --path . -s res://tests/acceptance/probe_balance.gd -- --rounds=r05,r09,r10 --seeds=10 [--budgets=low,none]
## Differences from 01 on purpose: seeds 101.. (not 1..5); noise = reaction delay U(0,0.6) s per decision
## and start U(0,5) s (01: U(0,0.35) / U(0,3)); also a casual policy. Upgrade levels read from 01's
## docs/design/balance/upgrade_budgets.json (same LOW/HIGH definition, so results are comparable).
## Prints one JSON line per round x budget x policy. Bot results are not human evidence. Owner: 07-qa.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	var rounds := ["r05", "r09", "r10"]
	var seeds := 10
	var budgets := ["low", "none"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="): rounds = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=", 1))
		if a.begins_with("--budgets="): budgets = Array(a.get_slice("=", 1).split(","))
	var bud = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/balance/upgrade_budgets.json"))
	var c = ContentS.new()
	c.load_all("res://data")
	for rid in rounds:
		var par := float(c.get_round(rid).get("stars", {}).get("time_3", 0))
		for b in budgets:
			var lv: Dictionary = {} if b == "none" or not (bud is Dictionary) else bud[b][rid]["levels"]
			for pol in [2, 1]:
				var rows := []
				for s in seeds:
					var sd := 101 + s
					var rng := RandomNumberGenerator.new(); rng.seed = sd * 7919
					var sim = SimS.new()
					sim.setup(c, rid, sd, lv)
					var bot = BotS.new(pol, sd)
					var wait := rng.randf_range(0.0, 5.0)
					var min_ratio := 1.0
					while not sim.ended and sim.t < 900.0:
						wait -= STEP
						if wait <= 0.0:
							bot.act(sim, STEP)
							if rng.randf() < 0.25: wait = rng.randf_range(0.0, 0.6)
						sim.step(STEP)
						min_ratio = minf(min_ratio, sim.player_base.hp / sim.player_base.hp_max)
					rows.append({"won": sim.won, "t": snappedf(sim.t, 0.1), "min_base": snappedf(min_ratio, 0.01), "stars": int(sim.result().stars)})
				var wins := rows.filter(func(x): return x.won)
				var ts := wins.map(func(x): return x.t); ts.sort()
				var mb := rows.map(func(x): return x.min_base); mb.sort()
				print("[balance] ", JSON.stringify({"round": rid, "budget": b, "policy": "competent" if pol == 2 else "casual", "seeds": seeds,
					"wins": wins.size(), "t_min_med_max": [ts[0] if ts.size() else null, ts[ts.size() / 2] if ts.size() else null, ts.back() if ts.size() else null],
					"par": par, "med_le_1_25_par": ts.size() > 0 and ts[ts.size() / 2] <= 1.25 * par, "worst_min_base": mb[0], "median_min_base": mb[mb.size() / 2],
					"stars": rows.map(func(x): return x.stars)}))
	c.free()
	quit(0)
