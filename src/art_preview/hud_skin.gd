extends Node
## Card-bar feedback for the release-slice preview, drawn through TouchButton.overlay (no HUD file is changed).
## Ideas from card / lane games that make spending feel good on a phone:
##   - a role colour stripe per card (the same colours as the portrait badges), so the bar reads by colour;
##   - "ready" state: a gold inner frame and a glint that sweeps across the card every few seconds;
##   - the moment a card becomes usable: a short gold pop around it;
##   - cooldown: a bright edge on the shade so the remaining time reads at a glance.
## Attach with HudSkin.attach(hud); it follows card rebuilds (each round) by itself.
const ROLE := {"melee_basic": Color("d0563f"), "ranged_basic": Color("78b257"), "tank": Color("5f86b8"),
	"fast": Color("a073c8"), "siege": Color("e0a83e")}
const GOLD := Color(1.0, 0.84, 0.36)
const MANA := Color(0.45, 0.72, 1.0)

var hud: Node = null
var _bound: Array = []
var _was_ready := {}
var _pop := {}
var t := 0.0

static func attach(p_hud: Node) -> Node:
	var old = p_hud.get_node_or_null("SliceHudSkin")
	if old != null: return old
	var s = load("res://src/art_preview/hud_skin.gd").new()
	s.name = "SliceHudSkin"
	s.hud = p_hud
	p_hud.add_child(s)
	return s

func _process(dt: float) -> void:
	t += dt
	if hud == null: return
	var cards: Array = hud.card_buttons
	var skills: Array = hud.skill_buttons
	if _bound != cards + skills:
		_bind(cards, skills)
	for b in _bound:
		if not is_instance_valid(b): continue
		var ready: bool = not b.disabled and b.cooldown_ratio <= 0.0
		if ready and not _was_ready.get(b, true):
			_pop[b] = t
		_was_ready[b] = ready
		b.queue_redraw()

func _bind(cards: Array, skills: Array) -> void:
	_bound = cards + skills
	var info: Dictionary = hud.info if hud.get("info") is Dictionary else {}
	var ids: Array = info.get("cards", [])
	for i in cards.size():
		var cid := str(ids[i].get("id", "")) if i < ids.size() else ""
		cards[i].overlay = _overlay.bind(ROLE.get(cid, GOLD), i)
	for i in skills.size():
		skills[i].overlay = _overlay.bind(MANA, i + 10)
	_was_ready.clear()

func _overlay(b: Control, col: Color, idx: int) -> void:
	var w := b.size.x
	var h := b.size.y
	var ready: bool = not b.disabled and b.cooldown_ratio <= 0.0
	# role stripe under the top edge
	b.draw_rect(Rect2(2, 2, w - 4, 3), col if not b.disabled else col.darkened(0.55))
	b.draw_rect(Rect2(2, 2, w - 4, 1), col.lightened(0.35) if not b.disabled else col.darkened(0.4))
	if b.cooldown_ratio > 0.0:
		var y := 2.0 + floorf((h - 4.0) * clampf(b.cooldown_ratio, 0.0, 1.0))
		b.draw_rect(Rect2(2, y, w - 4, 1), Color(1, 1, 1, 0.55))
	if ready:
		# gold inner frame
		var g := GOLD
		g.a = 0.75 + 0.25 * sin(t * 4.0 + idx)
		b.draw_rect(Rect2(2, 2, w - 4, h - 4), g, false, 1.0)
		# glint: a narrow slanted band sweeping left to right every 2.8 s (staggered per card)
		var cyc := fmod(t + idx * 0.37, 2.8)
		if cyc < 0.5:
			var x := -8.0 + (w + 16.0) * (cyc / 0.5)
			var top := 3.0
			var bot := h - 3.0
			var slant := (bot - top) * 0.35
			var pts := PackedVector2Array([Vector2(x, top), Vector2(x + 4, top), Vector2(x + 4 - slant, bot), Vector2(x - slant, bot)])
			for i in pts.size():
				pts[i].x = clampf(pts[i].x, 3.0, w - 3.0)
			if pts[1].x - pts[0].x > 0.5 or pts[2].x - pts[3].x > 0.5:
				b.draw_colored_polygon(pts, Color(1, 1, 1, 0.28))
	# pop when it just became usable
	if _pop.has(b):
		var k := (t - float(_pop[b])) / 0.35
		if k >= 1.0:
			_pop.erase(b)
		else:
			var grow := 1.0 + k * 4.0
			var c := GOLD
			c.a = 1.0 - k
			b.draw_rect(Rect2(-grow, -grow, w + grow * 2.0, h + grow * 2.0), c, false, 2.0)
			for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
				var d: Vector2 = (corner - Vector2(w, h) * 0.5).normalized() * (3.0 + k * 6.0)
				b.draw_rect(Rect2(corner + d - Vector2(1, 1), Vector2(2, 2)), c)
