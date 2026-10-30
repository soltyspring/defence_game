extends RefCounted
## Scripted player used by headless balance tests and the --autoplay preview. Owner: 02-engine.
## skill: 0 = passive (never acts), 1 = casual, 2 = competent.

var skill := 2
var _think := 0.0
var rng := RandomNumberGenerator.new()

func _init(p_skill := 2, seed_value := 7) -> void:
	skill = p_skill
	rng.seed = seed_value

func act(sim, dt: float) -> void:
	if skill == 0 or sim.ended:
		return
	_think -= dt
	if _think > 0.0:
		return
	_think = 0.25 if skill >= 2 else 0.9
	# economy: early workers
	var want_workers := 5 if skill >= 2 else 3
	if sim.workers < want_workers and sim.gold >= sim.worker_cost() and sim.t > 1.0:
		sim.buy_worker()
	# deploy: rotate through ready cards, favour the frontline when enemies are close
	var ids: Array = sim.card_ids.duplicate()
	if skill >= 2:
		ids.reverse()   # try expensive first, fallback cheap
	for id in ids:
		var d: Dictionary = sim.content.get_unit(id)
		var reserve := 0.0 if sim.workers >= want_workers else float(sim.worker_cost()) * 0.5
		if sim.card_cd[id] <= 0.0 and sim.gold - float(d.cost) >= reserve:
			if sim.deploy(id) == "":
				break
	# hero: advance with the army front, retreat when hurt
	var front: float = sim.player_base.x + 60.0
	for u in sim.players:
		if not u.dying: front = maxf(front, u.x)
	var hurt: bool = sim.hero.hp < sim.hero.hp_max * 0.3
	if hurt:
		sim.set_hero_dir(-1)
	elif sim.hero.x < front - 20.0:
		sim.set_hero_dir(1)
	elif sim.hero.x > front + 30.0:
		sim.set_hero_dir(-1)
	else:
		sim.set_hero_dir(0)
	# skills
	var near := 0
	for e in sim.enemies:
		if not e.dying and absf(e.x - sim.hero.x) < 90.0: near += 1
	for sid in sim.skill_ids:
		var s: Dictionary = sim.content.skills[sid]
		if str(s.kind) == "aoe_damage" and near >= (3 if skill >= 2 else 5):
			sim.cast(sid)
		elif str(s.kind) == "rally" and sim.army_count(1) >= 6:
			sim.cast(sid)
		elif str(s.kind) in ["heal_allies", "meteor", "summon"] and near >= 3:
			sim.cast(sid)
