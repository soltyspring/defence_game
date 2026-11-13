extends "res://src/ui/ui_screen.gd"

var selected: Array = []
var roster: Array = []
var tiles: Array = []
var back: Control
var confirm: Control
var message := ""

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	selected = Save.selected_loadout().duplicate()
	roster = Content.available_roster(100)
	back = make_button(UiText.t("ui.back"), _back)
	confirm = make_button(UiText.t("roster.save"), _save)
	for id in roster:
		var button := make_button(UiText.name_of("unit", id), _toggle.bind(id))
		button.font_size = UiStyle.FONT_S
		button.icon = UiStyle.ui_icon("card_" + str(id))
		button.wrap_lines = 2
		tiles.append(button)
	_refresh()

func _toggle(id: String) -> void:
	message = UiText.t(str(Content.units[id].get("desc_key", "")))
	if selected.has(id): selected.erase(id)
	elif selected.size() < 5: selected.append(id)
	else: message = UiText.t("roster.full")
	_refresh()

func _refresh() -> void:
	for i in roster.size():
		var id: String = roster[i]
		var unit: Dictionary = Content.units[id]
		var locked := int(unit.get("unlock_round", 1)) > Save.round_reach()
		tiles[i].disabled = locked
		tiles[i].badge = str(selected.find(id) + 1) if selected.has(id) else ""
		tiles[i].fill = UiStyle.C_ACCENT.darkened(0.45) if selected.has(id) else UiStyle.C_PANEL_LIGHT
		tiles[i].sub_text = "R%d" % int(unit.unlock_round) if locked else str(int(unit.cost))
		if not locked: tiles[i].tooltip_text = UiText.t(str(unit.get("desc_key", "")))
	confirm.disabled = selected.is_empty()
	queue_redraw()

func _save() -> void:
	if Save.set_loadout(selected):
		_back()
	else:
		message = UiText.t("roster.failed")
		queue_redraw()

func _back() -> void:
	emit_cmd_deferred(&"cmd_open_screen", [&"round_select"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and claim_back(): _back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _layout() -> void:
	if back == null: return
	var t := maxf(40, target)
	place(back, Rect2(safe.position + Vector2(6,6), Vector2(76,t)))
	place(confirm, Rect2(safe.end.x - 106,safe.position.y + 6,100,t))
	var gap := 8.0
	var width := floorf((safe.size.x - 24 - 4*gap)/5)
	var height := floorf((safe.size.y - t - 76 - gap)/2)
	for i in tiles.size():
		place(tiles[i], Rect2(safe.position.x+12+(i%5)*(width+gap),safe.position.y+t+28+(i/5)*(height+gap),width,height))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,view),UiStyle.C_BG)
	UiStyle.draw_text_centered(self,UiText.t("roster.heading") % selected.size(),Vector2(safe.get_center().x,safe.position.y+26),UiStyle.FONT_L)
	UiStyle.draw_text_centered(self,UiText.t("roster.hint"),Vector2(safe.get_center().x,safe.position.y+maxf(40,target)+16),UiStyle.FONT_S)
	UiStyle.draw_text_centered(self,message,Vector2(safe.get_center().x,safe.end.y-18),UiStyle.FONT_S)
