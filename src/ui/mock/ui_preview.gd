extends Node
## MOCK UI PREVIEW (04-client). Runs the real 04 UI scenes against MockEngine with a private
## Events bus, so it never touches 02's App router or the save file.
##   Run:     tools/engine/Godot_v4.7.2-stable_win64.exe --path . res://scenes/ui/ui_preview.tscn
##   Capture: ... res://scenes/ui/ui_preview.tscn -- --capture=build/qa/screens --tag=1280x720
##            [--safe=L,T,R,B in logical px] writes PNGs of every screen then quits.

const EventsScript := preload("res://src/core/events.gd")
const MockEngine := preload("res://src/ui/mock/mock_engine.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")
const SCENES := {
	&"menu": "res://scenes/ui/main_menu.tscn",
	&"round_select": "res://scenes/ui/round_select.tscn",
	&"battle": "res://scenes/ui/hud.tscn",
	&"result": "res://scenes/ui/result.tscn",
}

var bus: Node
var mock: Node
var layer: CanvasLayer
var current: Control
var current_name: StringName
var progress := {"version": 1, "unlocked_round": 4, "stars": {"r01": 3, "r02": 2, "r03": 1}, "coins": 340,
	"settings": {"fps_cap": 60, "sfx": 1.0, "music": 0.8, "show_damage": true}}
var _bg: Node2D

func _ready() -> void:
	bus = EventsScript.new()
	bus.name = "MockEvents"
	add_child(bus)
	mock = MockEngine.new()
	mock.auto_play = true
	add_child(mock)
	mock.attach(bus)
	_bg = preload("res://src/ui/mock/mock_battlefield.gd").new()
	_bg.mock = mock
	_bg.visible = false
	add_child(_bg)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	bus.cmd_open_screen.connect(func(s): show_screen(s))
	bus.cmd_start_round.connect(func(_id): _enter_battle())
	bus.cmd_retry.connect(func(): _enter_battle())
	bus.cmd_next_round.connect(func(): _enter_battle())
	bus.battle_ended.connect(func(r): show_screen(&"result", {"result": r}))
	bus.cmd_set_setting.connect(func(k, v): progress.settings[k] = v)
	var args := _args()
	if args.has("safe"):
		var p: PackedStringArray = str(args.safe).split(",")
		var vs := get_viewport().get_visible_rect().size
		SafeArea.override_safe_rect = Rect2(float(p[0]), float(p[1]), vs.x - float(p[0]) - float(p[2]), vs.y - float(p[1]) - float(p[3]))
	if args.has("capture"):
		_capture(str(args.capture), str(args.get("tag", "shot")))
	else:
		show_screen(&"menu")

func _enter_battle() -> void:
	show_screen(&"battle")
	mock.start(mock.round_id if mock.round_id != "" else "r01")

func show_screen(s: StringName, params: Dictionary = {}) -> void:
	if current != null:
		current.queue_free()
	current_name = s
	_bg.visible = s == &"battle" or s == &"result"
	var packed: PackedScene = load(SCENES[s])
	current = packed.instantiate()
	current.bus = bus
	current.progress_override = progress
	layer.add_child(current)
	if current.has_method("ui_setup"):
		current.ui_setup(params)
	bus.screen_changed.emit(s, params)

func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			d[kv[0]] = kv[1] if kv.size() > 1 else true
	return d

func _shot(dir: String, tag: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s_%s.png" % [dir, tag, label]
	var err := img.save_png(path)
	print("[capture] %s %dx%d err=%d" % [path, img.get_width(), img.get_height(), err])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _capture(dir: String, tag: String) -> void:
	if not dir.is_absolute_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	await _frames(3)
	print("[capture] window=%s visible=%s safe=%s" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect().size, SafeArea.safe_rect(get_viewport())])
	show_screen(&"menu")
	await _frames(3); await _shot(dir, tag, "1_menu")
	show_screen(&"round_select")
	await _frames(3); await _shot(dir, tag, "2_round_select")
	mock.auto_play = false
	_enter_battle()
	for i in 4:
		bus.cmd_deploy_unit.emit("melee_basic")
	mock.step(2.5)
	mock._emit_snapshot()
	bus.cmd_hero_skill.emit("skill_slam")
	mock.boss_alive = true
	mock._emit_snapshot()
	bus.tutorial_step.emit("tut_deploy_unit")
	bus.toast.emit("not_enough_gold", {})
	await _frames(3); await _shot(dir, tag, "3_hud")
	bus.cmd_set_paused.emit(true)
	await _frames(3); await _shot(dir, tag, "4_pause")
	bus.cmd_set_paused.emit(false)
	show_screen(&"result", {"result": {"round_id": "r01", "won": true, "stars": 2, "time": 195.2, "kills": 41, "coins": 60, "first_clear": true, "next_round_id": "r02", "player_base_ratio": 0.72, "star_rules": {"base_hp_2": 0.5, "time_3": 150}}})
	await _frames(40); await _shot(dir, tag, "5_result_win")
	show_screen(&"result", {"result": {"round_id": "r01", "won": false, "stars": 0, "time": 61.0, "kills": 12, "coins": 10, "first_clear": false, "next_round_id": ""}})
	await _frames(40); await _shot(dir, tag, "6_result_loss")
	get_tree().quit(0)
