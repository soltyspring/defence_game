extends Node2D
## Painted chapter backgrounds for R01-R100, with cached geometry as an import
## fallback. The six-plane API and live boss cues are shared by both paths.
const Raster := preload("res://src/gameplay/pixel_camera.gd")
const Painted := preload("res://src/gameplay/painted_chapter_backdrop.gd")
var painted: Node2D
var layers: Array[Node2D] = []
var village_texture: Texture2D
var factors := [0.0, 0.08, 0.22, 0.4, 0.68, 1.0]
## v2 lane set (tools/art/world/lane_set.py, docs/art/fable52/STYLE_RULES.md): bakery town by the keep, open field,
## mould thicket by the nest. Used when the sheet is imported; otherwise the v1 painted panorama below.
const SET_PATH := "res://assets/backgrounds/lane_set_v2.png"
const SET_HOME := Rect2(0, 0, 320, 108)
const SET_BLIGHT := Rect2(0, 112, 320, 108)
const SET_MILL := Rect2(324, 0, 112, 112)
var set_texture: Texture2D
var v2 := false
## Per-round scene (backdrop_scenes.gd). Empty = the generic meadow build below (rounds outside R01-R40, tests).
const Scenes := preload("res://src/gameplay/backdrop_scenes.gd")
var scene := {}
var live: Live
var _tension := 0.0            # 0..1 eased: a boss is on the field
var _tension_target := 0.0
var _mods: Array = []          # per layer: modulate without tension
var _last_seconds := -1.0

## Drawn every frame while a boss is alive, world-locked, behind the units. Nothing here sits at foot height (the
## pale ground band is reserved for announced attacks) and nothing depends on screen shake.
##   arrival   0.9 s: two pale bars run out along the ridge line from where the boss stands. No input is held.
##   core (a boss with `link_break`, R40): linked = violet strands from the ceiling with beads running down into it
##             and a hood above it; exposed = the strands hang cut and a pale shaft of light stands on the boss. The
##             shaft narrows as the exposure runs out, so its width is the time left to attack.
class Live extends Node2D:
	var ground := 290.0
	var core := false
	var boss_on := false
	var boss_x := 0.0
	var linked := false
	var exposed := 0.0
	var exposed_max := 0.0
	var enter_t := 0.0
	var t := 0.0
	var state := ""            # QA: "" | "linked" | "exposed" | "open"
	func _draw() -> void:
		if not boss_on:
			return
		if enter_t > 0.0:
			var a := enter_t / 0.9
			var w := 40.0 + 260.0 * (1.0 - a)
			draw_rect(Rect2(boss_x - w, ground - 108.0, w * 2.0, 3.0), Color(1.0, 0.96, 0.8, 0.7 * a))
			draw_rect(Rect2(boss_x - w * 0.6, ground - 116.0, w * 1.2, 2.0), Color(1.0, 0.96, 0.8, 0.5 * a))
		if not core:
			return
		var xs := [boss_x - 27.0, boss_x + 4.0, boss_x + 30.0]
		if linked:
			draw_rect(Rect2(boss_x - 46.0, ground - 150.0, 92.0, 12.0), Color("8f7fd6"))
			for i in 3:
				draw_rect(Rect2(xs[i], ground - 150.0, 4.0, 86.0 - i * 6.0), Color("8f7fd6"))
				var ph := fposmod(t * 0.9 + i * 0.37, 1.0)
				draw_rect(Rect2(xs[i] - 2.0, ground - 150.0 + ph * (78.0 - i * 6.0), 8.0, 8.0), Color("d9d2ea"))
		elif exposed > 0.0:
			var k := clampf(exposed / maxf(0.1, exposed_max), 0.0, 1.0)
			var half := 12.0 + 36.0 * k
			draw_colored_polygon(PackedVector2Array([Vector2(boss_x - half * 0.5, ground - 150.0), Vector2(boss_x + half * 0.5, ground - 150.0),
				Vector2(boss_x + half, ground - 48.0), Vector2(boss_x - half, ground - 48.0)]), Color(1.0, 0.94, 0.69, 0.45))
			draw_colored_polygon(PackedVector2Array([Vector2(boss_x - half * 0.25, ground - 150.0), Vector2(boss_x + half * 0.25, ground - 150.0),
				Vector2(boss_x + half * 0.5, ground - 48.0), Vector2(boss_x - half * 0.5, ground - 48.0)]), Color(1.0, 0.97, 0.82, 0.5))
			for i in 3:
				draw_rect(Rect2(xs[i], ground - 150.0, 4.0, 12.0 + i * 5.0), Color("b9b3ba"))
		else:
			for i in 3:
				draw_rect(Rect2(xs[i], ground - 150.0, 4.0, 12.0 + i * 5.0), Color("b9b3ba"))

