extends RefCounted
## Pixel UI palette, theme, typography and shared draw helpers. Owner: 04-client.
## Icons come from the 03 `ui_main` atlas via Atlas; drawn glyphs are only a fallback.
##
## Typography (docs/art/TYPOGRAPHY.md, 03; measured in docs/qa/TYPOGRAPHY_QA.md, 04):
## - Fonts from assets/manifest.json "fonts": ui = Galmuri11, ui_bold = Galmuri11-Bold,
##   numerals = Galmuri9 (ASCII digits only, NO Hangul).
## - Sizes are integer multiples of the native grid only: Galmuri11 12/24/36, Galmuri9 10/20.
##   Hangul is never drawn below 12 px. Text is never shrunk; if it cannot fit, it is ellipsized
##   (and tests fail for Korean).
## - Flags forced at load: no antialiasing, no hinting, no subpixel positioning, no mipmaps,
##   allow_system_fallback = false (a missing glyph shows as tofu in QA instead of a silent OS font).
## - Contrast via whole-pixel drop shadow (1 px at 12, 2 px at 24+), not fractional outlines.
## - Resource numbers use fixed digit cells so values do not jitter as they change.

const C_BG := Color(0.09, 0.10, 0.14)
const C_PANEL := Color(0.13, 0.15, 0.21, 0.92)
const C_PANEL_LIGHT := Color(0.22, 0.25, 0.33, 0.95)
const C_EDGE := Color(0.03, 0.03, 0.05)
const C_HILITE := Color(1, 1, 1, 0.18)
const C_TEXT := Color(0.96, 0.94, 0.88)
const C_TEXT_DIM := Color(0.66, 0.68, 0.74)
const C_GOLD := Color(1.0, 0.80, 0.25)
const C_MANA := Color(0.35, 0.65, 1.0)
const C_HP_PLAYER := Color(0.36, 0.85, 0.42)
const C_HP_ENEMY := Color(0.93, 0.32, 0.30)
const C_ACCENT := Color(0.98, 0.62, 0.20)
const C_DISABLED := Color(0.30, 0.31, 0.35, 0.92)
const C_DIM := Color(0, 0, 0, 0.55)
const C_STAR := Color(1.0, 0.85, 0.2)
const C_STAR_OFF := Color(0.30, 0.30, 0.36)
const C_TOAST_BG := Color(0.05, 0.05, 0.08, 0.82)

# Galmuri11 grid: 12 / 24 / 36 only.
const FONT_S := 12
const FONT_M := 12
const FONT_L := 24
const FONT_XL := 36
# Galmuri9 numerals grid: 10 / 20 only.
const NUM_S := 10
const NUM_L := 20
const ALLOWED_SIZES := {&"ui": [12, 24, 36], &"bold": [12, 24, 36], &"num": [10, 20]}

static var _theme: Theme
static var _fonts: Dictionary = {}          # kind -> Font
static var font_sources: Dictionary = {}    # kind -> "bundled:<path>" | "fallback"
static var font_source := ""                # ui font source (kept for older callers/tests)
static var _digit_cell: Dictionary = {}     # "kind:size" -> cell width

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font_size = FONT_M
	th.default_font = font(&"ui")
	for t in ["Label", "Button"]:
		th.set_color("font_color", t, C_TEXT)
	th.set_color("font_shadow_color", "Label", C_EDGE)
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)
	th.set_constant("outline_size", "Label", 0)
	th.set_stylebox("normal", "Button", box(C_PANEL_LIGHT))
	th.set_stylebox("hover", "Button", box(C_PANEL_LIGHT.lightened(0.1)))
	th.set_stylebox("pressed", "Button", box(C_ACCENT.darkened(0.3)))
	th.set_stylebox("disabled", "Button", box(C_DISABLED))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("panel", "PanelContainer", box(C_PANEL))
	th.set_stylebox("panel", "Panel", box(C_PANEL))
	_theme = th
	return th

