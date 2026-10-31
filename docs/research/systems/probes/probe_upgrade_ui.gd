extends SceneTree
## Visible research probe (10-research-systems): App-path C10 at screen level for the 04 upgrade panel.
## Boots the real main scene, opens the upgrade panel from the main menu, presses the real buy handler
## (UpgradePanel._on_buy → Events.cmd_buy_upgrade → App → Save.buy_upgrade → Events.upgrade_result) and
## captures the rendered frame after each case. Compares the shown status text and the coin number source
## (panel.coins()) with Save memory and with the file on disk.
## Writes ONLY user://probe10/ (run in a renamed snapshot project). Launch on the SECONDARY monitor via 04's
## tools/build/visible_launch.ps1 -ProjectPath <snapshot> -Script res://docs/research/systems/probes/probe_upgrade_ui.gd
## Prints "PROBE10_UPGRADE_UI {json}" and quits (60 s watchdog).

const P := "user://probe10/ui_save.json"
const SHOTS := "user://probe10/shots"
const UID := "up_melee_basic"

var out := {}

func _env_txt(p: Dictionary) -> String:
	var txt := JSON.stringify(p, "", true)
	return JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt}, "", true)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var save := root.get_node_or_null("Save")
	save.path = P
	for suf in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(P + suf): DirAccess.remove_absolute(P + suf)
	var S = load("res://src/core/save.gd")
	var p: Dictionary = S.fresh()
	p.coins = 500
	p.unlocked_round = 3
	var f := FileAccess.open(P, FileAccess.WRITE); f.store_string(_env_txt(p)); f.close()
	save.load_progress()
	create_timer(60.0).timeout.connect(func(): print("PROBE10_UPGRADE_UI {\"watchdog\":true}"); quit(0))
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n: await process_frame

func _shot(name: String) -> String:
	await _frames(3)
	var img := root.get_viewport().get_texture().get_image()
	var path := SHOTS + "/" + name + ".png"
	if img: img.save_png(path)
	return path

func _disk() -> Array:
	var S = load("res://src/core/save.gd")
	var s = S.new(); s.path = P; root.add_child(s); s.load_progress()
	var r := [int(s.progress.coins), int((s.progress.upgrades as Dictionary).get(UID, 1))]
	s.free()
	return r

func _case(panel, save, slot: int, name: String, toasts: Array) -> Dictionary:
	toasts.clear()
	panel._on_buy(slot)
	var shot: String = await _shot(name)
	var r := {"status_code": str(panel.status_code), "status_text": str(panel.status_text),
		"panel_coins": panel.coins(), "save_memory": [int(save.progress.coins), save.upgrade_level(UID)],
		"disk": _disk(), "toasts": toasts.duplicate(), "shot": shot}
	r.coins_match = r.panel_coins == r.save_memory[0]
	await create_timer(0.5).timeout          # BUY_LOCK_MS is 400 ms
	return r

func _run() -> void:
	var save = root.get_node("Save")
	var ev = root.get_node("Events")
	var app = root.get_node("App")
	var toasts: Array = []
	ev.toast.connect(func(k, _a): toasts.append(str(k)))
	var main = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	var screen = app.ui_layer.get_child(0) if app.ui_layer and app.ui_layer.get_child_count() > 0 else null
	out.ui_source = app.ui_source
	out.window = {"size": DisplayServer.window_get_size(), "position": DisplayServer.window_get_position(),
		"screen": DisplayServer.window_get_current_screen(), "primary": DisplayServer.get_primary_screen()}
	if screen == null or not screen.has_method("open_upgrades"):
		out.error = "menu screen with open_upgrades not found"
		print("PROBE10_UPGRADE_UI ", JSON.stringify(out)); quit(0); return
	screen.open_upgrades()
	await _shot("00_open")
	var panel = screen.upgrade_panel
	var slot := -1
	for i in panel.rows.size():
		if str(panel.rows[i].id) == UID: slot = i
	out.slot = slot
	# A success
	out.A_success = await _case(panel, save, slot, "01_success", toasts)
	# B not enough (memory coins 10; level 2 → next cost 100)
	save.progress.coins = 10
	panel._refresh(); panel.queue_redraw()
	out.B_not_enough = await _case(panel, save, slot, "02_not_enough", toasts)
	# C max level
	save.progress.coins = 500
	save.progress.upgrades[UID] = 5
	save.save_progress()
	panel._refresh(); panel.queue_redraw()
	out.C_max = await _case(panel, save, slot, "03_max", toasts)
	# D save failure injected (after_tmp_write) from L1 / 500
	save.progress.upgrades.erase(UID)
	save.progress.coins = 500
	save.save_progress()
	panel._refresh(); panel.queue_redraw()
	save._fault = "after_tmp_write"
	out.D_save_failed = await _case(panel, save, slot, "04_save_failed", toasts)
	# E uncertain (before_final_rename)
	save.load_progress()
	panel._refresh(); panel.queue_redraw()
	save._fault = "before_final_rename"
	out.E_save_uncertain = await _case(panel, save, slot, "05_save_uncertain", toasts)
	out.shots_dir = ProjectSettings.globalize_path(SHOTS)
	print("PROBE10_UPGRADE_UI ", JSON.stringify(out))
	quit(0)
