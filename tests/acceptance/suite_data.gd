extends RefCounted
## Data reference acceptance: reads data/** JSON directly (independent of Content normalisation)
## and checks every cross reference the game resolves at runtime. Owner: 07-qa.
## Contract: INTERFACES.md §2, docs/design/DATA_SCHEMA.md.

const Q := preload("res://tests/acceptance/qa_lib.gd")

var units := {}
var heroes := {}
var skills := {}
var rounds := {}
var order: Array = []

func _collect(kind: String) -> Dictionary:
	var out := {}
	for p in Q.list_files("res://data/" + kind, ".json"):
		if p.ends_with("order.json"):
			continue
		var d = Q.read_json(p)
		var list: Array = []
		if d is Dictionary and d.get(kind) is Array:
			list = d[kind]
		elif d is Dictionary and d.has("id"):
			list = [d]
		elif d is Array:
			list = d
		for it in list:
			if it is Dictionary and it.has("id"):
				out[str(it.id)] = it
	return out

func run(q, _tree) -> void:
	q.current_suite = "data"
	units = _collect("units")
	heroes = _collect("heroes")
	skills = _collect("skills")
	rounds = _collect("rounds")
	var od = Q.read_json("res://data/rounds/order.json")
	order = od.rounds if od is Dictionary and od.get("rounds") is Array else []
	q.check("DATA-01", "data/rounds/order.json lists >= 3 rounds", order.size() >= 3, "order=%s" % [order], {"order": order})
	var missing_order := []
	for id in order:
		if not rounds.has(str(id)): missing_order.append(id)
	q.check("DATA-02", "every round in order.json has a data file", missing_order.is_empty(), "missing: %s" % [missing_order])
	var unlisted := []
	for id in rounds:
		if not order.has(id): unlisted.append(id)
	q.check("DATA-03", "every round file is reachable from order.json", unlisted.is_empty(), "unlisted: %s" % [unlisted])

	var problems := []
	for rid in order:
		var r: Dictionary = rounds.get(str(rid), {})
		if r.is_empty(): continue
		problems.append_array(_round_refs(str(rid), r))
	for uid in units:
		var sm = units[uid].get("summon")
		if sm is Dictionary and not units.has(str(sm.get("unit", ""))):
			problems.append("unit %s: summon.unit %s missing" % [uid, sm.get("unit")])
	for hid in heroes:
		for s in heroes[hid].get("skills", []):
			if not skills.has(str(s)): problems.append("hero %s: skill %s missing" % [hid, s])
	q.check("DATA-04", "all round/unit/hero/skill cross references resolve with correct faction", problems.is_empty(), "; ".join(problems.slice(0, 12)), {"problems": problems})

	var p0 := order.slice(0, 3)
	var sanity := []
	for rid in p0:
		sanity.append_array(_round_sanity(str(rid), rounds.get(str(rid), {})))
	q.check("DATA-05", "P0 rounds %s numeric sanity (lane, base hp, wave times, start gold <= cap)" % [p0], sanity.is_empty(), "; ".join(sanity))
	var usan := []
	for uid in units:
		var u: Dictionary = units[uid]
		for k in ["hp", "atk_interval", "speed"]:
			if u.has(k) and float(u[k]) <= 0.0 and not bool(u.get("is_worker", false)):
				usan.append("%s.%s=%s" % [uid, k, u[k]])
		for k in ["cost", "cooldown", "atk", "range"]:
			if u.has(k) and float(u[k]) < 0.0:
				usan.append("%s.%s=%s" % [uid, k, u[k]])
	q.check("DATA-06", "unit stats are positive / non-negative", usan.is_empty(), "; ".join(usan))

	# text keys
	var ko = Q.read_json("res://data/text/ko.json")
	var en = Q.read_json("res://data/text/en.json")
	var kos: Dictionary = ko.strings if ko is Dictionary and ko.get("strings") is Dictionary else {}
	var ens: Dictionary = en.strings if en is Dictionary and en.get("strings") is Dictionary else {}
	var needed := []
	for coll in [units, heroes, skills, rounds]:
		for id in coll:
			for k in ["name_key", "desc_key"]:
				if coll[id].has(k): needed.append(str(coll[id][k]))
	for rid in order:
		for k in rounds.get(str(rid), {}).get("tutorial", []):
			needed.append(str(k))
	var miss_ko := []
	var miss_en := []
	for k in needed:
		if not kos.has(k): miss_ko.append(k)
		if not ens.has(k): miss_en.append(k)
	q.check("DATA-07", "every referenced text key exists in data/text/ko.json", miss_ko.is_empty(), "missing: %s" % [miss_ko], {"keys_checked": needed.size()})
	q.check("DATA-08", "every referenced text key exists in data/text/en.json", miss_en.is_empty(), "missing: %s" % [miss_en])
	var en_gap := []
	for k in kos:
		if not ens.has(k): en_gap.append(k)
	q.check("DATA-09", "en.json contains every ko.json key", en_gap.is_empty(), "missing in en: %s" % [en_gap])

	# runtime loader view of the same data
	var content = _tree.root.get_node_or_null("Content")
	if content == null:
		q.record("DATA-10", Q.BLOCKED, "Content autoload loads data/ without warnings", "Content autoload missing")
	else:
		var w: Array = Array(content.warnings)
		q.check("DATA-10", "Content autoload loads data/ without warnings", w.is_empty(), "; ".join(w.slice(0, 10)), {"warnings": w})
		var ro: Array = Array(content.round_order)
		q.check("DATA-11", "runtime round order equals order.json", ro == order.map(func(x): return str(x)), "runtime=%s file=%s" % [ro, order])

