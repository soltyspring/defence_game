extends SceneTree
## 08-performance font cost probe: Galmuri glyph-cache memory and first-use hitch at the UI sizes.
## DESKTOP PROXY only (debug editor binary, desktop GPU); never phone evidence.
## Run windowed (glyph rasterisation + texture upload need a real renderer), secondary monitor via tools/perf/run_perf.ps1 -Font:
##   Godot_console.exe --screen <idx> --resolution 1280x720 --path . -s res://tests/performance/perf_font_probe.gd -- \
##       [--font-out=<abs.json>] [--font-reps=3] [--perf-contended=N]
## Each case uses a FRESH FontFile (ResourceLoader CACHE_MODE_IGNORE) so its glyph cache starts cold, with the same pixel flags
## that src/ui/ui_style.gd applies at load (antialiasing NONE, hinting NONE, subpixel off, no MSDF, no mipmaps, no system fallback).
## Per case it measures:
##   load_ms            ResourceLoader.load of the .ttf import (fontdata)
##   shape_cold_ms      first Font.get_string_size() on the text (shaping + glyph rasterisation into the cache, CPU)
##   shape_warm_ms      same call again (cache hit)
##   draw_first_frame_ms frame time of the first frame drawing a Label with that text on a fresh font (vs idle median)
##   warm_label_first_frame_ms  control: first frame of a NEW Label with the same text on the now-warm font (layout without
##                      glyph rasterisation); glyph_hitch_ms = draw_first_frame_ms - warm_label_first_frame_ms
##   cache              FontFile cache textures after drawing: count, sizes, format, bytes (exact, from get_texture_image)
##   tex_mem_delta      RENDER_TEXTURE_MEM_USED after - before (engine view)
## Text sets: ascii (HUD digits/Latin), ko_all (every string value in data/text/ko.json = all UI Korean text, 218 distinct syllables
## at 2026-10-31), ko_stress_1000 (1000 distinct syllables U+AC00.., synthetic upper bound for page growth).
## Sizes: allowed 12/24/36 (Galmuri11/Bold), 10/20 (Galmuri9 numerals) + control 18 (forbidden size, shows extra cache cost).
## Owner: 08-performance.

const FONTS := {
	"Galmuri11": "res://assets/fonts/Galmuri11.ttf",
	"Galmuri11-Bold": "res://assets/fonts/Galmuri11-Bold.ttf",
	"Galmuri9": "res://assets/fonts/Galmuri9.ttf",
}
const IDLE_FRAMES := 30
const AFTER_FRAMES := 4

var out_path := ""
var reps := 3
var contended := -1
var cases: Array = []
var results: Array = []
var texts := {}
var _host: Control
var _state := "boot"
var _ci := 0
var _rep := 0
var _frames := 0
var _idle := PackedFloat32Array()
var _after := PackedFloat32Array()
var _cur := {}
var _label: Label
var _font: FontFile
var _tex0 := 0
var _env := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--font-out="): out_path = a.get_slice("=", 1)
		elif a.begins_with("--font-reps="): reps = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--perf-contended="): contended = int(a.get_slice("=", 1))
	if out_path == "":
		out_path = ProjectSettings.globalize_path("res://build/perf/font_latest.json")
	_boot.call_deferred()

