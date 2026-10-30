extends Node2D
## MOCK battlefield backdrop for UI preview only (04-client). Gives the HUD something to sit on in
## screenshots. Real battlefield rendering is 02's scenes/gameplay/battle.tscn with 03 atlases.

var mock: Node

func _process(_d: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.38, 0.55, 0.78))
	draw_rect(Rect2(0, vs.y * 0.55, vs.x, vs.y * 0.3), Color(0.30, 0.50, 0.30))
	draw_rect(Rect2(0, 300, vs.x, vs.y - 300), Color(0.42, 0.31, 0.20))
	draw_rect(Rect2(10, 200, 50, 100), Color(0.3, 0.3, 0.6))
	draw_rect(Rect2(vs.x - 60, 200, 50, 100), Color(0.6, 0.25, 0.25))
	var hx := 80.0
	if mock != null:
		hx = clampf(float(mock.hero_x) * 0.6, 40, vs.x - 80)
		for i in int(mock.army):
			draw_rect(Rect2(90 + i * 14 + fmod(mock.t * 20.0, 14.0), 280, 10, 20), Color(0.85, 0.85, 0.95))
	draw_rect(Rect2(hx, 268, 16, 32), Color(1.0, 0.8, 0.3))
	for i in 6:
		draw_rect(Rect2(vs.x - 160 + i * 16, 282, 10, 18), Color(0.4, 0.8, 0.3))
