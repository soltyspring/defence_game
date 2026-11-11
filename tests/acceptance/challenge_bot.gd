extends "res://src/gameplay/bot_player.gd"
## Scripted player for the challenge chapter probes (R31-R40). Same economy/deploy/hero-follow policy as the
## competent bot, plus the three reads the chapter asks for. It is a probe, not a model of a human player.
##   reads = false : the plain competent bot (ignores telegraphs, casts skills on its usual triggers).
##   reads = true  : leaves an announced zone, cuts link sources with the slam, keeps the barrage and the rally for
##                   an exposed boss (or a linked group when there is no boss).
var reads := true
var stats := {"dodges": 0, "cuts": 0, "punishes": 0}
var _was_in_zone := false

func act(sim, dt: float) -> void:
	if not reads:
		super.act(sim, dt)
		return
	var think_now: bool = _think - dt <= 0.0
	var mana: float = sim.mana
	sim.mana = 0.0            # the base policy may not spend mana: skills are decided below
	super.act(sim, dt)
	sim.mana = mana
	if sim.ended or sim.hero_respawn > 0.0:
		return
	var hero = sim.hero
	# 1. an announced zone that covers the hero: walk out (every step, not only on think ticks)
	var in_zone := false
	for e in sim.enemies:
		if e.dying or e.heavy_t < 0.0: continue
		if absf(hero.x - e.heavy_x) <= float(e.def.heavy.get("radius", 40.0)) + 8.0:
			in_zone = true
	if in_zone:
		sim.set_hero_dir(-1)
		if not _was_in_zone: stats.dodges += 1
	_was_in_zone = in_zone
	if not think_now:
		return
	var boss = null
	var sources_near := 0
	var exposed_near := 0
	var near := 0
	for e in sim.enemies:
		if e.dying: continue
		if e.is_boss: boss = e
		var d: float = e.x - hero.x
		if d >= -30.0 and d <= 90.0:        # the slam reaches hero.x - 30 .. hero.x + 90
			near += 1
			if e.def.has("link"): sources_near += 1
			if e.exposed_t > 0.0: exposed_near += 1
	# 2. cut links with the slam; otherwise slam a crowd or an exposed target
	if sim.skill_cd.has("skill_slam") and (sources_near > 0 or exposed_near > 0 or near >= 3):
		if sim.cast("skill_slam") == "" and sources_near > 0: stats.cuts += 1
	# 3. barrage + rally: on an exposed boss; without a boss on any exposed group
	var punish: bool = (boss != null and boss.exposed_t > 0.6 and absf(boss.x - sim._frontmost_enemy_x()) <= 80.0) or (boss == null and exposed_near >= 2)
	if punish:
		if sim.skill_cd.has("skill_barrage") and sim.cast("skill_barrage") == "": stats.punishes += 1
		if sim.skill_cd.has("skill_rally"): sim.cast("skill_rally")
	elif boss == null and sim.skill_cd.has("skill_rally") and sim.army_count(1) >= 6:
		sim.cast("skill_rally")
