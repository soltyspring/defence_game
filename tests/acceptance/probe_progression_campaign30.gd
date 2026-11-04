extends SceneTree
## Real reward -> atomic Save purchase -> next round. Starts with documented r10 LOW+2R.
const Sim = preload("res://src/gameplay/battle_sim.gd")
const Bot = preload("res://src/gameplay/bot_player.gd")
const STEP := 1.0/60.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c = root.get_node("Content")
	var save = root.get_node("Save")
	save.path = "user://campaign_economy/save.json"
	DirAccess.make_dir_recursive_absolute(save.path.get_base_dir())
	# docs are intentionally excluded from export snapshots: keep this explicit fixture
	# equal to docs/design/balance/upgrade_budgets.json low2r.r10.levels.
	var initial := {"up_melee_basic":5,"up_ranged_basic":5,"up_tank":4,"up_fast":4,"up_siege":3,"up_hero":4,"up_supply_regen":4,"up_energy_regen":4,"up_worker":4,"up_base_hp":5}
	var fails := 0
	for policy in [2,1]:
		save.progress = save.fresh()
		save.progress.coins = 24
		save.progress.unlocked_round = 11
		save.progress.upgrades = initial.duplicate()
		for n in range(11,31):
			var cleared := false
			for attempt in 3:
				# Buy the cheapest unlocked next level, so every coin comes from this route.
				for purchase in 120:
					var cheapest := ""
					var price := 999999
					for u in c.meta.upgrades:
						var next: int = save.upgrade_level(u.id)+1
						if next > int(u.max_level) or n < save.upgrade_level_unlock_round(u.id,next): continue
						var cost: int = save.upgrade_cost(u.id,next)
						if cost >= 0 and cost <= int(save.progress.coins) and cost < price:
							cheapest = u.id
							price = cost
					if cheapest == "": break
					if save.buy_upgrade(cheapest,save.upgrade_level(cheapest)+1) != save.UPG_OK:
						fails += 1
						break
				var sim = Sim.new()
				sim.setup(c,"r%02d"%n,301+n*7+attempt,save.progress.upgrades)
				var bot = Bot.new(policy,301+n*7+attempt)
				var rng := RandomNumberGenerator.new()
				rng.seed = 301+n*7+attempt
				var wait := rng.randf_range(0,3)
				var elapsed := 0.0
				var boss_seen := false
				while not sim.ended and sim.t < 900:
					wait -= STEP
					elapsed += STEP
					if wait <= 0:
						bot.act(sim,elapsed)
						elapsed = 0
						wait = rng.randf_range(0,0.6) if rng.randf() < 0.25 else 0
					sim.step(STEP)
					for enemy in sim.enemies:
						if enemy.is_boss: boss_seen = true
				var result: Dictionary = sim.result()
				var rd: Dictionary = c.get_round("r%02d"%n)
				var reward: int = result.coins
				if sim.won:
					reward += int(rd.reward.first_clear_coins)
					if int(result.stars) == 3: reward += int(rd.reward.three_star_bonus_coins)
				result.coins = reward
				result.battle_uid = "campaign-%d-%d-%d"%[policy,n,attempt]
				if not save.record_result(result,n-1): fails += 1
				print("[campaign_economy] ",JSON.stringify({"round":n,"policy":policy,"attempt":attempt+1,"won":sim.won,"seconds":snappedf(sim.t,0.1),"stars":result.stars,"earned":reward,"coins_left":save.progress.coins,"upgrades":save.progress.upgrades,"boss":boss_seen,"base":snappedf(sim.player_base.hp/sim.player_base.hp_max,0.01)}))
				if sim.won:
					cleared = true
					if n%5==0 and not boss_seen: fails += 1
					break
			if not cleared:
				fails += 1
				break
		print("[campaign_economy] final policy=",policy," reach=",save.progress.unlocked_round," coins=",save.progress.coins)
	print("[campaign_economy] failures=",fails)
	quit(0 if fails == 0 else 1)
