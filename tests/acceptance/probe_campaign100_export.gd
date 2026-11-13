extends SceneTree
## Run as an external script with the packaged executable and a private APPDATA.
var failures:=0
var checks:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL exported campaign100: ",message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var c=root.get_node("Content")
	var save=root.get_node("Save")
	var app=root.get_node("App")
	check(c.round_order.size()==100 and c.warnings.is_empty(),"embedded hundred rounds")
	check(c.available_roster(100).size()==10,"embedded ten types")
	check(OS.has_feature("gold_shop_preview"),"test shop feature enabled")
	check(ProjectSettings.get_setting("application/config/custom_user_dir_name","")=="BakeryKnights-Campaign100","independent save directory")
	save.progress=save.fresh()
	save.progress.unlocked_round=100
	var deck: Array=["baguette","macaron","chili","donut","waffle"]
	save.progress.coins=7900
	for id in deck: check(save.recruit(id)=="ok","packaged recruitment: " + id)
	check(save.progress.coins==0,"packaged recruitment costs 7900 total")
	check(save.set_loadout(deck),"selection saves")
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await process_frame
	app.show_screen(&"roster")
	await process_frame
	check(app.ui_layer.get_child(-1).tiles.size()==10,"packaged roster opens")
	app.start_round("r100")
	await process_frame
	check(Array(app.battle.sim.card_ids)==deck,"packaged battle receives selection")
	for button in app.ui_layer.get_child(-1).card_buttons:
		check(button.icon!=null and button.icon.get_size()==Vector2(24,24),"packaged portrait imported")
	for id in deck:
		check(root.get_node("Atlas").anim_rec(id,"attack")!=null,"packaged atlas JSON/texture resolves")
		app.battle.sim.gold=9999
		check(app.battle.sim.deploy(id)=="","packaged unit deploys")
	await create_timer(0.5,true,false,true).timeout
	app.show_screen(&"gold_shop")
	await process_frame
	var shop=app.ui_layer.get_child(-1)
	shop._switch_category()
	check(shop.growth_buttons.size()==5,"packaged growth offers")
	shop._buy_growth("growth_23")
	check(int(save.progress.coins)==6000,"packaged preview grants exact amount")
	shop._buy_growth("growth_23")
	check(int(save.progress.coins)==6000,"packaged grant cannot repeat")
	save.load_progress()
	check(save.selected_loadout()==deck and int(save.progress.coins)==6000,"packaged persistence")
	app.show_screen(&"menu")
	await process_frame
	root.get_node("Audio").prepare_quit()
	await create_timer(0.3,true,false,true).timeout
	print("[campaign100-export] checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
