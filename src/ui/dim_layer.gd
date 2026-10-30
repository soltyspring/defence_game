extends Control
## Full-screen dimmer for modal menus (pause). Swallows touches so the battlefield is not hit.
## Owner: 04-client.

const UiStyle := preload("res://src/ui/ui_style.gd")

var title := ""
var title_y := 100.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.C_DIM)
	if title != "":
		UiStyle.draw_text_centered(self, title, Vector2(size.x / 2, title_y), UiStyle.FONT_L)
