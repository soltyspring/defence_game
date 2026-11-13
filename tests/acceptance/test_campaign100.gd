extends SceneTree

const Sim := preload("res://src/gameplay/battle_sim.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL campaign100: ", message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c = root.get_node("Content")
	var save = root.get_node("Save")
	save.path = "user://campaign100-tests/save.json"
	DirAccess.make_dir_recursive_absolute(save.path.get_base_dir())
	save.progress = save.fresh()
	check(c.round_order.size() == 100 and c.warnings.is_empty(), "100 rounds, valid references")
	check(c.available_roster(100).size() == 10, "exactly ten selectable types, excludes hero/worker")
	for n in range(1,101):
		var rid := "r%02d" % n
		check(c.get_round(rid).index == n, "ordered round " + rid)
		check(c.next_round_id(rid) == ("r%02d" % (n+1) if n<100 else ""), "next route " + rid)
		var sim = Sim.new()
		sim.setup(c,rid,123)
		for tick in 30: sim.step(1.0/30.0)
		check(sim.enemy_hp_mult > 0 and sim.card_ids.size() <= 5, "valid simulation " + rid)
	var deck := ["baguette","macaron","chili","donut","waffle"]
	var joins := [30,40,50,60,70]
	var costs := [1000,1200,1500,1800,2400]
	save.progress.coins = 10000
	for i in deck.size():
		var id: String = deck[i]
		var before_recruit: int = save.progress.coins
		save.progress.unlocked_round = joins[i] - 1
		check(save.recruit(id) == "locked" and save.progress.coins == before_recruit, "recruit locked before join: " + id)
		save.progress.unlocked_round = joins[i]
		check(save.recruit_cost(id) == costs[i] and save.unit_recruitable(id) and not save.set_loadout([id]), "join requires purchase: " + id)
		if i == 0:
			check(save.save_progress(), "persist a pre-recruit save before testing write failure")
			save._fault = "after_tmp_write"
			check(save.recruit(id) == "save_failed" and save.progress.coins == before_recruit and not save.unit_owned(id), "failed recruit rolls back coins and ownership")
			save._fault = ""
		check(save.recruit(id) == "ok" and save.unit_owned(id) and save.progress.coins == before_recruit - costs[i], "recruit charges once: " + id)
		check(save.recruit(id) == "already_applied" and save.progress.coins == before_recruit - costs[i], "duplicate recruit does not charge: " + id)
	check(save.set_loadout(deck), "save five recruited types")
	save.load_progress()
	check(save.selected_loadout() == deck, "squad survives reload")
	check(not save.set_loadout(deck + ["tank"]), "sixth type rejected")
	check(not save.set_loadout(["tank","tank"]), "duplicate rejected")
	check(not save.set_loadout(["e_grunt"]), "enemy rejected")
	check(not save.set_loadout([]), "empty rejected")
	save.progress.unlocked_round = 1
	check(not save.set_loadout(["waffle"]), "locked unit rejected")
	check(save.selected_loadout() == ["melee_basic"], "stale locked squad repaired on read")
	save.progress.unlocked_round = 100
	check(save.set_loadout(deck), "restore late squad")
	save._fault = "after_tmp_write"
	check(not save.set_loadout(["tank"]) and save.selected_loadout() == deck, "failed save restores squad")
	save._fault = ""
	var sim = Sim.new()
	sim.setup(c,"r01",1,{},deck)
	check(Array(sim.card_ids) == deck, "unlocked late units may replay r01")
	for id in deck:
		sim.gold = 9999
		check(sim.deploy(id) == "", "new type deploys: " + id)
		var duel = Sim.new()
		duel.setup(c,"r20",7,{},[id])
		duel.spawn_queue.clear()
		duel.trickle_next = -1
		duel.hero.x = 50
		duel.gold = 9999
		duel.deploy(id)
		var attacker = duel.players.back()
		attacker.x = 400
		var enemy = duel._spawn_enemy("e_brute")
		enemy.x = 420
		var hp_before: float = enemy.hp
		for tick in 120: duel.step(1.0/30.0)
		check(enemy.hp < hp_before, "new type actually deals damage: " + id)
	var boosted = Sim.new()
	boosted.setup(c,"r96",1,{"up_baguette":40},deck)
	check(boosted._upgrade_mult("unit:baguette","atk_mult") > 35.0, "late upgrades compound")
	for u in c.meta.upgrades:
		check(int(u.max_level) == 40 and u.costs.size() == 39, "complete cost curve " + str(u.id))
		for i in range(1,u.costs.size()): check(u.costs[i] >= u.costs[i-1], "monotonic costs")
	save.progress.coins = 100000
	save.progress.upgrades = {"up_baguette":39}
	check(save.buy_upgrade("up_baguette",40) == "ok", "level 40 purchasable")
	check(save.buy_upgrade("up_baguette",41) != "ok", "level 41 rejected")
	var catalog = load("res://src/core/gold_shop_catalog.gd")
	var before: int = save.progress.coins
	if catalog.enabled():
		check(save.buy_preview_growth("growth_23") == "ok" and save.progress.coins == before+6000, "3000 KRW preview grants fixed 6000 gold")
		check(save.buy_preview_growth("growth_23") == "owned", "growth pack cannot repeat")
		save.load_progress()
		check(save.buy_preview_growth("growth_23") == "owned", "one-time entitlement persists")
		check(save.buy_preview_growth("invalid") == "unavailable", "unknown SKU rejected")
		before = int(save.progress.coins)
		save.progress.unlocked_round = 1
		check(save.buy_preview_growth("growth_42") == "locked" and int(save.progress.coins) == before, "locked growth pack gives no gold")
		save.progress.unlocked_round = 100
		save._fault = "after_tmp_write"
		check(save.buy_preview_growth("growth_42") == "save_failed" and int(save.progress.coins) == before and not save.progress.growth_purchases.has("growth_42"), "failed pack save rolls back wallet and entitlement")
		save._fault = ""
	else:
		check(save.buy_preview_growth("growth_23") == "unavailable" and save.progress.coins == before, "release cannot grant preview gold")
	var roster = load("res://scenes/ui/roster.tscn").instantiate()
	root.add_child(roster)
	await process_frame
	check(roster.tiles.size() == 10, "roster shows ten tiles")
	roster.selected = deck.duplicate()
	roster._toggle("tank")
	check(roster.selected.size() == 5 and not roster.selected.has("tank"), "UI rejects sixth card")
	for size in [Vector2(640,360),Vector2(800,450)]:
		roster.safe = Rect2(Vector2.ZERO,size)
		roster.view = size
		roster._layout()
		for tile in roster.tiles:
			check(roster.safe.encloses(tile.get_rect()) and tile.size.x >= 40 and tile.size.y >= 40, "touch targets fit")
	roster.queue_free()
	var atlas = root.get_node("Atlas")
	check(atlas.acquire("roster10"), "new atlas loads")
	for id in deck:
		for animation in ["idle","walk","attack","death"]:
			check(atlas.anim_rec(id,animation) != null, "animation " + id + "/" + animation)
	atlas.release("roster10")
	var preview := Image.create(240,48,false,Image.FORMAT_RGBA8)
	for i in deck.size():
		var portrait = load("res://assets/art/roster10/"+str(deck[i])+".png")
		check(portrait is Texture2D, "portrait loads")
		var character: Image = portrait.get_image() if portrait is Texture2D else Image.create(24,24,false,Image.FORMAT_RGBA8)
		check(character.get_size() == Vector2i(24,24), "portrait matches the existing HUD footprint")
		character.resize(48,48,Image.INTERPOLATE_NEAREST)
		preview.blit_rect(character,Rect2i(0,0,48,48),Vector2i(i*48,0))
	preview.resize(960,192,Image.INTERPOLATE_NEAREST)
	preview.save_png("user://campaign100-tests/roster-preview.png")
	var app = root.get_node("App")
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await process_frame
	await process_frame
	save.progress.unlocked_round = 100
	save.set_loadout(deck)
	app.show_screen(&"round_select")
	await process_frame
	var select_screen = app.ui_layer.get_child(-1)
	var tile_index: int = c.round_order.find("r42")
	var tiles_per_page: int = select_screen.tiles.size()
	select_screen._set_page(tile_index / tiles_per_page)
	select_screen._on_tile(tile_index % tiles_per_page)
	await process_frame
	check(app.screen == &"roster", "late round opens deploy preparation before battle")
	if app.screen != &"roster":
		quit(1)
		return
	var prep = app.ui_layer.get_child(-1)
	check(prep.round_id == "r42" and prep.selected == deck, "deploy preparation keeps round and recruited selection")
	prep._save()
	await process_frame
	check(app.screen == &"battle" and app.battle != null, "confirm starts the chosen battle")
	if app.battle == null:
		quit(1)
		return
	await process_frame
	check(Array(app.battle.sim.card_ids) == deck, "App passes saved selection into real battle")
	var hud = app.ui_layer.get_child(-1)
	check(hud.card_buttons.size() == 5, "real HUD mounts five selected cards")
	for button in hud.card_buttons: check(button.icon != null and button.icon.get_size() == Vector2(24,24), "real HUD uses correctly sized portrait")
	app.show_screen(&"roster")
	await process_frame
	check(app.ui_source.get(&"roster") == "scenes/ui", "real roster route mounts")
	if catalog.enabled():
		app.show_screen(&"gold_shop")
		await process_frame
		var shop = app.ui_layer.get_child(-1)
		shop._switch_category()
		check(shop.growth_buttons.size() == 5 and shop.growth_buttons[0].visible, "growth shop has five offers")
		for button in shop.growth_buttons:
			check(shop.safe.encloses(button.get_rect()), "growth button is inside screen")
	app.show_screen(&"menu")
	await process_frame
	root.get_node("Audio").prepare_quit()
	await create_timer(0.3, true, false, true).timeout
	print("[campaign100] checks=", checks, " failures=", failures)
	quit(0 if failures==0 else 1)
