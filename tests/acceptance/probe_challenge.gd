extends SceneTree
## Headless probe of the challenge rounds that exist (R31/R35/R40): plain bot vs a bot that reads the telegraphs
## and cuts links. Bot results are not human playtests.   Args: --seeds=3 --rounds=r31,r35,r40 --level=9
const Sim = preload("res://src/gameplay/battle_sim.gd")
const CBot = preload("res://tests/acceptance/challenge_bot.gd")
const STEP := 1.0 / 60.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c = root.get_node("Content")
	var seeds := 3
	var ids := ["r31", "r35", "r40"]
	var level := 9
	var skills := [2, 1]
	var workers := -1      # >= 0: override how many bakers the bot wants before it spends freely
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=", 1))
		if a.begins_with("--rounds="): ids = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--level="): level = int(a.get_slice("=", 1))
		if a.begins_with("--skill="): skills = [int(a.get_slice("=", 1))]
		if a.begins_with("--workers="): workers = int(a.get_slice("=", 1))
	var lv := {}
	for u in c.meta.upgrades:
		lv[u.id] = mini(level, int(u.max_level))
	for id in ids:
		for reads in [false, true]:
			for skill in skills:
				var rows := []
				for si in seeds:
					var sim = Sim.new()
					sim.setup(c, str(id), 101 + si, lv)
					var bot = CBot.new(skill, 101 + si)
					bot.reads = reads
					if workers >= 0: bot.want_workers = workers
					var heavy := 0
					var hero_hit := 0
					var breaks := 0
					var hero_dmg := 0.0
					var flour_lost := 0
					var dead := {}
					while not sim.ended and sim.t < 900:
						bot.act(sim, STEP)
						var hp0: float = sim.hero.hp
						sim.step(STEP)
						if sim.hero.hp < hp0: hero_dmg += hp0 - sim.hero.hp
						for u in sim.players:
							if u.dying and not dead.has(u.uid):
								dead[u.uid] = true
								flour_lost += int(u.def.cost)
						for e in sim.events:
							if e[0] == "heavy_hit":
								heavy += 1
								if sim.hero.hp < hp0 - 30.0: hero_hit += 1
							elif e[0] == "link_break": breaks += 1
						sim.events.clear()
						sim.cues.clear()
					rows.append({"won": sim.won, "t": snappedf(sim.t, 1.0), "base": snappedf(sim.player_base.hp / sim.player_base.hp_max, 0.01),
						"hero_deaths": sim.hero_deaths, "heavy": heavy, "hero_hit": hero_hit, "breaks": breaks, "kills": sim.kills, "hero_dmg": int(hero_dmg), "flour_lost": flour_lost,
						"lost": int(sim.stats.deployed) - sim.army_count(1), "deployed": int(sim.stats.deployed), "bakers": int(sim.workers), "bot": bot.stats})
				print("[challenge] ", JSON.stringify({"round": id, "reads": reads, "skill": skill, "level": level, "runs": rows}))
	quit(0)
