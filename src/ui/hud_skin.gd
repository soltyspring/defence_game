extends Node
## Card-bar and top-bar feedback for the battle HUD, drawn on two overlay Controls (no button redraws).
## Ideas from card / lane games that make spending feel good on a phone:
##   - a role colour stripe per card (the same colours as the portrait badges), so the bar reads by colour;
##   - "ready" state: a gold inner frame and a glint that sweeps across the ready cards every few seconds;
##   - the moment a card becomes usable: a short gold pop around it;
##   - cooldown: a bright edge on the shade so the remaining time reads at a glance.
## hud.gd attaches it in _build (HudSkin.attach(self)); it follows card rebuilds (each round) by itself.
## 08 H15 redraw-on-change: both layers redraw only when what they show changes (state signature per frame),
## so identical snapshots cost no redraw while nothing animates.
const ROLE := {"melee_basic": Color("d0563f"), "ranged_basic": Color("78b257"), "tank": Color("5f86b8"),
	"fast": Color("a073c8"), "siege": Color("e0a83e")}
const GOLD := Color(1.0, 0.84, 0.36)
const MANA := Color(0.45, 0.72, 1.0)
const GLINT_CYCLE := 3.2      # one sweep across all ready cards every 3.2 s
const GLINT_STEP := 0.07      # card i starts its sweep 0.07 s after card i-1
const GLINT_LEN := 0.45
const POP_LEN := 0.35

var hud: Node = null
var _bound: Array = []
var _cols: Array = []
var _was_ready := {}
var _pop := {}
var _sig := []
var t := 0.0

var top_skin: Control = null
var card_skin: Control = null

static func attach(p_hud: Node) -> Node:
	var old = p_hud.get_node_or_null("HudSkin")
	if old != null: return old
	var s = load("res://src/ui/hud_skin.gd").new()
	s.name = "HudSkin"
	s.hud = p_hud
	p_hud.add_child(s)
	var ts := TopSkin.new()
	ts.name = "HudTopSkin"
	ts.hud = p_hud
	ts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ts.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_hud.add_child(ts)
	p_hud.move_child(ts, p_hud.top.get_index() + 1)
	s.top_skin = ts
	var cs := CardSkin.new()
	cs.name = "HudCardSkin"
	cs.skin = s
	cs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_hud.add_child(cs)
	s.card_skin = cs
	return s

func _exit_tree() -> void:
	if is_instance_valid(top_skin): top_skin.queue_free()
	if is_instance_valid(card_skin): card_skin.queue_free()

func _process(dt: float) -> void:
	t += dt
	if hud == null or not is_instance_valid(card_skin): return
	var cards: Array = hud.card_buttons
	var skills: Array = hud.skill_buttons
	if _bound != cards + skills:
		_bind(cards, skills)
	var sig := []
	var any_ready := false
	for i in _bound.size():
		var b = _bound[i]
		if not is_instance_valid(b) or not b.is_visible_in_tree():
			sig.append(null)
			continue
		var ready: bool = not b.disabled and b.cooldown_ratio <= 0.0
		if ready and not _was_ready.get(b, true):
			_pop[b] = t
		_was_ready[b] = ready
		any_ready = any_ready or ready
		sig.append([b.position, b.size, b.disabled, ready, floori(b.cooldown_ratio * b.size.y)])
	for b in _pop.keys():
		if t - float(_pop[b]) >= POP_LEN: _pop.erase(b)
	# animated parts add a time key only while they actually move
	if not _pop.is_empty(): sig.append(floori(t * 30.0))
	elif any_ready and fmod(t, GLINT_CYCLE) < GLINT_LEN + GLINT_STEP * _bound.size(): sig.append(floori(t * 30.0))
	if sig != _sig:
		_sig = sig
		card_skin.queue_redraw()

func _bind(cards: Array, skills: Array) -> void:
	_bound = cards + skills
	_cols.clear()
	var info: Dictionary = hud.info if hud.get("info") is Dictionary else {}
	var ids: Array = info.get("cards", [])
	for i in cards.size():
		var cid := str(ids[i].get("id", "")) if i < ids.size() else ""
		_cols.append(ROLE.get(cid, GOLD))
	for i in skills.size():
		_cols.append(MANA)
	_was_ready.clear()
	_pop.clear()
	# draw right above the newest buttons (cards are re-added at the end of the HUD each round)
	var last := -1
	for b in _bound:
		if is_instance_valid(b) and b.get_parent() == hud: last = maxi(last, b.get_index())
	if last >= 0 and card_skin.get_parent() == hud:
		hud.move_child(card_skin, mini(last + 1, hud.get_child_count() - 1))

