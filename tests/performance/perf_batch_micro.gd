extends SceneTree
## 08-performance batching micro-check (DESKTOP PROXY, GL Compatibility; never phone evidence).
## Question: inside ONE CanvasItem, does switching between plain rects, UiStyle text (font glyph cache) and ui_main icons start a new
## draw call each time? Draws 12 repeats of each pattern on a lone Control (nothing else on screen) and reports the median
## RENDER_TOTAL_DRAW_CALLS_IN_FRAME minus the empty-screen baseline. Uses the project's UiStyle helpers so fonts/sizes match the HUD.
## Run: Godot_console.exe --screen 1 --resolution 1280x720 --path <snap> -s res://tests/performance/perf_batch_micro.gd -- [--bm-out=<abs.json>]
## Owner: 08-performance.

const UiStyle := preload("res://src/ui/ui_style.gd")
const N := 12
const MODES := ["empty", "rects", "texts_same_font", "numbers_bold_m", "rect_text_interleaved", "rects_then_texts",
	"text_s_number_m_interleaved", "texts_s_then_numbers_m", "icons", "rect_icon_text_interleaved", "rects_icons_texts_grouped"]

class Painter extends Control:
	var mode := "empty"
	func _draw() -> void:
		var y0 := 8.0
		match mode:
			"rects":
				for i in N: draw_rect(Rect2(8 + i * 40, y0, 30, 12), Color(0.3, 0.3, 0.4))
			"texts_same_font":
				for i in N: UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)
			"numbers_bold_m":
				for i in N: UiStyle.draw_number(self, "%d" % (i * 7), Vector2(8 + i * 40, y0 + 60), UiStyle.FONT_M, UiStyle.C_GOLD, -1, &"bold")
			"rect_text_interleaved":
				for i in N:
					draw_rect(Rect2(8 + i * 40, y0, 30, 12), Color(0.3, 0.3, 0.4))
					UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)
			"rects_then_texts":
				for i in N: draw_rect(Rect2(8 + i * 40, y0, 30, 12), Color(0.3, 0.3, 0.4))
				for i in N: UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)
			"text_s_number_m_interleaved":
				for i in N:
					UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)
					UiStyle.draw_number(self, "%d" % (i * 7), Vector2(8 + i * 40, y0 + 60), UiStyle.FONT_M, UiStyle.C_GOLD, -1, &"bold")
			"texts_s_then_numbers_m":
				for i in N: UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)
				for i in N: UiStyle.draw_number(self, "%d" % (i * 7), Vector2(8 + i * 40, y0 + 60), UiStyle.FONT_M, UiStyle.C_GOLD, -1, &"bold")
			"icons":
				for i in N: UiStyle.draw_ui_icon(self, "icon_supply", Vector2(20 + i * 40, y0 + 90))
			"rect_icon_text_interleaved":
				for i in N:
					draw_rect(Rect2(8 + i * 40, y0, 30, 12), Color(0.3, 0.3, 0.4))
					UiStyle.draw_ui_icon(self, "icon_supply", Vector2(20 + i * 40, y0 + 90))
					UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)
			"rects_icons_texts_grouped":
				for i in N: draw_rect(Rect2(8 + i * 40, y0, 30, 12), Color(0.3, 0.3, 0.4))
				for i in N: UiStyle.draw_ui_icon(self, "icon_supply", Vector2(20 + i * 40, y0 + 90))
				for i in N: UiStyle.draw_text_left(self, "가%d" % i, Vector2(8 + i * 40, y0 + 30), UiStyle.FONT_S)

var _p: Painter
var _i := 0
var _t := 0.0
var _dc := {}
var out_path := ""
var _icon_ok := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bm-out="): out_path = a.get_slice("=", 1)
	if out_path == "": out_path = ProjectSettings.globalize_path("res://build/perf/batch_micro.json")
	_p = Painter.new()
	_p.size = Vector2(640, 200)
	root.add_child.call_deferred(_p)
	for m in MODES: _dc[m] = PackedInt32Array()

func _process(delta: float) -> bool:
	if _p == null or not _p.is_inside_tree(): return false
	_t += delta
	if _t > 0.4:   # settle 0.4 s after a mode change, then sample 0.8 s
		_dc[MODES[_i]].append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= 1.2:
		_i += 1
		_t = 0.0
		if _i >= MODES.size():
			_finish()
			return true
		_p.mode = MODES[_i]
		_p.queue_redraw()
	return false

static func _med(a: PackedInt32Array) -> float:
	if a.is_empty(): return -1.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2])

func _finish() -> void:
	_icon_ok = UiStyle.ui_icon("icon_supply") != null
	var base := _med(_dc["empty"])
	var rows := []
	for m in MODES:
		rows.append({"mode": m, "draw_calls_median": _med(_dc[m]), "above_empty": _med(_dc[m]) - base, "frames": _dc[m].size()})
		print("[batch] %-30s draw_calls=%4.0f above_empty=%4.0f (N=%d repeats)" % [m, _med(_dc[m]), _med(_dc[m]) - base, N])
	print("[batch] ui_main icon available: ", _icon_ok)
	var v := Engine.get_version_info()
	var rep := {"evidence_class": "DESKTOP_PROXY_MICRO", "repeats": N, "icon_available": _icon_ok, "rows": rows,
		"env": {"engine": "%s.%s.%s" % [v.major, v.minor, v.patch], "gpu": RenderingServer.get_video_adapter_name(),
			"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "time": Time.get_datetime_string_from_system(false, true)}}
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rep, "  "))
		f.close()
	print("[batch] report ", out_path)
