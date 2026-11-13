extends Node2D
## One background tile per chapter, repeated without flips. Each 4×4 source
## block occupies one world pixel; the road is drawn independently of the art.
const DIR := "res://assets/backgrounds/chapter_tile_layers/"
const NAMES := [
	"meadow", "orchard", "frost", "nest", "frost_quarry", "spore_marsh",
	"frozen_bastion", "root_vault", "aurora_pass", "mould_heart",
]
## Logical rows cut from the bottom of each tile. R01-R40 end in 36 quiet rows (keep 16 above the road);
## R41-R100 (docs/art/release_slice/bg_regen) end in their own ground, which meets the road directly.
const TRIM_GROUND_ROWS := [20, 20, 20, 20, 0, 0, 0, 0, 0, 0]
const ROAD_PALETTES := [
	["a18c5e", "c1a878", "967c55", "675340", "776045"],
	["8d7858", "ae8b65", "886b50", "53463a", "6a5543"],
	["879eb4", "bac9d4", "96aabc", "4b5c6e", "5e7284"],
	["657164", "899081", "6c7668", "414c47", "515d53"],
	["8494a5", "b6c1cc", "95a5b4", "4a5562", "5c6a77"],
	["5f7267", "879b87", "738375", "3b4b43", "4b5e53"],
	["8193a9", "afc1d2", "91a6bc", "47576b", "596c81"],
	["8a7254", "a88d68", "7c6448", "4c3d30", "5f4c3a"],
	["6b839c", "9fb6ca", "829cb4", "3b4c62", "50657b"],
	["646772", "8a8591", "746e7c", "3b3743", "514752"],
]

var chapter := 0
var texture: Texture2D
var layers: Array[Node2D] = []
## Scenery at 55 % of the camera speed: close enough to read as the land beside the road (0.28 read as the horizon).
const SCENERY_SPEED := 0.55
var factors := [0.0, 0.0, SCENERY_SPEED, 0.0, 1.0, 1.0]

class Strip extends Node2D:
	var texture: Texture2D
	var source := Rect2()
	var destination := Rect2()
	var length := 0.0

	func _draw() -> void:
		var width := destination.size.x
		var edge := Rect2(0, 0, texture.get_width(), 4)
		for i in range(-3, int(ceil(length / width)) + 4):
			var tile := Rect2(destination.position + Vector2(i * width, 0), destination.size)
			draw_texture_rect_region(texture, tile, source)
			# Continue the top row in taller views. The first sky row joins exactly.
			draw_texture_rect_region(texture, Rect2(tile.position.x, tile.position.y - 1024, width, 1024), edge)

## Ground colour of each tile just above the road (sampled from the PNGs) and the small things that grow there.
const PROP_GROUND := ["7f8c52", "81824c", "7faedb", "54837e", "b4c9fb", "90ac68", "b6c7fc", "a4b160", "aec3fa", "52767c"]
const PROP_KINDS := [
	["bush", "tuft", "flower", "rock", "tuft"], ["bush", "tuft", "rock", "flower", "tuft"],
	["mound", "tuft", "rock", "mound"], ["mushroom", "tuft", "rock", "tuft"],
	["mound", "block", "tuft", "mound"], ["reed", "mushroom", "bush", "tuft"],
	["mound", "rock", "tuft", "mound"], ["root", "flower", "bush", "tuft"],
	["mound", "ice", "tuft", "mound"], ["mushroom", "crystal", "tuft", "mushroom"],
]
const AUTUMN_BUSH := "a8743a"

