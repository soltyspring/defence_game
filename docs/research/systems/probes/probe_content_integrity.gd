extends SceneTree
## Read-only research probe (10-research-systems): content-DB referential integrity for data/** and the
## art manifest it references. Reads res:// files only and writes nothing.
## Run (from the workspace root):
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_content_integrity.gd --quit-after 600
## Output: one line per finding "CI <SEV> <check_id> <owner> <file> :: <message>", then
## "PROBE10_CONTENT_INTEGRITY {json summary}". Exit code 1 if any ERROR, else 0, so it can be adopted
## as a test by 07/02 unchanged. Severity: ERROR = broken reference/duplicate/invalid value/order,
## WARN = suspicious or contract gap, INFO = proposal-level (e.g. missing version field).
## Engine hard ceilings come from docs/contracts/INTERFACES.md §2.7 (40/40/64/48/24).

const HARD_CAPS := {"max_ally_units": 40, "max_enemy_units": 40, "max_projectiles": 64, "max_vfx": 48, "max_damage_popups": 24}
const TEXT_LOCALES := ["ko", "en"]

var findings: Array = []
var counts := {"ERROR": 0, "WARN": 0, "INFO": 0}
var checked := {}

func _f(sev: String, check: String, owner: String, file: String, msg: String) -> void:
	findings.append({"sev": sev, "check": check, "owner": owner, "file": file, "msg": msg})
	counts[sev] += 1
	print("CI %s %s %s %s :: %s" % [sev, check, owner, file, msg])

func _tick(check: String) -> void:
	checked[check] = int(checked.get(check, 0)) + 1

