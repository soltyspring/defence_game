extends SceneTree
## Headless campaign gate/affordability probe; bot results are not human playtests.
const Sim = preload("res://src/gameplay/battle_sim.gd")
const Bot = preload("res://src/gameplay/bot_player.gd")
const STEP := 1.0/60.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c = root.get_node("Content")
	var seeds := 3
	var first := 11
	var last := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=",1))
		if a.begins_with("--first="): first = int(a.get_slice("=",1))
		if a.begins_with("--last="): last = int(a.get_slice("=",1))
	var failures := 0
	for n in range(first,last+1):
		for policy in [2,1]:
			var rows := []
			var lv := {}
			for u in c.meta.upgrades:
				var level := 1
				for candidate in range(2,int(u.max_level)+1):
					if int(u.get("level_unlock_rounds",{}).get(str(candidate),1)) <= n: level = candidate
				lv[u.id] = level
			for seed_index in seeds:
				var sim = Sim.new()
				sim.setup(c,"r%02d"%n,101+seed_index,lv)
				var bot = Bot.new(policy,101+seed_index)
				var boss_seen := false
				while not sim.ended and sim.t < 900:
					bot.act(sim,STEP)
					sim.step(STEP)
					for enemy in sim.enemies:
						if enemy.is_boss: boss_seen = true
				rows.append({"won":sim.won,"time":snappedf(sim.t,0.1),"base":snappedf(sim.player_base.hp/sim.player_base.hp_max,0.01),"boss":boss_seen,"coins":sim.result().get("coins",0)})
				if not sim.won or (n%5==0 and not boss_seen): failures += 1
			print("[campaign_balance] ",JSON.stringify({"round":n,"policy":policy,"levels":lv,"runs":rows}))
	print("[campaign_balance] failures=",failures)
	quit(0 if failures == 0 else 1)
