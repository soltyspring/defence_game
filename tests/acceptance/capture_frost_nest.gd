extends SceneTree
## Staged 1x game frames for the frost / nest enemies, at 640x360 and 1280x720 (docs/design/FROST_NEST_ENEMIES.md).
## Needs a real renderer (Windows, or Linux under Xvfb):
##   godot --path . --resolution 1280x720 -s tests/acceptance/capture_frost_nest.gd -- --out=<abs dir> --set=after|before
## `before` stages the same armies against the enemies those rounds used before 2026-11-11 (works on older trees).
## Uses an isolated save (user://capture-frost/); dev-forced rounds, nothing is written to the player's save.
var out_dir := "user://capture-frost/out"
var set_name := "after"
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame

const ARMY := [["tank", 52.0], ["melee_basic", 36.0], ["melee_basic", 44.0], ["ranged_basic", -22.0], ["ranged_basic", -36.0], ["siege", -72.0]]
## scene -> round, enemies as [unit, dx from the hero, state]; state: "" | "windup" | "open" | "lobbed" | "under"
const AFTER := {
	"r21_shell": ["r21", [["e_frostshell", 74.0, ""], ["e_frostshell", 104.0, "open"], ["e_frostshell", 140.0, "windup"]]],
	"r22_charge": ["r22", [["e_icerunner", 150.0, "windup"], ["e_icerunner", 205.0, ""]]],
	"r25_boss_charge": ["r25", [["boss_frostguard", 120.0, "windup"], ["e_frostshell", 170.0, ""], ["e_icerunner", 215.0, ""]]],
	"r25_boss_open": ["r25", [["boss_frostguard", 84.0, "open"], ["e_frostshell", 132.0, "open"], ["e_icerunner", 180.0, ""]]],
	"r37_sac": ["r37", [["e_thrall", 74.0, "windup"], ["e_sporesac", 150.0, "lobbed"], ["e_binder", 190.0, ""]]],
	"r37_overlap": ["r37", [["e_thrall", 74.0, ""], ["e_sporesac", 150.0, ""], ["e_binder", 190.0, ""]]],
	"r38_burrow": ["r38", [["e_thrall", 70.0, ""], ["e_binder", 118.0, ""], ["e_burrower", 150.0, "under"]]],
}
const BEFORE := {
	"r21_shell": ["r21", [["e_runner", 74.0, ""], ["e_runner", 104.0, ""], ["e_spitter", 140.0, ""]]],
	"r22_charge": ["r22", [["e_guard", 150.0, ""], ["e_mortar", 205.0, ""]]],
	"r25_boss_charge": ["r25", [["boss_frostguard", 120.0, ""], ["e_runner", 170.0, ""], ["e_runner", 215.0, ""]]],
	"r25_boss_open": ["r25", [["boss_frostguard", 84.0, ""], ["e_runner", 132.0, ""], ["e_spitter", 180.0, ""]]],
	"r37_sac": ["r37", [["e_thrall", 70.0, "windup"], ["e_binder", 118.0, ""], ["e_mortar", 150.0, ""]]],
	"r38_burrow": ["r38", [["e_thrall", 70.0, ""], ["e_binder", 118.0, ""], ["e_thrall", 150.0, ""]]],
}

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		if a.begins_with("--set="): set_name = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	DirAccess.make_dir_recursive_absolute("user://capture-frost")
	save.path = "user://capture-frost/save.json"
	save.progress = save.fresh()
	save.progress.settings.show_damage = true
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	var scenes: Dictionary = AFTER if set_name == "after" else BEFORE
	# One window size per run: pass the engine option --resolution WxH (640x360 and 1280x720 are the two required).
	for size in [DisplayServer.window_get_size()]:
		for name in scenes:
			await _stage(app, str(scenes[name][0]), scenes[name][1])
			if name == "r37_overlap":
				_stage_overlapping_tells(app.battle.sim)
			await frames(3)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var path := "%s/%s_%s_%dx%d.png" % [out_dir, name, set_name, size.x, size.y]
			if img.save_png(path) != OK:
				push_error("Could not write " + path)
				quit(1)
				return
			print("[capture] ", path, " ", img.get_size(), " view=", root.get_visible_rect().size)
			if name in ["r25_boss_charge", "r37_overlap", "r38_burrow"]:
				await _sample_render(name, app.battle.sim)
	app.show_screen(&"menu")
	await frames(4)
	app.quit_game(0)

