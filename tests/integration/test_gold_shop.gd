extends SceneTree

const Catalog := preload("res://src/core/gold_shop_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL gold shop: ", msg)

func frames(n := 4) -> void:
	for i in n: await process_frame

func tap(button: Control, touch: bool) -> void:
	var pos := button.get_global_rect().get_center()
	for down in [true, false]:
		if touch:
			var e := InputEventScreenTouch.new()
			e.position = pos
			e.pressed = down
			root.push_input(e, true)
		else:
			var e := InputEventMouseButton.new()
			e.device = 32
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = pos
			e.pressed = down
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			root.push_input(e, true)

func _run() -> void:
	var app = root.get_node("App")
	var save = root.get_node("Save")
	save.path = "user://gold-shop-test/save.json"
	DirAccess.make_dir_recursive_absolute(save.path.get_base_dir())
	save.progress = save.fresh()
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await frames()
	var menu = app.ui_layer.get_child(-1)
	if not Catalog.enabled():
		check(menu.btn_shop == null, "normal build has no shop entry")
		app.show_screen(&"gold_shop")
		check(app.screen == &"menu" and save.buy_preview_gold(1000) == "unavailable" and int(save.progress.coins) == 0, "normal build cannot access the preview route or mint gold")
	else:
		check(menu.btn_shop != null, "preview exposes the shop")
		check(menu.btn_shop == null or not menu.btn_shop.visible, "title keeps the shop in the lobby")
		tap(menu.btn_start, false)
		await frames()
		check(menu.page == "lobby", "start opens the lobby")
		if menu.btn_shop != null:
			check(menu.btn_shop.visible, "shop is visible in the lobby")
			tap(menu.btn_shop, false)
		await frames()
		check(app.screen == &"gold_shop", "menu click opens the real shop scene")
		if app.screen == &"gold_shop":
			var shop = app.ui_layer.get_child(-1)
			var total := 0
			for i in range(4):
				var button: Control = shop.pack_buttons[i]
				check(not button.text.is_empty() and Catalog.formatted(Catalog.PACKS[i]) in button.sub_text, "pack has matching price and amount")
				tap(button, i % 2 == 1)
				await frames()
				total += Catalog.PACKS[i]
				check(int(save.progress.coins) == total, "one click grants exactly one full pack: %d" % Catalog.PACKS[i])
			save.load_progress()
			check(int(save.progress.coins) == 18400, "all four packs persist in the upgrade wallet")
			var cost: int = save.upgrade_cost("up_melee_basic", 2)
			check(save.buy_upgrade("up_melee_basic", 2) == "ok" and int(save.progress.coins) == total - cost, "the same gold can be spent on upgrades")
			var before := int(save.progress.coins)
			check(save.buy_preview_gold(99999) == "unavailable" and int(save.progress.coins) == before, "unknown pack is rejected")
			save.read_only = true
			check(save.buy_preview_gold(1000) == "read_only" and int(save.progress.coins) == before, "read-only save is untouched")
			save.read_only = false
			save._fault = "after_tmp_write"
			check(save.buy_preview_gold(1000) == "save_failed" and int(save.progress.coins) == before, "failed save rolls back the grant")
			save.progress.coins = save._coins_cap() - 1
			check(save.buy_preview_gold(1000) == "wallet_full" and int(save.progress.coins) == save._coins_cap() - 1, "wallet cap never truncates a pack")
			await create_timer(0.15, true, false, true).timeout
			var back_cues: Array[StringName] = []
			var record_cue := func(cue: StringName, _voice: int): back_cues.append(cue)
			root.get_node("Audio").cue_played.connect(record_cue)
			tap(shop.btn_back, true)
			await frames()
			root.get_node("Audio").cue_played.disconnect(record_cue)
			check(app.screen == &"menu", "back returns to the main menu")
			check(back_cues == [&"ui_back"], "back plays the single-tick back cue once: %s" % str(back_cues))
	print("[gold-shop] checks=", checks, " failures=", failures, " preview=", Catalog.enabled())
	root.get_node("Audio").prepare_quit()
	await create_timer(0.3, true, false, true).timeout
	quit(0 if failures == 0 else 1)
