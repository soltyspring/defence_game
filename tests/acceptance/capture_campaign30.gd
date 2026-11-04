extends SceneTree
## Controlled real-render scenarios, private save. No asset generation or live-player data.
var out := ""
var failures := 0
var checks := 0
var report := {}
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): out = a.get_slice("=",1)
	_run.call_deferred()
func frames(n := 3) -> void:
	for i in n: await process_frame
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL capture: ",msg)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func tap(c: Control, relative := Vector2(0.5,0.5)) -> void:
	var p := c.global_position+c.size*relative
	for down in [true,false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = p
		e.pressed = down
		root.push_input(e,true)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	var c = root.get_node("Content")
	save.path = "user://campaign_capture/save.json"
	save.progress = save.fresh()
	save.progress.unlocked_round = 31
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await frames(5)
	for rid in ["r14","r21","r30"]:
		app.start_round(rid,true)
		await frames(3)
		var b = app.battle
		b.set_process(false)
		var sim = b.sim
		var hud = app.ui_layer.get_child(0)
		var center: float = sim.L-200
		sim.hero.x = center-100
		for i in 18:
			sim.card_cd.melee_basic = 0
			sim.gold = 1000
			sim.deploy("melee_basic")
			var u = sim.players.back()
			u.x = center-25
			u.lane_y = 0
		for i in 12:
			var u = sim._spawn_enemy(["e_guard","e_mortar","e_runner"][i%3])
			u.x = center+20+(i%3)*16
			u.lane_y = 0
		if rid == "r30":
			var boss = sim._spawn_enemy("boss_ovenheart")
			boss.x = center+100
		b._cam_x = center
		b._scouting = false
		b._update_camera(0)
		b._publish()
		b.view._update_formation(1.0)
		await frames(8)
		check(not hud.btn_follow.visible,"follow button hidden until scouting")
		await shot(rid+"_crowd")
		var positions := {}
		for u in sim.players: positions[b.view._unit_pos(u)] = true
		check(positions.size() >= 8,"dense friendly formation remains differentiated")
		report[rid] = {"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"distinct_friendly_positions":positions.size(),"minimap":str(hud.minimap.get_rect()),"world_zoom":b.world_zoom}
		var hero_before: float = sim.hero.x
		tap(hud.minimap,Vector2(0.15,0.5))
		await frames()
		check(b._scouting and hud.btn_follow.visible and is_equal_approx(sim.hero.x,hero_before),"small minimap scouts without moving hero")
		tap(hud.btn_follow)
		await frames()
		check(not b._scouting and not hud.btn_follow.visible,"follow restores camera and hides extra button")
		b._cam_x = center
		b._update_camera(0)
		var offsets := {}
		for i in 60:
			if i%5 == 0: sim._damage_base(-1,13)
			sim._step_fx(1.0/60)
			b.view.render_ahead = 0
			await frames(1)
			for serial in b.view._text_offsets:
				if offsets.has(serial): check(offsets[serial] == b.view._text_offsets[serial],"damage offset stays fixed throughout life")
				offsets[serial] = b.view._text_offsets[serial]
			if i in [3,12,24,36]: await shot(rid+"_damage_%02d"%i)
		check(b.view.texts_dropped == 0 and b.view._text_offsets.size() <= sim.caps.text,"continuous base hits do not drop or leak text")
	app.show_screen(&"round_select")
	await frames(5)
	await shot("round30_select")
	report.checks = checks
	report.failures = failures
	FileAccess.open(out.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[campaign_capture] ",JSON.stringify(report))
	quit(0 if failures == 0 else 1)
