extends SceneTree
## 09-art-world: deterministic real-game captures for background / base / FX A/B comparisons.
## Copy into a HEAD snapshot as res://art09_check/world_cam.gd (tools/art is .gdignore'd) and launch through 04's
## secondary-monitor launcher inside coordination/heavy_run.ps1:
##   .\tools\build\visible_launch.ps1 -ProjectPath <snapshot> -Script res://art09_check/world_cam.gd -Resolution 640x360
##       -UserArgs '--shot-dir=<abs>','--plan=r01:30,60;r06:46,75;r10:60,110'
## For each round: App.autoplay = true (seed = deterministic default + round index, 02 competent bot), Engine.time_scale 0,
## then the battle is advanced by calling battle._process(SIM_STEP) until sim.t reaches each capture time, so the same
## plan gives the same game state in every build (the art pages do not affect the simulation). Per capture time:
##   <round>_<t>_full.png  real render (units, fx, HUD)
##   <round>_<t>_bg.png    same frame with every unit, projectile, fx and damage number hidden (background + bases + HUD)
## and world_report.json with cam_x, view, ground_y, every unit/fx/projectile (anim set, frame index, rect, pivot,
## screen position) and both base states. With --bases, the last battle also gets scripted base captures: each base at
## 40 % hp (damaged) and 0 hp (ruined), camera on the base, no simulation step (base_<side>_<state>_full/_bg.png).
## Isolated save user://art09/world_save.json. No game code is changed.

var shot_dir := ""
var plan := {"r01": [30.0, 60.0], "r06": [46.0, 75.0], "r10": [60.0, 110.0]}
var order := ["r01", "r06", "r10"]
var report := {"captures": []}
var app: Node
var do_bases := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--bases":
			do_bases = true
		elif a.begins_with("--shot-dir="):
			shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--plan="):
			plan = {}
			order = []
			for part in a.get_slice("=", 1).split(";"):
				var rid := part.get_slice(":", 0)
				var ts: Array = []
				for s in part.get_slice(":", 1).split(","):
					ts.append(float(s))
				plan[rid] = ts
				order.append(rid)
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://art09")
		save.path = "user://art09/world_save.json"
		save.progress = save.fresh()
		save.progress.unlocked_round = 10
		save.save_progress()
	_run.call_deferred()

func _frames(n := 3) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(4)
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.get_texture().get_image().save_png(shot_dir.path_join("%s.png" % name))

func _rec_info(rec, fi: int) -> Dictionary:
	return {"frame_index": fi, "rect": [rec.rects[fi].position.x, rec.rects[fi].position.y, rec.rects[fi].size.x, rec.rects[fi].size.y],
		"pivot": [rec.pivots[fi].x, rec.pivots[fi].y]}

func _state(battle) -> Dictionary:
	var sim = battle.sim
	var view = battle.view
	var atlas = root.get_node("Atlas")
	var units := []
	var all := []
	for u in sim.players: all.append(u)
	for u in sim.enemies: all.append(u)
	if sim.hero_respawn <= 0.0: all.append(sim.hero)
	for u in all:
		var anim: String = view._anim_name(u)
		var info := {"id": u.id, "anim_set": u.anim_set, "side": u.side, "x": roundf(u.x), "y": roundf(view.ground_y + u.lane_y),
			"anim": anim, "is_hero": u.is_hero, "dying": u.dying, "flash": u.flash > 0.0,
			"flip": (u.side < 0) if not u.is_hero else (sim.hero_dir < 0)}
		var rec = atlas.anim_rec(u.anim_set, anim)
		if rec != null:
			info.merge(_rec_info(rec, atlas.rec_index(rec, u.anim_t)))
		units.append(info)
	var fxs := []
	for f in sim.fxs:
		if not f.alive:
			continue
		var info := {"kind": f.kind, "x": f.x, "y": view.ground_y + f.y, "t": f.t}
		var rec = atlas.anim_rec(f.kind, "play")
		if rec == null:
			rec = atlas.anim_rec(f.kind, "loop")
		if rec != null:
			info.merge(_rec_info(rec, atlas.rec_index(rec, f.t)))
		fxs.append(info)
	var projs := []
	for p in sim.projectiles:
		if p.alive:
			projs.append({"kind": p.kind, "x": p.x, "side": p.side})
	var bases := {}
	for pair in [["player", sim.player_base], ["enemy", sim.enemy_base]]:
		var b: Dictionary = pair[1]
		bases[pair[0]] = {"x": b.x, "ratio": b.hp / b.hp_max}
	return {"t": sim.t, "cam_x": view.cam_x, "cam_pos_x": battle.cam.position.x, "view_top": view.view_top, "view_w": view.view_w,
		"ground_y": view.ground_y, "units": units, "fx": fxs, "projectiles": projs, "bases": bases,
		"texts": sim.texts.filter(func(tx): return tx.alive).size()}

