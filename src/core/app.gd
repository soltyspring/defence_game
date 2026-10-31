extends Node
## App router, game progression and mobile lifecycle. Owner: 02-engine.
## Screens: menu -> round_select -> battle (+hud) -> result. UI scenes from scenes/ui/* when present,
## otherwise 02 fallback UI (src/gameplay/fallback_ui.gd). Contract: INTERFACES.md §1, §4.

const BattleScene := "res://scenes/gameplay/battle.tscn"
const UI_SCENES := {
	&"menu": "res://scenes/ui/main_menu.tscn",
	&"round_select": "res://scenes/ui/round_select.tscn",
	&"hud": "res://scenes/ui/hud.tscn",
	&"result": "res://scenes/ui/result.tscn",
}
const FallbackUI := preload("res://src/gameplay/fallback_ui.gd")

var main: Node = null
var world: Node2D = null
var ui_layer: CanvasLayer = null
var screen: StringName = &""
var battle: Node2D = null
var current_round := ""
var last_result: Dictionary = {}
var autoplay := false
var autoplay_rounds := 0
var _quit_after := -1.0
var _result_delay := -1.0
var _pending_result: Dictionary = {}
var ui_source := {}           # screen -> "scenes/ui" | "fallback" (evidence for QA)
var _shots: Array = []
var _shot_dir := "user://shots"
var _clock := 0.0

