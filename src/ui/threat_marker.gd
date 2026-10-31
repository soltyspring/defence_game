extends Control
## Off-screen threat marker at the left/right edge of the battlefield (03 A11, 09 X9 M3 "nest or enemy
## indicator visible at t = 10 s", 02 CAMERA_FRAMING_OPTIONS option B). Owner: 04-client.
## Shows direction (arrow pointing out of the screen), what is there (nest / enemy icon) and how far
## (metres past the screen edge). Never takes input (battlefield drags pass through).
##
## Input: HudSnapshot field `threat` (requested from 02, 04→02 R16). While it is missing the marker
## stays hidden, so it is inert until 02 publishes it:
##   view_left, view_right : world x range on screen (camera)
##   nest_left             : world x of the nest's drawn left edge
##   enemy_visible         : bool, any alive enemy unit on screen
##   enemy_right           : world x of the nearest alive enemy unit right of the screen (key absent = none)
##   enemy_left            : world x of the nearest alive enemy unit left of the screen (key absent = none)
## Rules (pure, see compute()):
##   right: enemy if no enemy is on screen and one is to the right; else nest while less than
##          NEST_MIN_VISIBLE px of it is on screen (03: its left 24-40 px pass the contrast lines); else none.
##   left : enemy if one is left of the screen (it is walking at the player base behind the camera).
## Icons: ui_main frames `icon_nest` (03 A12, 6949499) / `icon_skull` (existing) for enemies, 16x16;
## vector shapes if a frame is missing. Shapes differ (dome vs skull/diamond), so the kind never depends on colour alone.

const UiStyle := preload("res://src/ui/ui_style.gd")

const PX_PER_M := 16.0          # 1 m = 16 world px (a 24 px soldier is 1.5 m); lane 1600 px = 100 m
const NEST_MIN_VISIBLE := 24.0
const MAX_M := 999
const SIZE := Vector2(44, 34)   # plate: 16x16 icon + arrow on the top row, distance (12 px) below
const ICON := {"nest": "icon_nest", "enemy": "icon_skull"}
const C_NEST := Color(0.52, 0.62, 0.44)
const C_NEST_SPOT := Color(0.20, 0.26, 0.18)

## "left"/"right" marker this control draws.
var side := &"right"
var state: Dictionary = {}:     # {"kind": "nest"|"enemy"|"", "m": int}; redraw only on change (08 H15)
	set(v):
		if v != state:
			state = v
			visible = str(v.get("kind", "")) != ""
			queue_redraw()
var redraws := 0                 # QA

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

static func metres(px: float) -> int:
	return clampi(ceili(maxf(px, 0.0) / PX_PER_M), 1, MAX_M)

## Pure decision for both edges. t = HudSnapshot.threat (may be empty → nothing shown).
static func compute(t: Dictionary) -> Dictionary:
	var none := {"kind": "", "m": 0}
	var out := {"right": none, "left": none}
	if t.is_empty() or not t.has("view_left") or not t.has("view_right"):
		return out
	var vl := float(t.view_left)
	var vr := float(t.view_right)
	var seen := bool(t.get("enemy_visible", false))
	if not seen and t.get("enemy_right") != null and float(t.enemy_right) > vr:
		out.right = {"kind": "enemy", "m": metres(float(t.enemy_right) - vr)}
	elif t.get("nest_left") != null and float(t.nest_left) > vr - NEST_MIN_VISIBLE:
		out.right = {"kind": "nest", "m": metres(float(t.nest_left) - vr)}
	if t.get("enemy_left") != null and float(t.enemy_left) < vl:
		out.left = {"kind": "enemy", "m": metres(vl - float(t.enemy_left))}
	return out

func label() -> String:
	# Fixed unit string: "m" reads the same in ko and en, so no data/text key (07 QA-B019: ui.distance_m was
	# referenced but never added; 01 R9 withdrawn).
	return "%dm" % int(state.get("m", 0))

func _draw() -> void:
	var kind := str(state.get("kind", ""))
	if kind == "":
		return
	redraws += 1
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UiStyle.C_TOAST_BG)
	draw_rect(r, UiStyle.C_EDGE, false, 1.0)
	var out_dir := 1.0 if side == &"right" else -1.0
	# top row: icon on the inner side, arrow on the outer side (points off-screen)
	var icon_c := Vector2(size.x * 0.5 - out_dir * 7.0, 11.0).round()
	var arrow_c := Vector2(size.x * 0.5 + out_dir * 13.0, 11.0).round()
	var tex: Texture2D = UiStyle.ui_icon(ICON.get(kind, ""))
	if tex != null:
		draw_texture_rect(tex, Rect2(icon_c - Vector2(8, 8), Vector2(16, 16)), false)
	elif kind == "nest":
		_draw_nest(icon_c)
	else:
		_draw_enemy(icon_c)
	UiStyle.draw_glyph(self, &"right" if side == &"right" else &"left", arrow_c, 5.0, UiStyle.C_HP_ENEMY if kind == "enemy" else UiStyle.C_TEXT)
	UiStyle.draw_text_centered(self, label(), Vector2(size.x * 0.5, 26.0), UiStyle.FONT_S, UiStyle.C_TEXT)

## Fallback nest: a mould dome with dark spots (03's nest silhouette is a mound).
func _draw_nest(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		pts.append((c + Vector2(cos(a) * 8.0, 4.0 + sin(a) * 10.0)).round())
	draw_colored_polygon(pts, C_NEST)
	draw_rect(Rect2(c + Vector2(-8, 4), Vector2(16, 2)), C_NEST_SPOT)
	for p in [Vector2(-4, -2), Vector2(2, -4), Vector2(3, 1)]:
		draw_rect(Rect2((c + p).round(), Vector2(2, 2)), C_NEST_SPOT)

## Fallback enemy: red diamond with a white "!".
func _draw_enemy(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]), UiStyle.C_HP_ENEMY)
	draw_rect(Rect2(c + Vector2(-1, -5), Vector2(2, 6)), UiStyle.C_TEXT)
	draw_rect(Rect2(c + Vector2(-1, 3), Vector2(2, 2)), UiStyle.C_TEXT)
