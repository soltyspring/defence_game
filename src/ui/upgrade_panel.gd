extends Control
## Meta-progression upgrade panel (spend coins earned in rounds). Owner: 04-client.
## Data: Content.meta.upgrades (01 data/meta.json, read-only). Levels/coins: Save.progress (read-only).
## Purchase: ONLY through the proposed 02 contract `Save.buy_upgrade(upgrade_id, to_level) -> String`
## (10 DATA_AND_BACKEND_ANALYSIS §9.4; codes ok | already_applied | max_level | not_enough_coins |
## unknown_id | locked | save_failed | read_only). The UI never edits Save.progress itself: a direct
## edit + failed write was shown by 10 to keep the change in memory and double-charge on retry.
## Until 02 provides the method the panel is browsable but inactive (buttons disabled + notice).
## Layout (2026-11-14): list of targets on the left, the chosen one on the right with an attack example, its traits
## and the numbers the next level changes; one buy button (`btn_buy`). `rows` = the list rows on this page,
## `row_buttons[i]` selects `rows[i]`, `_on_buy(i)` still selects and buys row i.
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
	set_anchors_preset(Control.PRESET_TOP_LEFT) # sized explicitly by open()

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
		var sv := _save()
		if sv != null and sv.has_method("upgrade_locked"):
			if sv.upgrade_locked(str(u.id)): continue
			out.append(u)
			continue
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
			var lv := level_of(str(u.id))
			var rate := float(u.get("compound_rate", 0.0))
			var after := int(u.get("compound_after_level", 999))
			var before := (1.0 + v * (lv - 1)) * pow(1.0 + rate, maxi(0, lv - after))
			var next := (1.0 + v * lv) * pow(1.0 + rate, maxi(0, lv + 1 - after))
			parts.append("+%d%%" % int(roundf((next / before - 1.0) * 100)))
		else:
			parts.append(("+%.2f" % v).rstrip("0").rstrip("."))
	return " ".join(parts.slice(0, 2))

## Multiplier of an upgrade at a level: (1 + per_level x (lv - 1)) x (1 + rate)^(lv - compound_after), as BattleSim.
func level_mult(u: Dictionary, key: String, lv: int) -> float:
	var base := 1.0 + float(u.get("per_level", {}).get(key, 0.0)) * (lv - 1)
	var after := int(u.get("compound_after_level", 999))
	return base * pow(1.0 + float(u.get("compound_rate", 0.0)), maxi(0, lv - after))

func level_add(u: Dictionary, key: String, lv: int) -> float:
	return float(u.get("per_level", {}).get(key, 0.0)) * (lv - 1)

static func num(v: float) -> String:
	if absf(v) >= 100.0: return str(int(roundf(v)))
	var t := "%.1f" % v
	return t.trim_suffix(".0")

## The real numbers this upgrade changes, now and after the next level: [{label, now, next, delta}].
## Units / hero: HP and attack from their data. Base: HP multiplier. Flour, energy, baker: the in-battle values.
func stat_lines(u: Dictionary) -> Array:
	var c := _content()
	var lv := level_of(str(u.id))
	var nx := mini(lv + 1, int(u.get("max_level", lv)))
	var tgt := str(u.get("target", ""))
	var out := []
	var add_line := func(key: String, now: float, nxt: float, suffix := "") -> void:
		out.append({"label": UiText.t("stat." + key), "now": num(now) + suffix, "next": num(nxt) + suffix,
			"delta": ("+" + num(nxt - now) + suffix) if nxt > now else ""})
	if c == null: return out
	var econ: Dictionary = c.get("economy") if c.get("economy") is Dictionary else {}
	if tgt.begins_with("unit:") or tgt.begins_with("hero:"):
		var id := tgt.substr(5)
		var d: Dictionary = c.get_unit(id) if tgt.begins_with("unit:") else c.heroes.get(id, {})
		for key in ["hp", "atk"]:
			if u.get("per_level", {}).has(key + "_mult"):
				var b := float(d.get(key, 0))
				add_line.call(key, b * level_mult(u, key + "_mult", lv), b * level_mult(u, key + "_mult", nx))
	elif tgt == "base:player":
		out.append({"label": UiText.t("stat.base_hp"), "now": "x" + "%.2f" % level_mult(u, "hp_mult", lv),
			"next": "x" + "%.2f" % level_mult(u, "hp_mult", nx), "delta": ""})
	elif tgt == "resource:supply":
		var r := float(econ.get("base_income", 0))
		add_line.call("flour_regen", r + level_add(u, "regen_add", lv), r + level_add(u, "regen_add", nx), "/s")
		var m := float(econ.get("gold_max", 0))
		add_line.call("flour_max", m + level_add(u, "cap_add", lv), m + level_add(u, "cap_add", nx))
	elif tgt == "resource:energy":
		var h: Dictionary = c.heroes.values()[0] if not c.heroes.is_empty() else {}
		add_line.call("mana_regen", float(h.get("mana_regen", 0)) + level_add(u, "regen_add", lv), float(h.get("mana_regen", 0)) + level_add(u, "regen_add", nx), "/s")
		add_line.call("mana_max", float(h.get("mana_max", 0)) + level_add(u, "cap_add", lv), float(h.get("mana_max", 0)) + level_add(u, "cap_add", nx))
	elif tgt == "worker":
		var w := float(econ.get("worker_income", 0))
		add_line.call("worker_income", w + level_add(u, "income_add", lv), w + level_add(u, "income_add", nx), "/s")
	return out

