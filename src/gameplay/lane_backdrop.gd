extends Node2D
## Six cached scenery planes. One original village texture supplies material detail;
## simple geometry supplies sky, fields and a clear combat lane. No extra viewports.
const Raster := preload("res://src/gameplay/pixel_camera.gd")
var layers: Array[Node2D] = []
var village_texture: Texture2D
var factors := [0.0, 0.08, 0.22, 0.4, 0.68, 1.0]

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

func build(length: float, ground: float, _biome: String) -> void:
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
	for i in range(-8, int(length / 170.0) + 12):
		var x := float(i * 170)
		var h := float(22 + posmod(i * 37, 43))
		var y := ground - 100
		hills.poly(PackedVector2Array([Vector2(x-40,y+25),Vector2(x+24,y-h),Vector2(x+68,y-h-9),Vector2(x+147,y+16),Vector2(x+202,y+34)]),Color("86a69a"))
		hills.poly(PackedVector2Array([Vector2(x+8,y+29),Vector2(x+84,y-h+20),Vector2(x+154,y+10),Vector2(x+196,y+37)]),Color("a1b8a0"))
	var fields = layers[3]
	fields.box(Rect2(-1000,ground-102,length+3000,110),Color("9eae78"))
	for i in range(-5, int(length / 120.0) + 10):
		var x := float(i * 120)
		var y := ground - 77.0
		fields.poly(PackedVector2Array([Vector2(x,y),Vector2(x+36,y-14),Vector2(x+140,y-14),Vector2(x+112,y+30)]),Color("d3bd79"))
		for row in 4:
			fields.box(Rect2(x+10+row*4,y-4+row*6,91-row*7,2),Color("b5a66c"))
		fields.box(Rect2(x+113,y-4,3,39),Color("6d855e"))
		fields.box(Rect2(x+109,y-17,11,19),Color("799367"))
	# Chapter landmarks are baked into the existing field mesh, with no new textures/draw passes.
	if _biome == "biome_orchard":
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
	if ResourceLoader.exists(village_path):
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
	var lane = layers[5]
	# Clear, low-detail walking lane; the farm reads as a separate plane above it.
	lane.box(Rect2(-450,ground-14,length+1000,10),Color("91a06a"))
	lane.box(Rect2(-450,ground-4,length+1000,13),Color("c9bd9f"))
	lane.box(Rect2(-450,ground+9,length+1000,170),Color("9c805e"))
	lane.box(Rect2(-450,ground+9,length+1000,3),Color("64583f"))
	for i in range(-12,int(length/42.0)+15):
		var x := float(i*42)
		lane.box(Rect2(x,ground+16+posmod(i*19,35),9+posmod(i*7,10),2),Color("897354"))
		lane.box(Rect2(x+11,ground-9,3,6),Color("b7a77d"))
		if _biome == "biome_frost" and i%2 == 0:
			lane.box(Rect2(x-2,ground-14,25,3),Color("d6e3e5"))
	# Distinct route landmarks, never a wallpaper of identical doors.
	for fraction in [0.25,0.5,0.76]:
		var x: float = length * fraction
		lane.box(Rect2(x,ground-34,3,31),Color("685641"))
		lane.poly(PackedVector2Array([Vector2(x-7,ground-33),Vector2(x+16,ground-33),Vector2(x+23,ground-27),Vector2(x+16,ground-21),Vector2(x-7,ground-21)]),Color("b59560"))
	# Encroaching mold at the far end: large readable growths rather than noisy pixels.
	for i in 9:
		var x := length * 0.72 + i * length * 0.029
		lane.box(Rect2(x,ground-17,3,14),Color("5d7771"))
		lane.poly(PackedVector2Array([Vector2(x-8,ground-17),Vector2(x-5,ground-24),Vector2(x+6,ground-24),Vector2(x+11,ground-17)]),Color("82958a"))
	for i in layers.size():
		var layer = layers[i]
		if layer is Shapes: layer.bake()
		if _biome == "biome_orchard":
			layer.modulate = Color("e3d0a8") if i < 3 else Color("d9c3a2")
		elif _biome == "biome_frost":
			layer.modulate = Color("a8bddc") if i < 3 else Color("a9bfd1")

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
	for i in layers.size():
		var shift := Raster.layer_origin(camera, factors[i], zoom, device_scale)
		if i == 1: shift += Raster.world_position(-seconds * 1.3, zoom, device_scale)
		layers[i].position.x = shift
