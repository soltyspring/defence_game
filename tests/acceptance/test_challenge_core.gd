extends SceneTree
## Challenge chapter (R31-R40) core: data rules `heavy` / `link` / `hold_behind`, the three representative rounds,
## the closed-until-complete gate, save compatibility and the dev-only path.
## Run:  godot --headless --path . -s tests/acceptance/test_challenge_core.gd
## Design: docs/design/CHALLENGE_R31_R40.md. Bot/scripted results are not human playtests.
const Sim = preload("res://src/gameplay/battle_sim.gd")
const STEP := 1.0 / 60.0
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL challenge: ", msg)
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame

## A quiet lane of round `id`: no scheduled spawns, max upgrades, hero parked at `hero_x`.
func arena(c, id: String, hero_x: float):
	var lv := {}
	for u in c.meta.upgrades: lv[u.id] = int(u.max_level)
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

## Steps until `event` shows up (or `limit` s pass); returns the event data or {}. Events/cues are drained.
func until(sim, event: String, limit: float) -> Dictionary:
	var t0: float = sim.t
	while sim.t - t0 < limit and not sim.ended:
		sim.step(STEP)
		var found := {}
		for e in sim.events:
			if e[0] == event: found = e[1]
		sim.events.clear()
		sim.cues.clear()
		if not found.is_empty(): return found
	return {}

func _data_checks(c) -> void:
	check(c.round_order.size() == 40 and c.warnings.is_empty(), "player order includes all forty rounds without warnings: %s" % [c.warnings])
	var locale_ko: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/text/ko.json"))
	var locale_en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/text/en.json"))
	for n in range(31, 41):
		var id := "r%02d" % n
		var rd: Dictionary = c.get_round(id)
		check(c.round_order[n - 1] == id and c.is_challenge(id) and not c.is_dev_round(id) and int(rd.index) == n,
			"%s is playable and in order" % id)
		check(locale_ko.strings.has("round.%s.name" % id) and locale_en.strings.has("round.%s.name" % id), "%s has both localized titles" % id)
		if n < 40: check(c.next_round_id(id) == "r%02d" % (n + 1), "%s has the correct next round" % id)
	check(c.challenge_enabled and c.next_round_id("r40") == "", "chapter is open and r40 ends it")
	check(c.next_round_id("r30") == "", "r30 is still the last round of the campaign")
	var ruled := []
	for id in c.units:
		var u: Dictionary = c.units[id]
		if u.has("heavy") or u.has("link") or u.has("hold_behind"): ruled.append(id)
	ruled.sort()
	check(ruled == ["boss_nestcore", "e_binder", "e_thrall"], "only the three chapter-4 units use the new rules (%s)" % [ruled])
	for n in range(1, 31):
		for id in c.round_enemy_roster(c.get_round("r%02d" % n)):
			check(not ruled.has(id), "r%02d does not use a chapter-4 unit (%s)" % [n, id])
	var first: Dictionary = c.get_round("r31")
	var solo := true
	for w in first.waves:
		for s in w.spawns:
			if str(s.unit) != "e_thrall": solo = false
	check(solo and float(first.waves[0].at) >= 10.0 and int(first.waves[0].spawns[0].count) == 1, "r31 shows the new enemy alone, one at first")
	check(c.round_enemy_roster(c.get_round("r35")).has("e_binder") and c.round_enemy_roster(c.get_round("r35")).has("e_thrall"), "r35 pairs thrall and knot")
	check(c.round_enemy_roster(c.get_round("r40")).has("boss_nestcore") and bool(c.get_round("r40").get("boss_round", false)), "r40 is the core boss round")
	for id in ["r31", "r35", "r40"]:
		var sc: Dictionary = c.get_round(id).enemy_scaling
		var ref: Dictionary = c.get_round("r30").enemy_scaling
		check(is_equal_approx(float(sc.hp), float(ref.hp)) and is_equal_approx(float(sc.atk), float(ref.atk)), "%s keeps the r30 stat scaling" % id)

