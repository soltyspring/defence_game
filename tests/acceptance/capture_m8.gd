extends SceneTree
## 07-qa M8 visible capture (secondary monitor only, via tools/build/visible_launch.ps1 -ProjectPath).
##   -Script res://tests/acceptance/capture_m8.gd -UserArgs '--shot-dir=<abs>','--locale=ko','--tag=ko_2x_notch','--insets=34,0,34,0'
## Screens: menu (title), upgrade panel opened from the menu, r01 HUD after 2 real seconds (QA-J3 worker
## vs soldier card), r01 HUD after 30 real seconds with the casual bot driving the sim at normal speed
## (QA-J1 framing measure). Writes <tag>_m8_report.json:
##   title: drawn title text, width at its font, safe width, fits; projected width of the Q3 working title
##   upgrade: every buy button disabled?, status/notice text, money words found
##   j3: worker vs soldier button shape/fill/size, resource names visible in hud_top
##   j1: per frame, % of screen area covered by unit/base sprites (union, logical px) and lane band height %
## Owner: 07-qa.

const TouchButtonS := preload("res://src/ui/touch_button.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const Q3_TITLE_EN := "Bakery Knights: Mold Defense"
const Q3_TITLE_KO := "빵집 기사단: 곰팡이 디펜스"
const MONEY := ["광고", "구매", "상점", "결제", "보석", "젬", "패키지", "광고 제거", "ads", "shop", "store", "purchase", "gem", "gems", "iap", "remove ads", "restore"]

var shot_dir := ""
var tag := "run"
var insets := Vector4.ZERO
var app: Node
var rep := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a.begins_with("--locale="): UiText.load_locale(a.get_slice("=", 1))
		elif a == "--force-text-title" and ResourceLoader.exists("res://src/ui/title_block.gd"): load("res://src/ui/title_block.gd").force_text = true
		elif a.begins_with("--insets="):
			var p := a.get_slice("=", 1).split(",")
			insets = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://qa07")
		save.path = "user://qa07/m8_save.json"
		save.progress = save.fresh()
		save.progress.unlocked_round = 3
		save.progress.coins = 250
		save.progress.stars = {"r01": 3, "r02": 1}
		save.save_progress()
	if insets != Vector4.ZERO: SafeArea.override_insets = insets
	_run.call_deferred()

func _frames(n := 3) -> void:
	for i in n: await process_frame

func _shot(name: String) -> void:
	await _frames(3)
	if shot_dir == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.get_texture().get_image().save_png(shot_dir.path_join("%s_%s.png" % [tag, name]))

func _mask() -> void:
	if insets == Vector4.ZERO: return
	var cl := CanvasLayer.new(); cl.layer = 128; root.add_child(cl)
	var v := root.get_visible_rect().size
	for r in [Rect2(0, 0, insets.x, v.y), Rect2(v.x - insets.z, 0, insets.z, v.y)]:
		if r.size.x <= 0: continue
		var c := ColorRect.new(); c.color = Color.BLACK; c.position = r.position; c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(c)

func _walk(n: Node, out: Array) -> Array:
	for c in n.get_children():
		out.append(c)
		_walk(c, out)
	return out

func _texts(n: Node) -> Array:
	var out := []
	for c in _walk(n, []):
		if not (c is CanvasItem) or not c.is_visible_in_tree(): continue
		if c is Label or c is Button: out.append(str(c.text))
		elif c.get_script() == TouchButtonS: out.append(str(c.text) + " " + str(c.sub_text))
		for k in ["status_text", "title", "dim_reason"]:
			if k in c and c.get(k) is String and str(c.get(k)) != "": out.append(str(c.get(k)))
	return out

func _money(n: Node) -> Array:
	var hits := []
	for t in _texts(n):
		var low: String = str(t).to_lower()
		for w in MONEY:
			var hit := false
			if w.length() <= 4 and w.to_utf8_buffer().size() == w.length():
				for tok in low.replace(":", " ").split(" ", false): if tok == w: hit = true
			elif low.find(w) >= 0: hit = true
			if hit: hits.append({"text": t, "word": w})
	return hits

const TERMS := ["밀가루", "반죽", "보급", "Flour", "Dough", "Supply"]
func _terms(n: Node) -> Array:
	var out := []
	for t in _texts(n):
		for w in TERMS:
			if str(t).find(w) >= 0: out.append({"term": w, "text": t})
	return out

func _find(n: Node, suffix: String) -> Node:
	for c in _walk(n, []):
		if c.get_script() and str(c.get_script().resource_path).ends_with(suffix): return c
	return null

func _safe() -> Rect2:
	var v := root.get_visible_rect().size
	return Rect2(insets.x, insets.y, v.x - insets.x - insets.z, v.y - insets.y - insets.w)

func _run() -> void:
	app = root.get_node("App")
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	_mask()
	await _frames(6)
	root.size_changed.emit()
	rep.view = root.get_visible_rect().size
	rep.insets = [insets.x, insets.y, insets.z, insets.w]
	# ---- title (menu draws ui.title at FONT_XL bold, centred in the safe area)
	await _shot("1_menu")
	var sw := _safe().size.x
	var cur := UiText.t("ui.title")
	rep.title = {"drawn": cur, "width": UiStyle.text_width(cur, UiStyle.FONT_XL, &"bold"), "safe_w": sw,
		"q3_present": cur.find("Bakery Knights") >= 0 or cur.find("빵집 기사단") >= 0,
		"projected_en_w": UiStyle.text_width(Q3_TITLE_EN, UiStyle.FONT_XL, &"bold"), "projected_ko_w": UiStyle.text_width(Q3_TITLE_KO, UiStyle.FONT_XL, &"bold")}
	rep.title.fits = rep.title.width <= sw
	if ResourceLoader.exists("res://src/ui/title_block.gd"):
		var TB = load("res://src/ui/title_block.gd")
		var lines := []
		for ln in TB.last_lines:
			var txt := str(ln[0]) if ln is Array else str(ln)
			var sz := int(ln[1]) if ln is Array and ln.size() > 1 else UiStyle.FONT_XL
			lines.append({"text": txt, "size": sz, "width": UiStyle.text_width(txt, sz, &"bold"), "fits": UiStyle.text_width(txt, sz, &"bold") <= sw})
		rep.title_block = {"mode": str(TB.last_mode), "force_text": bool(TB.force_text), "lines": lines, "text": TB.title_text()}
	rep.terms = {}
	rep.money_menu = _money(app.ui_layer)
	# ---- upgrade panel
	var menu := _find(app.ui_layer, "ui/main_menu.gd")
	if menu and menu.has_method("open_upgrades"):
		menu.open_upgrades()
		await _frames(4)
		await _shot("2_upgrades")
		var up = menu.get("upgrade_panel")
		var btns := []
		for b in up.get("buy_buttons"):
			if b.is_visible_in_tree(): btns.append({"text": str(b.text), "disabled": bool(b.disabled), "truncated": bool(b.get("last_text_truncated"))})
		var outside := 0
		for c in _walk(up, []):
			if c.get_script() == TouchButtonS and c.is_visible_in_tree() and not _safe().grow(0.5).encloses(c.get_global_rect()): outside += 1
		rep.upgrade = {"purchase_available": up.purchase_available() if up.has_method("purchase_available") else null,
			"status_text": str(up.get("status_text")), "buttons": btns, "all_disabled": btns.all(func(x): return x.disabled),
			"buttons_outside_safe": outside, "money_words": _money(up)}
		rep.terms["upgrades"] = _terms(up)
		if up.has_method("close"): up.close()
		else: up.hide()
		await _frames(3)
	else:
		rep.upgrade = "NOT_FOUND"
	# ---- r01 HUD, real time
	root.get_node("Events").cmd_start_round.emit("r01")
	await create_timer(2.0).timeout
	await _shot("3_r01_hud_t02")
	var hud := _find(app.ui_layer, "ui/hud.gd")
	if hud:
		var w: Control = hud.get("btn_worker")
		var c0: Control = hud.card_buttons[0] if hud.card_buttons.size() > 0 else null
		rep.j3 = {"worker": {"text": str(w.text), "shape": str(w.get("shape")), "fill": str(w.get("fill")), "size": [w.size.x, w.size.y], "sub": str(w.sub_text)},
			"soldier": {"text": str(c0.text), "shape": str(c0.get("shape")), "fill": str(c0.get("fill")), "size": [c0.size.x, c0.size.y], "sub": str(c0.sub_text)} if c0 else null,
			"hud_texts": _texts(hud).filter(func(t): return t.find(UiText.t("res.supply")) >= 0 or t.find(UiText.t("res.energy")) >= 0),
			"res_supply": UiText.t("res.supply"), "res_energy": UiText.t("res.energy"),
			"tut_buy_worker": UiText.t("tut_buy_worker")}
		rep.money_hud = _money(hud)
		rep.terms["hud"] = _terms(hud)
		rep.terms["res_supply"] = UiText.t("res.supply")
	# ---- J1: casual bot at normal speed (driven per rendered frame with the real frame delta)
	var sim = app.battle.sim if app.battle else null
	rep.j1 = []
	if sim:
		var bot = BotS.new(1, 7)
		var t0 := Time.get_ticks_msec()
		var next := 5.0
		var last := Time.get_ticks_msec()
		while (Time.get_ticks_msec() - t0) / 1000.0 < 31.0:
			await process_frame
			var now := Time.get_ticks_msec()
			bot.act(sim, (now - last) / 1000.0)
			last = now
			if (now - t0) / 1000.0 >= next:
				rep.j1.append(_measure(sim))
				next += 5.0
		await _shot("4_r01_hud_t30")
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join(tag + "_m8_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(rep, "  ")); f.close()
	print("[m8] ", JSON.stringify({"tag": tag, "title": rep.get("title"), "upgrade_all_disabled": rep.upgrade.get("all_disabled") if rep.upgrade is Dictionary else null}))
	quit(0)

## Screen-area share of game objects (logical px): union of unit + hero + base sprite rects that are
## inside the camera view, rasterised on a 2-px grid; plus the lane band (top of the tallest visible
## unit sprite .. bottom of the ground strip) as % of view height.
func _measure(sim) -> Dictionary:
	var view: Node2D = app.battle.view
	var atlas = root.get_node("Atlas")
	var v := root.get_visible_rect().size
	var cam_x: float = float(view.cam_x)
	var left := cam_x - v.x / 2.0
	var gy: float = float(view.ground_y)
	var rects := []
	var units: Array = []
	units.append_array(sim.players); units.append_array(sim.enemies)
	if sim.hero_respawn <= 0.0: units.append(sim.hero)
	var top := gy
	for u in units:
		if u.dying: continue
		var fr: Dictionary = atlas.anim_frame(str(u.def.get("anim_set", u.id)), "walk", 0.0)
		var sz: Vector2 = (fr.rect as Rect2).size if not fr.is_empty() else Vector2(12, 14)
		var r := Rect2(u.x - left - sz.x / 2.0, gy + u.lane_y - sz.y, sz.x, sz.y)
		if r.end.x < 0 or r.position.x > v.x: continue
		rects.append(r)
		top = minf(top, r.position.y)
	for b in [sim.player_base, sim.enemy_base]:
		var r := Rect2(float(b.x) - left - 48.0, gy - 112.0, 96.0, 112.0)
		if r.end.x >= 0 and r.position.x <= v.x: rects.append(r)
	var cell := 2
	var covered := {}
	for r in rects:
		for y in range(maxi(0, int(r.position.y) / cell), mini(int(v.y) / cell, int(r.end.y) / cell + 1)):
			for x in range(maxi(0, int(r.position.x) / cell), mini(int(v.x) / cell, int(r.end.x) / cell + 1)):
				covered[y * 1000 + x] = true
	var total := (int(v.x) / cell) * (int(v.y) / cell)
	return {"sim_t": snappedf(sim.t, 0.1), "objects_on_screen": rects.size(), "object_area_pct": snappedf(100.0 * covered.size() / total, 0.1),
		"lane_band_pct": snappedf(100.0 * ((gy + 12.0) - top) / v.y, 0.1), "enemies_on_screen": sim.enemies.filter(func(e): return not e.dying and e.x - left >= 0 and e.x - left <= v.x).size()}
