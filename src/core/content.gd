extends Node
## Data loader with fallbacks. Contract: INTERFACES.md §2. Owner: 02-engine.
## Usable as autoload ("Content") or standalone (`preload(...).new()` + load_all()) for headless tests.

const Defaults := preload("res://src/core/default_content.gd")

const UNIT_DEFAULTS := {
	"name": "", "faction": "both", "cost": 50, "cooldown": 3.0, "hp": 100.0, "atk": 10.0,
	"atk_interval": 1.0, "range": 18.0, "speed": 30.0, "attack_type": "melee", "projectile": "",
	"splash": 0.0, "knockback": 0.0, "armor": 0.0, "targets": "ground", "bounty": 5, "size": 1.0,
	"anim_set": "", "tags": [],
}
const HERO_DEFAULTS := {
	"name": "Hero", "hp": 600.0, "atk": 25.0, "atk_interval": 0.8, "range": 22.0, "speed": 70.0,
	"armor": 0.0, "respawn": 10.0, "mana_max": 100.0, "mana_regen": 4.0, "skills": [], "anim_set": "", "leash": 0.6,
	"splash": 0.0, "projectile": "", "attack_type": "melee", "knockback": 0.0, "size": 1.0, "tags": ["hero"],
}
const SKILL_DEFAULTS := {
	"name": "", "mana": 30.0, "cooldown": 8.0, "kind": "aoe_damage", "radius": 80.0, "power": 50.0,
	"duration": 0.0, "fx": "", "unit": "", "count": 1,
}
const ROUND_DEFAULTS := {
	"name": "", "index": 0, "biome": "meadow", "lane_length": 1200.0, "player_base_hp": 1500.0,
	"enemy_base_hp": 1500.0, "start_gold": 100, "hero": "hero_knight", "cards": [], "waves": [],
	"enemy_ai": {}, "enemy_base_spawns_on_hp": [], "reward": {}, "stars": {},
}

var economy: Dictionary = {}
var config: Dictionary = {}      # data/game_config.json (caps, lane, ...)
var meta: Dictionary = {}        # data/meta.json (upgrades, currencies) — read-only here
var units: Dictionary = {}
var heroes: Dictionary = {}
var skills: Dictionary = {}
var rounds: Dictionary = {}
var round_order: Array[String] = []
var warnings: PackedStringArray = []
var data_root := "res://data"

func _ready() -> void:
	load_all()

func load_all(root := "res://data") -> void:
	data_root = root
	warnings.clear()
	economy = Defaults.economy()
	var e = _read_json(root + "/economy.json")
	if e is Dictionary:
		economy.merge(e, true)
	var gc = _read_json(root + "/game_config.json")
	config = gc if gc is Dictionary else {}
	var mt = _read_json(root + "/meta.json")
	meta = mt if mt is Dictionary else {}
	units = _load_set("units", Defaults.units(), UNIT_DEFAULTS)
	heroes = _load_set("heroes", Defaults.heroes(), HERO_DEFAULTS)
	skills = _load_set("skills", Defaults.skills(), SKILL_DEFAULTS)
	rounds = _load_set("rounds", Defaults.rounds(), ROUND_DEFAULTS)
	_build_order()
	_validate_refs()
	for w in warnings:
		push_warning("[Content] " + w)

## Data files replace the built-in defaults for a set when they provide at least one valid entry.
func _load_set(kind: String, defaults: Array, schema: Dictionary) -> Dictionary:
	var out := {}
	var fallback := {}
	for d in defaults:
		fallback[d.id] = _normalize(d, schema)
	var dir := DirAccess.open(data_root + "/" + kind)
	if dir == null:
		return fallback
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json") or f == "order.json":
			continue
		var parsed = _read_json(data_root + "/" + kind + "/" + f)
		var list: Array = []
		if parsed is Dictionary and parsed.has(kind) and parsed[kind] is Array:
			list = parsed[kind]
		elif parsed is Dictionary and parsed.has("id"):
			list = [parsed]
		elif parsed is Array:
			list = parsed
		elif parsed != null:
			warnings.append("%s/%s: unrecognised shape" % [kind, f])
		for item in list:
			if item is Dictionary and item.has("id") and str(item.id) != "":
				out[str(item.id)] = _normalize(item, schema)
			else:
				warnings.append("%s/%s: entry without id skipped" % [kind, f])
	if out.is_empty():
		return fallback
	return out

