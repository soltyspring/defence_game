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
	for n in range(1, 41):
		var path := Painted.path_for(n)
		check(path == Painted.DIR + Painted.NAMES[(n - 1) / 10] + ".png", "chapter selection r%02d" % n)
		check(ResourceLoader.exists(path), "imported texture r%02d" % n)
		seen[path] = true
	check(seen.size() == 4, "exactly four chapter images")
	for n in [1, 10, 11, 20, 21, 30, 31, 40]:
		var b = Backdrop.new()
		root.add_child(b)
		b.build(1800.0, 290.0, str(content.get_round("r%02d" % n).biome), 40.0, 1760.0, n)
		check(b.painted != null and b.painted.chapter == (n - 1) / 10, "production mounts chapter r%02d" % n)
		if b.painted != null:
			var art = b.painted
			check(art.texture.get_width() >= 2000 and art.texture.get_height() >= 700, "full resolution artwork")
			var scenery = art.layers[2]
			var road = art.layers[5]
			check(is_equal_approx(scenery.destination.end.y, road.destination.position.y), "no gap between landscape and road")
			check(is_equal_approx(scenery.source.end.y, road.source.position.y), "adjacent original image regions")
			check(road.destination.position.y < 290.0 and road.destination.end.y > 290.0, "feet remain inside road")
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
