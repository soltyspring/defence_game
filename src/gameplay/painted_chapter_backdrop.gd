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
## Plane 1 (clouds) also drifts with time in lane_backdrop.present().
const CLOUD_SPEED := 0.08
var factors := [0.0, CLOUD_SPEED, SCENERY_SPEED, 0.0, 1.0, 1.0]

class Strip extends Node2D:
	var texture: Texture2D
	var source := Rect2()
	var destination := Rect2()
	var length := 0.0
	var sky := Color.BLACK

	func _draw() -> void:
		var width := destination.size.x
		var edge := Rect2(0, 0, texture.get_width(), 4)
		for i in range(-3, int(ceil(length / width)) + 4):
			var tile := Rect2(destination.position + Vector2(i * width, 0), destination.size)
			draw_texture_rect_region(texture, tile, source)
			# The Sky plane continues above; the top row is repeated on every other line for a few pixels so clouds or
			# roots that touch the edge fade into it instead of ending on a hard line.
			for k in [1, 3, 6]:
				draw_texture_rect_region(texture, Rect2(tile.position.x, tile.position.y - k, width, 1), edge)

## Chapters drawn as caves: the space above the picture is a ceiling with hanging roots instead of sky with clouds.
const CAVES := [3, 7, 9]
const CAVE_GLOW := {3: "7fe6cf", 7: "f2c46a", 9: "c99cf2"}

## Plane 0: what taller views show above the 176-px picture (phones show ~270 world px, tablets ~380). The tile's
## top colour steps darker upward in 6 bands of 22 px with a checker seam between bands, then holds. Static on screen.
class SkyPlane extends Node2D:
	var top := 0.0          # world y of the picture's top row
	var sky := Color.BLACK
	var zenith := Color.BLACK
	var aurora := false
	var _bands: ImageTexture
	const BAND := 22
	const STEPS := 6
	const LEFT := -2048.0
	const SPAN := 8192.0

	func _ready() -> void:
		# one 4-px-wide strip of all bands with their checker seams, repeated across the view by the GPU
		var img := Image.create(4, BAND * STEPS, false, Image.FORMAT_RGBA8)
		for b in STEPS:
			var c := sky.lerp(zenith, float(STEPS - 1 - b) / float(STEPS))   # image row 0 is the top (darkest) band
			var lower := sky.lerp(zenith, float(STEPS - 2 - b) / float(STEPS)) if b < STEPS - 1 else c
			for y in BAND:
				for x in 4:
					var seam := b < STEPS - 1 and ((y == BAND - 1 and x % 2 == 0) or (y == BAND - 2 and x == 1))
					img.set_pixel(x, b * BAND + y, lower if seam else c)
		_bands = ImageTexture.create_from_image(img)
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var h := float(BAND * STEPS)
		draw_rect(Rect2(LEFT, top - 4000, SPAN, 4000 - h), zenith)
		if _bands != null:
			draw_texture_rect(_bands, Rect2(LEFT, top - h, SPAN, h), true)
		if aurora:
			for i in range(int(LEFT / 8.0), int((LEFT + SPAN) / 8.0)):
				var x := float(i) * 8.0
				var wave := roundf(sin(x * 0.012) * 9.0 + sin(x * 0.031) * 4.0)
				draw_rect(Rect2(x, top - 118 + wave, 8, 6), Color(0.55, 0.95, 0.75, 0.28))
				draw_rect(Rect2(x, top - 124 + wave, 8, 6), Color(0.95, 0.65, 0.9, 0.2))

