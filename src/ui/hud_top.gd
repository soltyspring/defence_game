extends Control
## Non-interactive HUD readouts: resources (top-left), base HP bars + wave (top-centre).
## Custom-drawn in one canvas item to keep draw calls low. Owner: 04-client.

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const Palette := preload("res://src/ui/battle_hud_palette.gd")

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
	return "%d|%d|%.1f|%d|%d/%d|%d/%d|%d/%d/%d/%s|%d/%d|%s/%d/%d/%s%s%s%d" % [
		int(s.get("gold", 0)), int(s.get("gold_max", 0)), float(s.get("income", 0)),
		int(float(s.get("mana", 0)) / mm * 512.0),
		ceili(float(pb.get("hp", 0))), int(pb.get("hp_max", 0)), ceili(float(eb.get("hp", 0))), int(eb.get("hp_max", 0)),
		int(w.get("index", 0)), int(w.get("total", 0)), ceili(float(w.get("next_in", 0))), str(w.get("boss", false)),
		int(a.get("player", 0)), int(a.get("cap", 0)),
		str(b.get("alive", false)), ceili(float(b.get("hp", 0))), int(b.get("hp_max", 0)),
		"T" if bool(b.get("telegraph", false)) else "", "X" if bool(b.get("exposed", false)) else "",
		"L" if bool(b.get("linked", false)) else "", int(b.get("phase", 1))]
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
	var show_name := false      # 2026-11-14 (user): icons only, no "밀가루" / "기력" words in the resource box
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
	var has_mana := not (snap.get("skills", []) as Array).is_empty()
	if not show_income:
		if _pass == P_TEXT:
			UiStyle.draw_number(self, income_txt, Vector2(r.end.x - 6, y2), UiStyle.NUM_READ, UiStyle.C_GOLD, 1, UiStyle.NUM_READ_KIND)
		income_rect = Rect2(r.end.x - 6 - income_w, y2 - 6, income_w, 12)
	if not has_mana:
		return
	if _pass == P_ICONS and not UiStyle.draw_ui_icon(self, "icon_energy", Vector2(r.position.x + 11, y2)):
		UiStyle.draw_glyph(self, &"mana", Vector2(r.position.x + 11, y2), 5)
	var bx := r.position.x + 20
	var lower_end := r.end.x - 8 - (income_w + 6 if not show_income else 0.0)
	if show_name and lower_end - bx > name_w + 32:
		if _pass == P_TEXT:
			UiStyle.draw_text_left(self, ename, Vector2(bx, y2), UiStyle.FONT_S, UiStyle.C_MANA)
		bx += name_w + 4
	if _pass == P_SHAPES:
		UiStyle.draw_bar(self, Rect2(bx, y2 - 4, maxf(8, lower_end - bx), 8), mana / mmax, UiStyle.C_MANA)

var name_shown := false
var name_rect := Rect2()
var income_rect := Rect2()
## Geometry of the base HP strip inside layout.bases, shared with the skin overlay (hud_skin.gd TopSkin).
static func base_bars(r: Rect2) -> Dictionary:
	var h := 18.0
	var y := r.position.y + 3
	var cy := y + h / 2
	var icon_w := 18.0
	var mid := roundf(r.get_center().x)
	var bar_h := 8.0
	var x0 := r.position.x + icon_w + 2
	return {"plate": Rect2(r.position.x, y, r.size.x, h), "cy": cy, "icon_w": icon_w, "mid": mid,
		"left": Rect2(x0, cy - bar_h / 2, mid - 6 - x0, bar_h), "right": Rect2(mid + 6, cy - bar_h / 2, r.end.x - icon_w - 2 - (mid + 6), bar_h)}

const BASE_HEALTH_SKIN := preload("res://assets/art/hud_skin/base_health.png")

