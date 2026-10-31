extends Node
## 03-art: render the ui_title logos with the real renderer at integer scales 1/2/3
## (SubViewport 360*s wide portrait-ish strip, 2D override 360 wide = a 360 dp phone width),
## plus the app-icon candidates (raw PNGs, copied into res://branding/ by the runner).

var _jobs := []
var _frames := 0


func _ready() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlases/ui_title.json"))
	var tex: Texture2D = load("res://assets/atlases/ui_title.png")
	for s in [1, 2, 3]:
		var vp := SubViewport.new()
		vp.size = Vector2i(360 * s, 220 * s)
		vp.size_2d_override = Vector2i(360, 220)
		vp.size_2d_override_stretch = true
		vp.snap_2d_transforms_to_pixel = true
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = Color8(40, 44, 58)
		bg.size = Vector2(360, 220)
		vp.add_child(bg)
		var y := 4.0
		var layout := []
		for name in ["logo_title_ko", "logo_title_en", "logo_title_ko_2line", "logo_title_en_2line"]:
			var f: Dictionary = doc["frames"][name]
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f["x"], f["y"], f["w"], f["h"])
			var sp := Sprite2D.new()
			sp.texture = at
			sp.centered = false
			sp.position = Vector2(roundf((360.0 - float(f["w"])) / 2.0), y)
			vp.add_child(sp)
			layout.append([name, sp.position.x, y, f["w"], f["h"]])
			y += float(f["h"]) + 4.0
		_jobs.append([s, vp, layout])
	var ic := []
	for px in [48, 96, 192]:
		var t: Texture2D = load("res://branding/app_icon_candidate_%d.png" % px)
		ic.append([px, t != null, t.get_width() if t else 0])
	_jobs.append(["icons", null, ic])


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 6:
		var dir := OS.get_user_data_dir() + "/title"
		DirAccess.make_dir_recursive_absolute(dir)
		var rep := {"renders": [], "window_screen": DisplayServer.window_get_current_screen(),
			"primary_screen": DisplayServer.get_primary_screen()}
		for j in _jobs:
			if j[0] is String:
				rep["icons"] = j[2]
				continue
			j[1].get_texture().get_image().save_png("%s/title_%dx.png" % [dir, j[0]])
			rep["renders"].append({"scale": j[0], "layout": j[2]})
		var fa := FileAccess.open(dir + "/report.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(rep))
		fa.close()
		print("ART_TITLE_JSON " + JSON.stringify(rep))
		get_tree().quit(0)
