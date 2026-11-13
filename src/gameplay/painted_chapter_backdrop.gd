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
var factors := [0.0, 0.0, 0.28, 0.0, 1.0, 1.0]

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
	# Keep the six-plane contract used by the battle renderer and boss tint.
	for i in 6:
		var layer := Node2D.new() if i != 2 and i != 5 else (scenery as Node2D if i == 2 else road as Node2D)
		add_child(layer)
		layers.append(layer)
	return true
