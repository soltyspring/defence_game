extends SceneTree
## Real game frames of every round with the current art (--mode=before) or the release-slice art (--mode=after).
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_rounds.gd -- --out=<abs dir> --mode=after
##   --rounds=1-40 | 1,5,10   --views=front,home,nest
## front = a small fight where the land turns (rounds.json `front`), home = the keep at round start, nest = the hero
## at the end of its leash in front of the enemy base. Isolated save, dev-forced rounds: the player's save is not written.
const Adapter = preload("res://src/art_preview/slice_adapter.gd")
var out_dir := "user://art_preview/out"
var mode := "after"
var rounds: Array = []
var views: Array = ["front"]
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame

func _run() -> void:
	var spec := "1-40"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		if a.begins_with("--mode="): mode = a.get_slice("=", 1)
		if a.begins_with("--rounds="): spec = a.get_slice("=", 1)
		if a.begins_with("--views="): views = Array(a.get_slice("=", 1).split(","))
	for part in spec.split(","):
		if part.contains("-"):
			for n in range(int(part.get_slice("-", 0)), int(part.get_slice("-", 1)) + 1): rounds.append(n)
		else:
			rounds.append(int(part))
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
	var table = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/release_slice/rounds.json"))
	var size: Vector2i = DisplayServer.window_get_size()
	for n in rounds:
		var rid := "r%02d" % n
		if mode == "after": Adapter.apply_ui(atlas)
		app.start_round(rid, true)
		await frames(6)
		if mode == "after" and not Adapter.apply(app, atlas, true):
			printerr("[rounds] adapter failed ", rid)
		var sim = app.battle.sim
		sim.spawn_queue.clear()
		sim.trickle_next = -1.0
		sim.time_limit = 0.0
		sim.enemy_tower_mult = 0.0
		sim.hero.hp_max *= 40.0
		sim.hero.hp = sim.hero.hp_max
		var front: float = float(table.rounds[str(n)].front) if table is Dictionary and table.rounds.has(str(n)) else 0.5
		for view in views:
			match str(view):
				"front":
					var fx: float = minf(sim.L * front, sim.L * float(sim.hero_def.leash) - 60.0)
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
				"army":
					# every regular unit on one screen: the five ally cards and the five common enemies
					var ax: float = sim.L * 0.45
					sim.hero.x = ax - 70.0
					var i := 0
					for cid in ["worker", "melee_basic", "ranged_basic", "tank", "fast", "siege"]:
						sim.gold = 999.0
						sim.card_cd[cid] = 0.0
						if sim.deploy(cid) == "":
							var u = sim.players.back()
							u.x = ax - 60.0 + i * 16.0
							u.hp_max *= 40.0
							u.hp = u.hp_max
						i += 1
					i = 0
					for eid in ["e_grunt", "e_spitter", "e_swarm", "e_brute", "e_bomber"]:
						var e = sim._spawn_enemy(eid)
						e.x = ax + 70.0 + i * 22.0
						e.hp_max *= 40.0
						e.hp = e.hp_max
						i += 1
				"boss":
					# the round's boss(es) close to the hero, mid swing: shape and wind-up at battle size
					var bx: float = sim.L * 0.45
					sim.hero.x = bx - 40.0
					var bosses := {5: ["boss_warlord"], 10: ["boss_overlord", "boss_warlord"], 15: ["boss_millward"], 20: ["boss_rootking"],
						25: ["boss_frostguard"], 30: ["boss_ovenheart"]}
					var k := 0
					for bid in bosses.get(n, []):
						var e = sim._spawn_enemy(bid)
						e.x = bx + 30.0 + k * 70.0
						e.hp_max *= 40.0
						e.hp = e.hp_max
						k += 1
					for off in [-10.0, 6.0]:
						sim.gold = 999.0
						sim.card_cd["melee_basic"] = 0.0
						if sim.deploy("melee_basic") == "":
							var u = sim.players.back()
							u.x = bx + off
							u.hp_max *= 40.0
							u.hp = u.hp_max
				"challenge":
					# every challenge enemy in a row (and the nest core in r40), facing the hero
					var qx: float = sim.L * 0.42
					sim.hero.x = qx - 50.0
					var k := 0
					var list := ["e_thrall", "e_binder", "e_frostshell", "e_icerunner", "e_sporesac", "e_burrower"]
					if n == 40: list = ["boss_nestcore", "e_binder", "e_thrall"]
					for eid in list:
						var e = sim._spawn_enemy(eid)
						e.x = qx + 10.0 + k * (34.0 if n != 40 else 60.0)
						e.hp_max *= 40.0
						e.hp = e.hp_max
						k += 1
				"home":
					sim.hero.x = sim.player_base.x + 90.0
				"nest":
					sim.hero_def = sim.hero_def.duplicate()      # capture only: let the hero walk up to the enemy base
					sim.hero_def.leash = 1.0
					sim.hero.x = sim.enemy_base.x - 120.0
			await frames(80)
			for attempt in 5:
				if not sim.paused: break
				root.get_node("Events").cmd_set_paused.emit(false)
				await frames(40)
			if sim.paused: printerr("[rounds] still paused at ", rid, " ", view)
			var path := "%s/%s_%s_%s_%dx%d.png" % [out_dir, rid, view, mode, size.x, size.y]
			root.get_texture().get_image().save_png(path)
			print("[rounds] ", path)
		if mode == "after":
			Adapter.restore(atlas)
			Adapter.restore_ui(atlas)
		app.show_screen(&"menu")
		await frames(4)
	quit(0)
