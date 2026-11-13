extends SceneTree
## Chapter boundaries, production integration, fixed ground and boss cues.
const Painted = preload("res://src/gameplay/painted_chapter_backdrop.gd")
const Backdrop = preload("res://src/gameplay/lane_backdrop.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL painted: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var content = root.get_node("Content")
	var seen := {}
	for n in range(1, 101):
		var path := Painted.path_for(n)
		check(path == Painted.DIR + Painted.NAMES[(n - 1) / 10] + ".png", "chapter selection r%02d" % n)
		check(ResourceLoader.exists(path), "imported texture r%02d" % n)
		seen[path] = true
	check(seen.size() == 10, "exactly ten chapter images")
	for n in [1, 10, 11, 20, 21, 30, 31, 40, 41, 50, 51, 60, 61, 70, 71, 80, 81, 90, 91, 100]:
		var b = Backdrop.new()
		root.add_child(b)
		b.build(1800.0, 290.0, str(content.get_round("r%02d" % n).get("biome", "")), 40.0, 1760.0, n)
		check(b.painted != null and b.painted.chapter == (n - 1) / 10, "production mounts chapter r%02d" % n)
		if b.painted != null:
			var art = b.painted
			check(art.texture.get_size() == Vector2(4096, 704), "full resolution tile")
			var scenery = art.layers[2]
			var road = art.layers[5]
			check(is_equal_approx(scenery.destination.end.y, road.top), "no gap between landscape and road")
			check(scenery.destination.size == scenery.source.size / 4.0, "one world pixel per logical pixel")
			check(scenery.destination.size.y == 176.0 - float(Painted.TRIM_GROUND_ROWS[(n - 1) / 10]), "ground rows trimmed without scaling")
			check(road.top < 290.0 and road.top + 17.0 > 290.0, "feet remain inside road")
			check(art.factors[2] >= 0.5, "scenery scrolls like nearby land, not the horizon")
			check(art.layers[4].items.size() > 20 and is_equal_approx(art.factors[4], 1.0), "world-locked near props")
			for zoom in [1.0, 1.5, 2.0]:
				for camera in [-160.0, 0.0, 660.0, 1260.0, 2000.0]:
					b.present(camera, zoom, 2.0, 1.0)
					check(is_zero_approx(road.position.x), "road stays world-locked while scrolling")
			if b.live != null:
				b.live_update(true, 900.0, true, false, 5.0, 0.016)
				check(b.live.state == "exposed", "core exposure cue survives painted background")
		b.free()
	print("[painted-chapters] checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
