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
var spawn_boss := false
var boss_id := "boss_warlord"
var toasts_seen: Array = []

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
	events.toast.connect(func(k, _a): toasts_seen.append(k))
	# visible-run options (headless runs ignore them): --shot-dir=<abs> --tag=<name> --locale=ko|en
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="):
			shot_tag = a.get_slice("=", 1)
		elif a.begins_with("--boss="):
			spawn_boss = true
			boss_id = a.get_slice("=", 1)
		elif a.begins_with("--tile="):
			tile = int(a.get_slice("=", 1))
			if tile > 0:
				save.progress.unlocked_round = 99   # visible layout run of a later round (5 cards/3 skills)
		elif a.begins_with("--safe="):
			# simulated notch insets L,T,R,B in logical px (same as ui_preview); worst case = 34,0,34,0
			var p := a.get_slice("=", 1).split(",")
			load("res://src/ui/safe_area.gd").override_insets = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
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
	# upgrades panel on the REAL engine: until 02 adds Save.buy_upgrade it must be inactive, not fake
	tap(rs.btn_upgrades)
	await _frames(2)
	var up: Control = rs.upgrade_panel
	check(up != null and up.visible, "round select → upgrades panel opens")
	if up != null:
		var real_api: bool = up.purchase_available()
		var any_btn: bool = not up.buy_buttons.is_empty()
		check(real_api or (any_btn and up.buy_buttons[0].disabled and up.status_text != ""), "upgrade buy %s (Save.buy_upgrade %s)" % ["active" if real_api else "inactive with notice", "present" if real_api else "missing"])
		await shot("2b_upgrades")
		tap(up.btn_close)
		await _frames(2)
		check(not up.visible, "upgrades panel closes")
	tap(rs.tiles[tile])
	await _frames(4)

	# ---- battle HUD ----
	var hud := assert_screen(&"hud")
	if hud == null:
		_finish(); return
	check(app.screen == &"battle" and app.battle != null, "battle running after tile tap")
	check(hud.card_buttons.size() >= 1, "HUD built %d real cards" % hud.card_buttons.size())
	check(HudOk(hud), "HUD layout valid on real mount: %s" % [hud.layout.get("overflow", "?")])
	var vsz: Vector2 = root.get_visible_rect().size
	check(hud.btn_left.get_global_rect().end.y >= vsz.y - 16.0, "HUD bottom row anchored to the real view bottom (btn end %.0f, view %s)" % [hud.btn_left.get_global_rect().end.y, vsz])
	await _seconds(0.4)
	check(snaps.size() >= 2, "real HudSnapshots received (%d)" % snaps.size())
	if tile == 0:
		# r01 data has tutorial [tut_move_hero, ...]; the real battle.gd emits tutorial_step
		var tw := 0.0
		while hud.tutorial_key == "" and tw < 3.0:
			await _seconds(0.1)
			tw += 0.1
		check(hud.tutorial_key != "" and hud.tutorial_label.modulate.a > 0.9, "real tutorial hint shown in r01 (%s: '%s')" % [hud.tutorial_key, hud.tutorial_label.text])
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
	# real HUD state BEFORE any test-injected toast (09 X3: the earlier 3_hud toast came from this test)
	await _frames(2)
	await shot("3_hud")
	check(not toasts_seen.has("not_enough_gold"), "no 'not enough supply' toast from real play so far (toasts: %s)" % [toasts_seen])
	# base HP numbers follow a real base hit
	sim._damage_base(sim.SIDE_PLAYER, 100.0)
	await _seconds(0.25)
	var want := "%d/%d" % [ceili(sim.player_base.hp), ceili(sim.player_base.hp_max)]
	check(hud.top.base_labels.player == want, "player base number after a real hit = %s (drawn %s)" % [want, hud.top.base_labels.player])
	if spawn_boss:
		sim._spawn_enemy(boss_id)
		var bw := 0.0
		while not hud.top.boss_drawn and bw < 2.0:
			await _seconds(0.1)
			bw += 0.1
		check(hud.top.boss_drawn, "real boss %s spawned → HUD boss bar drawn" % boss_id)
		await shot("3c_boss")
	if not hud.skill_buttons.is_empty():
		var sb: Control = hud.skill_buttons[0]
		touch(3, sb.get_global_rect().get_center(), true)
		await _frames(2)
		check(hud.skill_tip.modulate.a > 0.9 and hud.skill_tip.text == sb.text, "skill name tip on real skill button: '%s'" % hud.skill_tip.text)
		await shot("3d_skilltip")
		touch(3, sb.get_global_rect().get_center(), false)
		await _frames(1)
	events.toast.emit("not_enough_gold", {})
	await _frames(2)
	await shot("3b_toast")
	# pause via HUD
	tap(hud.btn_pause)
	await _frames(3)
	var t_paused: float = sim.t
	await _seconds(0.3)
	check(sim.paused or paused, "pause button paused the real sim")
	check(absf(sim.t - t_paused) < 0.001, "sim time frozen while paused (%.3f vs %.3f)" % [sim.t, t_paused])
	check(hud.pause_layer.visible, "pause overlay visible")
	await shot("4_pause")
	if shot_dir != "":
		# credits view inside pause → settings (visible runs only; headless covered by tests/ui)
		tap(hud.pause_buttons[2])
		await _frames(2)
		tap(hud.settings_panel._credits_btn)
		await _frames(2)
		await shot("4b_credits")
		hud.settings_panel._on_close()
		hud.settings_panel._on_close()
		await _frames(2)
		if not hud.pause_layer.visible:
			hud.pause_layer.visible = true
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
	var reasons: Array = res.star_reasons()
	var met := reasons.filter(func(x): return x.met).size()
	check(met == int(res.result.get("stars", -1)), "star reasons from real round thresholds match engine stars (%d vs %s: %s)" % [met, res.result.get("stars"), reasons])
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
