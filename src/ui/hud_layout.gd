extends RefCounted
## Pure HUD layout calculation (no nodes) so it can be unit-tested for every screen shape.
## Owner: 04-client. All rects are in logical viewport units.
##
## Layout (landscape), option B of docs/qa/UI_LAYOUT_REFERENCE.md (genre conventions shared by ≥ 3 of 5 lane-defence games):
##   top-left  : resources (gold + income, mana bar)      top-centre: base HP bars + wave     top-right: pause
##   edges, top half: off-screen threat markers (01 R10: ≥ 48 dp, never covered)
##   bottom-left: hero ◀ ▶ (hold) │ worker (own group) │ unit cards │ hero skills :bottom-right
## Groups are GROUP_GAP apart so the economy button is not read as a unit card (07 QA-J3, 09 §27.3).
## If the bottom row does not fit: the skill buttons, then the move buttons shrink to the minimum target before a
## card gets narrower than its name; then the cards shrink to the target; only then the skills stack in a column.

const GAP := 4.0
const GROUP_GAP := 12.0                       # between move | worker | cards | skills
const TOUCH_GAP := 8.0                        # between neighbouring touch targets: 8 dp (07 LAYOUT L4, QA-B027)
const GROUND_FROM_BOTTOM := 70.0              # 360 - battle_view.ground_y (290), bottom-anchored camera (02)
const LANE_ABOVE_GROUND := 56.0               # lane band: boss 45 px + HP bar + margin (07 baseline sizes)
const THREAT_MIN := 44.0                      # marker plate ≥ 44 px = 48 dp on the 393 dp phone (01 R10)
const THREAT_SIZE := Vector2(44, 34)          # = ThreatMarker.SIZE (content block)
const CARD_NAME_W := 42.0                     # 36 px ko card name (Galmuri11 12) + 6 px padding (touch_button fit_lines)

const FIT_GAP := 2.0                          # gap between controls in the last-resort "fit" row
const FIT_MIN := 16.0                         # smallest control in the fit row (mouse-only window sizes)
const MAP_MIN := 84.0                         # overview strip: 15 % of the width, 84-104 px (was 22 %, 126-150)
const MAP_MAX := 104.0

