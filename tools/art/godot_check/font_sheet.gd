extends Node
## 03-art font sheet: renders the shipped fonts with the REAL Godot renderer into
## SubViewports that emulate devices (canvas_items stretch: device-size viewport,
## 640x360-based 2D override, aspect expand). Saves one PNG per device + a JSON
## report with glyph-cache texture usage. Run via tools/art/run_godot_font_sheet.ps1.

const DEVICES := [
	{"id": "d1_640x360_1x", "size": Vector2i(640, 360)},
	{"id": "d2_1280x720_2x", "size": Vector2i(1280, 720)},
	{"id": "d3_2400x1080_3x", "size": Vector2i(2400, 1080)},
	{"id": "d4_1600x900_2.5x", "size": Vector2i(1600, 900)},
	{"id": "d5_2560x1600_4.44x", "size": Vector2i(2560, 1600)},
]
# [font file, px sizes]; native multiples first, then 04's current UiStyle sizes 9/18/28
const SPECS := [
	["Galmuri11.ttf", [12, 24]],
	["Galmuri11-Bold.ttf", [12, 24]],
	["Galmuri9.ttf", [10, 20]],
	["Galmuri11.ttf", [9, 18, 28]],
]
var _vps := []
var _fonts := {}
var _frames := 0
var _report := {"devices": [], "fonts": {}}
var _ko := {}


func _ready() -> void:
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/text/ko.json"))
	_ko = t.get("strings", {})
	for spec in SPECS:
		_font(spec[0])
	for d in DEVICES:
		_vps.append(_make_vp(d))


func _font(file: String) -> FontFile:
	if _fonts.has(file):
		return _fonts[file]
	var f: FontFile = load("res://assets/fonts/" + file)
	# pixel-font rendering rules (also requested as importer defaults from 02)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.multichannel_signed_distance_field = false
	f.generate_mipmaps = false
	f.allow_system_fallback = false
	_fonts[file] = f
	return f


func _s(key: String, fallback: String) -> String:
	var v = _ko.get(key, fallback)
	return v if v is String else fallback


func _make_vp(d: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = d["size"]
	var ref_h := 360.0
	var scale: float = float(d["size"].y) / ref_h
	if float(d["size"].x) / scale < 640.0:
		scale = float(d["size"].x) / 640.0
	var ref := Vector2(float(d["size"].x) / scale, float(d["size"].y) / scale)
	vp.size_2d_override = Vector2i(ref.round())
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.snap_2d_transforms_to_pixel = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color8(31, 47, 107)
	bg.size = ref
	vp.add_child(bg)
	var y := 4.0
	var sample_ko := "%s · %s · %s" % [_s("ui.victory", "승리!"), _s("ui.retry", "다시하기"), _s("ui.select_round", "라운드 선택")]
	var sample_long := _s("tut_move_hero", "◀ ▶ 버튼을 누르고 있으면 영웅이 움직입니다.")
	var sample_num := "0123456789 +12.5/s 999/999 x2 Wave 3/10 ★★☆"
	for spec in SPECS:
		for px in spec[1]:
			var lab := Label.new()
			lab.add_theme_font_override("font", _font(spec[0]))
			lab.add_theme_font_size_override("font_size", px)
			lab.add_theme_color_override("font_color", Color8(242, 246, 248))
			lab.add_theme_color_override("font_outline_color", Color8(27, 19, 37))
			lab.add_theme_constant_override("outline_size", 0)
			if spec[0] == "Galmuri9.ttf":
				lab.text = "%s %dpx  %s  Lv.12 HP 420/600 99+" % [spec[0].get_basename(), px, sample_num]
			else:
				lab.text = "%s %dpx  %s  %s  %s" % [spec[0].get_basename(), px, sample_ko, sample_num, sample_long]
			lab.position = Vector2(4, y)
			lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			vp.add_child(lab)
			y += px + 3
	_report["devices"].append({"id": d["id"], "device_px": [d["size"].x, d["size"].y], "ref_view": [ref.x, ref.y], "scale": scale})
	return vp


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 6:
		var outdir := OS.get_user_data_dir() + "/font_sheet"
		DirAccess.make_dir_recursive_absolute(outdir)
		for i in _vps.size():
			var img: Image = _vps[i].get_texture().get_image()
			img.save_png("%s/%s.png" % [outdir, DEVICES[i]["id"]])
		for file in _fonts:
			var f: FontFile = _fonts[file]
			var caches := []
			var tex_bytes := 0
			for ci in f.get_cache_count():
				for sz in f.get_size_cache_list(ci):
					var n := f.get_texture_count(ci, sz)
					for ti in n:
						var im := f.get_texture_image(ci, sz, ti)
						if im:
							tex_bytes += im.get_width() * im.get_height() * (2 if im.get_format() == Image.FORMAT_LA8 else 4 if im.get_format() == Image.FORMAT_RGBA8 else 1)
							caches.append({"size": [sz.x, sz.y], "tex": [im.get_width(), im.get_height()], "format": im.get_format()})
			_report["fonts"][file] = {"cache_textures": caches, "cache_bytes_est": tex_bytes}
		_report["out_dir"] = outdir
		print("ART_FONT_JSON " + JSON.stringify(_report))
		get_tree().quit(0)
