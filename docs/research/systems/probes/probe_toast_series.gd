extends SceneTree
## Visible research probe (10-research-systems): is the `save_failed` toast ever drawn on the menu screens?
## Series S1: upgrade panel open, purchase with an injected write failure (Save._fault = "after_tmp_write").
## Series S2: panel closed, Events.toast("save_failed") emitted directly on the main menu.
## Each series captures the rendered frame every 0.1 s for 2.0 s and counts pixels that differ from a baseline
## frame taken just before the trigger. A toast that is drawn anywhere changes pixels; a static UI does not.
## Writes ONLY user://probe10/ (renamed snapshot project). Launch on the SECONDARY monitor via 04's
## tools/build/visible_launch.ps1 -ProjectPath <snapshot> -Script res://docs/research/systems/probes/probe_toast_series.gd
## Prints "PROBE10_TOAST {json}" and quits (60 s watchdog).

const P := "user://probe10/toast_save.json"
const SHOTS := "user://probe10/toast"

func _env_txt(p: Dictionary) -> String:
	var txt := JSON.stringify(p, "", true)
	return JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt}, "", true)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var save := root.get_node("Save")
	save.path = P
	var S = load("res://src/core/save.gd")
	var p: Dictionary = S.fresh(); p.coins = 500; p.unlocked_round = 3
	var f := FileAccess.open(P, FileAccess.WRITE); f.store_string(_env_txt(p)); f.close()
	save.load_progress()
	create_timer(60.0).timeout.connect(func(): print("PROBE10_TOAST {\"watchdog\":true}"); quit(0))
	_run.call_deferred()

func _img() -> Image:
	return root.get_viewport().get_texture().get_image()

func _diff(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size(): return -1
	var da := a.get_data(); var db := b.get_data()
	var n := 0
	var step := 4 if a.get_format() == Image.FORMAT_RGBA8 else 3
	for i in range(0, da.size(), step * 2):      # every 2nd pixel is enough to detect a toast
		if da[i] != db[i] or da[i + 1] != db[i + 1] or da[i + 2] != db[i + 2]: n += 1
	return n

func _series(tag: String, trigger: Callable) -> Dictionary:
	for i in 5: await process_frame
	var base := _img()
	base.save_png("%s/%s_base.png" % [SHOTS, tag])
	var toasts: Array = []
	var cb := func(k, _a): toasts.append(str(k))
	root.get_node("Events").toast.connect(cb)
	trigger.call()
	var frames: Array = []
	var t0 := Time.get_ticks_msec()
	for k in 21:
		await process_frame
		var im := _img()
		var d := _diff(base, im)
		frames.append({"t_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.01), "changed_px": d})
		if k in [1, 5, 10, 20]: im.save_png("%s/%s_%02d.png" % [SHOTS, tag, k])
		await create_timer(0.1).timeout
	root.get_node("Events").toast.disconnect(cb)
	var mx := 0
	for fr in frames: mx = maxi(mx, int(fr.changed_px))
	return {"toasts_emitted": toasts, "frames": frames, "max_changed_px": mx}

func _run() -> void:
	var app = root.get_node("App")
	var save = root.get_node("Save")
	var main = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	var out := {"window": {"screen": DisplayServer.window_get_current_screen(), "primary": DisplayServer.get_primary_screen(),
		"size": DisplayServer.window_get_size()}, "ui_source": app.ui_source}
	var screen = app.ui_layer.get_child(0)
	# S2 first (panel closed): direct toast on the main menu
	out.S2_menu_direct_toast = await _series("s2_menu", func(): root.get_node("Events").toast.emit("save_failed", {"error": "probe"}))
	# S1: panel open, purchase with an injected write failure
	screen.open_upgrades()
	for i in 5: await process_frame
	var panel = screen.upgrade_panel
	var slot := 0
	for i in panel.rows.size():
		if str(panel.rows[i].id) == "up_melee_basic": slot = i
	out.S1_panel_buy_failure = await _series("s1_panel", func():
		save._fault = "after_tmp_write"
		panel._on_buy(slot))
	out.S1_status = {"code": str(panel.status_code), "text": str(panel.status_text)}
	out.shots = ProjectSettings.globalize_path(SHOTS)
	print("PROBE10_TOAST ", JSON.stringify(out))
	quit(0)
