extends SceneTree
## 1x game frames of the hero-down state during a crowded boss fight (r25), for before/after pairs.
##   godot --path . --resolution 640x360 -s tests/acceptance/capture_revive.gd -- --out=<abs dir> --tag=after
## Isolated save (user://capture-revive/); forced dev start, nothing is written to the player's save.
var out_dir := "user://capture-revive/out"
var tag := "after"
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame
func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		if a.begins_with("--tag="): tag = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	DirAccess.make_dir_recursive_absolute("user://capture-revive")
	save.path = "user://capture-revive/save.json"
	save.progress = save.fresh()
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	app.start_round("r25", true)
	await frames(6)
	var sim = app.battle.sim
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	sim.time_limit = 0.0
	sim.hero.x = 520.0
	for a in [["tank", 52.0], ["tank", 60.0], ["melee_basic", 36.0], ["melee_basic", 44.0], ["melee_basic", 30.0], ["fast", 40.0], ["ranged_basic", -22.0], ["ranged_basic", -36.0], ["ranged_basic", -30.0], ["siege", -72.0]]:
		sim.gold = 999.0
		sim.card_cd[a[0]] = 0.0
		if sim.deploy(a[0]) == "":
			sim.players.back().x = 520.0 + float(a[1])
			sim.players.back().hp_max *= 40.0
			sim.players.back().hp = sim.players.back().hp_max
		sim.card_cd[a[0]] = 0.0
	sim.gold = 310.0
	for f in [["boss_frostguard", 96.0], ["e_grunt", 130.0], ["e_grunt", 150.0], ["e_swarm", 120.0], ["e_swarm", 140.0], ["e_guard", 170.0], ["e_guard", 190.0], ["e_spitter", 230.0], ["e_spitter", 250.0]]:
		var e = sim._spawn_enemy(str(f[0]))
		e.x = 520.0 + float(f[1])
		e.hp_max *= 40.0
		e.hp = e.hp_max
	await frames(70)
	sim.hero.invuln = 0.0
	sim._damage(sim.hero, 1e9, 0.0)
	await frames(45)
	var size: Vector2i = DisplayServer.window_get_size()
	var img: Image = root.get_texture().get_image()
	var path := "%s/hero_down_boss_%s_%dx%d.png" % [out_dir, tag, size.x, size.y]
	img.save_png(path)
	print("[capture] ", path, " respawn=", snappedf(sim.hero_respawn, 0.1))
	app.show_screen(&"menu")
	await frames(4)
	quit(0)
