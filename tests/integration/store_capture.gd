extends SceneTree
## Store screenshot capture on the REAL engine (06 a143134, 09 SUCCESS_ANALYSIS §32.1). Owner: 04-client.
## Visible runs only, on the secondary monitor:
##   tools/build/visible_launch.ps1 -ProjectPath <HEAD snapshot> -Script res://tests/integration/store_capture.gd
##       -Resolution 1280x720 -UserArgs '--out=<abs dir>','--locale=ko'
## The script switches its own window to borderless fullscreen on the screen it was opened on (the launcher
## puts it on DISPLAY2, 1920x1080), so the viewport is exactly 1920x1080 = the 640x360 view at integer x3.
## Each frame is saved as a 24-bit RGB PNG (alpha dropped): store_<nn>_<scene>_<locale>.png.
## Viewport capture only: no PC window frame, no window title. No pause screen, no shop (Q2 보류),
## no test-injected toasts; tutorials are marked done in the isolated save so no hint strips are shown.
## Scenes follow 09's order: 1 lane battle with both base HP numbers, 2 hero move + first skill,
## 3 economy (baker vs soldier cards, "밀가루"), 4 roster, 5 boss, 6 result stars.
## Staging uses the real commands/sim (deploy, hero dir, skill cast, sim steps, base damage for the win).
## Exit 0 = all frames saved and none looked black; 2 = window could not reach 1920x1080; 1 = other failure.

var TEST_SAVE := "user://store_capture_save_%d.json" % OS.get_process_id()
var out_dir := ""
var locale := "ko"
var app: Node
var events: Node
var save: Node
var saved: Array = []
var problems: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 2) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	root.push_input(e, true)

func _hud() -> Control:
	for c in app.ui_layer.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path == "res://src/ui/hud.gd" and not c.is_queued_for_deletion():
			return c
	return null

## Wait until no toast or banner is mid-fade (real ones are allowed, but not half-transparent in a store image).
func _quiet_hud(max_s := 3.0) -> void:
	var hud := _hud()
	var w := 0.0
	while hud != null and w < max_s and (hud.toast_label.modulate.a > 0.01 or (hud.banner_label.modulate.a > 0.01 and hud.banner_label.modulate.a < 0.99)):
		await _seconds(0.1)
		w += 0.1

