extends RefCounted
## Pixel UI palette, theme and shared draw helpers. Owner: 04-client.
## Until 03 publishes a `ui` atlas (assets/manifest.json "ui"), everything is drawn with flat
## pixel-style boxes so the UI stays readable. When the atlas exists, icons come from Atlas.

const C_BG := Color(0.09, 0.10, 0.14)
const C_PANEL := Color(0.13, 0.15, 0.21, 0.92)
const C_PANEL_LIGHT := Color(0.22, 0.25, 0.33, 0.95)
const C_EDGE := Color(0.03, 0.03, 0.05)
const C_HILITE := Color(1, 1, 1, 0.18)
const C_TEXT := Color(0.96, 0.94, 0.88)
const C_TEXT_DIM := Color(0.62, 0.64, 0.70)
const C_GOLD := Color(1.0, 0.80, 0.25)
const C_MANA := Color(0.35, 0.65, 1.0)
const C_HP_PLAYER := Color(0.36, 0.85, 0.42)
const C_HP_ENEMY := Color(0.93, 0.32, 0.30)
const C_ACCENT := Color(0.98, 0.62, 0.20)
const C_DISABLED := Color(0.30, 0.31, 0.35, 0.92)
const C_DIM := Color(0, 0, 0, 0.55)
const C_STAR := Color(1.0, 0.85, 0.2)
const C_STAR_OFF := Color(0.30, 0.30, 0.36)

const FONT_S := 9
const FONT_M := 12
const FONT_L := 18
const FONT_XL := 28

static var _theme: Theme

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font_size = FONT_M
	for t in ["Label", "Button"]:
		th.set_color("font_color", t, C_TEXT)
	th.set_color("font_outline_color", "Label", C_EDGE)
	th.set_constant("outline_size", "Label", 3)
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

static func font() -> Font:
	return ThemeDB.fallback_font

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

static func draw_text_centered(ci: CanvasItem, text: String, center: Vector2, size: int, color := C_TEXT, outline := true) -> void:
	var f := font()
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pos := Vector2(roundf(center.x - ts.x / 2.0), roundf(center.y + f.get_ascent(size) / 2.0 - 1))
	if outline:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, C_EDGE)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func draw_text_left(ci: CanvasItem, text: String, left_mid: Vector2, size: int, color := C_TEXT) -> void:
	var f := font()
	var pos := Vector2(roundf(left_mid.x), roundf(left_mid.y + f.get_ascent(size) / 2.0 - 1))
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, C_EDGE)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

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

## Icon texture from the 03 atlas via the Atlas autoload (INTERFACES.md §4), or null.
static func icon_texture(icon: Variant) -> Texture2D:
	if not (icon is Dictionary) or not icon.has("atlas") or not icon.has("frame"):
		return null
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var atlas: Node = (loop as SceneTree).root.get_node_or_null("Atlas")
	if atlas == null or not atlas.has_method("get_frame_texture"):
		return null
	var tex = atlas.get_frame_texture(str(icon.atlas), str(icon.frame))
	return tex if tex is Texture2D else null
