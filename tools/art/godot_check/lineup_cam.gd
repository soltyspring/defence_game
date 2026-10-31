extends SceneTree
## 03-art: deterministic real-game lineup capture for A/B art comparisons (A26 silhouette test).
## Run in a HEAD snapshot only (copy to res://art03_check/), through 04's secondary-monitor launcher:
##   .\tools\build\visible_launch.ps1 -ProjectPath <snapshot> -Script res://art03_check/lineup_cam.gd -UserArgs '--shot-dir=<abs>'
## Boots the real main.tscn, starts r01, freezes time (Engine.time_scale 0), replaces the armies with a fixed, non-overlapping
## lineup (same x, lane_y 0, fixed anim time) and fixes the camera, then captures:
##   lineup_<pose>_full.png  real render with units
##   lineup_<pose>_bg.png    same frame with every unit moved off screen (background only)
## for pose = walk (anim_t 0) and attack (anim_t 0.22). Writes lineup_report.json with every unit's
## anim set, anim, frame index, atlas rect, pivot and screen position, so masks can be rebuilt from the
## atlas exactly. Isolated save user://art03/lineup_save.json. Owner: 03-art. No game code is changed.

const ALLIES := [["ranged_basic", 220.0], ["tank", 260.0], ["melee_basic", 300.0], ["HERO", 345.0], ["melee_basic", 390.0]]
const ENEMIES := [["e_grunt", 440.0], ["e_spitter", 480.0], ["e_brute", 530.0]]
const CAM_X := 375.0

var shot_dir := ""
var report := {"poses": {}}
var app: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): shot_dir = a.get_slice("=", 1)
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://art03")
		save.path = "user://art03/lineup_save.json"
		save.progress = save.fresh()
		save.progress.unlocked_round = 10
		save.save_progress()
	_run.call_deferred()

func _frames(n := 3) -> void:
	for i in n: await process_frame

func _shot(name: String) -> void:
	await _frames(4)
	if shot_dir == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.get_texture().get_image().save_png(shot_dir.path_join("lineup_%s.png" % name))

func _unit_info(battle, u) -> Dictionary:
	var view = battle.view
	var anim: String = view._anim_name(u)
	var rec = root.get_node("Atlas").anim_rec(u.anim_set, anim)
	var info := {"id": u.id, "anim_set": u.anim_set, "side": u.side, "x": u.x, "lane_y": u.lane_y, "anim": anim,
		"is_hero": u.is_hero, "flip": (u.side < 0) if not u.is_hero else (battle.sim.hero_dir < 0)}
	if rec != null:
		var fi: int = root.get_node("Atlas").rec_index(rec, u.anim_t)
		info["frame_index"] = fi
		info["rect"] = [rec.rects[fi].position.x, rec.rects[fi].position.y, rec.rects[fi].size.x, rec.rects[fi].size.y]
		info["pivot"] = [rec.pivots[fi].x, rec.pivots[fi].y]
	return info

func _place(battle, state: int, anim_t: float) -> Array:
	var sim = battle.sim
	var content = root.get_node("Content")
	sim.players.clear()
	sim.enemies.clear()
	for p in sim.projectiles: p.alive = false
	for f in sim.fxs: f.alive = false
	for tx in sim.texts: tx.alive = false
	var units: Array = []
	for e in ALLIES:
		var u
		if e[0] == "HERO":
			u = sim.hero
			sim.hero_respawn = 0.0
			sim.hero_dir = 0
		else:
			u = sim._new_unit(content.get_unit(e[0]), sim.SIDE_PLAYER, e[1])
			sim.players.append(u)
		u.x = e[1]
		units.append(u)
	for e in ENEMIES:
		var u = sim._new_unit(content.get_unit(e[0]), sim.SIDE_ENEMY, e[1])
		sim.enemies.append(u)
		units.append(u)
	for u in units:
		u.lane_y = 0.0
		u.state = state
		u.anim_t = anim_t
		u.flash = 0.0
		u.buff_t = 0.0
		u.hp = u.hp_max
	battle._free_cam_t = 600.0
	battle._cam_x = CAM_X
	return units

func _run() -> void:
	app = root.get_node("App")
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	root.get_node("Events").cmd_start_round.emit("r01")
	await _frames(10)
	var battle = app.battle
	if battle == null or battle.sim == null:
		report["error"] = "no battle"
	else:
		var sim = battle.sim
		app.autoplay = true          # app.gd skips its focus-loss auto-pause when autoplay is set (battle already started without the bot)
		Engine.time_scale = 0.0      # freeze sim and anim time without sim.paused (the HUD shows the pause menu for paused)
		report["ground_y"] = battle.view.ground_y
		report["view_w"] = root.get_visible_rect().size.x
		report["window"] = DisplayServer.window_get_size()
		for pose in [["walk", sim.S_WALK, 0.0], ["attack", sim.S_ATTACK, 0.22]]:
			var units := _place(battle, pose[1], pose[2])
			await _frames(4)
			var infos := []
			for u in units: infos.append(_unit_info(battle, u))
			report.poses[pose[0]] = {"units": infos, "cam_x": battle._cam_x, "view_top": battle.view.view_top}
			await _shot(pose[0] + "_full")
			for u in units: u.x = -9000.0
			await _shot(pose[0] + "_bg")
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join("lineup_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " "))
		f.close()
	quit(0)
