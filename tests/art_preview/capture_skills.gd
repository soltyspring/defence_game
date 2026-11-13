extends SceneTree
## The four new energy skills in a real battle (R41 with a chosen skill set): each is cast into a staged fight, its
## rule is checked (CHECK lines) and the moment is captured. Plus the 스킬 tab of the 출전 준비 screen.
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_skills.gd -- --out=<abs dir>
## Isolated save; the player's save is not written.
var out_dir := "user://art_preview/skills"
var size := Vector2i.ZERO
var failures := 0

func _initialize() -> void: _run.call_deferred()

func frames(n := 4) -> void:
	for i in n: await process_frame

func shot(name: String) -> void:
	var path := "%s/%s_%dx%d.png" % [out_dir, name, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	print("[skills] ", path)

func check(ok: bool, what: String) -> void:
	print("CHECK ", "ok " if ok else "FAIL ", what)
	if not ok: failures += 1

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
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	size = DisplayServer.window_get_size()
	# the 스킬 tab of 출전 준비
	var roster_script: GDScript = load("res://src/ui/roster.gd")
	roster_script.pending_round = "r41"
	app.show_screen(&"roster")
	await frames(4)
	var screen = null
	for n in root.find_children("*", "", true, false):
		if n.get_script() == roster_script and n.is_inside_tree(): screen = n
	screen._set_tab("skills")
	for i in 3: screen._take_out_skill(0)
	for id in ["skill_shield", "skill_frost", "skill_oven"]: screen._toggle_skill(id)
	await frames(6)
	shot("0_skill_tab")
	check(screen.skill_sel == ["skill_shield", "skill_frost", "skill_oven"], "skill tab picks three")
	screen._toggle_skill("skill_flour")
	check(screen.skill_sel.size() == 3 and not screen.skill_sel.has("skill_flour"), "fourth skill refused")
	screen._save()
	await frames(30)
	var sim = app.battle.sim
	check(sim.skill_ids == ["skill_shield", "skill_frost", "skill_oven"], "battle uses the chosen skills " + str(sim.skill_ids))
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	sim.time_limit = 0.0
	sim.enemy_tower_mult = 0.0
	sim.hero.hp_max *= 40.0
	sim.hero.hp = sim.hero.hp_max
	var x0: float = sim.L * 0.3
	sim.hero.x = x0
	for off in [-20.0, -8.0]:
		sim.gold = 999.0
		sim.card_cd["melee_basic"] = 0.0
		if sim.deploy("melee_basic") == "":
			var u = sim.players.back()
			u.x = x0 + off
	var foes: Array = []
	for i in 4:
		var e = sim._spawn_enemy("e_grunt")
		e.x = x0 + 50.0 + i * 14.0
		e.hp_max *= 40.0
		e.hp = e.hp_max
		foes.append(e)
	await frames(10)
	# shield
	sim.mana = 999.0
	check(sim.cast("skill_shield") == "", "shield casts")
	var guarded = sim.players[0]
	check(guarded.shield > 0.0, "ally gets a shield (%.0f)" % guarded.shield)
	var hp_before: float = guarded.hp
	sim._damage(guarded, guarded.shield * 0.5, 0.0)
	check(is_equal_approx(guarded.hp, hp_before), "shield absorbs damage before HP")
	await frames(8)
	shot("1_shield")
	# frost
	sim.mana = 999.0
	check(sim.cast("skill_frost") == "", "frost casts")
	check(foes[0].buff_mul < 0.6 and foes[0].buff_t > 3.0, "front enemy slowed (x%.2f for %.1fs)" % [foes[0].buff_mul, foes[0].buff_t])
	await frames(12)
	shot("2_frost")
	# oven
	await frames(30)
	sim.mana = 999.0
	var hp0: float = foes[1].hp
	check(sim.cast("skill_oven") == "", "oven casts")
	await frames(20)
	shot("3_oven")
	await frames(200)
	check(foes[1].hp < hp0 - 80.0, "oven burns several times (%.0f damage)" % (hp0 - foes[1].hp))
	# flour drop (cast directly: it is not in this set)
	sim.skill_cd["skill_flour"] = 0.0
	sim.gold = 10.0
	sim.mana = 999.0
	check(sim.cast("skill_flour") == "" and sim.gold >= 90.0, "flour drop gives flour (%.0f)" % sim.gold)
	await frames(10)
	shot("4_flour")
	print("[skills] failures=", failures)
	quit(0 if failures == 0 else 1)
