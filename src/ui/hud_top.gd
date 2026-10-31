extends Control
## Non-interactive HUD readouts: resources (top-left), base HP bars + wave (top-centre).
## Custom-drawn in one canvas item to keep draw calls low. Owner: 04-client.

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")

var snap: Dictionary = {}:
	set(v):
		snap = v
		var sig := _signature(v)
		if sig != _last_sig:
			_last_sig = sig
			queue_redraw()      # only when something this panel draws actually changed (08 H15)
var _last_sig := ""
var layout: Dictionary = {}:
	set(v):
		layout = v
		_last_sig = ""
		queue_redraw()
var round_title := "":
	set(v):
		if v != round_title:
			round_title = v
			_last_sig = ""
			queue_redraw()

## Exactly the values drawn, quantised like the drawing (whole-pixel bar widths, ceil seconds).
func _signature(s: Dictionary) -> String:
	var pb: Dictionary = s.get("player_base", {})
	var eb: Dictionary = s.get("enemy_base", {})
	var w: Dictionary = s.get("wave", {})
	var a: Dictionary = s.get("army", {})
	var b: Dictionary = s.get("boss", {})
	var mm := maxf(1.0, float(s.get("mana_max", 100)))
	return "%d|%d|%.1f|%d|%d/%d|%d/%d|%d/%d/%d/%s|%d/%d|%s/%d/%d" % [
		int(s.get("gold", 0)), int(s.get("gold_max", 0)), float(s.get("income", 0)),
		int(float(s.get("mana", 0)) / mm * 512.0),
		ceili(float(pb.get("hp", 0))), int(pb.get("hp_max", 0)), ceili(float(eb.get("hp", 0))), int(eb.get("hp_max", 0)),
		int(w.get("index", 0)), int(w.get("total", 0)), ceili(float(w.get("next_in", 0))), str(w.get("boss", false)),
		int(a.get("player", 0)), int(a.get("cap", 0)),
		str(b.get("alive", false)), ceili(float(b.get("hp", 0))), int(b.get("hp_max", 0))]
var gold_slot_debug := Rect2()    # QA: fixed gold number slot
var base_labels := {"player": "", "enemy": ""}        # QA: drawn HP text
var base_label_rects := {"player": Rect2(), "enemy": Rect2()}