## Near plane: small pixel props on the strip of land right above the road, world-locked like the units. They give
## the eye a step between the fighters and the scenery, so the background no longer reads as the far horizon.
class Props extends Node2D:
	var top := 0.0
	var length := 0.0
	var chapter := 0
	var items: Array = []      # [kind, x, size 0..2]

	func setup() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + chapter
		var kinds: Array = PROP_KINDS[chapter]
		var x := -1024.0
		while x < length + 1024.0:
			items.append([kinds[rng.randi() % kinds.size()], roundf(x), rng.randi() % 3])
			if rng.randf() < 0.35:
				items.append(["tuft", roundf(x + rng.randf_range(8.0, 14.0)), rng.randi() % 3])
			x += rng.randf_range(22.0, 52.0)

	func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(x, y, w, h), c)

	func _dome(x: float, w: int, h: int, body: Color, light: Color, dark: Color) -> void:
		# a rounded mound standing on the road edge: outline, body, a lit upper-left and a shaded lower-right
		for row in h:
			var t := float(row + 1) / float(h)      # 0 at the crown, 1 on the ground
			var half := floorf(w * 0.5 * sqrt(maxf(0.0, 1.0 - (1.0 - t) * (1.0 - t))) + 0.5)
			var y := top - h + row
			_px(x - half - 1, y, half * 2 + 2, 1, dark)
			if half > 0: _px(x - half, y, half * 2, 1, body)
			if row * 2 < h and half > 1: _px(x - half, y, maxf(1, half - 1), 1, light)

	func _draw() -> void:
		var g := Color(PROP_GROUND[chapter])
		var dark := g.darkened(0.5)
		var leaf := Color(AUTUMN_BUSH) if chapter == 1 else g.darkened(0.18)
		for it in items:
			var x: float = it[1]
			var s: int = it[2]
			match str(it[0]):
				"bush":
					_dome(x, 18 + s * 5, 10 + s * 2, leaf, leaf.lightened(0.22), leaf.darkened(0.45))
				"tuft":
					var c := g.darkened(0.32)
					for b in 4 + s:
						var h := 4 + (b % 2) * 3 + s
						_px(x + b * 2 - 3, top - h, 1, h, c)
				"flower":
					var c := g.darkened(0.32)
					_px(x, top - 7, 1, 7, c)
					_px(x + 4, top - 5, 1, 5, c)
					_px(x - 1, top - 9, 3, 3, Color("f2b6c4") if s != 1 else Color("f7e3a1"))
					_px(x + 3, top - 7, 3, 3, Color("ffffff"))
				"rock":
					var r := Color("8e877c").lerp(g, 0.25)
					_dome(x, 12 + s * 3, 7 + s * 2, r, r.lightened(0.25), r.darkened(0.5))
					if chapter in [2, 6]: _px(x - 4 - s, top - 8 - s * 2, 8 + s * 2, 2, Color("f4f7ff"))
				"block":
					var r := Color("9aa0b4")
					_px(x - 8, top - 11, 17, 11, r.darkened(0.45))
					_px(x - 7, top - 10, 15, 10, r)
					_px(x - 7, top - 10, 15, 3, Color("eef3ff"))
					_px(x + 3, top - 7, 4, 7, r.darkened(0.15))
				"mound":
					var snow := g.lightened(0.45)
					_dome(x, 22 + s * 6, 7 + s * 2, snow, Color("ffffff"), g.darkened(0.25))
				"mushroom":
					var cap := Color("efe2c4") if chapter != 9 else Color("e9d3ef")
					_px(x, top - 6 - s, 3, 6 + s, Color("e8dcc4").darkened(0.1))
					_px(x - 5, top - 11 - s, 13, 5, cap.darkened(0.45))
					_px(x - 4, top - 11 - s, 11, 4, cap)
					_px(x - 3, top - 11 - s, 4, 1, Color("ffffff"))
				"crystal":
					var c := Color("b48ce6")
					_px(x, top - 13 - s * 3, 4, 13 + s * 3, c.darkened(0.35))
					_px(x, top - 13 - s * 3, 2, 12 + s * 3, c.lightened(0.35))
					_px(x + 4, top - 7, 3, 7, c)
				"ice":
					var c := Color("bfe4ff")
					_px(x, top - 12 - s * 2, 5, 12 + s * 2, c.darkened(0.3))
					_px(x, top - 12 - s * 2, 3, 11 + s * 2, c)
					_px(x + 5, top - 6, 3, 6, c.darkened(0.15))
				"reed":
					var c := g.darkened(0.35)
					for b in 3 + s:
						_px(x + b * 3, top - 13 - (b % 2) * 2, 1, 13 + (b % 2) * 2, c)
					_px(x + 3, top - 17, 2, 5, Color("8a6440"))
				"root":
					var c := Color("8a6642")
					_px(x - 11, top - 5, 23, 5, c.darkened(0.4))
					_px(x - 10, top - 5, 21, 3, c)
					_px(x - 5, top - 7, 11, 2, c.darkened(0.4))
					_px(x - 8, top - 4, 6, 1, c.lightened(0.25))

class Road extends Node2D:
	var top := 0.0
	var length := 0.0
	var palette: Array = []

	func _draw() -> void:
		var left := -1024.0
		var span := length + 2048.0
		draw_rect(Rect2(left, top, span, 1024), Color(palette[3]))
		draw_rect(Rect2(left, top, span, 17), Color(palette[1]))
		draw_rect(Rect2(left, top, span, 2), Color(palette[0]))
		draw_rect(Rect2(left, top + 15, span, 2), Color(palette[2]))
		# Subtle wear marks on the road and a few strata below the walkable strip.
		for i in range(-30, int(length / 37.0) + 32):
			var x := float(i * 37 + posmod(i * 17, 14))
			draw_rect(Rect2(x, top + 3 + posmod(i * 11, 10), 3 + posmod(i * 7, 6), 1), Color(palette[0]))
			draw_rect(Rect2(x, top + 23 + posmod(i * 13, 42), 9 + posmod(i * 11, 20), 2), Color(palette[4]))

static func chapter_of(round_index: int) -> int:
	return clampi((maxi(round_index, 1) - 1) / 10, 0, NAMES.size() - 1)

static func path_for(round_index: int) -> String:
	return DIR + NAMES[chapter_of(round_index)] + ".png"

func build(length: float, ground: float, round_index: int) -> bool:
	chapter = chapter_of(round_index)
	var path := path_for(round_index)
	if not ResourceLoader.exists(path):
		return false
	texture = load(path) as Texture2D
	if texture == null:
		return false
	var source_size := Vector2(texture.get_size()) - Vector2(0, int(TRIM_GROUND_ROWS[chapter]) * 4)
	var size := source_size / 4.0
	var top := ground - 7.0
	var scenery := Strip.new()
	scenery.texture = texture
	scenery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scenery.source = Rect2(Vector2.ZERO, source_size)
	scenery.length = length
	# Put the main landmarks behind the early combat area.
	scenery.destination = Rect2(Vector2(-size.x * 0.35, top - size.y), size)
	var road := Road.new()
	road.top = top
	road.length = length
	road.palette = ROAD_PALETTES[chapter]
	var props := Props.new()
	props.top = top
	props.length = length
	props.chapter = chapter
	props.setup()
	# Keep the six-plane contract used by the battle renderer and boss tint.
	for i in 6:
		var layer: Node2D = scenery if i == 2 else props if i == 4 else road if i == 5 else Node2D.new()
		add_child(layer)
		layers.append(layer)
	return true
