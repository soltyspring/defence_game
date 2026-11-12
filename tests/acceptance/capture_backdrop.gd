extends SceneTree
## 1x game frames of the lane backdrop per round, same staging for before/after pairs (docs/art/fable52/backdrop/).
## Needs a real renderer (Windows window on the secondary monitor, or Linux under Xvfb):
##   godot --path . --resolution 640x360 -s tests/acceptance/capture_backdrop.gd -- --out=<abs dir> --tag=after --rounds=r01,r05,r10
## Shots per round: start (round opening at the keep), fight (mid lane, staged armies, one announced attack),
## far (by the enemy base; boss rounds stage the boss, the hero is down so the revive read-out shows),
## exposed (boss rounds: the boss alone, 5 s exposure running; for the linkable core of r40).
## Isolated save (user://capture-backdrop/); dev-forced rounds, nothing is written to the player's save.
var out_dir := "user://capture-backdrop/out"
var tag := "after"
var rounds: Array = ["r01", "r05", "r10", "r11", "r15", "r20", "r21", "r25", "r30", "r31", "r35", "r40"]
var shots: Array = ["start", "fight", "far"]
const ARMY := [["tank", 40.0], ["melee_basic", 26.0], ["melee_basic", 34.0], ["ranged_basic", -22.0], ["ranged_basic", -36.0]]
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame
func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		if a.begins_with("--tag="): tag = a.get_slice("=", 1)
		if a.begins_with("--rounds="): rounds = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--shots="): shots = Array(a.get_slice("=", 1).split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	var c = root.get_node("Content")
	DirAccess.make_dir_recursive_absolute("user://capture-backdrop")
	save.path = "user://capture-backdrop/save.json"
	save.progress = save.fresh()
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	for id in rounds:
		for shot in shots:
			app.start_round(str(id), true)
			await frames(6)
			var sim = app.battle.sim
			sim.spawn_queue.clear()
			sim.trickle_next = -1.0
			sim.time_limit = 0.0
			var roster: Array = c.round_enemy_roster(sim.round_def)
			var boss_id := ""
			var foes: Array = []
			for uid in roster:
				if bool(c.get_unit(str(uid)).get("is_boss", false)): boss_id = str(uid)
				elif foes.size() < 3: foes.append(str(uid))
			if shot != "start":
				var hx: float = sim.L * 0.5 if shot == "fight" else sim.L * float(sim.hero_def.leash) - 40.0
				sim.hero.x = hx
				for a in ARMY:
					if not sim.card_ids.has(a[0]): continue
					sim.gold = 999.0
					sim.card_cd[a[0]] = 0.0
					if sim.deploy(a[0]) == "":
						sim.players.back().x = hx + float(a[1])
						sim.players.back().hp_max *= 40.0
						sim.players.back().hp = sim.players.back().hp_max
				sim.gold = 120.0
				var dx := 70.0
				if shot == "far" and boss_id != "":
					var b = sim._spawn_enemy(boss_id)
					b.x = hx + 96.0
					b.hp_max *= 40.0
					b.hp = b.hp_max * 0.6
					b.heavy_cd = 0.4
					dx = 150.0
				for i in foes.size():
					if shot == "exposed" and c.get_unit(foes[i]).has("link"): continue      # no knot: every strand is cut
					var e = sim._spawn_enemy(foes[i])
					e.x = hx + dx + 30.0 * i
					e.hp_max *= 40.0
					e.hp = e.hp_max
					if i == 0 and not e.ab.is_empty(): e.heavy_cd = 0.3
				await frames(80)
				if shot == "exposed":
					# the linkable boss with every strand cut: the backdrop shows the opening
					var core = sim._spawn_enemy(boss_id) if boss_id != "" else null
					if core != null:
						core.x = hx + 96.0
						core.hp_max *= 40.0
						core.hp = core.hp_max * 0.6
						core.sm = {}
						core.phase = 99          # no phase change: nothing is summoned during the shot
						core.heavy_cd = 99.0
						core.exposed_mul = 2.0
						core.exposed_t = 5.0
						await frames(100)
				if shot == "far":
					sim.hero.invuln = 0.0
					sim._damage(sim.hero, 1e9, 0.0)
					await frames(40)
			else:
				await frames(50)
			var size: Vector2i = DisplayServer.window_get_size()
			var img: Image = root.get_texture().get_image()
			var path := "%s/%s_%s_%s_%dx%d.png" % [out_dir, id, shot, tag, size.x, size.y]
			img.save_png(path)
			print("[capture] ", path)
			app.show_screen(&"menu")
			await frames(4)
	quit(0)