func _boot() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("perf_font_probe needs a window (no --headless)")
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	texts.ascii = "0123456789 /+-%:.,x 12/200 +12.5/s Wave 3/10 HP 1500 ★☆♥"
	texts.ko_all = _ko_text()
	var s := ""
	for i in 1000: s += char(0xAC00 + i)
	texts.ko_stress_1000 = s
	for f in ["Galmuri11", "Galmuri11-Bold"]:
		for sz in [12, 24, 36, 18]:
			cases.append({"font": f, "size": sz, "text": "ko_all", "allowed": sz != 18})
		cases.append({"font": f, "size": 12, "text": "ascii", "allowed": true})
	cases.append({"font": "Galmuri11", "size": 12, "text": "ko_stress_1000", "allowed": true})
	cases.append({"font": "Galmuri11", "size": 24, "text": "ko_stress_1000", "allowed": true})
	for sz in [10, 20]:
		cases.append({"font": "Galmuri9", "size": sz, "text": "ascii", "allowed": true})
	var v := Engine.get_version_info()
	_env = {"engine": "%s.%s.%s.%s" % [v.major, v.minor, v.patch, v.status], "os": OS.get_name(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"window": DisplayServer.window_get_size(), "screen": DisplayServer.window_get_current_screen(),
		"debug_build": OS.is_debug_build(), "time": Time.get_datetime_string_from_system(false, true),
		"ko_all_chars": texts.ko_all.length(), "ko_all_distinct": _distinct(texts.ko_all)}
	_state = "idle"

static func _distinct(s: String) -> int:
	var d := {}
	for i in s.length(): d[s[i]] = true
	return d.size()

func _ko_text() -> String:
	var j = JSON.parse_string(FileAccess.get_file_as_string("res://data/text/ko.json"))
	var parts := PackedStringArray()
	_walk(j, parts)
	return " ".join(parts)

func _walk(x, parts: PackedStringArray) -> void:
	if x is String: parts.append(x)
	elif x is Dictionary:
		for k in x: _walk(x[k], parts)
	elif x is Array:
		for e in x: _walk(e, parts)

func _fresh_font(path: String) -> FontFile:
	var f = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (f is FontFile): return null
	var ff := f as FontFile
	ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ff.hinting = TextServer.HINTING_NONE
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ff.multichannel_signed_distance_field = false
	ff.generate_mipmaps = false
	ff.allow_system_fallback = false
	return ff

static func _mk(rs: Array, key: String) -> float:
	var a := PackedFloat32Array()
	for x in rs: a.append(float(x[key]))
	return snappedf(_median(a), 0.001)

static func _median(a: PackedFloat32Array) -> float:
	if a.is_empty(): return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]

func _cache_info(ff: FontFile) -> Dictionary:
	var pages := 0
	var bytes := 0
	var detail := []
	for c in ff.get_cache_count():
		for sz in ff.get_size_cache_list(c):
			var n := ff.get_texture_count(c, sz)
			for t in n:
				var img := ff.get_texture_image(c, sz, t)
				if img == null: continue
				var b := img.get_data_size()
				pages += 1
				bytes += b
				detail.append({"size": [sz.x, sz.y], "w": img.get_width(), "h": img.get_height(), "format": img.get_format(), "bytes": b})
	return {"pages": pages, "bytes": bytes, "textures": detail}

func _process(delta: float) -> bool:
	if _state == "boot" or _state == "done":
		return false
	var fm := delta * 1000.0
	match _state:
		"idle":
			_idle.append(fm)
			if _idle.size() >= IDLE_FRAMES:
				_start_case()
		"after":
			_after.append(fm)
			if _after.size() >= AFTER_FRAMES:
				_end_case()
		"warm":
			_after.append(fm)
			if _after.size() >= AFTER_FRAMES:
				_end_warm()
	return false

func _start_case() -> void:
	var c: Dictionary = cases[_ci]
	var path: String = FONTS[c.font]
	var text: String = texts[c.text]
	_cur = c.duplicate()
	_cur.rep = _rep
	_cur.idle_median_ms = snappedf(_median(_idle), 0.001)
	# cold shaping on its own fresh instance (CPU rasterisation into a cold cache)
	var t := Time.get_ticks_usec()
	var fa := _fresh_font(path)
	_cur.load_ms = snappedf((Time.get_ticks_usec() - t) / 1000.0, 0.001)
	t = Time.get_ticks_usec()
	fa.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(c.size))
	_cur.shape_cold_ms = snappedf((Time.get_ticks_usec() - t) / 1000.0, 0.001)
	t = Time.get_ticks_usec()
	fa.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(c.size))
	_cur.shape_warm_ms = snappedf((Time.get_ticks_usec() - t) / 1000.0, 0.001)
	_cur.cache_after_shape = _cache_info(fa)
	fa = null
	# first draw on a second fresh instance: measures the frame that rasterises + uploads glyph pages
	_font = _fresh_font(path)
	_tex0 = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	_label = _make_label(_font, int(c.size), text)
	_host.add_child(_label)
	_after.clear()
	_state = "after"

func _make_label(f: Font, sz: int, text: String) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.position = Vector2(8, 8)
	l.size = Vector2(620, 340)
	l.clip_text = true
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", sz)
	l.text = text
	return l