func icon_frame(u: Dictionary) -> String:
	var tgt := str(u.get("target", ""))
	if tgt.begins_with("unit:") or tgt.begins_with("hero:"): return "card_" + tgt.substr(5)
	return {"resource:supply": "icon_supply", "resource:energy": "icon_energy", "worker": "card_worker", "base:player": "icon_home"}.get(tgt, "icon_star")

## ---- Screen: list on the left, the chosen target on the right -------------------------------------------------
## Left: every upgrade target as a row (icon, name, level; a gold mark when the gold on hand buys the next level;
## characters that have not joined yet stay listed with their round). Right: the character with a looping attack
## example, what kind of attacker it is, the numbers the next level changes (now -> next, +delta), and one buy button.
var list: Array = []            # every row, in display order (rows = the ones on this page)
var selected_id := ""
var row_buttons: Array = []     # one per visible row: tap = select
var btn_buy: Control
var desc_line: Control          # description and traits scroll sideways when they do not fit (Marquee)
var traits_line: Control
var btn_gold: Control           # 골드 구매: shown while the selected purchase is short of gold (shop builds only)
var _gold_fits := false
const GoldShopCatalog := preload("res://src/core/gold_shop_catalog.gd")
var demo: Control               # attack example (redraws on its own, the panel does not)
var detail_rect := Rect2()
var _locked := {}               # upgrade id -> true while its character has not joined

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
	btn_buy = TouchButton.new()
	btn_buy.text = UiText.t("ui.upgrade_buy")
	btn_buy.tapped.connect(_buy_selected)
	add_child(btn_buy)
	buy_buttons = [btn_buy]
	btn_gold = TouchButton.new()
	btn_gold.text = UiText.t("upg.buy_gold")
	btn_gold.font_size = UiStyle.FONT_S
	btn_gold.fill = UiStyle.C_GOLD.darkened(0.45)
	btn_gold.tapped.connect(_on_gold)
	btn_gold.hide()
	add_child(btn_gold)
	desc_line = Marquee.new()
	add_child(desc_line)
	traits_line = Marquee.new()
	traits_line.color = UiStyle.C_TEXT
	add_child(traits_line)
	demo = Demo.new()
	demo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(demo)

## Display order: hero, characters by the round they join, then the bakery (flour, energy, apprentices, base).
func list_upgrades() -> Array:
	var c := _content()
	if c == null or not (c.get("meta") is Dictionary):
		return []
	var open_list := visible_upgrades()
	var keys := {}
	var out := []
	var all: Array = c.meta.get("upgrades", [])
	_locked.clear()
	for i in all.size():
		var u = all[i]
		if not (u is Dictionary) or not u.has("id"):
			continue
		var tgt := str(u.get("target", ""))
		var is_open := open_list.has(u)
		if not is_open and not tgt.begins_with("unit:"):
			continue
		if not is_open: _locked[str(u.id)] = true
		var group := 0 if tgt.begins_with("hero:") else (1 if tgt.begins_with("unit:") else 2)
		keys[str(u.id)] = [group, join_round(u), i]
		out.append(u)
	out.sort_custom(func(a, b): return keys[str(a.id)] < keys[str(b.id)])
	return out

func is_locked(u: Dictionary) -> bool:
	return _locked.has(str(u.get("id", "")))

## Gold needed to recruit this row's character (round reached, not bought yet); 0 = nothing to recruit here.
## Such a row is still "locked" for upgrades: the buy button recruits instead (Save.recruit).
func hire_cost(u: Dictionary) -> int:
	var sv := _save()
	var tgt := str(u.get("target", ""))
	if u.is_empty() or sv == null or not tgt.begins_with("unit:") or not sv.has_method("unit_recruitable"): return 0
	return int(sv.recruit_cost(tgt.substr(5))) if sv.unit_recruitable(tgt.substr(5)) else 0

