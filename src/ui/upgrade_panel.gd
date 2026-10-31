extends Control
## Meta-progression upgrade panel (spend coins earned in rounds). Owner: 04-client.
## Data: Content.meta.upgrades (01 data/meta.json, read-only). Levels/coins: Save.progress (read-only).
## Purchase: ONLY through the proposed 02 contract `Save.buy_upgrade(upgrade_id, to_level) -> String`
## (10 DATA_AND_BACKEND_ANALYSIS §9.4; codes ok | already_applied | max_level | not_enough_coins |
## unknown_id | locked | save_failed | read_only). The UI never edits Save.progress itself: a direct
## edit + failed write was shown by 10 to keep the change in memory and double-charge on retry.
## Until 02 provides the method the panel is browsable but inactive (buttons disabled + notice).
## No monetization UI here: Q2 = "보류" (user), so no gems, ads, shop or "remove ads".

signal closed

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const TouchButton := preload("res://src/ui/touch_button.gd")

## Injection points (tests / preview). Default: /root/Content, /root/Save, /root/Events.
var content: Object
var save: Object
var bus: Object
## Double-tap guard: after any purchase attempt the panel ignores further buy taps for this long
## (a second tap after a synchronous success would otherwise buy the NEXT level = 2 charges).
const BUY_LOCK_MS := 400
var _lock_until_ms := 0
var buy_calls := 0            # QA: purchase requests actually sent
var target := 40.0
var panel_rect := Rect2()
var page := 0
var rows: Array = []            # visible upgrade definitions on this page
var row_rects: Array[Rect2] = []
var buy_buttons: Array = []
var btn_close: Control
var btn_prev: Control
var btn_next: Control
var status_code := ""           # last purchase result code (QA)
var status_text := ""
var status_upgrade := ""
var per_page := 4

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP     # modal
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _content() -> Object:
	return content if content != null else get_node_or_null("/root/Content")

func _save() -> Object:
	return save if save != null else get_node_or_null("/root/Save")

func _bus() -> Object:
	return bus if bus != null else get_node_or_null("/root/Events")

## 02 R7 (INTERFACES §3 v1.5): Events.cmd_buy_upgrade → Events.upgrade_result. Direct
## Save.buy_upgrade is the fallback (tests / preview without the bus contract).
func purchase_available() -> bool:
	var b := _bus()
	if b != null and b.has_signal("cmd_buy_upgrade") and b.has_signal("upgrade_result"):
		return true
	var s := _save()
	return s != null and s.has_method("buy_upgrade")

func progress() -> Dictionary:
	var s := _save()
	if s != null and s.get("progress") is Dictionary:
		return s.progress
	return {"coins": 0, "upgrades": {}, "unlocked_round": 1}

func coins() -> int:
	return int(progress().get("coins", 0))

func level_of(id: String) -> int:
	var sv := _save()
	if sv != null and sv.has_method("upgrade_level"):
		return int(sv.upgrade_level(id))   # authoritative (02)
	var ups = progress().get("upgrades", {})
	var start := 1
	var c := _content()
	if c != null and c.get("meta") is Dictionary:
		start = int(c.meta.get("upgrade_level_start", 1))
	return int(ups.get(id, start)) if ups is Dictionary else start

## Upgrades whose target is unlocked (01 R1: show only unlocked targets).
func visible_upgrades() -> Array:
	var c := _content()
	if c == null or not (c.get("meta") is Dictionary):
		return []
	var unlocked := int(progress().get("unlocked_round", 1))
	var out := []
	for u in c.meta.get("upgrades", []):
		if not (u is Dictionary) or not u.has("id"):
			continue
		var tgt := str(u.get("target", ""))
		if tgt.begins_with("unit:") and c.has_method("get_unit"):
			var ud: Dictionary = c.get_unit(tgt.substr(5))
			if ud.is_empty() or str(ud.get("id", "")) != tgt.substr(5) or int(ud.get("unlock_round", 1)) > unlocked:
				continue
		out.append(u)
	return out

