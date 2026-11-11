extends SceneTree
## Frost road + nest additions (2026-11-11): unit rules `shell` and `heavy` kinds vent / charge / lob / burrow, the
## frost boss variation, and the rounds that introduce them (r21, r22, r25, r37, r38).
## Run:  godot --headless --path . -s tests/acceptance/test_frost_nest_core.gd
## Design and hand-over: docs/design/FROST_NEST_ENEMIES.md. Scripted results are not human playtests.
const Sim = preload("res://src/gameplay/battle_sim.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const STEP := 1.0 / 60.0
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL frost: ", msg)
func _initialize() -> void: _run.call_deferred()

func arena(c, id: String, hero_x: float):
	var lv := {}
	for u in c.meta.upgrades: lv[u.id] = 5
	var sim = Sim.new()
	sim.setup(c, id, 7, lv)
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	sim.hero.x = hero_x
	return sim

func place(sim, unit_id: String, x: float):
	var u = sim._spawn_enemy(unit_id)
	u.x = x
	return u

func ally(sim, card: String, x: float):
	sim.gold = 999.0
	sim.card_cd[card] = 0.0
	sim.deploy(card)
	var u = sim.players.back()
	u.x = x
	return u

func until(sim, event: String, limit: float) -> Dictionary:
	var t0: float = sim.t
	while sim.t - t0 < limit and not sim.ended:
		sim.step(STEP)
		var found := {}
		for e in sim.events:
			if e[0] == event and found.is_empty(): found = e[1]
		sim.events.clear()
		sim.cues.clear()
		if not found.is_empty(): return found
	return {}

func markers(sim) -> Array:
	var out := []
	for f in sim.fxs:
		if f.alive and f.kind == "telegraph": out.append(f)
	return out

func _data_checks(c) -> void:
	check(c.warnings.is_empty(), "no content warnings: %s" % [c.warnings])
	var solo := {"r21": "e_frostshell", "r22": "e_icerunner"}
	for id in solo:
		var first: Dictionary = c.get_round(id).waves[0]
		check(first.spawns.size() == 1 and str(first.spawns[0].unit) == solo[id] and int(first.spawns[0].count) == 1, "%s opens with one %s alone" % [id, solo[id]])
	var r25: Array = c.round_enemy_roster(c.get_round("r25"))
	check(r25.has("boss_frostguard") and r25.has("e_frostshell") and r25.has("e_icerunner"), "r25 combines both frost enemies under the boss")
	check(c.round_enemy_roster(c.get_round("r37")).has("e_sporesac") and c.round_enemy_roster(c.get_round("r38")).has("e_burrower"), "r37 brings the sac, r38 the burrower")
	for n in range(11, 21):
		for id in c.round_enemy_roster(c.get_round("r%02d" % n)):
			check(not ["e_frostshell", "e_icerunner", "e_sporesac", "e_burrower"].has(id), "orchard r%02d is untouched (%s)" % [n, id])
	for id in ["r21", "r22", "r25"]:
		var old := 0
		for w in c.get_round(id).waves:
			var uses_old := false
			for s in w.spawns:
				if ["e_guard", "e_runner", "e_mortar", "e_spitter", "e_bomber"].has(str(s.unit)): uses_old = true
			if uses_old: old += 1
		check(old <= 1, "%s uses earlier-chapter enemies in at most one wave (%d)" % [id, old])
	for id in ["e_frostshell", "e_icerunner", "e_sporesac", "e_burrower"]:
		var u: Dictionary = c.units[id]
		check(str(u.anim_set) == id and not u.has("visual_tint"), "%s has its own sprite set, not a tinted variant" % id)
	for n in [23, 24, 26, 27, 28, 29, 30]:
		var rd: Dictionary = c.get_round("r%02d" % n)
		var roster: Array = c.round_enemy_roster(rd)
		check(roster.has("e_frostshell") and roster.has("e_icerunner"), "%s uses the frost roster" % rd.id)
		check(not roster.has("e_guard") and not roster.has("e_mortar") and not roster.has("e_runner"), "%s no longer repeats orchard specialists" % rd.id)
		for wave in rd.waves:
			for spawn in wave.spawns:
				if spawn.unit == "e_icerunner" and int(spawn.count) > 1:
					check(float(spawn.interval) >= 2.0, "%s leaves time between successive charges" % rd.id)

func _overlapping_warnings(c) -> void:
	var sim = arena(c, "r37", 80.0)
	var a = place(sim, "e_thrall", 400.0)
	var b = place(sim, "e_thrall", 400.0)
	sim._begin_heavy(a, a.ab, "slam")
	sim._begin_heavy(b, b.ab, "slam")
	sim._fx("telegraph", a.heavy_x, 0.0, a.heavy_t, a.heavy_r, 0, "lob")
	var all := markers(sim)
	check(all.size() == 3 and all[0].warning_track != all[1].warning_track and all[1].warning_track != all[2].warning_track and all[0].warning_track != all[2].warning_track,
		"identical overlapping intervals have three distinct stable rails")
	sim._cancel_heavy(a)
	var rest := markers(sim)
	check(rest.size() == 2 and rest[0].warning_owner == b.uid and rest[1].warning_shape == "lob",
		"cancel removes only its owner's warning; another caster and a released hazard remain")

func _shell_checks(c) -> void:
	var sim = arena(c, "r21", 80.0)
	var sh = place(sim, "e_frostshell", 900.0)
	var closed: float = float(sh.def.shell.closed_mult)
	var hp0: float = sh.hp
	sim._damage(sh, 102.0, 0.0)
	check(is_equal_approx(hp0 - sh.hp, (102.0 - float(sh.def.armor)) * closed), "closed shell: damage x%.2f (%d)" % [closed, int(hp0 - sh.hp)])
	# it opens on its own, with nobody near
	var x0: float = sh.x
	var open := until(sim, "heavy_hit", 8.0)
	check(not open.is_empty() and str(open.kind) == "vent" and sh.exposed_t > 0.0 and markers(sim).is_empty(), "the shell opens by itself and marks no danger zone")
	check(sh.x < x0 - 30.0, "it walked before stopping to open")
	hp0 = sh.hp
	sim._damage(sh, 102.0, 0.0)
	check(is_equal_approx(hp0 - sh.hp, (102.0 - float(sh.def.armor)) * float(sh.def.heavy.exposed_mult)), "open shell: damage x%.1f (%d)" % [float(sh.def.heavy.exposed_mult), int(hp0 - sh.hp)])
	var xs: float = sh.x
	for i in 60: sim.step(STEP)
	check(is_equal_approx(sh.x, xs), "it stands still while open")
	for i in 200: sim.step(STEP)
	check(sh.exposed_t <= 0.0 and sh.x < xs, "then closes and walks on")
	sim.events.clear()
	# a hit with skill-grade knockback forces it open; a siege shot (knockback 10) does not
	sim._damage(sh, 50.0, 10.0)
	check(sh.exposed_t <= 0.0, "knockback 10 does not pry the shell")
	sim._damage(sh, 50.0, 30.0)
	var pried := false
	for e in sim.events:
		if e[0] == "shell_pry": pried = true
	check(pried and sh.exposed_t > 0.0 and sh.recover_t >= float(sh.def.shell.pry_open) - 0.01, "knockback 30 (hero slam) forces it open for %.1f s" % float(sh.def.shell.pry_open))

func _charge_checks(c) -> void:
	# a) ignored: the hero stands on the path with nobody in front
	var sim = arena(c, "r22", 360.0)
	var ch = place(sim, "e_icerunner", 500.0)
	ch.heavy_cd = 0.0
	var tele := until(sim, "heavy", 2.0)
	check(str(tele.get("kind", "")) == "charge" and markers(sim).size() == 1, "the charger marks its path (%s)" % [tele])
	var lo: float = ch.heavy_x - ch.heavy_r
	var hi: float = ch.heavy_x + ch.heavy_r
	check(is_equal_approx(hi, ch.x) and is_equal_approx(hi - lo, float(ch.def.heavy.dist)) and is_equal_approx(markers(sim)[0].x, ch.heavy_x) and is_equal_approx(markers(sim)[0].radius, ch.heavy_r),
		"marker = the path from the charger to %d px ahead" % int(ch.def.heavy.dist))
	var hp0: float = sim.hero.hp
	var hit := until(sim, "heavy_hit", 3.0)
	check(not hit.is_empty() and hp0 - sim.hero.hp >= 40.0 and absf(ch.x - sim.hero.x) < 40.0, "ignored: it rams the hero for %d" % int(hp0 - sim.hero.hp))
	check(float(hit.x) >= lo - 0.5 and float(hit.x) <= hi + 0.5, "the hit lands inside the announced path")
	# b) a cheap front unit on the path takes it; the hero behind is untouched
	var sim2 = arena(c, "r22", 360.0)
	var ch2 = place(sim2, "e_icerunner", 500.0)
	var toast = ally(sim2, "melee_basic", 420.0)
	toast.atk = 0.0
	ch2.heavy_cd = 0.0
	until(sim2, "heavy", 2.0)
	var hero_hp: float = sim2.hero.hp
	var toast_hp: float = toast.hp
	until(sim2, "heavy_hit", 3.0)
	check(toast.hp < toast_hp - 40.0 and is_equal_approx(sim2.hero.hp, hero_hp) and ch2.x > 400.0, "a front unit absorbs the charge (%d), the hero behind takes nothing" % int(toast_hp - toast.hp))
	# c) the hero walks off the path: the charger runs to the end of it and is left open
	var sim3 = arena(c, "r22", 360.0)
	var ch3 = place(sim3, "e_icerunner", 500.0)
	ch3.heavy_cd = 0.0
	until(sim3, "heavy", 2.0)
	var end_x: float = ch3.heavy_x - ch3.heavy_r
	sim3.set_hero_dir(-1)
	hero_hp = sim3.hero.hp
	until(sim3, "heavy_hit", 3.0)
	check(is_equal_approx(sim3.hero.hp, hero_hp) and sim3.hero.x < end_x and absf(ch3.x - end_x) < 1.0, "off the path: no damage, the charger stops at the end of its marker")
	check(ch3.recover_t > 0.0 and ch3.exposed_t > 0.0, "and recovers there, exposed")
	sim3.set_hero_dir(0)
	hero_hp = sim3.hero.hp
	for i in int(float(ch3.def.heavy.recover) / STEP) - 6: sim3.step(STEP)
	check(is_equal_approx(sim3.hero.hp, hero_hp), "no attack while it recovers (no lock on the player either: the hero moved freely)")
	# d) pause freezes the countdown; death removes the marker
	var sim4 = arena(c, "r22", 360.0)
	var ch4 = place(sim4, "e_icerunner", 500.0)
	ch4.heavy_cd = 0.0
	until(sim4, "heavy", 2.0)
	var left: float = ch4.heavy_t
	var fx_t: float = markers(sim4)[0].t
	sim4.paused = true
	for i in 120: sim4.step(STEP)
	check(is_equal_approx(ch4.heavy_t, left) and is_equal_approx(markers(sim4)[0].t, fx_t), "pause freezes both the wind-up and its marker")
	sim4.paused = false
	sim4._damage(ch4, 1e6, 0.0)
	check(markers(sim4).is_empty() and until(sim4, "heavy_hit", 2.0).is_empty(), "a charger killed during the wind-up leaves no marker and no hit")

func _lob_checks(c) -> void:
	# ignored: the hero stays on the marked ground
	var sim = arena(c, "r37", 400.0)
	var sac = place(sim, "e_sporesac", 500.0)
	sac.heavy_cd = 0.0
	var tele := until(sim, "heavy", 2.0)
	check(str(tele.get("kind", "")) == "lob" and markers(sim).is_empty(), "the sac swells first (no ground zone yet)")
	var thrown := until(sim, "heavy_hit", 3.0)
	check(not thrown.is_empty() and markers(sim).size() == 1 and sim.delayed.size() == 1, "then drops one marked zone")
	var zone: Dictionary = sim.delayed[0]
	check(is_equal_approx(markers(sim)[0].x, float(zone.x)) and is_equal_approx(markers(sim)[0].radius, float(zone.radius)) and absf(float(zone.x) - sim.hero.x) < 1.0, "marker and burst share one position: where the target stood")
	var hp0: float = sim.hero.hp
	for i in int(float(sac.def.heavy.delay) / STEP) + 4: sim.step(STEP)
	var loss: float = hp0 - sim.hero.hp
	check(loss >= 40.0 and sim.delayed.is_empty(), "ignored: the burst costs the hero %d" % int(loss))
	# moved away and waited
	var sim2 = arena(c, "r37", 400.0)
	var sac2 = place(sim2, "e_sporesac", 500.0)
	sac2.atk = 0.0
	sac2.heavy_cd = 0.0
	until(sim2, "heavy_hit", 4.0)
	sim2.set_hero_dir(-1)
	hp0 = sim2.hero.hp
	for i in int(float(sac2.def.heavy.delay) / STEP) + 4: sim2.step(STEP)
	check(is_equal_approx(sim2.hero.hp, hp0), "stepping off the marked ground avoids it")
	# cut it short: enough damage while it swells
	var sim3 = arena(c, "r37", 400.0)
	var sac3 = place(sim3, "e_sporesac", 500.0)
	sac3.heavy_cd = 0.0
	until(sim3, "heavy", 2.0)
	sim3._damage(sac3, float(sac3.def.heavy.interrupt_damage) + 1.0, 0.0)
	var cancelled := false
	for e in sim3.events:
		if e[0] == "heavy_cancel": cancelled = true
	sim3.events.clear()
	check(cancelled and sac3.heavy_t < 0.0 and sac3.exposed_t > 0.0, "%d damage during the swell cancels the throw and leaves it open" % int(sac3.def.heavy.interrupt_damage))
	check(until(sim3, "heavy_hit", 2.0).is_empty() and sim3.delayed.is_empty(), "no zone is dropped after the interrupt")

func _burrow_checks(c) -> void:
	var sim = arena(c, "r38", 300.0)
	var front = ally(sim, "tank", 420.0)
	var back = ally(sim, "ranged_basic", 370.0)
	front.atk = 0.0
	back.atk = 0.0
	var bw = place(sim, "e_burrower", 600.0)
	var dive := until(sim, "burrow", 3.0)
	check(not dive.is_empty() and bw.hidden, "the burrower goes under before it reaches the front")
	sim._sort_lanes()
	check(sim._find_target(front) == null and sim._find_target(sim.hero) == null, "nothing can target it while it is under")
	var hp0: float = bw.hp
	sim._area_damage(bw.x, 30.0, 40.0, 0.0, 1.0)
	check(bw.hp < hp0, "area damage (skills) still reaches it")
	var tele := until(sim, "heavy", 8.0)
	check(str(tele.get("kind", "")) == "burrow" and bw.hidden and markers(sim).size() == 1, "it announces where it will come up while still under")
	check(bw.x < front.x - 30.0 and is_equal_approx(markers(sim)[0].x, bw.x) and is_equal_approx(markers(sim)[0].radius, float(bw.def.heavy.radius)), "the marker sits behind the front line, on the burrower")
	var back_hp: float = back.hp
	var front_hp: float = front.hp
	var up := until(sim, "heavy_hit", 3.0)
	var back_in: bool = absf(back.x - float(up.x)) <= float(bw.def.heavy.radius)
	check(not up.is_empty() and not bw.hidden and is_equal_approx(front.hp, front_hp) and (back.hp < back_hp) == back_in, "it surfaces and hits only what stands in the marker (back line hit: %s)" % back_in)
	check(bw.exposed_t > 0.0, "and is exposed right after")
	# answers that need no special card: a fresh unit from the keep meets it, and the hero can walk back to it
	var fresh = ally(sim, "melee_basic", sim.player_base.x + 30.0)
	sim._sort_lanes()
	check(sim._find_target(fresh) == bw, "a newly sent unit targets the surfaced burrower")
	sim.hero.x = bw.x - 20.0
	check(sim._find_target(sim.hero) == bw, "the hero can fight it after walking back")
	check(sim._find_target(front) != bw, "the old front line does not turn around for it")

func _boss_checks(c) -> void:
	var sim = arena(c, "r25", 500.0)
	var boss = place(sim, "boss_frostguard", 640.0)
	var tank = ally(sim, "tank", 560.0)
	tank.hp = 1e6
	tank.atk = 0.0
	sim.hero.hp = 1e6
	var hp0: float = boss.hp
	sim._damage(boss, 107.0, 30.0)
	check(is_equal_approx(hp0 - boss.hp, (107.0 - float(boss.def.armor)) * float(boss.def.shell.closed_mult)) and boss.exposed_t <= 0.0, "boss shell: damage x%.1f, and knockback cannot pry it" % float(boss.def.shell.closed_mult))
	boss.heavy_cd = 0.0
	var kinds := []
	var overlap := false
	var opened := 0
	var t_end: float = sim.t + 70.0
	while sim.t < t_end and kinds.size() < 4:
		sim.step(STEP)
		for e in sim.events:
			if e[0] == "heavy": kinds.append(str(e[1].kind))
			if e[0] == "heavy_hit" and boss.exposed_t > 0.0: opened += 1
		sim.events.clear()
		sim.cues.clear()
		if markers(sim).size() > 1: overlap = true
	check(kinds.size() >= 4 and kinds[0] == "charge" and kinds[1] == "slam" and kinds[2] == "charge" and kinds[3] == "slam", "the boss alternates charge and frost slam (%s)" % [kinds])
	check(not overlap, "never two announced boss zones at once")
	check(opened >= 3, "its shell opens after each of them (%d openings)" % opened)

func _edge_checks(c) -> void:
	# a full effects pool must not swallow a danger marker
	var sim = arena(c, "r31", 380.0)
	for i in int(sim.caps.fx) + 8: sim._fx("hit_spark", 100.0 + i, 0.0, 5.0, 0.0)
	var th = place(sim, "e_thrall", 400.0)
	th.heavy_cd = 0.0
	until(sim, "heavy", 3.0)
	check(markers(sim).size() == 1, "with the effects pool full the marker still appears")
	# maximum crowd: every wind-up of 12 thralls gets its own marker, none is lost, none outlives its owner
	var sim2 = arena(c, "r31", 380.0)
	var pack := []
	for i in 12:
		var e = place(sim2, "e_thrall", 396.0 + i * 0.5)
		e.heavy_cd = 0.0
		pack.append(e)
	sim2.hero.hp = 1e6
	for i in 30: sim2.step(STEP)
	var announcing := 0
	for e in pack:
		if e.heavy_t >= 0.0: announcing += 1
	check(announcing == 12 and markers(sim2).size() == 12, "12 simultaneous wind-ups show 12 markers (%d / %d)" % [announcing, markers(sim2).size()])
	for e in pack: sim2._damage(e, 1e6, 0.0)
	check(markers(sim2).is_empty(), "all markers go when their owners die")
	# a wave arriving during a wind-up changes nothing about it
	var sim3 = arena(c, "r31", 380.0)
	var t3 = place(sim3, "e_thrall", 400.0)
	t3.heavy_cd = 0.0
	until(sim3, "heavy", 3.0)
	var zx: float = t3.heavy_x
	sim3._queue_spawns([{"unit": "e_thrall", "count": 3, "interval": 0.1}], sim3.t)
	var hit := until(sim3, "heavy_hit", 3.0)
	check(not hit.is_empty() and is_equal_approx(float(hit.x), zx), "new spawns during a wind-up do not move or cancel it")

## First ten minutes: a defeat names the one habit in that battle's own record worth changing.
func _hint_checks(c) -> void:
	var idle = Sim.new()
	idle.setup(c, "r01", 3, {})
	while not idle.ended: idle.step(STEP)
	check(not idle.won and str(idle.result().hint) == "no_units", "r01 lost without sending anyone -> hint no_units (%s)" % idle.result().hint)
	var hoard = Sim.new()
	hoard.setup(c, "r02", 3, {})
	hoard.deploy("melee_basic")
	while not hoard.ended: hoard.step(STEP)
	check(not hoard.won and str(hoard.result().hint) == "flour_idle", "r02 lost with flour sitting at its cap -> hint flour_idle (%s, %.0f s capped)" % [hoard.result().hint, float(hoard.stats.gold_capped_s)])
	var sim = Sim.new()
	sim.setup(c, "r03", 3, {})
	sim.stats.deployed = 9
	sim.t = 60.0
	check(sim.loss_hint() == "no_baker", "units sent, flour used, no baker hired -> no_baker (%s)" % sim.loss_hint())
	sim.stats.workers_bought = 2
	sim.hero_deaths = 2
	check(sim.loss_hint() == "hero_fell", "hero fell twice -> hero_fell (%s)" % sim.loss_hint())
	sim.hero_deaths = 0
	check(sim.loss_hint() == "no_skill", "a skill was available and never cast -> no_skill (%s)" % sim.loss_hint())
	sim.stats.skills_cast = 3
	check(sim.loss_hint() == "upgrade", "nothing basic left to change -> upgrade (%s)" % sim.loss_hint())
	var won = Sim.new()
	won.setup(c, "r01", 3, {})
	won._damage_base(-1, 1e9)
	check(won.won and str(won.result().hint) == "", "a win carries no hint")
	for id in ["no_units", "flour_idle", "no_baker", "hero_fell", "no_skill", "upgrade"]:
		check(UiText.has("hint.loss." + id), "text for hint.loss.%s exists" % id)
	var panel = load("res://scenes/ui/result.tscn").instantiate()
	root.add_child(panel)
	panel.ui_setup({"result": {"round_id": "r02", "won": false, "stars": 0, "time": 150.0, "kills": 4, "coins": 3, "hint": "flour_idle", "saved": true}})
	for i in 4: await process_frame
	check(panel.loss_hint_shown == "flour_idle", "the defeat panel draws the hint line (%s)" % panel.loss_hint_shown)
	panel.queue_free()
	await process_frame

func _run() -> void:
	var c = root.get_node("Content")
	_data_checks(c)
	_overlapping_warnings(c)
	_shell_checks(c)
	_charge_checks(c)
	_lob_checks(c)
	_burrow_checks(c)
	_boss_checks(c)
	_edge_checks(c)
	await _hint_checks(c)
	print("[frost] checks=", checks, " failures=", failures)
	root.get_node("Audio").prepare_quit()
	await create_timer(0.3, true, false, true).timeout
	quit(0 if failures == 0 else 1)
