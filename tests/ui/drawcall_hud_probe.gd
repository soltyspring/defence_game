extends SceneTree
## 04-client draw-call probe for the HUD parts (08 R8). Visible runs only (DISPLAY2 via tools/build/visible_launch.ps1):
## one real hud_top (r08-like snapshot: boss alive, wave line, full bars) or one real card button, alone on screen,
## drawn with only some passes at a time; reports median RENDER_TOTAL_DRAW_CALLS_IN_FRAME minus the empty screen.
## Desktop GL Compatibility proxy (same as 08's tools), not phone evidence. Owner: 04-client.
##   ... -s res://tests/ui/drawcall_hud_probe.gd -- --out=<abs.json> [--os=<float>] [--shots=<abs dir>]
## --os: set FontFile.oversampling of the ui/bold/num fonts before the prewarm (0 = Godot default: follow the viewport
##       scale; 1 = draw from the 12 px cache and let the canvas scale it). Without --os the fonts keep UiStyle's value.
## --shots: save the frame of top_all and card_idle as PNG there (pixel comparison between --os runs).

const UiStyle := preload("res://src/ui/ui_style.gd")
const HudLayout := preload("res://src/ui/hud_layout.gd")
const TouchButton := preload("res://src/ui/touch_button.gd")
const HUD_TEXT := "0123456789/+.%VSm8. 끝없는 초파리 웨이브 다음 초 밀가루 기력 곰팡이 장군 제빵사 식빵병 롤빵병 통식빵 프레첼 화덕포 Flour Energy Wave Next"

## hud_top with a selectable pass list (same drawing code, only the loop differs)
class TopProbe extends "res://src/ui/hud_top.gd":
	var only: Array = []
	var no_hatch := false
	func _draw() -> void:
		if layout.is_empty():
			return
		for p in (only if not only.is_empty() else PASSES):
			_pass = p
			_draw_resources(layout.resources)
			_draw_bases(layout.bases, layout.wave)

var out_path := ""
var shots_dir := ""
var os_arg := -1.0
var rows := []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_path = a.get_slice("=", 1)
		elif a.begins_with("--os="): os_arg = float(a.get_slice("=", 1))
		elif a.begins_with("--shots="): shots_dir = a.get_slice("=", 1)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _measure(label: String, node: Node) -> int:
	if node != null:
		root.add_child(node)
	await _frames(12)
	var v := []
	for i in 20:
		await process_frame
		v.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	v.sort()
	var med: int = v[v.size() / 2]
	if shots_dir != "" and label in ["top_all", "card_idle"]:
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(shots_dir)
		img.save_png(shots_dir.path_join("%s.png" % label))
	if node != null:
		node.queue_free()
		await _frames(3)
	return med

func _snap(boss: bool, enemy_hp: float) -> Dictionary:
	return {"gold": 67, "gold_max": 450, "income": 4.0, "mana": 30.0, "mana_max": 100.0,
		"player_base": {"hp": 1900.0, "hp_max": 2000.0}, "enemy_base": {"hp": enemy_hp, "hp_max": 2400.0},
		"wave": {"index": 0, "total": 4, "next_in": 19.0}, "army": {"player": 1, "cap": 36},
		"boss": {"alive": boss, "hp": 1300.0, "hp_max": 1300.0, "name_key": "enemy.boss_warlord.name"}}

func _top(only: Array, boss := true, enemy_hp := 2400.0) -> Control:
	var t := TopProbe.new()
	t.only = only
	t.size = Vector2(640, 360)
	t.layout = HudLayout.compute(Vector2(640, 360), Rect2(34, 0, 572, 360), 5, 3, 40.0)
	t.round_title = "8. 끝없는 초파리"
	t.snap = _snap(boss, enemy_hp)
	return t

func _card(cool: float, with_icon := true) -> Control:
	var b: Control = TouchButton.new()
	b.text = "식빵병"
	b.sub_text = "30"
	b.icon = UiStyle.ui_icon("card_melee_basic") if with_icon else null
	b.cooldown_ratio = cool
	b.position = Vector2(200, 200)
	b.size = Vector2(50, 56)
	return b

func _run() -> void:
	if os_arg >= 0.0:
		for k in [&"ui", &"bold", &"num"]:
			var f := UiStyle.font(k)
			if f is FontFile:
				(f as FontFile).oversampling = os_arg
	UiStyle.prewarm_fonts()
	await _frames(5)
	var base := await _measure("empty", null)
	var cases := [
		["top_all", _top([])],
		["top_shapes", _top([0])],
		["top_shapes_no_boss_no_hatch", _top([0], false, 0.0)],
		["top_icons", _top([1])],
		["top_text_ui12", _top([2])],
		["top_text_ui12_no_boss", _top([2], false)],
		["top_bold12", _top([3])],
		["card_idle", _card(0.0)],
		["card_cooldown", _card(0.5)],
		["card_no_icon_idle", _card(0.0, false)],
	]
	for c in cases:
		var m := await _measure(c[0], c[1])
		rows.append({"case": c[0], "draw_calls": m, "above_empty": m - base})
		print("[dc_hud] %-30s draw_calls=%3d above_empty=%3d" % [c[0], m, m - base])
	var ui := UiStyle.font(&"ui")
	var bold := UiStyle.font(&"bold")
	var vp_os := root.get_oversampling()
	var font_os: float = (ui as FontFile).oversampling if ui is FontFile else -1.0
	var eff: float = font_os if font_os > 0.0 else vp_os
	var key_px := int(round(12.0 * eff))
	var tex := {}
	for px in [12, 24, 36]:
		tex["ui%d" % px] = _cache_textures(ui, px)
		tex["bold%d" % px] = _cache_textures(bold, px)
	var res := {"empty": base, "rows": rows, "window": DisplayServer.window_get_size(), "view": root.get_visible_rect().size,
		"font_sources": UiStyle.font_sources, "os_arg": os_arg, "viewport_oversampling": vp_os, "ui_font_oversampling": font_os,
		"ui12_draw_cache_px": key_px, "cache_textures": tex,
		"ui12_cache_textures": _cache_textures(ui, 12), "bold12_cache_textures": _cache_textures(bold, 12),
		"hud_text_off_page0_at_12": _off_page0(ui, 12, HUD_TEXT),
		"hud_text_off_page0_at_draw_cache": _off_page0(ui, key_px, HUD_TEXT)}
	print("[dc_hud] " + JSON.stringify(res))
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "  "))
		f.close()
	quit(0)

## Characters of `s` whose glyph is NOT on cache texture 0 for this font size (each such glyph splits a text pass).
## `size` is the cache key in whole pixels: text drawn at 12 with oversampling 2 uses the 24 px cache.
func _off_page0(f: Font, size: int, s: String) -> Array:
	var out := []
	if not (f is FontFile):
		return out
	var ff := f as FontFile
	var sz := Vector2i(size, 0)
	for ch in s:
		if ch == " ":
			continue
		var gi := ff.get_glyph_index(size, ch.unicode_at(0), 0)
		if gi != 0 and ff.get_glyph_texture_idx(0, sz, gi) > 0 and not out.has(ch):
			out.append(ch)
	return out

## Glyph cache textures of one font at one size (FontFile cache index 0). More than 1 means one "font + size" is split
## over several textures, and text in one pass can still switch textures.
func _cache_textures(f: Font, size: int) -> int:
	if not (f is FontFile):
		return -1
	var ff := f as FontFile
	var sz := Vector2i(size, 0)
	return ff.get_texture_count(0, sz)
