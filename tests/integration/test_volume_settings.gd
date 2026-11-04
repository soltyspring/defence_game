extends SceneTree
## Actual settings -> preview audio bus -> commit Save -> reload, in private APPDATA.
var checks := 0
var failures := 0
var app: Node
var save: Node
var audio: Node
var out := ""
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL volume: ",message)
func frames(n := 3) -> void:
	for i in n: await process_frame
func touch(pos: Vector2, pressed: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = pos
	e.pressed = pressed
	root.push_input(e,true)
func point(slider: Control, percent: int) -> Vector2:
	return slider.global_position + Vector2(8.0+(slider.track_width()-16)*percent/100.0,slider.size.y/2)
func set_volume(slider: Control, percent: int) -> void:
	var p := point(slider,percent)
	touch(p,true)
	touch(p,false)
func tap(c: Control) -> void:
	touch(c.get_global_rect().get_center(),true)
	touch(c.get_global_rect().get_center(),false)
func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e,true)
	e = InputEventKey.new()
	e.keycode = code
	e.pressed = false
	root.push_input(e,true)
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--volume-out="): out = arg.get_slice("=",1)
	app = root.get_node("App")
	save = root.get_node("Save")
	audio = root.get_node("Audio")
	save.path = "user://volume_settings_test.json"
	save.progress = save.fresh()
	save.save_progress()
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await frames(6)
	var menu: Control = app.ui_layer.get_child(0)
	tap(menu.btn_settings)
	await frames()
	var panel: Control = menu.settings_panel
	var sfx: Control = panel._rows[1].slider
	var music: Control = panel._rows[2].slider
	check(panel.visible and sfx.percent == 100 and music.percent == 80,"initial sound 100% and music 80%")
	check(panel.panel_rect.encloses(sfx.get_rect()) and sfx.size.y >= 40,"slider has a safe >=40px touch region")
	var before := FileAccess.get_file_as_string(save.path)
	touch(point(sfx,27),true)
	check(sfx.percent == 27 and is_equal_approx(audio.snapshot().volumes.sfx,0.27),"touch preview immediately changes real audio to 27%")
	check(float(save.progress.settings.sfx) == 1.0 and FileAccess.get_file_as_string(save.path) == before,"drag preview does not write the save")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point(sfx,35)
	root.push_input(drag,true)
	check(sfx.percent == 35 and is_equal_approx(audio.snapshot().volumes.sfx,0.35),"drag updates label and real audio to 35%")
	touch(point(sfx,35),false)
	check(is_equal_approx(float(save.progress.settings.sfx),0.35),"release commits 35%")
	check(FileAccess.get_file_as_string(save.path) != before,"release writes the setting")
	set_volume(music,62)
	check(music.percent == 62 and is_equal_approx(audio.snapshot().volumes.music,0.62),"music independently adjusts to 62%")
	check(is_equal_approx(audio.snapshot().volumes.sfx,0.35),"music leaves sound effects at 35%")
	set_volume(sfx,0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")),"0% mutes effects and UI feedback")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"effects mute leaves music enabled")
	set_volume(sfx,100)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and is_zero_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))),"100% unmutes effects at configured maximum")
	set_volume(sfx,50)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - audio.slider_to_db(0.5)) < 0.01,"50% uses the existing perceptual audio taper")
	key(KEY_RIGHT)
	check(sfx.percent == 51,"keyboard right adjusts one percent")
	key(KEY_LEFT)
	check(sfx.percent == 50,"keyboard left adjusts one percent")
	key(KEY_HOME)
	check(sfx.percent == 0,"Home reaches 0%")
	key(KEY_LEFT)
	check(sfx.percent == 0,"lower endpoint clamps")
	key(KEY_END)
	check(sfx.percent == 100,"End reaches 100%")
	key(KEY_RIGHT)
	check(sfx.percent == 100,"upper endpoint clamps")
	touch(point(sfx,71),true)
	sfx.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(point(sfx,71),false)
	check(sfx._finger == -2 and is_equal_approx(float(save.progress.settings.sfx),0.71),"focus loss releases and saves the last preview")
	tap(panel._close)
	tap(menu.btn_settings)
	check(sfx.percent == 71 and music.percent == 62,"reopening preserves exact percentages")
	tap(panel._credits_btn)
	check(not sfx.visible and not music.visible,"credits hide both volume controls")
	tap(panel._close)
	check(sfx.visible and music.visible,"back from credits restores volume controls")
	tap(panel._close)
	app.start_round("r01",true)
	await frames(6)
	app.battle.set_paused(true)
	var hud: Control = app.ui_layer.get_child(0)
	hud._on_settings()
	panel = hud.settings_panel
	check(panel.visible and panel._rows[1].slider.percent == 71,"pause settings show the persisted percentage")
	set_volume(panel._rows[1].slider,41)
	check(app.battle.sim.paused and is_equal_approx(audio.snapshot().volumes.sfx,0.41),"pause settings adjust audio while battle remains paused")
	save.load_progress()
	check(is_equal_approx(float(save.progress.settings.sfx),0.41) and is_equal_approx(float(save.progress.settings.music),0.62),"disk reload restores both volume percentages")
	if out != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(out)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("volume-settings.png"))
	print("VOLUME_SETTINGS checks=%d failures=%d user_dir=%s" % [checks,failures,OS.get_user_data_dir()])
	app.show_screen(&"menu")
	audio.prepare_quit()
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)
