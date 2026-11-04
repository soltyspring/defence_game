extends Control
## A single, bounded CanvasItem: no textures, extra cameras, viewports or sim copies.
const Style := preload("res://src/ui/ui_style.gd")
const Text := preload("res://src/ui/ui_text.gd")
signal seek(world_x: float)
var state: Dictionary = {}:
	set(value):
		state = value
		queue_redraw()
var _mouse_down := false
var _finger := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = Text.t("ui.map_hint")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func world_at(local_x: float) -> float:
	var lo := float(state.get("left", 0.0))
	var hi := maxf(lo + 1.0, float(state.get("right", 1.0)))
	return lerpf(lo, hi, clampf((local_x - 12.0) / maxf(1.0, size.x - 24.0), 0.0, 1.0))

func map_x(world_x: float) -> float:
	var lo := float(state.get("left", 0.0))
	var hi := maxf(lo + 1.0, float(state.get("right", 1.0)))
	return roundf(12.0 + clampf((world_x - lo) / (hi - lo), 0.0, 1.0) * maxf(1.0, size.x - 24.0))

func _gui_input(event: InputEvent) -> void:
	if state.is_empty(): return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _finger < 0:
			_mouse_down = true
			seek.emit(world_at(event.position.x))
		elif not event.pressed:
			if _mouse_down: seek.emit(world_at(event.position.x))
			_mouse_down = false
		accept_event()
	elif event is InputEventMouseMotion and _mouse_down:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT: seek.emit(world_at(event.position.x))
		else: _mouse_down = false
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and _finger < 0 and not _mouse_down:
			_finger = event.index
			seek.emit(world_at(event.position.x))
		elif not event.pressed and event.index == _finger:
			seek.emit(world_at(event.position.x))
			_finger = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == _finger:
		seek.emit(world_at(event.position.x))
		accept_event()

func _notification(what: int) -> void:
	if (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()) or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_mouse_down = false
		_finger = -1

func _draw() -> void:
	# 20 px ink inside a 40–48 px touch area: the overview no longer owns a HUD row.
	Style.draw_pixel_box(self, Rect2(2, 4, size.x-4, 20), Color(0.12,0.16,0.16,0.82))
	if state.is_empty(): return
	var y := 15.0
	draw_rect(Rect2(10, y - 2, size.x - 20, 5), Color("68745a"))
	var bx := map_x(float(state.get("player_base", 0)))
	var ex := map_x(float(state.get("enemy_base", 1)))
	draw_rect(Rect2(bx - 4, y - 6, 8, 8), Color("e5c28c"))
	draw_rect(Rect2(bx - 6, y - 8, 12, 3), Color("ad7048"))
	draw_rect(Rect2(ex - 5, y - 7, 10, 9), Color("85999a"))
	for dot in state.get("dots", []):
		var x := map_x(float(dot[0]))
		var ally := int(dot[1]) > 0
		var h := 6.0 if bool(dot[2]) else 3.0
		draw_rect(Rect2(x - 1, y - 1 - h if ally else y + 3, 2, h), Color("70d7df") if ally else Color("ed9b78"))
	if bool(state.get("hero_alive", true)):
		var hx := map_x(float(state.get("hero", 0)))
		draw_colored_polygon(PackedVector2Array([Vector2(hx,y-10), Vector2(hx+3,y-6), Vector2(hx,y-2), Vector2(hx-3,y-6)]), Color("ffe19a"))
	var a := map_x(float(state.get("view_left", 0)))
	var b := map_x(float(state.get("view_right", 1)))
	draw_rect(Rect2(a, y - 9, maxf(3, b - a), 16), Color("ffe5a9"), false, 1.0)
