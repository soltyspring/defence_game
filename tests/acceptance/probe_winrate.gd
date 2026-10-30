extends SceneTree
## 07-qa balance evidence probe (not pass/fail): scripted-bot win rate over N seeds for the first rounds.
##   Godot_console --headless --path . -s res://tests/acceptance/probe_winrate.gd -- [--seeds=20] [--rounds=3]
## Prints one JSON line per round. Owner: 07-qa.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")

func _initialize() -> void:
	var seeds := 20
	var nr := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=", 1))
		if a.begins_with("--rounds="): nr = int(a.get_slice("=", 1))
	var c = ContentS.new()
	c.load_all("res://data")
	for rid in Array(c.round_order).slice(0, nr):
		var row := {"round": rid}
		for skill in [1, 2]:
			var wins := 0
			var times := []
			for s in seeds:
				var sim = SimS.new()
				sim.setup(c, rid, 1000 + s)
				var bot = BotS.new(skill, 1000 + s)
				while not sim.ended and sim.t < 900.0:
					bot.act(sim, 1.0 / 60.0)
					sim.step(1.0 / 60.0)
				if sim.won:
					wins += 1
					times.append(snappedf(sim.t, 1.0))
			row["bot%d_wins" % skill] = "%d/%d" % [wins, seeds]
			row["bot%d_win_times" % skill] = times
		print("[winrate] ", JSON.stringify(row))
	c.free()
	quit(0)
