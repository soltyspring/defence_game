extends "res://src/ui/ui_screen.gd"
## Win / loss result screen. Owner: 04-client. Contract: INTERFACES.md §1.3 BattleResult.
## Emits cmd_retry, cmd_next_round, cmd_open_screen(&"round_select").

var result: Dictionary = {}
var btn_retry: Control
var btn_next: Control
var btn_menu: Control
var btn_upgrades: Control
var panel := Rect2()
var _shown_t := 0.0
var _fx_t := 0.0                   # result flourish clock: crown stars land, sparkles, coin count-up (1.6 s)

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	btn_retry = make_button(UiText.t("ui.retry"), func(): emit_cmd(&"cmd_retry"))
	btn_next = make_button(UiText.t("ui.next"), func(): emit_cmd(&"cmd_next_round"))
	btn_next.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_menu = make_button(UiText.t("ui.menu"), func(): emit_cmd(&"cmd_open_screen", [&"round_select"]))
	btn_upgrades = make_button(UiText.t("ui.upgrades"), open_upgrades)
	_apply()

func _bus_links() -> Array:
	return [
		[&"battle_ended", set_result],
		[&"screen_changed", _on_screen_changed],
	]

func _on_screen_changed(screen: StringName, params: Dictionary) -> void:
	if screen == &"result" and params.get("result") is Dictionary:
		set_result(params.result)

func ui_setup(params: Dictionary) -> void:
	if params.get("result") is Dictionary:
		set_result(params.result)
	elif params.has("won"):
		set_result(params)

func set_result(r: Dictionary) -> void:
	result = r
	_shown_t = 0.0
	_fx_t = 0.0
	reason_mismatch = false
	_apply()

func _apply() -> void:
	if btn_next == null:
		return
	var won := bool(result.get("won", false))
	btn_next.visible = won and bool(result.get("saved", true)) and str(result.get("next_round_id", "")) != ""
	btn_retry.fill = UiStyle.C_ACCENT.darkened(0.15) if not won else UiStyle.C_PANEL_LIGHT
	# coins now cover an upgrade: make 강화 stand out (first runs never opened it on their own)
	can_upgrade = _affordable_upgrade()
	btn_upgrades.fill = UiStyle.C_GOLD.darkened(0.35) if can_upgrade else UiStyle.C_PANEL_LIGHT
	btn_upgrades.badge = "!" if can_upgrade else ""
	_layout()
	queue_redraw()

var can_upgrade := false

func _affordable_upgrade() -> bool:
	var sv := autoload("Save")
	var c := autoload("Content")
	if sv == null or c == null or not sv.has_method("upgrade_cost"): return false
	var coins := int(sv.progress.get("coins", 0))
	for u in c.meta.get("upgrades", []):
		if sv.has_method("upgrade_locked") and sv.upgrade_locked(str(u.id)): continue
		var cost := int(sv.upgrade_cost(str(u.id), int(sv.upgrade_level(str(u.id))) + 1))
		if cost > 0 and cost <= coins: return true
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and btn_menu != null and not modal_open() and claim_back():
		emit_cmd_deferred(&"cmd_open_screen", [&"round_select"])   # deferred: not inside the notification walk

func _process(delta: float) -> void:
	if _shown_t < 1.0:
		_shown_t = minf(1.0, _shown_t + delta * 2.0)
		queue_redraw()
	if _fx_t < 1.6:
		_fx_t = minf(1.6, _fx_t + delta)
		queue_redraw()

