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

## Overview strip, drawn to match the base HP strip beside it (same dark plate, same side colours):
##   lane track with the ground each side holds tinted in its colour (the front line is where the tints meet),
##   bakery and nest at the ends, allies as ticks above the lane and enemies below it (a boss is a larger block),
##   the hero as an outlined gold diamond, and the part of the lane on screen as corner brackets
##   (a full frame while the player is scouting away from the hero).
const C_ALLY := Color("5cd96b")
const C_FOE := Color("ed5a4d")
const C_INK := Color(0.05, 0.04, 0.04)

const MINIMAP_SKIN := preload("res://assets/art/hud_skin/minimap.png")

func _draw() -> void:
	# 18 px ink inside a 40-48 px touch area, level with the base HP strip
	draw_texture_rect(MINIMAP_SKIN, Rect2(0, 3, size.x, 18), false)
	if state.is_empty(): return
	var y := 12.0
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
	draw_rect(Rect2(7, y - 2, size.x - 14, 5), C_INK)
	draw_rect(Rect2(8, y - 1, size.x - 16, 3), Color(0.20, 0.15, 0.12))
	if af > bx: draw_rect(Rect2(bx, y - 1, af - bx, 3), Color(C_ALLY, 0.55))
	if ex > ef: draw_rect(Rect2(ef, y - 1, ex - ef, 3), Color(C_FOE, 0.55))
	# bakery (cream block, brown roof) and nest (grey-green mound), each with a dark outline
	draw_rect(Rect2(bx - 5, y - 7, 10, 10), C_INK)
	draw_rect(Rect2(bx - 4, y - 3, 8, 5), Color("e5c28c"))
	draw_rect(Rect2(bx - 4, y - 6, 8, 3), Color("ad7048"))
	draw_rect(Rect2(ex - 5, y - 7, 10, 10), C_INK)
	draw_rect(Rect2(ex - 4, y - 4, 8, 6), Color("7f9a8a"))
	draw_rect(Rect2(ex - 2, y - 6, 4, 2), Color("7f9a8a"))
	draw_rect(Rect2(ex - 1, y - 2, 2, 2), Color("2a3a34"))
	for dot in dots:
		var x := map_x(float(dot[0]))
		if int(dot[1]) > 0:
			draw_rect(Rect2(x - 1, y - 5, 2, 3), C_ALLY)
		elif bool(dot[2]):         # boss: a block with an outline, so it is not just "one more tick"
			draw_rect(Rect2(x - 3, y + 1, 6, 7), C_INK)
			draw_rect(Rect2(x - 2, y + 2, 4, 5), C_FOE)
			draw_rect(Rect2(x - 2, y + 2, 4, 1), Color("ffd0c0"))
		else:
			draw_rect(Rect2(x - 1, y + 3, 2, 3), C_FOE)
	if hero_on:
		for k in 2:
			var r := 4.0 - k
			var c := Vector2(hx, y - 5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), C_INK if k == 0 else Color("ffe19a"))
	# the part of the lane on screen
	var a := map_x(float(state.get("view_left", 0)))
	var b := maxf(a + 5.0, map_x(float(state.get("view_right", 1))))
	var top := 4.0
	var bot := 20.0
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
