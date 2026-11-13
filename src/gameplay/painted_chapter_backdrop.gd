extends Node2D
## Pixel art panoramas. Only the active chapter is loaded; the road stays
## world-locked while scenery moves at 28% camera speed. No runtime image edits.
const DIR := "res://assets/backgrounds/pixel_chapters/"
const NAMES := ["meadow", "orchard", "frost", "nest"]
const ART_HEIGHT := 220.0
## Authored road edge and foot line measured on each unmodified generated PNG.
const ROAD_EDGE := [0.791, 0.778, 0.803, 0.776]
const FOOT_LINE := [0.830, 0.826, 0.838, 0.808]
var chapter := 0
var texture: Texture2D
var layers: Array[Node2D] = []
var factors := [0.0, 0.0, 0.28, 0.0, 1.0, 1.0]

class Strip extends Node2D:
	var texture: Texture2D
	var source := Rect2()
	var destination := Rect2()
	var length := 0.0
	var upper := false
	func _draw() -> void:
		var width := destination.size.x
		# Adjacent tiles share the very same edge texels through reflection.
		for i in range(-3, int(ceil(length / width)) + 4):
			var x := float(i) * width
			var flip := posmod(i, 2) == 1
			draw_set_transform(Vector2(x + (width if flip else 0.0), 0.0), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
			draw_texture_rect_region(texture, destination, source)
			# Cover extreme aspect expansion, then reflect the full painted strip
			# at its vertical edge. Nearby sky/soil keeps its natural texture;
			# stretching a single edge row here would leave visible color streaks.
			var edge_y := 0.0 if upper else float(texture.get_height() - 1)
			var extension := Rect2(0.0, destination.position.y - 1600.0 if upper else destination.end.y, width, 1600.0)
			draw_texture_rect_region(texture, extension, Rect2(0.0, edge_y, texture.get_width(), 1.0))
			var boundary := destination.position.y if upper else destination.end.y
			draw_set_transform(Vector2(x + (width if flip else 0.0), boundary * 2.0), 0.0, Vector2(-1.0 if flip else 1.0, -1.0))
			draw_texture_rect_region(texture, destination, source)
		draw_set_transform(Vector2.ZERO)

static func chapter_of(round_index: int) -> int:
	return clampi((maxi(round_index, 1) - 1) / 10, 0, NAMES.size() - 1)

static func path_for(round_index: int) -> String:
	return DIR + NAMES[chapter_of(round_index)] + ".png"

func build(length: float, ground: float, round_index: int) -> bool:
	chapter = chapter_of(round_index)
	var path := path_for(round_index)
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null: texture = ImageTexture.create_from_image(image)
	if texture == null:
		return false
	var size := Vector2(texture.get_size())
	var width := ART_HEIGHT * size.x / size.y
	var cut := roundf(size.y * ROAD_EDGE[chapter])
	var top: float = ground - ART_HEIGHT * FOOT_LINE[chapter]
	var cut_y: float = top + ART_HEIGHT * cut / size.y
	# Keep the six-plane contract used by the battle renderer and boss tint.
	for i in 6:
		var layer: Node2D = Strip.new() if i == 2 or i == 5 else Node2D.new()
		add_child(layer)
		layers.append(layer)
		if layer is Strip:
			layer.texture = texture
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.length = length
			layer.upper = i == 2
			layer.source = Rect2(0, 0 if i == 2 else cut, size.x, cut if i == 2 else size.y - cut)
			layer.destination = Rect2(0, top if i == 2 else cut_y, width, cut_y - top if i == 2 else top + ART_HEIGHT - cut_y)
	return true
