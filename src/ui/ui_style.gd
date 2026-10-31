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
	_prewarmed = false

## 08 R5: rasterise every glyph the UI can show, once per (font, size), at a loading point (main menu
## mount) so no new Hangul glyph is rasterised mid-battle (measured +9.4 ms hitch on first boss toast).
## Strings: the active locale's data/text table + UI fallbacks + digits. Returns elapsed msec.
static var _prewarmed := false
static var prewarm_ms := 0.0
static func prewarm_fonts() -> float:
	if _prewarmed:
		return 0.0
	_prewarmed = true
	var t0 := Time.get_ticks_usec()
	var UiTextS = load("res://src/ui/ui_text.gd")
	var chars := {}
	var add := func(s: String) -> void:
		for ch in s:
			chars[ch] = true
	for loc in ["ko", "en"]:
		var p := "res://data/text/%s.json" % loc
		if FileAccess.file_exists(p):
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(p)) == OK and j.data is Dictionary:
				for k in j.data.get("strings", {}):
					add.call(str(j.data.strings[k]))
	for k in UiTextS.FALLBACK_KO:
		add.call(str(UiTextS.FALLBACK_KO[k]))
	for k in UiTextS.FALLBACK_EN:
		add.call(str(UiTextS.FALLBACK_EN[k]))
	add.call("0123456789+-/.:%xv… ")
	var all := "".join(chars.keys())
	var ascii := ""
	for ch in chars:
		if ch.unicode_at(0) < 128:
			ascii += ch
	for pair in [[&"ui", [12, 24]], [&"bold", [12, 24, 36]], [&"num", [10, 20]]]:
		var f := font(pair[0])
		for sz in pair[1]:
			var s: String = ascii if pair[0] == &"num" else all
			f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)   # shapes + rasterises into the cache
	prewarm_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return prewarm_ms

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

## Multi-line fit used by wrapping buttons (round tiles) and by tests/07 checks:
## single line if it fits (with the 10 px Latin step), else word-wrap at the same size up to max_lines;
## only the last line is ellipsized if still too long. Returns {"lines": PackedStringArray, "size": int,
## "kind": StringName, "truncated": bool}.
static func fit_lines(text: String, max_w: float, size: int, max_lines := 2, kind: StringName = &"ui") -> Dictionary:
	if text_width(text, size, kind) <= max_w or max_lines <= 1:
		var one: Array = fit_label(text, max_w, size, kind)
		return {"lines": PackedStringArray([one[0]]), "size": one[1], "kind": one[2], "truncated": one[0] != text}
	# prefer wrapping at the same size over switching to the 10 px cut: tiles in one grid keep one
	# text size (15:45 capture: "Break the Mold Wall" alone at 10 px looked inconsistent)
	var w := wrap_text(text, max_w, size, kind)
	if w.size() <= max_lines:
		return {"lines": w, "size": size, "kind": kind, "truncated": false}
	var one2: Array = fit_label(text, max_w, size, kind)
	if one2[0] == text:
		return {"lines": PackedStringArray([text]), "size": one2[1], "kind": one2[2], "truncated": false}
	var out := w.slice(0, max_lines - 1)
	var rest := " ".join(w.slice(max_lines - 1))
	out.append(fit_text(rest, max_w, size, kind)[0])
	return {"lines": out, "size": size, "kind": kind, "truncated": true}

## Greedy word wrap at spaces (Korean words are space-separated too); a single over-long word is
## broken by characters. Never changes the font size.
static func wrap_text(text: String, max_w: float, size: int, kind: StringName = &"ui") -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var cand := word if line == "" else line + " " + word
		if text_width(cand, size, kind) <= max_w:
			line = cand
			continue
		if line != "":
			out.append(line)
		line = ""
		var w := word
		while text_width(w, size, kind) > max_w and w.length() > 1:
			var n := w.length()
			while n > 1 and text_width(w.substr(0, n), size, kind) > max_w:
				n -= 1
			out.append(w.substr(0, n))
			w = w.substr(n)
		line = w
	if line != "":
		out.append(line)
	return out

## Grid-safe label fit. Returns [text, size, kind]:
## 1) as requested if it fits; 2) ASCII-only text at 12 px may step down to Galmuri9 10 px (Latin/
## numerals cut, still on its native grid; Hangul never shrinks); 3) otherwise ellipsis at the
## requested size. Used for button labels where English expands (~35%) beyond Korean.
static func fit_label(text: String, max_w: float, size: int, kind: StringName = &"ui") -> Array:
	if text_width(text, size, kind) <= max_w:
		return [text, size, kind]
	font(&"num")   # make sure the numerals font is loaded before checking its source (07 QA-B009: fresh start → ellipsis)
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

## Economy (worker) button silhouette: octagon with cut corners + dough-coloured top band, so the
## worker button differs from unit cards by SHAPE, not only by a badge (07 QA-J3).
static func draw_pixel_octagon(ci: CanvasItem, r: Rect2, fill: Color, band: Color, pressed := false) -> void:
	var c := 6.0
	var outer := PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c),
		Vector2(r.end.x, r.end.y - c), Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, r.end.y - c), r.position + Vector2(0, c)])
	ci.draw_colored_polygon(outer, C_EDGE)
	var i := r.grow(-2)
	var ci2 := c - 1.0
	var inner := PackedVector2Array([i.position + Vector2(ci2, 0), Vector2(i.end.x - ci2, i.position.y), Vector2(i.end.x, i.position.y + ci2),
		Vector2(i.end.x, i.end.y - ci2), Vector2(i.end.x - ci2, i.end.y), Vector2(i.position.x + ci2, i.end.y), Vector2(i.position.x, i.end.y - ci2), i.position + Vector2(0, ci2)])
	ci.draw_colored_polygon(inner, fill.darkened(0.25) if pressed else fill)
	if not pressed:
		ci.draw_rect(Rect2(i.position.x + ci2, i.position.y, i.size.x - 2 * ci2, 3), band)

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
	var pts := _star_points(c, r)
	if not on:
		draw_star_hollow(ci, c, r)
		return
	ci.draw_colored_polygon(pts, C_STAR)
	pts.append(pts[0])
	ci.draw_polyline(pts, C_EDGE, 1.0)