class SetPieces extends Node2D:
	var texture: Texture2D
	var items: Array = []   # [source Rect2, world position Vector2]
	func _draw() -> void:
		for item in items:
			var src: Rect2 = item[0]
			draw_texture_rect_region(texture, Rect2(item[1], src.size), src)

class Panorama extends Node2D:
	var texture: Texture2D
	var length := 1800.0
	var ground := 290.0
	func _draw() -> void:
		# Keep the raw generated alpha asset. Crop transparent margins at draw time;
		# a 4:1 integer reduction keeps the artwork on the world's pixel grid.
		var source := Rect2(0, 128, 2172, 496)
		var ratio := float(texture.get_width()) / 2172.0
		source = Rect2(source.position * ratio, source.size * ratio)
		for i in range(-2, int(length / 735.0) + 3):
			var x := float(i * 735 - 130)
			var cold := clampf((x / length - 0.4) / 0.5, 0.0, 1.0)
			var tint := Color("dce4d0").lerp(Color("7a9990"), cold)
			tint.a = 0.82
			var dest := Rect2(x, ground - 142, 543, 124)
			if posmod(i, 2):
				draw_set_transform(Vector2(x + 543, 0),0,Vector2(-1,1))
				dest.position.x = 0
			draw_texture_rect_region(texture, dest, source, tint)
			draw_set_transform(Vector2.ZERO)

class Shapes extends Node2D:
	var commands: Array = []
	var mesh: ArrayMesh
	func box(rect: Rect2, color: Color) -> void:
		commands.append([0, rect, color])
	func poly(points: PackedVector2Array, color: Color) -> void:
		commands.append([1, points, color])
	func _draw() -> void:
		if mesh: draw_mesh(mesh, null)
	func bake() -> void:
		var vertices := PackedVector3Array()
		var colors := PackedColorArray()
		for command in commands:
			var points := PackedVector2Array()
			if command[0] == 0:
				var r: Rect2 = command[1]
				points = PackedVector2Array([r.position, Vector2(r.end.x,r.position.y), r.end, Vector2(r.position.x,r.end.y)])
			else: points = command[1]
			var indices := Geometry2D.triangulate_polygon(points)
			for index in indices:
				vertices.append(Vector3(points[index].x, points[index].y, 0))
				colors.append(command[2])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh = ArrayMesh.new()
		if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		commands.clear()
		queue_redraw()

