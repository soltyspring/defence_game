extends RefCounted
## Minimal functional fallback UI used ONLY when 04's scenes/ui/*.tscn are absent.
## Talks exclusively through the Events bus, exactly like 04's UI must. Owner: 02-engine.

static func create(name: StringName, params: Dictionary) -> Control:
	var root := Control.new()
	root.name = "Fallback_" + str(name)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match name:
		&"menu": _menu(root)
		&"round_select": _round_select(root)
		&"hud": root.set_script(preload("res://src/gameplay/fallback_hud.gd"))
		&"result": _result(root, params)
	return root

static func _btn(text: String, cb: Callable, min_size := Vector2(120, 32)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

static func _panel_bg(root: Control, alpha := 0.75) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1, alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

static func _center_box(root: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	cc.add_child(vb)
	return vb

static func _label(text: String, size := 12, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l

## Same title source as the window title (App._apply_window_title): 04 UiText `ui.title` in the current locale.
static func _title() -> String:
	if ResourceLoader.exists("res://src/ui/ui_text.gd"):
		var ut = load("res://src/ui/ui_text.gd")
		if ut and ut.has_method("t"):
			var s := str(ut.t("ui.title", ""))
			if s != "": return s
	return "Bakery Knights"

static func _menu(root: Control) -> void:
	_panel_bg(root, 1.0)
	var vb := _center_box(root)
	vb.add_child(_label(_title(), 28, Color("f2d16b")))
	vb.add_child(_label("(engine fallback menu)", 8, Color(0.7, 0.7, 0.8)))
	var coins := int(Save.progress.get("coins", 0))
	vb.add_child(_label("Coins: %d" % coins, 10))
	vb.add_child(_btn("Play", func(): Events.cmd_open_screen.emit(&"round_select"), Vector2(160, 40)))
	var unlocked := int(Save.progress.unlocked_round)
	var cont_idx := mini(unlocked, Content.round_order.size()) - 1
	if cont_idx >= 0:
		var rid: String = Content.round_order[cont_idx]
		vb.add_child(_btn("Continue: " + str(Content.get_round(rid).name), func(): Events.cmd_start_round.emit(rid), Vector2(160, 32)))

static func _round_select(root: Control) -> void:
	_panel_bg(root, 1.0)
	var vb := _center_box(root)
	vb.add_child(_label("Select Round", 18, Color("f2d16b")))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	var i := 0
	for r in Content.get_round_list():
		var rid: String = r.id
		var stars := int(Save.progress.stars.get(rid, 0))
		var unlocked := Save.is_unlocked(i)
		var txt := "%d\n%s\n%s" % [r.index, str(r.name), ("★".repeat(stars) + "☆".repeat(3 - stars)) if unlocked else "LOCKED"]
		var b := _btn(txt, func(): Events.cmd_start_round.emit(rid), Vector2(96, 56))
		b.disabled = not unlocked
		b.add_theme_font_size_override("font_size", 9)
		grid.add_child(b)
		i += 1
	vb.add_child(_btn("Back", func(): Events.cmd_open_screen.emit(&"menu"), Vector2(100, 28)))

static func _result(root: Control, r: Dictionary) -> void:
	_panel_bg(root, 0.6)
	var vb := _center_box(root)
	var won := bool(r.get("won", false))
	vb.add_child(_label("VICTORY!" if won else "DEFEAT", 28, Color("f2d16b") if won else Color("e5534b")))
	var stars := int(r.get("stars", 0))
	vb.add_child(_label("★".repeat(stars) + "☆".repeat(3 - stars), 22, Color("f2d16b")))
	vb.add_child(_label("Time %.0fs   Kills %d   Coins +%d%s" % [float(r.get("time", 0)), int(r.get("kills", 0)), int(r.get("coins", 0)),
		"   (first clear)" if r.get("first_clear", false) else ""], 10))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	hb.add_child(_btn("Retry", func(): Events.cmd_retry.emit(), Vector2(90, 32)))
	if won and str(r.get("next_round_id", "")) != "":
		hb.add_child(_btn("Next", func(): Events.cmd_next_round.emit(), Vector2(90, 32)))
	hb.add_child(_btn("Rounds", func(): Events.cmd_open_screen.emit(&"round_select"), Vector2(90, 32)))