## A controlled renderer case; natural wave play is covered by the simulation tests.
func _stage_overlapping_tells(sim) -> void:
	var center: float = sim.hero.x + 70.0
	sim._fx("telegraph", center, 0.0, 5.0, 48.0, 0, "slam")
	sim._fx("telegraph", center + 14.0, 0.0, 5.0, 43.0, 0, "lob")
	sim._fx("telegraph", center + 40.0, 0.0, 5.0, 31.0, 0, "charge")
	sim._fx("telegraph", center + 25.0, 0.0, 5.0, 59.0, 0, "burrow")
	for f in sim.fxs:
		if f.alive and f.kind == "telegraph":
			f.t = f.dur * 0.45

func _sample_render(label: String, sim) -> void:
	# Keep the same frame composition throughout the sample (software-render proxy).
	sim.paused = true
	await frames(12)
	var calls: Array[int] = []
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 90:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		last = now
	sim.paused = false
	times.sort()
	calls.sort()
	print("[render-sample] %s calls_median=%d frame_ms_p95=%.2f n=%d" % [label, calls[45], times[85], times.size()])

func _stage(app, round_id: String, foes: Array) -> void:
	app.start_round(round_id, true)
	await frames(6)
	var sim = app.battle.sim
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	sim.time_limit = 0.0
	var hx := 520.0
	sim.hero.x = hx
	sim.gold = 470.0
	sim.mana = 60.0
	for a in ARMY:
		var g: float = sim.gold
		sim.gold = 999.0
		sim.card_cd[a[0]] = 0.0
		if sim.deploy(a[0]) == "":
			sim.players.back().x = hx + float(a[1])
			sim.players.back().hp_max *= 40.0      # the staged state must outlast the walk-in
			sim.players.back().hp = sim.players.back().hp_max
		sim.card_cd[a[0]] = 0.0
		sim.gold = g
	var staged := []
	for f in foes:
		if not sim.content.units.has(str(f[0])): continue
		var e = sim._spawn_enemy(str(f[0]))
		e.x = hx + float(f[1])
		e.hp_max *= 40.0
		e.hp = e.hp_max
		if "heavy_cd" in e: e.heavy_cd = 99.0
		staged.append([e, str(f[2])])
	sim.hero.hp_max *= 40.0
	sim.hero.hp = sim.hero.hp_max
	await frames(50)          # formation settles, walk-in poses
	# phase 1: states with their own timing (a lobbed zone on the ground, a burrower announcing its exit)
	var slow := false
	for s in staged:
		var e = s[0]
		if s[1] == "open":
			e.recover_t = 9.0
			e.exposed_t = 9.0
			e.exposed_mul = 1.6
		elif s[1] == "lobbed" or s[1] == "under":
			e.heavy_cd = 0.0
			slow = true
	if slow:
		for i in 900:
			await process_frame
			var ok := true
			for s in staged:
				var e = s[0]
				if s[1] == "lobbed" and sim.delayed.is_empty(): ok = false
				if s[1] == "under" and not (e.hidden and e.heavy_t >= 0.0 and e.heavy_t < 0.9): ok = false
			if ok: break
	# phase 2: wind-ups, shot at about half of the announcement
	var winding := false
	for s in staged:
		if s[1] == "windup":
			s[0].heavy_cd = 0.0
			winding = true
	if winding:
		for i in 400:
			await process_frame
			var ok2 := true
			for s in staged:
				var e = s[0]
				if s[1] != "windup": continue
				var spec: Dictionary = e.ab if "ab" in e else e.def.heavy      # older trees have no Unit.ab
				if not (e.heavy_t >= 0.0 and e.heavy_t <= float(spec.get("windup", 1.2)) * 0.6): ok2 = false
			if ok2: break
