extends SceneTree
## Energy skill balance: the bot plays sample rounds with the round's default set (slam, rally, barrage) and with
## one new skill in place of barrage; same upgrade plan as probe_campaign100_balance (first-clear + 3-star income,
## cheapest active upgrade first), 30 Hz, 600 s cap, seeds 11/29/47, casual bot. Prints SKILLBAL rows and a summary.
##   godot --headless --path . -s tests/acceptance/probe_skill_balance.gd -- [--rounds=16,24,...]
const Sim := preload("res://src/gameplay/battle_sim.gd")
const Bot := preload("res://src/gameplay/bot_player.gd")
const Plan := preload("res://tests/acceptance/probe_campaign100_balance.gd")
const SETS := {
	"default": ["skill_slam", "skill_rally", "skill_barrage"],
	"flour": ["skill_slam", "skill_rally", "skill_flour"],
	"shield": ["skill_slam", "skill_rally", "skill_shield"],
	"frost": ["skill_slam", "skill_rally", "skill_frost"],
	"oven": ["skill_slam", "skill_rally", "skill_oven"],
}
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var c = root.get_node("Content")
	var rounds := [16, 24, 30, 42, 61, 79, 96]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			rounds = []
			for x in a.get_slice("=", 1).split(","): rounds.append(int(x))
	var summary := {}
	for n in rounds:
		var plan: Dictionary = Plan.build_upgrades(c, n, 0)
		for set_name in SETS:
			var ids: Array = SETS[set_name]
			if ids.any(func(s): return int(c.skills[s].unlock_round) > n): continue
			for seed_value in [11, 29, 47]:
				var sim = Sim.new()
				sim.setup(c, "r%02d" % n, seed_value, plan.upgrades, [], ids)
				var bot = Bot.new(1, seed_value)
				while not sim.ended and sim.t < 600:
					bot.act(sim, 1.0 / 30.0)
					sim.step(1.0 / 30.0)
				var won: bool = sim.ended and sim.enemy_base.hp <= 0
				var row := {"round": n, "set": set_name, "seed": seed_value, "won": won, "seconds": snappedf(sim.t, 0.1),
					"base_hp": snappedf(sim.player_base.hp / sim.player_base.hp_max, 0.01), "casts": int(sim.stats.skills_cast)}
				print("SKILLBAL ", JSON.stringify(row))
				var key := "%d/%s" % [n, set_name]
				var s: Dictionary = summary.get(key, {"wins": 0, "runs": 0, "seconds": 0.0, "base": 0.0, "casts": 0})
				s.wins += 1 if won else 0
				s.runs += 1
				s.seconds += sim.t
				s.base += sim.player_base.hp / sim.player_base.hp_max
				s.casts += int(sim.stats.skills_cast)
				summary[key] = s
	for key in summary:
		var s: Dictionary = summary[key]
		print("SKILLSUM %s wins %d/%d avg_time %.0f avg_base %.2f casts %.1f" % [key, s.wins, s.runs, s.seconds / s.runs, s.base / s.runs, float(s.casts) / s.runs])
	quit(0)
