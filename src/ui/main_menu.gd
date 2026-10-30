extends "res://src/ui/ui_screen.gd"
## Main menu. Owner: 04-client. Emits cmd_start_round (continue), cmd_open_screen(&"round_select").

var btn_play: Control
var btn_select: Control
var btn_settings: Control
var settings_panel: Control
var quit_layer: Control
var quit_buttons: Array = []
var _notice := ""

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # menu owns the whole screen
	btn_play = make_button(UiText.t("ui.play"), _on_play)
	btn_play.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_play.font_size = UiStyle.FONT_L
	btn_select = make_button(UiText.t("ui.select_round"), _on_select)
	btn_settings = make_button(UiText.t("ui.settings"), _on_settings)
	settings_panel = SettingsPanel.new()
	settings_panel.hide()
	add_child(settings_panel)
	quit_layer = preload("res://src/ui/dim_layer.gd").new()
	quit_layer.title = UiText.t("ui.quit_confirm")
	quit_layer.hide()
	add_child(quit_layer)
	for d in [["ui.quit", func(): get_tree().quit()], ["ui.cancel", func(): quit_layer.hide()]]:
		var b: Control = TouchButton.new()
		b.text = UiText.t(d[0])
		b.tapped.connect(d[1])
		quit_layer.add_child(b)
		quit_buttons.append(b)
	var s := autoload("Save")
	if s != null and bool(s.get("recovered")):
		_notice = UiText.t("ui.save_recovered")
	_refresh_labels()

func _bus_links() -> Array:
	return [[&"progress_changed", func(_p): _refresh_labels()]]

## Round id to start with "play": first unlocked round without stars, else the last unlocked.
func continue_round_id() -> String:
	var list := _round_list()
	if list.is_empty():
		return ""
	var p := progress()
	var unlocked := int(p.get("unlocked_round", 1))
	var stars: Dictionary = p.get("stars", {})
	var pick := str(list[0].id)
	for i in mini(unlocked, list.size()):
		pick = str(list[i].id)
		if int(stars.get(pick, 0)) == 0:
			return pick
	return pick

func _round_list() -> Array:
	var c := autoload("Content")
	if c != null and c.has_method("get_round_list"):
		return c.get_round_list()
	return []

func _refresh_labels() -> void:
	var p := progress()
	var started := int(p.get("unlocked_round", 1)) > 1 or not (p.get("stars", {}) as Dictionary).is_empty()
	btn_play.text = UiText.t("ui.continue") if started else UiText.t("ui.play")
	btn_play.queue_redraw()

func _on_play() -> void:
	var id := continue_round_id()
	if id == "":
		emit_cmd(&"cmd_open_screen", [&"round_select"])
	else:
		emit_cmd(&"cmd_start_round", [id])

func _on_select() -> void:
	emit_cmd(&"cmd_open_screen", [&"round_select"])

func _on_settings() -> void:
	settings_panel.open(bus, progress().get("settings", {}), view, safe, target)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and quit_layer != null:
		if settings_panel.visible:
			return
		quit_layer.visible = not quit_layer.visible

func _layout() -> void:
	if btn_play == null:
		return
	var bw := clampf(safe.size.x * 0.34, 180.0, 240.0)
	var bh := maxf(target, 44.0)
	var cx := safe.get_center().x
	var y := safe.position.y + safe.size.y * 0.50
	place(btn_play, Rect2(cx - bw / 2, y, bw, bh + 6))
	place(btn_select, Rect2(cx - bw / 2, y + bh + 14, bw / 2 - 3, bh))
	place(btn_settings, Rect2(cx + 3, y + bh + 14, bw / 2 - 3, bh))
	place(quit_layer, Rect2(Vector2.ZERO, view))
	quit_layer.title_y = safe.get_center().y - 30
	for i in quit_buttons.size():
		place(quit_buttons[i], Rect2(cx - 124 + i * 128, safe.get_center().y, 120, bh))
	if settings_panel.visible:
		settings_panel.open(bus, settings_panel.settings, view, safe, target)

func _draw() -> void:
	# Background placeholder until 03 ships menu art: sky gradient bands + pixel hills.
	var h := view.y
	var bands := [Color(0.14, 0.18, 0.32), Color(0.18, 0.24, 0.40), Color(0.24, 0.32, 0.48), Color(0.32, 0.40, 0.52)]
	for i in bands.size():
		draw_rect(Rect2(0, i * h * 0.15, view.x, h * 0.15 + 1), bands[i])
	draw_rect(Rect2(0, h * 0.6, view.x, h * 0.4), Color(0.20, 0.36, 0.22))
	var x := 0.0
	while x < view.x:
		var hh := 18.0 + 14.0 * absf(sin(x * 0.013)) + 8.0 * absf(sin(x * 0.041))
		draw_rect(Rect2(x, h * 0.6 - hh, 8, hh), Color(0.16, 0.30, 0.20))
		x += 8
	draw_rect(Rect2(0, h * 0.82, view.x, h * 0.18), Color(0.36, 0.27, 0.18))
	var tc := Vector2(safe.get_center().x, safe.position.y + safe.size.y * 0.24)
	UiStyle.draw_text_centered(self, UiText.t("ui.title"), tc, UiStyle.FONT_XL, UiStyle.C_GOLD, true, &"bold")
	UiStyle.draw_text_centered(self, UiText.t("ui.subtitle"), tc + Vector2(0, 32), UiStyle.FONT_M, UiStyle.C_TEXT)
	var p := progress()
	if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(safe.position.x + 14, safe.position.y + 14)):
		UiStyle.draw_glyph(self, &"coin", Vector2(safe.position.x + 14, safe.position.y + 14), 5)
	UiStyle.draw_number(self, str(int(p.get("coins", 0))), Vector2(safe.position.x + 25, safe.position.y + 14), UiStyle.FONT_M, UiStyle.C_GOLD, -1, &"bold")
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	UiStyle.draw_number(self, "v" + ver, Vector2(safe.end.x - 6, safe.end.y - 10), UiStyle.NUM_S, UiStyle.C_TEXT_DIM, 1)
	if _notice != "":
		UiStyle.draw_text_centered(self, _notice, Vector2(safe.get_center().x, safe.end.y - 24), UiStyle.FONT_S, UiStyle.C_ACCENT)
