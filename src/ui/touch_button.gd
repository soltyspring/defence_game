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
# Every visual property redraws ONLY when its value changes (08 H15/H18: the HUD assigns all of them
# 10×/s; unconditional queue_redraw() re-ran text measuring on ~12 buttons per snapshot).
@export var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
@export var sub_text := "":       # small line under the main text (cost etc.)
	set(v):
		if v != sub_text:
			sub_text = v
			queue_redraw()
@export var glyph: StringName = &"":
	set(v):
		if v != glyph:
			glyph = v
			queue_redraw()
@export var font_size := 12:
	set(v):
		if v != font_size:
			font_size = v
			queue_redraw()
var icon: Texture2D:
	set(v):
		if v != icon:
			icon = v
			queue_redraw()
var fill: Color = preload("res://src/ui/ui_style.gd").C_PANEL_LIGHT:   # default fill follows the chrome palette (03 A10)
	set(v):
		if v != fill:
			fill = v
			queue_redraw()
var disabled := false:
	set(v):
		if v != disabled:
			disabled = v
			queue_redraw()
## 0..1 remaining cooldown (draws a top-down shade); 0 = ready.
var cooldown_ratio := 0.0:
	set(v):
		if not is_equal_approx(v, cooldown_ratio):
			var before := ceilf((size.y - 4) * clampf(cooldown_ratio, 0, 1))
			cooldown_ratio = v
			if ceilf((size.y - 4) * clampf(v, 0, 1)) != before:
				queue_redraw()   # only when the shade's whole-pixel height changes
var cooldown_left := 0.0:            # seconds until ready; shown as a big number while > 0.5, only on buttons without an icon
	set(v):
		if ceili(v) != ceili(cooldown_left):
			cooldown_left = v
			queue_redraw()
		else:
			cooldown_left = v
var badge := "":                   # small corner label e.g. "x3", "MAX"
	set(v):
		if v != badge:
			badge = v
			queue_redraw()
var dim_reason := "":              # shown centred when disabled (e.g. "가득")
	set(v):
		if v != dim_reason:
			dim_reason = v
			queue_redraw()
var is_pressed := false
## Optional extra drawing on top of the button: func(button: Control) -> void
var overlay: Callable
var illustration: Texture2D
var face_texture: Texture2D
var face_tint := Color.WHITE:
	set(v):
		if face_tint != v:
			face_tint = v
			queue_redraw()
var _finger := -2                  # -2 none, -1 mouse, >=0 touch index
const UiStyle := preload("res://src/ui/ui_style.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	get_viewport().size_changed.connect(cancel)

func _input(event: InputEvent) -> void:
	# Finish captured pointers even when the release is routed outside this Control
	# after a resize, drag or a DPI transition. GUI-local release alone can leave a
	# held button latched and reject every later click.
	if _finger == -2: return
	var release := false
	if event is InputEventScreenTouch:
		release = not event.pressed and event.index == _finger
	elif event is InputEventMouseButton:
		release = event.device != InputEvent.DEVICE_ID_EMULATION and _finger == -1 and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventMouseMotion and _finger == -1 and event.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		cancel()
	if release:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO,size).has_point(local)
		if event is InputEventScreenTouch and event.canceled: inside = false
		_release(inside)
		get_viewport().set_input_as_handled()

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
var last_line_count := 1
## Max name lines (round tiles use 2: long theme names wrap instead of ellipsizing, 07 QA-B010)
var wrap_lines := 1
## &"rect" (unit cards, default) or &"econ" (worker: octagon + dough band, 07 QA-J3)
var shape: StringName = &"rect"

## 08 R8: drawn in passes (shapes → icon → text → overlay shapes → overlay text) so a card costs ~3 draw calls
## instead of 7–11 (every rect/texture/glyph-cache switch starts a new draw call). Positions and colours unchanged.
var passes_drawn := 0              # QA

func _draw_fast_forward() -> void:
	# Draw only the symbol; the Control still owns the full touch rectangle.
	var center := (size * 0.5).round()
	var active := text == "x2"
	var tint := Color("ffd27a") if active else Color("fff0d2")
	if is_pressed: tint = tint.darkened(0.25)
	for x in [-10.0, 0.0]:
		var p := center + Vector2(x, 0)
		var tri := PackedVector2Array([p + Vector2(0, -6), p + Vector2(9, 0), p + Vector2(0, 6)])
		draw_colored_polygon(tri, tint if active or x == -10.0 else Color("a69a89"))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("231818"), 2.0)