## Plane 1: pixel clouds in the upper sky, or roots hanging from the cave ceiling with a glowing tip.
class CloudPlane extends Node2D:
	var top := 0.0
	var sky := Color.BLACK
	var zenith := Color.BLACK
	var cave := false
	var glow := Color.WHITE
	var items: Array = []

	func setup(seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var x := -3000.0
		while x < 12000.0:
			if cave:
				items.append([roundf(x), rng.randi_range(10, 120), rng.randi_range(3, 7), rng.randf() < 0.55, rng.randi() % 997])
				x += rng.randf_range(16.0, 52.0)
			else:
				items.append([roundf(x), rng.randi_range(24, 150), rng.randi_range(22, 54), rng.randi_range(7, 13)])
				x += rng.randf_range(120.0, 300.0)

	func _draw() -> void:
		if cave:
			# thick roots that wiggle in 10-px steps, a lit left edge, a knot now and then and a glowing bud at the tip
			var root := zenith.darkened(0.3)
			var lit := root.lightened(0.22)
			for it in items:
				var x0: float = it[0]
				var end_y: float = top - float(it[1])
				var w: int = it[2]
				var seed: int = it[4]
				var y := end_y - 600.0
				while y < end_y:
					var step := minf(10.0, end_y - y)
					var wiggle := float(posmod(int(y) / 10 + seed, 5) - 2)
					var taper := w if end_y - y > 24.0 else maxi(2, w - 2)
					draw_rect(Rect2(x0 + wiggle, y, taper, step), root)
					draw_rect(Rect2(x0 + wiggle, y, 1, step), lit)
					if posmod(int(y) / 10 + seed, 7) == 0:
						draw_rect(Rect2(x0 + wiggle - 2, y + 3, taper + 4, 3), root)
					y += step
				var tip_x := x0 + float(posmod(int(end_y) / 10 + seed, 5) - 2)
				if it[3]:
					draw_rect(Rect2(tip_x - 2, end_y - 1, w + 4, 6), glow.darkened(0.35))
					draw_rect(Rect2(tip_x - 1, end_y, w + 2, 4), glow)
					draw_rect(Rect2(tip_x, end_y + 1, 2, 2), glow.lightened(0.5))
			return
		var light := sky.lightened(0.62).lerp(Color("fff3e2"), 0.35)
		var shade := sky.lightened(0.3)
		for it in items:
			var cx: float = it[0]
			var base: float = top - float(it[1])
			var w: int = it[2]
			var h: int = it[3]
			# three lumps on one flat bottom: centre tallest
			for lump in [[-0.28, 0.55, 0.62], [0.0, 1.0, 0.5], [0.3, 0.7, 0.56]]:
				var lx: float = cx + roundf(float(lump[0]) * w)
				var lh: int = maxi(3, int(roundf(h * float(lump[1]))))
				var lw: float = w * float(lump[2])
				for row in lh:
					var t := float(row + 1) / float(lh)
					var half := floorf(lw * 0.5 * sqrt(maxf(0.0, 1.0 - (1.0 - t) * (1.0 - t))) + 0.5)
					draw_rect(Rect2(lx - half, base - lh + row, half * 2, 1), shade if row >= lh - 2 else light)

## Ground colour of each tile just above the road (sampled from the PNGs) and the small things that grow there.
## Main colour of each tile's top row (sampled from the PNGs): fills taller views above the picture.
const SKY_TOP := ["7fa3d2", "9da7df", "79aee8", "4a6b62", "95bafd", "9cd5c9", "97b8fc", "9f6f54", "7091e5", "4d4f81"]
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

	func _dome(x: float, w: int, h: int, body: Color, light: Color, dark: Color, style := "leaf") -> void:
		# A mound on the road edge, drawn row by row as runs of one colour: a 1-px outline, a lit upper-left, a shaded
		# lower-right. "leaf" gets a lumpy edge and leaf speckles, "stone" a few chips, "snow" a smooth crest and glints.
		var seed := int(absf(x)) * 7 + w
		var lumps := [0, 1, 0, -1, 1, 0, 1, -1] if style == "leaf" else ([0, 0, 1, 0, -1, 0] if style == "stone" else [0])
		var shade := body.darkened(0.16)
		for row in h:
			var t := float(row + 1) / float(h)      # 0 at the crown, 1 on the ground
			var half := floorf(w * 0.5 * sqrt(maxf(0.0, 1.0 - (1.0 - t) * (1.0 - t))) + 0.5)
			if row < h - 2: half = maxf(0.0, half + float(lumps[(row + seed) % lumps.size()]))
			var y := top - h + row
			_px(x - half - 1, y, half * 2 + 2, 1, dark)
			var run_start := x - half
			var run_colour := Color(0, 0, 0, 0)
			var px := x - half
			while px <= x + half:
				var c := body
				if px < x + half:
					var u := (px - x) / maxf(1.0, half)          # -1 left edge .. 1 right edge
					if style == "snow":
						if row <= 1 and u < 0.5: c = light
						elif u > 0.35 and t > 0.45: c = shade
						elif (int(px) * 5 + row * 3 + seed) % 23 == 0: c = light
					else:
						var n := (int(px) * 3 + row * 5 + seed) % 7
						if u < -0.05 and t < 0.6 and n != 0 and (style == "leaf" or n < 4): c = light
						elif u > 0.3 and t > 0.4: c = shade
						if style == "leaf" and n == 0 and row > 0: c = dark.lerp(body, 0.45)
						elif style == "stone" and n == 3 and row > 1 and u > -0.4: c = shade.darkened(0.2)
				else:
					c = Color(0, 0, 0, 0)                       # flush the last run
				if c != run_colour:
					if px > run_start and run_colour.a > 0.0:
						_px(run_start, y, px - run_start, 1, run_colour)
					run_start = px
					run_colour = c
				px += 1.0

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
					_dome(x, 12 + s * 3, 7 + s * 2, r, r.lightened(0.25), r.darkened(0.5), "stone")
					if chapter in [2, 6]: _px(x - 4 - s, top - 8 - s * 2, 8 + s * 2, 2, Color("f4f7ff"))
				"block":
					var r := Color("9aa0b4")
					_px(x - 8, top - 11, 17, 11, r.darkened(0.45))
					_px(x - 7, top - 10, 15, 10, r)
					_px(x - 7, top - 10, 15, 3, Color("eef3ff"))
					_px(x + 3, top - 7, 4, 7, r.darkened(0.15))
				"mound":
					var snow := g.lightened(0.45)
					_dome(x, 22 + s * 6, 7 + s * 2, snow, Color("ffffff"), g.darkened(0.25), "snow")
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
	scenery.sky = Color(SKY_TOP[chapter])
	# Put the main landmarks behind the early combat area.
	scenery.destination = Rect2(Vector2(-size.x * 0.35, top - size.y), size)
	var road := Road.new()
	road.top = top
	road.length = length
	road.palette = ROAD_PALETTES[chapter]
	var sky_colour := Color(SKY_TOP[chapter])
	var zenith := sky_colour.darkened(0.36 if chapter == 8 else 0.24)
	var sky_plane := SkyPlane.new()
	sky_plane.top = top - size.y
	sky_plane.sky = sky_colour
	sky_plane.zenith = zenith
	sky_plane.aurora = chapter == 8
	var cloud_plane := CloudPlane.new()
	cloud_plane.top = top - size.y
	cloud_plane.sky = sky_colour
	cloud_plane.zenith = zenith
	cloud_plane.cave = chapter in CAVES
	cloud_plane.glow = Color(CAVE_GLOW.get(chapter, "ffffff"))
	cloud_plane.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cloud_plane.setup(7300 + chapter)
	var props := Props.new()
	props.top = top
	props.length = length
	props.chapter = chapter
	props.setup()
	# Keep the six-plane contract used by the battle renderer and boss tint.
	for i in 6:
		var layer: Node2D = sky_plane if i == 0 else cloud_plane if i == 1 else scenery if i == 2 else props if i == 4 			else road if i == 5 else Node2D.new()
		add_child(layer)
		layers.append(layer)
	return true