func _load(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		_f("ERROR", "PARSE", "01", path, "JSON parse error line %d: %s" % [j.get_error_line(), j.get_error_message()])
		return null
	return j.data

func _json_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null: return out
	for fn in d.get_files():
		if fn.ends_with(".json"): out.append(dir + "/" + fn)
	out.sort()
	return out

func _num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

func _range(file: String, owner: String, label: String, v: Variant, lo: float, hi: float, required := true) -> void:
	_tick("RANGE")
	if v == null:
		if required: _f("ERROR", "RANGE", owner, file, "%s missing" % label)
		return
	if not _num(v):
		_f("ERROR", "RANGE", owner, file, "%s not a number (%s)" % [label, str(v)])
		return
	if float(v) < lo or float(v) > hi:
		_f("ERROR", "RANGE", owner, file, "%s=%s outside [%s, %s]" % [label, str(v), str(lo), str(hi)])

func _initialize() -> void:
	# ---------- load tables ----------
	var units_doc = _load("res://data/units/units.json")
	var units := {}
	var unit_list: Array = units_doc.get("units", []) if units_doc is Dictionary else []
	for u in unit_list:
		_tick("DUP_ID")
		var id := str(u.get("id", ""))
		if id == "": _f("ERROR", "DUP_ID", "01", "data/units/units.json", "unit without id"); continue
		if units.has(id): _f("ERROR", "DUP_ID", "01", "data/units/units.json", "duplicate unit id %s" % id)
		units[id] = u
	var skills := {}
	for p in _json_files("res://data/skills"):
		var s = _load(p)
		if not (s is Dictionary): continue
		var id := str(s.get("id", ""))
		_tick("DUP_ID")
		if skills.has(id): _f("ERROR", "DUP_ID", "01", p, "duplicate skill id %s" % id)
		if id + ".json" != p.get_file(): _f("WARN", "ID_FILE", "01", p, "skill id '%s' differs from file name" % id)
		skills[id] = s
	var heroes := {}
	for p in _json_files("res://data/heroes"):
		var h = _load(p)
		if not (h is Dictionary): continue
		var id := str(h.get("id", ""))
		_tick("DUP_ID")
		if heroes.has(id): _f("ERROR", "DUP_ID", "01", p, "duplicate hero id %s" % id)
		if id + ".json" != p.get_file(): _f("WARN", "ID_FILE", "01", p, "hero id '%s' differs from file name" % id)
		heroes[id] = h
	var rounds := {}
	var round_files := {}
	for p in _json_files("res://data/rounds"):
		if p.get_file() == "order.json": continue
		var r = _load(p)
		if not (r is Dictionary): continue
		var id := str(r.get("id", ""))
		_tick("DUP_ID")
		if rounds.has(id): _f("ERROR", "DUP_ID", "01", p, "duplicate round id %s" % id)
		if id + ".json" != p.get_file(): _f("WARN", "ID_FILE", "01", p, "round id '%s' differs from file name" % id)
		rounds[id] = r
		round_files[id] = p.replace("res://", "")
	var order_doc = _load("res://data/rounds/order.json")
	var order: Array = order_doc.get("rounds", []) if order_doc is Dictionary else []
	var economy = _load("res://data/economy.json")
	var meta = _load("res://data/meta.json")
	var cfg = _load("res://data/game_config.json")
	var texts := {}
	for loc in TEXT_LOCALES:
		var t = _load("res://data/text/%s.json" % loc)
		texts[loc] = t.get("strings", {}) if t is Dictionary else {}
	var manifest = _load("res://assets/manifest.json")
	var anim_sets: Dictionary = manifest.get("anim_sets", {}) if manifest is Dictionary else {}
	var biomes: Dictionary = manifest.get("biomes", {}) if manifest is Dictionary else {}
	var ui_frames := {}
	var ui_doc = _load("res://assets/atlases/ui_main.json")
	if ui_doc is Dictionary: ui_frames = ui_doc.get("frames", {})

	var used_text_keys := {}
	var text_key := func(file: String, owner: String, key: Variant) -> void:
		if key == null or str(key) == "": return
		used_text_keys[str(key)] = true
		for loc in TEXT_LOCALES:
			_tick("TEXT_REF")
			if not texts[loc].has(str(key)):
				_f("ERROR", "TEXT_REF", owner, file, "text key '%s' missing in data/text/%s.json" % [str(key), loc])
	var anim_ref := func(file: String, owner: String, label: String, aid: Variant) -> void:
		if aid == null or str(aid) == "": return
		_tick("ANIM_REF")
		if not anim_sets.has(str(aid)):
			_f("ERROR", "ANIM_REF", owner, file, "%s '%s' not in assets/manifest.json anim_sets (engine falls back to placeholder art)" % [label, str(aid)])

	# ---------- units ----------
	var uf := "data/units/units.json"
	var max_round := order.size()
	for id in units:
		var u: Dictionary = units[id]
		var fac := str(u.get("faction", ""))
		_tick("ENUM")
		if not fac in ["player", "enemy", "both"]: _f("ERROR", "ENUM", "01", uf, "%s faction '%s'" % [id, fac])
		if not str(u.get("attack_type", "melee")) in ["melee", "ranged", "siege"]: _f("ERROR", "ENUM", "01", uf, "%s attack_type '%s'" % [id, u.get("attack_type")])
		_range(uf, "01", id + ".hp", u.get("hp"), 1, 1e6)
		_range(uf, "01", id + ".atk", u.get("atk"), 0, 1e5)
		_range(uf, "01", id + ".atk_interval", u.get("atk_interval"), 0.05, 60)
		_range(uf, "01", id + ".range", u.get("range"), 1, 2000)
		_range(uf, "01", id + ".speed", u.get("speed"), 0, 1000)
		_range(uf, "01", id + ".armor", u.get("armor", 0), 0, 1e4, false)
		_range(uf, "01", id + ".splash", u.get("splash", 0), 0, 1000, false)
		_range(uf, "01", id + ".structure_mult", u.get("structure_mult", 1.0), 0.01, 100, false)
		if fac != "enemy":
			_range(uf, "01", id + ".cost", u.get("cost"), 0, 1e5)
			_range(uf, "01", id + ".cooldown", u.get("cooldown"), 0, 600)
			if u.has("unlock_round"): _range(uf, "01", id + ".unlock_round", u.get("unlock_round"), 1, max_round)
		if fac != "player":
			_range(uf, "01", id + ".bounty", u.get("bounty", 0), 0, 1e5, false)
			_range(uf, "01", id + ".kill_coins", u.get("kill_coins", 0), 0, 1e5, false)
			if u.has("first_round"): _range(uf, "01", id + ".first_round", u.get("first_round"), 1, max_round)
		anim_ref.call(uf, "01/03", id + ".anim_set", u.get("anim_set", id))
		anim_ref.call(uf, "01/03", id + ".projectile", u.get("projectile", ""))
		text_key.call(uf, "01", u.get("name_key"))
		text_key.call(uf, "01", u.get("desc_key"))
		var sm = u.get("summon")
		if sm is Dictionary:
			_tick("UNIT_REF")
			if not units.has(str(sm.get("unit", ""))): _f("ERROR", "UNIT_REF", "01", uf, "%s.summon.unit '%s' unknown" % [id, sm.get("unit")])
			_range(uf, "01", id + ".summon.count", sm.get("count"), 1, 100)
			_range(uf, "01", id + ".summon.max_alive", sm.get("max_alive"), 1, 40, false)

	# ---------- skills / heroes ----------
	for id in skills:
		var s: Dictionary = skills[id]
		var sf := "data/skills/%s.json" % id
		_tick("ENUM")
		if not str(s.get("kind", "")) in ["aoe_damage", "heal_allies", "rally", "meteor", "summon"]: _f("ERROR", "ENUM", "01", sf, "kind '%s' unsupported by INTERFACES §2.3" % s.get("kind"))
		_range(sf, "01", "mana", s.get("mana"), 0, 1e4)
		_range(sf, "01", "cooldown", s.get("cooldown"), 0, 600)
		_range(sf, "01", "radius", s.get("radius", 0), 0, 2000, false)
		if s.has("unlock_round"): _range(sf, "01", "unlock_round", s.get("unlock_round"), 1, max_round)
		anim_ref.call(sf, "01/03", "fx", s.get("fx", ""))
		text_key.call(sf, "01", s.get("name_key"))
		text_key.call(sf, "01", s.get("desc_key"))
		if str(s.get("kind", "")) == "summon":
			_tick("UNIT_REF")
			if not units.has(str(s.get("unit", ""))): _f("ERROR", "UNIT_REF", "01", sf, "summon unit '%s' unknown" % s.get("unit"))
	for id in heroes:
		var h: Dictionary = heroes[id]
		var hf := "data/heroes/%s.json" % id
		for sk in h.get("skills", []):
			_tick("SKILL_REF")
			if not skills.has(str(sk)): _f("ERROR", "SKILL_REF", "01", hf, "hero skill '%s' unknown" % sk)
		_range(hf, "01", "hp", h.get("hp"), 1, 1e6)
		_range(hf, "01", "mana_max", h.get("mana_max"), 1, 1e4)
		_range(hf, "01", "mana_start", h.get("mana_start", 0), 0, float(h.get("mana_max", 0)), false)
		_range(hf, "01", "leash", h.get("leash"), 0.05, 1.0)
		anim_ref.call(hf, "01/03", "anim_set", h.get("anim_set", id))
		text_key.call(hf, "01", h.get("name_key"))
		text_key.call(hf, "01", h.get("desc_key"))

	# ---------- order ----------
	var seen := {}
	for i in order.size():
		var rid := str(order[i])
		_tick("ORDER")
		if seen.has(rid): _f("ERROR", "ORDER", "01", "data/rounds/order.json", "round '%s' listed twice" % rid)
		seen[rid] = true
		if not rounds.has(rid):
			_f("ERROR", "ORDER", "01", "data/rounds/order.json", "round '%s' has no file" % rid)
			continue
		if int(rounds[rid].get("index", -1)) != i + 1:
			_f("ERROR", "ORDER", "01", round_files[rid], "index %s but position %d in order.json (save unlocked_round is an order index)" % [str(rounds[rid].get("index")), i + 1])
	for rid in rounds:
		_tick("ORDER")
		if not seen.has(rid): _f("WARN", "ORDER", "01", round_files[rid], "round file not listed in order.json (unreachable)")

	# ---------- rounds ----------
	var used_cards := {}
	var used_skills := {}
	for rid in rounds:
		var r: Dictionary = rounds[rid]
		var rf: String = round_files[rid]
		var ridx := int(r.get("index", 0))
		var hero_id := str(r.get("hero", cfg.get("hero_id", "") if cfg is Dictionary else ""))
		_tick("HERO_REF")
		if not heroes.has(hero_id): _f("ERROR", "HERO_REF", "01", rf, "hero '%s' unknown" % hero_id)
		_tick("BIOME_REF")
		if not biomes.has(str(r.get("biome", ""))): _f("ERROR", "BIOME_REF", "01/03", rf, "biome '%s' not in manifest biomes" % r.get("biome"))
		_range(rf, "01", "lane_length", r.get("lane_length"), 320, 20000)
		_range(rf, "01", "player_base_hp", r.get("player_base_hp"), 1, 1e7)
		_range(rf, "01", "enemy_base_hp", r.get("enemy_base_hp"), 1, 1e7)
		_range(rf, "01", "start_gold", r.get("start_gold"), 0, 1e5)
		if r.has("gold_max") and _num(r.get("start_gold")) and float(r.get("start_gold")) > float(r.get("gold_max")):
			_f("ERROR", "RANGE", "01", rf, "start_gold %s > gold_max %s" % [r.get("start_gold"), r.get("gold_max")])
		var st = r.get("stars", {})
		_range(rf, "01", "stars.time_3", st.get("time_3"), 1, 3600)
		_range(rf, "01", "stars.base_hp_2", st.get("base_hp_2"), 0, 1)
		var rw = r.get("reward", {})
		for k in ["coins", "first_clear_coins", "three_star_bonus_coins"]:
			_range(rf, "01", "reward." + k, rw.get(k, 0), 0, 1e6, false)
		var es = r.get("enemy_scaling", {})
		if es is Dictionary:
			for k in es: _range(rf, "01", "enemy_scaling." + str(k), es[k], 0.1, 20)
		for c in r.get("cards", []):
			var cid := str(c)
			used_cards[cid] = true
			_tick("UNIT_REF")
			if not units.has(cid): _f("ERROR", "UNIT_REF", "01", rf, "card '%s' unknown" % cid); continue
			if str(units[cid].get("faction")) == "enemy": _f("ERROR", "FACTION", "01", rf, "card '%s' is an enemy unit" % cid)
			if int(units[cid].get("unlock_round", 1)) > ridx: _f("WARN", "UNLOCK", "01", rf, "card '%s' unlock_round %s > round index %d" % [cid, units[cid].get("unlock_round"), ridx])
		var hero_sk: Array = heroes[hero_id].get("skills", []) if heroes.has(hero_id) else []
		for sk in r.get("skills", []):
			var sid := str(sk)
			used_skills[sid] = true
			_tick("SKILL_REF")
			if not skills.has(sid): _f("ERROR", "SKILL_REF", "01", rf, "skill '%s' unknown" % sid); continue
			if not hero_sk.has(sid): _f("WARN", "SKILL_REF", "01", rf, "skill '%s' not in hero '%s' skills (engine filters it out)" % [sid, hero_id])
			if int(skills[sid].get("unlock_round", 1)) > ridx: _f("WARN", "UNLOCK", "01", rf, "skill '%s' unlock_round %s > round index %d" % [sid, skills[sid].get("unlock_round"), ridx])
		var enemy_refs: Array = []
		var last_at := -1.0
		var waves: Array = r.get("waves", [])
		for wi in waves.size():
			var w: Dictionary = waves[wi]
			_range(rf, "01", "waves[%d].at" % wi, w.get("at"), 0, 3600)
			if _num(w.get("at")):
				_tick("WAVE_ORDER")
				if float(w.at) < last_at: _f("ERROR", "WAVE_ORDER", "01", rf, "waves[%d].at=%s earlier than previous %s" % [wi, w.at, last_at])
				last_at = float(w.at)
			for sp in w.get("spawns", []):
				enemy_refs.append(["waves[%d]" % wi, sp.get("unit")])
				_range(rf, "01", "waves[%d].count" % wi, sp.get("count"), 1, 200)
				_range(rf, "01", "waves[%d].interval" % wi, sp.get("interval", 0), 0, 120, false)
		for hpw in r.get("enemy_base_spawns_on_hp", []):
			_range(rf, "01", "enemy_base_spawns_on_hp.below", hpw.get("below"), 0.0001, 0.9999)
			for sp in hpw.get("spawns", []): enemy_refs.append(["enemy_base_spawns_on_hp", sp.get("unit")])
		var tr = r.get("trickle")
		if tr is Dictionary:
			for pu in tr.get("pattern", []): enemy_refs.append(["trickle.pattern", pu])
			_range(rf, "01", "trickle.interval", tr.get("interval"), 0.1, 600)
			_range(rf, "01", "trickle.interval_min", tr.get("interval_min"), 0.1, float(tr.get("interval", 600)))
		var ai = r.get("enemy_ai")
		if ai is Dictionary:
			for pu in ai.get("pool", []): enemy_refs.append(["enemy_ai.pool", pu])
		for er in enemy_refs:
			_tick("UNIT_REF")
			var eid := str(er[1])
			if not units.has(eid): _f("ERROR", "UNIT_REF", "01", rf, "%s unit '%s' unknown" % [er[0], eid]); continue
			if str(units[eid].get("faction")) == "player": _f("ERROR", "FACTION", "01", rf, "%s spawns player unit '%s' as enemy" % [er[0], eid])
		for tk in r.get("tutorial", []): text_key.call(rf, "01", tk)
		text_key.call(rf, "01", r.get("name_key"))

	# ---------- icons the engine builds (battle_sim.gd battle_info: ui_main card_<id>, skill_<id>) ----------
	for cid in used_cards:
		_tick("ICON_REF")
		if not ui_frames.has("card_" + cid): _f("ERROR", "ICON_REF", "03", "assets/atlases/ui_main.json", "card icon 'card_%s' missing (used by a round card)" % cid)
	for sid in used_skills:
		_tick("ICON_REF")
		if not ui_frames.has("skill_" + sid): _f("ERROR", "ICON_REF", "03", "assets/atlases/ui_main.json", "skill icon 'skill_%s' missing" % sid)

	# ---------- meta / economy / config ----------
	if meta is Dictionary:
		var up_seen := {}
		for c in meta.get("currencies", []):
			text_key.call("data/meta.json", "01", c.get("name_key"))
		for up in meta.get("upgrades", []):
			var uid := str(up.get("id", ""))
			_tick("DUP_ID")
			if up_seen.has(uid): _f("ERROR", "DUP_ID", "01", "data/meta.json", "duplicate upgrade id %s" % uid)
			up_seen[uid] = true
			var tgt := str(up.get("target", ""))
			var ok := false
			if tgt.begins_with("unit:"): ok = units.has(tgt.substr(5))
			elif tgt.begins_with("hero:"): ok = heroes.has(tgt.substr(5))
			else: ok = tgt in ["resource:supply", "resource:energy", "worker", "base:player"]
			_tick("UPG_REF")
			if not ok: _f("ERROR", "UPG_REF", "01", "data/meta.json", "%s target '%s' unknown" % [uid, tgt])
			var costs: Array = up.get("costs", [])
			_tick("UPG_COST")
			if costs.size() != int(up.get("max_level", 0)) - 1: _f("ERROR", "UPG_COST", "01", "data/meta.json", "%s costs length %d != max_level-1" % [uid, costs.size()])
			for i in costs.size():
				if not _num(costs[i]) or float(costs[i]) <= 0 or (i > 0 and float(costs[i]) < float(costs[i - 1])):
					_f("ERROR", "UPG_COST", "01", "data/meta.json", "%s costs not positive non-decreasing at %d" % [uid, i])
			text_key.call("data/meta.json", "01", up.get("name_key"))
	if economy is Dictionary:
		var ef := "data/economy.json"
		_range(ef, "01", "base_income", economy.get("base_income"), 0, 1e4)
		_range(ef, "01", "worker_income", economy.get("worker_income"), 0, 1e4)
		_range(ef, "01", "worker_cost_base", economy.get("worker_cost_base"), 1, 1e5)
		_range(ef, "01", "worker_cost_growth", economy.get("worker_cost_growth"), 1.0, 10)
		_range(ef, "01", "loss_coin_ratio", economy.get("loss_coin_ratio", 0), 0, 1, false)
		if cfg is Dictionary and cfg.get("worker") is Dictionary:
			var w: Dictionary = cfg.worker
			for pair in [["base_cost", "worker_cost_base"], ["cost_growth", "worker_cost_growth"], ["income_per_sec", "worker_income"]]:
				_tick("MIRROR")
				if w.has(pair[0]) and economy.has(pair[1]) and float(w[pair[0]]) != float(economy[pair[1]]):
					_f("WARN", "MIRROR", "01", "data/game_config.json", "worker.%s=%s != economy.%s=%s (DATA_SCHEMA C3: mirrors must stay equal)" % [pair[0], w[pair[0]], pair[1], economy[pair[1]]])
			_tick("MIRROR")
			if w.has("max_workers_default") and float(w.max_workers_default) != float(economy.get("workers_max", -1)):
				_f("WARN", "MIRROR", "01", "data/game_config.json", "worker.max_workers_default=%s != economy.workers_max=%s" % [w.max_workers_default, economy.get("workers_max")])
	if cfg is Dictionary:
		var caps = cfg.get("caps", {})
		for k in HARD_CAPS:
			if caps.has(k):
				_range("data/game_config.json", "01", "caps." + k, caps[k], 1, HARD_CAPS[k])
		_tick("HERO_REF")
		if cfg.has("hero_id") and not heroes.has(str(cfg.hero_id)): _f("ERROR", "HERO_REF", "01", "data/game_config.json", "hero_id '%s' unknown" % cfg.hero_id)
		anim_ref.call("data/game_config.json", "01/03", "worker.unit_id", cfg.get("worker", {}).get("unit_id", ""))

	# ---------- text parity ----------
	var ko: Dictionary = texts["ko"]
	var en: Dictionary = texts["en"]
	var rx := RegEx.create_from_string("\\{[A-Za-z0-9_]+\\}")
	for k in ko:
		_tick("TEXT_PARITY")
		if not en.has(k): _f("ERROR", "TEXT_PARITY", "01", "data/text/en.json", "key '%s' only in ko" % k); continue
		var a := {}
		var b := {}
		for m in rx.search_all(str(ko[k])): a[m.get_string()] = true
		for m in rx.search_all(str(en[k])): b[m.get_string()] = true
		if a.keys().size() != b.keys().size() or not a.keys().all(func(x): return b.has(x)):
			_f("ERROR", "TEXT_PARITY", "01", "data/text/en.json", "placeholders differ for '%s': ko %s en %s" % [k, a.keys(), b.keys()])
	for k in en:
		if not ko.has(k): _f("ERROR", "TEXT_PARITY", "01", "data/text/ko.json", "key '%s' only in en" % k)

	# ---------- display names (theme-rename risks) ----------
	# NAMES: id -> {ko, en, fallback} for every unit/hero/skill/round, printed so before/after a retheme can be diffed.
	# DUP_NAME (WARN): two different ids show the same text in one locale (players cannot tell them apart).
	# STALE_NAME (WARN): the data `name` fallback differs from the ko text of `name_key` (a renamed label whose
	# fallback still shows the old name if the text table fails to load).
	var name_rows := {}
	var named: Array = []
	for id in units: named.append(["unit", id, units[id], uf])
	for id in heroes: named.append(["hero", id, heroes[id], "data/heroes/%s.json" % id])
	for id in skills: named.append(["skill", id, skills[id], "data/skills/%s.json" % id])
	for rid in rounds: named.append(["round", rid, rounds[rid], round_files[rid]])
	var by_text := {"ko": {}, "en": {}}
	for n in named:
		var d: Dictionary = n[2]
		var key := str(d.get("name_key", ""))
		var row := {"kind": n[0], "fallback": str(d.get("name", ""))}
		for loc in TEXT_LOCALES:
			var txt := str(texts[loc].get(key, "")) if key != "" else ""
			row[loc] = txt
			if txt != "":
				var bucket: String = n[0] + ":" + txt
				if by_text[loc].has(bucket):
					_f("WARN", "DUP_NAME", "01", n[3], "%s '%s' shows the same %s name '%s' as '%s'" % [n[0], n[1], loc, txt, by_text[loc][bucket]])
				else:
					by_text[loc][bucket] = n[1]
			_tick("DUP_NAME")
		_tick("STALE_NAME")
		if key != "" and row.fallback != "" and row.ko != "" and row.fallback != row.ko:
			_f("WARN", "STALE_NAME", "01", n[3], "%s '%s' fallback name '%s' != ko text '%s'" % [n[0], n[1], row.fallback, row.ko])
		name_rows[n[1]] = row
	print("CI NAMES ", JSON.stringify(name_rows))

	# ---------- version fields (proposal-level: DATA_SCHEMA does not mandate them yet) ----------
	var vfiles := {"data/units/units.json": units_doc, "data/rounds/order.json": order_doc, "data/economy.json": economy,
		"data/meta.json": meta, "data/game_config.json": cfg}
	for loc in TEXT_LOCALES: vfiles["data/text/%s.json" % loc] = _load("res://data/text/%s.json" % loc)
	for id in skills: vfiles["data/skills/%s.json" % id] = skills[id]
	for id in heroes: vfiles["data/heroes/%s.json" % id] = heroes[id]
	for rid in rounds: vfiles[round_files[rid]] = rounds[rid]
	var missing_v: Array = []
	for f in vfiles:
		_tick("VERSION")
		var d = vfiles[f]
		if d is Dictionary and not d.has("schema_version"): missing_v.append(f)
	if not missing_v.is_empty():
		_f("INFO", "VERSION", "01", "data/**", "%d of %d data files have no schema_version: %s" % [missing_v.size(), vfiles.size(), ", ".join(missing_v)])
	_tick("VERSION")
	if not (cfg is Dictionary and cfg.has("data_version")):
		_f("INFO", "VERSION", "01", "data/game_config.json", "no global data_version")

	var summary := {"counts": counts, "checks_run": checked, "tables": {"units": units.size(), "skills": skills.size(),
		"heroes": heroes.size(), "rounds": rounds.size(), "order": order.size(), "text_ko": ko.size(), "text_en": en.size(),
		"anim_sets": anim_sets.size(), "ui_frames": ui_frames.size()}}
	print("PROBE10_CONTENT_INTEGRITY ", JSON.stringify(summary))
	quit(1 if counts.ERROR > 0 else 0)
