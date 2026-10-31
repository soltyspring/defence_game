extends RefCounted
## Theme-change guard (Q1 → A "빵집 기사단 vs 곰팡이 군단"). Fails as soon as renamed text or recoloured
## sprites break readability. Measures with the real UI font (UiStyle.font / fit_label) and the
## real HUD layout (HudLayout.compute), not a mock. Owner: 07-qa.
## Checks:
##   TH-TEXT-*  every display name for player cards, heroes, skills, rounds exists in ko+en, non-empty, not equal to its key/id
##   TH-FIT-*   card / skill / round-tile labels fit without ellipsis at the narrowest supported HUD layout
##   TH-COL-*   ally vs enemy sprite colour separation (normal vision + simulated protan/deutan/tritan)

const Q := preload("res://tests/acceptance/qa_lib.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const HudLayout := preload("res://src/ui/hud_layout.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")

# Narrowest supported HUD: 16:9 with both-side notch insets and 5 cards + 3 skills, 40 px targets
# (same matrix family as tests/ui/test_ui.gd and suite_flow SAFE-*).
const NARROW_VIEW := Vector2(640, 360)
const NARROW_SAFE := Rect2(34, 0, 572, 360)
const LABEL_PAD := 6.0      # TouchButton draws name with size.x - 6
const JND_DE76 := 2.3       # CIE ΔE*ab just-noticeable difference (Sharma 2003); "distinguishable at all"

func run(q, tree) -> void:
	q.current_suite = "theme"
	var ko = Q.read_json("res://data/text/ko.json")
	var en = Q.read_json("res://data/text/en.json")
	var locales := {"ko": ko.strings if ko is Dictionary else {}, "en": en.strings if en is Dictionary else {}}
	var content = tree.root.get_node_or_null("Content")
	if content == null:
		q.record("TH-00", Q.BLOCKED, "Content autoload", "missing")
		return
	# ---- names in play
	var cards := {}
	var skills := {}
	var rounds := {}
	for rid in content.round_order:
		var r: Dictionary = content.get_round(rid)
		rounds[rid] = str(r.get("name_key", "round.%s.name" % rid))
		for c in content.round_cards(r): cards[str(c)] = str(content.get_unit(str(c)).get("name_key", "unit.%s.name" % c))
		for s in content.round_skills(r): skills[str(s)] = str(content.skills[s].get("name_key", "skill.%s.name" % s))
	var heroes := {}
	for h in content.heroes: heroes[h] = str(content.heroes[h].get("name_key", "hero.%s.name" % h))
	var enemies := {}
	for u in content.units:
		if str(content.units[u].faction) == "enemy": enemies[u] = str(content.units[u].get("name_key", "enemy.%s.name" % u))
	for loc in locales:
		var bad := []
		for group in [cards, skills, rounds, heroes, enemies]:
			for id in group:
				var k: String = group[id]
				var v := str(locales[loc].get(k, ""))
				if v == "" or v == k or v == id: bad.append("%s→'%s'" % [k, v])
		q.check("TH-TEXT-" + loc.to_upper(), "%s: every card/skill/round/hero/enemy display name exists and is not a raw id (%d names)" % [loc, cards.size() + skills.size() + rounds.size() + heroes.size() + enemies.size()],
			bad.is_empty(), "; ".join(bad.slice(0, 12)))
	# ---- label fit: each round's own card/skill count at the narrowest supported safe area
	for loc in locales:
		var cut := []
		var widths := {}
		var hidden := {}
		var atlas = tree.root.get_node_or_null("Atlas")
		for rid in content.round_order:
			var r: Dictionary = content.get_round(rid)
			var rc: Array = content.round_cards(r)
			var rs: Array = content.round_skills(r)
			var l: Dictionary = HudLayout.compute(NARROW_VIEW, NARROW_SAFE, rc.size(), rs.size(), SafeArea.MIN_TARGET_LOGICAL)
			var cw: float = (l.cards[0] as Rect2).size.x - LABEL_PAD if (l.cards as Array).size() > 0 else 0.0
			var sw: float = (l.skills[0] as Rect2).size.x - LABEL_PAD if (l.skills as Array).size() > 0 else 0.0
			var ch: float = (l.cards[0] as Rect2).size.y if (l.cards as Array).size() > 0 else 0.0
			var sh: float = (l.skills[0] as Rect2).size.y if (l.skills as Array).size() > 0 else 0.0
			widths[rid] = [snappedf(cw, 0.01), snappedf(sw, 0.01)]
			for pair in [[rc, cards, cw, "card", ch], [rs, skills, sw, "skill", sh]]:
				for id in pair[0]:
					# mirror TouchButton.show_name: icon + cost line on a button < 54 px tall hides the name
					var icon_ok: bool = atlas != null and (atlas.get_frame_texture("ui_main", ("card_" if pair[3] == "card" else "skill_") + str(id)) != null or atlas.get_frame_texture("ui_main", "icon_" + str(id)) != null)
					if icon_ok and float(pair[4]) < 54.0:
						hidden["%s %s" % [pair[3], id]] = true
						continue
					var txt := str(locales[loc].get(pair[1].get(str(id), ""), str(id)))
					var fit: Array = UiStyle.fit_label(txt, pair[2], UiStyle.FONT_S)
					if str(fit[0]) != txt:
						var e := "%s %s '%s'→'%s' (%.0f>%.1f px)" % [rid, pair[3], txt, fit[0], UiStyle.text_width(txt, UiStyle.FONT_S), pair[2]]
						if not cut.has(e): cut.append(e)
		q.check("TH-FIT-HUD-" + loc.to_upper(), "%s: every drawn card/skill label fits at 640x360 with 34 px notches both sides (no ellipsis); icon-only buttons listed in evidence" % loc,
			cut.is_empty(), "%d cut: %s" % [cut.size(), "; ".join(cut.slice(0, 8))], {"label_px_per_round_[card,skill]": widths, "cut": cut, "name_hidden_icon_only": hidden.keys()})
	# round-select tiles: 5 columns in the safe area minus side buttons (round_select.gd _layout)
	var t := SafeArea.MIN_TARGET_LOGICAL
	var side := t + 10.0
	var tile_w := floorf(((NARROW_SAFE.size.x - side * 2.0) - 6.0 * 4.0) / 5.0) - LABEL_PAD
	for loc in locales:
		var cut2 := []
		var wrapped := []
		for rid in rounds:
			var txt := str(locales[loc].get(rounds[rid], rid))
			# mirror the committed round tile: TouchButton.wrap_lines (2 since 5a2099d) via UiStyle.fit_lines
			if (UiStyle as Script).get_script_method_list().any(func(m): return m.name == "fit_lines"):
				var fl: Dictionary = UiStyle.fit_lines(txt, tile_w, UiStyle.FONT_S, 2)
				if bool(fl.truncated): cut2.append("'%s'→%s" % [txt, Array(fl.lines)])
				elif (fl.lines as PackedStringArray).size() > 1: wrapped.append(txt)
			else:
				var fit: Array = UiStyle.fit_label(txt, tile_w, UiStyle.FONT_S)
				if str(fit[0]) != txt: cut2.append("'%s'→'%s'" % [txt, fit[0]])
		q.check("TH-FIT-ROUND-" + loc.to_upper(), "%s: round names fit round-select tiles (%.0f px, up to 2 lines) at narrowest layout without ellipsis" % [loc, tile_w], cut2.is_empty(), "; ".join(cut2.slice(0, 10)), {"wrapped_to_2_lines": wrapped})
	# ---- ally vs enemy colour separation
	_colours(q, tree, content)

func _colours(q, tree, content) -> void:
	var atlas = tree.root.get_node_or_null("Atlas")
	if atlas == null or not atlas.has_manifest():
		q.record("TH-COL", Q.NOT_IMPL, "ally/enemy colour separation", "no atlas manifest")
		return
	var sides := {"player": {}, "enemy": {}}
	for u in content.units:
		var f := str(content.units[u].faction)
		if f in sides: sides[f][str(content.units[u].anim_set)] = u
	sides.player[str(content.heroes.values()[0].anim_set)] = "hero"
	var mean := {}
	var imgs := {}
	for side in sides:
		for aset in sides[side]:
			var fr: Dictionary = atlas.anim_frame(aset, "walk", 0.0)
			if fr.is_empty():
				var a_id := str(atlas.anim_sets.get(aset, ""))
				if a_id != "" and atlas.acquire(a_id): fr = atlas.anim_frame(aset, "walk", 0.0)
			if fr.is_empty(): continue
			var path := str(atlas.pages[str(atlas.anim_sets[aset])].meta.image)
			if not imgs.has(path): imgs[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
			mean[aset] = [side, _mean_rgb(imgs[path], fr.rect)]
	var sims := {"normal": null, "protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
		"deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
		"tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]}
	var allies := mean.keys().filter(func(k): return mean[k][0] == "player")
	var foes := mean.keys().filter(func(k): return mean[k][0] == "enemy")
	if allies.is_empty() or foes.is_empty():
		q.record("TH-COL", Q.BLOCKED, "ally/enemy colour separation", "no resolvable walk frames (allies=%d enemies=%d)" % [allies.size(), foes.size()])
		return
	for sim_name in sims:
		var worst := 1e9
		var pair := ""
		for a in allies:
			for e in foes:
				var d := _de76(_sim(mean[a][1], sims[sim_name]), _sim(mean[e][1], sims[sim_name]))
				if d < worst:
					worst = d
					pair = "%s vs %s" % [a, e]
		q.check("TH-COL-" + sim_name.to_upper(), "ally vs enemy mean sprite colour ΔE76 >= %.1f (%s vision, Machado 2009 severity 1.0)" % [JND_DE76, sim_name],
			worst >= JND_DE76, "closest pair %s ΔE=%.2f" % [pair, worst], {"closest": pair, "delta_e": snappedf(worst, 0.01), "note": "mean colour proxy only; silhouettes, markers and facing are not measured; human/CVD review still required"})

func _mean_rgb(img: Image, r: Rect2) -> Color:
	var acc := Vector3.ZERO
	var n := 0.0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			var c := img.get_pixel(x, y)
			if c.a < 0.5: continue
			acc += Vector3(c.r, c.g, c.b)
			n += 1.0
	if n == 0.0: return Color.BLACK
	acc /= n
	return Color(acc.x, acc.y, acc.z)

func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

func _sim(c: Color, m) -> Color:
	if m == null: return c
	var l := Vector3(_lin(c.r), _lin(c.g), _lin(c.b))
	var o := Vector3(m[0][0] * l.x + m[0][1] * l.y + m[0][2] * l.z, m[1][0] * l.x + m[1][1] * l.y + m[1][2] * l.z, m[2][0] * l.x + m[2][1] * l.y + m[2][2] * l.z)
	var g := func(v: float) -> float: return clampf(12.92 * v if v <= 0.0031308 else 1.055 * pow(maxf(v, 0.0), 1.0 / 2.4) - 0.055, 0.0, 1.0)
	return Color(g.call(o.x), g.call(o.y), g.call(o.z))

func _lab(c: Color) -> Vector3:
	var r := _lin(c.r); var g := _lin(c.g); var b := _lin(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z)))

func _de76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))
