extends SceneTree
## Campaign economy route R11 -> R40 without the test save being touched by hand: real battle reward -> Save.record_result
## -> Save.buy_upgrade (cheapest unlocked level first) -> next round. Starts from the documented r10 LOW+2R fixture.
## Bot results are not human playtests.
##   --to=40 --attempts=6      last round, tries per round before the route stops
##   --pack=0 --pack_at=21     gold added once before round pack_at (a gold pack; 0 = free route)
##   --reads=1                 1 = the bot answers telegraphs (challenge_bot), 0 = plain competent bot
##   --skill=2                 2 competent, 1 casual
##   --farm=1                  after a loss, credit one replay of the previous round (its repeat reward) before the retry
const Sim = preload("res://src/gameplay/battle_sim.gd")
const CBot = preload("res://tests/acceptance/challenge_bot.gd")
const STEP := 1.0 / 60.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c = root.get_node("Content")
	var save = root.get_node("Save")
	var to := 40
	var attempts := 6
	var pack := 0
	var pack_at := 21
	var reads := true
	var skill := 2
	var farm := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--to="): to = int(a.get_slice("=", 1))
		if a.begins_with("--attempts="): attempts = int(a.get_slice("=", 1))
		if a.begins_with("--pack="): pack = int(a.get_slice("=", 1))
		if a.begins_with("--pack_at="): pack_at = int(a.get_slice("=", 1))
		if a.begins_with("--reads="): reads = int(a.get_slice("=", 1)) != 0
		if a.begins_with("--skill="): skill = int(a.get_slice("=", 1))
		if a.begins_with("--farm="): farm = int(a.get_slice("=", 1)) != 0
	var tag := "pack%d_reads%d_skill%d" % [pack, int(reads), skill]
	save.path = "user://campaign_r40/%s.json" % tag
	DirAccess.make_dir_recursive_absolute(save.path.get_base_dir())
	save.progress = save.fresh()
	save.progress.coins = 24
	save.progress.unlocked_round = 11
	save.progress.upgrades = {"up_melee_basic":5,"up_ranged_basic":5,"up_tank":4,"up_fast":4,"up_siege":3,"up_hero":4,"up_supply_regen":4,"up_energy_regen":4,"up_worker":4,"up_base_hp":5}
	var retries := 0
	var farms := 0
	var farmed := 0
	var spent := 0
	var reached := 10
	for n in range(11, to + 1):
		if pack > 0 and n == pack_at:
			save.progress.coins = int(save.progress.coins) + pack
		var cleared := false
		for attempt in attempts:
			for purchase in 200:
				var cheapest := ""
				var price := 999999
				for u in c.meta.upgrades:
					var next: int = save.upgrade_level(u.id) + 1
					if next > int(u.max_level) or n < save.upgrade_level_unlock_round(u.id, next): continue
					var cost: int = save.upgrade_cost(u.id, next)
					if cost >= 0 and cost <= int(save.progress.coins) and cost < price:
						cheapest = u.id
						price = cost
				if cheapest == "": break
				if save.buy_upgrade(cheapest, save.upgrade_level(cheapest) + 1) != save.UPG_OK: break
				spent += price
			var sim = Sim.new()
			sim.setup(c, "r%02d" % n, 301 + n * 7 + attempt, save.progress.upgrades)
			var bot = CBot.new(skill, 301 + n * 7 + attempt)
			bot.reads = reads
			bot.want_workers = 5 + (attempt % 2)      # a retry changes the opening, not only the seed
			while not sim.ended and sim.t < 900:
				bot.act(sim, STEP)
				sim.step(STEP)
				sim.events.clear()
				sim.cues.clear()
			var result: Dictionary = sim.result()
			var rd: Dictionary = c.get_round("r%02d" % n)
			var reward: int = result.coins
			if sim.won:
				reward += int(rd.reward.first_clear_coins)
				if int(result.stars) == 3: reward += int(rd.reward.three_star_bonus_coins)
			result.coins = reward
			result.battle_uid = "r40route-%s-%d-%d" % [tag, n, attempt]
			save.record_result(result, n - 1)
			var lv: Array = []
			var sum := 0
			for u in c.meta.upgrades:
				lv.append(save.upgrade_level(u.id))
				sum += save.upgrade_level(u.id)
			print("[route] ", JSON.stringify({"tag": tag, "round": n, "attempt": attempt + 1, "won": sim.won, "t": snappedf(sim.t, 1.0), "stars": result.stars,
				"base": snappedf(sim.player_base.hp / sim.player_base.hp_max, 0.01), "hero_deaths": sim.hero_deaths, "earned": reward,
				"coins": save.progress.coins, "spent": spent, "levels": lv, "avg": snappedf(float(sum) / lv.size(), 0.1)}))
			if sim.won:
				cleared = true
				reached = n
				break
			retries += 1
			# After a loss the player replays the round before (already cleared) once for its repeat reward, then
			# retries. The replay is credited, not simulated: it is counted in `farms` and `farmed`.
			if farm and n > 11:
				var prev: Dictionary = c.get_round("r%02d" % (n - 1))
				save.progress.coins = int(save.progress.coins) + int(prev.reward.coins)
				farms += 1
				farmed += int(prev.reward.coins)
		if not cleared: break
	print("[route] ", JSON.stringify({"tag": tag, "final": true, "reached": reached, "retries": retries, "farms": farms, "farmed": farmed, "spent": spent, "coins": save.progress.coins}))
	quit(0)