func _layout() -> void:
	if btn_retry == null:
		return
	var w := minf(safe.size.x - 24, 380.0)
	var h := minf(safe.size.y - 24, 260.0)
	panel = Rect2((safe.get_center() - Vector2(w, h) / 2).round(), Vector2(w, h))
	var bh := maxf(target, 40.0)
	var y := panel.end.y - bh - 12
	var buttons := [btn_menu, btn_upgrades, btn_retry]
	if btn_next.visible:
		buttons.append(btn_next)
	var bw := floorf((w - 24 - (buttons.size() - 1) * 8) / buttons.size())
	for i in buttons.size():
		place(buttons[i], Rect2(panel.position.x + 12 + i * (bw + 8), y, bw, bh))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), UiStyle.C_DIM)
	if result.is_empty():
		return
	var won := bool(result.get("won", false))
	UiStyle.draw_pixel_box(self, panel, UiStyle.C_PANEL)
	var cx := panel.get_center().x
	if won:
		_draw_crown_stars(cx, int(result.get("stars", 0)))
	else:
		# defeat: a muted red rim instead of the crown
		draw_rect(panel.grow(-3), Color(UiStyle.C_HP_ENEMY, 0.55), false, 2.0)
	UiStyle.draw_text_centered(self, UiText.t("ui.victory") if won else UiText.t("ui.defeat"), Vector2(cx, panel.position.y + 30), UiStyle.FONT_XL, UiStyle.C_GOLD if won else UiStyle.C_HP_ENEMY, true, &"bold")
	if not bool(result.get("saved", true)):
		UiStyle.draw_text_centered(self, UiText.t("toast.save_failed"), Vector2(cx, panel.position.y + 48), UiStyle.FONT_S, UiStyle.C_HP_ENEMY)
	var stars := int(result.get("stars", 0)) if won else 0
	var reasons := star_reasons()
	var t := float(result.get("time", 0))
	var seconds := ceili(t)
	var lines := [
		[UiText.t("ui.time"), "%d:%02d" % [seconds / 60, seconds % 60]],
		[UiText.t("ui.kills"), str(int(result.get("kills", 0)))],
		[UiText.t("ui.reward"), "+%d" % _counted_coins()],
	]
	# two columns: left = star conditions (met/unmet), right = stats. 22 px rows (12 px text grid).
	var lx := panel.position.x + 18
	var col_w := floorf((panel.size.x - 36) / 2.0) - 6
	var rx := panel.position.x + 18 + col_w + 12
	var y0 := panel.position.y + 70
	for k in 3:
		var y := y0 + k * 22
		var met: bool = reasons[k].met
		var on := met and _shown_t >= (k + 1) / 4.0     # stars pop in one by one
		row_markers[k] = UiStyle.draw_star_marker(self, Vector2(lx + 8, y), on)
		if met and not on:
			row_markers[k] = "pending"
		var fit: Array = UiStyle.fit_text(reasons[k].text, col_w - 22, UiStyle.FONT_S)
		UiStyle.draw_text_left(self, fit[0], Vector2(lx + 20, y), UiStyle.FONT_S, UiStyle.C_TEXT if met else UiStyle.C_TEXT_DIM)
		UiStyle.draw_text_left(self, lines[k][0], Vector2(rx, y), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
		UiStyle.draw_number(self, lines[k][1], Vector2(panel.end.x - 18, y), UiStyle.FONT_M, UiStyle.C_GOLD if k == 2 else UiStyle.C_TEXT, 1, &"bold")
	if bool(result.get("first_clear", false)) and won:
		UiStyle.draw_text_centered(self, UiText.t("ui.first_clear"), Vector2(cx, y0 + 3 * 22 + 6), UiStyle.FONT_M, UiStyle.C_ACCENT)
	if won and can_upgrade:
		UiStyle.draw_text_centered(self, UiText.t("ui.upgrade_hint"), Vector2(cx, y0 + 3 * 22 + 26), UiStyle.FONT_S, UiStyle.C_GOLD)
	if not won and str(result.get("round_id", "")) == "r05":
		for i in 2:
			var hint := UiText.t("hint.loss.r05.tactic" if i == 0 else "hint.loss.upgrade")
			var fit := UiStyle.fit_text(hint, panel.size.x - 24, UiStyle.FONT_S)
			UiStyle.draw_text_centered(self, fit[0], Vector2(cx, y0 + 3 * 22 + 14 + i * 18), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	elif not won and str(result.get("hint", "")) != "" and UiText.has("hint.loss." + str(result.hint)):
		# every other defeat: one line taken from what happened in this battle (BattleResult.hint)
		loss_hint_shown = str(result.hint)
		var fit2 := UiStyle.fit_text(UiText.t("hint.loss." + loss_hint_shown), panel.size.x - 24, UiStyle.FONT_S)
		UiStyle.draw_text_centered(self, fit2[0], Vector2(cx, y0 + 3 * 22 + 14), UiStyle.FONT_S, UiStyle.C_TEXT)
	if stars != reasons.filter(func(r): return r.met).size():
		# engine star count and UI reason derivation disagree: show engine count, flag for QA
		reason_mismatch = true

## Coins tick up from 0 once the stars have landed (the number QA reads stays result.coins).
func _counted_coins() -> int:
	var coins := int(result.get("coins", 0))
	return int(roundf(coins * clampf((_fx_t - 0.55) / 0.6, 0.0, 1.0)))

## Three big stars sitting on the panel's top edge (middle one raised). Earned ones land one by one with a
## short overshoot and a ring of gold pixels; unearned slots stay as hollow outlines.
func _draw_crown_stars(cx: float, stars: int) -> void:
	# a crust tab behind the stars so they never sit on the dimmed HUD text
	UiStyle.draw_pixel_box(self, Rect2(cx - 66.0, panel.position.y - 26.0, 132.0, 34.0), UiStyle.C_PANEL)
	for k in 3:
		var c := Vector2(cx + (k - 1) * 42.0, panel.position.y - (10.0 if k == 1 else 5.0))
		var age := _fx_t - (0.15 + k * 0.2)
		if k >= stars or age < 0.0:
			UiStyle.draw_star_hollow(self, c, 13.0 if k == 1 else 9.0)
			continue
		var base := 3.0 if k == 1 else 2.0      # whole-pixel scales once landed
		var sc := base * (1.0 + 0.45 * maxf(0.0, 1.0 - age / 0.16)) if age < 0.16 else base
		if not UiStyle.draw_ui_icon(self, "icon_star", c, sc):
			UiStyle.draw_star(self, c, 8.0 * sc, true)
		if age < 0.45:
			var a := 1.0 - age / 0.45
			for i in 8:
				var dir := Vector2.RIGHT.rotated(i * TAU / 8.0 + k)
				var p := (c + dir * (12.0 + age * 60.0)).round()
				var s := 3.0 if i % 2 == 0 else 2.0
				draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(1.0, 0.9, 0.45, a))

var reason_mismatch := false      # QA: UI reasons disagree with engine stars
var loss_hint_shown := ""         # QA: hint id drawn on the last defeat panel
var row_markers := ["", "", ""]   # QA: "filled" | "hollow" | "pending" (pop-in not reached yet)

## Star conditions (INTERFACES §2.4: 1 = win, +1 base hp ≥ base_hp_2, +1 time ≤ time_3) with
## the round's real thresholds from Content when available. Returns [{met, text}] ×3.
func star_reasons() -> Array:
	var won := bool(result.get("won", false))
	var rules := {}
	var c := autoload("Content")
	if c != null and c.has_method("get_round"):
		rules = (c.get_round(str(result.get("round_id", ""))) as Dictionary).get("stars", {})
	if result.get("star_rules") is Dictionary:
		rules = result.star_rules
	var ratio := float(result.get("player_base_ratio", -1.0))
	var t := float(result.get("time", 0.0))
	var out := [{"met": won, "text": UiText.t("ui.star_win")}]
	if rules.has("base_hp_2"):
		var need := float(rules.base_hp_2)
		out.append({"met": won and ratio >= need, "text": UiText.t("ui.star_base_hp") % int(roundf(need * 100))})
	else:
		out.append({"met": won and int(result.get("stars", 0)) >= 2, "text": UiText.t("ui.star_base_hp_any")})
	if rules.has("time_3"):
		out.append({"met": won and t <= float(rules.time_3), "text": UiText.t("ui.star_time") % int(rules.time_3)})
	else:
		out.append({"met": won and int(result.get("stars", 0)) >= 3, "text": UiText.t("ui.star_time_any")})
	return out
