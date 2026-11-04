extends Control
## Modal settings panel (fps cap, sfx, music, damage numbers). Owner: 04-client.
## Emits Events.cmd_set_setting(key, value); engine persists via Save (INTERFACES.md §1.2, §3).

signal closed

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const TouchButton := preload("res://src/ui/touch_button.gd")
const VolumeSlider := preload("res://src/ui/volume_slider.gd")

var bus: Node
var settings: Dictionary = {}
var panel_rect := Rect2()
var _rows: Array = []   # [{key, label, options:[[label,value],...], buttons:[]}]
var _close: Control
var _credits_btn: Control
var showing_credits := false   # credits view replaces the option rows (same modal, Back returns)
var credit_lines: Array = []  # QA: wrapped lines actually drawn
var target := 40.0
var row_h_used := 40.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # modal: swallow touches behind
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rows = [
		{"key": "fps_cap", "label": "ui.fps_cap", "options": [["30", 30], ["60", 60]]},
		{"key": "sfx", "label": "ui.sfx", "options": [], "volume": true},
		{"key": "music", "label": "ui.music", "options": [], "volume": true},
		{"key": "show_damage", "label": "ui.show_damage", "options": [["ui.on", true], ["ui.off", false]]},
		{"key": "screen_shake", "label": "ui.screen_shake", "options": [["ui.on", true], ["ui.off", false]]},
	]

func open(p_bus: Node, p_settings: Dictionary, view: Vector2, safe: Rect2, p_target: float) -> void:
	bus = p_bus
	settings = p_settings.duplicate()
	target = p_target
	size = view
	if _close == null:
		_build()
	_layout(view, safe)
	_refresh()
	show()

func _build() -> void:
	for row in _rows:
		row.buttons = []
		if row.get("volume", false):
			var slider := VolumeSlider.new()
			slider.preview.connect(_on_volume_preview.bind(row.key))
			slider.committed.connect(_on_volume_commit.bind(row.key))
			add_child(slider)
			row.slider = slider
		for opt in row.options:
			var b: Control = TouchButton.new()
			b.text = UiText.t(opt[0]) if str(opt[0]).begins_with("ui.") else str(opt[0])
			b.tapped.connect(_on_option.bind(row.key, opt[1]))
			add_child(b)
			row.buttons.append(b)
	_close = TouchButton.new()
	_close.text = UiText.t("ui.close")
	_close.fill = UiStyle.C_ACCENT.darkened(0.2)
	_close.tapped.connect(_on_close)
	add_child(_close)
	_credits_btn = TouchButton.new()
	_credits_btn.text = UiText.t("ui.credits")
	_credits_btn.tapped.connect(_on_credits)
	add_child(_credits_btn)

func _layout(view: Vector2, safe: Rect2) -> void:
	# rows + close button must fit the safe height; never below the 40 logical floor
	var row_h := clampf((safe.size.y - 16 - 54) / (_rows.size() + 1) - 4, 40.0, maxf(target, 40.0))
	var w := minf(safe.size.x - 16, 360.0)
	var h := 38 + _rows.size() * (row_h + 4) + row_h + 12   # 38: 24 px title fully inside the border
	panel_rect = Rect2((safe.get_center() - Vector2(w, h) / 2).round(), Vector2(w, h))
	row_h_used = row_h
	var y := panel_rect.position.y + 38
	var bw := maxf(target, 64.0)
	for row in _rows:
		if row.has("slider"):
			row.slider.position = Vector2(panel_rect.end.x - 204,y).round()
			row.slider.size = Vector2(196,row_h)
		var x: float = panel_rect.end.x - 8 - row.buttons.size() * (bw + 4) + 4
		for b in row.buttons:
			b.position = Vector2(x, y).round()
			b.size = Vector2(bw, row_h)
			x += bw + 4
		row.y = y
		y += row_h + 4
	_close.position = Vector2(panel_rect.get_center().x + 4, y + 4).round()
	_close.size = Vector2(100, row_h)
	_credits_btn.position = Vector2(panel_rect.get_center().x - 104, y + 4).round()
	_credits_btn.size = Vector2(100, row_h)
	_apply_mode()
	queue_redraw()