## boss_bar = false (no boss alive): the feedback strips and threat markers move up into the unused boss-bar row.
static func compute(view: Vector2, safe: Rect2, n_cards: int, n_skills: int, min_target: float, boss_bar := true) -> Dictionary:
	var t := maxf(min_target, 40.0)
	var m := 4.0
	var s := safe.grow(-m)
	var out := {}
	out.min_target = t
	out.safe = safe
	out.view = view

	# --- top row ---
	var top_h := t
	var pause_r := Rect2(Vector2(s.end.x - t, s.position.y), Vector2(t, t))
	out.pause = pause_r
	var res_w := clampf(s.size.x * 0.26, 132.0, 180.0)
	out.resources = Rect2(s.position, Vector2(res_w, top_h))
	var bars_x := s.position.x + res_w + GAP * 2
	var follow_r := Rect2(pause_r.position.x-TOUCH_GAP-t,s.position.y,t,t)
	var map_w := roundf(clampf(s.size.x*0.15,MAP_MIN,MAP_MAX))
	var map_r := Rect2(follow_r.position.x-TOUCH_GAP-map_w,s.position.y,map_w,t)
	var bars_end := map_r.position.x - GAP * 2
	if bars_end - bars_x < 60.0:
		# Too narrow for bars + overview: drop the overview (zero-size = hidden, no input) instead of letting it
		# cover the base HP bars. Dragging the battlefield still scouts.
		map_r = Rect2(follow_r.position, Vector2(0.0, t))
		bars_end = follow_r.position.x - GAP * 2
	out.minimap = map_r
	out.follow = follow_r
	out.compact = true
	out.bases = Rect2(Vector2(bars_x, s.position.y), Vector2(maxf(bars_end - bars_x, 60.0), 22.0))
	out.wave = Rect2(Vector2(bars_x, s.position.y + 24.0), Vector2(out.bases.size.x, 14.0))

	# --- bottom row: move │ worker │ cards │ skills ---
	var move := maxf(t, 52.0)
	var card_h := maxf(t + 8.0, 56.0)
	var row_bottom := s.end.y
	var skill := maxf(t, 48.0)
	var skills_in_row := true
	# fit order: the icon-only skill buttons, then the move buttons (held, so they keep their size longest) shrink
	# to the target before a card gets narrower than CARD_NAME_W (3-syllable ko names are 36 px at 12 px + 6 px
	# padding); cards then shrink to the target; only below that the skills stack in a column.
	var gg := GROUP_GAP
	var cw_fit := _card_fit(s.size.x, n_cards, move, skill, n_skills, gg)
	if cw_fit < maxf(t, CARD_NAME_W):
		skill = t
		cw_fit = _card_fit(s.size.x, n_cards, move, skill, n_skills, gg)
	if cw_fit < maxf(t, CARD_NAME_W):
		move = t
		cw_fit = _card_fit(s.size.x, n_cards, move, skill, n_skills, gg)
	if cw_fit < t:
		gg = TOUCH_GAP     # groups 8 px apart (the worker keeps its octagon shape) before the skills leave the row
		cw_fit = _card_fit(s.size.x, n_cards, move, skill, n_skills, gg)
	if cw_fit < t and n_skills > 0:
		skills_in_row = false
		gg = GROUP_GAP
		cw_fit = _card_fit(s.size.x, n_cards, move, skill, 0, gg)
	var card_w := clampf(cw_fit, t, maxf(t, 50.0))
	var tg := TOUCH_GAP      # gap between cards / between skills
	var mg := GAP * 2        # gap between the two move buttons
	# Last resort. Two cases used to leave controls unreachable in small desktop windows (k = 1, view = window):
	#  - below ~392 logical px even the column mode overflowed: cards were laid out past the right edge;
	#  - on short views the skill column climbed into the top row and sat on top of the pause button.
	# Both now collapse to ONE row in which every control shrinks equally; nothing leaves the view or stacks.
	var col_top := row_bottom - card_h - GAP * 2 - n_skills * skill - maxi(n_skills - 1, 0) * TOUCH_GAP
	var fit := cw_fit < t or (not skills_in_row and col_top < s.position.y + top_h + TOUCH_GAP)
	if fit:
		skills_in_row = true
		gg = FIT_GAP
		tg = FIT_GAP
		mg = FIT_GAP
		var n := 3 + n_cards + n_skills      # 2 move buttons + worker + cards + skills
		var u := clampf(floorf((s.size.x - (n - 1) * FIT_GAP) / float(n)), FIT_MIN, t)
		move = u
		skill = u
		card_w = u
		card_h = clampf(s.size.y - top_h - TOUCH_GAP, u, card_h)
		out.min_target = u
	out.fit = fit
	var skills_w := (n_skills * skill + maxi(n_skills - 1, 0) * tg + gg) if (skills_in_row and n_skills > 0) else 0.0
	var need := n_cards * card_w + maxi(n_cards - 1, 0) * tg
	var avail := s.size.x - (2.0 * move + mg) - gg - card_w - gg - skills_w
	out.skills_in_row = skills_in_row
	out.group_gap = gg
	out.overflow = need > avail + 0.5
	out.move_left = Rect2(Vector2(s.position.x, row_bottom - move), Vector2(move, move))
	out.move_right = Rect2(Vector2(s.position.x + move + mg, row_bottom - move), Vector2(move, move))
	out.worker = Rect2(Vector2((out.move_right as Rect2).end.x + gg, row_bottom - card_h), Vector2(card_w, card_h))
	var sk_w := skills_w
	var lo: float = (out.worker as Rect2).end.x + gg
	var hi := s.end.x - sk_w
	# centre the unit cards between the worker and the skills
	var x0 := lo + maxf(0.0, (hi - lo - need) / 2.0)
	var cards: Array[Rect2] = []
	for i in n_cards:
		cards.append(Rect2(Vector2(x0 + i * (card_w + tg), row_bottom - card_h), Vector2(card_w, card_h)))
	out.cards = cards

	var skills: Array[Rect2] = []
	for i in n_skills:
		if skills_in_row:
			var x := s.end.x - (n_skills - i) * skill - (n_skills - 1 - i) * tg
			skills.append(Rect2(Vector2(x, row_bottom - skill), Vector2(skill, skill)))
		else:
			var y := row_bottom - card_h - GAP * 2 - (i + 1) * skill - i * TOUCH_GAP
			skills.append(Rect2(Vector2(s.end.x - skill, y), Vector2(skill, skill)))
	out.skills = skills

	# feedback strips (boss bar, tutorial hint, toast) stay left of a stacked skill column
	var strip_end := s.end.x
	if not skills_in_row and n_skills > 0:
		strip_end = (skills[0] as Rect2).position.x - GAP * 2
	var boss_y := s.position.y + top_h + TOUCH_GAP
	out.boss = Rect2(Vector2(bars_x, boss_y), Vector2(map_r.end.x-bars_x, 14.0) if boss_bar else Vector2.ZERO)
	# off-screen threat markers (03 A11, 01 R10): square plate ≥ 44 px at the screen edges, just below the toast
	# strip and always inside the top half, so no HUD part and no lane unit covers them. Right marker stays left
	# of a stacked skill column.
	var mk := maxf(t, THREAT_MIN)
	var ty := boss_y + (16.0 if boss_bar else 0.0)
	out.threat_right = Rect2(Vector2(strip_end - mk, ty), Vector2(mk, mk))
	out.threat_left = Rect2(Vector2(s.position.x, ty), Vector2(mk, mk))
	# banner: between the two markers
	var bx: float = (out.threat_left as Rect2).end.x + GAP * 2
	var bend: float = (out.threat_right as Rect2).position.x - GAP * 2
	out.tutorial = Rect2(bx, ty, bend - bx, 20.0)
	out.toast = Rect2(bx, ty + 22.0, bend - bx, 20.0)
	out.banner = Rect2(Vector2(bx, ty + 50.0), Vector2(bend - bx, 24.0))
	return out

