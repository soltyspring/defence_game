extends "res://src/ui/ui_screen.gd"

const Catalog := preload("res://src/core/gold_shop_catalog.gd")
var btn_back: Control
var pack_buttons: Array[Control] = []
var receipt := ""
var credit_busy := false

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	btn_back = make_button(UiText.t("ui.back"), _back)
	for amount: int in Catalog.PACKS:
		var digits := Catalog.formatted(amount)
		var b := make_button(UiText.t("shop.pack") % digits, _buy.bind(amount))
		b.sub_text = UiText.t("shop.price") % digits
		pack_buttons.append(b)

func _buy(amount: int) -> void:
	if credit_busy: return
	var save := autoload("Save")
	if save == null: return
	credit_busy = true
	var code: String = save.buy_preview_gold(amount)
	credit_busy = false
	receipt = UiText.t("shop." + code)
	if code == "ok": receipt = receipt % Catalog.formatted(amount)
	if code == "save_uncertain" or code == "read_only":
		for button in pack_buttons: button.disabled = true
	queue_redraw()

func _back() -> void:
	emit_cmd_deferred(&"cmd_open_screen", [&"menu"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree() and claim_back():
		_back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _layout() -> void:
	if btn_back == null: return
	var t := maxf(target, 40.0)
	place(btn_back, Rect2(safe.position + Vector2(6, 6), Vector2(76, t)))
	var cols := 4 if safe.size.x >= 540 or safe.size.y < 208 else 2
	var rows := 4 / cols
	var width := clampf(safe.size.x - 24.0, 1.0, 600.0)
	var gap := 8.0
	var bw := floorf((width - (cols - 1) * gap) / cols)
	var start_y := safe.position.y + t + (58.0 if safe.size.y >= 208 else 24.0)
	var bh := maxf(32.0, minf(94.0, floorf((safe.end.y - 30.0 - start_y - (rows - 1) * gap) / rows)))
	var left := safe.get_center().x - (bw * cols + gap * (cols - 1)) * 0.5
	for i in pack_buttons.size():
		place(pack_buttons[i], Rect2(left + (i % cols) * (bw + gap), start_y + (i / cols) * (bh + gap), bw, bh))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), UiStyle.C_BG)
	if btn_back == null: return
	var x := safe.get_center().x
	var y := safe.position.y
	var compact := safe.size.y < 208
	var t := maxf(target, 40.0)
	UiStyle.draw_text_centered(self, UiText.t("shop.title"), Vector2(x, y + 6 + t * 0.5), UiStyle.FONT_M if compact else UiStyle.FONT_L)
	var balance := UiText.t("shop.balance") % Catalog.formatted(int(progress().get("coins", 0)))
	UiStyle.draw_text_centered(self, balance, Vector2(x, y + t + 15), UiStyle.FONT_M, UiStyle.C_GOLD)
	if not compact:
		UiStyle.draw_text_centered(self, UiText.t("shop.preview"), Vector2(x, y + t + 35), UiStyle.FONT_S)
	var msg := receipt if not receipt.is_empty() else UiText.t("shop.preview_short")
	var fitted := UiStyle.fit_text(msg, maxf(1.0, safe.size.x - 16.0), UiStyle.FONT_S)
	UiStyle.draw_text_centered(self, fitted[0], Vector2(x, safe.end.y - 15), UiStyle.FONT_S)
