extends SceneTree
## 07-qa visible capture + geometry probe. MUST be launched through 04's secondary-monitor launcher:
##   .\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/acceptance/capture_visual.gd `
##       -Resolution 1280x720 -UserArgs '--shot-dir=<abs>','--locale=ko','--tag=ko_2x'
## Boots the real main.tscn with an isolated save (user://qa07/visual_save.json, all rounds unlocked),
## captures menu, round select, settings, r01 HUD at ~0 s / ~30 s / ~60 s (+ the result), and writes
## <shot-dir>/<tag>_report.json with:
##   - round tile name block vs tile height / number / star rows (2-line wrap fit, QA-B010 follow-up)
##   - services mode + any visible ad/purchase/shop control (D9 disabled state)
## Owner: 07-qa. Read-only for the game; never touches user://save.json.

const TouchButtonS := preload("res://src/ui/touch_button.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const MONEY_WORDS := ["광고", "구매", "상점", "결제", "보석", "젬", "패키지", "ad", "ads", "shop", "store", "purchase", "buy gems", "gem", "iap", "restore", "remove ads"]

var shot_dir := ""
var tag := "run"
var report := {"shots": [], "tiles": [], "money_controls": [], "services": {}}
var app: Node

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a.begins_with("--locale="): load("res://src/ui/ui_text.gd").load_locale(a.get_slice("=", 1))
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://qa07")
		save.path = "user://qa07/visual_save.json"
		save.progress = save.fresh()
		save.progress.unlocked_round = 10
		save.progress.stars = {"r01": 3, "r02": 2, "r03": 1}
		save.save_progress()
	_run.call_deferred()

func _frames(n := 3) -> void:
	for i in n: await process_frame

func _shot(name: String) -> void:
	await _frames(3)
	report.shots.append(name)
	if shot_dir == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.get_texture().get_image().save_png(shot_dir.path_join("%s_%s.png" % [tag, name]))

func _buttons(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c is Control and c.get_script() == TouchButtonS and c.is_visible_in_tree(): out.append(c)
		_buttons(c, out)
	return out

func _labels(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c is Label and c.is_visible_in_tree() and str(c.text) != "": out.append(str(c.text))
		if c is Button and c.is_visible_in_tree(): out.append(str(c.text))
		if c is Control and c.get_script() == TouchButtonS and c.is_visible_in_tree(): out.append(str(c.text) + " " + str(c.sub_text))
		_labels(c, out)
	return out

func _scan_money(where: String) -> void:
	for t in _labels(app.ui_layer):
		var low: String = str(t).to_lower()
		for w in MONEY_WORDS:
			var hit := false
			if w.length() <= 3 and w.to_utf8_buffer().size() == w.length():
				for tok in low.split(" ", false): if tok == w: hit = true
			elif low.find(w) >= 0: hit = true
			if hit: report.money_controls.append({"screen": where, "text": t, "word": w})

func _run() -> void:
	app = root.get_node("App")
	var svc = root.get_node_or_null("Services")
	report.services = {"autoload": svc != null, "mode": str(svc.get("mode")) if svc else "absent"}
	if svc and svc.has_method("diagnostics"): report.services["diagnostics_live"] = svc.diagnostics().get("live", {})
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	report.view = root.get_visible_rect().size
	report.window = DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	await _shot("1_menu")
	_scan_money("menu")
	root.get_node("Events").cmd_open_screen.emit(&"round_select")
	await _frames(4)
	await _shot("2_round_select")
	_scan_money("round_select")
	_measure_tiles()
	root.get_node("Events").cmd_open_screen.emit(&"menu")
	await _frames(3)
	var set_btn: Control = null
	for b in _buttons(app.ui_layer):
		if str(b.text) == load("res://src/ui/ui_text.gd").t("ui.settings"): set_btn = b
	if set_btn:
		set_btn.tapped.emit()
		await _frames(3)
		await _shot("3_settings")
		_scan_money("settings")
	root.get_node("Events").cmd_start_round.emit("r01")
	await _frames(6)
	var sim = app.battle.sim if app.battle else null
	await _shot("4_r01_t00")
	_scan_money("battle_hud")
	if sim:
		var bot = BotS.new(1, 7)   # casual policy: a plausible first-time player, not a human
		for mark in [30.0, 60.0]:
			while sim.t < mark and not sim.ended:
				bot.act(sim, 1.0 / 60.0); sim.step(1.0 / 60.0)
			await _shot("5_r01_t%02d" % int(mark))
		report["r01_at_60s"] = {"t": sim.t, "kills": sim.kills, "deployed": sim.stats.deployed, "workers": sim.workers,
			"player_base": sim.player_base.hp, "enemy_base": sim.enemy_base.hp, "enemy_base_max": sim.enemy_base.hp_max}
		while not sim.ended and sim.t < 900.0:
			bot.act(sim, 1.0 / 60.0); sim.step(1.0 / 60.0)
		await create_timer(1.6).timeout
		await _shot("6_result")
		_scan_money("result")
		report["r01_end"] = {"t": sim.t, "won": sim.won}
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join(tag + "_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[capture] ", JSON.stringify({"tag": tag, "shots": report.shots.size(), "money": report.money_controls.size(), "services": report.services}))
	quit(0)

## Name block geometry inside each visible round tile, using TouchButton's own drawing rules
## (name centred at size.y/2 when there is no icon, 14 px line pitch) and round_select's overlay
## (big number centred at y=16, stars centred at size.y-30, radius 5.5).
func _measure_tiles() -> void:
	var f: Font = UiStyle.font(&"ui")
	for b in _buttons(app.ui_layer):
		if int(b.get("wrap_lines")) < 2: continue
		var fl: Dictionary = UiStyle.fit_lines(str(b.text), b.size.x - 6, b.font_size, int(b.wrap_lines))
		var n: int = (fl.lines as PackedStringArray).size()
		var fh: float = f.get_height(b.font_size)
		var name_y: float = b.size.y / 2.0
		var top: float = name_y - (n - 1) * 14.0 / 2.0 - fh / 2.0
		var bottom: float = name_y + (n - 1) * 14.0 / 2.0 + fh / 2.0
		var num_bottom: float = 16.0 + UiStyle.font(&"bold").get_height(UiStyle.FONT_L) / 2.0
		var star_top: float = b.size.y - 30.0 - 5.5
		var widest := 0.0
		for l in fl.lines: widest = maxf(widest, UiStyle.text_width(l, b.font_size))
		report.tiles.append({"text": b.text, "lines": Array(fl.lines), "truncated": fl.truncated, "tile": [b.size.x, b.size.y],
			"block_top": top, "block_bottom": bottom, "number_bottom": num_bottom, "star_top": star_top, "widest_px": widest,
			"fits": top >= num_bottom and bottom <= star_top and widest <= b.size.x - 6 and not fl.truncated, "disabled": b.disabled})
