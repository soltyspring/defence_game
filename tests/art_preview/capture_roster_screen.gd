extends SceneTree
## The loadout screen in use: round tap -> 출전 준비 (R41) with the saved squad, after swapping two units, a full squad
## refusing a sixth, the start button launching the battle with those cards, and the plain 편성 screen at R14 (locks).
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_roster_screen.gd -- --out=<abs dir>
## Isolated save; the player's save is not written. Prints CHECK lines for the flow.
var RosterScreen: GDScript       # loaded in _run: a preload here compiles before the autoloads (Save, Content) exist
var out_dir := "user://art_preview/roster_screen"
var size := Vector2i.ZERO
var failures := 0

func _initialize() -> void: _run.call_deferred()

func frames(n := 4) -> void:
	for i in n: await process_frame

func shot(name: String) -> void:
	await frames(6)
	var path := "%s/%s_%dx%d.png" % [out_dir, name, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	print("[roster-screen] ", path)

func check(ok: bool, what: String) -> void:
	print("CHECK ", "ok " if ok else "FAIL ", what)
	if not ok: failures += 1

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	RosterScreen = load("res://src/ui/roster.gd")
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
	# 1 round select -> tap R41 opens 출전 준비
	app.show_screen(&"round_select")
	await frames(4)
	RosterScreen.pending_round = "r41"
	app.show_screen(&"roster")
	await frames(4)
	await shot("1_prep_default")
	var screen = _screen(app)
	check(screen != null and screen.round_id == "r41", "round tap opens the prep screen for that round")
	# 2 take two out, put two new ones in
	screen._take_out(0)
	screen._take_out(0)
	screen._toggle("baguette")
	screen._toggle("chili")
	await shot("2_prep_swapped")
	check(screen.selected.size() == 5 and screen.selected.has("baguette") and screen.selected.has("chili"), "swap keeps five")
	screen._toggle("donut")
	await shot("3_prep_full")
	check(screen.selected.size() == 5 and not screen.selected.has("donut"), "sixth refused")
	var squad: Array = screen.selected.duplicate()
	# 3 start -> battle with those cards
	screen._save()
	await frames(30)
	check(app.battle != null and app.battle.sim != null and str(app.battle.sim.round_def.get("id", "")) == "r41", "start launches R41")
	if app.battle != null and app.battle.sim != null:
		var cards: Array = app.battle.sim.card_cd.keys()
		var ok := true
		for id in squad: ok = ok and cards.has(id)
		check(ok, "battle cards are the chosen squad " + str(squad))
	await frames(40)
	await shot("4_battle_cards")
	# 4 plain 편성 at R14 reach: later units locked
	app.show_screen(&"menu")
	await frames(4)
	save.progress = save.fresh()
	save.progress.unlocked_round = 14
	app.show_screen(&"roster")
	await frames(4)
	await shot("5_squad_r14")
	print("[roster-screen] failures=", failures)
	quit(0 if failures == 0 else 1)

func _screen(app):
	for n in root.find_children("*", "", true, false):
		if n.get_script() == RosterScreen and n.is_inside_tree(): return n
	return null