func _recruit(u: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if now < _lock_until_ms:
		return
	_lock_until_ms = now + BUY_LOCK_MS
	var cost := hire_cost(u)
	buy_calls += 1
	var code := str(_save().recruit(str(u.target).substr(5)))
	status_upgrade = str(u.id)
	_set_status(code, u)
	if code in ["ok", "already_applied"]: status_text = UiText.t("upg.recruit_ok") % target_name(u)
	elif code == "not_enough_coins": status_text = UiText.t("ui.upgrade_not_enough") % maxi(0, cost - coins())
	_refresh()

## Round at which this upgrade's character joins (1 for the hero and the bakery).
func join_round(u: Dictionary) -> int:
	var d := target_def(u)
	return int(d.get("unlock_round", 1)) if str(u.get("target", "")).begins_with("unit:") else 1

## Unit / hero data behind an upgrade ({} for the bakery upgrades).
func target_def(u: Dictionary) -> Dictionary:
	var c := _content()
	var tgt := str(u.get("target", ""))
	if c == null: return {}
	if tgt.begins_with("unit:") and c.has_method("get_unit"):
		var d: Dictionary = c.get_unit(tgt.substr(5))
		return d if str(d.get("id", "")) == tgt.substr(5) else {}
	if tgt.begins_with("hero:") and c.get("heroes") is Dictionary:
		return c.heroes.get(tgt.substr(5), {})
	return {}

func target_name(u: Dictionary) -> String:
	var tgt := str(u.get("target", ""))
	if tgt.begins_with("unit:"): return UiText.name_of("unit", tgt.substr(5), tgt.substr(5))
	if tgt.begins_with("hero:"): return UiText.name_of("hero", tgt.substr(5), tgt.substr(5))
	return UiText.t(str(u.get("name_key", "")), str(u.id))

func selected() -> Dictionary:
	for u in list:
		if str(u.id) == selected_id: return u
	return {}

func select(id: String) -> void:
	if id == selected_id: return
	selected_id = id
	for i in list.size():           # bring its row onto the page
		if str(list[i].id) == id: page = i / per_page
	status_code = ""
	status_text = UiText.t("ui.upgrade_unavailable") if not purchase_available() else ""
	_refresh()

## Gold on hand buys the next level right now.
func can_buy(u: Dictionary) -> bool:
	if u.is_empty(): return false
	if hire_cost(u) > 0: return coins() >= hire_cost(u)
	if is_locked(u) or is_max(u) or coins() < next_cost(u): return false
	return not _gated(u)

func gate_round(u: Dictionary) -> int:
	var sv := _save()
	if sv != null and sv.has_method("upgrade_level_unlock_round"):
		return int(sv.upgrade_level_unlock_round(str(u.id), level_of(str(u.id)) + 1))
	return 1

func _gated(u: Dictionary) -> bool:
	var sv := _save()
	return sv != null and sv.has_method("round_reach") and int(sv.round_reach()) < gate_round(u)

func _layout(_view: Vector2, safe: Rect2) -> void:
	var w := minf(safe.size.x - 16, 620.0)
	var row_h := maxf(target, 44.0)
	var h := safe.size.y - 16
	panel_rect = Rect2((safe.get_center() - Vector2(w, h) / 2).round(), Vector2(w, h))
	var top := panel_rect.position.y + 36
	var by := panel_rect.end.y - row_h - 8
	var lw := clampf(w * 0.34, 168.0, 210.0)
	# left column: rows, then prev / page / next under them
	per_page = maxi(1, int(floor((by - 4 - top) / (row_h + 4))))
	for b in row_buttons:
		b.queue_free()
	row_buttons.clear()
	row_rects.clear()
	for i in per_page:
		var r := Rect2(panel_rect.position.x + 8, top + i * (row_h + 4), lw, row_h)
		row_rects.append(r)
		var b: Control = TouchButton.new()
		b.tapped.connect(_on_row.bind(i))
		b.overlay = _draw_row.bind(i)
		b.position = r.position.round()
		b.size = r.size
		add_child(b)
		row_buttons.append(b)
	btn_prev.position = Vector2(panel_rect.position.x + 8, by)
	btn_prev.size = Vector2(row_h, row_h)
	btn_next.position = Vector2(panel_rect.position.x + 8 + lw - row_h, by)
	btn_next.size = Vector2(row_h, row_h)
	# right pane: details, then close (left) and buy (right) on the bottom bar
	detail_rect = Rect2(panel_rect.position.x + 8 + lw + 8, top, w - lw - 24, by - 4 - top)
	btn_close.position = Vector2(detail_rect.position.x, by).round()
	btn_close.size = Vector2(84, row_h)
	var buy_width := minf(132.0, detail_rect.size.x - btn_close.size.x - 8.0)
	btn_buy.position = Vector2(detail_rect.end.x - buy_width, by).round()
	btn_buy.size = Vector2(buy_width, row_h)
	# 골드 구매 sits between 닫기 and the buy button; dropped when there is no room for a readable button
	var gx := btn_close.position.x + btn_close.size.x + 8.0
	_gold_fits = btn_buy.position.x - 8.0 - gx >= 64.0
	btn_gold.position = Vector2(gx, by).round()
	btn_gold.size = Vector2(maxf(0.0, btn_buy.position.x - 8.0 - gx), row_h)
	# Leave room for traits, next-level stats and the purchase notice on short screens.
	var dh := clampf(detail_rect.size.y - 34 - 16 - 3 * 18 - 22, 44.0, 120.0)
	demo.position = (detail_rect.position + Vector2(0, 34)).round()
	demo.size = Vector2(detail_rect.size.x, dh).round()
	move_child(demo, -1)
	desc_line.position = (detail_rect.position + Vector2(0, 17)).round()
	desc_line.size = Vector2(detail_rect.size.x, 14)
	traits_line.position = Vector2(detail_rect.position.x, demo.position.y + demo.size.y + 3).round()
	traits_line.size = Vector2(detail_rect.size.x, 14)

func pages() -> int:
	return maxi(1, ceili(list_upgrades().size() / float(per_page)))

func _set_page(p: int) -> void:
	page = clampi(p, 0, pages() - 1)
	_refresh()

func _refresh() -> void:
	list = list_upgrades()
	if selected().is_empty():
		selected_id = str(list[0].id) if not list.is_empty() else ""
		for u in list:                      # open on something the player can act on
			if can_buy(u):
				selected_id = str(u.id)
				break
		for i in list.size():
			if str(list[i].id) == selected_id: page = i / per_page
	page = clampi(page, 0, pages() - 1)
	rows = list.slice(page * per_page, page * per_page + per_page)
	for i in row_buttons.size():
		var b: Control = row_buttons[i]
		b.visible = i < rows.size()
		if not b.visible: continue
		var on := str(rows[i].id) == selected_id
		b.fill = UiStyle.C_ACCENT.darkened(0.25) if on else (UiStyle.C_DISABLED if is_locked(rows[i]) and hire_cost(rows[i]) == 0 else UiStyle.C_PANEL_LIGHT)
		b.queue_redraw()
	btn_prev.visible = page > 0
	btn_next.visible = page < pages() - 1
	var u := selected()
	var mx := not u.is_empty() and is_max(u)
	var gated := not u.is_empty() and not mx and _gated(u)
	btn_buy.visible = not u.is_empty()
	btn_buy.text = UiText.t("ui.max") if mx else (("R%d" % gate_round(u)) if gated else UiText.t("ui.upgrade_buy"))
	btn_buy.sub_text = "" if u.is_empty() or mx or is_locked(u) else str(next_cost(u))
	btn_buy.disabled = u.is_empty() or mx or gated or is_locked(u) or not purchase_available()
	var hire := hire_cost(u)
	if hire > 0:                    # recruit instead of upgrade; stays tappable so a short purse gets its message
		btn_buy.text = UiText.t("upg.recruit")
		btn_buy.sub_text = str(hire)
		btn_buy.disabled = false
	btn_buy.fill = UiStyle.C_ACCENT.darkened(0.15) if can_buy(u) else UiStyle.C_PANEL_LIGHT
	btn_buy.queue_redraw()
	btn_gold.visible = _gold_fits and GoldShopCatalog.enabled()      # always there (2026-11-14 user); brighter when short
	btn_gold.fill = UiStyle.C_GOLD.darkened(0.25 if short_of_gold(u) > 0 else 0.5)
	var dd := target_def(u) if not u.is_empty() else {}
	var dk := str(dd.get("desc_key", "")) if not dd.is_empty() else str(u.get("desc_key", ""))
	desc_line.set_text(UiText.t(dk) if dk != "" and UiText.has(dk) else "")
	traits_line.set_text(traits_text(u) if not u.is_empty() else "")
	if demo != null:
		var d := target_def(u) if not u.is_empty() else {}
		var lv := level_of(str(u.id)) if not u.is_empty() else 1
		demo.setup(d, UiStyle.ui_icon(icon_frame(u)) if not u.is_empty() else null,
			float(d.get("atk", 0)) * (level_mult(u, "atk_mult", lv) if not u.is_empty() else 1.0), is_locked(u) and hire == 0)
	queue_redraw()

## Gold missing for what the buy button would do right now (next level or recruiting); 0 = enough, or nothing to buy.
func short_of_gold(u: Dictionary) -> int:
	if u.is_empty(): return 0
	if hire_cost(u) > 0: return maxi(0, hire_cost(u) - coins())
	if is_locked(u) or is_max(u) or _gated(u): return 0
	return maxi(0, next_cost(u) - coins())

## 골드 구매: leave for the gold shop; the menu brings the player back to this screen afterwards.
func _on_gold() -> void:
	var b := _bus()
	if b == null or not b.has_signal("cmd_open_screen"): return
	GoldShopCatalog.return_to_upgrades = true
	hide()
	closed.emit()
	b.emit_signal("cmd_open_screen", &"gold_shop")

func _on_row(slot: int) -> void:
	if slot < rows.size():
		select(str(rows[slot].id))

## Kept for callers that buy by row: selects that row, then buys it.
func _on_buy(slot: int) -> void:
	if slot >= rows.size():
		return
	selected_id = str(rows[slot].id)
	_buy_selected()

## Purchase through the 02 contract only. Result code → distinct message (and colour + glyph).
func _buy_selected() -> void:
	var u := selected()
	if u.is_empty():
		return
	var id := str(u.id)
	status_upgrade = id
	if is_max(u):
		_set_status("max_level", u)
		return
	if hire_cost(u) > 0:
		_recruit(u)
		return
	if is_locked(u):
		_set_status("locked", u)
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
			status_text = UiText.t("ui.upgrade_error")
	queue_redraw()

func _on_close() -> void:
	hide()
	closed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and preload("res://src/ui/ui_screen.gd").claim_back():
		_on_close()

## One list row, drawn over its button: icon, name, level (or the round the character joins), ready mark.
func _draw_row(b: Control, i: int) -> void:
	if i >= rows.size(): return
	var u: Dictionary = rows[i]
	var locked := is_locked(u)
	var x := 6.0
	var tex: Texture2D = UiStyle.ui_icon(icon_frame(u))
	if tex != null:
		var k := maxf(1.0, floorf((b.size.y - 10) / maxf(1.0, float(tex.get_height()))))
		var isz := Vector2(tex.get_size()) * k
		b.draw_texture_rect(tex, Rect2(Vector2(x, b.size.y / 2 - isz.y / 2).round(), isz), false, Color(1, 1, 1, 0.5) if locked else Color.WHITE)
		x += isz.x + 6
	var nm: Array = UiStyle.fit_text(target_name(u), b.size.x - x - 18, UiStyle.FONT_S)
	UiStyle.draw_text_left(b, nm[0], Vector2(x, b.size.y / 2 - 8), UiStyle.FONT_S, UiStyle.C_TEXT_DIM if locked else UiStyle.C_TEXT)
	var sub := UiText.t("upg.joins") % join_round(u) if locked else "Lv %d / %d" % [level_of(str(u.id)), int(u.get("max_level", 1))]
	if hire_cost(u) > 0: sub = UiText.t("upg.recruit_ready")
	UiStyle.draw_text_left(b, sub, Vector2(x, b.size.y / 2 + 8), UiStyle.FONT_S, UiStyle.C_GOLD if hire_cost(u) > 0 else UiStyle.C_TEXT_DIM)
	if can_buy(u):       # shape + colour: an up arrow, not only gold
		UiStyle.draw_text_centered(b, "▲", Vector2(b.size.x - 11, b.size.y / 2), UiStyle.FONT_S, UiStyle.C_GOLD)
	elif not locked and is_max(u):
		UiStyle.draw_star_marker(b, Vector2(b.size.x - 11, b.size.y / 2), true)

## "원거리 · 사거리 110 · 1.2초마다 공격 · 밀가루 40" for a character; "" for the bakery upgrades.
func traits_text(u: Dictionary) -> String:
	var d := target_def(u)
	if d.is_empty(): return ""
	var parts := []
	var ranged: bool = str(d.get("attack_type", "")) == "ranged" or float(d.get("range", 0)) >= 60.0
	parts.append(UiText.t("upg.ranged") if ranged else UiText.t("upg.melee"))
	parts.append(UiText.t("upg.range") % int(d.get("range", 0)))
	if float(d.get("splash", 0)) > 0.0: parts.append(UiText.t("upg.splash") % int(d.splash))
	if float(d.get("atk_interval", 0)) > 0.0: parts.append(UiText.t("upg.interval") % num(float(d.atk_interval)))
	if float(d.get("structure_mult", 1.0)) > 1.0: parts.append(UiText.t("upg.structure") % num(float(d.structure_mult)))
	if d.has("cost"): parts.append(UiText.t("upg.cost") % int(d.cost))
	return " · ".join(parts)

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
	if pages() > 1:
		UiStyle.draw_text_centered(self, "%d / %d" % [page + 1, pages()], Vector2((btn_prev.position.x + btn_next.position.x + btn_next.size.x) / 2, btn_prev.position.y + btn_prev.size.y / 2), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	var u := selected()
	if u.is_empty():
		UiStyle.draw_text_centered(self, UiText.t("ui.upgrade_none"), detail_rect.get_center(), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	else:
		_draw_detail(u)
	if status_text != "":
		var kind: String = STATUS_KIND.get(status_code, "info") if status_code != "" else "info"
		var col: Color = {"good": UiStyle.C_HP_PLAYER, "warn": UiStyle.C_GOLD, "error": UiStyle.C_HP_ENEMY, "info": UiStyle.C_TEXT_DIM}[kind]
		var mark: String = {"good": "●", "warn": "▲", "error": "×", "info": "※"}[kind]   # shape differs per kind, not only colour (all in Galmuri11)
		var line: Array = UiStyle.fit_text(mark + " " + status_text, detail_rect.size.x, UiStyle.FONT_S)
		UiStyle.draw_text_centered(self, line[0], Vector2(detail_rect.get_center().x, detail_rect.end.y - 8), UiStyle.FONT_S, col)
		status_kind_drawn = kind
	else:
		status_kind_drawn = ""

## Right pane, top to bottom: name + level, one-line description, [attack example], traits, stat rows (now -> next).
func _draw_detail(u: Dictionary) -> void:
	var r := detail_rect
	var locked := is_locked(u)
	var lv := level_of(str(u.id))
	var mx := int(u.get("max_level", 1))
	var lvt := UiText.t("upg.joins") % join_round(u) if locked else "Lv %d / %d" % [lv, mx]
	if hire_cost(u) > 0: lvt = UiText.t("upg.recruit_ready")
	lvt = UiStyle.fit_text(lvt, r.size.x * 0.52, UiStyle.FONT_S)[0]
	var lw := UiStyle.text_width(lvt, UiStyle.FONT_S)
	var name_fit: Array = UiStyle.fit_text(target_name(u), maxf(1.0, r.size.x - lw - 8), UiStyle.FONT_M)
	UiStyle.draw_text_left(self, name_fit[0], Vector2(r.position.x, r.position.y + 8), UiStyle.FONT_M, UiStyle.C_TEXT)
	UiStyle.draw_text_left(self, lvt, Vector2(r.end.x - lw, r.position.y + 8), UiStyle.FONT_S, UiStyle.C_GOLD if locked else UiStyle.C_TEXT_DIM)
	var d := target_def(u)
	var y := demo.position.y + demo.size.y + 10
	var traits := traits_text(u)
	if traits != "":      # drawn by traits_line
		y += 18
	# what the next level changes
	var maxed := is_max(u)
	var head := UiText.t("upg.maxed") if maxed else UiText.t("upg.next") % (lv + 1)
	if not maxed and not locked and _gated(u): head += "  ·  " + UiText.t("upg.gate") % gate_round(u)
	if hire_cost(u) > 0:
		UiStyle.draw_text_left(self, UiStyle.fit_text(UiText.t("upg.recruit_line") % hire_cost(u), r.size.x, UiStyle.FONT_S)[0], Vector2(r.position.x, y), UiStyle.FONT_S, UiStyle.C_GOLD)
		y += 18
	elif not locked:
		UiStyle.draw_text_left(self, UiStyle.fit_text(head, r.size.x, UiStyle.FONT_S)[0], Vector2(r.position.x, y), UiStyle.FONT_S, UiStyle.C_GOLD if not maxed else UiStyle.C_TEXT_DIM)
		y += 18
	var col_w := floorf(r.size.x / 2.0)
	var lines := stat_lines(u)
	for i in lines.size():
		var line: Dictionary = lines[i]
		var x := r.position.x + (i % 2) * col_w
		var ly := y + (i / 2) * 18
		var seg := [[str(line.label) + " ", UiStyle.C_TEXT_DIM], [str(line.now), UiStyle.C_TEXT]]
		if not maxed and not locked:
			seg.append([" → ", UiStyle.C_TEXT_DIM])
			seg.append([str(line.next), UiStyle.C_GOLD])
			if str(line.delta) != "": seg.append([" (" + str(line.delta) + ")", UiStyle.C_HP_PLAYER])
		for sg in seg:
			var tw := UiStyle.text_width(sg[0], UiStyle.FONT_S)
			if x + tw > r.position.x + (i % 2 + 1) * col_w: break
			UiStyle.draw_text_left(self, sg[0], Vector2(x, ly), UiStyle.FONT_S, sg[1])
			x += tw

var status_kind_drawn := ""     # QA

## Attack example: the character on the left swings / throws at a practice dummy standing at its real reach, on a
## loop as long as its attack interval. Shows reach (ground ruler), projectile, area (ring + extra dummies) and the
## damage number at the current level. Bakery upgrades show their icon only. Redraws ~15 times a second by itself.
class Demo extends Control:
	const UiStyle := preload("res://src/ui/ui_style.gd")
	const TRAINING := preload("res://assets/art/lobby/training.png")
	var def: Dictionary = {}
	var icon: Texture2D
	var atk := 0.0
	var locked := false
	var t := 0.0
	var _acc := 0.0
	var _page := ""               # atlas page held for the sprite

	func setup(p_def: Dictionary, p_icon: Texture2D, p_atk: float, p_locked: bool) -> void:
		var same: bool = not def.is_empty() and str(p_def.get("id", "")) == str(def.get("id", ""))
		def = p_def
		icon = p_icon
		atk = p_atk
		locked = p_locked
		if not same: t = 0.0
		_hold(str(_atlas().anim_sets.get(str(def.get("anim_set", "")), "")) if _atlas() != null and not def.is_empty() else "")
		queue_redraw()

	func _atlas() -> Node:
		return get_node_or_null("/root/Atlas") if is_inside_tree() else null

	func _hold(page: String) -> void:
		if page == _page: return
		var a := _atlas()
		if a != null:
			if _page != "": a.release(_page)
			if page != "" and not a.acquire(page): page = ""
		_page = page if a != null else ""

	func _exit_tree() -> void:
		_hold("")

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _page != "":
			_hold("")             # the panel closed: give the page back

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or def.is_empty(): return
		t += delta
		_acc += delta
		if _acc >= 1.0 / 15.0:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.30))
		if def.is_empty():
			if icon != null:
				var k := maxf(1.0, floorf((size.y - 16) / maxf(1.0, float(icon.get_height()))))
				var isz := Vector2(icon.get_size()) * k
				draw_texture_rect(icon, Rect2(((size - isz) / 2).round(), isz), false)
			return
		var gy := size.y - 14.0
		var tex_size := TRAINING.get_size()
		var source_width := minf(tex_size.x, size.x * tex_size.y / size.y)
		var source_x := floorf((tex_size.x - source_width) * 0.5)
		# The wall-to-floor seam in the crop is at pixel 98; keep it at the unit baseline.
		draw_texture_rect_region(TRAINING, Rect2(0, 0, size.x, gy), Rect2(source_x, 0, source_width, 98))
		draw_texture_rect_region(TRAINING, Rect2(0, gy, size.x, size.y - gy), Rect2(source_x, 98, source_width, tex_size.y - 98))
		draw_rect(Rect2(0, gy, size.x, 1), Color(1, 1, 1, 0.16))
		var rng := float(def.get("range", 20))
		# Widest sprites (hero, siege) reach 22 px left of the pivot, 44 px at 2x: keep them inside the frame.
		var ux := 50.0
		var px := (size.x - 66.0 - ux) / 180.0
		var tx := ux + clampf(rng * px, 30.0, size.x - 36.0 - ux)
		var splash := float(def.get("splash", 0))
		var ranged: bool = str(def.get("attack_type", "")) == "ranged" or rng >= 60.0
		# reach ruler on the ground
		draw_rect(Rect2(ux, gy + 4, tx - ux, 1), Color(UiStyle.C_GOLD, 0.55))
		draw_rect(Rect2(tx, gy + 1, 1, 7), Color(UiStyle.C_GOLD, 0.55))
		# one loop = swing, (flight), impact, rest
		var cycle := maxf(float(def.get("atk_interval", 1.0)), 0.9) + 0.4
		var ct := fmod(t, cycle)
		var a := _atlas()
		var rec = a.anim_rec(str(def.get("anim_set", "")), "attack") if a != null and _page != "" else null
		var hit_t := 0.35
		var swing_len := 0.5
		if rec != null:
			swing_len = rec.rects.size() / maxf(1.0, rec.fps)
			hit_t = (rec.hit_frame / maxf(1.0, rec.fps)) if rec.hit_frame >= 0 else swing_len * 0.6
		var fly := 0.24 if ranged else 0.0
		var impact := hit_t + fly
		var since := ct - impact               # seconds after the hit landed
		var hit_now := since >= 0.0 and since < 0.22
		# dummies
		var spots := [tx]
		if splash > 0.0: spots.append_array([tx + 15.0, tx + 30.0])
		for sx in spots:
			_dummy(Vector2(sx + (1.0 if hit_now and int(since * 40) % 2 == 0 else 0.0), gy), hit_now)
		var cream: bool = str(def.get("projectile", "")) == "cream"
		if cream:
			if since >= 0.0 and since < CREAM_LINGER: _cream_splat(spots, gy, since)
		elif splash > 0.0 and since >= 0.0 and since < 0.3:
			draw_arc(Vector2(tx + 15.0, gy - 6), maxf(12.0, splash * px + 8.0) * minf(1.0, 0.4 + since * 4.0), 0, TAU, 24, Color(1.0, 0.6, 0.2, 0.9 - since * 2.5), 1.0)
		# the character
		var mod := Color(1, 1, 1, 0.55) if locked else Color.WHITE
		var drawn := false
		if rec != null:
			var use = rec
			var fi := 0
			if ct < swing_len:
				fi = mini(int(ct * rec.fps), rec.rects.size() - 1)
			else:
				var idle = a.anim_rec(str(def.get("anim_set", "")), "idle")
				if idle != null:
					use = idle
					fi = int(ct * idle.fps) % idle.rects.size()
			var rr: Rect2 = use.rects[fi]
			var pv: Vector2 = use.pivots[fi]
			draw_texture_rect_region(use.tex, Rect2(Vector2(ux, gy) - pv * 2.0, rr.size * 2.0), rr, mod)
			drawn = true
		if not drawn and icon != null:
			var lunge := 5.0 if absf(ct - hit_t) < 0.1 else 0.0
			var isz := Vector2(icon.get_size()) * 2.0
			draw_texture_rect(icon, Rect2(Vector2(ux - isz.x / 2 + lunge, gy - isz.y).round(), isz), false, mod)
		# projectile
		if ranged and ct >= hit_t and ct < impact:
			var f := (ct - hit_t) / fly
			if cream:
				_cream_shot(Vector2(minf(ux + CREAM_TIP.x, tx - 8.0), gy - CREAM_TIP.y), Vector2(tx, gy - 16.0), f)
			else:
				var arc := 22.0 if str(def.get("projectile", "")) == "rock" else 8.0
				var p := Vector2(lerpf(ux + 10.0, tx, f), gy - 16.0 - sin(f * PI) * arc)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.08, 0.05, 0.04))
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.86, 0.5))
		# damage number at the current level
		if since >= 0.0 and since < 0.55 and atk > 0.0:
			UiStyle.draw_number(self, "-%d" % int(roundf(atk)), Vector2(tx, gy - 30.0 - since * 18.0), UiStyle.FONT_M, Color(UiStyle.C_HP_ENEMY, 1.0 - since * 1.4), 0, &"bold")

	# Cake: the cream leaves the tip of the burst in its hit frame (sprite px 52,30 against the 24,44 pivot, at 2x).
	const CREAM_TIP := Vector2(56.0, 28.0)
	const CREAM_LINGER := 0.6
	const CREAM := Color(1.0, 0.98, 0.94)
	const CREAM_SHADE := Color(0.85, 0.79, 0.66)

	# whipped-cream dollop, nose to the right: 1 cream, 2 shade (one row per string)
	const DOLLOP := ["..111...", ".111111.", "11111111", "1111111.", ".22222..."]

	## Cake shot: a dollop of whipped cream flying almost straight from the dispenser, two drops trailing behind.
	func _cream_shot(from: Vector2, to: Vector2, f: float) -> void:
		for i in [2, 1]:
			var g := clampf(f - float(i) * 0.12, 0.0, 1.0)
			if g <= 0.0: continue
			var p := (from.lerp(to, g) - Vector2(0.0, sin(g * PI) * 3.0 - float(i))).round()
			var s := 3.0 if i == 1 else 2.0
			draw_rect(Rect2(p + Vector2(0, 1), Vector2(s, s)), CREAM_SHADE)
			draw_rect(Rect2(p, Vector2(s, s)), CREAM)
		var o := (from.lerp(to, f) - Vector2(4.0, 3.0 + sin(f * PI) * 3.0)).round()
		for y in DOLLOP.size():
			var row: String = DOLLOP[y]
			for x in row.length():
				var ch := row[x]
				if ch != ".": draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), CREAM if ch == "1" else CREAM_SHADE)

	## Cake hit: cream bursts over the dummies, lands on their heads and pools on the ground, then fades.
	func _cream_splat(spots: Array, gy: float, since: float) -> void:
		var k := since / CREAM_LINGER
		var a := 1.0 - smoothstep(0.6, 1.0, k)
		var shade := Color(CREAM_SHADE, a)
		var fill := Color(CREAM, a)
		var x0: float = spots.front() - 10.0
		var x1: float = spots.back() + 10.0
		var spread := minf(1.0, since * 8.0)
		var mid := (x0 + x1) * 0.5
		var hw := (x1 - x0) * 0.5 * spread
		draw_rect(Rect2(roundf(mid - hw), gy - 2.0, roundf(hw * 2.0), 2.0), fill)
		for sx in spots:
			# a cap of cream on the head
			draw_rect(Rect2(sx - 5.0, gy - 27.0, 10.0, 3.0), shade)
			draw_rect(Rect2(sx - 4.0, gy - 29.0, 8.0, 3.0), fill)
			draw_rect(Rect2(sx - 1.0, gy - 31.0, 3.0, 2.0), fill)
		# flying blobs over the group for the first moment
		if since < 0.25:
			var up := sin(since / 0.25 * PI) * 10.0
			for i in 5:
				var bx := mid + (float(i) - 2.0) * maxf(8.0, hw * 0.45)
				var by := gy - 22.0 - up * (1.0 - absf(float(i) - 2.0) * 0.25)
				draw_rect(Rect2(roundf(bx) - 2.0, roundf(by), 4.0, 3.0), shade)
				draw_rect(Rect2(roundf(bx) - 2.0, roundf(by) - 1.0, 4.0, 3.0), fill)

	## Practice dummy: a post, a straw body and a head; turns pale for a moment when hit.
	func _dummy(p: Vector2, hit: bool) -> void:
		var straw := Color(1.0, 0.95, 0.85) if hit else Color(0.80, 0.62, 0.32)
		draw_rect(Rect2(p.x - 1, p.y - 8, 2, 8), Color(0.36, 0.22, 0.12))
		draw_rect(Rect2(p.x - 5, p.y - 20, 10, 12), Color(0.05, 0.04, 0.04))
		draw_rect(Rect2(p.x - 4, p.y - 19, 8, 10), straw)
		draw_rect(Rect2(p.x - 3, p.y - 26, 6, 6), Color(0.05, 0.04, 0.04))
		draw_rect(Rect2(p.x - 2, p.y - 25, 4, 4), straw.darkened(0.12))

