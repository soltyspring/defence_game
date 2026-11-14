extends "res://src/ui/ui_screen.gd"
## 출전 준비: up to 5 unit types (battle cards in slot order) and up to 3 energy skills, chosen right before a battle.
## Ways in: a round tap (or 이어하기) once there is a choice to make (it saves and starts that round), or the 편성 card
## in 기사단 본부 at any time (it only saves). Unit types:
## five by R6, then one more at R30/40/50/60/70 (data/units/roster_expansion.json). Two tabs, 유닛 and 스킬, same layout: the slots on top (tap one to take it
## out), every choice below as a card (tap to put it in or take it out), the last card's details on the bottom line.

## Round to start after choosing (set by round_select before opening this screen); "" = plain 편성 from the menu.
static var pending_round := ""
## Screen that 뒤로 returns to (set by the opener; reset after each open). The hall and 이어하기 come back to the menu.
static var back_to: StringName = &"round_select"

## True once the player has more unit types than slots (from R30) or more skills than skill slots.
static func needs_choice(content, save) -> bool:
	if content == null or save == null or not content.has_method("available_roster"): return false
	var reach: int = save.round_reach()
	var n: int = save.owned_roster().size() if save.has_method("owned_roster") else content.available_roster(reach).size()
	return n > 5 or content.available_skills(reach).size() > 3

var selected: Array = []
var roster: Array = []
var tiles: Array = []            # one card per unit type (10)
var slots: Array = []            # the five deck slots
var skill_sel: Array = []
var skill_list: Array = []
var skill_tiles: Array = []      # one card per skill (7)
var skill_slots: Array = []      # the three skill slots
var tab := "units"
var tab_units: Control
var tab_skills: Control
var back: Control
var confirm: Control
var message := ""
var focus_id := ""
var focus_skill := ""
var round_id := ""
var back_target: StringName = &"round_select"
var _slot_label_y := 0.0
var _grid_label_y := 0.0

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	round_id = pending_round
	pending_round = ""
	back_target = back_to
	back_to = &"round_select"
	selected = Save.selected_loadout().duplicate()
	roster = Content.available_roster(100)
	skill_list = Content.available_skills(100)
	skill_sel = Save.selected_skills().duplicate()
	if skill_sel.is_empty():      # nothing chosen yet: start from what this round would give (the old default)
		var r: Dictionary = Content.get_round(round_id) if round_id != "" else {}
		var reach: int = Save.round_reach()
		for s in (Content.round_skills(r) if not r.is_empty() else skill_list):
			if skill_sel.size() < 3 and int(Content.skills[s].get("unlock_round", 1)) <= reach: skill_sel.append(str(s))
	back = make_button(UiText.t("ui.back"), _back)
	confirm = make_button(UiText.t("roster.start") if round_id != "" else UiText.t("roster.save"), _save)
	tab_units = make_button(UiText.t("roster.tab_units"), _set_tab.bind("units"))
	tab_skills = make_button(UiText.t("roster.tab_skills"), _set_tab.bind("skills"))
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
	for i in 3:
		var slot = make_button("", _take_out_skill.bind(i))
		slot.font_size = UiStyle.FONT_S
		skill_slots.append(slot)
	for id in skill_list:
		var button = make_button(UiText.name_of("skill", id), _toggle_skill.bind(id))
		button.font_size = UiStyle.FONT_S
		button.icon = UiStyle.ui_icon("icon_" + str(id))
		button.wrap_lines = 1
		skill_tiles.append(button)
	if not selected.is_empty(): focus_id = str(selected[0])
	if not skill_sel.is_empty(): focus_skill = str(skill_sel[0])
	_set_tab("units")

func _set_tab(t: String) -> void:
	tab = t
	message = ""
	for c in slots + tiles: c.visible = tab == "units"
	for c in skill_slots + skill_tiles: c.visible = tab == "skills"
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

func _toggle_skill(id: String) -> void:
	focus_skill = id
	message = ""
	if skill_sel.has(id): skill_sel.erase(id)
	elif skill_sel.size() < 3: skill_sel.append(id)
	else: message = UiText.t("roster.skill_full")
	_refresh()

func _take_out_skill(i: int) -> void:
	if i < skill_sel.size():
		focus_skill = str(skill_sel[i])
		skill_sel.remove_at(i)
		message = ""
		_refresh()