func _draw() -> void:
	if shape == &"fast_forward":
		_draw_fast_forward()
		return
	var r := Rect2(Vector2.ZERO, size)
	var f := fill if not disabled else UiStyle.C_DISABLED
	if is_pressed:
		f = f.darkened(0.25)
	# ---- pass 1: shapes
	if face_texture != null:
		draw_texture_rect(face_texture, r, false, face_tint.darkened(0.25) if is_pressed else face_tint)
	elif shape == &"econ":
		UiStyle.draw_pixel_octagon(self, r, f, UiStyle.C_GOLD if not disabled else UiStyle.C_TEXT_DIM, is_pressed)
	else:
		UiStyle.draw_pixel_box(self, r, f, is_pressed)
	if illustration != null:
		var inner := r.grow(-3)
		var pixels := illustration.get_size()
		var source_size := pixels / maxf(pixels.x / inner.size.x, pixels.y / inner.size.y)
		# Keep the quiet bottom of the card when cropping to fit.
		var source := Rect2(Vector2((pixels.x - source_size.x) * 0.5, pixels.y - source_size.y), source_size)
		draw_texture_rect_region(illustration, inner, source, Color(0.74, 0.74, 0.74) if is_pressed else Color.WHITE)
		draw_rect(Rect2(3, size.y - 35, size.x - 6, 32), Color(0.12, 0.08, 0.06, 0.67))
	var off := Vector2(0, 1) if is_pressed else Vector2.ZERO
	var has_sub := sub_text != ""
	var has_visual := icon != null or glyph != &""
	# on cooldown with a picture: no seconds, no curtain; the whole button is greyed and clears as the cooldown runs out
	var cd_fade := has_visual and cooldown_ratio > 0.0
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
	if illustration != null:
		name_y = size.y - 19.0
	# ---- pass 2: icon (ui_main page) or its vector stand-in
	if icon:
		# integer scale keeps pixel art crisp; never fractional
		var avail := minf(size.x - 8, icon_bottom - 4.0) if (show_name or has_sub) else minf(size.x - 8, size.y - 8)
		var isize := icon.get_size()
		var k := maxf(1.0, floorf(avail / maxf(isize.x, isize.y)))
		var dsz := isize * k
		var ir := Rect2((icon_c - dsz / 2).round(), dsz)
		# disabled: grey body + dim cost show the off state; the icon stays at α .70 so unit pairs remain
		# distinguishable (06 R3 Ask B: at .45, 4–5 card pairs fail 07 U1 shape distance; at .70 all ≥ 13.5)
		draw_texture_rect(icon, ir, false, Color(1, 1, 1, 0.70) if disabled else Color.WHITE)
	elif glyph != &"":
		UiStyle.draw_glyph(self, glyph, icon_c, minf(size.x, icon_bottom) * 0.22, tc)
	# ---- pass 3: text (name + cost share Galmuri11 12 = one glyph cache)
	if show_name:
		if numeric_text:
			# e.g. hero respawn countdown: big fixed-cell digits over the icon
			UiStyle.draw_number(self, text, Vector2(size.x / 2, size.y / 2) + off, UiStyle.NUM_L, UiStyle.C_HP_ENEMY, 0)
			last_text_drawn = text
			last_text_truncated = false
		else:
			var fl: Dictionary = UiStyle.fit_lines(text, size.x - 6, font_size, wrap_lines)
			var lines: PackedStringArray = fl.lines
			last_text_drawn = " ".join(lines)
			last_text_truncated = bool(fl.truncated)
			last_line_count = lines.size()
			var lh := 14.0
			# single line: as before; several lines: centred block (or bottom-anchored under an icon)
			var y0: float = name_y - (lines.size() - 1) * lh / 2.0
			if has_visual and lines.size() > 1:
				y0 = name_y - (lines.size() - 1) * lh
			for li in lines.size():
				UiStyle.draw_text_centered(self, lines[li], Vector2(size.x / 2, y0 + li * lh) + off, fl.size, tc, true, fl.kind)
	if has_sub:
		UiStyle.draw_number(self, sub_text, Vector2(size.x / 2, cost_y) + off, UiStyle.NUM_READ, UiStyle.C_GOLD if not disabled else UiStyle.C_TEXT_DIM, 0, UiStyle.NUM_READ_KIND)
	passes_drawn = 3
	# ---- pass 4: overlay shapes (must cover icon and name): cooldown shade, dim-reason strip
	var reason := disabled and dim_reason != ""
	var dr := Rect2(Vector2(2, size.y / 2 - 8), Vector2(size.x - 4, 16))
	if cooldown_ratio > 0.0:
		var inner := r.grow(-2)
		if cd_fade:
			draw_rect(inner, Color(0.10, 0.10, 0.13, 0.72 * clampf(cooldown_ratio, 0, 1)))
		else:
			var h := ceilf(inner.size.y * clampf(cooldown_ratio, 0, 1))
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, h)), Color(0, 0, 0, 0.55))
	if reason:
		draw_rect(dr, UiStyle.C_TOAST_BG)
	if cooldown_ratio > 0.0 or reason:
		passes_drawn += 1
	# ---- pass 5: overlay text (stays readable on top of the shade)
	if badge != "":
		UiStyle.draw_number(self, badge, Vector2(size.x - 4, 9), UiStyle.NUM_READ, UiStyle.C_ACCENT, 1, UiStyle.NUM_READ_KIND)
	if reason:
		UiStyle.draw_text_centered(self, UiStyle.fit_text(dim_reason, size.x - 6, UiStyle.FONT_S)[0], dr.get_center(), UiStyle.FONT_S, UiStyle.C_HP_ENEMY)
	if not cd_fade and cooldown_ratio > 0.0 and cooldown_left > 0.5 and not reason:
		UiStyle.draw_text_centered(self, str(ceili(cooldown_left)), Vector2(size.x / 2, size.y * 0.42), UiStyle.FONT_L, Color.WHITE)
	if overlay.is_valid():
		overlay.call(self)