func _heavy_checks(c) -> void:
	# ignored: the hero stands in the announced zone
	var sim = arena(c, "r31", 380.0)
	var th = place(sim, "e_thrall", 400.0)
	th.heavy_cd = 0.0
	var tele := until(sim, "heavy", 3.0)
	check(not tele.is_empty() and is_equal_approx(float(tele.windup), float(th.def.heavy.windup)), "the thrall announces its slam (%s)" % [tele])
	var zone: float = float(th.def.heavy.radius)
	check(absf(sim.hero.x - th.heavy_x) <= zone, "the hero starts inside the announced zone")
	var telegraphs := 0
	for f in sim.fxs:
		if f.alive and f.kind == "telegraph": telegraphs += 1
	check(telegraphs == 1, "one zone marker is on the ground during the wind-up")
	var hp0: float = sim.hero.hp
	var hit := until(sim, "heavy_hit", 3.0)
	var ignored_loss: float = hp0 - sim.hero.hp
	check(not hit.is_empty() and ignored_loss >= 100.0, "ignoring the telegraph costs the hero %d hp" % int(ignored_loss))
	# read: the hero walks out during the wind-up
	var sim2 = arena(c, "r31", 380.0)
	var th2 = place(sim2, "e_thrall", 400.0)
	th2.heavy_cd = 0.0
	until(sim2, "heavy", 3.0)
	sim2.set_hero_dir(-1)
	var hp1: float = sim2.hero.hp
	var hit2 := until(sim2, "heavy_hit", 3.0)
	check(not hit2.is_empty() and absf(sim2.hero.x - th2.heavy_x) > zone, "the hero has left the zone when the slam lands")
	check(is_equal_approx(sim2.hero.hp, hp1), "stepping out avoids the slam completely (lost %d hp)" % int(hp1 - sim2.hero.hp))
	# the opening: recovering = no attack, no move, more damage taken
	check(th2.recover_t > 0.0 and th2.exposed_t > 0.0, "the thrall recovers after the slam")
	var x_before: float = th2.x
	var thp: float = th2.hp
	sim2._damage(th2, 100.0, 0.0)
	var expect: float = (100.0 - float(th2.def.armor)) * float(th2.def.heavy.exposed_mult)
	check(is_equal_approx(thp - th2.hp, expect), "damage on a recovering thrall is x%.1f (%d vs %d)" % [float(th2.def.heavy.exposed_mult), int(thp - th2.hp), int(expect)])
	sim2.set_hero_dir(0)
	var hp2: float = sim2.hero.hp
	for i in int(float(th2.def.heavy.recover) / STEP) - 6: sim2.step(STEP)
	check(is_equal_approx(th2.x, x_before) and is_equal_approx(sim2.hero.hp, hp2), "a recovering thrall neither walks nor attacks")
	for i in 240: sim2.step(STEP)
	check(th2.exposed_t <= 0.0 and is_equal_approx(th2.exposed_mul, 1.0), "the opening closes again")
	# a unit that dies while announcing takes its marker with it
	var sim3 = arena(c, "r31", 380.0)
	var th3 = place(sim3, "e_thrall", 400.0)
	th3.heavy_cd = 0.0
	until(sim3, "heavy", 3.0)
	sim3._damage(th3, 1e6, 0.0)
	var left := 0
	for f in sim3.fxs:
		if f.alive and f.kind == "telegraph": left += 1
	check(left == 0 and until(sim3, "heavy_hit", 3.0).is_empty(), "killing it during the wind-up removes the marker and the slam")

func _link_checks(c) -> void:
	var sim = arena(c, "r35", 70.0)
	var th = place(sim, "e_thrall", 500.0)
	var kn = place(sim, "e_binder", 540.0)
	sim.step(STEP)
	check(th.link_src == kn.uid and is_equal_approx(th.guard_mul, float(kn.def.link.damage_taken)), "the knot protects the thrall in front of it")
	var hp0: float = th.hp
	sim._damage(th, 100.0, 0.0)
	check(is_equal_approx(hp0 - th.hp, (100.0 - float(th.def.armor)) * float(kn.def.link.damage_taken)), "linked damage is x%.2f (%d)" % [float(kn.def.link.damage_taken), int(hp0 - th.hp)])
	# cutting the link during a wind-up calls the slam off and exposes the thrall
	sim.hero.x = 485.0
	th.heavy_cd = 0.0
	check(not until(sim, "heavy", 3.0).is_empty(), "linked thrall announces a slam")
	sim._damage(kn, 1e6, 0.0)
	var cut := {}
	for e in sim.events:
		if e[0] == "link_break": cut = e[1]
	sim.events.clear()
	check(int(cut.get("freed", 0)) == 1 and th.link_src == 0 and is_equal_approx(th.guard_mul, 1.0), "killing the knot frees the thrall (%s)" % [cut])
	check(th.heavy_t < 0.0 and th.exposed_t > 0.0 and th.exposed_mul >= float(kn.def.link.break_exposed), "the cut cancels the announced slam and exposes it")
	var hp1: float = sim.hero.hp
	check(until(sim, "heavy_hit", 1.0).is_empty() and sim.hero.hp >= hp1 - 1.0, "no slam lands after the cut")
	# hold_behind: a knot that is ahead of its front waits, then follows at a distance
	var sim2 = arena(c, "r35", 70.0)
	var front = place(sim2, "e_thrall", 620.0)
	var knot = place(sim2, "e_binder", 540.0)
	var knot_x: float = knot.x
	for i in 120: sim2.step(STEP)
	check(is_equal_approx(knot.x, knot_x) and front.x < 620.0 - 40.0, "a knot ahead of the front waits for it")
	for i in 600: sim2.step(STEP)
	var gap: float = knot.x - front.x
	check(gap >= float(knot.def.hold_behind) - 2.0 and knot.x < knot_x, "then follows %d px behind (hold_behind %d)" % [int(gap), int(knot.def.hold_behind)])
	# with nobody in front it walks on like any other unit
	var sim3 = arena(c, "r35", 70.0)
	var alone = place(sim3, "e_binder", 600.0)
	for i in 120: sim3.step(STEP)
	check(alone.x < 600.0 - 40.0, "a knot without a front advances")

