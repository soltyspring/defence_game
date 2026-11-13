extends SceneTree
## First run as a new player, through real taps (input events at button centres): menu -> 시작 -> R01 with its
## tutorial (follows each hint: card, hero move, baker, push) -> rest of the fight played by the casual bot ->
## result -> 다음 -> back to the menu -> quit dialog. Captures each step and logs a timeline (sim time, tutorial
## hints, toasts, screens) for a UX review.
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_first_run.gd -- --out=<abs dir>
## Isolated save; the player's save is not written.
const Bot := preload("res://src/gameplay/bot_player.gd")
var out_dir := "user://art_preview/first_run"
var size := Vector2i.ZERO
var n := 0
var log_lines: Array = []
var app
var t0 := 0

func _initialize() -> void: _run.call_deferred()

func frames(k := 4) -> void:
	for i in k: await process_frame

func note(s: String) -> void:
	var sim_t := ""
	if app != null and app.battle != null and app.battle.sim != null: sim_t = " sim=%.1f" % app.battle.sim.t
	var line := "[%5.1fs%s] %s" % [(Time.get_ticks_msec() - t0) / 1000.0, sim_t, s]
	log_lines.append(line)
	print("[first-run] ", line)

func shot(name: String) -> void:
	await frames(3)
	n += 1
	var path := "%s/%02d_%s_%dx%d.png" % [out_dir, n, name, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	note("shot " + path.get_file())

func tap(c: Control, hold_frames := 2) -> void:
	if c == null or not c.is_visible_in_tree():
		note("TAP MISSED (not visible) " + str(c))
		return
	var p: Vector2 = c.get_global_rect().get_center()
	var vp := root
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = vp.get_final_transform() * p
	ev.global_position = ev.position
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(hold_frames)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)

func find(script_path: String) -> Node:
	for x in root.find_children("*", "", true, false):
		var s = x.get_script()
		if s != null and s.resource_path == script_path and x.is_inside_tree() and x.is_visible_in_tree(): return x
	return null

func _run() -> void:
	t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	app = root.get_node("App")
	var save = root.get_node("Save")
	var ev = root.get_node("Events")
	DirAccess.make_dir_recursive_absolute("user://art_preview")
	save.path = "user://art_preview/first_run_save.json"
	save.progress = save.fresh()
	ev.tutorial_step.connect(func(k): note("TUTORIAL " + (k if k != "" else "(hidden)")))
	ev.toast.connect(func(k, a): note("TOAST %s %s" % [k, a]))
	ev.screen_changed.connect(func(s, p): note("SCREEN %s %s" % [s, p]))
	ev.wave_cleared.connect(func(i): note("WAVE_CLEARED %s" % [i]))
	ev.battle_ended.connect(func(r): note("BATTLE_ENDED won=%s stars=%s time=%s coins=%s" % [r.get("won"), r.get("stars"), r.get("time"), r.get("coins")]))
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await frames(30)
	size = DisplayServer.window_get_size()
	await shot("menu")
	var menu = find("res://src/ui/main_menu.gd")
	note("menu play button text=" + str(menu.btn_play.text))
	await tap(menu.btn_play)
	await frames(20)
	await shot("battle_start")
	var hud = find("res://src/ui/hud.gd")
	var sim = app.battle.sim
	# follow the tutorial like a beginner: act on each hint ~1.5 s after it appears
	var seen := {}
	var deadline := 120.0
	var watch := 0
	while sim.t < deadline and not sim.ended:
		await frames(2)
		watch += 1
		if watch % 60 == 0:
			note("watch sim.t=%.2f sim.paused=%s tree.paused=%s battle_scale=%s ended=%s" % [sim.t, sim.paused, paused, app.battle.time_scale, sim.ended])
		if watch > 3000:
			note("STALL: giving up on the tutorial loop")
			break
		var key: String = app.battle.tutorial_key
		if key != "" and not seen.has(key):
			seen[key] = true
			await frames(20)
			await shot("tut_" + key)
			await frames(60)
			match key:
				"tut_deploy_unit": await tap(hud.card_buttons[0])
				"tut_move_hero": await tap(hud.btn_right, 90)
				"tut_buy_worker": await tap(hud.btn_worker)
		if seen.has("tut_destroy_base"): break
		if seen.has("tut_buy_worker") and int(sim.t) % 6 == 0 and sim.gold >= 30.0:
			await tap(hud.card_buttons[0])
	note("tutorial phase over: seen=%s" % [seen.keys()])
	await shot("mid_battle")
	# the rest: casual bot (a player who keeps sending soldiers and follows with the hero)
	app.battle.autoplay_bot = Bot.new(1, 7)
	Engine.time_scale = 4.0
	var last_shot: float = sim.t
	while not sim.ended and sim.t < 400.0:
		await frames(10)
		if sim.t - last_shot > 40.0:
			last_shot = sim.t
			Engine.time_scale = 1.0
			await shot("battle_t%d" % int(sim.t))
			Engine.time_scale = 4.0
	Engine.time_scale = 1.0
	note("battle over ended=%s enemy_base=%.0f player_base=%.0f t=%.1f" % [sim.ended, sim.enemy_base.hp, sim.player_base.hp, sim.t])
	await frames(90)
	await shot("result")
	var result = find("res://src/ui/result.gd")
	if result != null:
		note("result buttons: next=%s retry=%s menu=%s upgrades=%s" % [result.btn_next.visible, result.btn_retry.visible, result.btn_menu.visible, result.btn_upgrades.visible])
		await tap(result.btn_next)
		await frames(30)
		await shot("after_next")
	# pause menu in the new battle (if any), then leave to the menu
	if app.battle != null and app.battle.sim != null and not app.battle.sim.ended:
		hud = find("res://src/ui/hud.gd")
		if hud != null:
			await tap(hud.btn_pause)
			await frames(10)
			await shot("pause")
	app.show_screen(&"menu")
	await frames(20)
	await shot("menu_after")
	# back press on the menu: quit dialog
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(10)
	await shot("quit_dialog")
	var f := FileAccess.open(out_dir + "/timeline.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	quit(0)