func build(length: float, ground: float, _biome: String, player_x := 40.0, enemy_x := -1.0, round_index := 0) -> void:
	if enemy_x < 0.0: enemy_x = length - 40.0
	v2 = ResourceLoader.exists(SET_PATH)
	if v2:
		set_texture = load(SET_PATH)
		factors[4] = 1.0   # set pieces are world-locked: they frame the two bases
	scene = Scenes.spec(round_index)
	if round_index >= 1 and round_index <= Painted.NAMES.size() * 10:
		var art := Painted.new()
		if art.build(length, ground, round_index):
			painted = art
			add_child(art)
			layers = art.layers
			factors = art.factors
			for layer in layers: _mods.append(layer.modulate)
			live = Live.new()
			live.ground = ground
			add_child(live)
			return
		art.free()
	if not scene.is_empty():
		_build_scene(length, ground, _biome, player_x, enemy_x)
		return
	for i in factors.size():
		var layer := Shapes.new()
		add_child(layer)
		layers.append(layer)
	var sky = layers[0]
	var sky_colors := [Color("80adca"), Color("9ec2d4"), Color("bcd6dd"), Color("d8e2d6")]
	for i in 4:
		sky.box(Rect2(-2000, ground - 800 + i * 170, length + 6000, 174), sky_colors[i])
	sky.box(Rect2(-2000, ground - 120, length + 6000, 300), sky_colors[3])
	var clouds = layers[1]
	for i in range(-4, int(length / 180.0) + 8):
		var x := float(i * 180 + posmod(i * 71, 80))
		var y := ground - 205 - posmod(i * 19, 45)
		clouds.box(Rect2(x,y,55,8),Color("c6d9df"))
		clouds.box(Rect2(x+7,y-7,40,9),Color("edf0df"))
		clouds.box(Rect2(x+18,y-12,20,7),Color("edf0df"))
	var hills = layers[2]
	var hill_span := 235 if v2 else 170
	for i in range(-8, int(length / float(hill_span)) + 12):
		var x := float(i * hill_span)
		var h := float(22 + posmod(i * 37, 43))
		var y := ground - 100
		if v2:
			# Broad, overlapping ridges. Lower crests leave the wave timer over calm sky.
			hills.poly(PackedVector2Array([Vector2(x-45,y+18),Vector2(x-14,y-3),Vector2(x+25,y-h*0.45),Vector2(x+72,y-h*0.62),Vector2(x+116,y-h*0.57),Vector2(x+176,y-h*0.26),Vector2(x+253,y+10),Vector2(x+269,y+28)]),Color("9ab5a9"))
			hills.poly(PackedVector2Array([Vector2(x+12,y+23),Vector2(x+57,y+4),Vector2(x+111,y-h*0.22),Vector2(x+155,y-h*0.26),Vector2(x+211,y-2),Vector2(x+263,y+21),Vector2(x+270,y+31)]),Color("aec2a6"))
		else:
			hills.poly(PackedVector2Array([Vector2(x-40,y+25),Vector2(x+24,y-h),Vector2(x+68,y-h-9),Vector2(x+147,y+16),Vector2(x+202,y+34)]),Color("86a69a"))
			hills.poly(PackedVector2Array([Vector2(x+8,y+29),Vector2(x+84,y-h+20),Vector2(x+154,y+10),Vector2(x+196,y+37)]),Color("a1b8a0"))
	var fields = layers[3]
	fields.box(Rect2(-1000,ground-102,length+3000,110),Color("9eae78"))
	if v2:
		# One broad wheat band and sparse sheaves instead of furrows and posts every 120 px.
		fields.box(Rect2(-1000,ground-88,length+3000,34),Color("cdbf85"))
		fields.box(Rect2(-1000,ground-88,length+3000,3),Color("ddd09a"))
		for i in range(-1, int(length * 0.4 / 420.0) + 3):
			var sx := float(i * 420 + 150)
			fields.box(Rect2(sx,ground-66,12,12),Color("b7a468"))
			fields.box(Rect2(sx+2,ground-70,8,4),Color("c9b877"))
		# The blight takes the far fields in two flat steps; slanted edges read as terrain, not as a seam.
		var far := length + 3000.0
		for step in [[0.4 * 0.58 * length + 130.0, "9aa888", "bcb992"], [0.4 * 0.8 * length + 190.0, "93a290", "a9b09c"]]:
			var b: float = step[0]
			fields.poly(PackedVector2Array([Vector2(b+70,ground-102),Vector2(far,ground-102),Vector2(far,ground+8),Vector2(b,ground+8)]),Color(str(step[1])))
			fields.poly(PackedVector2Array([Vector2(b+61,ground-88),Vector2(far,ground-88),Vector2(far,ground-54),Vector2(b+39,ground-54)]),Color(str(step[2])))
	for i in range(-5, (int(length / 120.0) + 10) if not v2 else -5):
		var x := float(i * 120)
		var y := ground - 77.0
		fields.poly(PackedVector2Array([Vector2(x,y),Vector2(x+36,y-14),Vector2(x+140,y-14),Vector2(x+112,y+30)]),Color("d3bd79"))
		for row in 4:
			fields.box(Rect2(x+10+row*4,y-4+row*6,91-row*7,2),Color("b5a66c"))
		fields.box(Rect2(x+113,y-4,3,39),Color("6d855e"))
		fields.box(Rect2(x+109,y-17,11,19),Color("799367"))
	# Chapter landmarks are baked into the existing field mesh, with no new textures/draw passes.
	if v2:
		_chapter_landmark(fields, length, ground, _biome)
	elif _biome == "biome_orchard":
		for i in range(-1,int(length/155.0)+2):
			var x := float(i*155+44)
			var y := ground-40.0
			_tree(fields,x,y,false)
			for d in [Vector2(-9,-38),Vector2(6,-45),Vector2(1,-29)]:
				fields.box(Rect2(Vector2(x,y)+d,Vector2(5,5)),Color("b96d4c"))
	elif _biome == "biome_frost":
		for i in range(-2,int(length/130.0)+3):
			var x := float(i*130)
			fields.poly(PackedVector2Array([Vector2(x,ground-50),Vector2(x+24,ground-62),Vector2(x+73,ground-60),Vector2(x+103,ground-47)]),Color("e0e9e4"))
			fields.box(Rect2(x+18,ground-49,66,3),Color("c8d9df"))
	var village = layers[4]
	var village_path := "res://assets/backgrounds/village_panorama_v1.png"
	if v2:
		var pieces := SetPieces.new()
		pieces.texture = set_texture
		pieces.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pieces.items = [[SET_HOME, Vector2(player_x + 52.0, ground - 12.0 - 107.0)], [SET_BLIGHT, Vector2(enemy_x - 250.0, ground - 12.0 - 107.0)]]
		add_child(pieces)
		move_child(pieces, 4)
		layers[4] = pieces
		village.queue_free()
	elif ResourceLoader.exists(village_path):
		var panorama := Panorama.new()
		village_texture = load(village_path)
		panorama.texture = village_texture
		panorama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panorama.length = length
		panorama.ground = ground
		add_child(panorama)
		move_child(panorama, 4)
		layers[4] = panorama
		village.queue_free()
	else:
		# Readable fallback also keeps source-only tests independent of image imports.
		for i in range(-2, int(length / 180.0) + 3):
			var x := float(i * 180 + 25)
			var y := ground - 18.0
			var dark := x > length * 0.67
			_house(village, x, y, 68 + posmod(i*31,35), 41 + posmod(i*17,25), posmod(i,4), dark)
			if i % 3 == 0: _tree(village, x+132, y, dark)
			elif i % 3 == 1: _well(village,x+126,y)
	_paint_lane(layers[5], length, ground, _biome, player_x, enemy_x)
	for i in layers.size():
		var layer = layers[i]
		if layer is Shapes: layer.bake()
		if _biome == "biome_orchard":
			layer.modulate = Color("e3d0a8") if i < 3 else Color("d9c3a2")
		elif _biome == "biome_frost":
			layer.modulate = Color("a8bddc") if i < 3 else Color("a9bfd1")
		elif _biome == "biome_nest":
			# Challenge chapter (R31-R40): the same layers under a dim grey-teal cast; no new texture.
			layer.modulate = Color("9fb3ac") if i < 3 else Color("94a9a2")

