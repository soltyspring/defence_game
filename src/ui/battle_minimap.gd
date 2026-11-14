extends Control
## A single, bounded CanvasItem: no extra cameras, viewports or sim copies.
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

## Illustrated battlefield with live front lines, unit markers and camera bounds.
const Palette := preload("res://src/ui/battle_hud_palette.gd")
const C_ALLY := Palette.ALLY
const C_FOE := Palette.FOE

const MINIMAP_SKIN := preload("res://assets/art/hud_skin/minimap_illustrated.png")
const MARKERS := preload("res://assets/art/hud_skin/minimap_markers.png")
const FACE_HEIGHT := 22.0
const ALLY_MARK := Rect2(0, 0, 5, 6)
const FOE_MARK := Rect2(8, 0, 5, 6)
const BOSS_MARK := Rect2(16, 0, 7, 7)
const HERO_MARK := Rect2(24, 0, 7, 7)

func _marker(region: Rect2, x: float, y: float) -> void:
	var pos := (Vector2(x, y) - region.size * 0.5).round()
	draw_texture_rect_region(MARKERS, Rect2(pos, region.size), region)

func _draw() -> void:
	draw_texture_rect(MINIMAP_SKIN, Rect2(0, 0, size.x, FACE_HEIGHT), false)
	if state.is_empty(): return
	var y := 11.0 # between the two rows of markers
	var bx := map_x(float(state.get("player_base", 0)))
	var ex := map_x(float(state.get("enemy_base", 1)))
	var dots: Array = state.get("dots", [])
	var hero_on := bool(state.get("hero_alive", true))
	var hx := map_x(float(state.get("hero", 0)))
	# fronts: the furthest ally and the nearest enemy; where they overlap the line sits between them
	var af := bx
	var ef := ex
	if hero_on: af = maxf(af, hx)
	for dot in dots:
		var dx := map_x(float(dot[0]))
		if int(dot[1]) > 0: af = maxf(af, dx)
		else: ef = minf(ef, dx)
	if af > ef:
		af = roundf((af + ef) * 0.5)
		ef = af
	# Tint only the live front; the lane and both landmarks come from the illustration.
	var inset := 8.0
	if af > bx + inset: draw_rect(Rect2(bx + inset, y, af - bx - inset, 1), C_ALLY)
	if ex - inset > ef: draw_rect(Rect2(ef, y, ex - inset - ef, 1), C_FOE)
	for dot in dots:
		var x := map_x(float(dot[0]))
		if int(dot[1]) > 0:
			_marker(ALLY_MARK, x, y - 4.0)
		elif bool(dot[2]):
			_marker(BOSS_MARK, x, y + 4.5)
		else:
			_marker(FOE_MARK, x, y + 4.5)
	if hero_on:
		_marker(HERO_MARK, hx, y - 4.0)
	# the part of the lane on screen
	var a := map_x(float(state.get("view_left", 0)))
	var b := maxf(a + 5.0, map_x(float(state.get("view_right", 1))))
	var top := 2.0
	var bot := FACE_HEIGHT - 2.0
	var col := Color("ffe5a9")
	if bool(state.get("scouting", false)):
		draw_rect(Rect2(a, top, b - a, bot - top), Style.C_ACCENT, false, 1.0)
	else:
		for cx in [a, b - 1]:
			draw_rect(Rect2(cx, top, 1, 4), col)
			draw_rect(Rect2(cx, bot - 4, 1, 4), col)
		draw_rect(Rect2(a, top, 3, 1), col)
		draw_rect(Rect2(b - 3, top, 3, 1), col)
		draw_rect(Rect2(a, bot - 1, 3, 1), col)
		draw_rect(Rect2(b - 3, bot - 1, 3, 1), col)