func next_cost(u: Dictionary) -> int:
	var sv := _save()
	if sv != null and sv.has_method("upgrade_cost"):
		return int(sv.upgrade_cost(str(u.id), level_of(str(u.id)) + 1))   # -1 = no further level
	var lv := level_of(str(u.id))
	var costs: Array = u.get("costs", [])
	var i := lv - int(_content().meta.get("upgrade_level_start", 1)) if _content() != null else lv - 1
	return int(costs[i]) if i >= 0 and i < costs.size() else -1

func is_max(u: Dictionary) -> bool:
	return level_of(str(u.id)) >= int(u.get("max_level", 1)) or next_cost(u) < 0

## Display name: "<unit name> 강화" style per 01 R2.4 for unit targets, else the upgrade name key.
func display_name(u: Dictionary) -> String:
	var tgt := str(u.get("target", ""))
	var base := UiText.t(str(u.get("name_key", "")), str(u.id))
	if tgt.begins_with("unit:"):
		return "%s · %s" % [UiText.name_of("unit", tgt.substr(5), tgt.substr(5)), base]
	if tgt.begins_with("hero:"):
		return "%s · %s" % [UiText.name_of("hero", tgt.substr(5), tgt.substr(5)), base]
	return base

## Compact effect of the NEXT level, from per_level numbers (no new text needed).
func effect_text(u: Dictionary) -> String:
	var parts := []
	var pl: Dictionary = u.get("per_level", {})
	for k in pl:
		var v := float(pl[k])
		if str(k).ends_with("_mult"):
			parts.append("+%d%%" % int(roundf(v * 100)))
		else:
			parts.append(("+%.2f" % v).rstrip("0").rstrip("."))
	return " ".join(parts.slice(0, 2))

func open(view: Vector2, safe: Rect2, p_target: float) -> void:
	target = p_target
	size = view
	if btn_close == null:
		_build()
	status_code = ""
	status_text = UiText.t("ui.upgrade_unavailable") if not purchase_available() else ""
	_layout(view, safe)
	_refresh()
	show()

func _build() -> void:
	btn_close = TouchButton.new()
	btn_close.text = UiText.t("ui.close")
	btn_close.fill = UiStyle.C_ACCENT.darkened(0.2)
	btn_close.tapped.connect(_on_close)
	add_child(btn_close)
	btn_prev = TouchButton.new()
	btn_prev.glyph = &"left"
	btn_prev.tapped.connect(func(): _set_page(page - 1))
	add_child(btn_prev)
	btn_next = TouchButton.new()
	btn_next.glyph = &"right"
	btn_next.tapped.connect(func(): _set_page(page + 1))
	add_child(btn_next)

func _layout(_view: Vector2, safe: Rect2) -> void:
	var w := minf(safe.size.x - 16, 460.0)
	var row_h := maxf(target, 40.0)
	var h := safe.size.y - 16
	panel_rect = Rect2((safe.get_center() - Vector2(w, h) / 2).round(), Vector2(w, h))
	# title 38 + rows + status 20 + bottom bar row_h + margins
	per_page = maxi(1, int(floor((h - 38 - 24 - row_h - 16) / (row_h + 4))))
	var by := panel_rect.end.y - row_h - 8
	btn_close.position = Vector2(panel_rect.get_center().x - 50, by).round()
	btn_close.size = Vector2(100, row_h)
	btn_prev.position = Vector2(panel_rect.position.x + 8, by)
	btn_prev.size = Vector2(row_h, row_h)
	btn_next.position = Vector2(panel_rect.end.x - 8 - row_h, by)
	btn_next.size = Vector2(row_h, row_h)
	for b in buy_buttons:
		b.queue_free()
	buy_buttons.clear()
	row_rects.clear()
	for i in per_page:
		var r := Rect2(panel_rect.position.x + 8, panel_rect.position.y + 38 + i * (row_h + 4), w - 16, row_h)
		row_rects.append(r)
		var b: Control = TouchButton.new()
		b.text = UiText.t("ui.upgrade_buy")
		b.tapped.connect(_on_buy.bind(i))
		b.position = Vector2(r.end.x - 76, r.position.y).round()
		b.size = Vector2(76, row_h)
		add_child(b)
		buy_buttons.append(b)