## R01-R40: sky, ridge, field and set planes from the round's scene; the walking lane keeps its earlier look.
func _build_scene(length: float, ground: float, biome: String, player_x: float, enemy_x: float) -> void:
	factors[4] = 1.0
	var pal: Dictionary = scene.pal
	var ch: int = scene.chapter
	for i in factors.size():
		var layer := Shapes.new()
		add_child(layer)
		layers.append(layer)
	var far := length + 6000.0
	# sky: the two lower bands sit just above the ridge so the time of day also shows at 2x zoom
	var sky = layers[0]
	var sc: Array = scene.sky
	sky.box(Rect2(-2000, ground - 900, far, 702), sc[0])
	sky.box(Rect2(-2000, ground - 198, far, 36), sc[1])
	sky.box(Rect2(-2000, ground - 162, far, 30), sc[2])
	sky.box(Rect2(-2000, ground - 132, far, 320), sc[3])
	var clouds = layers[1]
	if ch == 3:
		# under ground: a ceiling instead of clouds, with uneven lobes hanging from it
		clouds.box(Rect2(-2000, ground - 900, far, 760), Color(str(pal.cloud_lo)))
		for i in range(-6, int(length / 90.0) + 10):
			var cx := float(i * 90 + posmod(i * 53, 40))
			var cw := 34.0 + float(posmod(i * 17, 30))
			clouds.poly(PackedVector2Array([Vector2(cx, ground - 141), Vector2(cx + cw, ground - 141), Vector2(cx + cw * 0.7, ground - 129 + posmod(i * 7, 6)), Vector2(cx + cw * 0.3, ground - 127 + posmod(i * 5, 5))]), Color(str(pal.cloud_lo)))
	else:
		# fewer, lower clouds as each chapter goes on
		var every := 1 + int(float(scene.stage) * 2.0)
		for i in range(-4, int(length / 180.0) + 8):
			if posmod(i, every) != 0: continue
			var x := float(i * 180 + posmod(i * 71, 80))
			var y := ground - 128 - posmod(i * 19, 24)
			clouds.box(Rect2(x, y, 55, 8), Color(str(pal.cloud_lo)))
			clouds.box(Rect2(x + 7, y - 7, 40, 9), Color(str(pal.cloud)))
			clouds.box(Rect2(x + 18, y - 12, 20, 7), Color(str(pal.cloud)))
	var hills = layers[2]
	var ridge_y := ground - 100.0
	if ch == 3:
		# the back wall of the tunnel: two flat bands, no horizon
		hills.box(Rect2(-2000, ground - 150, far, 70), Color(str(pal.ridge_a)))
		hills.box(Rect2(-2000, ground - 112, far, 40), Color(str(pal.ridge_b)))
	elif ch != 2:
		var span := 235 if ch == 0 else 310
		for i in range(-8, int(length / float(span)) + 12):
			var x := float(i * span)
			var h := float(22 + posmod(i * 37, 43)) * (1.0 if ch == 0 else 0.6)
			hills.poly(PackedVector2Array([Vector2(x-45,ridge_y+18),Vector2(x-14,ridge_y-3),Vector2(x+25,ridge_y-h*0.45),Vector2(x+72,ridge_y-h*0.62),Vector2(x+116,ridge_y-h*0.57),Vector2(x+176,ridge_y-h*0.26),Vector2(x+253,ridge_y+10),Vector2(x+269,ridge_y+28)]),Color(str(pal.ridge_a)))
			hills.poly(PackedVector2Array([Vector2(x+12,ridge_y+23),Vector2(x+57,ridge_y+4),Vector2(x+111,ridge_y-h*0.22),Vector2(x+155,ridge_y-h*0.26),Vector2(x+211,ridge_y-2),Vector2(x+263,ridge_y+21),Vector2(x+270,ridge_y+31)]),Color(str(pal.ridge_b)))
	else:
		hills.box(Rect2(-2000, ridge_y - 4, far, 40), Color(str(pal.ridge_b)))
	var fields = layers[3]
	fields.box(Rect2(-1000, ground - 102, length + 3000, 110), Color(str(pal.field)))
	fields.box(Rect2(-1000, ground - 88, length + 3000, 34), Color(str(pal.band)))
	fields.box(Rect2(-1000, ground - 88, length + 3000, 3), Color(str(pal.band_hi)))
	match ch:
		0:
			for i in range(-1, int(length * 0.4 / 420.0) + 3):
				var sx := float(i * 420 + 150)
				fields.box(Rect2(sx, ground - 66, 12, 12), Color("b7a468"))
				fields.box(Rect2(sx + 2, ground - 70, 8, 4), Color("c9b877"))
			# the blight takes the far fields in two flat steps; it starts earlier as the chapter goes on
			var lead: float = lerpf(0.0, 0.22, float(scene.stage))
			for step in [[0.4 * (0.58 - lead) * length + 130.0, "9aa888", "bcb992"], [0.4 * (0.8 - lead) * length + 190.0, "93a290", "a9b09c"]]:
				var b: float = step[0]
				fields.poly(PackedVector2Array([Vector2(b+70,ground-102),Vector2(far,ground-102),Vector2(far,ground+8),Vector2(b,ground+8)]),Color(str(step[1])))
				fields.poly(PackedVector2Array([Vector2(b+61,ground-88),Vector2(far,ground-88),Vector2(far,ground-54),Vector2(b+39,ground-54)]),Color(str(step[2])))
		1:
			# windfall rows in the dry grass: short uneven dashes above the unit band
			for i in range(-2, int(length * 0.4 / 150.0) + 4):
				var wx := float(i * 150 + posmod(i * 41, 70))
				fields.box(Rect2(wx, ground - 62, 22 + posmod(i * 13, 18), 4), Color("a2965e"))
				if float(scene.stage) < 0.5: fields.box(Rect2(wx + 8, ground - 66, 5, 5), Color("cf8f62"))
		2:
			# snow lies in drifts on the upper field only; the strip behind the units stays mid-tone
			for i in range(-2, int(length * 0.4 / 130.0) + 4):
				var dx := float(i * 130 + posmod(i * 29, 60))
				fields.poly(PackedVector2Array([Vector2(dx, ground - 86), Vector2(dx + 22, ground - 96), Vector2(dx + 70, ground - 94), Vector2(dx + 100, ground - 86)]), Color("dfe8ea"))
		3:
			# floor ridges of the tunnel, uneven
			for i in range(-2, int(length * 0.4 / 170.0) + 4):
				var fx := float(i * 170 + posmod(i * 37, 80))
				fields.poly(PackedVector2Array([Vector2(fx, ground - 54), Vector2(fx + 18, ground - 64), Vector2(fx + 60, ground - 62), Vector2(fx + 84, ground - 54)]), Color(str(pal.band_hi)))
	var near = layers[4]
	var pieces: SetPieces = null
	if v2:
		pieces = SetPieces.new()
		pieces.texture = set_texture
		pieces.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# chapters 1-3 keep the bakery town by the keep; under ground a forward camp stands there instead.
		if ch < 3: pieces.items.append([SET_HOME, Vector2(player_x + 52.0, ground - 12.0 - 107.0)])
		# the mould thicket frames the enemy base until the road reaches a built place (ice works, nest wall)
		if ch < 2 or (ch == 2 and int(scene.index) < 27): pieces.items.append([SET_BLIGHT, Vector2(enemy_x - 250.0, ground - 12.0 - 107.0)])
	var has_enemy_piece := false
	for lm in scene.landmarks:
		var kind := str(lm[0])
		var plane := str(lm[1])
		var k: float = float(lm[4]) if lm.size() > 4 else 1.0
		match plane:
			"far": Scenes.paint(hills, kind, 0.22 * float(lm[2]) * length, ridge_y + 2.0, lm[3], k)
			"mid": Scenes.paint(fields, kind, 0.4 * float(lm[2]) * length, ground - 54.0, lm[3], k)
			"near": Scenes.paint(near, kind, float(lm[2]) * length, ground - 12.0, lm[3], k)
			"home": Scenes.paint(near, kind, player_x + float(lm[2]), ground - 12.0, lm[3], k)
			"enemy":
				has_enemy_piece = true
				Scenes.paint(near, kind, enemy_x + float(lm[2]), ground - 12.0, lm[3], k)
	if ch == 3 and not has_enemy_piece:
		Scenes.paint(near, "knot_wall", enemy_x - 150.0, ground - 12.0, 1, 0.9)
	if pieces != null:
		add_child(pieces)
		move_child(pieces, 5)       # above the painted near plane, below the lane
	_paint_lane(layers[5], length, ground, biome, player_x, enemy_x)
	var light: Color = scene.light
	var home_tint := [Color.WHITE, Color("f0e2c4"), Color("cfd8e6"), Color.WHITE]
	for i in layers.size():
		var layer = layers[i]
		layer.bake()
		layer.modulate = Color(str(pal.lane_tint)) if i == 5 else (light if i >= 1 else Color.WHITE)
		_mods.append(layer.modulate)
	if pieces != null: pieces.modulate = home_tint[ch] * light
	live = Live.new()
	live.ground = ground
	add_child(live)

