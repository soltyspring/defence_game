extends SceneTree
const Sim = preload("res://src/gameplay/battle_sim.gd")
const View = preload("res://src/gameplay/battle_view.gd")
const Layout = preload("res://src/ui/hud_layout.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL campaign: ",message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c = root.get_node("Content")
	var save = root.get_node("Save")
	save.path = "user://campaign_tests/save.json"
	DirAccess.make_dir_recursive_absolute(save.path.get_base_dir())
	save.progress = save.fresh()
	check(c.round_order.size() == 40 and c.warnings.is_empty(),"40 valid rounds without fallback warnings")
	check(c.next_round_id("r10") == "r11" and c.next_round_id("r30") == "","chapter transitions and final round")
	for n in range(11,31):
		var rd: Dictionary = c.get_round("r%02d" % n)
		check(rd.index == n and rd.cards.size() == 5 and rd.waves.size() == 4,"round %d complete" % n)
		for wave in rd.waves:
			for spawn in wave.spawns: check(c.units.has(spawn.unit),"known enemy %s" % spawn.unit)
		if n % 5 == 0: check(rd.waves[0].boss and str(rd.waves[0].spawns[0].unit).begins_with("boss_"),"boss enters before base rush")
	var legacy: Dictionary = save.fresh()
	legacy.unlocked_round = 11
	legacy.stars = {"r10":3}
	legacy.upgrades = {"up_melee_basic":5}
	legacy.settings.sfx = 0.37
	save.progress = save._migrate(legacy,1)
	check(save.is_unlocked(10) and not save.is_unlocked(11),"old r10 clear opens r11 only")
	check(save.upgrade_level("up_melee_basic") == 5 and is_equal_approx(save.progress.settings.sfx,0.37),"old upgrades and volume survive")
	save.progress.coins = 99999
	save.progress.unlocked_round = 10
	save.progress.stars = {}
	var coins: int = save.progress.coins
	check(save.buy_upgrade("up_melee_basic",6) == save.UPG_LOCKED and save.progress.coins == coins,"late tier blocked without debit in chapter one")
	save.progress.unlocked_round = 11
	check(save.buy_upgrade("up_melee_basic",6) == save.UPG_OK,"tier 6 at r11")
	check(save.buy_upgrade("up_melee_basic",7) == save.UPG_LOCKED,"tier 7 held until r16")
	save.progress.unlocked_round = 16
	check(save.buy_upgrade("up_melee_basic",7) == save.UPG_OK,"tier 7 at r16")
	save.progress.unlocked_round = 31
	save.progress.stars["r30"] = 1
	var select = load("res://src/ui/round_select.gd").new()
	root.add_child(select)
	await process_frame
	check(select._pages() == 4 and select.page == 3 and select.tiles[0].get_meta("number") == 31 and select.tiles[9].get_meta("number") == 40,"fourth page contains r31–r40")
	check(not select.tiles[0].disabled and select.tiles[1].disabled and select.tiles[9].disabled,"r30 clear unlocks only the first challenge tile")
	select.queue_free()
	var sim = Sim.new()
	sim.setup(c,"r11",41)
	sim._damage_base(-1,10)
	var tx = sim.texts.filter(func(t): return t.alive and t.uid == -100)[0]
	sim._step_fx(0.1)
	sim._damage_base(-1,12)
	check(tx.value == 22 and is_equal_approx(tx.t,0.1),"merged base damage retains animation age")
	var prev := View.damage_curve(0)
	for i in range(1,97):
		var point := View.damage_curve(i/120.0)
		check(point.x >= prev.x and point.y <= prev.y and point.x-prev.x < 0.7,"continuous monotonic 120Hz rise/fade")
		prev = point
	check(is_zero_approx(prev.y),"damage fully fades")
	var view = View.new()
	view.sim = sim
	for i in 18:
		var unit = sim._spawn_enemy("e_guard")
		unit.x = 900
		unit.lane_y = 0
	view._update_formation(1.0)
	var positions := {}
	for u in sim.enemies:
		positions[view._unit_pos(u)] = true
		check(is_equal_approx(u.x,900) and is_zero_approx(u.lane_y),"formation leaves simulation unchanged")
		check(view._unit_pos(u).y <= view.ground_y,"formation feet stay above the card strip")
	check(positions.size() >= 8 and view._crowd_badges.size() == 1 and view._crowd_badges[0].count == 18,"crowd has separated rows and exact count")
	sim.enemies.clear()
	view._update_formation(1.0)
	check(view._formation_offsets.size() <= 1,"dead formation cache is pruned")
	view.free()
	for size in [Vector2(640,360),Vector2(800,450)]:
		var l = Layout.compute(size,Rect2(Vector2.ZERO,size),5,3,48)
		check(Layout.validate(l).is_empty() and l.minimap.size.x <= 150 and l.minimap.size.y >= 40 and l.minimap.position.y == l.pause.position.y,"compact single row minimap remains touchable")
	await process_frame
	print("[campaign] passed=",checks-failures," failed=",failures)
	quit(0 if failures == 0 else 1)