## Same pack (2 thralls + knot against a fixed mixed army), two plans: fight through, or cut the knot first.
func _plan(c, cut: bool) -> Dictionary:
	var sim = arena(c, "r35", 545.0)
	var a = place(sim, "e_thrall", 600.0)
	var b = place(sim, "e_thrall", 612.0)
	var kn = place(sim, "e_binder", 650.0)
	for id in ["tank", "tank", "melee_basic", "melee_basic", "melee_basic", "ranged_basic", "ranged_basic", "siege"]:
		sim.gold = 999.0
		sim.card_cd[id] = 0.0
		sim.deploy(id)
		sim.players.back().x = 560.0 - 8.0 * sim.players.size()
	sim.mana = sim.mana_max
	sim.set_hero_dir(1)                     # the hero walks up to the front in both plans
	var knot_dead_at := -1.0
	while sim.t < 120.0 and not (a.dying and b.dying):
		sim.gold = 0.0                      # no reinforcements: the plan is the only difference
		if cut and not kn.dying and kn.x - sim.hero.x <= 88.0 and kn.x - sim.hero.x >= -28.0:
			sim.cast("skill_slam")
		sim.step(STEP)
		if kn.dying and knot_dead_at < 0.0: knot_dead_at = sim.t
		sim.events.clear()
		sim.cues.clear()
	var alive := 0
	for u in sim.players:
		if not u.dying: alive += 1
	return {"cleared": a.dying and b.dying, "t": snappedf(sim.t, 0.1), "knot_dead_at": snappedf(knot_dead_at, 0.1), "army_left": alive, "hero_hp": int(sim.hero.hp)}

func _boss_checks(c) -> void:
	var sim = arena(c, "r40", 640.0)
	var boss = place(sim, "boss_nestcore", 700.0)
	boss.summon_t = float(boss.def.summon.interval) - 0.05
	for i in 12: sim.step(STEP)
	var knot = null
	for e in sim.enemies:
		if e.id == "e_binder": knot = e
	check(knot != null and boss.link_src == knot.uid, "the core calls a knot and is the first thing it protects")
	check(bool(sim.snapshot().boss.linked), "HUD snapshot reports the boss as linked")
	boss.heavy_cd = 0.0
	var tele := until(sim, "heavy", 4.0)
	check(not tele.is_empty() and bool(tele.boss) and float(tele.windup) >= 1.8, "the boss slam is announced for %.1f s" % float(tele.get("windup", 0.0)))
	check(bool(sim.snapshot().boss.telegraph), "HUD snapshot reports the wind-up")
	var hit := until(sim, "heavy_hit", 4.0)
	check(not hit.is_empty() and float(hit.recover) >= 3.0 and bool(sim.snapshot().boss.exposed), "and followed by a %.1f s opening" % float(hit.get("recover", 0.0)))
	var hp0: float = boss.hp
	sim._damage(boss, 107.0, 0.0)
	var linked_open: float = hp0 - boss.hp
	sim._damage(knot, 1e6, 0.0)
	hp0 = boss.hp
	sim._damage(boss, 107.0, 0.0)
	check(hp0 - boss.hp > linked_open * 1.9, "an opening without the knot is worth more than one with it (%d vs %d per 100 after armour)" % [int(hp0 - boss.hp), int(linked_open)])