## Preview evidence: saves the rendered frame (no-op in headless mode).
func _capture(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := get_viewport().get_texture().get_image()
	if img == null: return
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var p := _shot_dir.path_join(file)
	img.save_png(p)
	print("[App] screenshot ", p, " ", img.get_size(), " perf=", JSON.stringify(Perf.snapshot()))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.cmd_start_round.connect(start_round)
	Events.cmd_retry.connect(func(): start_round(current_round))
	Events.cmd_next_round.connect(_on_next_round)
	Events.cmd_open_screen.connect(func(s): show_screen(StringName(s)))
	Events.cmd_set_setting.connect(_on_setting)
	var args := OS.get_cmdline_user_args()
	autoplay = args.has("--autoplay")
	for a in args:
		if a.begins_with("--quit-after="):
			_quit_after = float(a.get_slice("=", 1))
		if a.begins_with("--autoplay-rounds="):
			autoplay_rounds = int(a.get_slice("=", 1))
		if a.begins_with("--shots="):
			for s in a.get_slice("=", 1).split(","):
				_shots.append(float(s))
		if a.begins_with("--shot-dir="):
			_shot_dir = a.get_slice("=", 1)

## Called by scenes/gameplay/main.tscn once its World and UI nodes exist.
func boot(p_main: Node, p_world: Node2D, p_ui: CanvasLayer) -> void:
	main = p_main
	world = p_world
	ui_layer = p_ui
	Perf.set_fps_cap(int(Save.progress.settings.get("fps_cap", 60)))
	for id in Atlas.pages:   # always-resident UI pages (load_policy "always" / group "ui")
		var m: Dictionary = Atlas.pages[id].meta
		if str(m.get("group", "")) == "ui" or str(m.get("load_policy", "")) == "always":
			Atlas.acquire(id)
	if Save.recovered:
		Events.toast.emit("save_recovered", {"source": Save.recovery_source})
	if Save.read_only:
		Events.toast.emit("save_read_only", {})
	var args := OS.get_cmdline_user_args()
	var direct := ""
	for a in args:
		if a.begins_with("--round="):
			direct = a.get_slice("=", 1)
	if autoplay and direct == "":
		direct = Content.round_order[0]
	if direct != "":
		start_round(direct, true)
	else:
		show_screen(&"menu")
	print("[App] boot ok platform=%s renderer=%s screen=%s ui_source=%s atlas=%s save_recovered=%s" % [OS.get_name(),
		RenderingServer.get_video_adapter_name(), str(screen), JSON.stringify(ui_source), JSON.stringify(Atlas.texture_report()), Save.recovered])

func _process(delta: float) -> void:
	_clock += delta
	if not _shots.is_empty() and _clock >= _shots[0]:
		var at: float = _shots.pop_front()
		_capture("shot_%03ds_%s.png" % [int(at), str(screen)])
	if _quit_after > 0.0:
		_quit_after -= delta
		if _quit_after <= 0.0:
			print("[App] quit-after reached. perf=", JSON.stringify(Perf.snapshot()), " atlas=", JSON.stringify(Atlas.texture_report()))
			if battle and battle.sim:
				print("[App] battle t=%.1f paused=%s ended=%s players=%d enemies=%d gold=%d" % [battle.sim.t, battle.sim.paused, battle.sim.ended, battle.sim.players.size(), battle.sim.enemies.size(), battle.sim.gold])
			var au := get_node_or_null("/root/Audio")
			if au and au.has_method("snapshot"):
				print("[App] audio=", JSON.stringify(au.snapshot()))
			get_tree().quit(0)
	if _result_delay > 0.0:
		_result_delay -= delta
		if _result_delay <= 0.0:
			_show_result(_pending_result)

# ---------------- screens ----------------
func _clear_ui() -> void:
	if ui_layer == null: return
	for c in ui_layer.get_children():
		c.queue_free()

func _make_ui(name: StringName, params: Dictionary) -> Control:
	var path: String = UI_SCENES.get(name, "")
	if path != "" and ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			var inst = ps.instantiate()
			var scr = inst.get_script() if inst else null
			if inst is Control and scr is GDScript and scr.can_instantiate():
				ui_source[name] = "scenes/ui"
				return inst
			push_warning("[App] UI scene %s unusable (script missing/failed) -> fallback" % path)
			if inst: inst.free()
	ui_source[name] = "fallback"
	return FallbackUI.create(name, params)

## 04 R1: mount then call ui_setup(params) when the scene provides it.
func _mount_ui(c: Control, params: Dictionary) -> void:
	if c == null: return
	ui_layer.add_child(c)
	if c.has_method("ui_setup"):
		c.ui_setup(params)

## 04 R2: 04 scenes handle the Android back button themselves; App only handles it for fallback UI.
func _ui_handles_back() -> bool:
	return ui_source.get(screen if screen != &"battle" else &"hud", "fallback") == "scenes/ui"

func show_screen(name: StringName, params: Dictionary = {}) -> void:
	if name == &"battle":
		return
	_end_battle()
	_clear_ui()
	screen = name
	get_tree().paused = false
	var c := _make_ui(name, params)
	_mount_ui(c, params)
	Events.screen_changed.emit(name, params)

func _end_battle() -> void:
	if battle:
		battle.queue_free()
		battle = null
	_result_delay = -1.0

func start_round(round_id: String, force := false) -> void:
	var idx := Content.round_order.find(round_id)
	if idx < 0:
		push_warning("[App] unknown round " + round_id)
		return
	if not force and not autoplay and not Save.is_unlocked(idx):
		Events.toast.emit("round_locked", {"round_id": round_id})
		return
	_end_battle()
	_clear_ui()
	current_round = round_id
	screen = &"battle"
	var ps: PackedScene = load(BattleScene)
	battle = ps.instantiate()
	world.add_child(battle)
	var hud := _make_ui(&"hud", {})
	ui_layer.add_child(hud)   # HUD first so it receives battle_started
	battle.finished.connect(_on_battle_finished)
	var seed_v := int(Content.config.get("combat", {}).get("deterministic_seed_default", 12345)) + idx
	if not autoplay: seed_v = randi()
	battle.start(round_id, seed_v, Save.progress.get("upgrades", {}), autoplay)
	if hud.has_method("ui_setup"):
		hud.ui_setup({"info": battle.battle_info()})
	Events.screen_changed.emit(&"battle", {"round_id": round_id})

func _on_battle_finished(r: Dictionary) -> void:
	var result := r.duplicate()
	var idx := Content.round_order.find(result.round_id)
	var rd: Dictionary = Content.get_round(result.round_id)
	var rw: Dictionary = rd.get("reward", {})
	var prev_stars := int(Save.progress.stars.get(result.round_id, 0))
	var first_clear: bool = result.won and not Save.progress.stars.has(result.round_id)
	var coins := int(result.coins)
	if result.won:
		coins += int(rw.get("first_clear_coins", rw.get("coins", 0))) if first_clear else int(rw.get("coins", 0))
		if int(result.stars) == 3 and prev_stars < 3:
			coins += int(rw.get("three_star_bonus_coins", 0))
	result.coins = coins
	result.first_clear = first_clear
	result.next_round_id = Content.next_round_id(result.round_id) if result.won else ""
	var td: Array = Save.progress.get("tutorial_done", [])
	for k in result.get("tutorial_done", []):
		if not td.has(k): td.append(k)
	Save.progress["tutorial_done"] = td
	var uid := str(result.get("battle_uid", ""))
	if Save.was_applied(uid):
		result["saved"] = false      # same battle already rewarded (10 R3): nothing granted twice
		result["duplicate"] = true
	else:
		result["saved"] = Save.record_result(result, idx)
	last_result = result
	print("[App] battle ended ", JSON.stringify(result))
	_pending_result = result
	_result_delay = 1.2
	if autoplay:
		autoplay_rounds -= 1

func _show_result(result: Dictionary) -> void:
	if autoplay and autoplay_rounds > 0:
		Events.battle_ended.emit(result)
		if result.next_round_id != "":
			start_round(result.next_round_id, true)
		else:
			start_round(result.round_id, true)
		return
	# keep battle visible under the result panel; freeze it
	if battle and battle.sim: battle.sim.paused = true
	var c := _make_ui(&"result", result)
	_mount_ui(c, {"result": result})
	screen = &"result"
	Events.screen_changed.emit(&"result", result)
	Events.battle_ended.emit(result)  # emitted once, after the result scene is mounted

func _on_next_round() -> void:
	var nid := Content.next_round_id(current_round)
	if nid != "" and Save.is_unlocked(Content.round_order.find(nid)):
		start_round(nid)
	else:
		show_screen(&"round_select")

func _on_setting(key: String, value: Variant) -> void:
	Save.set_setting(key, value)
	if key == "fps_cap": Perf.set_fps_cap(int(value))
	if key == "show_damage" and battle and battle.view: battle.view.show_damage = bool(value)

# ---------------- mobile lifecycle ----------------
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if battle and battle.sim and not battle.sim.ended and not autoplay:
				battle.set_paused(true)
			Save.save_progress()
		NOTIFICATION_WM_CLOSE_REQUEST:
			Save.save_progress()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if not _ui_handles_back():
				_on_back()

func _on_back() -> void:
	match screen:
		&"battle":
			if battle and battle.sim: battle.set_paused(not battle.sim.paused)
		&"round_select", &"result":
			show_screen(&"menu")
		_:
			Save.save_progress()
			get_tree().quit()
