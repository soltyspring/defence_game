extends Node2D
## 03-art atlas check scene (runs in a throwaway copy of the project, see run_godot_check.ps1).
## 1) loads every atlas page + json the way the engine will (AtlasTexture regions)
## 2) builds a worst-case battle frame at the provisional entity caps
## 3) measures draw calls / texture memory over 120 frames, saves screenshots
##    (one at 1x, one zoomed 4x with sprites at fractional positions to expose bleeding)

const CAPS := {"ally": 30, "enemy": 40, "proj": 64, "fx": 32}
var _frames := 0
var _report := {}
var _cam: Camera2D
var _samples: Array = []
var _textures := {}
var _atlas_docs := {}


func _ready() -> void:
	_move_to_secondary_screen()
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	var pages := []
	for a in m["atlases"]:
		var tex: Texture2D = load(a["image"])
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(a["frames"]))
		_textures[a["id"]] = tex
		_atlas_docs[a["id"]] = doc
		pages.append({"id": a["id"], "loaded": tex != null, "size": [tex.get_width(), tex.get_height()] if tex else [],
			"size_ok": tex != null and tex.get_width() == int(a["size"][0]) and tex.get_height() == int(a["size"][1]),
			"frames": doc["frames"].size()})
	_report["pages"] = pages
	_build_scene(m)
	_cam = Camera2D.new()
	_cam.position = Vector2(320, 180)
	add_child(_cam)


func _move_to_secondary_screen() -> void:
	# QUALITY_REVIEW.md: visible test windows only on the secondary monitor.
	var primary := DisplayServer.get_primary_screen()
	var target := -1
	for i in DisplayServer.get_screen_count():
		if i != primary:
			target = i
			break
	_report["screens"] = []
	for i in DisplayServer.get_screen_count():
		_report["screens"].append({"index": i, "rect": DisplayServer.screen_get_usable_rect(i), "primary": i == primary})
	if target < 0:
		_report["secondary_blocked"] = true
		push_error("no secondary screen")
		get_tree().quit(3)
		return
	var r := DisplayServer.screen_get_usable_rect(target)
	var size := Vector2i(1280, 720)
	DisplayServer.window_set_current_screen(target)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(r.position + (r.size - size) / 2)


func _frame_tex(atlas_id: String, frame: String) -> AtlasTexture:
	var f: Dictionary = _atlas_docs[atlas_id]["frames"][frame]
	var at := AtlasTexture.new()
	at.atlas = _textures[atlas_id]
	at.region = Rect2(f["x"], f["y"], f["w"], f["h"])
	return at


func _sprite(atlas_id: String, frame: String, pos: Vector2, flip := false) -> Sprite2D:
	var f: Dictionary = _atlas_docs[atlas_id]["frames"][frame]
	var s := Sprite2D.new()
	s.texture = _frame_tex(atlas_id, frame)
	s.centered = false
	var px: float = f["pivot"][0]
	if flip:
		px = float(f["w"]) - px
	s.offset = -Vector2(px, f["pivot"][1])
	s.flip_h = flip
	s.position = pos
	return s


func _build_scene(m: Dictionary) -> void:
	var bm: Dictionary = m["biomes"]["biome_01"]
	var ground_y := 295.0
	for L in bm["layers"]:
		var y: float = L["view_y"]
		if L["frame"] == "ground":
			y = ground_y - float(L["lane_line"])
		var period: int = int(L.get("repeat_x", 640))
		var x := 0
		while x < 800:
			var s := _sprite(bm["atlas"], L["frame"], Vector2(x, y))
			s.offset = Vector2.ZERO
			add_child(s)
			x += period
	add_child(_sprite("bases", "base_player", Vector2(40, ground_y)))
	add_child(_sprite("bases", "base_enemy", Vector2(600, ground_y)))
	var units := Node2D.new()
	units.y_sort_enabled = true
	add_child(units)
	var ally := ["melee_basic", "ranged_basic", "tank", "worker"]
	var enemy := ["e_grunt", "e_swarm", "e_spitter"]
	for i in CAPS["ally"]:
		var sid: String = ally[i % ally.size()]
		units.add_child(_sprite("char_player", "%s/walk/%d" % [sid, i % 6 if sid != "tank" else i % 6], Vector2(120 + i * 7.5, ground_y + (i % 5) - 2)))
	units.add_child(_sprite("char_player", "hero_captain/attack/3", Vector2(330, ground_y)))
	for i in CAPS["enemy"]:
		var sid: String = enemy[i % enemy.size()]
		var n := 4 if sid == "e_swarm" else 6
		units.add_child(_sprite("char_enemy", "%s/walk/%d" % [sid, i % n], Vector2(340 + i * 6.5, ground_y + (i % 5) - 2), true))
	for i in CAPS["proj"]:
		units.add_child(_sprite("fx_combat", ["arrow/fly/0", "spit/fly/1", "rock/fly/2"][i % 3], Vector2(150 + i * 6.1, 230 + (i % 7) * 3.3)))
	for i in CAPS["fx"]:
		units.add_child(_sprite("fx_combat", ["hit_spark/play/2", "explosion/play/2", "death_poof/play/1", "skill_slam/play/2"][i % 4], Vector2(200 + i * 11.3, 270 + (i % 3) * 4)))
	_report["entities"] = {"units": CAPS["ally"] + CAPS["enemy"] + 1, "projectiles": CAPS["proj"], "fx": CAPS["fx"]}


func _process(_dt: float) -> void:
	_frames += 1
	if _frames > 10 and _frames <= 130:
		_samples.append({
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"tex_mem": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
			"vid_mem": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		})
	if _frames == 132:
		get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/battle_cap_1x.png")
		# fractional positions + zoom to expose any bleeding
		for c in get_children():
			if c is Node2D and c != _cam:
				c.position += Vector2(0.37, 0.61)
		_cam.zoom = Vector2(4, 4)
		_cam.position = Vector2(330, 280)
	if _frames == 140:
		get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/battle_cap_zoom4_fractional.png")
		_finish()


func _finish() -> void:
	var dc := []
	var obj := []
	for s in _samples:
		dc.append(s["draw_calls"])
		obj.append(s["objects"])
	dc.sort()
	_report["draw_calls"] = {"min": dc[0], "median": dc[dc.size() / 2], "max": dc[-1]}
	_report["objects_median"] = obj[obj.size() / 2]
	_report["texture_mem_bytes"] = _samples[-1]["tex_mem"]
	_report["video_mem_bytes"] = _samples[-1]["vid_mem"]
	_report["renderer"] = RenderingServer.get_video_adapter_name() + " / " + RenderingServer.get_video_adapter_api_version()
	_report["viewport"] = get_viewport().get_visible_rect().size
	_report["window_position"] = DisplayServer.window_get_position()
	_report["window_screen"] = DisplayServer.window_get_current_screen()
	_report["primary_screen"] = DisplayServer.get_primary_screen()
	_report["user_dir"] = OS.get_user_data_dir()
	print("ART_CHECK_JSON " + JSON.stringify(_report))
	get_tree().quit(0)