static func box(fill: Color, border := C_EDGE, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(4)
	s.anti_aliasing = false
	return s

# ------------------------------------------------------------------ fonts

static func _manifest_fonts() -> Dictionary:
	if not FileAccess.file_exists("res://assets/manifest.json"):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/manifest.json")) != OK or not (j.data is Dictionary):
		return {}
	var f = j.data.get("fonts", {})
	return f if f is Dictionary else {}

static func _path_of(v: Variant) -> String:
	if v is Dictionary:
		return str(v.get("path", ""))
	return str(v) if v != null else ""

static func _pixel_flags(f: Font) -> void:
	if f is FontFile:
		var ff := f as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.multichannel_signed_distance_field = false
		ff.generate_mipmaps = false
		ff.allow_system_fallback = false

## kind: &"ui" (Galmuri11), &"bold" (Galmuri11-Bold), &"num" (Galmuri9 digits; falls back to ui).
static func font(kind: StringName = &"ui") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var mf := _manifest_fonts()
	var key: String = {&"ui": "ui", &"bold": "ui_bold", &"num": "numerals"}.get(kind, "ui")
	var path := _path_of(mf.get(key, ""))
	var f: Font = null
	if path != "" and ResourceLoader.exists(path):
		var r = load(path)
		if r is Font:
			f = r
			_pixel_flags(f)
			font_sources[kind] = "bundled:" + path
	if f == null:
		if kind != &"ui":
			f = font(&"ui")             # bold/num missing → regular bundled font
			font_sources[kind] = "alias:ui"
		else:
			f = ThemeDB.fallback_font
			font_sources[kind] = "fallback"
	_fonts[kind] = f
	if kind == &"num" and f is FontFile and font_sources[kind].begins_with("bundled"):
		# digits-only font: any other char (e.g. Hangul) comes from Galmuri11, never from the OS
		(f as FontFile).fallbacks = [font(&"ui")]
	if kind == &"ui":
		font_source = font_sources[kind]
	return f

static func reset_fonts() -> void:
	_fonts.clear()
	font_sources.clear()
	_digit_cell.clear()
	_theme = null

static func shadow_px(size: int) -> int:
	return 2 if size >= 24 else 1

## Ellipsizes (never shrinks: the pixel grid forbids arbitrary sizes) so text fits max_w.
## Returns [text, size] (size returned unchanged, kept for call-site compatibility).
static func fit_text(text: String, max_w: float, size: int, kind: StringName = &"ui") -> Array:
	var f := font(kind)
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return [text, size]
	var t := text
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		t = t.substr(0, t.length() - 1)
	return [t + "…", size]

static func text_width(text: String, size: int, kind: StringName = &"ui") -> float:
	return font(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Grid-safe label fit. Returns [text, size, kind]:
## 1) as requested if it fits; 2) ASCII-only text at 12 px may step down to Galmuri9 10 px (Latin/
## numerals cut, still on its native grid; Hangul never shrinks); 3) otherwise ellipsis at the
## requested size. Used for button labels where English expands (~35%) beyond Korean.
static func fit_label(text: String, max_w: float, size: int, kind: StringName = &"ui") -> Array:
	if text_width(text, size, kind) <= max_w:
		return [text, size, kind]
	if size == FONT_S and _is_numeric(text) and font_sources.get(&"num", "").begins_with("bundled") and text_width(text, NUM_S, &"num") <= max_w:
		return [text, NUM_S, &"num"]
	var f: Array = fit_text(text, max_w, size, kind)
	return [f[0], size, kind]

static func _baseline_y(f: Font, center_y: float, size: int) -> float:
	return roundf(center_y - f.get_height(size) / 2.0 + f.get_ascent(size))

static func _draw_shadowed(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int, color: Color, shadow: bool) -> void:
	if shadow:
		var s := shadow_px(size)
		ci.draw_string(f, pos + Vector2(s, s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(C_EDGE, color.a))
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func draw_text_centered(ci: CanvasItem, text: String, center: Vector2, size: int, color := C_TEXT, shadow := true, kind: StringName = &"ui") -> void:
	var f := font(kind)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_draw_shadowed(ci, f, Vector2(roundf(center.x - w / 2.0), _baseline_y(f, center.y, size)), text, size, color, shadow)

static func draw_text_left(ci: CanvasItem, text: String, left_mid: Vector2, size: int, color := C_TEXT, kind: StringName = &"ui") -> void:
	var f := font(kind)
	_draw_shadowed(ci, f, Vector2(roundf(left_mid.x), _baseline_y(f, left_mid.y, size)), text, size, color, true)

# ------------------------------------------------------------------ stable-width numerals

static func _is_numeric(text: String) -> bool:
	for ch in text:
		if ch.unicode_at(0) > 127:
			return false
	return true

## Width of one digit cell = widest of 0-9 at this size, so "111" and "888" have the same width.
static func digit_cell(size: int, kind: StringName = &"num") -> float:
	var k := "%s:%d" % [kind, size]
	if _digit_cell.has(k):
		return _digit_cell[k]
	var f := font(kind)
	var w := 0.0
	for d in 10:
		w = maxf(w, f.get_char_size(48 + d, size).x)
	_digit_cell[k] = w
	return w

static func number_width(text: String, size: int, kind: StringName = &"num") -> float:
	var f := font(kind)
	var cell := digit_cell(size, kind)
	var w := 0.0
	for ch in text:
		var c := ch.unicode_at(0)
		w += cell if c >= 48 and c <= 57 else f.get_char_size(c, size).x
	return w

## Draw a number string with fixed digit cells. align: -1 left edge at anchor.x, 0 centred, 1 right edge.
## Non-ASCII text (e.g. "최대") is routed to Galmuri11 12 px (Hangul minimum) instead.
static func draw_number(ci: CanvasItem, text: String, anchor: Vector2, size: int, color := C_TEXT, align := 0, kind: StringName = &"num") -> void:
	if not _is_numeric(text):
		if align == 0:
			draw_text_centered(ci, text, anchor, FONT_S, color)
		else:
			var w0 := text_width(text, FONT_S)
			draw_text_left(ci, text, Vector2(anchor.x - (w0 if align == 1 else 0.0), anchor.y), FONT_S, color)
		return
	var f := font(kind)
	var cell := digit_cell(size, kind)
	var w := number_width(text, size, kind)
	var x := anchor.x - (w / 2.0 if align == 0 else (w if align == 1 else 0.0))
	x = roundf(x)
	var by := _baseline_y(f, anchor.y, size)
	for ch in text:
		var c := ch.unicode_at(0)
		var cw := f.get_char_size(c, size).x
		var adv := cell if c >= 48 and c <= 57 else cw
		var gx := roundf(x + (adv - cw) / 2.0)    # centre narrow digits (e.g. "1") in the cell
		_draw_shadowed(ci, f, Vector2(gx, by), ch, size, color, true)
		x += adv

# ------------------------------------------------------------------ shapes

## Pixel-style bevelled box: dark edge, fill, 1px top highlight.
static func draw_pixel_box(ci: CanvasItem, r: Rect2, fill: Color, pressed := false) -> void:
	ci.draw_rect(r, C_EDGE)
	var inner := r.grow(-2)
	ci.draw_rect(inner, fill)
	if not pressed:
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), C_HILITE)
		ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(inner.size.x, 2)), Color(0, 0, 0, 0.25))
	else:
		ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), Color(0, 0, 0, 0.3))

