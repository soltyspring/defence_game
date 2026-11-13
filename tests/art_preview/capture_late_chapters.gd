extends SceneTree
## Real game frames of the R41-R100 chapter backgrounds before their rounds exist on main: start R40, then rebuild the
## battle view's backdrop with round index 41/51/.../91 and take two shots along the lane with a small fight.
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_late_chapters.gd -- --out=<abs dir>
## Isolated save; the player's save is not written.
const Backdrop := preload("res://src/gameplay/lane_backdrop.gd")
var out_dir := "user://art_preview/late"

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
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	var size: Vector2i = DisplayServer.window_get_size()
	for index in [41, 51, 61, 71, 81, 91]:
		app.start_round("r40", true)
		await frames(6)
		var sim = app.battle.sim
		var view = app.battle.view
		sim.spawn_queue.clear()
		sim.trickle_next = -1.0
		sim.time_limit = 0.0
		sim.enemy_tower_mult = 0.0
		sim.hero.hp_max *= 40.0
		sim.hero.hp = sim.hero.hp_max
		view.environment.free()
		var env = Backdrop.new()
		env.z_index = -10
		view.add_child(env)
		view.move_child(env, 0)
		env.build(float(sim.L), view.ground_y, view.biome, float(sim.player_base.x), float(sim.enemy_base.x), index)
		view.environment = env
		for k in 2:
			var fx: float = minf(sim.L * (0.25 + 0.3 * k), sim.L * float(sim.hero_def.leash) - 60.0)
			sim.hero.x = fx
			for off in [26.0, -22.0]:
				sim.gold = 999.0
				sim.card_cd["melee_basic"] = 0.0
				if sim.deploy("melee_basic") == "":
					var u = sim.players.back()
					u.x = fx + off
					u.hp_max *= 40.0
					u.hp = u.hp_max
			for off in [58.0, 84.0]:
				var e = sim._spawn_enemy("e_grunt")
				e.x = fx + off
				e.hp_max *= 40.0
				e.hp = e.hp_max
			await frames(80)
			for attempt in 5:
				if not sim.paused: break
				root.get_node("Events").cmd_set_paused.emit(false)
				await frames(40)
			var path := "%s/r%02d_%d_%dx%d.png" % [out_dir, index, k, size.x, size.y]
			root.get_texture().get_image().save_png(path)
			print("[late] ", path)
		app.show_screen(&"menu")
		await frames(4)
	quit(0)