func pages() -> int:
	return maxi(1, ceili(visible_upgrades().size() / float(per_page)))

func _set_page(p: int) -> void:
	page = clampi(p, 0, pages() - 1)
	_refresh()

func _refresh() -> void:
	var all := visible_upgrades()
	page = clampi(page, 0, pages() - 1)
	rows = all.slice(page * per_page, page * per_page + per_page)
	var active := purchase_available()
	for i in buy_buttons.size():
		var b: Control = buy_buttons[i]
		if i >= rows.size():
			b.hide()
			continue
		b.show()
		var u: Dictionary = rows[i]
		var mx := is_max(u)
		b.text = UiText.t("ui.max") if mx else UiText.t("ui.upgrade_buy")
		b.disabled = mx or not active
		b.dim_reason = ""
		b.fill = UiStyle.C_PANEL_LIGHT if mx or coins() < next_cost(u) else UiStyle.C_ACCENT.darkened(0.15)
		b.queue_redraw()
	btn_prev.visible = page > 0
	btn_next.visible = page < pages() - 1
	queue_redraw()

## Purchase through the 02 contract only. Result code → distinct message (and colour + glyph).
func _on_buy(slot: int) -> void:
	if slot >= rows.size():
		return
	var u: Dictionary = rows[slot]
	var id := str(u.id)
	status_upgrade = id
	if is_max(u):
		_set_status("max_level", u)
		return
	if not purchase_available():
		_set_status("unavailable", u)
		return
	var now := Time.get_ticks_msec()
	if now < _lock_until_ms:
		return                              # double tap: ignored, exactly one request per press
	_lock_until_ms = now + BUY_LOCK_MS
	var to := level_of(id) + 1
	var code := ""
	var b := _bus()
	buy_calls += 1
	if b != null and b.has_signal("cmd_buy_upgrade") and b.has_signal("upgrade_result"):
		var got := {}
		var cb := func(r: Dictionary) -> void:
			if str(r.get("id", "")) == id:
				got.merge(r)
		b.connect("upgrade_result", cb)
		b.emit_signal("cmd_buy_upgrade", id, to)   # synchronous in 02's App (R7)
		b.disconnect("upgrade_result", cb)
		code = str(got.get("code", "no_reply"))
	else:
		code = str(_save().buy_upgrade(id, to))
	_set_status(code, u)
	_refresh()

const STATUS_KIND := {
	"ok": "good", "already_applied": "good", "max_level": "info", "not_enough_coins": "warn",
	"save_failed": "error", "save_uncertain": "error", "read_only": "error", "locked": "warn", "unknown_id": "error",
	"invalid_level": "error", "no_reply": "error", "unavailable": "info",
}

func _set_status(code: String, u: Dictionary) -> void:
	status_code = code
	match code:
		"ok", "already_applied":
			status_text = UiText.t("ui.upgrade_ok") % [display_name(u), level_of(str(u.id))]
		"not_enough_coins":
			status_text = UiText.t("ui.upgrade_not_enough") % maxi(0, next_cost(u) - coins())
		"max_level":
			status_text = UiText.t("ui.upgrade_max")
		"save_failed", "read_only":
			status_text = UiText.t("ui.upgrade_save_failed")
		"save_uncertain":
			status_text = UiText.t("ui.upgrade_save_uncertain")
		"unavailable":
			status_text = UiText.t("ui.upgrade_unavailable")
		"locked":
			status_text = UiText.t("ui.upgrade_locked")
		_:
			status_text = UiText.t("ui.upgrade_error") % code
	queue_redraw()

