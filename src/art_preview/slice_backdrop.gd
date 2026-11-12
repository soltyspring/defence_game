extends Node2D
## Release-slice battlefield (docs/art/release_slice). Same interface as src/gameplay/lane_backdrop.gd, so the
## battle view and bakery_supply use it unchanged: build() / present() / live_update(), v2, set_texture, SET_MILL.
## Pieces: the R01 page (slice_atlas.png: bases, home set, mill, clouds, chapter-1 land) plus one chapter page
## (slice_ch<n>.png). Which pieces a round uses comes from rounds.json; the shared offsets from integration.json.
const Raster := preload("res://src/gameplay/pixel_camera.gd")
const DIR := "res://assets/art/release_slice/"
const ATLAS_JSON := DIR + "slice_atlas.json"
const ATLAS_PNG := DIR + "slice_atlas.png"
const LAYOUT_JSON := DIR + "integration.json"
const ROUNDS_JSON := DIR + "rounds.json"
## Chapter 1 keeps its land on the R01 page under the R01 names.
const ALIAS := {"mid_a": "mid_home", "mid_b": "mid_blight", "lane_a": "lane", "lane_b": "lane_blight", "enemy_a": "enemy_set"}
const LANDMARK_BASE := -40.0    # "mid" landmarks stand on the field line of the mid layer, above the unit band

class Layer extends Node2D:
	var fills: Array = []      # [Rect2, Color]
	var items: Array = []      # [source Rect2, position Vector2, texture]
	func _draw() -> void:
		for f in fills:
			draw_rect(f[0], f[1])
		for item in items:
			var src: Rect2 = item[0]
			if item[2] != null and src.size.x > 0.0:
				draw_texture_rect_region(item[2], Rect2(item[1], src.size), src)

