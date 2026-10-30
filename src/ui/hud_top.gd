extends Control
## Non-interactive HUD readouts: resources (top-left), base HP bars + wave (top-centre).
## Custom-drawn in one canvas item to keep draw calls low. Owner: 04-client.

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")

var snap: Dictionary = {}
var layout: Dictionary = {}
var round_title := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if layout.is_empty():
		return
	_draw_resources(layout.resources)
	_draw_bases(layout.bases, layout.wave)

func _draw_resources(r: Rect2) -> void:
	UiStyle.draw_pixel_box(self, r, UiStyle.C_PANEL)
	var gold := int(snap.get("gold", 0))
	var gmax := int(snap.get("gold_max", 0))
	var income := float(snap.get("income", 0))
	var y1 := r.position.y + 11
	UiStyle.draw_glyph(self, &"coin", Vector2(r.position.x + 11, y1), 5)
	var gtxt := "%d" % gold
	if gmax > 0:
		gtxt += "/%d" % gmax
	UiStyle.draw_text_left(self, gtxt, Vector2(r.position.x + 20, y1), UiStyle.FONT_M, UiStyle.C_GOLD)
	UiStyle.draw_text_left(self, "+%.1f/s" % income, Vector2(r.end.x - 46, y1), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	var mana := float(snap.get("mana", 0))
	var mmax := maxf(1.0, float(snap.get("mana_max", 100)))
	var y2 := r.position.y + 27
	UiStyle.draw_glyph(self, &"mana", Vector2(r.position.x + 11, y2), 5)
	UiStyle.draw_bar(self, Rect2(r.position.x + 20, y2 - 4, r.size.x - 28, 8), mana / mmax, UiStyle.C_MANA)

func _draw_bases(r: Rect2, wr: Rect2) -> void:
	var pb: Dictionary = snap.get("player_base", {})
	var eb: Dictionary = snap.get("enemy_base", {})
	var half := floorf((r.size.x - 18) / 2)
	var h := 10.0
	var y := r.position.y + 6
	var pr := float(pb.get("hp", 1)) / maxf(1.0, float(pb.get("hp_max", 1)))
	var er := float(eb.get("hp", 1)) / maxf(1.0, float(eb.get("hp_max", 1)))
	UiStyle.draw_bar(self, Rect2(r.position.x, y, half, h), pr, UiStyle.C_HP_PLAYER)
	# enemy bar drains towards the centre (mirror)
	var er_rect := Rect2(r.position.x + half + 18, y, half, h)
	draw_rect(er_rect, UiStyle.C_EDGE)
	var inner := er_rect.grow(-1)
	draw_rect(inner, Color(0.05, 0.05, 0.08))
	var w := floorf(inner.size.x * clampf(er, 0, 1))
	draw_rect(Rect2(inner.end.x - w, inner.position.y, w, inner.size.y), UiStyle.C_HP_ENEMY)
	UiStyle.draw_text_centered(self, "VS", Vector2(r.position.x + half + 9, y + h / 2), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	var wave: Dictionary = snap.get("wave", {})
	var txt := round_title
	if not wave.is_empty():
		var wt := UiText.t("ui.wave") % [int(wave.get("index", 0)), int(wave.get("total", 0))]
		var next_in := float(wave.get("next_in", 0))
		if next_in > 0:
			wt += "  " + UiText.t("ui.wave_next") % ceili(next_in)
		txt = wt if txt == "" else txt + "   " + wt
	if txt != "":
		UiStyle.draw_text_centered(self, txt, wr.get_center(), UiStyle.FONT_S + 1, UiStyle.C_TEXT)
	var army: Dictionary = snap.get("army", {})
	if not army.is_empty():
		UiStyle.draw_text_left(self, "%d/%d" % [int(army.get("player", 0)), int(army.get("cap", 0))], Vector2(r.position.x, wr.get_center().y), UiStyle.FONT_S, UiStyle.C_HP_PLAYER)
