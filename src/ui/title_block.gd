extends RefCounted
## Main-menu title: 03 logo frame when available, else the localized ui.title text. Owner: 04-client.
## User Q3 (16:19 KST): working title "빵집 기사단: 곰팡이 디펜스". Final store name only after a
## human KIPRIS check (classes 9/41), so this stays a WORKING title. Text comes from data/text `ui.title`
## (01). The old provisional values ("레인 디펜스"/"Lane Defence") are treated as stale until 01 updates
## the key (04→01 R7). Then the UI fallback below is used.
## Layout rules (grid sizes only, never shrink arbitrarily):
##   1 line Bold 36 → else split after ":" into 2 lines (36 + 24) → else 2 lines at 24 → else ellipsis.
## Logo: ui_title atlas frames `logo_title_<locale>` / `logo_title_<locale>_2line`, integer scale ≥ 1,
## whichever is larger while fitting the slot. Text is used if the atlas or frame is missing.

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")

const STALE := ["레인 디펜스", "Lane Defence"]
const WORKING_TITLE := {"ko": "빵집 기사단: 곰팡이 디펜스", "en": "Bakery Knights: Mold Defense"}

static func title_text() -> String:
	var t := UiText.t("ui.title")
	if t in STALE or t == "ui.title":
		var loc := "en" if UiText.t("ui.play") == "Play" else "ko"
		return WORKING_TITLE[loc]
	return t

## Returns {"mode": "logo"|"text", "lines": [[text, size]], "tex": Texture2D, "rect": Rect2, "truncated": bool}
static func compute(slot: Rect2, locale: String) -> Dictionary:
	# --- logo first
	var best: Dictionary = {}
	for fr in ["logo_title_%s" % locale, "logo_title_%s_2line" % locale]:
		var tex: Texture2D = UiStyle.icon_texture({"atlas": "ui_title", "frame": fr})
		if tex == null:
			continue
		var s := tex.get_size()
		var k := floorf(minf(slot.size.x / s.x, slot.size.y / s.y))
		if k < 1.0:
			continue
		var sz := s * k
		if best.is_empty() or sz.x * sz.y > best.area:
			best = {"mode": "logo", "tex": tex, "rect": Rect2((slot.get_center() - sz / 2).round(), sz), "area": sz.x * sz.y, "lines": [], "truncated": false}
	if not best.is_empty():
		return best
	# --- text
	var t := title_text()
	var maxw := slot.size.x
	if UiStyle.text_width(t, UiStyle.FONT_XL, &"bold") <= maxw:
		return {"mode": "text", "lines": [[t, UiStyle.FONT_XL]], "truncated": false}
	var parts := t.split(":", true, 1)
	if parts.size() == 2:
		var a := parts[0].strip_edges() + ":"
		var b := parts[1].strip_edges()
		for sizes in [[UiStyle.FONT_XL, UiStyle.FONT_L], [UiStyle.FONT_L, UiStyle.FONT_L]]:
			if UiStyle.text_width(a, sizes[0], &"bold") <= maxw and UiStyle.text_width(b, sizes[1], &"bold") <= maxw:
				return {"mode": "text", "lines": [[a, sizes[0]], [b, sizes[1]]], "truncated": false}
	if UiStyle.text_width(t, UiStyle.FONT_L, &"bold") <= maxw:
		return {"mode": "text", "lines": [[t, UiStyle.FONT_L]], "truncated": false}
	return {"mode": "text", "lines": [[UiStyle.fit_text(t, maxw, UiStyle.FONT_L, &"bold")[0], UiStyle.FONT_L]], "truncated": true}

## Draws the block centred in slot; returns the bottom y used (for the subtitle).
static func draw(ci: CanvasItem, slot: Rect2, locale: String) -> float:
	var l := compute(slot, locale)
	if l.mode == "logo":
		ci.draw_texture_rect(l.tex, l.rect, false)
		return (l.rect as Rect2).end.y
	var lines: Array = l.lines
	var hs := []
	var total := 0.0
	for ln in lines:
		var h := float(ln[1]) + 4.0
		hs.append(h)
		total += h
	var y := slot.get_center().y - total / 2.0
	for i in lines.size():
		UiStyle.draw_text_centered(ci, lines[i][0], Vector2(slot.get_center().x, y + hs[i] / 2.0), lines[i][1], UiStyle.C_GOLD, true, &"bold")
		y += hs[i]
	return y
