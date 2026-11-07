extends SceneTree
## Window-client pixel events: deliberately do not bypass the viewport stretch transform.
var failures := 0
var checks := 0
var held_button: Control
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL resolution: ",message)
func tap(c: Control, touch := false) -> void:
	if c == null: return
	var pixel := root.get_final_transform() * c.get_global_rect().get_center()
	check(Rect2(Vector2.ZERO,root.size).has_point(pixel),"drawn button center stays inside native client area")
	for down in [true,false]:
		if touch:
			var e := InputEventScreenTouch.new()
			e.index = 0
			e.position = pixel
			e.pressed = down
			root.push_input(e,false)
		else:
			var e := InputEventMouseButton.new()
			e.device = 32
			e.position = pixel
			e.global_position = pixel
			e.button_index = MOUSE_BUTTON_LEFT
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			e.pressed = down
			root.push_input(e,false)
func _run() -> void:
	var app = root.get_node("App")
	var save = root.get_node("Save")
	save.path = "user://resolution-input/save.json"
	save.progress = save.fresh()
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await frames()
	root.notify_mouse_entered()
	for sz in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1600,900),Vector2i(800,450),Vector2i(640,360),Vector2i(1280,800)]:
		root.size = sz
		await frames(10)
		var k := maxi(1,mini(sz.x/640,sz.y/360))
		check(root.get_visible_rect().size.is_equal_approx(Vector2(sz/k)),"logical view follows the current native size %s"%sz)
		print("[window] native=",DisplayServer.window_get_size()," root=",root.size," final=",root.get_final_transform()," screen=",root.get_screen_transform())
		for touch in [false,true]:
			app.show_screen(&"menu")
			await frames()
			var menu = app.ui_layer.get_child(-1)
			tap(menu.btn_settings,touch)
			await frames()
			if not is_instance_valid(menu):
				check(false,"settings pixel hit another menu action at %s"%sz)
				continue
			check(menu.settings_panel.visible,"settings opens at %s touch=%s"%[sz,touch])
			tap(menu.settings_panel._close,touch)
			await frames()
			check(not menu.settings_panel.visible,"settings closes at %s touch=%s"%[sz,touch])
			app.start_round("r08",true)
			await frames()
			var hud = app.ui_layer.get_child(-1)
			var sim = app.battle.sim
			sim.gold = sim.gold_max
			app.battle._publish()
			await frames()
			var count: int = sim.players.size()
			tap(hud.card_buttons[0],touch)
			await frames()
			check(sim.players.size() > count,"card deploys at %s touch=%s"%[sz,touch])
			app.battle.set_paused(false)
			tap(hud.btn_pause,touch)
			await frames()
			check(sim.paused,"pause button at %s touch=%s"%[sz,touch])
			print("[resolution] ",sz," logical=",root.get_visible_rect().size," root_ui=",hud.size," scale=",root.get_stretch_transform())
	# Reproduce a native capture loss: pointer held during resize, then a new click.
	app.show_screen(&"menu")
	await frames()
	var menu = app.ui_layer.get_child(-1)
	var button: Control = menu.btn_settings
	var down := InputEventMouseButton.new()
	down.device = 32
	down.position = root.get_final_transform()*button.get_global_rect().get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.pressed = true
	root.push_input(down,false)
	check(button.is_pressed,"pointer capture starts before resize")
	root.size = Vector2i(1366,768)
	await frames(10)
	check(not button.is_pressed,"resize cancels obsolete pointer capture")
	tap(button)
	await frames()
	check(menu.settings_panel.visible,"first new click works after resize without old mouse-up")
	for factor in [1.0,1.25,1.5]:
		root.content_scale_factor = factor
		await frames(10)
		app.show_screen(&"menu")
		await frames()
		menu = app.ui_layer.get_child(-1)
		tap(menu.btn_settings)
		await frames()
		check(menu.settings_panel.visible,"screen-pixel settings hit with content scale %s"%factor)
	root.content_scale_factor = 1.0
	for mode in [Window.MODE_MAXIMIZED,Window.MODE_FULLSCREEN]:
		root.mode = mode
		await frames(20)
		app.show_screen(&"menu")
		await frames()
		menu = app.ui_layer.get_child(-1)
		tap(menu.btn_settings)
		await frames()
		check(menu.settings_panel.visible,"native window mode %s accepts screen-pixel clicks"%mode)
	root.mode = Window.MODE_WINDOWED
	app.show_screen(&"menu")
	await frames()
	print("[resolution] checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
