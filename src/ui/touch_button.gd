extends Control
## Multi-touch aware button. Owner: 04-client.
## Godot BaseButton only reacts to (emulated) mouse, so holding the hero ◀ button while tapping a
## card with a second finger would fail. This control tracks InputEventScreenTouch by finger
## index and ignores emulated mouse events (device == DEVICE_ID_EMULATION) to avoid double fire.
## Real mouse input (desktop) is also supported.

signal pressed_down
signal released(inside: bool)
signal tapped

enum Mode { TAP, HOLD }

@export var mode: Mode = Mode.TAP
@export var text := ""
@export var sub_text := ""        # small line under the main text (cost etc.)
@export var glyph: StringName = &""
@export var font_size := 12
var icon: Texture2D
var fill := Color(0.22, 0.25, 0.33, 0.95)
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
## 0..1 remaining cooldown (draws a top-down shade); 0 = ready.
var cooldown_ratio := 0.0:
	set(v):
		if not is_equal_approx(v, cooldown_ratio):
			cooldown_ratio = v
			queue_redraw()
var badge := ""                    # small corner label e.g. "x3", "MAX"
var dim_reason := ""               # shown centred when disabled (e.g. "가득")
var is_pressed := false
## Optional extra drawing on top of the button: func(button: Control) -> void
var overlay: Callable
var _finger := -2                  # -2 none, -1 mouse, >=0 touch index
const UiStyle := preload("res://src/ui/ui_style.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _finger == -2:
			_press(st.index)
			accept_event()
		elif not st.pressed and st.index == _finger:
			_release(Rect2(Vector2.ZERO, size).has_point(st.position))
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and _finger == -2:
			_press(-1)
			accept_event()
		elif not mb.pressed and _finger == -1:
			_release(Rect2(Vector2.ZERO, size).has_point(mb.position))
			accept_event()

func _press(finger: int) -> void:
	_finger = finger
	is_pressed = true
	queue_redraw()
	pressed_down.emit()

func _release(inside: bool) -> void:
	_finger = -2
	is_pressed = false
	queue_redraw()
	released.emit(inside)
	if inside:
		tapped.emit()

## Force release (app lost focus, screen hidden, battle ended).
func cancel() -> void:
	if _finger != -2:
		_release(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		cancel()

## Text rows inside the button (logical px): name uses Galmuri11 12 px, cost/badge use fixed-cell
## Galmuri9 10 px numerals. Layout adapts to height: >=54 → icon/name/cost rows; otherwise the name
## row is dropped when an icon is present (icon + cost), and text-only buttons centre one 12 px line.
var last_text_drawn := ""          # QA: text after ellipsis, as actually drawn
var last_text_truncated := false

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var f := fill if not disabled else UiStyle.C_DISABLED
	if is_pressed:
		f = f.darkened(0.25)
	UiStyle.draw_pixel_box(self, r, f, is_pressed)
	var off := Vector2(0, 1) if is_pressed else Vector2.ZERO
	var has_sub := sub_text != ""
	var has_visual := icon != null or glyph != &""
	var numeric_text := text != "" and text.is_valid_int()
	var show_name := text != "" and (not has_visual or not has_sub or size.y >= 54 or numeric_text)
	var tc := UiStyle.C_TEXT if not disabled else UiStyle.C_TEXT_DIM
	# vertical slots
	var cost_y := size.y - 9.0
	var name_y := (size.y - 21.0) if has_sub else (size.y - 10.0)
	var icon_bottom := (name_y - 7.0) if show_name and not numeric_text else (cost_y - 6.0 if has_sub else size.y - 4.0)
	var icon_c := Vector2(size.x / 2, (4.0 + icon_bottom) / 2.0) + off
	if not show_name and not has_sub:
		icon_c = Vector2(size.x / 2, size.y / 2) + off
	if not has_visual:
		name_y = size.y / 2 - (6.0 if has_sub else 0.0)
	if icon:
		# integer scale keeps pixel art crisp; never fractional
		var avail := minf(size.x - 8, icon_bottom - 4.0) if (show_name or has_sub) else minf(size.x - 8, size.y - 8)
		var isize := icon.get_size()
		var k := maxf(1.0, floorf(avail / maxf(isize.x, isize.y)))
		var dsz := isize * k
		var ir := Rect2((icon_c - dsz / 2).round(), dsz)
		draw_texture_rect(icon, ir, false, Color(1, 1, 1, 0.45) if disabled else Color.WHITE)
	elif glyph != &"":
		UiStyle.draw_glyph(self, glyph, icon_c, minf(size.x, icon_bottom) * 0.22, tc)
	if show_name:
		if numeric_text:
			# e.g. hero respawn countdown: big fixed-cell digits over the icon
			UiStyle.draw_number(self, text, Vector2(size.x / 2, size.y / 2) + off, UiStyle.NUM_L, UiStyle.C_HP_ENEMY, 0)
			last_text_drawn = text
			last_text_truncated = false
		else:
			var fit := UiStyle.fit_text(text, size.x - 6, font_size)
			last_text_drawn = fit[0]
			last_text_truncated = fit[0] != text
			UiStyle.draw_text_centered(self, fit[0], Vector2(size.x / 2, name_y) + off, font_size, tc)
	if has_sub:
		UiStyle.draw_number(self, sub_text, Vector2(size.x / 2, cost_y) + off, UiStyle.NUM_S, UiStyle.C_GOLD if not disabled else UiStyle.C_TEXT_DIM, 0)
	if cooldown_ratio > 0.0:
		var inner := r.grow(-2)
		var h := ceilf(inner.size.y * clampf(cooldown_ratio, 0, 1))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, h)), Color(0, 0, 0, 0.55))
	if badge != "":
		UiStyle.draw_number(self, badge, Vector2(size.x - 4, 9), UiStyle.NUM_S, UiStyle.C_ACCENT, 1)
	if disabled and dim_reason != "":
		var dr := Rect2(Vector2(2, size.y / 2 - 8), Vector2(size.x - 4, 16))
		draw_rect(dr, UiStyle.C_TOAST_BG)
		UiStyle.draw_text_centered(self, UiStyle.fit_text(dim_reason, size.x - 6, UiStyle.FONT_S)[0], dr.get_center(), UiStyle.FONT_S, UiStyle.C_HP_ENEMY)
	if overlay.is_valid():
		overlay.call(self)