func _hide(battle) -> Array:
	var sim = battle.sim
	var saved := []
	var who: Array = []
	for u in sim.players: who.append(u)
	for u in sim.enemies: who.append(u)
	who.append(sim.hero)
	for u in who:
		saved.append([u, u.x])
		u.x = -9000.0
	var flags := []
	for arr in [sim.projectiles, sim.fxs, sim.texts]:
		for e in arr:
			flags.append([e, e.alive])
			e.alive = false
	return [saved, flags]

func _restore(state: Array) -> void:
	for s in state[0]:
		s[0].x = s[1]
	for f in state[1]:
		f[0].alive = f[1]

func _run() -> void:
	app = root.get_node("App")
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	report["window"] = DisplayServer.window_get_size()
	report["view"] = root.get_visible_rect().size
	Engine.time_scale = 0.0          # from here on real frames never advance a battle; only the manual steps below do
	for rid in order:
		app.autoplay = true          # deterministic seed + competent bot; app.gd also skips its focus-loss pause
		root.get_node("Events").cmd_start_round.emit(rid)
		await _frames(4)
		var battle = app.battle
		if battle == null or battle.sim == null:
			report.captures.append({"round": rid, "error": "no battle"})
			continue
		var step: float = 1.0 / 60.0
		for t in plan[rid]:
			var guard := 0
			while battle.sim.t < t and not battle.sim.ended and guard < 200000:
				battle._process(step)
				guard += 1
			await _frames(2)
			var st := _state(battle)
			st["round"] = rid
			st["name"] = "%s_%03d" % [rid, int(t)]
			st["ended"] = battle.sim.ended
			await _shot(st.name + "_full")
			var hidden := _hide(battle)
			await _shot(st.name + "_bg")
			_restore(hidden)
			report.captures.append(st)
	if do_bases and app.battle != null and app.battle.sim != null:
		# scripted base states in the last battle (real renderer, no sim step): damaged (40 % hp) and ruined (0 hp)
		var battle = app.battle
		var sim = battle.sim
		for pair in [["damaged", 0.4], ["ruined", 0.0]]:
			for key in ["player", "enemy"]:
				var b: Dictionary = sim.player_base if key == "player" else sim.enemy_base
				var keep_hp: float = b.hp
				b.hp = b.hp_max * float(pair[1])
				battle._free_cam_t = 600.0
				battle._cam_x = b.x + (150.0 if key == "player" else -150.0)
				battle._update_camera(0.0)
				await _frames(2)
				var st := _state(battle)
				st["round"] = "bases"
				st["name"] = "base_%s_%s" % [key, pair[0]]
				st["ended"] = sim.ended
				await _shot(st.name + "_full")
				var hidden := _hide(battle)
				await _shot(st.name + "_bg")
				_restore(hidden)
				b.hp = keep_hp
				report.captures.append(st)
	Engine.time_scale = 1.0
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join("world_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " "))
		f.close()
	quit(0)
