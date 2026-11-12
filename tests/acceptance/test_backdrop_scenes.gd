extends SceneTree
## Lane scenery R01-R40 (src/gameplay/backdrop_scenes.gd, lane_backdrop.gd): every round has a scene, neighbours
## differ, nothing in the kit is darker than the background floor, and the live boss overlay follows the boss state.
## Run:  godot --headless --path . -s tests/acceptance/test_backdrop_scenes.gd
const Scenes = preload("res://src/gameplay/backdrop_scenes.gd")
const Backdrop = preload("res://src/gameplay/lane_backdrop.gd")
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL backdrop: ", msg)
func _initialize() -> void: _run.call_deferred()

class Probe:
	var boxes := 0
	var polys := 0
	var darkest := 1.0
	var top := 0.0
	func box(r: Rect2, c: Color) -> void:
		boxes += 1
		darkest = minf(darkest, c.get_luminance())
		top = minf(top, r.position.y)
	func poly(p: PackedVector2Array, c: Color) -> void:
		polys += 1
		darkest = minf(darkest, c.get_luminance())
		for v in p: top = minf(top, v.y)

func _run() -> void:
	var c = root.get_node("Content")
	var kinds := {}
	for n in range(1, 41):
		var s: Dictionary = Scenes.spec(n)
		check(not s.is_empty() and int(s.chapter) == (n - 1) / 10 and str(s.note) != "", "r%02d has a scene and a note" % n)
		check(str(c.get_round("r%02d" % n).biome) != "" and int(c.get_round("r%02d" % n).index) == n, "r%02d round data carries its index" % n)
		var sig: Array = s.landmarks
		if n > 1 and (n - 1) % 10 != 0:
			var prev: Dictionary = Scenes.spec(n - 1)
			check(str(sig) != str(prev.landmarks), "r%02d landmarks differ from r%02d" % [n, n - 1])
		var mid_or_near := 0
		for lm in sig:
			kinds[str(lm[0])] = true
			if str(lm[1]) != "far": mid_or_near += 1
			var probe := Probe.new()
			Scenes.paint(probe, str(lm[0]), 0.0, 0.0, lm[3], float(lm[4]) if lm.size() > 4 else 1.0)
			check(probe.boxes + probe.polys >= 1, "r%02d %s draws shapes (%d)" % [n, lm[0], probe.boxes + probe.polys])
			check(probe.darkest >= 0.38, "r%02d %s stays lighter than the unit outlines (%.2f)" % [n, lm[0], probe.darkest])
			if str(lm[1]) == "far": check(probe.top >= -60.0, "r%02d %s fits above the ridge at 2x zoom (top %.0f)" % [n, lm[0], probe.top])
		check(mid_or_near >= 2, "r%02d has at least two landmarks at lane depth (%d)" % [n, mid_or_near])
		if n % 5 == 0: check(bool(s.boss), "r%02d is staged as a boss round" % n)
	check(Scenes.sky_of(1) != Scenes.sky_of(8) and Scenes.sky_of(8) != Scenes.sky_of(10), "chapter 1 goes morning -> dusk -> overcast")
	check(Scenes.light_of(21) != Scenes.light_of(30) and Scenes.light_of(31) != Scenes.light_of(40), "light changes inside the later chapters as well")
	check(kinds.size() >= 30, "the kit has %d landmark kinds" % kinds.size())
	# the built node: scene path, layers, live overlay states
	for n in [1, 10, 20, 30, 40]:
		var b = Backdrop.new()
		root.add_child(b)
		b.build(1800.0, 290.0, "biome_x", 40.0, 1760.0, n)
		check(b.layers.size() == 6 and b.live != null and not b.scene.is_empty(), "r%02d builds six planes and the live overlay" % n)
		b.live_update(false, 0.0, false, false, 0.0, 0.016)
		check(not b.live.visible, "no boss: the overlay is hidden")
		b.live_update(true, 900.0, n == 40, true, 0.0, 0.016)
		check(b.live.visible and b.live.enter_t > 0.8 and b.live.state == ("linked" if n == 40 else ""), "boss arrives: arrival bars start (%s)" % b.live.state)
		for i in 70: b.live_update(true, 900.0, n == 40, true, 0.0, 0.016)
		check(b.live.enter_t == 0.0, "the arrival lasts under a second")
		b.live_update(true, 900.0, n == 40, false, 5.0, 0.016)
		check(b.live.state == ("exposed" if n == 40 else "") and (n != 40 or is_equal_approx(b.live.exposed_max, 5.0)), "cut: exposed, the shaft starts at full width")
		b.live_update(true, 900.0, n == 40, false, 0.0, 0.016)
		check(b.live.state == ("open" if n == 40 else ""), "after the opening: cut strands only")
		b.present(600.0, 2.0, 1.0, 1.0)
		b.present(600.0, 2.0, 1.0, 1.05)
		check(b._tension > 0.0 and b.layers[5].modulate == b._mods[5], "tension tints the far planes, never the lane")
		b.queue_free()
	# rounds outside the table keep the generic build
	var g = Backdrop.new()
	root.add_child(g)
	g.build(1200.0, 290.0, "meadow")
	check(g.scene.is_empty() and g.layers.size() == 6 and g.live == null, "no index: generic backdrop, no overlay")
	g.live_update(true, 10.0, false, false, 0.0, 0.016)
	g.present(300.0, 1.0, 1.0, 0.5)
	g.queue_free()
	print("[backdrop] checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