func _hp_text(b: Dictionary, max_w: float) -> String:
	if b.is_empty():
		return ""
	var hp := ceili(maxf(0.0, float(b.get("hp", 0))))
	var full := "%d/%d" % [hp, ceili(float(b.get("hp_max", 0)))]
	return full if UiStyle.number_width(full, UiStyle.NUM_READ, UiStyle.NUM_READ_KIND) <= max_w else str(hp)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 08 R8 (DRAWCALLS.md §2.2): every switch between a plain rect, the ui_main icon page and a glyph cache (one font
## at ONE size) starts a new draw call, and this panel used to interleave them per row (48–56 draw calls). It is now
## drawn in fixed passes with unchanged positions, sizes and colours, so it costs about one draw call per pass.
## Nothing overlaps across passes except text over its plate/bar, which the order keeps on top.
const P_SHAPES := 0   # boxes, bars, hatch, HP plates, boss strip (no texture)
const P_ICONS := 1    # ui_main icons (one page); vector fallbacks when the atlas is missing
const P_TEXT := 2     # Galmuri11 12: resource names, wave line, boss name and every NUM_READ number
const P_BOLD := 3     # Galmuri11-Bold 12: resource amount
const PASSES := [P_SHAPES, P_ICONS, P_TEXT, P_BOLD]
var _pass := P_SHAPES
var passes_drawn := 0              # QA: passes run in the last _draw

func _draw() -> void:
	if layout.is_empty():
		return
	passes_drawn = 0
	for p in PASSES:
		_pass = p
		_draw_resources(layout.resources)
		_draw_bases(layout.bases, layout.wave)
		passes_drawn += 1

func _draw_resources(r: Rect2) -> void:
	if _pass == P_SHAPES:
		UiStyle.draw_pixel_box(self, r, UiStyle.C_PANEL)
	var gold := int(snap.get("gold", 0))
	var gmax := int(snap.get("gold_max", 0))
	var income := float(snap.get("income", 0))
	var y1 := r.position.y + 11
	if _pass == P_ICONS and not UiStyle.draw_ui_icon(self, "icon_supply", Vector2(r.position.x + 11, y1)):
		UiStyle.draw_glyph(self, &"coin", Vector2(r.position.x + 11, y1), 5)
	# resource NAME next to its icon (07 QA-J3: tutorials say "반죽"/"Dough"; the HUD must show the word)
	var nx := r.position.x + 20
	var sname := UiText.t("res.supply")
	var ename := UiText.t("res.energy")
	var name_w := maxf(UiStyle.text_width(sname, UiStyle.FONT_S), UiStyle.text_width(ename, UiStyle.FONT_S))
	var income_txt := "+%.1f/s" % income
	var income_w := UiStyle.number_width(income_txt, UiStyle.NUM_READ, UiStyle.NUM_READ_KIND)
	# Stable-width readout: current gold right-aligned in a slot as wide as the cap's digits.
	var digits := maxi(3, str(maxi(gmax, gold)).length())
	var slot := UiStyle.digit_cell(UiStyle.FONT_M, &"bold") * digits
	var cap_txt := "/%d" % gmax if gmax > 0 else ""
	var cap_w := UiStyle.number_width(cap_txt, UiStyle.NUM_READ, UiStyle.NUM_READ_KIND)
	var avail := r.size.x - 20 - 6
	# priority: amount > resource name > income rate (the name must stay visible, QA-J3)
	var show_name := name_w + 4 + slot + cap_w <= avail
	var show_income := slot + cap_w + 4 + income_w + (name_w + 4 if show_name else 0.0) <= avail
	name_shown = show_name
	if show_name:
		if _pass == P_TEXT:
			UiStyle.draw_text_left(self, sname, Vector2(nx, y1), UiStyle.FONT_S, UiStyle.C_GOLD)
		name_rect = Rect2(nx, y1 - 6, name_w, 12)
		nx += name_w + 4
	var gx := nx
	if _pass == P_BOLD:
		UiStyle.draw_number(self, "%d" % gold, Vector2(gx + slot, y1), UiStyle.FONT_M, UiStyle.C_GOLD, 1, &"bold")
	if _pass == P_TEXT:
		if gmax > 0:
			UiStyle.draw_number(self, cap_txt, Vector2(gx + slot, y1), UiStyle.NUM_READ, UiStyle.C_TEXT_DIM, -1, UiStyle.NUM_READ_KIND)
		if show_income:
			UiStyle.draw_number(self, income_txt, Vector2(r.end.x - 6, y1), UiStyle.NUM_READ, UiStyle.C_TEXT_DIM, 1, UiStyle.NUM_READ_KIND)
	gold_slot_debug = Rect2(gx, y1 - 6, slot, 12)
	income_rect = Rect2(r.end.x - 6 - income_w, y1 - 6, income_w, 12) if show_income else Rect2()
	var mana := float(snap.get("mana", 0))
	var mmax := maxf(1.0, float(snap.get("mana_max", 100)))
	var y2 := r.position.y + 27
	if _pass == P_ICONS and not UiStyle.draw_ui_icon(self, "icon_energy", Vector2(r.position.x + 11, y2)):
		UiStyle.draw_glyph(self, &"mana", Vector2(r.position.x + 11, y2), 5)
	var bx := r.position.x + 20
	if show_name:
		if _pass == P_TEXT:
			UiStyle.draw_text_left(self, ename, Vector2(bx, y2), UiStyle.FONT_S, UiStyle.C_MANA)
		bx += name_w + 4
	if _pass == P_SHAPES:
		UiStyle.draw_bar(self, Rect2(bx, y2 - 4, r.end.x - 8 - bx, 8), mana / mmax, UiStyle.C_MANA)

var name_shown := false
var name_rect := Rect2()
var income_rect := Rect2()
func _draw_bases(r: Rect2, wr: Rect2) -> void:
	var pb: Dictionary = snap.get("player_base", {})
	var eb: Dictionary = snap.get("enemy_base", {})
	var half := floorf((r.size.x - 18) / 2)
	var h := 16.0   # 14 px inner: Galmuri11 12 digits (ink 11) + 1 px shadow on the dark plate
	var y := r.position.y + 4
	var pr := float(pb.get("hp", 1)) / maxf(1.0, float(pb.get("hp_max", 1)))
	var er := float(eb.get("hp", 1)) / maxf(1.0, float(eb.get("hp_max", 1)))
	# enemy bar drains towards the centre (mirror)
	var er_rect := Rect2(r.position.x + half + 18, y, half, h)
	var inner := er_rect.grow(-1)
	var w := floorf(inner.size.x * clampf(er, 0, 1))
	# exact HP numbers (09 R09-04-5): fixed-cell Galmuri11 12 digits (NUM_READ, ≥ 1.7 mm on phones) inside each bar, at
	# the OUTER end so they never touch "VS"; "hp/max" when it fits, else "hp". Bar is 16 high → 14 px inner.
	base_labels.player = _hp_text(pb, half - 8)
	base_labels.enemy = _hp_text(eb, half - 8)
	var cy := y + h / 2
	# solid backing plate under the digits so the enemy stripes never run through glyph strokes; same
	# plate on both bars so only the bar fill differs. (Correction: the "8 read as 3" given as the reason
	# in commit 5eab876 was wrong — r05 enemy base HP really is 1300 in data, c15e43a.)
	var pw := UiStyle.number_width(base_labels.player, UiStyle.NUM_READ, UiStyle.NUM_READ_KIND)
	var ew0 := UiStyle.number_width(base_labels.enemy, UiStyle.NUM_READ, UiStyle.NUM_READ_KIND)
	var plate := Color(0.05, 0.05, 0.08, 0.78)
	if _pass == P_SHAPES:
		UiStyle.draw_bar(self, Rect2(r.position.x, y, half, h), pr, UiStyle.C_HP_PLAYER)
		draw_rect(er_rect, UiStyle.C_EDGE)
		draw_rect(inner, Color(0.05, 0.05, 0.08))
		if w > 0:
			UiStyle.draw_hatch(self, Rect2(inner.end.x - w, inner.position.y, w, inner.size.y), UiStyle.C_HP_ENEMY)   # pattern: not hue alone (QA-B013)
		if pw > 0:
			draw_rect(Rect2(r.position.x + 2, y + 2, pw + 4, h - 4), plate)
		if ew0 > 0:
			draw_rect(Rect2(er_rect.end.x - 6 - ew0, y + 2, ew0 + 4, h - 4), plate)
	if _pass == P_TEXT:
		UiStyle.draw_number(self, "VS", Vector2(r.position.x + half + 9, y + h / 2), UiStyle.NUM_READ, UiStyle.C_TEXT_DIM, 0, UiStyle.NUM_READ_KIND)
		UiStyle.draw_number(self, base_labels.player, Vector2(r.position.x + 4, cy), UiStyle.NUM_READ, UiStyle.C_TEXT, -1, UiStyle.NUM_READ_KIND)
		UiStyle.draw_number(self, base_labels.enemy, Vector2(er_rect.end.x - 4, cy), UiStyle.NUM_READ, UiStyle.C_TEXT, 1, UiStyle.NUM_READ_KIND)
	base_label_rects.player = Rect2(r.position.x + 4, y, pw, h)
	base_label_rects.enemy = Rect2(er_rect.end.x - 4 - ew0, y, ew0, h)
	var wave: Dictionary = snap.get("wave", {})
	var txt := round_title
	if not wave.is_empty():
		var wt := UiText.t("ui.wave") % [int(wave.get("index", 0)), int(wave.get("total", 0))]
		var next_in := float(wave.get("next_in", 0))
		if next_in > 0:
			wt += "  " + UiText.t("ui.wave_next") % ceili(next_in)
		txt = wt if txt == "" else txt + "   " + wt
	if txt != "" and _pass == P_TEXT:
		UiStyle.draw_text_centered(self, UiStyle.fit_text(txt, wr.size.x - 70, UiStyle.FONT_S)[0], wr.get_center(), UiStyle.FONT_S, UiStyle.C_TEXT)
	var army: Dictionary = snap.get("army", {})
	if not army.is_empty() and _pass == P_TEXT:
		UiStyle.draw_number(self, "%d/%d" % [int(army.get("player", 0)), int(army.get("cap", 0))], Vector2(r.position.x, wr.get_center().y), UiStyle.NUM_READ, UiStyle.C_HP_PLAYER, -1, UiStyle.NUM_READ_KIND)
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
	if _pass == P_TEXT:
		var fit: Array = UiStyle.fit_text(name, name_w - 6, UiStyle.FONT_S)
		UiStyle.draw_text_left(self, fit[0], Vector2(br.position.x + 3, br.get_center().y), UiStyle.FONT_S, UiStyle.C_HP_ENEMY)
	if _pass != P_SHAPES:
		return
	draw_rect(Rect2(br.position, Vector2(br.size.x, br.size.y)), UiStyle.C_TOAST_BG)
	var bar := Rect2(br.position.x + name_w + 2, br.position.y + 3, br.size.x - name_w - 4, br.size.y - 6)
	draw_rect(bar, UiStyle.C_EDGE)
	var bi := bar.grow(-1)
	draw_rect(bi, Color(0.05, 0.05, 0.08))
	var bw := floorf(bi.size.x * clampf(float(b.get("hp", 0)) / maxf(1.0, float(b.get("hp_max", 1))), 0.0, 1.0))
	if bw > 0:
		UiStyle.draw_hatch(self, Rect2(bi.position, Vector2(bw, bi.size.y)), UiStyle.C_HP_ENEMY)   # enemy pattern (QA-B013)
