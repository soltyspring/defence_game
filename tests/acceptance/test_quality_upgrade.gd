extends SceneTree
## Actual input routing + frozen gameplay assertions; visible mode also probes raster motion.
const Supply = preload("res://src/gameplay/bakery_supply.gd")
const Layout = preload("res://src/ui/hud_layout.gd")
var failures := 0
var checks := 0
var app: Node
var events: Node
var out := "user://quality"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL quality: ", message)
func frames(n := 3) -> void:
	for i in n: await process_frame
func touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = index
	root.push_input(e, true)
func tap(control: Control) -> void:
	var p := control.get_global_rect().get_center()
	touch(p, true)
	touch(p, false)
func mouse(pos: Vector2, pressed: bool, device := 0) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.device = device
	root.push_input(e,true)
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# This harness freezes View._process; apply its normal parallax update before
	# capturing a changed camera, otherwise the image would show the previous plane.
	if app.battle:
		var b = app.battle
		b.view.environment.present(b.view.cam_x,b.world_zoom,float(app.pixel_scale),b.sim.t)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality-out="): out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	app = root.get_node("App")
	events = root.get_node("Events")
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await frames()
	app.start_round("r01", true)
	await frames(8)
	var b = app.battle
	check(b != null, "real battle mounted")
	if b == null: quit(1); return
	b.set_process(false) # freeze sim, production, animations: scouting must not mutate any of them
	b.view.set_process(false)
	var hud: Control = app.ui_layer.get_child(0)
	var map: Control = hud.minimap
	check(not map.state.is_empty(), "real HudSnapshot supplies map")
	var hero_x := float(b.sim.hero.x)
	var gold := float(b.sim.gold)
	var sim_time := float(b.sim.t)
	var r := map.get_global_rect()
	touch(Vector2(r.end.x - 15, r.get_center().y), true)
	touch(Vector2(r.end.x - 15, r.get_center().y), false)
	await frames()
	check(b._scouting, "tap through Viewport enters scouting")
	check(b.cam.position.x > b.sim.L * 0.7, "tap reveals far battlefield")
	check(is_equal_approx(b.sim.hero.x, hero_x) and is_equal_approx(b.sim.gold, gold) and is_equal_approx(b.sim.t, sim_time), "scouting does not teleport hero, spend flour or advance sim")
	await shot("scout_far")
	var start := Vector2(r.get_center().x, r.get_center().y)
	touch(start, true, 2)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(r.position.x + 20, start.y)
	drag.relative = drag.position - start
	root.push_input(drag, true)
	touch(drag.position, false, 2)
	await frames()
	check(b.cam.position.x < b.sim.L * 0.3, "touch drag pans to home")
	check(map._finger == -1, "touch release ends drag")
	mouse(start,true)
	# Desktop touch emulation can accompany the physical mouse press/release.
	touch(start,true)
	mouse(start,false)
	touch(start,false)
	var cx := float(b.cam.position.x)
	var hover := InputEventMouseMotion.new()
	hover.position = Vector2(r.position.x+20,start.y)
	hover.global_position = hover.position
	root.push_input(hover,true)
	check(not map._mouse_down and map._finger == -1 and is_equal_approx(b.cam.position.x,cx), "mouse release plus emulated touch cannot leave hover panning")
	mouse(hover.position,true,InputEvent.DEVICE_ID_EMULATION)
	mouse(hover.position,false,InputEvent.DEVICE_ID_EMULATION)
	check(is_equal_approx(b.cam.position.x,cx), "emulated mouse does not duplicate touch commands")
	check(map.world_at(-1000) == float(map.state.left) and map.world_at(99999) == float(map.state.right), "out-of-range map positions clamp")
	tap(hud.btn_follow)
	await frames()
	check(not b._scouting and b.cam.position.x < b.sim.L * 0.3, "Hero button returns to follow")
	touch(r.get_center(), true)
	touch(r.get_center(), false)
	touch(hud.btn_right.get_global_rect().get_center(), true, 3)
	check(not b._scouting, "movement cancels scouting")
	touch(hud.btn_right.get_global_rect().get_center(), false, 3)
	map._finger = 4
	map.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(map._finger == -1 and not map._mouse_down, "focus loss releases captured map input")
	for sec in [0.1,2.0,3.99]:
		var w := Supply.worker_state(0, sec, 40)
		check(w.left and not w.carry and w.walk, "outbound worker is empty")
	for sec in [4.81,6.0,8.79]:
		var w := Supply.worker_state(0, sec, 40)
		check(not w.left and w.carry and w.walk, "returning worker carries flour")
	check(Supply.MILL_FROM_BASE - Supply.GATE_FROM_BASE >= 120, "delivery route expanded from 28 to at least 120 world pixels")
	check(not Supply.worker_state(0,9.0,40).walk, "unloading has a visible dwell")
	for size in [Vector2(640,360),Vector2(800,360),Vector2(800,450),Vector2(960,540)]:
		for inset in [0.0, 17.0, 34.0]:
			for target in [40.0,44.0,48.0]:
				var safe := Rect2(inset,0,size.x-inset*2,size.y)
				var layout := Layout.compute(size,safe,5,3,target)
				var errors := Layout.validate(layout)
				check(errors.is_empty(), "minimap layout %s/%s/%s: %s" % [size,inset,target,errors])
	b._on_camera_follow()
	b.sim.t = 6.0
	b._publish()
	await frames()
	await shot("home_supply")
	if DisplayServer.get_name() != "headless": await motion_probe(b)
	print("QUALITY_PERF ",JSON.stringify(root.get_node("Perf").snapshot()))
	print("QUALITY_UPGRADE checks=%d failures=%d" % [checks,failures])
	app.show_screen(&"menu")
	await frames(4)
	root.get_node("Audio").prepare_quit()
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)

