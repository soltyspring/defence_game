extends Control
## Non-interactive HUD readouts: resources (top-left), base HP bars + wave (top-centre).
## Custom-drawn in one canvas item to keep draw calls low. Owner: 04-client.

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")

var snap: Dictionary = {}
var layout: Dictionary = {}
var round_title := ""
var gold_slot_debug := Rect2()    # QA: fixed gold number slot
var base_labels := {"player": "", "enemy": ""}        # QA: drawn HP text
var base_label_rects := {"player": Rect2(), "enemy": Rect2()}

func _hp_text(b: Dictionary, max_w: float) -> String:
	if b.is_empty():
		return ""
	var hp := ceili(maxf(0.0, float(b.get("hp", 0))))
	var full := "%d/%d" % [hp, ceili(float(b.get("hp_max", 0)))]
	return full if UiStyle.number_width(full, UiStyle.NUM_S) <= max_w else str(hp)

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
	if not UiStyle.draw_ui_icon(self, "icon_supply", Vector2(r.position.x + 11, y1)):
		UiStyle.draw_glyph(self, &"coin", Vector2(r.position.x + 11, y1), 5)
	# Stable-width readout: current gold is right-aligned in a slot as wide as the cap's digits,
	# so "/200" and the income never move while gold ticks (fixed digit cells, Galmuri11 Bold 12).
	var digits := maxi(3, str(maxi(gmax, gold)).length())
	var slot := UiStyle.digit_cell(UiStyle.FONT_M, &"bold") * digits
	var gx := r.position.x + 20
	UiStyle.draw_number(self, "%d" % gold, Vector2(gx + slot, y1), UiStyle.FONT_M, UiStyle.C_GOLD, 1, &"bold")
	if gmax > 0:
		UiStyle.draw_number(self, "/%d" % gmax, Vector2(gx + slot, y1), UiStyle.NUM_S, UiStyle.C_TEXT_DIM, -1)
	UiStyle.draw_number(self, "+%.1f/s" % income, Vector2(r.end.x - 6, y1), UiStyle.NUM_S, UiStyle.C_TEXT_DIM, 1)
	gold_slot_debug = Rect2(gx, y1 - 6, slot, 12)
	var mana := float(snap.get("mana", 0))
	var mmax := maxf(1.0, float(snap.get("mana_max", 100)))
	var y2 := r.position.y + 27
	if not UiStyle.draw_ui_icon(self, "icon_energy", Vector2(r.position.x + 11, y2)):
		UiStyle.draw_glyph(self, &"mana", Vector2(r.position.x + 11, y2), 5)
	UiStyle.draw_bar(self, Rect2(r.position.x + 20, y2 - 4, r.size.x - 28, 8), mana / mmax, UiStyle.C_MANA)

func _draw_bases(r: Rect2, wr: Rect2) -> void:
	var pb: Dictionary = snap.get("player_base", {})
	var eb: Dictionary = snap.get("enemy_base", {})
	var half := floorf((r.size.x - 18) / 2)
	var h := 14.0
	var y := r.position.y + 4
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
	UiStyle.draw_number(self, "VS", Vector2(r.position.x + half + 9, y + h / 2), UiStyle.NUM_S, UiStyle.C_TEXT_DIM, 0)
	# exact HP numbers (09 R09-04-5): fixed-cell Galmuri9 10 inside each bar, at the OUTER end so they
	# never touch "VS"; "hp/max" when it fits, else "hp". Bar is 14 high → 12 px inner > 10 px glyph line.
	base_labels.player = _hp_text(pb, half - 8)
	base_labels.enemy = _hp_text(eb, half - 8)
	var cy := y + h / 2
	UiStyle.draw_number(self, base_labels.player, Vector2(r.position.x + 4, cy), UiStyle.NUM_S, UiStyle.C_TEXT, -1)
	UiStyle.draw_number(self, base_labels.enemy, Vector2(er_rect.end.x - 4, cy), UiStyle.NUM_S, UiStyle.C_TEXT, 1)
	base_label_rects.player = Rect2(r.position.x + 4, y, UiStyle.number_width(base_labels.player, UiStyle.NUM_S), h)
	var ew := UiStyle.number_width(base_labels.enemy, UiStyle.NUM_S)
	base_label_rects.enemy = Rect2(er_rect.end.x - 4 - ew, y, ew, h)
	var wave: Dictionary = snap.get("wave", {})
	var txt := round_title
	if not wave.is_empty():
		var wt := UiText.t("ui.wave") % [int(wave.get("index", 0)), int(wave.get("total", 0))]
		var next_in := float(wave.get("next_in", 0))
		if next_in > 0:
			wt += "  " + UiText.t("ui.wave_next") % ceili(next_in)
		txt = wt if txt == "" else txt + "   " + wt
	if txt != "":
		UiStyle.draw_text_centered(self, UiStyle.fit_text(txt, wr.size.x - 70, UiStyle.FONT_S)[0], wr.get_center(), UiStyle.FONT_S, UiStyle.C_TEXT)
	var army: Dictionary = snap.get("army", {})
	if not army.is_empty():
		UiStyle.draw_number(self, "%d/%d" % [int(army.get("player", 0)), int(army.get("cap", 0))], Vector2(r.position.x, wr.get_center().y), UiStyle.NUM_S, UiStyle.C_HP_PLAYER, -1)
	_draw_boss(layout.get("boss", Rect2()))

## Boss HP bar (HudSnapshot.boss, 02 R6) while a boss is alive: name (Galmuri11 12) + bar + hp numbers.
var boss_drawn := false            # QA
func _draw_boss(br: Rect2) -> void:
	var b: Dictionary = snap.get("boss", {})
	boss_drawn = br.size != Vector2.ZERO and bool(b.get("alive", false))
	if not boss_drawn:
		return
	var key := str(b.get("name_key", ""))
	var name := UiText.t(key) if key != "" and UiText.has(key) else UiText.t("ui.boss")
	var name_w := minf(UiStyle.text_width(name, UiStyle.FONT_S) + 6, br.size.x * 0.35)
	var fit: Array = UiStyle.fit_text(name, name_w - 6, UiStyle.FONT_S)
	draw_rect(Rect2(br.position, Vector2(br.size.x, br.size.y)), UiStyle.C_TOAST_BG)
	UiStyle.draw_text_left(self, fit[0], Vector2(br.position.x + 3, br.get_center().y), UiStyle.FONT_S, UiStyle.C_HP_ENEMY)
	var bar := Rect2(br.position.x + name_w + 2, br.position.y + 3, br.size.x - name_w - 4, br.size.y - 6)
	UiStyle.draw_bar(self, bar, float(b.get("hp", 0)) / maxf(1.0, float(b.get("hp_max", 1))), UiStyle.C_HP_ENEMY)