func _refresh() -> void:
	var reach: int = Save.round_reach()
	for i in roster.size():
		var id: String = roster[i]
		var unit: Dictionary = Content.units[id]
		var locked := int(unit.get("unlock_round", 1)) > reach
		var hire: bool = not locked and Save.unit_recruitable(id)      # round reached, not bought yet (강화 화면 → 합류)
		tiles[i].dim_reason = UiText.t("roster.need_recruit") if hire else ""
		locked = locked or hire
		var on := selected.has(id)
		tiles[i].disabled = locked
		tiles[i].badge = str(selected.find(id) + 1) if on else ""
		tiles[i].fill = UiStyle.C_BG.lightened(0.1) if on else UiStyle.C_PANEL_LIGHT     # taken: dark, its slot number shows
		tiles[i].sub_text = str(int(unit.cost)) if not locked or hire else "R%d" % int(unit.unlock_round)
	for i in 5:
		_fill_slot(slots[i], i, selected, "unit")
	for i in skill_list.size():
		var id: String = skill_list[i]
		var sk: Dictionary = Content.skills[id]
		var locked := int(sk.get("unlock_round", 1)) > reach
		var on := skill_sel.has(id)
		skill_tiles[i].disabled = locked
		skill_tiles[i].badge = str(skill_sel.find(id) + 1) if on else ""
		skill_tiles[i].fill = UiStyle.C_BG.lightened(0.1) if on else Color(0.24, 0.3, 0.5)
		skill_tiles[i].sub_text = "R%d" % int(sk.unlock_round) if locked else str(int(sk.mana))
	for i in 3:
		_fill_slot(skill_slots[i], i, skill_sel, "skill")
	tab_units.fill = UiStyle.C_ACCENT.darkened(0.2) if tab == "units" else UiStyle.C_PANEL_LIGHT
	tab_skills.fill = UiStyle.C_ACCENT.darkened(0.2) if tab == "skills" else UiStyle.C_PANEL_LIGHT
	confirm.disabled = selected.is_empty()
	queue_redraw()

func _fill_slot(slot, i: int, list: Array, kind: String) -> void:
	if i < list.size():
		var id := str(list[i])
		slot.text = UiText.name_of(kind, id)
		slot.sub_text = str(int(Content.units[id].cost)) if kind == "unit" else str(int(Content.skills[id].mana))
		slot.icon = UiStyle.ui_icon(("card_" if kind == "unit" else "icon_") + id)
		slot.fill = UiStyle.C_ACCENT.darkened(0.3) if kind == "unit" else Color(0.3, 0.4, 0.7)
		slot.disabled = false
	else:
		slot.text = UiText.t("roster.empty")
		slot.sub_text = ""
		slot.icon = null
		slot.fill = UiStyle.C_BG.lightened(0.08)
		slot.disabled = true
	slot.badge = str(i + 1)

func _save() -> void:
	if selected.is_empty(): return
	if not Save.set_loadout(selected) or (not skill_sel.is_empty() and not Save.set_skills(skill_sel)):
		message = UiText.t("roster.failed")
		queue_redraw()
		return
	if round_id != "":
		emit_cmd_deferred(&"cmd_start_round", [round_id])
	else:
		_back()

func _back() -> void:
	emit_cmd_deferred(&"cmd_open_screen", [back_target])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and claim_back(): _back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

## Rows: top bar (back, tabs, title, confirm) | slot label | slots | card label | 2 rows of 5 cards | details line.
func _layout() -> void:
	if back == null: return
	var t := maxf(40, target)
	var top := safe.position.y + 6
	place(back, Rect2(safe.position.x + 6, top, 76, t))
	place(tab_units, Rect2(safe.position.x + 88, top, 60, t))
	place(tab_skills, Rect2(safe.position.x + 152, top, 60, t))
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
	for i in 3:
		place(skill_slots[i], Rect2(x0 + i * (width + gap), y, width, slot_h))
	y += slot_h + gap
	_grid_label_y = y + label * 0.5
	y += label
	for i in tiles.size():
		place(tiles[i], Rect2(x0 + (i % 5) * (width + gap), y + (i / 5) * (card_h + gap), width, card_h))
	for i in skill_tiles.size():
		place(skill_tiles[i], Rect2(x0 + (i % 5) * (width + gap), y + (i / 5) * (card_h + gap), width, card_h))

func _info_line() -> String:
	if message != "": return message
	if tab == "skills":
		if focus_skill == "" or not Content.skills.has(focus_skill): return UiText.t("roster.hint")
		var s: Dictionary = Content.skills[focus_skill]
		if int(s.get("unlock_round", 1)) > Save.round_reach():
			return UiText.t("roster.unlock") % int(s.unlock_round)
		return "%s · %s · %s" % [UiText.name_of("skill", focus_skill), UiText.t(str(s.get("desc_key", ""))),
			UiText.t("roster.skill_stats") % [int(s.mana), int(s.cooldown)]]
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
	UiStyle.draw_text_centered(self, heading, Vector2(safe.get_center().x + 40, safe.position.y + 26), UiStyle.FONT_L)
	var left := safe.position.x + 14
	var slot_label := UiText.t("roster.slots") % selected.size() if tab == "units" else UiText.t("roster.skill_slots") % skill_sel.size()
	var list_label := UiText.t("roster.units") if tab == "units" else UiText.t("roster.skill_list")
	UiStyle.draw_text_left(self, slot_label, Vector2(left, _slot_label_y), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	UiStyle.draw_text_left(self, list_label, Vector2(left, _grid_label_y), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	var line: Array = UiStyle.fit_text(_info_line(), safe.size.x - 16, UiStyle.FONT_S)
	UiStyle.draw_text_centered(self, line[0], Vector2(safe.get_center().x, safe.end.y - 12), UiStyle.FONT_S)