func motion_probe(b) -> void:
	# Measure real Canvas2D transforms, then actual rendered hero silhouettes with
	# a hidden-hero control frame. The whole scene is frozen between each pair.
	app.ui_layer.visible = false
	b._scouting = true
	b.sim.hero.x = 210.0
	var widths: Array[int] = []
	var camera_steps: Array[float] = []
	var previous := 0.0
	for i in 12:
		b._cam_x = 202.0 + i * 0.12
		b._update_camera(0.0)
		b.cam.force_update_scroll()
		b.view.environment.present(b.view.cam_x,b.world_zoom,float(app.pixel_scale),b.sim.t)
		b.sim.hero_respawn = 0.0
		b.view.queue_redraw()
		await frames(2)
		await RenderingServer.frame_post_draw
		var with_hero := root.get_texture().get_image()
		var shift: float = root.get_canvas_transform().origin.x * app.pixel_scale
		check(absf(shift-roundf(shift)) < 0.002, "actual canvas translation on device grid")
		if i > 0: camera_steps.append(absf(shift-previous))
		previous = shift
		b.sim.hero_respawn = 99.0
		b.view.queue_redraw()
		await frames(2)
		await RenderingServer.frame_post_draw
		var without_hero := root.get_texture().get_image()
		var left := with_hero.get_width()
		var right := -1
		# Only the hero's vicinity; the rest of the scene is a frozen control.
		var center: Vector2 = (b.view.get_global_transform_with_canvas() * Vector2(b.sim.hero.x,b.view.ground_y)) * app.pixel_scale
		for y in range(maxi(0,int(center.y)-140),mini(with_hero.get_height(),int(center.y)+10)):
			for x in range(maxi(0,int(center.x)-120),mini(with_hero.get_width(),int(center.x)+120)):
				var diff := with_hero.get_pixel(x,y) - without_hero.get_pixel(x,y)
				if absf(diff.r) + absf(diff.g) + absf(diff.b) > 0.03:
					left = mini(left,x)
					right = maxi(right,x)
		widths.append(right-left+1)
		if i in [0,5,11]: with_hero.save_png(out.path_join("motion_%02d.png" % i))
	check(widths.min() > 20 and widths.max()-widths.min() <= 1, "rendered hero width stays constant during slow travel: %s" % [widths])
	check(camera_steps.max() <= 1.01, "slow travel advances at most one device pixel per frame: %s" % [camera_steps])
	var file := FileAccess.open(out.path_join("motion.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"hero_widths":widths,"camera_steps":camera_steps,"k":app.pixel_scale,"zoom":b.world_zoom},"\t"))