static func draw_bar(ci: CanvasItem, r: Rect2, ratio: float, fill: Color) -> void:
	ci.draw_rect(r, C_EDGE)
	var inner := r.grow(-1)
	ci.draw_rect(inner, Color(0.05, 0.05, 0.08))
	var w := floorf(inner.size.x * clampf(ratio, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
		ci.draw_rect(Rect2(inner.position, Vector2(w, 1)), fill.lightened(0.35))

static func draw_star(ci: CanvasItem, c: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, C_STAR if on else C_STAR_OFF)
	pts.append(pts[0])
	ci.draw_polyline(pts, C_EDGE, 1.0)

## Simple vector glyphs for icons when no atlas is available.
static func draw_glyph(ci: CanvasItem, glyph: StringName, c: Vector2, s: float, color := C_TEXT) -> void:
	match glyph:
		&"left":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.6, -s), c + Vector2(s * 0.6, s)]), color)
		&"right":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.6, -s), c + Vector2(-s * 0.6, s)]), color)
		&"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s), Vector2(s * 0.5, s * 2)), color)
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s), Vector2(s * 0.5, s * 2)), color)
		&"coin":
			ci.draw_circle(c, s, C_EDGE)
			ci.draw_circle(c, s - 1, C_GOLD)
			ci.draw_rect(Rect2(c + Vector2(-1, -s * 0.5), Vector2(2, s)), C_GOLD.darkened(0.4))
		&"mana":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0)]), C_MANA)
		&"worker":
			ci.draw_circle(c + Vector2(0, -s * 0.45), s * 0.38, color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.05), Vector2(s, s * 0.9)), color)
		&"lock":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.1), Vector2(s * 1.2, s)), color)
			ci.draw_arc(c + Vector2(0, -s * 0.15), s * 0.4, PI, TAU, 8, color, 2.0)
		_:
			ci.draw_circle(c, s * 0.6, color)

# ------------------------------------------------------------------ atlas icons

static var _icon_cache: Dictionary = {}

## Frame from the always-resident UI atlas (manifest "ui".atlas, default ui_main). Cached; null if absent.
static func ui_icon(frame: String) -> Texture2D:
	if _icon_cache.has(frame):
		return _icon_cache[frame]
	var atlas_id := "ui_main"
	var atlas := _atlas_node()
	if atlas != null and atlas.get("manifest") is Dictionary:
		var ui = atlas.manifest.get("ui", {})
		if ui is Dictionary and ui.has("atlas"):
			atlas_id = str(ui.atlas)
	var tex := icon_texture({"atlas": atlas_id, "frame": frame})
	_icon_cache[frame] = tex
	return tex

static func clear_icon_cache() -> void:
	_icon_cache.clear()

static func _atlas_node() -> Node:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("Atlas")

## Draw a ui atlas icon centred at c with integer scale k; returns false if unavailable.
static func draw_ui_icon(ci: CanvasItem, frame: String, c: Vector2, k := 1.0, modulate := Color.WHITE) -> bool:
	var t := ui_icon(frame)
	if t == null:
		return false
	var sz := t.get_size() * k
	ci.draw_texture_rect(t, Rect2((c - sz / 2).round(), sz), false, modulate)
	return true

## Icon texture from the 03 atlas via the Atlas autoload (INTERFACES.md §4), or null.
static func icon_texture(icon: Variant) -> Texture2D:
	if not (icon is Dictionary) or not icon.has("atlas") or not icon.has("frame"):
		return null
	var atlas := _atlas_node()
	if atlas == null or not atlas.has_method("get_frame_texture"):
		return null
	var tex = atlas.get_frame_texture(str(icon.atlas), str(icon.frame))
	return tex if tex is Texture2D else null
