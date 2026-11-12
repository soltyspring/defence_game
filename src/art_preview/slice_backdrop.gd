extends Node2D
## Release-slice battlefield (docs/art/release_slice). Same interface as src/gameplay/lane_backdrop.gd, so the
## battle view and bakery_supply use it unchanged: build() / present() / live_update(), v2, set_texture, SET_MILL.
## Pieces come from one atlas page (assets/art/release_slice/slice_atlas.png); the layout from integration.json.
const Raster := preload("res://src/gameplay/pixel_camera.gd")
const ATLAS_JSON := "res://assets/art/release_slice/slice_atlas.json"
const ATLAS_PNG := "res://assets/art/release_slice/slice_atlas.png"
const LAYOUT_JSON := "res://assets/art/release_slice/integration.json"

class Layer extends Node2D:
	var texture: Texture2D
	var fills: Array = []      # [Rect2, Color]
	var items: Array = []      # [source Rect2, position Vector2]
	func _draw() -> void:
		for f in fills:
			draw_rect(f[0], f[1])
		for item in items:
			var src: Rect2 = item[0]
			draw_texture_rect_region(texture, Rect2(item[1], src.size), src)

var layers: Array[Node2D] = []
var factors: Array[float] = []
var drifts: Array[float] = []
var set_texture: Texture2D             # read by bakery_supply (the mill) - the slice atlas page
var village_texture: Texture2D = null
var v2 := true
var SET_MILL := Rect2()
var scene := {}                        # lane_backdrop API: no per-round scene here
var live = null
var frames := {}
var layout := {}

static func load_texture() -> Texture2D:
	if ResourceLoader.exists(ATLAS_PNG):
		var t = load(ATLAS_PNG)
		if t is Texture2D: return t
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PNG))     # not imported: dev decode
	return ImageTexture.create_from_image(img) if img != null else null

func _src(frame_name: String) -> Rect2:
	var f: Dictionary = frames.get(frame_name, {})
	return Rect2(float(f.get("x", 0)), float(f.get("y", 0)), float(f.get("w", 0)), float(f.get("h", 0)))

func _layer(factor: float, drift := 0.0) -> Layer:
	var l := Layer.new()
	l.texture = set_texture
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	layers.append(l)
	factors.append(factor)
	drifts.append(drift)
	return l

func build(length: float, ground: float, _biome: String, player_x := 40.0, enemy_x := -1.0, _round_index := 0) -> void:
	if enemy_x < 0.0: enemy_x = length - 40.0
	set_texture = load_texture()
	var meta = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_JSON))
	frames = meta.frames if meta is Dictionary else {}
	var integ = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_JSON))
	layout = integ.layout if integ is Dictionary else {}
	SET_MILL = _src("mill")
	# sky: flat bands, the lowest ones warm; they reach far above the 2x view for taller windows
	var sky := _layer(0.0)
	var bands: Array = layout.sky
	for i in bands.size():
		var top: float = ground + float(bands[i][1])
		var bottom: float = ground + (float(bands[i + 1][1]) if i + 1 < bands.size() else 400.0)
		sky.fills.append([Rect2(-3000, top, length + 8000, bottom - top), Color(str(bands[i][0]))])
	# clouds: a few, drifting slowly; the picture is complete without the motion
	var clouds := _layer(float(layout.clouds.parallax), float(layout.clouds.drift))
	var names := ["cloud_a", "cloud_c", "cloud_b"]
	for i in range(-2, int(length * 0.3 / 150.0) + 6):
		clouds.items.append([_src(names[posmod(i, 3)]), Vector2(i * 150.0 + posmod(i * 37, 60), ground + float(layout.clouds.y) + posmod(i * 11, 16))])
	# far ridge with the village
	var far := _layer(float(layout.far.parallax))
	var fw: float = _src("far").size.x
	for i in range(-2, int(length * 0.3 / fw) + 4):
		far.items.append([_src("far"), Vector2(i * fw, ground + float(layout.far.y))])
	# fields: healthy up to the blight front, taken after it, the ragged edge drawn over the join
	var mid := _layer(float(layout.mid.parallax))
	var mf: float = float(layout.mid.parallax)
	var mw: float = _src("mid_home").size.x
	var front: float = mf * float(layout.mid.blight_from) * length
	var my: float = ground + float(layout.mid.y)
	var x := front - mw
	while x > -900.0 - mw:
		mid.items.append([_src("mid_home"), Vector2(x, my)])
		x -= mw
	x = front
	while x < mf * length + 900.0:
		mid.items.append([_src("mid_blight"), Vector2(x, my)])
		x += mw
	mid.items.append([_src("mid_edge"), Vector2(front - 60.0, my)])
	# the two base surroundings, world-locked, behind the units
	var sets := _layer(1.0)
	var hs := _src("home_set")
	sets.items.append([hs, Vector2(player_x + float(layout.home_set.x), ground + float(layout.home_set.bottom) - hs.size.y)])
	var es := _src("enemy_set")
	sets.items.append([es, Vector2(enemy_x + float(layout.enemy_set.x), ground + float(layout.enemy_set.bottom) - es.size.y)])
	# the road
	var lane := _layer(1.0)
	var lw: float = _src("lane").size.x
	var ly: float = ground + float(layout.lane.y)
	var turn: float = float(layout.lane.blight_from) * length
	x = -768.0
	var first_grey := true
	while x < length + 768.0:
		var grey: bool = x + lw * 0.5 >= turn
		lane.items.append([_src("lane_blight" if grey else "lane"), Vector2(x, ly)])
		if grey and first_grey:
			first_grey = false
			lane.items.append([_src("lane_edge"), Vector2(x - _src("lane_edge").size.x, ly)])    # ragged start of the grey road
		x += lw
	lane.items.append([_src("lane_home"), Vector2(player_x + float(layout.lane.home_x), ly)])
	# soil below the tile, for views taller than the tile
	lane.fills.append([Rect2(-3000, ly + _src("lane").size.y - 1.0, length + 8000, 400), Color("6a4e38")])

func live_update(_boss_on: bool, _boss_x: float, _core: bool, _linked: bool, _exposed: float, _dt: float) -> void:
	pass

func present(camera: float, zoom: float, device_scale: float, seconds: float) -> void:
	for i in layers.size():
		var shift := Raster.layer_origin(camera, factors[i], zoom, device_scale)
		if drifts[i] != 0.0: shift += Raster.world_position(-seconds * drifts[i], zoom, device_scale)
		layers[i].position.x = shift