## Called every frame by the battle view. `core` = the boss can be linked and exposed (unit key `link_break`).
func live_update(boss_on: bool, boss_x: float, core: bool, linked: bool, exposed: float, dt: float) -> void:
	_tension_target = 1.0 if boss_on else 0.0
	if live == null:
		return
	if boss_on and not live.boss_on: live.enter_t = 0.9
	live.boss_on = boss_on
	live.boss_x = boss_x
	live.core = core
	live.linked = linked
	if exposed > live.exposed + 0.05: live.exposed_max = exposed      # a new opening began
	live.exposed = exposed
	live.enter_t = maxf(0.0, live.enter_t - dt)
	live.t += dt
	live.state = "" if not (boss_on and core) else ("linked" if linked else ("exposed" if exposed > 0.0 else "open"))
	live.visible = boss_on
	if boss_on: live.queue_redraw()

## The walking lane (verge, path, soil), the two base aprons, route signposts and the mould near the nest.
func _paint_lane(lane, length: float, ground: float, _biome: String, player_x: float, enemy_x: float) -> void:
	# Clear, low-detail walking lane; the farm reads as a separate plane above it.
	lane.box(Rect2(-450,ground-14,length+1000,10),Color("91a06a"))
	lane.box(Rect2(-450,ground-4,length+1000,13),Color("c9bd9f"))
	lane.box(Rect2(-450,ground+9,length+1000,170),Color("9c805e"))
	lane.box(Rect2(-450,ground+9,length+1000,3),Color("64583f"))
	for i in range(-12,int(length/42.0)+15):
		var x := float(i*42)
		lane.box(Rect2(x,ground+16+posmod(i*19,35),9+posmod(i*7,10),2),Color("897354"))
		if not v2: lane.box(Rect2(x+11,ground-9,3,6),Color("b7a77d"))
		if _biome == "biome_frost" and i%2 == 0:
			# Rime on the verge. It sits at foot height, so it stays close to the verge colour: the pale danger
			# marker must be the only light band on the ground (was d6e3e5, which read as marker pieces).
			lane.box(Rect2(x-2,ground-14,25,3),Color("b4c2b0") if v2 else Color("d6e3e5"))
	if v2:
		# Verge and path cool in two steps towards the nest; a light forecourt and a dark creep apron mark the bases.
		lane.box(Rect2(0.6*length,ground-14,length,10),Color("8d9c7c"))
		lane.box(Rect2(0.8*length,ground-14,length,10),Color("869687"))
		lane.box(Rect2(0.8*length,ground-4,length,13),Color("bdb7a3"))
		lane.box(Rect2(player_x-78,ground-4,190,13),Color("ddd2b2"))
		lane.box(Rect2(player_x-78,ground-4,190,2),Color("ece3c8"))
		for apron in [[-150.0,"9fa998"],[-112.0,"8b9b90"],[-74.0,"778b84"]]:
			var ax: float = enemy_x + float(apron[0])
			lane.poly(PackedVector2Array([Vector2(ax,ground+9),Vector2(ax+22,ground-4),Vector2(enemy_x+80,ground-4),Vector2(enemy_x+80,ground+9)]),Color(str(apron[1])))
		for dx in [-112.0,-74.0,-30.0]:
			lane.box(Rect2(enemy_x+dx,ground+1,3,3),Color("c6d6cb"))
	# Distinct route landmarks, never a wallpaper of identical doors.
	for fraction in ([0.3,0.55] if v2 else [0.25,0.5,0.76]):
		var x: float = length * fraction
		lane.box(Rect2(x,ground-34,3,31),Color("685641"))
		lane.poly(PackedVector2Array([Vector2(x-7,ground-33),Vector2(x+16,ground-33),Vector2(x+23,ground-27),Vector2(x+16,ground-21),Vector2(x-7,ground-21)]),Color("b59560"))
	# Encroaching mold at the far end: large readable growths rather than noisy pixels.
	if v2:
		# Uneven spacing and heights: growth, not a fence.
		for growth in [[0.70,12.0],[0.745,17.0],[0.80,14.0],[0.83,22.0],[0.875,16.0],[0.90,26.0]]:
			var gx: float = length * float(growth[0])
			var gh: float = growth[1]
			lane.box(Rect2(gx,ground-3-gh,3,gh),Color("5d7771"))
			lane.poly(PackedVector2Array([Vector2(gx-8,ground-3-gh),Vector2(gx-5,ground-10-gh),Vector2(gx+6,ground-10-gh),Vector2(gx+11,ground-3-gh)]),Color("82958a"))
	for i in (0 if v2 else 9):
		var x := length * 0.72 + i * length * 0.029
		lane.box(Rect2(x,ground-17,3,14),Color("5d7771"))
		lane.poly(PackedVector2Array([Vector2(x-8,ground-17),Vector2(x-5,ground-24),Vector2(x+6,ground-24),Vector2(x+11,ground-17)]),Color("82958a"))