## The card / skill decorations, drawn for every bound button at its rect.
class CardSkin extends Control:
	var skin: Node
	func _draw() -> void:
		if skin == null: return
		for i in skin._bound.size():
			var b = skin._bound[i]
			if not is_instance_valid(b) or not b.is_visible_in_tree(): continue
			_card(b, Rect2(b.global_position - global_position, b.size), skin._cols[i] if i < skin._cols.size() else GOLD, i)

	func _card(b: Control, r: Rect2, col: Color, idx: int) -> void:
		var o := r.position
		var w := r.size.x
		var h := r.size.y
		var ready: bool = not b.disabled and b.cooldown_ratio <= 0.0
		# role stripe under the top edge
		draw_rect(Rect2(o + Vector2(2, 2), Vector2(w - 4, 3)), col if not b.disabled else col.darkened(0.55))
		draw_rect(Rect2(o + Vector2(2, 2), Vector2(w - 4, 1)), col.lightened(0.35) if not b.disabled else col.darkened(0.4))
		var t: float = skin.t
		if ready:
			var g := GOLD
			g.a = 0.9
			draw_rect(Rect2(o + Vector2(2, 2), Vector2(w - 4, h - 4)), g, false, 1.0)
			# glint: a narrow slanted band sweeping left to right, card by card
			var cyc := fmod(t, GLINT_CYCLE) - idx * GLINT_STEP
			if cyc >= 0.0 and cyc < GLINT_LEN:
				var x := -8.0 + (w + 16.0) * (cyc / GLINT_LEN)
				var top := 3.0
				var bot := h - 3.0
				var slant := (bot - top) * 0.35
				var pts := PackedVector2Array([Vector2(x, top), Vector2(x + 4, top), Vector2(x + 4 - slant, bot), Vector2(x - slant, bot)])
				for i in pts.size():
					pts[i].x = clampf(pts[i].x, 3.0, w - 3.0)
					pts[i] += o
				if pts[1].x - pts[0].x > 0.5 or pts[2].x - pts[3].x > 0.5:
					draw_colored_polygon(pts, Color(1, 1, 1, 0.28))
		# pop when it just became usable
		if skin._pop.has(b):
			var k := (t - float(skin._pop[b])) / POP_LEN
			if k < 1.0:
				var grow := 1.0 + k * 4.0
				var c := GOLD
				c.a = 1.0 - k
				draw_rect(Rect2(o - Vector2(grow, grow), Vector2(w, h) + Vector2(grow, grow) * 2.0), c, false, 2.0)
				for corner in [Vector2(0, 0), Vector2(w, 0), Vector2(0, h), Vector2(w, h)]:
					var d: Vector2 = (corner - Vector2(w, h) * 0.5).normalized() * (3.0 + k * 6.0)
					draw_rect(Rect2(o + corner + d - Vector2(1, 1), Vector2(2, 2)), c)

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
	var _sig := []
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
		var lay: Dictionary = hud.top.layout if hud.top.get("layout") is Dictionary else {}
		var full := float(snap.get("gold_max", 0)) > 0 and float(snap.get("gold", 0)) >= float(snap.get("gold_max", 0))
		var sig := [lay.get("resources"), lay.get("bases"), roundi(shown.player * 400), roundi(shown.enemy * 400),
			roundi(ghost.player * 400), roundi(ghost.enemy * 400), full, shown.player < 0.3]
		if full or shown.player < 0.3: sig.append(floori(t * 20.0))
		if sig != _sig:
			_sig = sig
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
		# base HP strip: one crust frame around the plate, the damage trail and the low-HP pulse on the bars themselves
		var g: Dictionary = hud.top.base_bars(lay.bases)
		var pr: Rect2 = g.left
		var er: Rect2 = g.right
		_ghost(pr, shown.player, ghost.player, false)
		_ghost(er, shown.enemy, ghost.enemy, true)
		_frame(g.plate, crust, crust_d)
		if shown.player < 0.3:
			draw_rect(pr.grow(2), Color(1.0, 0.3, 0.25, 0.4 + 0.4 * sin(t * 8.0)), false, 2.0)
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
