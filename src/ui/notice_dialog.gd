extends Control
## One-shot modal notice on the main menu: 01 D32 `notice.content_migrated` ({levels}, {coins}) after 02's content
## migration (52f9fa3: Events.content_migrated / Save.migration_notice / cmd_ack_content_migrated). Owner: 04-client.
## Dims the menu and swallows touches; the text wraps to at most 3 lines of Galmuri11 12 (never shrunk). `acknowledged`
## fires exactly once per opening, when the player closes it (button or Android back).

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const TouchButton := preload("res://src/ui/touch_button.gd")
const MAX_W := 420.0
const LINE_H := 16.0

signal acknowledged

var text := ""                    # QA: formatted notice as shown
var lines: PackedStringArray = [] # QA: wrapped lines as drawn
var truncated := false            # QA: true only if 3 lines were not enough (ellipsis on the last)
var panel := Rect2()
var btn_close: Control

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	btn_close = TouchButton.new()
	btn_close.text = UiText.t("ui.close")
	btn_close.fill = UiStyle.C_ACCENT.darkened(0.15)
	btn_close.tapped.connect(close)
	add_child(btn_close)

## Text formatting of 01's key with the engine's numbers.
static func format_notice(info: Dictionary) -> String:
	return UiText.t("notice.content_migrated").format({"levels": int(info.get("levels", 0)), "coins": int(info.get("coins", 0))})

func open(p_text: String, view: Vector2, safe: Rect2, target: float) -> void:
	text = p_text
	position = Vector2.ZERO
	size = view
	var w := minf(safe.size.x - 32.0, MAX_W)
	var fl: Dictionary = UiStyle.fit_lines(text, w - 24.0, UiStyle.FONT_M, 3)
	lines = fl.lines
	truncated = bool(fl.truncated)
	var bh := maxf(target, 40.0)
	var h := 16.0 + lines.size() * LINE_H + 14.0 + bh + 12.0
	panel = Rect2((safe.get_center() - Vector2(w, h) / 2.0).round(), Vector2(w, h))
	btn_close.position = Vector2(panel.get_center().x - 60.0, panel.end.y - 12.0 - bh).round()
	btn_close.size = Vector2(120, bh)
	visible = true
	move_to_front()
	queue_redraw()

func close() -> void:
	if not visible:
		return
	visible = false
	acknowledged.emit()

func _draw() -> void:
	# shapes first, then one text pass (08 R8 layer order)
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.C_DIM)
	UiStyle.draw_pixel_box(self, panel, UiStyle.C_PANEL)
	for i in lines.size():
		UiStyle.draw_text_centered(self, lines[i], Vector2(panel.get_center().x, panel.position.y + 16.0 + LINE_H * (i + 0.5)), UiStyle.FONT_M, UiStyle.C_TEXT)