## Moving life per chapter, the kind of small ambient motion lane games use to make a static field feel alive:
## 1 butterflies over the meadow and a flock of birds, 2 falling leaves and fruit-fly motes, 3 snowfall,
## 4 glowing spores rising. Deterministic (seeded), ~40-70 rects a frame, drawn behind the units.
class Ambient extends Node2D:
	var chapter := 1
	var t := 0.0
	var span := 1000.0
	var ground := 0.0
	var parts: Array = []        # [x, y, speed, phase, size]
	var intensity := 1.0
	func setup(ch: int, length: float, g: float, stage: float) -> void:
		chapter = ch
		span = length
		ground = g
		intensity = 0.6 + stage * 0.8
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + ch
		var n := int(float([0, 70, 90, 220, 110][ch]) * intensity)
		for i in n:
			parts.append([rng.randf_range(-300.0, length + 300.0), rng.randf_range(-150.0, -20.0), rng.randf_range(0.6, 1.4), rng.randf() * TAU, rng.randi_range(1, 2)])
	func _draw() -> void:
		match chapter:
			1: _meadow()
			2: _orchard()
			3: _snow()
			4: _spores()
	func _meadow() -> void:
		for i in parts.size():
			var p: Array = parts[i]
			if i % 3 == 0:     # butterflies low over the field, wings opening and closing
				var x: float = p[0] + sin(t * 0.4 * p[2] + p[3]) * 40.0
				var y: float = ground - 30.0 - 12.0 * absf(sin(t * 0.9 + p[3])) + p[1] * 0.08
				var open: bool = int(t * 8.0 + p[3] * 3.0) % 2 == 0
				var c: Color = [Color("f6d36a"), Color("f2f2f2"), Color("e88a7a")][(i / 3) % 3]
				draw_rect(Rect2(x, y, 1, 2), Color("3a2a24"))
				if open:
					draw_rect(Rect2(x - 3, y - 2, 3, 3), c)
					draw_rect(Rect2(x + 1, y - 2, 3, 3), c)
				else:
					draw_rect(Rect2(x - 1, y - 2, 1, 2), c)
					draw_rect(Rect2(x + 1, y - 2, 1, 2), c)
		# a small flock crossing the sky now and then
		var cyc := fmod(t, 40.0)
		if cyc < 26.0:
			var fx := -200.0 + cyc / 26.0 * (span + 400.0)
			for k in 5:
				var bx := fx - k * 9.0 - (k % 2) * 4.0
				var by := ground - 160.0 + absf(k - 2.0) * 4.0 + sin(t * 2.0 + k) * 2.0
				var up := int(t * 6.0 + k) % 2 == 0
				draw_rect(Rect2(bx - 2, by + (0 if up else 1), 2, 1), Color("4a4458"))
				draw_rect(Rect2(bx, by + 1, 1, 1), Color("4a4458"))
				draw_rect(Rect2(bx + 1, by + (0 if up else 1), 2, 1), Color("4a4458"))
	func _orchard() -> void:
		for i in parts.size():
			var p: Array = parts[i]
			if i % 2 == 0:     # leaves: fall, sway, loop over the height
				var h := 150.0
				var y: float = fmod(p[1] + 150.0 + t * 10.0 * p[2], h) - h + ground - 10.0
				var x: float = p[0] + sin(t * 1.3 * p[2] + p[3]) * 8.0 - t * 4.0 * p[2]
				x = fposmod(x + 300.0, span + 600.0) - 300.0
				var c: Color = [Color("d9903a"), Color("b8603a"), Color("8e9c88")][i % 3]
				var flip: bool = int(t * 4.0 + p[3] * 2.0) % 2 == 0
				draw_rect(Rect2(x, y, 3 if flip else 2, 2 if flip else 3), c)
				draw_rect(Rect2(x, y, 1, 1), c.darkened(0.3))
			else:              # fruit-fly motes buzzing around a point
				var x: float = p[0] + sin(t * 5.0 * p[2] + p[3]) * 4.0
				var y: float = ground - 40.0 + p[1] * 0.2 + cos(t * 6.3 * p[2] + p[3]) * 3.0
				draw_rect(Rect2(x, y, 2, 1), Color("3e4152"))
				draw_rect(Rect2(x, y - 1, 1, 1), Color(0.9, 0.95, 1.0, 0.7))
	func _snow() -> void:
		for i in parts.size():
			var p: Array = parts[i]
			var h := 170.0
			var y: float = fmod(p[1] + 170.0 + t * 9.0 * p[2], h) - h + ground
			var x: float = p[0] + sin(t * 0.8 + p[3]) * 6.0 - t * 3.0
			x = fposmod(x + 300.0, span + 600.0) - 300.0
			var s: int = p[4] + 1
			draw_rect(Rect2(x + 1, y + 1, s, s), Color("8a9cb8"))      # cool edge so a flake reads on a pale sky
			draw_rect(Rect2(x, y, s, s), Color.WHITE)
	func _spores() -> void:
		for i in parts.size():
			var p: Array = parts[i]
			var h := 150.0
			var y: float = ground - fmod(-p[1] + t * 6.0 * p[2], h) - 5.0
			var x: float = p[0] + sin(t * 0.7 * p[2] + p[3]) * 10.0
			var a: float = 0.45 + 0.4 * sin(t * 2.0 + p[3])
			var c: Color = Color("9fe6cf") if i % 3 else Color("c7b1c8")
			c.a = a
			draw_rect(Rect2(x, y, p[4] + 1, p[4] + 1), c)
			if p[4] == 2:
				var g: Color = c
				g.a = a * 0.3
				draw_rect(Rect2(x - 1, y - 1, 4, 4), g)

var ambient: Ambient = null
var layers: Array[Node2D] = []
var factors: Array[float] = []
var drifts: Array[float] = []
var set_texture: Texture2D             # read by bakery_supply (the mill) - the R01 page
var chapter_texture: Texture2D = null
var village_texture: Texture2D = null
var v2 := true
var SET_MILL := Rect2()
var scene := {}                        # lane_backdrop API: no per-round scene here
var live = null
var frames := {}
var chapter_frames := {}
var layout := {}
var round_def := {}