func _end_case() -> void:
	_cur.draw_first_frame_ms = snappedf(_after[0], 0.001)
	_cur.draw_next_frames_ms = Array(_after.slice(1))
	_cur.hitch_ms = snappedf(_after[0] - _cur.idle_median_ms, 0.001)
	_cur.cache_after_draw = _cache_info(_font)
	_cur.tex_mem_delta = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) - _tex0
	# control: a NEW Label with the same text on the now-warm font = layout/draw cost without glyph rasterisation/upload
	_label.queue_free()
	_label = _make_label(_font, int(_cur.size), texts[_cur.text])
	_host.add_child(_label)
	_after.clear()
	_state = "warm"

func _end_warm() -> void:
	_cur.warm_label_first_frame_ms = snappedf(_after[0], 0.001)
	_cur.glyph_hitch_ms = snappedf(_cur.draw_first_frame_ms - _cur.warm_label_first_frame_ms, 0.001)
	results.append(_cur)
	print("[font_probe] %s %d %s rep%d load=%.2f cold=%.2f warm=%.3f first_frame=%.2f warm_label=%.2f (idle %.2f) pages=%d bytes=%d tex_delta=%d" % [
		_cur.font, _cur.size, _cur.text, _rep, _cur.load_ms, _cur.shape_cold_ms, _cur.shape_warm_ms, _cur.draw_first_frame_ms,
		_cur.warm_label_first_frame_ms, _cur.idle_median_ms, _cur.cache_after_draw.pages, _cur.cache_after_draw.bytes, _cur.tex_mem_delta])
	_label.queue_free()
	_label = null
	_font = null
	_idle.clear()
	_ci += 1
	if _ci >= cases.size():
		_ci = 0
		_rep += 1
	if _rep >= reps:
		_finish()
	else:
		_state = "idle"

func _finish() -> void:
	_state = "done"
	# aggregate: median over reps per case key
	var agg := {}
	for r in results:
		var k := "%s|%d|%s" % [r.font, r.size, r.text]
		if not agg.has(k): agg[k] = []
		agg[k].append(r)
	var summary := []
	for k in agg:
		var rs: Array = agg[k]
		summary.append({"case": k, "allowed_size": rs[0].allowed, "reps": rs.size(), "load_ms_med": _mk(rs, "load_ms"),
			"shape_cold_ms_med": _mk(rs, "shape_cold_ms"), "shape_warm_ms_med": _mk(rs, "shape_warm_ms"),
			"first_frame_ms_med": _mk(rs, "draw_first_frame_ms"), "warm_label_frame_ms_med": _mk(rs, "warm_label_first_frame_ms"), "glyph_hitch_ms_med": _mk(rs, "glyph_hitch_ms"),
			"cache_format": rs[0].cache_after_draw.textures[0].format if not rs[0].cache_after_draw.textures.is_empty() else -1,
			"cache_page_dims": rs[0].cache_after_draw.textures.map(func(x): return "%dx%d" % [x.w, x.h]), "idle_ms_med": _mk(rs, "idle_median_ms"), "hitch_ms_med": _mk(rs, "hitch_ms"),
			"cache_pages": rs[0].cache_after_draw.pages, "cache_bytes": rs[0].cache_after_draw.bytes, "tex_mem_delta_med": _mk(rs, "tex_mem_delta")})
	var rep := {"evidence_class": "CONTENDED_DESKTOP_PROXY" if contended > 0 else ("DESKTOP_PROXY" if contended == 0 else "DESKTOP_PROXY_UNVERIFIED_ISOLATION"),
		"concurrent_godot_processes": contended,
		"note": "Desktop debug editor binary, desktop GPU, vsync off. Not phone evidence. Glyph rasterisation cost on phone CPUs is expected higher; measure on device.",
		"env": _env, "reps": reps, "summary": summary, "runs": results}
	var txt := JSON.stringify(rep, "  ")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var fh := FileAccess.open(out_path, FileAccess.WRITE)
	if fh:
		fh.store_string(txt)
		fh.close()
	for s in summary:
		print("[font_summary] %-32s allowed=%s cold=%.2fms warm=%.3fms first=%.2fms warm_label=%.2fms glyph_hitch=%.2fms (idle %.2f) pages=%d cache=%dB load=%.2fms" % [
			s.case, str(s.allowed_size), s.shape_cold_ms_med, s.shape_warm_ms_med, s.first_frame_ms_med, s.warm_label_frame_ms_med, s.glyph_hitch_ms_med, s.idle_ms_med, s.cache_pages, s.cache_bytes, s.load_ms_med])
	print("[font_probe] report ", out_path)
	quit(0)
