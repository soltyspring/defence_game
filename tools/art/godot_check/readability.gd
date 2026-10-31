extends Node
## 03-art readability renders: draws res://scenes.json (written by tools/art/readability.py)
## with the real renderer. For every scene x background variant renders two SubViewports:
## 640x360 (1x) and 1280x720 with 2D override 640x360 (2x phone-like integer scale).
## Draw order = 02's battle_view: biome layers -> overlay -> units/projectiles/fx in list order.

var _spec: Dictionary
var _m: Dictionary
var _tex := {}
var _docs := {}
var _jobs := []
var _frames := 0


func _ready() -> void:
	_m = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	_spec = JSON.parse_string(FileAccess.get_file_as_string("res://scenes.json"))
	for a in _m["atlases"]:
		_tex[a["id"]] = load(a["image"])
		_docs[a["id"]] = JSON.parse_string(FileAccess.get_file_as_string(a["frames"]))
	for sc in _spec["scenes"]:
		for v in _spec["over"]:
			for s in [1, 2]:
				_jobs.append([sc, v, s, _make(sc, v, s)])


func _sprite(aid: String, fname: String, x: float, y: float, flip: bool) -> Sprite2D:
	var f: Dictionary = _docs[aid]["frames"][fname]
	var at := AtlasTexture.new()
	at.atlas = _tex[aid]
	at.region = Rect2(f["x"], f["y"], f["w"], f["h"])
	var sp := Sprite2D.new()
	sp.texture = at
	sp.centered = false
	sp.flip_h = flip
	var px: float = float(f["w"]) - float(f["pivot"][0]) if flip else float(f["pivot"][0])
	sp.position = Vector2(x - px, y - float(f["pivot"][1]))
	return sp


func _make(sc: String, v: String, s: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(640 * s, 360 * s)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.snap_2d_transforms_to_pixel = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bm: Dictionary = _m["biomes"]["biome_01"]
	var clear := ColorRect.new()
	clear.color = Color(str(bm["clear_color"]))
	clear.size = Vector2(640, 360)
	vp.add_child(clear)
	for L in bm["layers"]:
		var y: float = float(_spec["ground_y"]) - float(L["lane_line"]) if L.has("lane_line") else float(L["view_y"])
		var period := int(L.get("repeat_x", 640))
		var x := 0
		while x < 640:
			var sp := _sprite(bm["atlas"], L["frame"], 0, 0, false)
			sp.position = Vector2(x, y)
			vp.add_child(sp)
			x += period
	var ov = _spec["over"][v]
	if ov != null:
		var cr := ColorRect.new()
		cr.color = Color8(int(ov[0]), int(ov[1]), int(ov[2]), int(round(float(ov[3]) * 255.0)))
		cr.size = Vector2(640, 360)
		vp.add_child(cr)
	for d in _spec["scenes"][sc]:
		vp.add_child(_sprite(d["atlas"], d["frame"], d["x"], d["y"], d["flip"]))
	return vp


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 6:
		var dir := OS.get_user_data_dir() + "/readability"
		DirAccess.make_dir_recursive_absolute(dir)
		for j in _jobs:
			j[3].get_texture().get_image().save_png("%s/godot_%s_%s_%dx.png" % [dir, j[0], j[1], j[2]])
		var rep := {"renders": _jobs.size(), "window_screen": DisplayServer.window_get_current_screen(),
			"primary_screen": DisplayServer.get_primary_screen(), "dir": dir,
			"renderer": RenderingServer.get_video_adapter_name()}
		var fa := FileAccess.open(dir + "/report.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(rep))
		fa.close()
		print("ART_READ_JSON " + JSON.stringify(rep))
		get_tree().quit(0)
