extends Control
## Tutorial pointer: a pulsing gold ring around the button the current hint is about, and a bouncing arrow
## above it, so a new player finds "the 식빵병 card" without reading the whole screen. Never takes input.
## Owner: 04-client (hud.gd sets `target`; null hides it).

const UiStyle := preload("res://src/ui/ui_style.gd")

var target: Control = null:
	set(v):
		target = v
		_t = 0.0
		queue_redraw()
var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	if target != null:
		_t += dt
		queue_redraw()

func _draw() -> void:
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var r := Rect2(target.global_position - global_position, target.size)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var grow := roundf(2.0 + 2.0 * pulse)
	var ring := r.grow(grow)
	var c := UiStyle.C_GOLD
	c.a = 0.55 + 0.45 * pulse
	for k in 2:     # 2 px pixel ring
		var q := ring.grow(-k)
		draw_rect(Rect2(q.position, Vector2(q.size.x, 1)), c)
		draw_rect(Rect2(q.position + Vector2(0, q.size.y - 1), Vector2(q.size.x, 1)), c)
		draw_rect(Rect2(q.position, Vector2(1, q.size.y)), c)
		draw_rect(Rect2(q.position + Vector2(q.size.x - 1, 0), Vector2(1, q.size.y)), c)
	# arrow above the button, bobbing 3 px
	var tip := Vector2(roundf(r.get_center().x), roundf(ring.position.y - 3.0 - 3.0 * pulse))
	var dark := Color(0.12, 0.08, 0.05)
	for row in 7:          # down-pointing: one pixel wide at the tip, wider towards the shaft
		var half := row
		draw_rect(Rect2(tip.x - half - 1, tip.y - row - 1, half * 2 + 2, 1), dark)
		draw_rect(Rect2(tip.x - half, tip.y - row - 1, half * 2, 1), UiStyle.C_GOLD)
	draw_rect(Rect2(tip.x - 3, tip.y - 14, 6, 7), dark)
	draw_rect(Rect2(tip.x - 2, tip.y - 14, 4, 7), UiStyle.C_GOLD)