## A single silhouette per chapter. Keep the shapes above the unit band and
## bake them into the field mesh so all three chapters share the same sheet.
func _chapter_landmark(field: Shapes, length: float, ground: float, biome: String) -> void:
	var x := roundf(length * 0.4 * 0.48 + 140.0)
	var y := ground - 57.0
	match biome:
		"biome_01", "biome_meadow":
			# A distant grain shelter and uneven windbreak add scale without competing with troops.
			field.box(Rect2(x-49, y-30, 52, 28), Color("c4b58a"))
			field.poly(PackedVector2Array([Vector2(x-57,y-30), Vector2(x-39,y-47), Vector2(x-8,y-47), Vector2(x+10,y-30)]), Color("bcaa7e"))
			field.box(Rect2(x-36, y-19, 17, 17), Color("b7aa7e"))
			field.poly(PackedVector2Array([Vector2(x+20,y-2), Vector2(x+21,y-22), Vector2(x+34,y-35), Vector2(x+51,y-38), Vector2(x+70,y-29), Vector2(x+78,y-32), Vector2(x+97,y-21), Vector2(x+106,y-2)]), Color("a9b585"))
		"biome_orchard":
			# Harvest orchard: a single cluster with staggered canopies, not a repeating row.
			for tree in [Vector2(-47, -4), Vector2(0, -13), Vector2(54, 0)]:
				var o: Vector2 = Vector2(x, y) + tree
				field.box(Rect2(o + Vector2(-4, -34), Vector2(8, 34)), Color("af9b75"))
				field.poly(PackedVector2Array([o + Vector2(-29,-27), o + Vector2(-27,-47), o + Vector2(-14,-59), o + Vector2(9,-63), o + Vector2(28,-49), o + Vector2(30,-30), o + Vector2(13,-23), o + Vector2(-14,-22)]), Color("b7bc87"))
				field.box(Rect2(o + Vector2(-19,-47), Vector2(24, 8)), Color("c9c990"))
				for fruit in [Vector2(-13,-36), Vector2(2,-50), Vector2(17,-37)]:
					field.box(Rect2(o + fruit, Vector2(5, 5)), Color("cc986e"))
		"biome_frost":
			# Frost road: a broken frozen arch, with a clear opening even in silhouette.
			field.poly(PackedVector2Array([Vector2(x-77,y), Vector2(x-64,y-44), Vector2(x-43,y-69), Vector2(x-10,y-71), Vector2(x-18,y-52), Vector2(x-38,y-50), Vector2(x-53,y-27), Vector2(x-54,y)]), Color("b5cbcd"))
			field.poly(PackedVector2Array([Vector2(x+28,y), Vector2(x+22,y-32), Vector2(x+12,y-48), Vector2(x+24,y-55), Vector2(x+47,y-35), Vector2(x+58,y)]), Color("aabfc6"))
			field.poly(PackedVector2Array([Vector2(x-65,y-45), Vector2(x-44,y-70), Vector2(x-10,y-72), Vector2(x-15,y-61), Vector2(x-42,y-61)]), Color("e3ebe4"))
			field.box(Rect2(x-92, y, 170, 6), Color("d6e0df"))

