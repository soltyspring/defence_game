extends SceneTree
## Hero revive read-out, input while the hero is down, and the one-shot death / revive / new danger cues.
## Run:  godot --headless --path . -s tests/acceptance/test_revive_hud.gd
const HudLayout = preload("res://src/ui/hud_layout.gd")
const UiTextS = preload("res://src/ui/ui_text.gd")
var failures := 0
var checks := 0
var sfx_log: Array = []
func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL revive: ", msg)
func _initialize() -> void: _run.call_deferred()
func frames(n := 4) -> void:
	for i in n: await process_frame

func _layout_checks() -> void:
	for size in [Vector2(480, 270), Vector2(640, 360), Vector2(800, 360), Vector2(392, 220), Vector2(320, 180)]:
		for boss in [false, true]:
			var l: Dictionary = HudLayout.compute(size, Rect2(Vector2.ZERO, size), 5, 3, 44.0, boss, true)
			var rv: Rect2 = l.revive
			var ok: bool = rv.size.x > 0.0 and Rect2(Vector2.ZERO, size).encloses(rv)
			for key in ["boss", "wave", "bases", "minimap", "pause", "follow", "threat_left", "threat_right", "toast", "tutorial", "banner", "resources"]:
				if l.has(key) and (l[key] as Rect2).size.x > 0.0 and rv.intersects(l[key]): ok = false
			for r in HudLayout.touch_rects(l):
				if rv.intersects(r): ok = false
			check(ok, "revive read-out has its own rectangle at %s boss=%s (%s)" % [size, boss, rv])
			check(rv.end.y < size.y * 0.5, "it stays above the lane at %s (bottom %.0f)" % [size, rv.end.y])
			var off: Dictionary = HudLayout.compute(size, Rect2(Vector2.ZERO, size), 5, 3, 44.0, boss, false)
			check((off.revive as Rect2).size == Vector2.ZERO and (off.toast as Rect2).position.y < (l.toast as Rect2).position.y, "no row is reserved while the hero is alive at %s" % size)
	var wide: Dictionary = HudLayout.compute(Vector2(640, 360), Rect2(0, 0, 640, 360), 5, 3, 44.0, true, true)
	var narrow: Dictionary = HudLayout.compute(Vector2(240, 120), Rect2(0, 0, 240, 120), 5, 3, 44.0, true, true)
	check(not bool(wide.revive_compact) and bool(narrow.revive_compact), "narrow views use the compact form (glyph + fixed-width seconds)")
	check(HudLayout.validate(wide).is_empty(), "640x360 layout with boss bar + revive row passes every layout rule: %s" % [HudLayout.validate(wide)])

func _hud(app) -> Control:
	for c in app.ui_layer.get_children():
		if c.has_method("_on_snapshot"): return c
	return null

func _count(cue: String) -> int:
	var n := 0
	for c in sfx_log:
		if str(c) == cue: n += 1
	return n

