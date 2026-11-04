extends Control
## Percent volume with touch/mouse capture and 1% keyboard adjustment.
## Preview while dragging; persist once on release, hiding or focus loss.
const Style := preload("res://src/ui/ui_style.gd")
signal preview(value: float)
signal committed(value: float)
var percent := 100:
	set(value):
		percent = clampi(value, 0, 100)
		queue_redraw()
var _finger := -2 # -2 none, -1 mouse, >=0 touch
var _dirty := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

func track_width() -> float: return maxf(24.0, size.x - 52.0)

func _change(value: int) -> void:
	var next := clampi(value, 0, 100)
	if next == percent: return
	percent = next
	_dirty = true
	preview.emit(percent / 100.0)

func _seek(x: float) -> void:
	_change(roundi(100.0 * clampf((x - 8.0) / maxf(1.0, track_width() - 16.0), 0.0, 1.0)))

func _release() -> void:
	_finger = -2
	if _dirty:
		_dirty = false
		committed.emit(percent / 100.0)
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouse and e.device == InputEvent.DEVICE_ID_EMULATION: return
	if e is InputEventScreenTouch:
		if e.pressed and _finger == -2 and e.position.x <= track_width():
			_finger = e.index
			grab_focus()
			_seek(e.position.x)
		elif not e.pressed and e.index == _finger: _release()
		accept_event()
	elif e is InputEventScreenDrag and e.index == _finger:
		_seek(e.position.x)
		accept_event()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and _finger == -2 and e.position.x <= track_width():
			_finger = -1
			grab_focus()
			_seek(e.position.x)
		elif not e.pressed and _finger == -1: _release()
		accept_event()
	elif e is InputEventMouseMotion and _finger == -1:
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT: _seek(e.position.x)
		else: _release()
		accept_event()
	elif e is InputEventKey and e.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
		if e.pressed:
			match e.keycode:
				KEY_LEFT: _change(percent - 1)
				KEY_RIGHT: _change(percent + 1)
				KEY_HOME: _change(0)
				KEY_END: _change(100)
			_release()
		accept_event()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE, NOTIFICATION_FOCUS_EXIT] or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_release()
	elif what == NOTIFICATION_FOCUS_ENTER: queue_redraw()

func _draw() -> void:
	var w := track_width()
	var y := floorf(size.y * 0.5)
	draw_rect(Rect2(3,y-5,w-6,10),Style.C_EDGE)
	draw_rect(Rect2(5,y-3,w-10,6),Style.C_PANEL_LIGHT)
	var x := roundf(8.0 + (w-16.0) * percent / 100.0)
	draw_rect(Rect2(5,y-3,maxf(0,x-5),6),Style.C_GOLD)
	Style.draw_pixel_box(self,Rect2(x-6,y-12,12,24),Style.C_ACCENT if percent > 0 else Style.C_TEXT_DIM)
	if has_focus(): draw_rect(Rect2(0,1,w,size.y-2),Style.C_GOLD,false,1)
	Style.draw_text_centered(self,"%d%%" % percent,Vector2(size.x-23,y),Style.FONT_M,Style.C_TEXT)