func _save_checks(c, save) -> void:
	var real_path: String = save.path
	var real_progress: Dictionary = save.progress
	var dir := "user://challenge-test"
	DirAccess.make_dir_recursive_absolute(dir + "/data")
	_copy_tree("res://data", dir + "/data")
	var order_path := dir + "/data/rounds/order.json"
	var order := FileAccess.get_file_as_string("res://data/rounds/order.json")
	var fo := FileAccess.open(order_path, FileAccess.WRITE)
	fo.store_string(order.replace("\"enabled\": true", "\"enabled\": false"))
	fo.close()
	c.load_all(dir + "/data")
	# Two saves written while only the original thirty rounds are playable.
	for name in ["cleared", "short"]:
		save.path = "%s/%s.json" % [dir, name]
		for stale in [save.path, save.path + ".bak", save.path + ".tmp"]:
			if FileAccess.file_exists(stale): DirAccess.remove_absolute(stale)
		save.progress = save.fresh()
		var last := 30 if name == "cleared" else 29
		for n in range(1, last + 1): save.progress.stars["r%02d" % n] = 3 if n % 2 == 0 else 2
		save.progress.unlocked_round = last + 1
		save.progress.coins = 777
		save.progress.upgrades = {"up_melee_basic": 5}
		check(save.save_progress(), "wrote the %s save" % name)
	check(not save.is_unlocked(30), "with the chapter closed there is no round after r30 to unlock")
	# The same saves under the actual published data, without fabricated rounds.
	c.load_all("res://data")
	check(c.challenge_enabled and c.round_order.size() == 40 and c.round_order[30] == "r31", "all ten rounds present + enabled: order has 40 rounds")
	check(c.next_round_id("r30") == "" and c.next_round_id("r31") == "r32", "r30 still ends the campaign; r31 leads to r32")
	save.path = dir + "/cleared.json"
	save.load_progress()
	check(save.is_unlocked(30) and not save.is_unlocked(31), "a save that cleared r30 opens r31 only")
	check(int(save.progress.coins) == 777 and int(save.progress.stars.get("r30", 0)) == 3 and int(save.progress.stars.get("r29", 0)) == 2 and int(save.progress.upgrades.get("up_melee_basic", 0)) == 5,
		"coins, stars and upgrades survive (%s coins, r30 %s stars)" % [save.progress.coins, save.progress.stars.get("r30")])
	check(not save.progress.stars.has("r31"), "no star appears for a round that was never played")
	check(save.record_result({"round_id": "r31", "won": true, "stars": 2, "time": 111.0, "coins": 10, "battle_uid": "challenge-test-1"}, 30) and save.is_unlocked(31) and not save.is_unlocked(32), "winning r31 opens r32")
	save.path = dir + "/short.json"
	save.load_progress()
	check(save.is_unlocked(29) and not save.is_unlocked(30), "a save that has not cleared r30 keeps r31 locked")
	check(int(save.progress.coins) == 777 and int(save.progress.upgrades.get("up_melee_basic", 0)) == 5, "and keeps its coins and upgrades")
	# enabled but incomplete: stays closed, with a warning
	fo = FileAccess.open(order_path, FileAccess.WRITE)
	fo.store_string(order)
	fo.close()
	DirAccess.remove_absolute(dir + "/data/rounds/r39.json")
	c.load_all(dir + "/data")
	check(not c.challenge_enabled and c.round_order.size() == 30 and not c.warnings.is_empty(), "enabled with a missing round stays closed and warns")
	c.load_all("res://data")
	save.path = real_path
	save.progress = real_progress

## The player-facing part of a save (other autoloads may add their own keys, e.g. services).
func _core(p: Dictionary) -> String:
	var out := []
	for k in ["unlocked_round", "stars", "best_time", "coins", "clears", "applied_battles", "tutorial_done", "upgrades", "open_rounds"]:
		out.append([k, p.get(k)])
	return JSON.stringify(out)

func _copy_tree(from: String, to: String) -> void:
	var d := DirAccess.open(from)
	if d == null: return
	DirAccess.make_dir_recursive_absolute(to)
	for f in d.get_files():
		if f.ends_with(".json"):
			var out := FileAccess.open(to + "/" + f, FileAccess.WRITE)
			out.store_buffer(FileAccess.get_file_as_bytes(from + "/" + f))
			out.close()
	for sub in d.get_directories():
		_copy_tree(from + "/" + sub, to + "/" + sub)

