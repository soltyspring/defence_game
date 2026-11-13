extends SceneTree
## The upgrade panel with real numbers: page 1 and 2 at mixed levels, one maxed row, and right after a purchase.
##   godot --path . --resolution 640x360 -s tests/art_preview/capture_upgrades.gd -- --out=<abs dir>
## Isolated save; the player's save is not written.
var out_dir := "user://art_preview/upgrades"
var size := Vector2i.ZERO

func _initialize() -> void: _run.call_deferred()

func frames(n := 4) -> void:
	for i in n: await process_frame

func shot(name: String) -> void:
	await frames(6)
	var path := "%s/%s_%dx%d.png" % [out_dir, name, size.x, size.y]
	root.get_texture().get_image().save_png(path)
	print("[upgrades] ", path)

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var app = root.get_node("App")
	var save = root.get_node("Save")
	DirAccess.make_dir_recursive_absolute("user://art_preview")
	save.path = "user://art_preview/save.json"
	save.progress = save.fresh()
	save.progress.unlocked_round = 30
	save.progress.coins = 4000
	save.progress.upgrades = {"up_melee_basic": 7, "up_ranged_basic": 3, "up_tank": 12, "up_hero": 9, "up_base_hp": 40, "up_supply_regen": 5, "up_energy_regen": 2, "up_worker": 4}
	if app.world == null:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		await frames()
	size = DisplayServer.window_get_size()
	app.show_screen(&"round_select")
	await frames(4)
	var screen = null
	for n in root.find_children("*", "", true, false):
		if n.has_method("open_upgrades") and n.is_inside_tree() and n.is_visible_in_tree(): screen = n
	screen.open_upgrades()
	await shot("1_page1")
	var panel = screen.upgrade_panel
	panel._on_buy(0)
	await shot("2_after_buy")
	for p in range(1, panel.pages()):
		panel._set_page(p)
		await shot("3_page%d" % (p + 1))
	quit(0)
