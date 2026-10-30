extends Control
## Modal settings panel (fps cap, sfx, music, damage numbers). Owner: 04-client.
## Emits Events.cmd_set_setting(key, value); engine persists via Save (INTERFACES.md §1.2, §3).

signal closed

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const TouchButton := preload("res://src/ui/touch_button.gd")

var bus: Node
var settings: Dictionary = {}
var panel_rect := Rect2()
var _rows: Array = []   # [{key, label, options:[[label,value],...], buttons:[]}]
var _close: Control
var target := 40.0
var row_h_used := 40.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # modal: swallow touches behind
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rows = [
		{"key": "fps_cap", "label": "ui.fps_cap", "options": [["30", 30], ["60", 60]]},
		{"key": "sfx", "label": "ui.sfx", "options": [["ui.on", 1.0], ["ui.off", 0.0]]},
		{"key": "music", "label": "ui.music", "options": [["ui.on", 0.8], ["ui.off", 0.0]]},
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

func _layout(view: Vector2, safe: Rect2) -> void:
	# rows + close button must fit the safe height; never below the 40 logical floor
	var row_h := clampf((safe.size.y - 16 - 46) / (_rows.size() + 1) - 4, 40.0, maxf(target, 40.0))
	var w := minf(safe.size.x - 16, 360.0)
	var h := 30 + _rows.size() * (row_h + 4) + row_h + 12
	panel_rect = Rect2((safe.get_center() - Vector2(w, h) / 2).round(), Vector2(w, h))
	row_h_used = row_h
	var y := panel_rect.position.y + 30
	var bw := maxf(target, 64.0)
	for row in _rows:
		var x: float = panel_rect.end.x - 8 - row.buttons.size() * (bw + 4) + 4
		for b in row.buttons:
			b.position = Vector2(x, y).round()
			b.size = Vector2(bw, row_h)
			x += bw + 4
		row.y = y
		y += row_h + 4
	_close.position = Vector2(panel_rect.get_center().x - 50, y + 4).round()
	_close.size = Vector2(100, row_h)
	queue_redraw()

## Whether stored value `cur` corresponds to option value `opt` for this key.
static func option_matches(key: String, cur: Variant, opt: Variant) -> bool:
	match key:
		"fps_cap":
			return int(cur) == int(opt)
		"sfx", "music":
			return (float(cur) > 0.0) == (float(opt) > 0.0)   # volume: any >0 is "on"
		_:
			return bool(cur) == bool(opt)

func _refresh() -> void:
	for row in _rows:
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

func _on_close() -> void:
	hide()
	closed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		_on_close()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.C_DIM)
	UiStyle.draw_pixel_box(self, panel_rect, UiStyle.C_PANEL)
	UiStyle.draw_text_centered(self, UiText.t("ui.settings"), Vector2(panel_rect.get_center().x, panel_rect.position.y + 15), UiStyle.FONT_L)
	for row in _rows:
		if row.has("y"):
			UiStyle.draw_text_left(self, UiText.t(row.label), Vector2(panel_rect.position.x + 12, row.y + row_h_used / 2), UiStyle.FONT_M)