func _dev_path_checks(c, save) -> void:
	var app = root.get_node("App")
	if app.world == null:               # -s runs without the main scene: mount it like tests/integration does
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	var real_path: String = save.path
	var real_progress: Dictionary = save.progress
	save.path = "user://challenge-test/dev.json"
	save.progress = save.fresh()
	app.start_round("r31")
	await frames(2)
	check(app.current_round != "r31", "r31 is locked on a fresh save")
	for n in range(1, 31): save.progress.stars["r%02d" % n] = 3
	save.progress.unlocked_round = 31
	save.progress.coins = 500
	save.save_progress()
	var before := _core(save.progress)
	var mixer = root.get_node("Audio")
	var played: Array[StringName] = []
	var on_cue := func(cue: StringName, _voice: int): played.append(cue)
	mixer.cue_played.connect(on_cue)
	app.start_round("r32")
	await frames(2)
	check(app.current_round != "r32", "clearing r30 does not skip r31")
	for id in ["r31", "r35", "r40"]:
		app.start_round(id, true, true)       # what --round=<id> does
		await frames(90)
		var ok: bool = app.current_round == id and app.battle != null and app.battle.sim != null and str(app.battle.sim.round_def.id) == id
		check(ok, "dev path starts %s and the battle runs with its view and HUD" % id)
		if not ok: continue
		var th = app.battle.sim._spawn_enemy("boss_nestcore" if id == "r40" else "e_thrall")
		var atlas = root.get_node("Atlas")
		for pose in ["idle", "walk", "heavy_prepare", "heavy_release", "heavy_exposed", "death"]:
			check(atlas.anim_rec(th.anim_set, pose) != null, "%s loads its own %s sprite" % [th.id, pose])
		if id != "r31":
			check(atlas.anim_rec("e_binder", "idle") != null, "%s loads the knot sprite" % id)
		th.x = app.battle.sim.hero.x + 24.0
		th.heavy_cd = 0.0
		var kn = app.battle.sim._spawn_enemy("e_binder")
		kn.x = th.x + 40.0
		var marked := false
		for i in 150:                   # telegraph, strands and marks are drawn for real frames
			await process_frame
			if not app.battle.view._state_marks.is_empty(): marked = true
		check(marked, "%s: the view drew a wind-up / weak-point mark" % id)
		check(app.battle.sim.t > 1.0 and not app.battle.sim.ended, "%s is still running after the telegraph frames" % id)
		if id == "r35":
			check(th.link_src == kn.uid, "knot is still linked in the audio scenario")
			app.battle.sim._damage(kn, 1e6, 0.0)
			app.battle._drain_events()
		app.battle.sim._damage_base(-1, 1e9)
		await frames(120)
		check(bool(app.last_result.get("dev_round", false)) and bool(app.last_result.won) and str(app.last_result.round_id) == id and int(app.last_result.coins) == 0 and str(app.last_result.next_round_id) == "",
			"%s win is reported as a dev result: no coins, no next round (%s)" % [id, app.last_result])
	check(_core(save.progress) == before, "three dev wins left stars, unlocks, coins, clears, upgrades and tutorial flags as they were")
	mixer.cue_played.disconnect(on_cue)
	for cue in [&"nest_windup", &"nest_slam", &"nest_link_snap"]:
		check(played.has(cue), "the live battle routed %s to the audio mixer" % cue)
	save.load_progress()
	check(_core(save.progress) == before, "and the save file on disk holds the same")
	app.start_round("r31")
	await frames(4)
	check(app.current_round == "r31" and app.battle != null, "r30 clear allows normal r31 entry")
	if app.battle != null:
		app.battle.sim._damage_base(-1, 1e9)
		await frames(5)
		check(not bool(app.last_result.get("dev_round", false)) and str(app.last_result.next_round_id) == "r32"
			and save.is_unlocked(31) and save.progress.stars.has("r31"), "a normal r31 win saves progress and unlocks r32")
	app.show_screen(&"menu")
	await frames(4)
	save.path = real_path
	save.progress = real_progress

func _run() -> void:
	var c = root.get_node("Content")
	var save = root.get_node("Save")
	var mixer = root.get_node("Audio")
	for cue in ["nest_windup", "nest_slam", "nest_link_snap"]:
		check(not mixer.cues.get(cue, {}).get("streams", []).is_empty(), "%s has a playable stream" % cue)
	_data_checks(c)
	_heavy_checks(c)
	_link_checks(c)
	var through := _plan(c, false)
	var cutting := _plan(c, true)
	print("[challenge] r35 pack, fight through: ", through, "  cut the knot first: ", cutting)
	check(bool(through.cleared) and bool(cutting.cleared), "both plans clear the r35 pack")
	check(float(cutting.knot_dead_at) > 0.0 and (float(through.knot_dead_at) < 0.0 or float(cutting.knot_dead_at) < float(through.knot_dead_at)), "the cut plan removes the knot earlier")
	_boss_checks(c)
	_save_checks(c, save)
	await _dev_path_checks(c, save)
	print("[challenge] checks=", checks, " failures=", failures)
	mixer.prepare_quit()
	await create_timer(0.3, true, false, true).timeout
	quit(0 if failures == 0 else 1)
