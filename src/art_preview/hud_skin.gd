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

var top_skin: Control = null

static func attach(p_hud: Node) -> Node:
	var old = p_hud.get_node_or_null("SliceHudSkin")
	if old != null: return old
	var s = load("res://src/art_preview/hud_skin.gd").new()
	s.name = "SliceHudSkin"
	s.hud = p_hud
	p_hud.add_child(s)
	var ts := TopSkin.new()
	ts.name = "SliceTopSkin"
	ts.hud = p_hud
	ts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ts.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_hud.add_child(ts)
	p_hud.move_child(ts, p_hud.top.get_index() + 1)
	s.top_skin = ts
	return s

func _exit_tree() -> void:
	if is_instance_valid(top_skin): top_skin.queue_free()

## Ornaments and feedback over the top bar (hud_top.gd draws the numbers; this only adds on top):
##   resource panel: crust frame with corner studs; flour at its cap -> a gold pulse (spend it!)
##   base HP bars: a white "damage ghost" chunk that drains after a hit (fighting-game bars);
##   your base below 30 % -> a red pulsing outline.
class TopSkin extends Control:
	var hud: Node
	var t := 0.0
	var ghost := {"player": 1.0, "enemy": 1.0}
	var shown := {"player": 1.0, "enemy": 1.0}
	var hold := {"player": 0.0, "enemy": 0.0}
	func _process(dt: float) -> void:
		t += dt
		if hud == null: return
		var snap: Dictionary = hud.snap if hud.get("snap") is Dictionary else {}
		for side in ["player", "enemy"]:
			var b: Dictionary = snap.get(side + "_base", {})
			var r := float(b.get("hp", 1)) / maxf(1.0, float(b.get("hp_max", 1)))
			if r < shown[side]: hold[side] = 0.45
			shown[side] = r
			if r > ghost[side]: ghost[side] = r
			elif hold[side] > 0.0: hold[side] -= dt
			else: ghost[side] = maxf(r, ghost[side] - dt * 0.35)
		queue_redraw()
	func _draw() -> void:
		var lay: Dictionary = hud.top.layout if hud.top.get("layout") is Dictionary else {}
		if lay.is_empty(): return
		var snap: Dictionary = hud.snap if hud.get("snap") is Dictionary else {}
		var crust := Color("c27d3e")
		var crust_d := Color("6b3a24")
		var res: Rect2 = lay.resources
		_frame(res, crust, crust_d)
		var gold := float(snap.get("gold", 0))
		var gmax := float(snap.get("gold_max", 0))
		if gmax > 0 and gold >= gmax:
			var c := Color(1.0, 0.85, 0.35, 0.45 + 0.35 * sin(t * 5.0))
			draw_rect(res.grow(1), c, false, 2.0)
		var r: Rect2 = lay.bases
		var half := floorf((r.size.x - 18) / 2)
		var y := r.position.y + 4
		var pr := Rect2(r.position.x, y, half, 16)
		var er := Rect2(r.position.x + half + 18, y, half, 16)
		_ghost(pr.grow(-1), shown.player, ghost.player, false)
		_ghost(er.grow(-1), shown.enemy, ghost.enemy, true)
		_frame(pr, crust, crust_d)
		_frame(er, Color("5f8387"), Color("24383c"))
		if shown.player < 0.3:
			draw_rect(pr.grow(1), Color(1.0, 0.3, 0.25, 0.4 + 0.4 * sin(t * 8.0)), false, 2.0)
	func _ghost(inner: Rect2, now: float, was: float, mirror: bool) -> void:
		if was <= now + 0.002: return
		var x0 := inner.size.x * now
		var w := inner.size.x * (was - now)
		var rr := Rect2(inner.position.x + x0, inner.position.y, w, inner.size.y)
		if mirror: rr.position.x = inner.end.x - inner.size.x * was
		draw_rect(rr, Color(1, 0.97, 0.85, 0.85))
	func _frame(r: Rect2, c: Color, d: Color) -> void:
		draw_rect(Rect2(r.position.x, r.position.y - 1, r.size.x, 1), c)
		draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), d)
		for p in [r.position, Vector2(r.end.x - 3, r.position.y), Vector2(r.position.x, r.end.y - 3), r.end - Vector2(3, 3)]:
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(4, 4)), d)
			draw_rect(Rect2(p, Vector2(2, 2)), c.lightened(0.3))

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