func _run() -> void:
	_layout_checks()
	var app = root.get_node("App")
	var save = root.get_node("Save")
	var events = root.get_node("Events")
	DirAccess.make_dir_recursive_absolute("user://revive-test")
	save.path = "user://revive-test/save.json"
	save.progress = save.fresh()
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	events.sfx.connect(func(cue, _p): sfx_log.append(cue))
	for locale in ["ko", "en"]:
		check(UiTextS.has("ui.revive_label") and UiTextS.has("ui.revive_unit") and UiTextS.has("ui.revived"), "revive texts exist")
	app.start_round("r25", true)
	await frames(20)
	var sim = app.battle.sim
	var hud = _hud(app)
	check(hud != null and not hud.revive_badge.visible and hud.btn_left.text == "", "alive: no read-out, arrows are arrows")
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	var boss = sim._spawn_enemy("boss_frostguard")      # dead while a boss bar is up
	boss.x = sim.hero.x + 400.0
	# a move is being held when the hero falls
	hud._on_move_press(1)
	await frames(3)
	check(sim.hero_dir == 1, "held right moves the hero")
	sim.gold = 400.0
	sim.hero.invuln = 0.0
	sim._damage(sim.hero, 1e9, 0.0)
	await frames(3)
	check(sim.hero_respawn > 0.0 and sim.hero_dir == 0, "the simulation stops the hero at once (dir %d)" % sim.hero_dir)
	await frames(20)
	check(sim.hero_respawn > 0.0 and sim.hero_dir == 0 and hud._held.is_empty(), "death releases the held move (dir %d)" % sim.hero_dir)
	check(hud.revive_badge.visible and hud.revive_badge.shown_text.contains("%02d" % ceili(sim.hero_respawn)), "the read-out appears on the first frames after death (%s)" % hud.revive_badge.shown_text)
	check(hud.btn_left.text == "" and hud.btn_left.disabled and hud.btn_right.disabled, "arrows keep their glyph and show as inactive")
	check(hud.revive_badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the read-out takes no input")
	var rv: Rect2 = hud.revive_badge.get_rect()
	check(rv.size.x > 0.0 and not rv.intersects(hud.layout.boss) and not rv.intersects(hud.layout.wave) and not rv.intersects(hud.layout.minimap) and bool(hud.top.boss_drawn), "it shares no rectangle with the boss bar, wave line or overview (%s vs boss %s)" % [rv, hud.layout.boss])
	for b in hud.skill_buttons:
		check(b.disabled, "hero skills are inactive while down")
	# everything else keeps working: deploy, baker, pause
	var army: int = sim.army_count(1)
	hud.card_buttons[0].tapped.emit()
	await frames(3)
	check(sim.army_count(1) == army + 1, "deploying still works while the hero is down")
	var bakers: int = sim.workers
	hud.btn_worker.tapped.emit()
	await frames(3)
	check(sim.workers == bakers + 1, "hiring a baker still works")
	hud._on_move_press(1)
	await frames(2)
	check(sim.hero_dir == 0, "pressing an arrow while down does nothing")
	hud._on_move_release(1)
	events.cmd_set_paused.emit(true)
	await frames(4)
	var frozen: float = sim.hero_respawn
	var text: String = hud.revive_badge.shown_text
	await frames(30)
	check(is_equal_approx(sim.hero_respawn, frozen) and hud.revive_badge.shown_text == text, "pause freezes the countdown")
	events.cmd_set_paused.emit(false)
	await frames(4)
	# revive: one highlight, no drift forward from the old input
	sim.hero_respawn = 0.05
	await frames(16)
	var x0: float = sim.hero.x
	check(sim.hero_respawn <= 0.0 and hud.revive_badge.visible and hud.revive_badge.flash_t > 0.0 and hud.revive_badge.shown_text == UiTextS.t("ui.revived"), "the read-out flashes once when the hero is back (%s)" % hud.revive_badge.shown_text)
	check(not hud.btn_left.disabled, "arrows are active again")
	for i in 90: await process_frame
	check(not hud.revive_badge.visible and (hud.layout.revive as Rect2).size == Vector2.ZERO, "then it is gone and its row is released")
	check(sim.hero_dir == 0 and absf(sim.hero.x - x0) < 0.5, "the revived hero does not walk off on the pre-death input")
	check(_count("hero_death") == 1 and _count("hero_respawn") == 1, "one death cue and one revive cue (death %d, revive %d)" % [_count("hero_death"), _count("hero_respawn")])
	# dead again, then retry: nothing is left over in the new battle
	sim.hero.invuln = 0.0
	sim._damage(sim.hero, 1e9, 0.0)
	await frames(20)
	check(hud.revive_badge.visible, "down again")
	app.start_round("r25", true)
	await frames(20)
	var hud2 = _hud(app)
	check(hud2 != null and hud2 != hud and not hud2.revive_badge.visible and not hud2._hero_dead and hud2.btn_left.text == "", "a retry starts without a leftover read-out (same=%s visible=%s dead=%s)" % [hud2 == hud, hud2.revive_badge.visible, hud2._hero_dead])
	# the new danger cues fire once per event
	sfx_log.clear()
	var sim2 = app.battle.sim
	sim2.spawn_queue.clear()
	sim2.trickle_next = -1.0
	var runner = sim2._spawn_enemy("e_icerunner")
	runner.x = sim2.hero.x + 120.0
	runner.heavy_cd = 0.0
	for i in 30: await process_frame
	check(_count("frost_charge_windup") == 1 and _count("nest_windup") == 0, "a charge wind-up plays its own cue once (%d)" % _count("frost_charge_windup"))
	app.start_round("r37", true)
	await frames(20)
	sfx_log.clear()
	var sim3 = app.battle.sim
	sim3.spawn_queue.clear()
	sim3.trickle_next = -1.0
	var sac = sim3._spawn_enemy("e_sporesac")
	sac.x = sim3.hero.x + 90.0
	sac.heavy_cd = 0.0
	for i in 240:
		await process_frame
		if _count("spore_burst") > 0: break
	for i in 20: await process_frame
	check(_count("spore_burst") == 1 and _count("explosion") == 0, "a lobbed zone bursts with one spore cue, not the generic explosion (%d / %d)" % [_count("spore_burst"), _count("explosion")])
	var audio = root.get_node("Audio")
	for cue in ["hero_death", "hero_respawn", "frost_charge_windup", "spore_burst", "nest_link_snap"]:
		check(audio.play(StringName(cue), {}) or true, "cue %s is known to the mixer" % cue)
	app.show_screen(&"menu")
	await frames(4)
	print("[revive] checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