## Whether stored value `cur` corresponds to option value `opt` for this key.
static func option_matches(key: String, cur: Variant, opt: Variant) -> bool:
	match key:
		"fps_cap":
			return int(cur) == int(opt)
		"sfx", "music":
			return is_equal_approx(float(cur), float(opt))
		_:
			return bool(cur) == bool(opt)

func _refresh() -> void:
	for row in _rows:
		if row.has("slider"):
			row.slider.percent = roundi(clampf(float(settings.get(row.key, 0.8 if row.key == "music" else 1.0)),0.0,1.0)*100.0)
			continue
		var cur = settings.get(row.key, row.options[0][1])
		for i in row.buttons.size():
			var on := option_matches(row.key, cur, row.options[i][1])
			row.buttons[i].fill = UiStyle.C_ACCENT.darkened(0.15) if on else UiStyle.C_PANEL_LIGHT
			row.buttons[i].queue_redraw()
	queue_redraw()

func _on_option(key: String, value: Variant) -> void:
	settings[key] = value
	if bus != null and bus.has_signal(&"cmd_set_setting"):
		bus.cmd_set_setting.emit(key, value)
	_refresh()

func _on_volume_preview(value: float, key: String) -> void:
	settings[key] = value
	if bus != null and bus.has_signal(&"cmd_preview_volume"):
		bus.cmd_preview_volume.emit(key,value)

func _on_volume_commit(value: float, key: String) -> void:
	_on_option(key,value)

func _on_close() -> void:
	if showing_credits:
		showing_credits = false     # Back from credits returns to the settings rows
		_apply_mode()
		return
	hide()
	closed.emit()

func _on_credits() -> void:
	showing_credits = true
	_apply_mode()

func _apply_mode() -> void:
	for row in _rows:
		if row.has("slider"): row.slider.visible = not showing_credits
		for b in row.buttons:
			b.visible = not showing_credits
	if _credits_btn:
		_credits_btn.visible = not showing_credits
	if _close:
		_close.text = UiText.t("ui.back") if showing_credits else UiText.t("ui.close")
		_close.queue_redraw()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and preload("res://src/ui/ui_screen.gd").claim_back():
		_on_close()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.C_DIM)
	UiStyle.draw_pixel_box(self, panel_rect, UiStyle.C_PANEL)
	UiStyle.draw_text_centered(self, UiText.t("ui.credits") if showing_credits else UiText.t("ui.settings"), Vector2(panel_rect.get_center().x, panel_rect.position.y + 19), UiStyle.FONT_L)
	if showing_credits:
		# Galmuri11 12 only: Galmuri9 has no Hangul and no ©. Lines are word-wrapped, never shrunk.
		credit_lines = []
		for k in ["ui.font_credit"]:
			credit_lines.append_array(UiStyle.wrap_text(UiText.t(k), panel_rect.size.x - 24, UiStyle.FONT_S))
		credit_lines.append("")
		credit_lines.append_array(UiStyle.wrap_text("SIL Open Font License 1.1: assets/fonts/OFL-Galmuri.txt", panel_rect.size.x - 24, UiStyle.FONT_S))
		credit_lines.append_array(UiStyle.wrap_text("github.com/quiple/galmuri", panel_rect.size.x - 24, UiStyle.FONT_S))
		var y := panel_rect.position.y + 50
		for line in credit_lines:
			UiStyle.draw_text_left(self, line, Vector2(panel_rect.position.x + 12, y), UiStyle.FONT_S, UiStyle.C_TEXT)
			y += 18
		return
	for row in _rows:
		if row.has("y"):
			UiStyle.draw_text_left(self, UiText.t(row.label), Vector2(panel_rect.position.x + 12, row.y + row_h_used / 2), UiStyle.FONT_M)