func _draw_base_skin(plate: Rect2, mid: float) -> void:
	# Keep the ends and center divider crisp while only the long troughs stretch.
	var src := [0, 8, 61, 67, 120, 128]
	var dst := [plate.position.x, plate.position.x + 8, mid - 3, mid + 3, plate.end.x - 8, plate.end.x]
	for i in range(5):
		draw_texture_rect_region(BASE_HEALTH_SKIN,
			Rect2(dst[i], plate.position.y, dst[i + 1] - dst[i], plate.size.y),
			Rect2(src[i], 0, src[i + 1] - src[i], 20))

func _draw_bases(r: Rect2, wr: Rect2) -> void:
	var pb: Dictionary = snap.get("player_base", {})
	var eb: Dictionary = snap.get("enemy_base", {})
	# One dark plate holding both sides: [bakery icon][our bar >  <> < their bar][nest icon]. No numbers (2026-11-14
	# user): the fills show how the fight stands. Each bar empties towards its own icon, so the two fills meet at the
	# centre mark while both bases are whole and pull apart as a base is worn down.
	var g := base_bars(r)
	var cy: float = g.cy
	var icon_w: float = g.icon_w
	var mid: float = g.mid
	var left: Rect2 = g.left
	var right: Rect2 = g.right
	var pr := clampf(float(pb.get("hp", 1)) / maxf(1.0, float(pb.get("hp_max", 1))), 0.0, 1.0)
	var er := clampf(float(eb.get("hp", 1)) / maxf(1.0, float(eb.get("hp_max", 1))), 0.0, 1.0)
	base_labels.player = ""
	base_labels.enemy = ""
	if _pass == P_SHAPES:
		_draw_base_skin(g.plate, mid)
		for side in 2:
			var bar: Rect2 = left if side == 0 else right
			var ratio := pr if side == 0 else er
			var w := floorf(bar.size.x * ratio)
			if w <= 0: continue
			# our fill is anchored at the bakery (left), theirs at the nest (right)
			var fill := Rect2(bar.position.x if side == 0 else bar.end.x - w, bar.position.y, w, bar.size.y)
			draw_rect(fill, Palette.ALLY if side == 0 else Palette.FOE)
			if side == 1: # Keep a shape cue for players who cannot distinguish the two hues.
				var x := bar.end.x - 3.0
				while x >= fill.position.x:
					draw_rect(Rect2(x, fill.position.y + 1, 1, fill.size.y - 2), Palette.FOE_STRIPE)
					x -= 5.0
			draw_rect(Rect2(fill.position, Vector2(w, 1)), Palette.ALLY_LIGHT if side == 0 else Palette.FOE_LIGHT)
			if side == 1 and ratio < 0.3:   # their base nearly down: a pale frame (ours pulses, hud_skin.gd TopSkin)
				draw_rect(bar.grow(1), Color("fff0b0"), false, 1.0)
		# centre mark: a small gold diamond where the two fronts meet (was the text "VS")
		for k in 4:
			draw_rect(Rect2(mid - (3 - k), cy - k if k < 3 else cy - 3, (3 - k) * 2, 1), UiStyle.C_GOLD)
			draw_rect(Rect2(mid - (3 - k), cy + k if k < 3 else cy + 3, (3 - k) * 2, 1), UiStyle.C_GOLD.darkened(0.25))
	if _pass == P_ICONS:
		if not UiStyle.draw_ui_icon(self, "icon_home", Vector2(r.position.x + icon_w / 2 + 1, cy)):
			UiStyle.draw_glyph(self, &"coin", Vector2(r.position.x + icon_w / 2 + 1, cy), 4, UiStyle.C_HP_PLAYER)
		if not UiStyle.draw_ui_icon(self, "icon_nest", Vector2(r.end.x - icon_w / 2 - 1, cy)):
			UiStyle.draw_glyph(self, &"coin", Vector2(r.end.x - icon_w / 2 - 1, cy), 4, UiStyle.C_HP_ENEMY)
	base_label_rects.player = Rect2(left.position, Vector2.ZERO)
	base_label_rects.enemy = Rect2(right.end, Vector2.ZERO)
	var wave: Dictionary = snap.get("wave", {})
	var txt := ""
	if not wave.is_empty():
		var wt := UiText.t("ui.wave") % [int(wave.get("index", 0)), int(wave.get("total", 0))]
		var next_in := float(wave.get("next_in", 0))
		if next_in > 0:
			wt += "  " + UiText.t("ui.wave_next") % ceili(next_in)
		txt = wt
	var compact := bool(layout.get("compact",false))
	var army_width := 0.0 if compact else 70.0
	var text_width := maxf(0, wr.size.x - army_width)
	if compact and not round_title.is_empty():
		txt = round_title.get_slice(".",0) + " · " + txt
	elif not round_title.is_empty():
		var remain := text_width - UiStyle.text_width(txt, UiStyle.FONT_S) - 8
		if remain >= 24:
			var title := str(UiStyle.fit_text(round_title, remain, UiStyle.FONT_S)[0])
			txt = title + "  " + txt
	if txt != "" and _pass == P_TEXT:
		var shown: String = UiStyle.fit_text(txt, text_width, UiStyle.FONT_S)[0]
		var c := Vector2(wr.position.x + army_width + text_width * 0.5, wr.get_center().y)
		var tw := UiStyle.text_width(shown, UiStyle.FONT_S) + 12.0
		# dark plate: the line sits on the sky and was thin white on light blue (first-run review)
		draw_rect(Rect2(roundf(c.x - tw * 0.5), roundf(c.y - 8.0), roundf(tw), 16.0), Color(0.09, 0.07, 0.06, 0.62))
		UiStyle.draw_text_centered(self, shown, c, UiStyle.FONT_S, UiStyle.C_TEXT)
	var army: Dictionary = snap.get("army", {})
	if not compact and not army.is_empty() and _pass == P_TEXT:
		UiStyle.draw_number(self, "%d/%d" % [int(army.get("player", 0)), int(army.get("cap", 0))], Vector2(r.position.x, wr.get_center().y), UiStyle.NUM_READ, UiStyle.C_HP_PLAYER, -1, UiStyle.NUM_READ_KIND)
	_draw_boss(layout.get("boss", Rect2()))