## Width of the skill group incl. the gap before it (0 without skills).
static func _skills_w(skill: float, n_skills: int, gg: float) -> float:
	if n_skills <= 0:
		return 0.0
	return n_skills * skill + (n_skills - 1) * TOUCH_GAP + gg

## Widest card (= worker) width that fits next to the move and skill groups.
static func _card_fit(width: float, n_cards: int, move: float, skill: float, n_skills: int, gg: float) -> float:
	var fixed := (2.0 * move + GAP * 2) + gg * 2 + _skills_w(skill, n_skills, gg) + maxi(n_cards - 1, 0) * TOUCH_GAP
	return (width - fixed) / float(n_cards + 1)

## Lane band in view px (units walk here; 07 U3: the HUD must not cover units).
static func lane_band(view: Vector2) -> Rect2:
	var ground := view.y - GROUND_FROM_BOTTOM
	return Rect2(0, ground - LANE_ABOVE_GROUND, view.x, LANE_ABOVE_GROUND + 2.0)

## All interactive rects, for validation.
static func touch_rects(l: Dictionary) -> Array[Rect2]:
	var r: Array[Rect2] = [l.pause, l.move_left, l.move_right, l.worker]
	if l.has("minimap") and (l.minimap as Rect2).size.x > 0.0: r.append(l.minimap)
	if l.has("follow"): r.append(l.follow)
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
	# feedback strips must not overlap each other, the top readouts or the bottom controls
	var strips := ["boss", "tutorial", "toast", "banner"]
	var fixed: Array[Rect2] = [l.resources, l.bases, l.wave, l.pause]
	for i in strips.size():
		var a: Rect2 = l[strips[i]]
		if not safe.encloses(a):
			problems.append("%s outside safe" % strips[i])
		for ti in rects.size():
			if a.intersects(rects[ti]):
				problems.append("%s overlaps touch target %d %s" % [strips[i], ti, rects[ti]])
		for j in range(i + 1, strips.size()):
			if a.intersects(l[strips[j]]):
				problems.append("%s overlaps %s" % [strips[i], strips[j]])
		for k in fixed.size():
			if a.intersects(fixed[k]):
				problems.append("%s overlaps top readout %d" % [strips[i], k])
	if l.overflow:
		problems.append("bottom row overflow")
	# threat markers: inside safe, clear of every control, strip and top readout, and of each other
	for key in ["threat_right", "threat_left"]:
		if not l.has(key):
			continue
		var a: Rect2 = l[key]
		if not safe.encloses(a):
			problems.append("%s outside safe %s" % [key, a])
		for ti in rects.size():
			if a.intersects(rects[ti]):
				problems.append("%s overlaps touch target %d %s" % [key, ti, rects[ti]])
		for sk in strips:
			if a.intersects(l[sk]):
				problems.append("%s overlaps %s" % [key, sk])
		for k in fixed.size():
			if a.intersects(fixed[k]):
				problems.append("%s overlaps top readout %d" % [key, k])
	if l.has("threat_right") and (l.threat_right as Rect2).intersects(l.threat_left):
		problems.append("threat markers overlap each other")
	# docs/qa/UI_LAYOUT_REFERENCE.md rules
	var view: Vector2 = l.get("view", Vector2.ZERO)
	for key in ["threat_right", "threat_left"]:
		var a: Rect2 = l[key]
		if a.size.x + 0.01 < THREAT_MIN or a.size.y + 0.01 < THREAT_MIN:
			problems.append("01 R10 %s smaller than %.0f px %s" % [key, THREAT_MIN, a.size])
		if view != Vector2.ZERO and a.end.y > view.y / 2.0 + 0.01:
			problems.append("01 R10 %s not in the top half (end y %.0f > %.0f)" % [key, a.end.y, view.y / 2.0])
	if bool(l.get("fit", false)):
		return problems      # fit row: spacing rules (QA-J3, L4, L2) are deliberately traded for reachability
	var w: Rect2 = l.worker
	var gmin: float = GROUP_GAP if l.skills_in_row and float(l.get("group_gap", GROUP_GAP)) >= GROUP_GAP else TOUCH_GAP
	if w.position.x - (l.move_right as Rect2).end.x + 0.01 < gmin:
		problems.append("QA-J3 worker closer than %.0f px to the move buttons" % gmin)
	if not l.cards.is_empty() and (l.cards[0] as Rect2).position.x - w.end.x + 0.01 < gmin:
		problems.append("QA-J3 worker closer than %.0f px to the first unit card" % gmin)
	# 07 LAYOUT L4: every two touch targets at least TOUCH_GAP apart (8 dp)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a2: Rect2 = rects[i]
			var b2: Rect2 = rects[j]
			var dx := maxf(b2.position.x - a2.end.x, a2.position.x - b2.end.x)
			var dy := maxf(b2.position.y - a2.end.y, a2.position.y - b2.end.y)
			if maxf(dx, dy) + 0.01 < TOUCH_GAP:
				problems.append("L4 targets %d and %d only %.1f px apart (< %.0f)" % [i, j, maxf(dx, dy), TOUCH_GAP])
	# 07 LAYOUT L2: with no bottom inset and the skills in the row, no touch target enters the lane band
	if view != Vector2.ZERO and safe.end.y >= view.y - 0.01 and l.skills_in_row:
		var lane := lane_band(view)
		for i in rects.size():
			if rects[i].intersects(lane):
				problems.append("L2 target %d %s covers the lane band %s" % [i, rects[i], lane])
	return problems