func _house(layer, x: float, y: float, w: float, h: float, kind: int, dark: bool) -> void:
	var wall := Color("a4aca3") if dark else Color("dacbad")
	var roof: Color = Color("5e766f") if dark else [Color("9c6049"),Color("75846a"),Color("ae8056"),Color("7f7471")][kind]
	layer.box(Rect2(x-3,y-h-3,w+6,h+4),Color("756956"))
	layer.box(Rect2(x,y-h,w,h),wall)
	layer.poly(PackedVector2Array([Vector2(x-8,y-h),Vector2(x+12,y-h-22),Vector2(x+w-12,y-h-22),Vector2(x+w+8,y-h)]),roof)
	layer.box(Rect2(x+8,y-h-35,9,20),Color("837f6b"))
	layer.box(Rect2(x+6,y-h-36,13,4),Color("686451"))
	layer.box(Rect2(x+7,y-h+3,w-14,3),Color("89775b"))
	layer.box(Rect2(x+w*0.5-7,y-24,14,24),Color("6f6553"))
	for side in [9.0,w-24.0]:
		layer.box(Rect2(x+side,y-h+13,15,19),Color("6d7f7b"))
		layer.box(Rect2(x+side+2,y-h+15,5,12),Color("bdc7b3"))
		layer.box(Rect2(x+side+9,y-h+15,4,12),Color("9fb4ad"))
	if kind == 0 and not dark:
		layer.box(Rect2(x+w*0.5-21,y-30,42,7),Color("e0d3ae"))
		for stripe in 4: layer.box(Rect2(x+w*0.5-20+stripe*11,y-30,5,7),Color("ad7756"))
		layer.box(Rect2(x+w-12,y-6,18,6),Color("b2905c"))
	elif kind == 2:
		layer.box(Rect2(x+w+3,y-12,20,12),Color("9c8159"))
		layer.box(Rect2(x+w+5,y-17,7,7),Color("c5aa70"))

