extends SceneTree
## 04-client REAL-ENGINE UI integration test (no mocks). Exit code 0 = pass.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/integration/test_ui_integration.gd
## Boots 02's real scenes/gameplay/main.tscn + App router + BattleSim, drives the 04 UI only through
## simulated touches (Viewport.push_input), and asserts:
##   - every screen was mounted from scenes/ui (App.ui_source), never the 02 fallback UI,
##   - the mounted root scripts are the 04 scripts (exact resource paths),
##   - HUD receives real HudSnapshots, card tap really deploys, hero hold really moves the hero,
##     pause really pauses the sim, base destruction leads to the 04 result screen, retry restarts.
## Uses an isolated save file (user://test_ui_integration_save.json) so player progress is untouched.

const EXPECT := {
	&"menu": "res://src/ui/main_menu.gd",
	&"round_select": "res://src/ui/round_select.gd",
	&"hud": "res://src/ui/hud.gd",
	&"result": "res://src/ui/result.gd",
}
const TEST_SAVE := "user://test_ui_integration_save.json"

var failures := PackedStringArray()
var passes := 0
var app: Node
var events: Node
var snaps: Array = []
var main: Node
var shot_dir := ""
var shot_tag := "real"
var tile := 0

## Saves the real rendered frame (only in a visible run with --shot-dir). Records UI root script.
func shot(label: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var p := shot_dir.path_join("%s_%s.png" % [shot_tag, label])
	img.save_png(p)
	var roots := []
	for c in app.ui_layer.get_children():
		roots.append(c.get_script().resource_path if c.get_script() else "?")
	print("[shot] %s %dx%d view=%s ui_roots=%s" % [p, img.get_width(), img.get_height(), root.get_visible_rect().size, roots])

func _initialize() -> void:
	_run.call_deferred()

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  ok   " + msg)
	else:
		failures.append(msg)
		printerr("FAIL: " + msg)

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

func tap(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	touch(0, p, true)
	touch(0, p, false)

func mounted(screen: StringName) -> Control:
	var layer: CanvasLayer = app.ui_layer
	if layer == null:
		return null
	for c in layer.get_children():
		if c.is_queued_for_deletion():
			continue
		var s: Script = c.get_script()
		if s != null and s.resource_path == EXPECT[screen]:
			return c
	return null

func assert_screen(screen: StringName) -> Control:
	var src := str(app.ui_source.get(screen, "<none>"))
	check(src == "scenes/ui", "%s mounted from scenes/ui (App.ui_source=%s)" % [screen, src])
	var c := mounted(screen)
	var names := []
	for n in app.ui_layer.get_children():
		names.append("%s<%s>" % [n.name, n.get_script().resource_path if n.get_script() else "no script"])
	check(c != null, "%s root script is %s (layer children: %s)" % [screen, EXPECT[screen], names])
	return c

func _run() -> void:
	app = root.get_node_or_null("App")
	events = root.get_node_or_null("Events")
	var save := root.get_node_or_null("Save")
	if app == null or events == null or save == null:
		check(false, "autoloads App/Events/Save present")
		_finish()
		return
	# isolate progress
	save.path = TEST_SAVE
	for f in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	save.load_progress()
	events.hud_snapshot.connect(func(s): snaps.append(s))
	# visible-run options (headless runs ignore them): --shot-dir=<abs> --tag=<name> --locale=ko|en
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="):
			shot_tag = a.get_slice("=", 1)
		elif a.begins_with("--tile="):
			tile = int(a.get_slice("=", 1))
			if tile > 0:
				save.progress.unlocked_round = 99   # visible layout run of a later round (5 cards/3 skills)
		elif a.begins_with("--locale="):
			load("res://src/ui/ui_text.gd").load_locale(a.get_slice("=", 1))

	main = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)

	# ---- menu ----
	var menu := assert_screen(&"menu")
	if menu == null:
		_finish(); return
	await shot("1_menu")
	tap(menu.btn_select)
	await _frames(3)

	# ---- round select ----
	var rs := assert_screen(&"round_select")
	if rs == null:
		_finish(); return
	check(rs.rounds.size() >= 3, "round select lists real rounds from Content (%d)" % rs.rounds.size())
	if tile == 0:
		check(not rs.tiles[0].disabled and rs.tiles[1].disabled, "fresh save: r01 open, r02 locked")
	await shot("2_round_select")
	tap(rs.tiles[tile])
	await _frames(4)

	# ---- battle HUD ----
	var hud := assert_screen(&"hud")
	if hud == null:
		_finish(); return
	check(app.screen == &"battle" and app.battle != null, "battle running after tile tap")
	check(hud.card_buttons.size() >= 1, "HUD built %d real cards" % hud.card_buttons.size())
	check(HudOk(hud), "HUD layout valid on real mount: %s" % [hud.layout.get("overflow", "?")])
	await _seconds(0.4)
	check(snaps.size() >= 2, "real HudSnapshots received (%d)" % snaps.size())
	if snaps.is_empty():
		_finish(); return
	var sim = app.battle.sim
	# card deploy through touch
	var cost := int(hud.info.cards[0].get("cost", 0))
	sim.gold = maxf(sim.gold, cost + 5.0)
	await _frames(2)
	var deployed_before := int(sim.stats.deployed)
	var gold_before: float = sim.gold
	tap(hud.card_buttons[0])
	await _frames(2)
	check(int(sim.stats.deployed) == deployed_before + 1, "card tap deployed a real unit (deployed %d→%d)" % [deployed_before, sim.stats.deployed])
	check(sim.gold <= gold_before - cost + 1.0, "gold spent (%.0f→%.0f, cost %d)" % [gold_before, sim.gold, cost])
	# hero hold right
	var x0: float = sim.hero.x if sim.hero else 0.0
	var rp: Vector2 = hud.btn_right.get_global_rect().get_center()
	touch(1, rp, true)
	await _seconds(0.8)
	touch(1, rp, false)
	await _frames(2)
	var x1: float = sim.hero.x if sim.hero else 0.0
	check(x1 > x0 + 10.0, "holding ▶ moved hero right (%.1f→%.1f)" % [x0, x1])
	check(sim.hero_dir == 0, "release stops hero (dir=%d)" % sim.hero_dir)
	events.toast.emit("not_enough_gold", {})
	await _frames(2)
	await shot("3_hud")
	# pause via HUD
	tap(hud.btn_pause)
	await _frames(3)
	var t_paused: float = sim.t
	await _seconds(0.3)
	check(sim.paused or paused, "pause button paused the real sim")
	check(absf(sim.t - t_paused) < 0.001, "sim time frozen while paused (%.3f vs %.3f)" % [sim.t, t_paused])
	check(hud.pause_layer.visible, "pause overlay visible")
	await shot("4_pause")
	tap(hud.pause_buttons[0])
	await _seconds(0.3)
	check(not sim.paused and sim.t > t_paused, "resume continues sim (t %.2f→%.2f)" % [t_paused, sim.t])
	# win → result
	# shortcut: apply lethal damage through the sim's own base-damage path (same code a siege hit uses)
	sim._damage_base(sim.SIDE_ENEMY, sim.enemy_base.hp + 1.0)
	var waited := 0.0
	while mounted(&"result") == null and waited < 6.0:
		await _seconds(0.1)
		waited += 0.1
	var res := assert_screen(&"result")
	if res == null:
		_finish(); return
	check(bool(res.result.get("won", false)), "result screen shows a win (%s)" % [res.result])
	check(res.btn_retry.visible and res.btn_menu.visible, "result has retry + menu")
	await _seconds(0.8)   # star pop-in animation
	await shot("5_result")
	# retry from result restarts battle with the 04 HUD again
	tap(res.btn_retry)
	await _frames(4)
	var hud2 := assert_screen(&"hud")
	check(hud2 != null and app.battle != null and app.battle.sim.t < 1.0, "retry restarted battle")
	_finish()

func HudOk(hud: Control) -> bool:
	var HudLayout := load("res://src/ui/hud_layout.gd")
	return HudLayout.validate(hud.layout).is_empty()

func _finish() -> void:
	print("[ui_integration] passed=%d failed=%d" % [passes, failures.size()])
	for f in failures:
		print("  - " + f)
	if main != null:
		main.queue_free()
	for f in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit(1 if failures.size() > 0 or passes == 0 else 0)
