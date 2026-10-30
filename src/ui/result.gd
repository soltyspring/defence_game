extends "res://src/ui/ui_screen.gd"
## Win / loss result screen. Owner: 04-client. Contract: INTERFACES.md §1.3 BattleResult.
## Emits cmd_retry, cmd_next_round, cmd_open_screen(&"round_select").

var result: Dictionary = {}
var btn_retry: Control
var btn_next: Control
var btn_menu: Control
var panel := Rect2()
var _shown_t := 0.0

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	btn_retry = make_button(UiText.t("ui.retry"), func(): emit_cmd(&"cmd_retry"))
	btn_next = make_button(UiText.t("ui.next"), func(): emit_cmd(&"cmd_next_round"))
	btn_next.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_menu = make_button(UiText.t("ui.menu"), func(): emit_cmd(&"cmd_open_screen", [&"round_select"]))
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
	reason_mismatch = false
	_apply()

func _apply() -> void:
	if btn_next == null:
		return
	var won := bool(result.get("won", false))
	btn_next.visible = won and str(result.get("next_round_id", "")) != ""
	btn_retry.fill = UiStyle.C_ACCENT.darkened(0.15) if not won else UiStyle.C_PANEL_LIGHT
	_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and btn_menu != null:
		emit_cmd(&"cmd_open_screen", [&"round_select"])

func _process(delta: float) -> void:
	if _shown_t < 1.0:
		_shown_t = minf(1.0, _shown_t + delta * 2.0)
		queue_redraw()

func _layout() -> void:
	if btn_retry == null:
		return
	var w := minf(safe.size.x - 24, 380.0)
	var h := minf(safe.size.y - 24, 260.0)
	panel = Rect2((safe.get_center() - Vector2(w, h) / 2).round(), Vector2(w, h))
	var bh := maxf(target, 40.0)
	var y := panel.end.y - bh - 12
	var buttons := [btn_menu, btn_retry]
	if btn_next.visible:
		buttons.append(btn_next)
	var bw := floorf((w - 24 - (buttons.size() - 1) * 8) / buttons.size())
	for i in buttons.size():
		place(buttons[i], Rect2(panel.position.x + 12 + i * (bw + 8), y, bw, bh))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), UiStyle.C_DIM)
	if result.is_empty():
		return
	UiStyle.draw_pixel_box(self, panel, UiStyle.C_PANEL)
	var won := bool(result.get("won", false))
	var cx := panel.get_center().x
	UiStyle.draw_text_centered(self, UiText.t("ui.victory") if won else UiText.t("ui.defeat"), Vector2(cx, panel.position.y + 30), UiStyle.FONT_XL, UiStyle.C_GOLD if won else UiStyle.C_HP_ENEMY, true, &"bold")
	var stars := int(result.get("stars", 0)) if won else 0
	var reasons := star_reasons()
	var t := float(result.get("time", 0))
	var lines := [
		[UiText.t("ui.time"), "%d:%02d" % [int(t) / 60, int(t) % 60]],
		[UiText.t("ui.kills"), str(int(result.get("kills", 0)))],
		[UiText.t("ui.reward"), "+%d" % int(result.get("coins", 0))],
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
		if not UiStyle.draw_ui_icon(self, "icon_star" if on else "icon_star_empty", Vector2(lx + 8, y)):
			UiStyle.draw_star(self, Vector2(lx + 8, y), 7.0, on)
		var fit: Array = UiStyle.fit_text(reasons[k].text, col_w - 22, UiStyle.FONT_S)
		UiStyle.draw_text_left(self, fit[0], Vector2(lx + 20, y), UiStyle.FONT_S, UiStyle.C_TEXT if met else UiStyle.C_TEXT_DIM)
		UiStyle.draw_text_left(self, lines[k][0], Vector2(rx, y), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
		UiStyle.draw_number(self, lines[k][1], Vector2(panel.end.x - 18, y), UiStyle.FONT_M, UiStyle.C_GOLD if k == 2 else UiStyle.C_TEXT, 1, &"bold")
	if bool(result.get("first_clear", false)) and won:
		UiStyle.draw_text_centered(self, UiText.t("ui.first_clear"), Vector2(cx, y0 + 3 * 22 + 6), UiStyle.FONT_M, UiStyle.C_ACCENT)
	if stars != reasons.filter(func(r): return r.met).size():
		# engine star count and UI reason derivation disagree: show engine count, flag for QA
		reason_mismatch = true

var reason_mismatch := false      # QA: UI reasons disagree with engine stars

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