func _on_close() -> void:
	hide()
	closed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and preload("res://src/ui/ui_screen.gd").claim_back():
		_on_close()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.C_DIM)
	UiStyle.draw_pixel_box(self, panel_rect, UiStyle.C_PANEL)
	UiStyle.draw_text_centered(self, UiText.t("ui.upgrades"), Vector2(panel_rect.get_center().x, panel_rect.position.y + 19), UiStyle.FONT_L)
	# wallet (top-right): coins only — no premium currency (Q2 보류)
	var cx := panel_rect.end.x - 12
	UiStyle.draw_number(self, str(coins()), Vector2(cx, panel_rect.position.y + 19), UiStyle.FONT_M, UiStyle.C_GOLD, 1, &"bold")
	var cw := UiStyle.number_width(str(coins()), UiStyle.FONT_M, &"bold")
	if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(cx - cw - 10, panel_rect.position.y + 19)):
		UiStyle.draw_glyph(self, &"coin", Vector2(cx - cw - 10, panel_rect.position.y + 19), 5)
	for i in rows.size():
		var u: Dictionary = rows[i]
		var r: Rect2 = row_rects[i]
		draw_rect(r, Color(0, 0, 0, 0.18))
		var name_w := r.size.x - 76 - 8 - 130
		var nm: Array = UiStyle.fit_text(display_name(u), name_w, UiStyle.FONT_S)
		UiStyle.draw_text_left(self, nm[0], Vector2(r.position.x + 6, r.position.y + 12), UiStyle.FONT_S, UiStyle.C_TEXT)
		UiStyle.draw_number(self, effect_text(u), Vector2(r.position.x + 6, r.position.y + 29), UiStyle.NUM_S, UiStyle.C_HP_PLAYER, -1)
		var lv := level_of(str(u.id))
		var mx := int(u.get("max_level", 1))
		var lx := r.end.x - 76 - 8 - 124
		UiStyle.draw_number(self, "Lv %d/%d" % [lv, mx], Vector2(lx, r.get_center().y), UiStyle.NUM_S, UiStyle.C_TEXT_DIM, -1)
		if not is_max(u):
			var cost := next_cost(u)
			var col := UiStyle.C_GOLD if coins() >= cost else UiStyle.C_HP_ENEMY
			UiStyle.draw_number(self, str(cost), Vector2(r.end.x - 76 - 10, r.get_center().y), UiStyle.FONT_M, col, 1, &"bold")
			var w2 := UiStyle.number_width(str(cost), UiStyle.FONT_M, &"bold")
			if not UiStyle.draw_ui_icon(self, "icon_gold", Vector2(r.end.x - 76 - 18 - w2, r.get_center().y)):
				UiStyle.draw_glyph(self, &"coin", Vector2(r.end.x - 76 - 18 - w2, r.get_center().y), 5)
		else:
			UiStyle.draw_star_marker(self, Vector2(r.end.x - 76 - 18, r.get_center().y), true)
	if visible_upgrades().is_empty():
		UiStyle.draw_text_centered(self, UiText.t("ui.upgrade_none"), panel_rect.get_center(), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	if status_text != "":
		var kind: String = STATUS_KIND.get(status_code, "info") if status_code != "" else "info"
		var col: Color = {"good": UiStyle.C_HP_PLAYER, "warn": UiStyle.C_GOLD, "error": UiStyle.C_HP_ENEMY, "info": UiStyle.C_TEXT_DIM}[kind]
		var sy := panel_rect.end.y - maxf(target, 40.0) - 20
		var mark: String = {"good": "●", "warn": "▲", "error": "×", "info": "※"}[kind]   # shape differs per kind, not only colour (all in Galmuri11)
		var line: Array = UiStyle.fit_text(mark + " " + status_text, panel_rect.size.x - 24, UiStyle.FONT_S)
		UiStyle.draw_text_centered(self, line[0], Vector2(panel_rect.get_center().x, sy), UiStyle.FONT_S, col)
		status_kind_drawn = kind
	else:
		status_kind_drawn = ""

var status_kind_drawn := ""     # QA
