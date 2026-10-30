extends RefCounted
## Pure HUD layout calculation (no nodes) so it can be unit-tested for every screen shape.
## Owner: 04-client. All rects are in logical viewport units.
##
## Layout (landscape):
##   top-left  : resources (gold + income, mana bar)      top-centre: base HP bars + wave     top-right: pause
##   bottom-left: hero ◀ ▶ (hold)   bottom-centre: worker + unit cards   bottom-right: hero skills
## If the bottom row does not fit, cards shrink to the minimum target, then skills move to a
## right-hand column above the bottom row.

const GAP := 4.0

static func compute(view: Vector2, safe: Rect2, n_cards: int, n_skills: int, min_target: float) -> Dictionary:
	var t := maxf(min_target, 40.0)
	var m := 4.0
	var s := safe.grow(-m)
	var out := {}
	out.min_target = t
	out.safe = safe

	# --- top row ---
	var top_h := t
	var pause_r := Rect2(Vector2(s.end.x - t, s.position.y), Vector2(t, t))
	out.pause = pause_r
	var res_w := clampf(s.size.x * 0.26, 132.0, 180.0)
	out.resources = Rect2(s.position, Vector2(res_w, top_h))
	var bars_x := s.position.x + res_w + GAP * 2
	var bars_end := pause_r.position.x - GAP * 2
	out.bases = Rect2(Vector2(bars_x, s.position.y), Vector2(maxf(bars_end - bars_x, 60.0), 22.0))
	out.wave = Rect2(Vector2(bars_x, s.position.y + 24.0), Vector2(out.bases.size.x, 14.0))

	# --- bottom row ---
	var move := maxf(t, 52.0)
	var card_h := maxf(t + 8.0, 56.0)
	var row_bottom := s.end.y
	out.move_left = Rect2(Vector2(s.position.x, row_bottom - move), Vector2(move, move))
	out.move_right = Rect2(Vector2(s.position.x + move + GAP * 2, row_bottom - move), Vector2(move, move))
	var left_end: float = (out.move_right as Rect2).end.x + GAP * 3

	var skill := maxf(t, 48.0)
	var n_items := n_cards + 1  # worker button + cards
	var card_w := maxf(t, 50.0)
	var skills_in_row := true

	var right_start := s.end.x - (n_skills * skill + maxi(n_skills - 1, 0) * GAP) - (GAP * 3 if n_skills > 0 else 0.0)
	var avail := right_start - left_end
	var need := n_items * card_w + (n_items - 1) * GAP
	if need > avail:
		# shrink cards down to the minimum target
		card_w = maxf(t, (avail - (n_items - 1) * GAP) / maxf(n_items, 1))
		need = n_items * card_w + (n_items - 1) * GAP
	if need > avail and n_skills > 0:
		skills_in_row = false
		right_start = s.end.x
		avail = right_start - left_end
		card_w = clampf((avail - (n_items - 1) * GAP) / maxf(n_items, 1), t, maxf(t, 50.0))
		need = n_items * card_w + (n_items - 1) * GAP
	out.skills_in_row = skills_in_row
	out.overflow = need > avail + 0.5

	# centre the card strip inside available space
	var x0 := left_end + maxf(0.0, (avail - need) / 2.0)
	var cards: Array[Rect2] = []
	for i in n_items:
		cards.append(Rect2(Vector2(x0 + i * (card_w + GAP), row_bottom - card_h), Vector2(card_w, card_h)))
	out.worker = cards[0]
	out.cards = cards.slice(1)

	var skills: Array[Rect2] = []
	for i in n_skills:
		if skills_in_row:
			var x := s.end.x - (n_skills - i) * skill - (n_skills - 1 - i) * GAP
			skills.append(Rect2(Vector2(x, row_bottom - skill), Vector2(skill, skill)))
		else:
			var y := row_bottom - card_h - GAP * 2 - (i + 1) * skill - i * GAP
			skills.append(Rect2(Vector2(s.end.x - skill, y), Vector2(skill, skill)))
	out.skills = skills

	out.toast = Rect2(Vector2(s.position.x, s.position.y + top_h + 26.0), Vector2(s.size.x, 20.0))
	out.banner = Rect2(Vector2(s.position.x, view.y * 0.30), Vector2(s.size.x, 32.0))
	return out

## All interactive rects, for validation.
static func touch_rects(l: Dictionary) -> Array[Rect2]:
	var r: Array[Rect2] = [l.pause, l.move_left, l.move_right, l.worker]
	for c in l.cards:
		r.append(c)
	for c in l.skills:
		r.append(c)
	return r

## Returns a list of human-readable problems (empty = valid).
static func validate(l: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var rects := touch_rects(l)
	var safe: Rect2 = l.safe
	var t: float = l.min_target
	for i in rects.size():
		var a: Rect2 = rects[i]
		if a.size.x + 0.01 < t or a.size.y + 0.01 < t:
			problems.append("target %d too small %s < %.1f" % [i, a.size, t])
		if not safe.encloses(a):
			problems.append("target %d %s outside safe %s" % [i, a, safe])
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j]
			if a.intersects(b):
				problems.append("targets %d and %d overlap %s %s" % [i, j, a, b])
	for key in ["resources", "bases"]:
		var r: Rect2 = l[key]
		if r.intersects(l.pause):
			problems.append("%s overlaps pause" % key)
	if l.overflow:
		problems.append("bottom row overflow")
	return problems
