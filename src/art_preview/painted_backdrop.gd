extends Node2D
## Release-slice preview backdrop on the relit painted panoramas (assets/art/release_slice/painted_relit/, made by
## tools/art/release_slice/relight.py from Codex's assets/backgrounds/painted_chapters/, which stay unmodified).
## Placement follows src/gameplay/painted_chapter_backdrop.gd (same measured road / foot lines, mirrored tiling, scenery
## at 28 % camera speed, road world-locked), plus the chapter's ambient life from slice_backdrop.gd.
## Same interface as lane_backdrop.gd: build() / present() / live_update(), v2, set_texture, SET_MILL.
const Raster := preload("res://src/gameplay/pixel_camera.gd")
const Slice := preload("res://src/art_preview/slice_backdrop.gd")
const DIR := "res://assets/art/release_slice/painted_relit/"
const NAMES := ["meadow", "orchard", "frost", "nest"]
const ART_HEIGHT := 220.0
## measured on the generated PNGs (values from painted_chapter_backdrop.gd)
const ROAD_EDGE := [0.775, 0.790, 0.820, 0.770]
const FOOT_LINE := [0.812, 0.820, 0.850, 0.805]
const SCENERY_SPEED := 0.28

class Strip extends Node2D:
	var texture: Texture2D
	var source := Rect2()
	var destination := Rect2()
	var length := 0.0
	var upper := false
	func _draw() -> void:
		var width := destination.size.x
		for i in range(-3, int(ceil(length / width)) + 4):
			var x := float(i) * width
			var flip := posmod(i, 2) == 1
			draw_set_transform(Vector2(x + (width if flip else 0.0), 0.0), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
			draw_texture_rect_region(texture, destination, source)
			var boundary := destination.position.y if upper else destination.end.y
			draw_set_transform(Vector2(x + (width if flip else 0.0), boundary * 2.0), 0.0, Vector2(-1.0 if flip else 1.0, -1.0))
			draw_texture_rect_region(texture, destination, source)
		draw_set_transform(Vector2.ZERO)

var layers: Array[Node2D] = []
var factors: Array[float] = []
var set_texture: Texture2D             # the R01 slice page: bakery_supply draws the mill from it
var village_texture: Texture2D = null
var v2 := true
var SET_MILL := Rect2()
var scene := {}
var live = null
var ambient = null

func _add(node: Node2D, factor: float) -> void:
	add_child(node)
	layers.append(node)
	factors.append(factor)

func build(length: float, ground: float, _biome: String, _player_x := 40.0, _enemy_x := -1.0, round_index := 0) -> bool:
	var chapter := clampi((maxi(round_index, 1) - 1) / 10, 0, NAMES.size() - 1)
	var tex: Texture2D = Slice.load_texture(DIR + NAMES[chapter] + ".png")
	if tex == null:
		return false
	set_texture = Slice.load_texture()
	var meta := Slice._json(Slice.ATLAS_JSON)
	var mill: Dictionary = meta.get("frames", {}).get("mill", {})
	SET_MILL = Rect2(float(mill.get("x", 0)), float(mill.get("y", 0)), float(mill.get("w", 0)), float(mill.get("h", 0)))
	var size := Vector2(tex.get_size())
	var width := ART_HEIGHT * size.x / size.y
	var cut := roundf(size.y * ROAD_EDGE[chapter])
	var top: float = ground - ART_HEIGHT * FOOT_LINE[chapter]
	var cut_y: float = top + ART_HEIGHT * cut / size.y
	var up := Strip.new()
	up.texture = tex
	up.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	up.length = length * SCENERY_SPEED + 640.0
	up.upper = true
	up.source = Rect2(0, 0, size.x, cut)
	up.destination = Rect2(0, top, width, cut_y - top)
	_add(up, SCENERY_SPEED)
	var amb = Slice.Ambient.new()
	amb.setup(chapter + 1, length, ground, float((round_index - 1) % 10) / 9.0 if round_index > 0 else 0.0)
	_add(amb, 1.0)
	ambient = amb
	var low := Strip.new()
	low.texture = tex
	low.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	low.length = length
	low.source = Rect2(0, cut, size.x, size.y - cut)
	low.destination = Rect2(0, cut_y, width, top + ART_HEIGHT - cut_y)
	_add(low, 1.0)
	return true

func live_update(_boss_on: bool, _boss_x: float, _core: bool, _linked: bool, _exposed: float, _dt: float) -> void:
	pass

func present(camera: float, zoom: float, device_scale: float, seconds: float) -> void:
	if ambient != null:
		ambient.t = seconds
		ambient.queue_redraw()
	for i in layers.size():
		layers[i].position.x = Raster.layer_origin(camera, factors[i], zoom, device_scale)
