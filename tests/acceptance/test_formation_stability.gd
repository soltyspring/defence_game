extends SceneTree
const Sim = preload("res://src/gameplay/battle_sim.gd")
const View = preload("res://src/gameplay/battle_view.gd")
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL formation: ",msg)
func _initialize() -> void: _run.call_deferred()
func duel_refs() -> Array:
	var a := Sim.Unit.new()
	var b := Sim.Unit.new()
	a.w_target = b
	b.w_target = a
	return [weakref(a),weakref(b)]
func _run() -> void:
	var refs := duel_refs()
	check(refs[0].get_ref() == null and refs[1].get_ref() == null,"mutual attack targets do not leak")
	var sim = Sim.new()
	sim.setup(root.get_node("Content"),"r08",41)
	for i in 18:
		sim.gold = 500
		sim.card_cd.melee_basic = 0
		sim.deploy("melee_basic")
		sim.players.back().x = 700
		sim.players.back().lane_y = 0
	var view = View.new()
	view.sim = sim
	view._update_formation(1)
	var rows := {}
	var places := {}
	for u in sim.players:
		rows[u.uid] = view._unit_pos(u).y
		places[view._unit_pos(u)] = true
	check(places.size() == 18,"18 identical units receive distinct positions")
	var travel := 0.0
	var moves := 0
	var feet_safe := true
	var max_correction := 0.0
	for frame in 600:
		if frame % 60 == 0:
			var leaving = sim.players.pop_front()
			leaving.alive = false
			sim.gold = 500
			sim.card_cd.melee_basic = 0
			sim.deploy("melee_basic")
		for i in sim.players.size():
			# Repeatedly cross the old 24 px regroup threshold, with arrivals/deaths.
			sim.players[i].x = 700+float((i%3)*24)*(1 if frame%24 < 12 else -1)
		var before: Dictionary = view._formation_offsets.duplicate()
		view._update_formation(1.0/60)
		for u in sim.players:
			var y: float = view._unit_pos(u).y
			if rows.has(u.uid):
				travel += absf(y-float(rows[u.uid]))
				if not is_equal_approx(y,float(rows[u.uid])): moves += 1
			rows[u.uid] = y
			feet_safe = feet_safe and y <= view.ground_y
			if before.has(u.uid): max_correction = maxf(max_correction,absf(view._formation_offsets[u.uid].x-before[u.uid].x))
	check(feet_safe,"feet stay above cards throughout the scenario")
	check(max_correction <= 0.501,"horizontal correction has a bounded speed")
	check(is_zero_approx(travel) and moves == 0,"survivors never switch rows during merges/deaths")
	check(view._formation_slots.size() == sim.players.size(),"departed slots are reclaimed")
	print("[formation] checks=",checks," failures=",failures," survivor_y_travel=",travel," row_switches=",moves)
	view.free()
	quit(0 if failures == 0 else 1)
