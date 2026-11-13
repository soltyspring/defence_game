extends "res://src/ui/ui_screen.gd"
## Loadout (편성): pick up to 5 of the unlocked unit types; they become the battle's cards in slot order.
## Two ways in: the 편성 button on round select (saves and returns), and a round tap once more than five types are
## unlocked (출전 준비: saves and starts that round). Top: the five slots (tap one to take the unit out).
## Below: every type as a card (tap to put it in the first free slot or take it out). Bottom: the last card's role.

## Round to start after choosing (set by round_select before opening this screen); "" = plain 편성 from the menu.
static var pending_round := ""

var selected: Array = []
var roster: Array = []
var tiles: Array = []            # one card per unit type (10)
var slots: Array = []            # the five deck slots
var back: Control
var confirm: Control
var message := ""
var focus_id := ""
var round_id := ""
var _slot_label_y := 0.0
var _grid_label_y := 0.0

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	round_id = pending_round
	pending_round = ""
	selected = Save.selected_loadout().duplicate()
	roster = Content.available_roster(100)
	back = make_button(UiText.t("ui.back"), _back)
	confirm = make_button(UiText.t("roster.start") if round_id != "" else UiText.t("roster.save"), _save)
	for i in 5:
		var slot = make_button("", _take_out.bind(i))
		slot.font_size = UiStyle.FONT_S
		slots.append(slot)
	for id in roster:
		var button = make_button(UiText.name_of("unit", id), _toggle.bind(id))
		button.font_size = UiStyle.FONT_S
		button.icon = UiStyle.ui_icon("card_" + str(id))
		button.wrap_lines = 1
		tiles.append(button)
	if not selected.is_empty(): focus_id = str(selected[0])
	_refresh()

func _toggle(id: String) -> void:
	focus_id = id
	message = ""
	if selected.has(id): selected.erase(id)
	elif selected.size() < 5: selected.append(id)
	else: message = UiText.t("roster.full")
	_refresh()

func _take_out(i: int) -> void:
	if i < selected.size():
		focus_id = str(selected[i])
		selected.remove_at(i)
		message = ""
		_refresh()

func _refresh() -> void:
	var reach: int = Save.round_reach()
	for i in roster.size():
		var id: String = roster[i]
		var unit: Dictionary = Content.units[id]
		var locked := int(unit.get("unlock_round", 1)) > reach
		var on := selected.has(id)
		tiles[i].disabled = locked
		tiles[i].badge = str(selected.find(id) + 1) if on else ""
		tiles[i].fill = UiStyle.C_BG.lightened(0.1) if on else UiStyle.C_PANEL_LIGHT     # taken: dark, its slot number shows
		tiles[i].sub_text = "R%d" % int(unit.unlock_round) if locked else str(int(unit.cost))
		if not locked: tiles[i].tooltip_text = UiText.t(str(unit.get("desc_key", "")))
	for i in 5:
		var slot = slots[i]
		if i < selected.size():
			var id := str(selected[i])
			slot.text = UiText.name_of("unit", id)
			slot.sub_text = str(int(Content.units[id].cost))
			slot.icon = UiStyle.ui_icon("card_" + id)
			slot.fill = UiStyle.C_ACCENT.darkened(0.3)
			slot.disabled = false
		else:
			slot.text = UiText.t("roster.empty")
			slot.sub_text = ""
			slot.icon = null
			slot.fill = UiStyle.C_BG.lightened(0.08)
			slot.disabled = true
		slot.badge = str(i + 1)
	confirm.disabled = selected.is_empty()
	queue_redraw()

func _save() -> void:
	if selected.is_empty(): return
	if not Save.set_loadout(selected):
		message = UiText.t("roster.failed")
		queue_redraw()
		return
	if round_id != "":
		emit_cmd_deferred(&"cmd_start_round", [round_id])
	else:
		_back()

func _back() -> void:
	emit_cmd_deferred(&"cmd_open_screen", [&"round_select"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and claim_back(): _back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

## Rows: top bar | slot label | 5 slots | card label | 2 rows of 5 cards | role line.
func _layout() -> void:
	if back == null: return
	var t := maxf(40, target)
	var top := safe.position.y + 6
	place(back, Rect2(safe.position.x + 6, top, 76, t))
	place(confirm, Rect2(safe.end.x - 106, top, 100, t))
	var gap := 6.0
	var x0 := safe.position.x + 12
	var width := floorf((safe.size.x - 24 - 4 * gap) / 5)
	var label := 16.0
	var info := 22.0
	var free := safe.size.y - (t + 6) - 2 * label - info - 3 * gap
	var slot_h := floorf(maxf(40.0, free * 0.36))
	var card_h := floorf(maxf(40.0, (free - slot_h) / 2.0))
	_slot_label_y = top + t + label * 0.5 + 1
	var y := top + t + label
	for i in 5:
		place(slots[i], Rect2(x0 + i * (width + gap), y, width, slot_h))
	y += slot_h + gap
	_grid_label_y = y + label * 0.5
	y += label
	for i in tiles.size():
		place(tiles[i], Rect2(x0 + (i % 5) * (width + gap), y + (i / 5) * (card_h + gap), width, card_h))

func _info_line() -> String:
	if message != "": return message
	if focus_id == "" or not Content.units.has(focus_id): return UiText.t("roster.hint")
	var u: Dictionary = Content.units[focus_id]
	if int(u.get("unlock_round", 1)) > Save.round_reach():
		return UiText.t("roster.unlock") % int(u.unlock_round)
	return "%s · %s · %s" % [UiText.name_of("unit", focus_id), UiText.t(str(u.get("desc_key", ""))),
		UiText.t("roster.stats") % [int(u.hp), int(u.atk), int(u.range)]]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), UiStyle.C_BG)
	var heading := UiText.t("roster.heading") % selected.size()
	if round_id != "":
		heading = UiText.t("roster.prep") % int(Content.get_round(round_id).get("index", 0))
	UiStyle.draw_text_centered(self, heading, Vector2(safe.get_center().x, safe.position.y + 26), UiStyle.FONT_L)
	var left := safe.position.x + 14
	UiStyle.draw_text_left(self, UiText.t("roster.slots") % selected.size(), Vector2(left, _slot_label_y), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	UiStyle.draw_text_left(self, UiText.t("roster.units"), Vector2(left, _grid_label_y), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	UiStyle.draw_text_centered(self, _info_line(), Vector2(safe.get_center().x, safe.end.y - 12), UiStyle.FONT_S)
