extends Node2D
## 03-art: compare what Godot ACTUALLY samples for every atlas frame with the source PNG.
## For each manifest page: load the imported texture (what the game uses), read back every
## frame region (AtlasTexture.get_image) and compare pixel-exactly with the same rect of the
## raw PNG decoded from disk. Also renders a labelled contact sheet of all ui_main frames
## through the renderer and saves it (window on the secondary monitor; see check.gd).

var _frames := 0
var _report := {"pages": []}
var _sheet_ids := []


func _ready() -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	for a in m["atlases"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(a["frames"]))
		var tex: Texture2D = load(a["image"])
		var raw := Image.load_from_file(ProjectSettings.globalize_path(a["image"]))
		raw.convert(Image.FORMAT_RGBA8)
		var bad := []
		for name in doc["frames"]:
			var f: Dictionary = doc["frames"][name]
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f["x"], f["y"], f["w"], f["h"])
			var got := at.get_image()
			got.convert(Image.FORMAT_RGBA8)
			var want := raw.get_region(Rect2i(f["x"], f["y"], f["w"], f["h"]))
			if not _same_visible(got.get_data(), want.get_data()):
				bad.append(name)
		_report["pages"].append({"id": a["id"], "frames": doc["frames"].size(), "mismatch": bad.size(), "mismatch_sample": bad.slice(0, 8)})
		if a["id"] == "ui_main":
			_build_sheet(tex, doc)


## Equal if alpha matches everywhere and RGB matches wherever alpha > 0
## (import fix_alpha_border legitimately rewrites RGB of fully transparent texels).
func _same_visible(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	if a == b:
		return true
	var i := 0
	while i < a.size():
		if a[i + 3] != b[i + 3]:
			return false
		if a[i + 3] != 0 and (a[i] != b[i] or a[i + 1] != b[i + 1] or a[i + 2] != b[i + 2]):
			return false
		i += 4
	return true


func _build_sheet(tex: Texture2D, doc: Dictionary) -> void:
	var bg := ColorRect.new()
	bg.color = Color8(40, 44, 58)
	bg.size = Vector2(640, 360)
	add_child(bg)
	var names: Array = doc["frames"].keys()
	names.sort()
	var x := 2.0
	var y := 2.0
	var row_h := 0.0
	for n in names:
		var f: Dictionary = doc["frames"][n]
		var w := float(f["w"])
		var h := float(f["h"])
		if x + w + 2 > 638:
			x = 2.0
			y += row_h + 3
			row_h = 0.0
		var s := Sprite2D.new()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(f["x"], f["y"], w, h)
		s.texture = at
		s.centered = false
		s.position = Vector2(x, y)
		add_child(s)
		_sheet_ids.append([n, x, y, w, h])
		x += w + 3
		row_h = maxf(row_h, h)
	_report["sheet_items"] = _sheet_ids.size()


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 8:
		var dir := OS.get_user_data_dir()
		get_viewport().get_texture().get_image().save_png(dir + "/ui_main_godot_sheet.png")
		var fa := FileAccess.open(dir + "/ui_sheet_layout.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(_sheet_ids))
		fa.close()
		_report["window_screen"] = DisplayServer.window_get_current_screen()
		_report["primary_screen"] = DisplayServer.get_primary_screen()
		var fr := FileAccess.open(dir + "/ui_sheet_report.json", FileAccess.WRITE)
		fr.store_string(JSON.stringify(_report))
		fr.close()
		print("ART_UI_JSON " + JSON.stringify(_report))
		get_tree().quit(0)
