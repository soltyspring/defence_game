extends SceneTree
## 2026-11-11 Fable 5.2 core pass: HUD fit row / smaller overview, column-stable formation, base damage total.
## Run (headless, inside coordination/heavy_run):  godot --headless --path . -s tests/acceptance/test_fable52_core.gd
## NOT yet run in Godot by the author (no engine in that environment); the same maths passed in the Python
## mirrors tools/qa/hud_layout_mirror.py and tools/qa/formation_mirror.py.
const Sim = preload("res://src/gameplay/battle_sim.gd")
const View = preload("res://src/gameplay/battle_view.gd")
const HudLayout = preload("res://src/ui/hud_layout.gd")
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL fable52: ", msg)
func _initialize() -> void: _run.call_deferred()

func _layout_checks() -> void:
	# every control stays inside the view and clear of the others, down to small desktop windows
	for size in [Vector2(640,360), Vector2(800,360), Vector2(480,270), Vector2(392,220), Vector2(320,180), Vector2(240,120), Vector2(640,200)]:
		for cards in [1, 3, 5]:
			for skills in [0, 3]:
				var l: Dictionary = HudLayout.compute(size, Rect2(Vector2.ZERO, size), cards, skills, 44.0)
				var rects: Array[Rect2] = HudLayout.touch_rects(l)
				var ok := true
				for i in rects.size():
					var a: Rect2 = rects[i]
					if not Rect2(Vector2.ZERO, size).encloses(a): ok = false
					for j in range(i + 1, rects.size()):
						if a.intersects(rects[j]): ok = false
				check(ok, "controls reachable at %s cards=%d skills=%d" % [size, cards, skills])
	var wide: Dictionary = HudLayout.compute(Vector2(640,360), Rect2(0,0,640,360), 5, 3, 44.0)
	check((wide.minimap as Rect2).size.x <= HudLayout.MAP_MAX, "overview strip is at most %d px wide" % int(HudLayout.MAP_MAX))
	check(HudLayout.validate(wide).is_empty(), "640x360 layout still passes every layout rule: %s" % [HudLayout.validate(wide)])
	check(not bool(wide.fit), "640x360 does not use the fit row")
	var calm: Dictionary = HudLayout.compute(Vector2(640,360), Rect2(0,0,640,360), 5, 3, 44.0, false)
	check((calm.banner as Rect2).end.y < (wide.banner as Rect2).end.y, "strips move up while no boss is alive")
	check(HudLayout.validate(calm).is_empty(), "no-boss layout passes every layout rule: %s" % [HudLayout.validate(calm)])

func _formation_checks(sim) -> void:
	check(View.column_blocked(100.0, PackedFloat32Array([104.0])), "drawn 4 px apart = covered")
	check(not View.column_blocked(100.0, PackedFloat32Array([109.0])), "drawn 9 px apart = clear")
	check(View.free_column(100.0, 1, 0, PackedFloat32Array([100.0])) == 1, "nearest free column is taken")
	for i in 12:
		sim.gold = 500
		sim.card_cd.melee_basic = 0
		sim.deploy("melee_basic")
		sim.players.back().lane_y = 0
	var view = View.new()
	view.sim = sim
	# a marching column, 28 px apart, that keeps closing up and spreading: nobody may be re-seated while walking
	for i in sim.players.size():
		sim.players[i].x = 300.0 + i * 28.0
		sim.players[i].state = Sim.S_WALK
	view._update_formation(1.0)
	var seats: Dictionary = view._formation_slots.duplicate()
	var reseats := 0
	for frame in 300:
		for i in sim.players.size():
			sim.players[i].x = 300.0 + frame * 0.5 + i * (28.0 + 6.0 * sin(frame * 0.2 + i))
		view._update_formation(1.0 / 60)
		for uid in seats:
			if view._formation_slots[uid] != seats[uid]: reseats += 1
		seats = view._formation_slots.duplicate()
	check(reseats == 0, "walking units keep their column (re-seats = %d)" % reseats)
	# they stop on one spot: every same-row pair ends up drawn apart, and then nothing moves any more
	for u in sim.players:
		u.x = 700.0
		u.state = Sim.S_IDLE
	for frame in 240: view._update_formation(1.0 / 60)
	var drawn := {}
	for u in sim.players:
		var slot: Vector2i = view._formation_slots[u.uid]
		drawn[Vector2i(slot.x, int(roundf(View.drawn_x(u.x, u.side, slot.y))))] = true
	check(drawn.size() == sim.players.size(), "12 stopped units occupy 12 distinct places (%d)" % drawn.size())
	seats = view._formation_slots.duplicate()
	for frame in 240: view._update_formation(1.0 / 60)
	check(view._formation_slots == seats, "a settled pack does not shuffle")
	view.free()

func _combo_checks(sim) -> void:
	check(is_equal_approx(View.combo_curve(0.0).x, 1.0) and is_zero_approx(View.combo_curve(0.0).y), "total is solid and still while hits land")
	check(is_zero_approx(View.combo_curve(View.COMBO_HOLD + View.COMBO_FADE).x), "total is gone after hold + fade")
	var last := 0.0
	var monotonic := true
	for i in 40:
		var y: float = View.combo_curve(i * 0.03).y
		if y < last - 0.0001: monotonic = false
		last = y
	check(monotonic, "the total only drifts up, never back")
	var view = View.new()
	view.sim = sim
	var a = Sim.FText.new()
	a.alive = true
	a.uid = -100
	a.serial = 9001
	a.x = float(sim.enemy_base.x)
	a.value = 12
	view._feed_base_combo(a)
	a.value = 30                       # the sim merged another hit into the same text
	view._feed_base_combo(a)
	view._feed_base_combo(a)           # re-reading the same value adds nothing
	var b = Sim.FText.new()
	b.alive = true
	b.uid = -100
	b.serial = 9002
	b.x = float(sim.enemy_base.x)
	b.value = 60                       # next 0.24 s window of the same siege
	view._feed_base_combo(b)
	check(int(view._base_combo[-100].total) == 90, "shown total = sum of the sim's base hits (%d)" % int(view._base_combo[-100].total))
	check(float(view._base_combo[-100].x) < float(sim.enemy_base.x), "enemy-base total sits on the battlefield side of the nest")
	sim.t += View.COMBO_HOLD + View.COMBO_FADE + 0.1
	var c = Sim.FText.new()
	c.alive = true
	c.uid = -100
	c.serial = 9003
	c.x = float(sim.enemy_base.x)
	c.value = 7
	view._feed_base_combo(c)
	check(int(view._base_combo[-100].total) == 7, "a new burst after the fade starts from zero")
	view.free()

func _run() -> void:
	_layout_checks()
	var sim = Sim.new()
	sim.setup(root.get_node("Content"), "r08", 41)
	_formation_checks(sim)
	var sim2 = Sim.new()
	sim2.setup(root.get_node("Content"), "r08", 41)
	_combo_checks(sim2)
	print("[fable52] checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