func _normalize(d: Dictionary, schema: Dictionary) -> Dictionary:
	var n := schema.duplicate(true)
	n.merge(d.duplicate(true), true)
	n.id = str(n.id)
	if str(n.get("name", "")) == "":
		n.name = n.id.capitalize()
	# coerce numeric fields to the schema's type (JSON gives floats)
	for k in schema:
		if typeof(schema[k]) == TYPE_FLOAT and (typeof(n[k]) == TYPE_INT or typeof(n[k]) == TYPE_FLOAT):
			n[k] = float(n[k])
		elif typeof(schema[k]) == TYPE_INT and typeof(n[k]) == TYPE_FLOAT:
			n[k] = int(n[k])
	if str(n.get("anim_set", "")) == "" and schema.has("anim_set"):
		n.anim_set = n.id
	return n

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	var j := JSON.new()
	if j.parse(txt) != OK:
		warnings.append("%s: JSON error line %d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data

func _build_order() -> void:
	round_order.clear()
	var o = _read_json(data_root + "/rounds/order.json")
	if o is Dictionary and o.get("rounds") is Array:
		for id in o.rounds:
			if rounds.has(str(id)):
				round_order.append(str(id))
			else:
				warnings.append("order.json references missing round " + str(id))
	if round_order.is_empty():
		var ids := rounds.keys()
		ids.sort_custom(func(a, b): return [rounds[a].index, a] < [rounds[b].index, b])
		for id in ids:
			round_order.append(str(id))

func _validate_refs() -> void:
	for rid in rounds:
		var r: Dictionary = rounds[rid]
		if not heroes.has(str(r.hero)):
			warnings.append("round %s: hero %s missing -> first hero" % [rid, r.hero])
			r.hero = heroes.keys()[0]
		var cards: Array = []
		for c in r.cards:
			if c == null:
				continue   # null entries -> derive from unlock_round below
			if units.has(str(c)):
				cards.append(str(c))
			else:
				warnings.append("round %s: card %s missing, dropped" % [rid, c])
		r.cards = cards
		var raw_skills = r.get("skills", null)
		var explicit_skills: bool = raw_skills is Array and (raw_skills.is_empty() or raw_skills.any(func(x): return x != null))
		var sk: Array = []
		for s in (raw_skills if raw_skills is Array else []):
			if s != null and skills.has(str(s)):
				sk.append(str(s))
		r["skills"] = sk
		r["_skills_explicit"] = explicit_skills
		for w in r.waves:
			for s in w.get("spawns", []):
				if not units.has(str(s.get("unit", ""))):
					warnings.append("round %s: wave unit %s missing -> first enemy" % [rid, s.get("unit")])
					s.unit = _first_enemy_id()
	for hid in heroes:
		var keep: Array = []
		for s in heroes[hid].skills:
			if skills.has(str(s)):
				keep.append(str(s))
			else:
				warnings.append("hero %s: skill %s missing" % [hid, s])
		heroes[hid].skills = keep

func _first_enemy_id() -> String:
	for id in units:
		if str(units[id].faction) == "enemy":
			return id
	return units.keys()[0]

## Deploy cards for a round: explicit list, else player units with unlock_round <= index (max 5).
func round_cards(r: Dictionary) -> Array:
	if not r.cards.is_empty():
		return r.cards.slice(0, 5)
	var idx := int(r.index)
	var ids: Array = []
	for id in units:
		var u: Dictionary = units[id]
		if str(u.faction) in ["player", "both"] and int(u.get("unlock_round", 1)) <= idx and not bool(u.get("is_worker", false)):
			ids.append(id)
	ids.sort_custom(func(a, b): return [int(units[a].get("unlock_round", 1)), float(units[a].cost)] < [int(units[b].get("unlock_round", 1)), float(units[b].cost)])
	if ids.is_empty():
		ids = ["spearman"] if units.has("spearman") else [units.keys()[0]]
	return ids.slice(0, 5)

## Enemy unit ids that can appear in a round (waves, AI pool, trickle, HP triggers, boss summons).
## Used for per-round atlas residency (08 P6).
func round_enemy_roster(r: Dictionary) -> Array:
	var ids: Array = []
	var add := func(id) -> void:
		var s := str(id)
		if units.has(s) and not ids.has(s): ids.append(s)
	for w in r.get("waves", []):
		for s in w.get("spawns", []): add.call(s.get("unit", ""))
	for id in r.get("enemy_ai", {}).get("pool", []): add.call(id)
	for id in r.get("trickle", {}).get("pattern", []): add.call(id)
	for trg in r.get("enemy_base_spawns_on_hp", []):
		for s in trg.get("spawns", []): add.call(s.get("unit", ""))
	for id in ids.duplicate():
		var sm = units[id].get("summon")
		if sm is Dictionary: add.call(sm.get("unit", ""))
	return ids

## Hero skills for a round: explicit round list, else hero skills with unlock_round <= index.
func round_skills(r: Dictionary) -> Array:
	var hero: Dictionary = heroes.get(str(r.hero), {})
	var hs: Array = hero.get("skills", [])
	var explicit: Array = r.get("skills", [])
	var is_explicit := bool(r.get("_skills_explicit", false))
	var out: Array = []
	for s in hs:
		if not is_explicit:
			if int(skills[s].get("unlock_round", 1)) <= int(r.index):
				out.append(s)
		elif explicit.has(s):
			out.append(s)
	return out.slice(0, 3)

## Effective entity caps. ONE source: data/game_config.json `caps` (01). Missing keys use CAPS_DEFAULT (same
## values as the data at 2026-10-31); every value is clamped to the engine hard ceilings in perf.gd.
const CAPS_DEFAULT := {"max_ally_units": 36, "max_enemy_units": 36, "max_projectiles": 64, "max_vfx": 48, "max_damage_popups": 24}
const PerfS := preload("res://src/core/perf.gd")

func caps() -> Dictionary:
	var gc: Dictionary = CAPS_DEFAULT.duplicate()
	var src = config.get("caps", {})
	if src is Dictionary:
		for k in CAPS_DEFAULT:
			if src.has(k) and (src[k] is int or src[k] is float):
				gc[k] = src[k]
	return {
		"ally": clampi(int(gc.max_ally_units), 1, PerfS.CAP_UNITS_PER_SIDE),
		"enemy": clampi(int(gc.max_enemy_units), 1, PerfS.CAP_UNITS_PER_SIDE),
		"projectiles": clampi(int(gc.max_projectiles), 8, PerfS.CAP_PROJECTILES),
		"fx": clampi(int(gc.max_vfx), 8, PerfS.CAP_FX),
		"text": clampi(int(gc.max_damage_popups), 0, PerfS.CAP_FLOATING_TEXT),
	}

# ---- read-only queries (INTERFACES.md §4) ----
func get_unit(id: String) -> Dictionary:
	if units.has(id):
		return units[id]
	return units.values()[0]

func get_round(id: String) -> Dictionary:
	return rounds.get(id, {})

func get_round_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in round_order:
		var r: Dictionary = rounds[id]
		out.append({"id": id, "index": r.index, "name": r.name, "biome": r.biome})
	return out

func next_round_id(id: String) -> String:
	var i := round_order.find(id)
	if i >= 0 and i + 1 < round_order.size():
		return round_order[i + 1]
	return ""