static func load_texture(path := ATLAS_PNG) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D: return t
	if not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))     # not imported: dev decode
	return ImageTexture.create_from_image(img) if img != null else null

static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

## [source rect, texture] of a piece: the chapter page first, then the R01 page (through ALIAS for chapter 1).
func _piece(piece_name: String) -> Array:
	var f: Dictionary = {}
	var tex: Texture2D = chapter_texture
	if chapter_frames.has(piece_name) and chapter_texture != null:
		f = chapter_frames[piece_name]
	else:
		tex = set_texture
		f = frames.get(ALIAS.get(piece_name, piece_name), frames.get(piece_name, {}))
	return [Rect2(float(f.get("x", 0)), float(f.get("y", 0)), float(f.get("w", 0)), float(f.get("h", 0))), tex]

func _put(layer: Layer, piece_name: String, pos: Vector2) -> void:
	var p := _piece(piece_name)
	layer.items.append([p[0], pos, p[1]])

func _size(piece_name: String) -> Vector2:
	return (_piece(piece_name)[0] as Rect2).size

func _layer(factor: float, drift := 0.0) -> Layer:
	var l := Layer.new()
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	layers.append(l)
	factors.append(factor)
	drifts.append(drift)
	return l

func build(length: float, ground: float, _biome: String, player_x := 40.0, enemy_x := -1.0, round_index := 0) -> void:
	if enemy_x < 0.0: enemy_x = length - 40.0
	set_texture = load_texture()
	frames = _json(ATLAS_JSON).get("frames", {})
	layout = _json(LAYOUT_JSON).get("layout", {})
	var table := _json(ROUNDS_JSON)
	round_def = table.get("rounds", {}).get(str(round_index), {})
	var chapter := int(round_def.get("chapter", 1))
	chapter_texture = load_texture(DIR + "slice_ch%d.png" % chapter)
	chapter_frames = _json(DIR + "slice_ch%d.json" % chapter).get("frames", {}) if chapter_texture != null else {}
	var front_at: float = float(round_def.get("front", layout.mid.blight_from))
	SET_MILL = _piece("mill")[0]
	# sky: flat bands; they reach far above the 2x view for taller windows
	var sky := _layer(0.0)
	var bands: Array = round_def.get("sky", layout.sky)
	for i in bands.size():
		var top: float = ground + float(bands[i][1])
		var bottom: float = ground + (float(bands[i + 1][1]) if i + 1 < bands.size() else 400.0)
		sky.fills.append([Rect2(-3000, top, length + 8000, bottom - top), Color(str(bands[i][0]))])
	# clouds: a few, drifting slowly; the picture is complete without the motion. None underground.
	if bool(round_def.get("clouds", true)):
		var clouds := _layer(float(layout.clouds.parallax), float(layout.clouds.drift))
		var names := ["cloud_a", "cloud_c", "cloud_b"]
		for i in range(-2, int(length * 0.3 / 150.0) + 6):
			_put(clouds, names[posmod(i, 3)], Vector2(i * 150.0 + posmod(i * 37, 60), ground + float(layout.clouds.y) + posmod(i * 11, 16)))
	# far ridge
	var ff: float = float(layout.far.parallax)
	var far := _layer(ff)
	var fw: float = _size("far").x
	var fy: float = ground + float(layout.far.y)
	for i in range(-2, int(length * 0.3 / fw) + 4):
		_put(far, "far", Vector2(i * fw, fy))
	# the ridge's own base colour down to the ground: no sky shows between the ridge and a low middle ground
	var far_fill := str(table.get("far_fill", {}).get(str(chapter), ""))
	if far_fill != "":
		far.fills.append([Rect2(-3000, fy + _size("far").y - 1.0, length + 8000, -float(layout.far.y)), Color(far_fill)])
	# middle ground: side A up to the front, side B after it, the ragged edge drawn over the join
	var mid := _layer(float(layout.mid.parallax))
	var mf: float = float(layout.mid.parallax)
	var mw: float = _size("mid_a").x
	var front: float = mf * front_at * length
	var my: float = ground + float(layout.mid.y)
	var x := front - mw
	while x > -900.0 - mw:
		_put(mid, "mid_a", Vector2(x, my))
		x -= mw
	x = front
	while x < mf * length + 900.0:
		_put(mid, "mid_b", Vector2(x, my))
		x += mw
	_put(mid, "mid_edge", Vector2(front - 60.0, my))
	# the two base surroundings, world-locked, behind the units
	var sets := _layer(1.0)
	var home_name := str(round_def.get("home", "home_set"))
	var hs := _size(home_name)
	_put(sets, home_name, Vector2(player_x + float(layout.home_set.x), ground + float(layout.home_set.bottom) - hs.y))
	var enemy_name := str(round_def.get("enemy", "enemy_a"))
	var es := _size(enemy_name)
	_put(sets, enemy_name, Vector2(enemy_x + float(layout.enemy_set.x), ground + float(layout.enemy_set.bottom) - es.y))
	# landmarks of this round: [piece, lane fraction or px, plane]
	for lm in round_def.get("landmarks", []):
		var lname := str(lm[0])
		var ls := _size(lname)
		match str(lm[2]):
			"mid": _put(mid, lname, Vector2(mf * float(lm[1]) * length - ls.x * 0.5, ground + LANDMARK_BASE - ls.y))
			"far": _put(far, lname, Vector2(ff * float(lm[1]) * length - ls.x * 0.5, fy + _size("far").y - ls.y))
			"home": _put(sets, lname, Vector2(player_x + float(lm[1]) - ls.x * 0.5, ground + float(layout.home_set.bottom) - ls.y))
	# the road
	var lane := _layer(1.0)
	var lw: float = _size("lane_a").x
	var ly: float = ground + float(layout.lane.y)
	var turn: float = front_at * length
	x = -768.0
	var first_b := true
	while x < length + 768.0:
		var side_b: bool = x + lw * 0.5 >= turn
		_put(lane, "lane_b" if side_b else "lane_a", Vector2(x, ly))
		if side_b and first_b:
			first_b = false
			_put(lane, "lane_edge", Vector2(x - _size("lane_edge").x, ly))    # ragged start of the taken road
		x += lw
	if bool(round_def.get("forecourt", true)):
		_put(lane, "lane_home", Vector2(player_x + float(layout.lane.home_x), ly))
	# ambient life: in front of the middle ground, behind the units (same plane as the base sets)
	ambient = Ambient.new()
	add_child(ambient)
	move_child(ambient, lane.get_index())
	layers.append(ambient)
	factors.append(1.0)
	drifts.append(0.0)
	ambient.setup(chapter, length, ground, float((round_index - 1) % 10) / 9.0 if round_index > 0 else 0.0)
	# soil below the tile, for views taller than the tile
	var soil := str(table.get("soil", {}).get(str(chapter), "6a4e38"))
	lane.fills.append([Rect2(-3000, ly + _size("lane_a").y - 1.0, length + 8000, 400), Color(soil)])

func live_update(_boss_on: bool, _boss_x: float, _core: bool, _linked: bool, _exposed: float, _dt: float) -> void:
	pass

func present(camera: float, zoom: float, device_scale: float, seconds: float) -> void:
	if ambient != null:
		ambient.t = seconds
		ambient.queue_redraw()
	for i in layers.size():
		var shift := Raster.layer_origin(camera, factors[i], zoom, device_scale)
		if drifts[i] != 0.0: shift += Raster.world_position(-seconds * drifts[i], zoom, device_scale)
		layers[i].position.x = shift