## Unachieved star: outline only (no fill), so met/unmet differ by SHAPE and stay distinct in
## greyscale / for colour-blind players (09 R09-04-6), not just by yellow vs grey.
static func draw_star_hollow(ci: CanvasItem, c: Vector2, r: float, color := C_TEXT_DIM) -> void:
	var pts := _star_points(c, r)
	pts.append(pts[0])
	ci.draw_polyline(pts, C_EDGE, 3.0)
	ci.draw_polyline(pts, color, 1.0)

static func _star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append((c + Vector2(cos(a), sin(a)) * rr).round())
	return pts

## Star marker used by result rows and round tiles: met → atlas icon_star (or filled vector star);
## unmet → hollow vector star always (atlas icon_star_empty is a filled grey star = same shape).
## Returns "filled" | "hollow" (QA).
static func draw_star_marker(ci: CanvasItem, c: Vector2, met: bool, r := 7.0) -> String:
	if met:
		if not draw_ui_icon(ci, "icon_star", c):
			draw_star(ci, c, r, true)
		return "filled"
	draw_star_hollow(ci, c, r)
	return "hollow"

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
	var tex := icon_texture({"atlas": atlas_id, "frame": frame})   # guard applied inside icon_texture
	_icon_cache[frame] = tex
	return tex

## Guard against a stale imported texture vs. a regenerated frames file (observed 08:14: ui_main.json
## re-packed to 256×256 while the imported texture was still the old 256×128 → wrong icons drawn).
## On mismatch, icons are disabled (vector glyph fallbacks) and a warning is printed once.
static var _atlas_ok: Dictionary = {}
static var atlas_warnings: PackedStringArray = []
static func _atlas_consistent(atlas: Node, atlas_id: String) -> bool:
	if _atlas_ok.has(atlas_id):
		return _atlas_ok[atlas_id]
	var ok := true
	if atlas != null and atlas.get("pages") is Dictionary and atlas.pages.has(atlas_id):
		var p: Dictionary = atlas.pages[atlas_id]
		if p.get("tex") == null and atlas.has_method("acquire"):
			atlas.acquire(atlas_id)
		var tex = p.get("tex")
		var fpath := str((p.get("meta", {}) as Dictionary).get("frames", ""))
		if tex is Texture2D and fpath != "" and FileAccess.file_exists(fpath):
			var j := JSON.new()
			if j.parse(FileAccess.get_file_as_string(fpath)) == OK and j.data is Dictionary and j.data.get("size") is Array:
				var want := Vector2(float(j.data.size[0]), float(j.data.size[1]))
				if (tex as Texture2D).get_size() != want:
					ok = false
					var msg := "[UiStyle] atlas %s texture %s != frames file size %s (stale import?) → icons disabled" % [atlas_id, (tex as Texture2D).get_size(), want]
					atlas_warnings.append(msg)
					push_warning(msg)
	_atlas_ok[atlas_id] = ok and _import_fresh(atlas_id)
	return _atlas_ok[atlas_id]

## Dev-tree check: the imported texture must come from the current source PNG (Godot writes
## source_md5 into .godot/imported/<file>.md5). Observed 08:14: 03 re-packed ui_main.png/json at the
## same 256×256 size while the import was stale → wrong icons with no size mismatch. Exported builds
## contain no source PNG, so this check is skipped there.
static func _import_fresh(atlas_id: String) -> bool:
	var png := "res://assets/atlases/%s.png" % atlas_id
	var ok := import_is_fresh(png)
	if not ok:
		var msg := "[UiStyle] atlas %s import is stale (source PNG md5 %s not in its .godot/imported md5) → icons disabled until re-import" % [atlas_id, FileAccess.get_md5(png)]
		atlas_warnings.append(msg)
		push_warning(msg)
	return ok

## Pure check, testable with any png + .import pair: false ONLY when an import md5 record exists and
## its source_md5 differs from the current PNG. Missing PNG/.import/.md5 (e.g. exported build) → true,
## so the guard can never hide icons once the import matches again (recovery is automatic).
static func import_is_fresh(png: String) -> bool:
	var imp := png + ".import"
	if not FileAccess.file_exists(png) or not FileAccess.file_exists(imp):
		return true
	var cfg := ConfigFile.new()
	if cfg.load(imp) != OK:
		return true
	var dest := str(cfg.get_value("remap", "path", ""))
	if dest == "":
		var dests = cfg.get_value("deps", "dest_files", [])
		dest = str(dests[0]) if dests is Array and not dests.is_empty() else ""
	var md5_path := dest.get_basename() + ".md5"
	if dest == "" or not FileAccess.file_exists(md5_path):
		return true
	var rec := ConfigFile.new()
	var src := ""
	if rec.load(md5_path) == OK:
		src = str(rec.get_value("", "source_md5", ""))
	if src == "":
		return true
	return src == FileAccess.get_md5(png)

static func clear_icon_cache() -> void:
	_icon_cache.clear()
	_atlas_ok.clear()

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
	# same stale-import guard as ui_icon: engine-supplied icons (BattleInfo cards/skills) must not bypass it
	if not _atlas_consistent(atlas, str(icon.atlas)):
		return null
	var tex = atlas.get_frame_texture(str(icon.atlas), str(icon.frame))
	return tex if tex is Texture2D else null