func _round_refs(rid: String, r: Dictionary) -> Array:
	var out := []
	var hero := str(r.get("hero", ""))
	if not heroes.has(hero): out.append("%s: hero %s missing" % [rid, hero])
	for c in r.get("cards", []):
		if c == null: continue
		var u: Dictionary = units.get(str(c), {})
		if u.is_empty(): out.append("%s: card %s missing" % [rid, c])
		elif not (str(u.get("faction", "")) in ["player", "both"]): out.append("%s: card %s faction %s" % [rid, c, u.get("faction")])
	var hs: Array = heroes.get(hero, {}).get("skills", [])
	for s in r.get("skills", []):
		if s == null: continue
		if not skills.has(str(s)): out.append("%s: skill %s missing" % [rid, s])
		elif not hs.has(s): out.append("%s: skill %s not in hero %s skills (engine drops it)" % [rid, s, hero])
	var enemy_refs := []
	for w in r.get("waves", []):
		for sp in w.get("spawns", []): enemy_refs.append(["wave", sp.get("unit", "")])
	for u in r.get("enemy_ai", {}).get("pool", []): enemy_refs.append(["enemy_ai.pool", u])
	for u in r.get("trickle", {}).get("pattern", []): enemy_refs.append(["trickle", u])
	for trg in r.get("enemy_base_spawns_on_hp", []):
		for sp in trg.get("spawns", []): enemy_refs.append(["hp_trigger", sp.get("unit", "")])
	for e in enemy_refs:
		var u: Dictionary = units.get(str(e[1]), {})
		if u.is_empty(): out.append("%s: %s unit %s missing" % [rid, e[0], e[1]])
		elif not (str(u.get("faction", "")) in ["enemy", "both"]): out.append("%s: %s unit %s faction %s" % [rid, e[0], e[1], u.get("faction")])
	return out

func _round_sanity(rid: String, r: Dictionary) -> Array:
	var out := []
	if r.is_empty():
		return ["%s missing" % rid]
	if float(r.get("lane_length", 0)) < 400: out.append("%s lane_length %s" % [rid, r.get("lane_length")])
	if float(r.get("player_base_hp", 0)) <= 0 or float(r.get("enemy_base_hp", 0)) <= 0: out.append("%s base hp" % rid)
	var last := -1.0
	for w in r.get("waves", []):
		var at := float(w.get("at", -1))
		if at < 0 or at < last: out.append("%s wave at %s not ascending" % [rid, at])
		last = at
	var econ = Q.read_json("res://data/economy.json")
	var cap := float(r.get("gold_max", econ.get("gold_max", 999) if econ is Dictionary else 999))
	if float(r.get("start_gold", 0)) > cap: out.append("%s start_gold %s > gold_max %s" % [rid, r.start_gold, cap])
	if r.get("cards", []).is_empty(): out.append("%s has no cards" % rid)
	return out