## Boss HP bar (HudSnapshot.boss, 02 R6) while a boss is alive: name (Galmuri11 12) + bar + hp numbers.
var boss_drawn := false            # QA
var boss_state := ""               # QA: "" | "telegraph" | "exposed" | "linked" (frame drawn on the boss bar)
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
	# The boss bar itself carries the boss state, so no extra banner has to compete with the lane:
	# wind-up = pale frame in the marker colour, opening = bright frame + a solid light fill under the hatch.
	# linked (a knot shields it) = the fill is dimmed inside a dull violet frame: hits barely count until the strands are cut.
	# Phase marks (boss key `phases`) are thin notches at the HP shares where the fight changes.
	for m in b.get("phase_marks", []):
		draw_rect(Rect2(bi.position.x + floorf(bi.size.x * float(m)), bi.position.y, 1.0, bi.size.y), Color("fff0b0"))
	boss_state = "telegraph" if bool(b.get("telegraph", false)) else ("exposed" if bool(b.get("exposed", false)) else ("linked" if bool(b.get("linked", false)) else ""))
	if boss_state == "linked":
		if bw > 0: draw_rect(Rect2(bi.position, Vector2(bw, bi.size.y)), Color(0.05, 0.05, 0.08, 0.6))
		draw_rect(bar, Color("8f7fd6"), false, 1.0)
	elif boss_state == "exposed":
		if bw > 0: draw_rect(Rect2(bi.position.x, bi.end.y - 2.0, bw, 2.0), Color("fff0b0"))
		draw_rect(bar, Color("fff0b0"), false, 1.0)
	elif boss_state == "telegraph":
		draw_rect(bar, Color("bff3ee"), false, 1.0)
