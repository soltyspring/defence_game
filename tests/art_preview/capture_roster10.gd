extends SceneTree
## Real game frames of the five campaign-100 units (baguette, macaron, chili, donut, waffle): their loadout cards and
## all five on the lane against grunts, at two moments of the fight.
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_roster10.gd -- --out=<abs dir>
## Isolated save; the player's save is not written.
const IDS := ["baguette", "macaron", "chili", "donut", "waffle"]
var out_dir := "user://art_preview/roster10"

func _initialize() -> void: _run.call_deferred()

func frames(n := 4) -> void:
	for i in n: await process_frame

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	DirAccess.make_dir_recursive_absolute("user://art_preview")
	save.path = "user://art_preview/save.json"
	save.progress = save.fresh()
	save.progress.unlocked_round = 100
	save.progress.loadout = IDS.duplicate()
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	var size: Vector2i = DisplayServer.window_get_size()
	for rid in ["r41", "r81"]:
		app.start_round(rid)          # not forced: a forced start ignores the saved loadout
		await frames(6)
		var sim = app.battle.sim
		sim.spawn_queue.clear()
		sim.trickle_next = -1.0
		sim.time_limit = 0.0
		sim.enemy_tower_mult = 0.0
		sim.hero.hp_max *= 40.0
		sim.hero.hp = sim.hero.hp_max
		var x0: float = sim.L * 0.3
		sim.hero.x = x0 - 40.0
		var i := 0
		for uid in IDS:
			sim.gold = 999.0
			sim.card_cd[uid] = 0.0
			var why: String = sim.deploy(uid)
			if why != "":
				printerr("[roster10] deploy ", uid, " ", why)
			else:
				var u = sim.players.back()
				u.x = x0 + i * 22.0
				u.hp_max *= 40.0
				u.hp = u.hp_max
			i += 1
		for off in [140.0, 165.0, 190.0]:
			var e = sim._spawn_enemy("e_grunt")
			e.x = x0 + off
			e.hp_max *= 40.0
			e.hp = e.hp_max
		for shot in 2:
			await frames(50 if shot == 0 else 140)
			for attempt in 5:
				if not sim.paused: break
				root.get_node("Events").cmd_set_paused.emit(false)
				await frames(40)
			var path := "%s/%s_%d_%dx%d.png" % [out_dir, rid, shot, size.x, size.y]
			root.get_texture().get_image().save_png(path)
			print("[roster10] ", path)
		app.show_screen(&"menu")
		await frames(4)
	quit(0)
