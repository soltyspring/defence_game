extends RefCounted
## Scripted player used by headless balance tests and the --autoplay preview. Owner: 02-engine.
## skill: 0 = passive (never acts), 1 = casual, 2 = competent.
## 2026-11-01 (01 R10/R11 bot stall, src/core/diag/bot_stall_probe.gd): two policy defects fixed.
##  1. Worker reserve trap (competent): deploys kept only HALF of the next worker's cost, so gold rarely reached the
##     full cost and the bot stayed at 2-3 workers (it wants 5) while idling the reserve. Now it saves the full cost,
##     except while enemies are near its own base. The worker target is capped at the round's workers_max (r01: 4).
##  2. Hero lock (both): a hero below 30 % HP walked home and stayed there for the rest of the round (heroes do not
##     regenerate). Now a hurt hero holds 60 px behind the army front (inside its 80 px aura) instead.
## The old behaviour is still available through the knobs below (probes set them for before/after comparisons).

var skill := 2
var _think := 0.0
var rng := RandomNumberGenerator.new()
## Policy knobs (probes may override them after construction; defaults are the shipped policy for `skill`).
var expensive_first := true   # competent tries cards most-expensive first (casual: cheapest first)
var want_workers := 5         # workers bought before deploys stop holding a reserve (casual 3)
var reserve_ratio := 1.0      # deploys keep gold >= worker_cost * ratio while workers < want (old competent: 0.5)
var threat_px := 350.0        # no reserve while an enemy is within this distance of the player base (0 = never; old)
var cap_want_by_max := true   # stop wanting workers at the round's workers_max (old: false)
var hurt_hold_behind := 60.0  # hurt hero holds this far behind the front (0 = walk home and stay; old)

func _init(p_skill := 2, seed_value := 7) -> void:
	skill = p_skill
	rng.seed = seed_value
	expensive_first = skill >= 2
	want_workers = 5 if skill >= 2 else 3
	if skill < 2:
		reserve_ratio = 0.5   # the casual player keeps the looser economy (it reaches its 3 workers by ~30 s)
		threat_px = 0.0

## The behaviour before 2026-11-01, for comparisons.
func use_legacy_policy() -> void:
	reserve_ratio = 0.5
	threat_px = 0.0
	cap_want_by_max = false
	hurt_hold_behind = 0.0

func act(sim, dt: float) -> void:
	if skill == 0 or sim.ended:
		return
	_think -= dt
	if _think > 0.0:
		return
	_think = 0.25 if skill >= 2 else 0.9
	var want := mini(want_workers, int(sim.workers_max)) if cap_want_by_max else want_workers
	# economy: early workers
	if sim.workers < want and sim.gold >= sim.worker_cost() and sim.t > 1.0:
		sim.buy_worker()
	var threat := false
	if threat_px > 0.0:
		for e in sim.enemies:
			if not e.dying and e.x - sim.player_base.x <= threat_px:
				threat = true
				break
	var reserve := 0.0 if sim.workers >= want or threat else float(sim.worker_cost()) * reserve_ratio
	# deploy: rotate through ready cards, favour the frontline when enemies are close
	var ids: Array = sim.card_ids.duplicate()
	if expensive_first:
		ids.reverse()   # try expensive first, fallback cheap
	for id in ids:
		var d: Dictionary = sim.content.get_unit(id)
		if sim.card_cd[id] <= 0.0 and sim.gold - float(d.cost) >= reserve:
			if sim.deploy(id) == "":
				break
	# hero: advance with the army front; when hurt, stay behind it
	var front: float = sim.player_base.x + 60.0
	for u in sim.players:
		if not u.dying: front = maxf(front, u.x)
	var hurt: bool = sim.hero.hp < sim.hero.hp_max * 0.3
	if hurt and hurt_hold_behind <= 0.0:
		sim.set_hero_dir(-1)
	elif hurt:
		var spot := maxf(sim.player_base.x + 20.0, front - hurt_hold_behind)
		if sim.hero.x > spot + 10.0:
			sim.set_hero_dir(-1)
		elif sim.hero.x < spot - 10.0:
			sim.set_hero_dir(1)
		else:
			sim.set_hero_dir(0)
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