## One line of text that fits its width or, when it is longer, slides left to its end and back to the start
## (holds 1.5 s at each end). Used for descriptions and trait lists, so nothing is cut off with an ellipsis.
class Marquee extends Control:
	const UiStyle := preload("res://src/ui/ui_style.gd")
	const HOLD := 1.5
	const SPEED := 28.0             # px per second
	var text := ""
	var color := UiStyle.C_TEXT_DIM
	var _t := 0.0
	var _acc := 0.0
	var _over := 0.0                # px the text is wider than the line

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_text(v: String) -> void:
		if v == text: return
		text = v
		_t = 0.0
		_measure()

	func _measure() -> void:
		_over = maxf(0.0, UiStyle.text_width(text, UiStyle.FONT_S) - size.x)
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: _measure()

	func scroll_x() -> float:
		if _over <= 0.0: return 0.0
		var c := fmod(_t, HOLD + _over / SPEED + HOLD)
		return roundf(clampf((c - HOLD) * SPEED, 0.0, _over))

	func _process(delta: float) -> void:
		if _over <= 0.0 or not is_visible_in_tree(): return
		_t += delta
		_acc += delta
		if _acc >= 0.05:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		if text != "":
			UiStyle.draw_text_left(self, text, Vector2(-scroll_x(), size.y / 2), UiStyle.FONT_S, color)