func shot(n: int, scene: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img.get_size() != Vector2i(1920, 1080):
		problems.append("%s: frame %s, not 1920x1080" % [scene, img.get_size()])
	img.convert(Image.FORMAT_RGB8)
	# black-frame guard (locked PC / no presentation): sample every 16th pixel
	var dark := 0
	var total := 0
	for y in range(0, img.get_height(), 16):
		for x in range(0, img.get_width(), 16):
			total += 1
			if img.get_pixel(x, y).get_luminance() < 0.02:
				dark += 1
	var p := out_dir.path_join("store_%02d_%s_%s.png" % [n, scene, locale])
	var err := img.save_png(p)
	var dark_pct := 100.0 * dark / maxf(1.0, float(total))
	if dark_pct > 90.0:
		problems.append("%s: %.0f%% black samples (INVALID_BLACK: PC locked or not presented?)" % [scene, dark_pct])
	var bt := -1.0
	if is_instance_valid(app.battle) and app.battle.sim != null:
		bt = float(app.battle.sim.t)
	saved.append({"n": n, "scene": scene, "path": p, "err": err, "dark_pct": dark_pct, "t": bt})
	print("[store] %s err=%d %dx%d view=%s dark=%.1f%% round=%s t=%.1f" % [p, err, img.get_width(), img.get_height(), root.get_visible_rect().size, dark_pct, app.current_round, bt])

func _start(round_id: String) -> Object:
	app.start_round(round_id, true)
	await _frames(4)
	return app.battle.sim

## Step the REAL sim fast (0.5 s per frame) until cond(sim) or max_t; returns true if cond met.
func _ff(sim: Object, cond: Callable, max_t: float) -> bool:
	while not cond.call(sim) and sim.t < max_t and not sim.ended:
		if sim.paused:
			app.battle.set_paused(false)   # focus loss pauses the battle (7ed4a5f)
		for k in 30:
			sim.step(1.0 / 60.0)
		await process_frame
	return cond.call(sim)

## Fast-forward like _ff, but walk the hero (real dir command) so it stays `lead` px behind the army's front;
## the camera follows the hero, so the army stays in view. Then let the camera settle in real time.
func _ff_follow(sim: Object, cond: Callable, max_t: float, lead: float) -> bool:
	while not cond.call(sim) and sim.t < max_t and not sim.ended:
		if sim.paused:
			app.battle.set_paused(false)
		for k in 30:
			if sim.hero != null:
				var want := _front_x(sim) - lead
				sim.set_hero_dir(1 if sim.hero.x < want - 6.0 else (-1 if sim.hero.x > want + 30.0 else 0))
			sim.step(1.0 / 60.0)
		await process_frame
	sim.set_hero_dir(0)
	await _seconds(1.0)
	return cond.call(sim)

func _deploy(sim: Object, ids: Array, gap_s := 1.2) -> void:
	for id in ids:
		sim.gold = maxf(sim.gold, 400.0)
		sim.card_cd[id] = 0.0
		events.cmd_deploy_unit.emit(id)
		for k in int(gap_s * 60.0):
			sim.step(1.0 / 60.0)
		await process_frame

static func _front_contact(sim: Object) -> bool:
	for e in sim.enemies:
		if not e.alive or e.dying:
			continue
		for p in sim.players:
			if p.alive and not p.dying and not p.is_hero and absf(e.x - p.x) < 40.0:
				return true
	return false

static func _front_x(sim: Object) -> float:
	var fx := 0.0
	for p in sim.players:
		if p.alive and not p.is_hero:
			fx = maxf(fx, p.x)
	return fx

## Midpoint of the closest live ally/enemy pair (the fight), or -1.
static func _contact_x(sim: Object) -> float:
	var best := 1e9
	var cx := -1.0
	for e in sim.enemies:
		if not e.alive or e.dying:
			continue
		for p in sim.players:
			if p.alive and not p.dying and not p.is_hero and absf(e.x - p.x) < best:
				best = absf(e.x - p.x)
				cx = (e.x + p.x) * 0.5
	return cx

static func _near(sim: Object, u: Object, d: float) -> bool:
	if u == null or not u.alive:
		return false
	for p in sim.players:
		if p.alive and not p.dying and not p.is_hero and absf(u.x - p.x) < d:
			return true
	return false

## Walk the hero (real dir command) to x, then let the camera settle in real time.
func _hero_to(sim: Object, x: float) -> void:
	var guard := 0
	while sim.hero != null and absf(sim.hero.x - x) > 12.0 and guard < 600:
		sim.set_hero_dir(1 if sim.hero.x < x else -1)
		for k in 6:
			sim.step(1.0 / 60.0)
		guard += 1
		await process_frame
	sim.set_hero_dir(0)
	await _seconds(1.2)

func _run() -> void:
	app = root.get_node_or_null("App")
	events = root.get_node_or_null("Events")
	save = root.get_node_or_null("Save")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--locale="):
			locale = a.get_slice("=", 1)
	if app == null or events == null or save == null or out_dir == "" or DisplayServer.get_name() == "headless":
		printerr("[store] needs a visible run with autoloads and --out=<abs dir>")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	save.path = TEST_SAVE
	for f in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	save.load_progress()
	var content: Node = root.get_node_or_null("Content")
	var tut: Array = []
	for rid in content.round_order:
		for k in content.get_round(str(rid)).get("tutorial", []):
			tut.append(str(k))
	save.progress["tutorial_done"] = tut
	load("res://src/ui/ui_text.gd").load_locale(locale)
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	# 1920x1080 on the launcher's screen (DISPLAY2) → integer x3 of 640x360. Godot's multi-window fullscreen
	# may differ by a pixel on Windows; then exclusive fullscreen (same screen, same video mode) is tried.
	var ws := Vector2i.ZERO
	for mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(mode)
		await _seconds(1.5)
		ws = DisplayServer.window_get_size()
		print("[store] mode=%d window=%s screen=%d view=%s pixel_scale=%s" % [mode, ws, DisplayServer.window_get_current_screen(), root.get_visible_rect().size, app.get("pixel_scale")])
		if ws == Vector2i(1920, 1080) and root.get_visible_rect().size == Vector2(640, 360):
			break
	if ws != Vector2i(1920, 1080) or root.get_visible_rect().size != Vector2(640, 360):
		printerr("[store] window %s / view %s is not 1920x1080 / 640x360: no capture" % [ws, root.get_visible_rect().size])
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		quit(2); return

	# 1) lane battle: r03, a mixed army meets the first wave; camera on the contact point; both base HP numbers
	var sim: Object = await _start("r03")
	await _deploy(sim, ["melee_basic", "tank", "ranged_basic", "melee_basic"])
	await _ff(sim, _front_contact, 120.0)
	await _deploy(sim, ["melee_basic", "ranged_basic", "tank"], 0.8)
	await _hero_to(sim, maxf(200.0, _contact_x(sim) - 120.0))
	sim.gold = 0.42 * float(sim.gold_max)
	await _seconds(0.3)
	await _quiet_hud()
	await shot(1, "battle")
	# 2) hero control + first skill: hero next to the fight, hold ▶ and cast skill_slam via the real HUD buttons
	var hud := _hud()
	await _hero_to(sim, maxf(200.0, _contact_x(sim) - 50.0))
	sim.mana = sim.mana_max
	if hud != null and not hud.skill_buttons.is_empty():
		var rp: Vector2 = hud.btn_right.get_global_rect().get_center()
		var sp: Vector2 = (hud.skill_buttons[0] as Control).get_global_rect().get_center()
		touch(1, rp, true)
		await _seconds(0.2)
		touch(3, sp, true)
		await _frames(2)
		touch(3, sp, false)
		await _seconds(0.3)        # cast_time 0.25 s, then the slam shockwave (0.5 s)
		await shot(2, "hero_skill")
		touch(1, rp, false)
	else:
		problems.append("hero_skill: no skill button in r03")
	# 3) economy: r03 early; baker (worker) button vs soldier cards, flour (밀가루) readout, a second baker
	sim = await _start("r03")
	for k in 600:
		sim.step(1.0 / 60.0)
	sim.gold = maxf(sim.gold, 160.0)
	events.cmd_buy_worker.emit()
	await _deploy(sim, ["melee_basic", "ranged_basic", "melee_basic"], 1.5)
	sim.gold = 185.0
	await _seconds(1.0)
	await _quiet_hud()
	await shot(3, "economy")
	# 4) roster: r06 has all five soldier types (cards); the mixed column marches up the lane with the hero
	sim = await _start("r06")
	await _deploy(sim, ["tank", "melee_basic", "fast", "ranged_basic", "siege", "melee_basic", "ranged_basic", "fast"], 0.9)
	await _ff_follow(sim, func(s): return _front_x(s) >= 560.0 or _front_contact(s), 150.0, 150.0)
	sim.gold = 0.55 * float(sim.gold_max)
	await _seconds(0.3)
	await _quiet_hud()
	await shot(4, "roster")
	# 5) boss: r05; the mould general walks into the army; boss HP bar + name in the HUD
	sim = await _start("r05")
	await _deploy(sim, ["tank", "melee_basic", "ranged_basic", "melee_basic", "fast", "ranged_basic", "tank"], 0.9)
	var boss = sim._spawn_enemy("boss_warlord")
	await _ff_follow(sim, func(s): return _near(s, boss, 70.0), 200.0, 120.0)
	sim.gold = 0.38 * float(sim.gold_max)
	await _seconds(0.3)
	await _quiet_hud()
	await shot(5, "boss")
	# 6) result: r03 won with the base intact and some kills → 3 stars (base kill through the sim's own damage path)
	sim = await _start("r03")
	await _deploy(sim, ["melee_basic", "tank", "ranged_basic", "melee_basic", "ranged_basic"])
	await _ff(sim, func(s): return s.kills >= 4, 90.0)
	sim._damage_base(sim.SIDE_ENEMY, float(sim.enemy_base.hp) + 1.0)
	var waited := 0.0
	while waited < 6.0:
		await _seconds(0.1)
		waited += 0.1
		var found := false
		for c in app.ui_layer.get_children():
			if c.get_script() and c.get_script().resource_path == "res://src/ui/result.gd":
				found = true
		if found:
			break
	await _seconds(1.2)   # star pop-in
	await shot(6, "result")

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var f := FileAccess.open(out_dir.path_join("store_capture_%s.json" % locale), FileAccess.WRITE)
	f.store_string(JSON.stringify({"locale": locale, "frames": saved, "problems": problems}, "  "))
	f.close()
	for pr in problems:
		printerr("[store] PROBLEM " + str(pr))
	print("[store] saved=%d problems=%d" % [saved.size(), problems.size()])
	for fpath in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(fpath):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fpath))
	quit(0 if problems.is_empty() and saved.size() == 6 else 1)