func _tree(layer, x: float, y: float, dark: bool) -> void:
	layer.box(Rect2(x-3,y-36,6,36),Color("6d6b50"))
	var c := Color("738c80") if dark else Color("7a996e")
	layer.poly(PackedVector2Array([Vector2(x-24,y-29),Vector2(x-20,y-53),Vector2(x-7,y-65),Vector2(x+12,y-61),Vector2(x+25,y-40),Vector2(x+19,y-25)]),c)
	layer.box(Rect2(x-15,y-52,21,7),c.lightened(0.1))

func _well(layer, x: float, y: float) -> void:
	layer.box(Rect2(x-13,y-14,26,14),Color("999784"))
	layer.box(Rect2(x-16,y-17,32,5),Color("bbb6a0"))
	for side in [-12,12]: layer.box(Rect2(x+side,y-44,3,28),Color("7b654a"))
	layer.poly(PackedVector2Array([Vector2(x-21,y-44),Vector2(x,y-57),Vector2(x+21,y-44)]),Color("9d7550"))

func present(camera: float, zoom: float, device_scale: float, seconds: float) -> void:
	# A boss on the field: sky, clouds, ridge and field shift towards the chapter's tension colour within ~0.8 s and back
	# when it falls. The lane, the set pieces and every marker keep their colours.
	if not _mods.is_empty() and not is_equal_approx(_tension, _tension_target):
		var dt := clampf(seconds - _last_seconds, 0.0, 0.1) if _last_seconds >= 0.0 else 0.0
		_tension = move_toward(_tension, _tension_target, dt / 0.8)
		var tint := Color(str(scene.pal.tension)) if not scene.is_empty() else Color("d1c9d9")
		for i in 4:
			layers[i].modulate = (_mods[i] as Color).lerp((_mods[i] as Color) * tint, _tension)
	_last_seconds = seconds
	for i in layers.size():
		var shift := Raster.layer_origin(camera, factors[i], zoom, device_scale)
		if i == 1: shift += Raster.world_position(-seconds * 1.3, zoom, device_scale)
		layers[i].position.x = shift
