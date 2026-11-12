extends SceneTree
## Real game frames of the R01 battle with the current art (--mode=before) or the release slice (--mode=after).
## Same round, staging, camera and resolution in both modes. Needs a renderer:
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_slice.gd -- --out=<abs dir> --mode=after
##   --shots=home,mid,nest,crowd,melee,damaged_home,damaged_nest,ruined_nest   --frames=0 (N > 0: also save N
##   consecutive frames of the `melee` shot, 6 game frames apart, as engine-output animation evidence)
## Isolated save (user://art_preview/), dev-forced round: nothing is written to the player's save.
const Adapter = preload("res://src/art_preview/slice_adapter.gd")
var out_dir := "user://art_preview/out"
var mode := "after"
var shots: Array = ["home", "mid", "nest", "crowd", "melee", "damaged_home", "damaged_nest", "ruined_nest"]
var strip := 0
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame

func _army(sim, hx: float, list: Array) -> void:
	for a in list:
		sim.gold = 999.0
		sim.card_cd[a[0]] = 0.0
		if sim.deploy(a[0]) == "":
			var u = sim.players.back()
			u.x = hx + float(a[1])
			u.hp_max *= 40.0
			u.hp = u.hp_max
	sim.gold = 63.0

func _foes(sim, hx: float, list: Array) -> void:
	for f in list:
		var e = sim._spawn_enemy(str(f[0]))
		e.x = hx + float(f[1])
		e.hp_max *= 40.0
		e.hp = e.hp_max

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		if a.begins_with("--mode="): mode = a.get_slice("=", 1)
		if a.begins_with("--shots="): shots = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--frames="): strip = int(a.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	var atlas = root.get_node("Atlas")
	DirAccess.make_dir_recursive_absolute("user://art_preview")
	save.path = "user://art_preview/save.json"
	save.progress = save.fresh()
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	var size: Vector2i = DisplayServer.window_get_size()
	for shot in shots:
		app.start_round("r01", true)
		await frames(6)
		if mode == "after":
			var ok: bool = Adapter.apply(app, atlas)
			if not ok: printerr("[slice] adapter failed")
		var sim = app.battle.sim
		sim.spawn_queue.clear()
		sim.trickle_next = -1.0
		sim.time_limit = 0.0
		var mid: float = sim.L * 0.5
		match str(shot):
			"home":
				sim.workers = 3
			"mid":
				sim.hero.x = mid
				_army(sim, mid, [["melee_basic", 30.0], ["melee_basic", -24.0]])
				_foes(sim, mid, [["e_grunt", 66.0], ["e_grunt", 96.0]])
			"nest":
				sim.hero.x = sim.L * float(sim.hero_def.leash) - 30.0
				_army(sim, sim.hero.x, [["melee_basic", 24.0], ["melee_basic", -26.0]])
			"crowd":
				sim.hero.x = mid - 40.0
				_army(sim, mid, [["melee_basic", 0.0], ["melee_basic", 3.0], ["melee_basic", 6.0], ["melee_basic", 9.0], ["melee_basic", 12.0], ["melee_basic", 15.0], ["melee_basic", 18.0], ["melee_basic", 21.0]])
				_foes(sim, mid, [["e_grunt", 110.0]])
			"melee":
				sim.hero.x = mid
				_army(sim, mid, [["melee_basic", 22.0], ["melee_basic", 30.0], ["melee_basic", 12.0], ["melee_basic", -20.0]])
				_foes(sim, mid, [["e_grunt", 44.0], ["e_grunt", 52.0], ["e_grunt", 60.0], ["e_grunt", 74.0], ["e_grunt", 90.0]])
			"damaged_home":
				sim.player_base.hp = sim.player_base.hp_max * 0.4
			"damaged_nest", "ruined_nest":
				sim.hero.x = sim.L * float(sim.hero_def.leash) - 30.0
				sim.enemy_base.hp = sim.enemy_base.hp_max * (0.4 if shot == "damaged_nest" else 0.001)
				sim.enemy_tower_mult = 0.0
		await frames(70)
		var path := "%s/r01_%s_%s_%dx%d.png" % [out_dir, shot, mode, size.x, size.y]
		root.get_texture().get_image().save_png(path)
		print("[slice] ", path)
		if strip > 0 and str(shot) == "melee":
			for i in strip:
				await frames(6)
				root.get_texture().get_image().save_png("%s/r01_melee_%s_strip%02d_%dx%d.png" % [out_dir, mode, i, size.x, size.y])
		if mode == "after": Adapter.restore(atlas)
		app.show_screen(&"menu")
		await frames(4)
	quit(0)
