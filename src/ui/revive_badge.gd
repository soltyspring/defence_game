extends Control
## Hero revive countdown. Owner: 04-client. A read-out only: it never takes input, sits in its own HudLayout
## rectangle (`revive`) under the top bar, and is driven by HudSnapshot.hero {alive, respawn}, so it freezes
## with the simulation (pause) and cannot outlive a battle.
##   wide    "영웅 부활 05초" + a thin progress line
##   compact (narrow views) pointer glyph + "05"
##   flash() once when the hero is actually back, then it hides itself and emits `finished`.
const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
signal finished

var remaining := 0.0
var total := 1.0
var compact := false
var flash_t := 0.0
var shown_text := ""      # QA: what the badge says right now

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func set_state(p_remaining: float, p_total: float, p_compact: bool) -> void:
	var secs := "%02d" % ceili(maxf(p_remaining, 0.0))
	var text: String = secs if p_compact else "%s %s%s" % [UiText.t("ui.revive_label"), secs, UiText.t("ui.revive_unit")]
	var changed := text != shown_text or p_compact != compact
	remaining = p_remaining
	total = maxf(0.1, p_total)
	compact = p_compact
	shown_text = text
	if changed or absf(p_remaining - remaining) >= 0.0: queue_redraw()     # the progress line moves every snapshot

func flash(seconds: float) -> void:
	flash_t = seconds
	shown_text = UiText.t("ui.revived")
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if flash_t <= 0.0:
		return
	flash_t -= delta
	if flash_t <= 0.0:
		flash_t = 0.0
		set_process(false)
		hide()
		finished.emit()
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0:
		return
	var cy := r.get_center().y - 1.0
	draw_rect(r, UiStyle.C_TOAST_BG)
	if flash_t > 0.0:
		draw_rect(r, UiStyle.C_ACCENT, false, 1.0)
		_pointer(Vector2(8.0, cy), true)
		if not compact:
			UiStyle.draw_text_centered(self, shown_text, Vector2(r.get_center().x + 4.0, cy), UiStyle.FONT_S, UiStyle.C_ACCENT)
		return
	var secs := "%02d" % ceili(maxf(remaining, 0.0))
	_pointer(Vector2(8.0, cy), false)
	if compact:
		UiStyle.draw_number(self, secs, Vector2(r.end.x - 5.0, cy), UiStyle.FONT_M, UiStyle.C_TEXT, 1, &"bold")
	else:
		var label := UiText.t("ui.revive_label")
		var unit := UiText.t("ui.revive_unit")
		var lw := UiStyle.text_width(label, UiStyle.FONT_S)
		var nw := UiStyle.number_width("00", UiStyle.FONT_M, &"bold")      # fixed cell: the text does not jitter
		var uw := UiStyle.text_width(unit, UiStyle.FONT_S)
		var x := roundf(r.get_center().x + 6.0 - (lw + 4.0 + nw + 2.0 + uw) * 0.5)
		UiStyle.draw_text_left(self, label, Vector2(x, cy), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
		UiStyle.draw_number(self, secs, Vector2(x + lw + 4.0 + nw, cy), UiStyle.FONT_M, UiStyle.C_TEXT, 1, &"bold")
		UiStyle.draw_text_left(self, unit, Vector2(x + lw + 4.0 + nw + 2.0, cy), UiStyle.FONT_S, UiStyle.C_TEXT_DIM)
	var k := clampf(1.0 - remaining / total, 0.0, 1.0)
	draw_rect(Rect2(1.0, r.size.y - 3.0, r.size.x - 2.0, 2.0), Color(0.05, 0.05, 0.08))
	draw_rect(Rect2(1.0, r.size.y - 3.0, floorf((r.size.x - 2.0) * k), 2.0), Color("ffe7a0"))

## The same pointer that floats over the hero in the lane: hollow while down, filled when back.
func _pointer(c: Vector2, filled: bool) -> void:
	var pts := PackedVector2Array([c + Vector2(-4, -3), c + Vector2(4, -3), c + Vector2(0, 4)])
	if filled:
		draw_colored_polygon(pts, Color("ffe7a0"))
	else:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color("ffe7a0"), 1.0)
