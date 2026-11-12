extends "res://src/gameplay/bot_player.gd"
## Scripted player for the challenge chapter probes (R31-R40). Same economy/deploy/hero-follow policy as the
## competent bot, plus the three reads the chapter asks for. It is a probe, not a model of a human player.
##   reads = false : the plain competent bot (ignores telegraphs, casts skills on its usual triggers).
##   reads = true  : leaves an announced zone (slam, charge path, lobbed zone), cuts link sources / pries shells /
##                   interrupts swelling sacs with the slam, walks back to a surfacing burrower, keeps the barrage
##                   and the rally for an exposed boss (or an exposed group when there is no boss).
var reads := true
## The hero leaves a zone only when the walk out would otherwise come too late (+ this margin, s), and so keeps
## fighting through most of the announcement. 99 = leave as soon as the zone is announced (the earlier policy).
var dodge_margin := 0.35
## false = only the movement reads (leave zones, meet burrowers); skills stay on the plain bot's triggers.
var targeted_skills := true
var stats := {"dodges": 0, "cuts": 0, "punishes": 0, "pries": 0, "returns": 0}
var _was_in_zone := false
var _was_raided := false

func act(sim, dt: float) -> void:
	if not reads:
		super.act(sim, dt)
		return
	var think_now: bool = _think - dt <= 0.0
	var mana: float = sim.mana
	if targeted_skills: sim.mana = 0.0     # the base policy may not spend mana: skills are decided below
	super.act(sim, dt)
	if targeted_skills: sim.mana = mana
	if sim.ended or sim.hero_respawn > 0.0:
		return
	var hero = sim.hero
	# 1. an announced zone that covers the hero: walk out (every step, not only on think ticks)
	var in_zone := false
	var spd: float = maxf(1.0, float(hero.def.speed) * hero.buff_mul)
	for e in sim.enemies:
		if e.dying or e.heavy_t < 0.0: continue
		if e.heavy_r > 0.0 and absf(hero.x - e.heavy_x) <= e.heavy_r + 8.0:
			if e.heavy_t > (hero.x - (e.heavy_x - e.heavy_r - 8.0)) / spd + dodge_margin: continue    # still time to fight
			var shielded := false       # a charge stops at the first unit on its path: no need to move behind one
			if str(e.ab.get("kind", "")) == "charge":
				for u in sim.players:
					if not u.dying and u.x > hero.x + 4.0 and u.x < e.x: shielded = true
			if not shielded: in_zone = true
	for d in sim.delayed:               # zones dropped by units (heavy kind "lob")
		if d.has("side") and int(d.side) == -1 and absf(hero.x - float(d.x)) <= float(d.radius) + 8.0:
			if float(d.at) - sim.t > (hero.x - (float(d.x) - float(d.radius) - 8.0)) / spd + dodge_margin: continue
			in_zone = true
	if in_zone:
		sim.set_hero_dir(-1)
		if not _was_in_zone: stats.dodges += 1
	_was_in_zone = in_zone
	# 1b. a burrower that has announced its exit or already stands behind the army: the hero goes back to meet it
	var army_front: float = sim.player_base.x + 60.0
	for u in sim.players:
		if not u.dying: army_front = maxf(army_front, u.x)
	var raider = null
	for e in sim.enemies:
		if e.dying or str(e.ab.get("kind", "")) != "burrow": continue
		if (e.hidden and e.heavy_t >= 0.0) or (not e.hidden and e.x < army_front - 30.0):
			if raider == null or e.x < raider.x: raider = e
	if raider != null and not in_zone:
		var want: float = raider.x - (float(raider.def.heavy.radius) + 14.0 if raider.heavy_t >= 0.0 else 16.0)
		sim.set_hero_dir(-1 if hero.x > want + 6.0 else (1 if hero.x < want - 6.0 else 0))
		if not _was_raided: stats.returns += 1
	_was_raided = raider != null
	if not think_now or not targeted_skills:
		return
	var boss = null
	var sources_near := 0
	var exposed_near := 0
	var closed_near := 0
	var near := 0
	for e in sim.enemies:
		if e.dying: continue
		if e.is_boss: boss = e
		var d: float = e.x - hero.x
		if d >= -30.0 and d <= 90.0:        # the slam reaches hero.x - 30 .. hero.x + 90
			near += 1
			if e.def.has("link"): sources_near += 1
			if e.exposed_t > 0.0: exposed_near += 1
			# a closed shell (the slam pries it open) or a sac that is swelling (the slam interrupts it)
			if e.shell_mul < 1.0 and e.exposed_t <= 0.0 and not e.is_boss: closed_near += 1
			if e.heavy_t >= 0.0 and float(e.ab.get("interrupt_damage", 0.0)) > 0.0: closed_near += 1
	# 2. cut links with the slam; otherwise slam a crowd or an exposed target
	# while something worth a targeted slam is about to come into reach, it is not spent on a plain crowd
	var keep_slam := false
	for e in sim.enemies:
		if e.dying or e.x - hero.x > 170.0 or e.x < hero.x - 30.0: continue
		if e.def.has("link") or e.shell_mul < 1.0 or float(e.ab.get("interrupt_damage", 0.0)) > 0.0: keep_slam = true
	if sim.skill_cd.has("skill_slam") and (sources_near > 0 or exposed_near > 0 or closed_near > 0 or (near >= 3 and not keep_slam)):
		if sim.cast("skill_slam") == "":
			if sources_near > 0: stats.cuts += 1
			if closed_near > 0: stats.pries += 1
	# 3. barrage + rally: on an exposed boss; without a boss on any exposed group
	# (a full mana bar is never left idle: without a boss the barrage also goes on a plain crowd, like the plain bot's)
	var punish: bool = (boss != null and boss.exposed_t > 0.6 and absf(boss.x - sim._frontmost_enemy_x()) <= 80.0) or (boss == null and (exposed_near >= 2 or near >= 3)) 		or (boss != null and near >= 3 and sim.mana >= sim.mana_max * 0.95)
	if punish:
		if sim.skill_cd.has("skill_barrage") and sim.cast("skill_barrage") == "": stats.punishes += 1
		if sim.skill_cd.has("skill_rally"): sim.cast("skill_rally")
	elif boss == null and sim.skill_cd.has("skill_rally") and sim.army_count(1) >= 6:
		sim.cast("skill_rally")
