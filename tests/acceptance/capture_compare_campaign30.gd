extends SceneTree
## Identical r08 / 18 allied and 18 enemy units on v0.1.3 and current code.
var out := ""
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): out = a.get_slice("=",1)
	_run.call_deferred()
func _run() -> void:
	var app = root.get_node("App")
	var save = root.get_node("Save")
	save.path = "user://compare/save.json"
	save.progress = save.fresh()
	save.progress.unlocked_round = 30
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	for i in 5: await process_frame
	app.start_round("r08",true)
	for i in 3: await process_frame
	var b = app.battle
	b.set_process(false)
	var sim = b.sim
	var center: float = sim.L-200
	sim.hero.x = center-110
	for i in 18:
		sim.card_cd.melee_basic = 0
		sim.gold = 500
		sim.deploy("melee_basic")
		sim.players.back().x = center-25
		sim.players.back().lane_y = 0
		var e = sim._spawn_enemy("e_grunt")
		e.x = center+10
		e.lane_y = 0
	b._cam_x = center
	b._update_camera(0)
	b._publish()
	# Performance monitors refresh once per second; exclude scene/font startup samples.
	for i in 180: await process_frame
	var durations := []
	for i in 120:
		await process_frame
		durations.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png(out.path_join("r08_dense.png"))
	durations.sort()
	var report := {"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"process_ms_p50":durations[durations.size()/2],"process_ms_p95":durations[int(durations.size()*0.95)],"units":37,"zoom":b.world_zoom}
	FileAccess.open(out.path_join("compare.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[compare] ",JSON.stringify(report))
	quit()
