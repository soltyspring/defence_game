extends SceneTree
## 03-art: real-game capture of the enemy mould nest at the right edge (09 X9 art check).
## Run in a HEAD snapshot only, through 04's secondary-monitor launcher:
##   .\tools\build\visible_launch.ps1 -ProjectPath <snapshot> -Script res://tools/art/godot_check/nest_cam.gd `
##       -UserArgs '--shot-dir=<abs>','--round=r01'
## Boots the real main.tscn, starts the round, lets it run 6 s, then pans the battle camera the same
## way a drag does (sets the free-camera timer and camera x; no game code is changed) so that only the
## left 24 / 40 / 96 px of the nest frame are on screen, plus a close-up of the hero / toast knight at the
## start. Writes <shot-dir>/nest_cam_report.json (camera x, nest left edge, view width, paused flag).
## Isolated save: user://art03/nest_save.json. Owner: 03-art.

var shot_dir := ""
var round_id := "r01"
var report := {"shots": []}
var app: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--round="): round_id = a.get_slice("=", 1)
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://art03")
		save.path = "user://art03/nest_save.json"
		save.progress = save.fresh()
		save.progress.unlocked_round = 10
		save.save_progress()
	_run.call_deferred()

func _frames(n := 3) -> void:
	for i in n: await process_frame

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

func _shot(name: String, battle) -> void:
	await _frames(4)
	var sim = battle.sim
	var vw: float = root.get_visible_rect().size.x
	var nest_left: float = float(sim.enemy_base.x) - 48.0
	var view_right: float = float(battle._cam_x) + vw * 0.5
	var entry := {"name": name, "t": snappedf(sim.t, 0.01), "paused": bool(sim.paused), "cam_x": battle._cam_x,
		"view_w": vw, "nest_left_x": nest_left, "nest_px_on_screen": clampf(view_right - nest_left, 0.0, 96.0)}
	report.shots.append(entry)
	if shot_dir == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.get_texture().get_image().save_png(shot_dir.path_join("nest_cam_%s.png" % name))

func _pan(battle, nest_px: float) -> void:
	var vw: float = root.get_visible_rect().size.x
	var nest_left: float = float(battle.sim.enemy_base.x) - 48.0
	battle._free_cam_t = 30.0          # same field a drag sets: camera stops following the hero
	battle._cam_x = nest_left + nest_px - vw * 0.5
	await _frames(6)

func _run() -> void:
	app = root.get_node("App")
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	root.get_node("Events").cmd_start_round.emit(round_id)
	await _frames(6)
	var battle = app.battle
	if battle == null or battle.sim == null:
		report["error"] = "no battle"
	else:
		await _wait(6.0)
		await _shot("hero_close_06s", battle)
		for px in [24.0, 40.0, 96.0]:
			await _pan(battle, px)
			await _shot("vis%d" % int(px), battle)
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join("nest_cam_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " "))
		f.close()
	quit(0)
