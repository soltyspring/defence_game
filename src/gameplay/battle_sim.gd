extends RefCounted
## Deterministic 1-D lane battle simulation (no nodes, no autoloads) so it runs headless.
## Owner: 02-engine. Rendering lives in battle_view.gd; node wiring in battle.gd.
## Supported data keys: INTERFACES.md §2 + §2.7 (01 design extensions).

const PerfC := preload("res://src/core/perf.gd")

const SIDE_PLAYER := 1
const SIDE_ENEMY := -1
const BASE_INSET := 40.0
const BASE_HALF := 22.0
const HERO_HOME := 64.0     # hero start / revive point, world px right of the player base centre
const TIME_LIMIT := 900.0
const KB_DECAY := 300.0
const SIDES: Array[int] = [1, -1]
enum { S_WALK, S_ATTACK, S_DYING, S_IDLE }

class Unit:
	var alive := false
	var dying := false
	var uid := 0
	var side := 1
	var id := ""
	var def: Dictionary
	var x := 0.0
	var lane_y := 0.0
	var hp := 1.0
	var hp_max := 1.0
	var atk := 1.0
	var atk_cd := 0.0
	var windup := -1.0
	# Mutual attack targets must not keep two RefCounted units alive after battle teardown.
	var _target_ref: WeakRef
	var w_target: Unit:
		get: return _target_ref.get_ref() if _target_ref != null else null
		set(value): _target_ref = weakref(value) if value != null else null
	var w_base := false
	var state := 0
	var anim_t := 0.0
	var dead_t := 0.0
	var buff_t := 0.0
	var buff_mul := 1.0
	var shield := 0.0      # sugar barrier (skill_shield): absorbs damage before HP
	var shield_t := 0.0
	var aura_mul := 1.0
	var cream_t := 0.0      # > 0: whipped cream on its head (cake hit): attacks recharge at cream_mul
	var cream_mul := 1.0
	var flash := 0.0
	var kb := 0.0
	var invuln := 0.0
	var is_hero := false
	var is_boss := false
	var contact := 6.0
	var summon_t := 0.0
	var in_lane := false
	var wave_tag := 0      # 1-based scripted wave that spawned this unit; 0 = trickle/AI/trigger/summon/pressure
	var anim_set := ""
	# Chapter 4 data rules (unit keys `heavy`, `link`, `hold_behind`; docs/design/CHALLENGE_R31_R40.md). All neutral by default.
	var heavy_cd := 0.0    # s until the next announced heavy attack may start
	var heavy_t := -1.0    # >= 0: announcing (telegraph), s left before the hit
	var heavy_x := 0.0     # centre of the announced zone (fixed when the telegraph starts, so it can be left)
	var recover_t := 0.0   # > 0: recovering after a heavy attack: no move, no attack
	var exposed_t := 0.0   # > 0: damage taken x exposed_mul (recovering, or its link was just cut)
	var exposed_mul := 1.0
	var guard_mul := 1.0   # < 1 while a living link source protects this unit
	var ab: Dictionary = {}  # the `heavy` entry in use ({} = none); units with a list switch after each use
	var ab_i := 0
	var heavy_r := 0.0     # half width of the announced zone around heavy_x (0 = no ground zone)
	var heavy_acc := 0.0   # damage taken during the current prepare (interrupt_damage)
	var fire_t := -1.0     # >= 0: dashing (charge), s left
	var fire_dur := 0.1
	var fire_x0 := 0.0
	var fire_x1 := 0.0
	var hidden := false    # burrowed: not in the target lanes, drawn as a trail
	var burrow_t := 0.0
	var shell_mul := 1.0   # `shell`.closed_mult: damage factor while not exposed
	var link_src := 0      # uid of that source (0 = none); the view draws the strand
	var link_lost := false # a source of this unit died this step; resolved in _step_links (unit key `link_break`)
	var phase := 0         # boss key `phases`: entries already entered
	var sm: Dictionary = {}  # the `summon` entry in use (a phase may replace or clear it)

class Projectile:
	var alive := false
	var side := 1
	var kind := ""
	var x0 := 0.0
	var x1 := 0.0
	var x := 0.0
	var y := 0.0
	var t := 0.0
	var dur := 0.3
	var arc := 0.0
	var dmg := 0.0
	var splash := 0.0
	var struct_mult := 1.0
	var knockback := 0.0
	var homing := true
	var target: Unit = null
	var hit_base := false
	var slow_mul := 1.0     # attack-speed factor put on every unit it splashes (unit keys atk_slow_mul / atk_slow_s)
	var slow_s := 0.0

class Fx:
	var alive := false
	var kind := ""
	var warning_owner := 0    # unit uid for wind-ups; 0 for a released hazard
	var warning_shape := ""
	var warning_track := 0    # three visible rails, then the overflow rail
	var x := 0.0
	var y := 0.0
	var t := 0.0
	var dur := 0.4
	var radius := 0.0

class FText:
	var serial := 0
	var alive := false
	var x := 0.0
	var y := 0.0
	var t := 0.0
	var text := ""
	var kind := &"dmg"
	var uid := 0          # target unit uid for merging repeated hits (0 = not mergeable)
	var value := 0        # numeric value of a merged damage text
	var anchor_set := ""  # target anim_set: renderer places the text above that sprite's frame + hp bar
	var rise := 0.0       # px risen since spawn (renderer offset)

# ---- config ----
var content            # content.gd instance (autoload or standalone)
var round_def: Dictionary
var econ: Dictionary
var hero_def: Dictionary
var caps := {}            # filled from Content.caps() in setup (single source: data/game_config.json caps)
var upgrades: Dictionary = {}     # upgrade_id -> level (from Save)
var L := 1200.0
var rng := RandomNumberGenerator.new()
var _text_rng := RandomNumberGenerator.new()
var gold_max := 999.0
var workers_max := 8
var enemy_hp_mult := 1.0
var enemy_atk_mult := 1.0
var tower: Dictionary = {}
var enemy_tower_mult := 1.0
## 01 D29 player-base defence (economy.base_defense; every key 0 = off = previous behaviour):
## dps_cap HP/s over a sliding 1 s window, push_px knock-back on enemy melee base hits (bosses immune),
## stagger_s extra attack delay after an enemy base hit, tower_splash px splash for the PLAYER tower only.
var base_defense := {"dps_cap": 0.0, "push_px": 0.0, "stagger_s": 0.0, "tower_splash": 0.0}
var _pbase_hits := PackedFloat64Array()   # [t0, dmg0, t1, dmg1, ...] applied damage on the player base, last 1 s
var base_dmg_capped := 0.0                # damage removed by the cap this battle (probe/QA evidence)
var hero_atk_mult := 1.0
var hero_hp_mult := 1.0
var income_add := 0.0
var mana_regen := 3.0
var mana_max := 100.0

# ---- state ----
var t := 0.0
var ended := false
var won := false
var paused := false
var gold := 0.0
var workers := 1
var mana := 0.0
var kills := 0
var kill_coins := 0
var hero_deaths := 0
var card_ids: Array[String] = []
var card_cd: Dictionary = {}
var skill_ids: Array[String] = []
var skill_cd: Dictionary = {}
var hero: Unit
var hero_dir := 0
var hero_respawn := 0.0
var player_base := {"hp": 1500.0, "hp_max": 1500.0, "x": BASE_INSET, "flash": 0.0, "tower_cd": 0.0}
var enemy_base := {"hp": 1500.0, "hp_max": 1500.0, "x": 1160.0, "flash": 0.0, "tower_cd": 0.0}
var players: Array[Unit] = []
var enemies: Array[Unit] = []
var projectiles: Array[Projectile] = []
var fxs: Array[Fx] = []
var texts: Array[FText] = []
var _text_serial := 0
var delayed: Array = []            # delayed skill impacts [{at, x, radius, power, kb, struct, fx}]
var _unit_pool: Array[Unit] = []
var _uid := 0
var spawn_queue: Array = []        # [{at, unit}] sorted by at
var waves_total := 0
var wave_times: Array[float] = []     # scripted waves only (pressure waves excluded, 01 D21)
var wave_boss: Array[bool] = []
var _wave_announced := 0
var _wave_pending: Array[int] = []    # per scripted wave: units still to spawn
var _wave_alive: Array[int] = []      # per scripted wave: spawned units not yet dead
var _wave_cleared: Array[bool] = []
var pressure_times: Array[float] = []   # `pressure: true` waves (01 D18/D21): not counted, one cue on the first
var _pressure_announced := false
var ai_gold := 0.0
var ai_think := 2.0
var trickle: Dictionary = {}
var trickle_next := -1.0
var trickle_i := 0
var hp_triggers_fired: Dictionary = {}
var events: Array = []             # drained by battle.gd: [type:String, data:Dictionary]
var refused_spawns := 0
var time_limit := TIME_LIMIT        # <= 0 disables (QA long runs)
var cues: Dictionary = {}           # audio cues coalesced per step: "cue:kind" -> [cue, params]; drained by battle.gd
var _lane_p: Array[Unit] = []
var _lane_e: Array[Unit] = []
var _base_dead_enemy := false
var _base_dead_player := false
var _in_step := false
var _linear_targets := false        # A/B benchmark switch only (selftest/perf); never set in gameplay
var _link_sources := 0              # living enemy units with a `link` key; 0 = the link pass is skipped
var _links_dirty := false           # a source died: clear the protection it gave
var danger_gap := 0.0               # round key `danger_gap` (s): enemy danger zones come one at a time, with this calm after each
var _danger_free_at := 0.0          # t from which the next enemy announcement may start
var stats := {"deployed": 0, "workers_bought": 0, "skills_cast": 0, "enemy_spawned": 0, "max_units": 0, "max_projectiles": 0, "hero_deaths": 0,
	"gold_capped_s": 0.0, "mana_capped_s": 0.0}

func setup(p_content, round_id: String, seed_value: int = 1, p_upgrades: Dictionary = {}, loadout: Array = [], skill_pick: Array = []) -> void:
	content = p_content
	upgrades = p_upgrades
	round_def = content.get_round(round_id)
	if round_def.is_empty():
		round_def = content.get_round(content.round_order[0])
	econ = content.economy
	hero_def = content.heroes.get(str(round_def.hero), content.heroes.values()[0])
	rng.seed = seed_value
	_text_rng.seed = seed_value ^ 0x5eed
	L = float(round_def.lane_length)
	_read_caps()
	_prealloc_pools()
	gold_max = float(round_def.get("gold_max", econ.gold_max))
	workers_max = int(round_def.get("workers_max", econ.workers_max))
	var sc: Dictionary = round_def.get("enemy_scaling", {})
	enemy_hp_mult = float(sc.get("hp", 1.0))
	enemy_atk_mult = float(sc.get("atk", 1.0))
	tower = econ.get("base_tower", {})
	enemy_tower_mult = float(round_def.get("enemy_tower_atk_mult", 1.0))
	danger_gap = float(round_def.get("danger_gap", 0.0))
	var bd = econ.get("base_defense", {})
	base_defense = {"dps_cap": 0.0, "push_px": 0.0, "stagger_s": 0.0, "tower_splash": 0.0}
	if bd is Dictionary:
		for k in base_defense:
			if bd.get(k) is int or bd.get(k) is float: base_defense[k] = float(bd[k])
	_pbase_hits.clear()
	# meta upgrades
	var base_hp_mult := _upgrade_mult("base:player", "hp_mult")
	hero_hp_mult = _upgrade_mult("hero:" + str(hero_def.id), "hp_mult")
	hero_atk_mult = _upgrade_mult("hero:" + str(hero_def.id), "atk_mult")
	income_add = _upgrade_add("resource:supply", "regen_add")
	gold_max += _upgrade_add("resource:supply", "cap_add")
	mana_regen = float(hero_def.mana_regen) + _upgrade_add("resource:energy", "regen_add")
	mana_max = float(hero_def.mana_max) + _upgrade_add("resource:energy", "cap_add")
	var php := float(round_def.player_base_hp) * base_hp_mult
	player_base = {"hp": php, "hp_max": php, "x": BASE_INSET, "flash": 0.0, "tower_cd": 0.0}
	enemy_base = {"hp": float(round_def.enemy_base_hp), "hp_max": float(round_def.enemy_base_hp), "x": L - BASE_INSET, "flash": 0.0, "tower_cd": 0.0}
	gold = float(round_def.start_gold)
	workers = int(econ.workers_start)
	mana = float(hero_def.get("mana_start", mana_max * 0.5))
	card_ids.clear()
	# The caller validates account unlocks; this layer also rejects enemies, duplicates and a sixth slot.
	var selected: Array = content.valid_loadout(loadout, 100)
	for c in (selected if not selected.is_empty() else content.round_cards(round_def)):
		card_ids.append(str(c))
		card_cd[str(c)] = 0.0
	skill_ids.clear()
	# the player's chosen 3 (validated against their progress by Save) or the round's default skills
	var picked: Array = content.valid_skills(skill_pick, 100) if content.has_method("valid_skills") else []
	for s in (picked if not picked.is_empty() else content.round_skills(round_def)):
		skill_ids.append(str(s))
		skill_cd[str(s)] = 0.0
	# start (and revive) just right of the keep: at +30 the hero stood on the keep's light wall and was hard to find
	hero = _new_unit(hero_def, SIDE_PLAYER, player_base.x + HERO_HOME)
	hero.is_hero = true
	hero.hp_max *= hero_hp_mult
	hero.hp = hero.hp_max
	hero.atk *= hero_atk_mult
	hero.lane_y = 2.0
	# schedule waves
	spawn_queue.clear()
	wave_times.clear()
	wave_boss.clear()
	pressure_times.clear()
	_pressure_announced = false
	_wave_pending.clear()
	_wave_alive.clear()
	_wave_cleared.clear()
	for w in round_def.waves:
		var at := float(w.get("at", 0))
		if bool(w.get("pressure", false)):
			_queue_spawns(w.get("spawns", []), at, 0)   # pressure waves spawn but are not counted/announced
			pressure_times.append(at)
			continue
		wave_times.append(at)
		wave_boss.append(bool(w.get("boss", false)))
		_wave_pending.append(0)
		_wave_alive.append(0)
		_wave_cleared.append(false)
		_wave_pending[-1] = _queue_spawns(w.get("spawns", []), at, wave_times.size())
	waves_total = wave_times.size()
	var ai: Dictionary = round_def.enemy_ai
	ai_gold = float(ai.get("start_gold", 0))
	ai_think = float(ai.get("think", 3.0))
	trickle = round_def.get("trickle", {})
	trickle_next = float(trickle.get("start", -1.0)) if trickle.get("pattern", []).size() > 0 else -1.0

func _read_caps() -> void:
	caps = content.caps()

## Pre-create pooled objects up to the caps so no object is allocated mid-fight (08 P7 item 9).
func _prealloc_pools() -> void:
	while projectiles.size() < caps.projectiles:
		projectiles.append(Projectile.new())
	while fxs.size() < caps.fx:
		fxs.append(Fx.new())
	while texts.size() < caps.text:
		texts.append(FText.new())
	var want_units: int = caps.ally + caps.enemy + 8   # + dying units still on screen
	while _unit_pool.size() < want_units:
		_unit_pool.append(Unit.new())

func _upgrade_level(target: String) -> int:
	for u in content.meta.get("upgrades", []):
		if str(u.get("target", "")) == target:
			return int(upgrades.get(str(u.id), 1))
	return 1

func _upgrade_mult(target: String, key: String) -> float:
	for u in content.meta.get("upgrades", []):
		if str(u.get("target", "")) == target:
			var lvl := int(upgrades.get(str(u.id), 1))
			lvl = clampi(lvl, 1, int(u.get("max_level", 1)))
			var base := 1.0 + float(u.get("per_level", {}).get(key, 0.0)) * (lvl - 1)
			var after := int(u.get("compound_after_level", lvl))
			return base * pow(1.0 + float(u.get("compound_rate", 0.0)), maxi(0, lvl - after))
	return 1.0

func _upgrade_add(target: String, key: String) -> float:
	for u in content.meta.get("upgrades", []):
		if str(u.get("target", "")) == target:
			var lvl := int(upgrades.get(str(u.id), 1))
			lvl = clampi(lvl, 1, int(u.get("max_level", 1)))
			return float(u.get("per_level", {}).get(key, 0.0)) * (lvl - 1)
	return 0.0

## Queue spawn entries; `wave` = scripted wave index (1-based) or 0. Returns the number of units queued.
func _queue_spawns(spawns: Array, at: float, wave: int = 0) -> int:
	var total := 0
	for s in spawns:
		var n := int(s.get("count", 1))
		var iv := float(s.get("interval", 1.0))
		for i in n:
			spawn_queue.append({"at": at + i * iv, "unit": str(s.unit), "wave": wave})
			total += 1
	spawn_queue.sort_custom(func(a, b): return a.at < b.at)
	return total

# ================= commands =================
func worker_cost() -> int:
	return int(round(float(econ.worker_cost_base) * pow(float(econ.worker_cost_growth), workers - int(econ.workers_start))))

func income() -> float:
	return float(econ.base_income) + income_add + workers * (float(econ.worker_income) + _upgrade_add("worker", "income_add"))

func buy_worker() -> String:
	if ended: return "ended"
	if workers >= workers_max: return "worker_max"
	var c := worker_cost()
	if gold < c: return "not_enough_gold"
	gold -= c
	workers += 1
	stats.workers_bought += 1
	events.append(["worker", {"workers": workers}])
	return ""

func army_count(side: int) -> int:
	var n := 0
	for u in (players if side == SIDE_PLAYER else enemies):
		if not u.dying: n += 1
	return n

func deploy(unit_id: String) -> String:
	if ended: return "ended"
	if not card_cd.has(unit_id): return "unknown"
	if card_cd[unit_id] > 0.0: return "on_cooldown"
	var d: Dictionary = content.get_unit(unit_id)
	if gold < float(d.cost): return "not_enough_gold"
	if army_count(SIDE_PLAYER) >= caps.ally: return "army_full"
	gold -= float(d.cost)
	card_cd[unit_id] = float(d.cooldown)
	var u := _new_unit(d, SIDE_PLAYER, player_base.x + BASE_HALF)
	u.hp_max *= _upgrade_mult("unit:" + unit_id, "hp_mult")
	u.hp = u.hp_max
	u.atk *= _upgrade_mult("unit:" + unit_id, "atk_mult")
	players.append(u)
	stats.deployed += 1
	events.append(["deploy", {"unit": unit_id}])
	return ""

func cast(skill_id: String) -> String:
	if ended: return "ended"
	if not skill_cd.has(skill_id): return "unknown"
	if hero_respawn > 0.0: return "hero_dead"
	if skill_cd[skill_id] > 0.0: return "on_cooldown"
	var s: Dictionary = content.skills[skill_id]
	if mana < float(s.mana): return "not_enough_mana"
	mana -= float(s.mana)
	skill_cd[skill_id] = float(s.cooldown)
	stats.skills_cast += 1
	var radius := float(s.radius)
	var power := float(s.power) * hero_atk_mult
	var kb := float(s.get("knockback", 0.0))
	var cx := hero.x + float(s.get("offset_x", 0.0))
	var fx := str(s.fx)
	match str(s.kind):
		"aoe_damage":
			_area_damage(cx, radius, power, kb, 1.0)
			_fx(fx if fx != "" else "shockwave", cx, 0.0, 0.5, radius)
		"meteor":
			var mx := _frontmost_enemy_x()
			if mx - hero.x > 320.0 or mx < hero.x - 40.0:
				mx = hero.x + 120.0
			var delay := float(s.get("delay", 0.0))
			if delay > 0.0:
				delayed.append({"at": t + delay, "x": mx, "radius": radius, "power": power, "kb": kb, "fx": fx if fx != "" else "meteor"})
				_fx("target_mark", mx, 0.0, delay, radius)
			else:
				_area_damage(mx, radius, power, kb, 1.0)
				_fx(fx if fx != "" else "meteor", mx, 0.0, 0.6, radius)
		"heal_allies":
			for a in players + [hero]:
				if not a.dying and absf(a.x - cx) <= radius:
					a.hp = minf(a.hp_max, a.hp + power)
					_text(a.x, -30.0, "+%d" % int(power), &"heal")
			_fx(fx if fx != "" else "heal", cx, 0.0, 0.6, radius)
		"rally":
			for a in players + [hero]:
				if not a.dying and absf(a.x - cx) <= radius:
					a.buff_t = float(s.duration)
					a.buff_mul = 1.0 + float(s.power) / 100.0
			_fx(fx if fx != "" else "rally", hero.x, 0.0, 0.8, radius)
		"supply":
			# flour drop: instant flour, may pass the cap by nothing
			var before := gold
			gold = minf(gold_max, gold + float(s.power))
			_text(hero.x, -40.0, "+%d" % int(gold - before), &"heal")
			_fx(fx if fx != "" else "skill_flour", hero.x, 0.0, 0.8, 40.0)
		"shield":
			# sugar barrier: every ally in range absorbs power % of its max HP for `duration`
			for a in players + [hero]:
				if not a.dying and absf(a.x - cx) <= radius:
					a.shield = maxf(a.shield, a.hp_max * float(s.power) / 100.0)
					a.shield_t = float(s.duration)
			_fx(fx if fx != "" else "skill_shield", hero.x, 0.0, 0.8, radius)
		"frost":
			# frost cream: around the front of the enemy line, slow + weaken (bosses half as much) and a little damage
			var fx_x := _frontmost_enemy_x()
			if fx_x - hero.x > 320.0 or fx_x < hero.x - 40.0:
				fx_x = hero.x + 100.0
			var slow := float(s.get("slow", 0.5))
			for e in enemies:
				if not e.dying and absf(e.x - fx_x) <= radius:
					e.buff_mul = minf(e.buff_mul, 1.0 - (1.0 - slow) * (0.5 if e.is_boss else 1.0))
					e.buff_t = maxf(e.buff_t, float(s.duration))
			_area_damage(fx_x, radius, power, 0.0, 0.5)
			_fx(fx if fx != "" else "skill_frost", fx_x, 0.0, 0.9, radius)
		"oven":
			# oven heat: a strip of fire from the hero forward, `ticks` hits over `duration`
			var ticks := maxi(1, int(s.get("ticks", 4)))
			var span := float(s.duration)
			var mid := hero.x + radius * 0.5 + 10.0
			for i in ticks:
				delayed.append({"at": t + 0.15 + span * float(i) / float(ticks), "x": mid, "radius": radius * 0.5,
					"power": power, "kb": 0.0, "fx": "skill_oven"})
			_fx(fx if fx != "" else "skill_oven", mid, 0.0, span + 0.2, radius * 0.5)
		"summon":
			for i in int(s.get("count", 1)):
				if army_count(SIDE_PLAYER) < caps.ally and content.units.has(str(s.unit)):
					players.append(_new_unit(content.get_unit(str(s.unit)), SIDE_PLAYER, hero.x))
	events.append(["skill", {"skill": skill_id}])
	return ""

func set_hero_dir(d: int) -> void:
	hero_dir = clampi(d, -1, 1)

# ================= simulation =================
func step(dt: float) -> void:
	if ended or paused:
		return
	_in_step = true
	_step_inner(dt)
	_in_step = false

func _step_inner(dt: float) -> void:
	t += dt
	gold = minf(gold_max, gold + income() * dt)
	mana = minf(mana_max, mana + mana_regen * dt)
	if gold >= gold_max - 0.01: stats.gold_capped_s += dt          # flour sat at its cap: nothing was being bought
	if mana >= mana_max - 0.01 and not skill_ids.is_empty(): stats.mana_capped_s += dt
	for k in card_cd: card_cd[k] = maxf(0.0, card_cd[k] - dt)
	for k in skill_cd: skill_cd[k] = maxf(0.0, skill_cd[k] - dt)
	player_base.flash = maxf(0.0, player_base.flash - dt)
	enemy_base.flash = maxf(0.0, enemy_base.flash - dt)
	_step_wave_announce()
	_step_spawns()
	_step_trickle()
	_step_ai(dt)
	_step_hp_triggers()
	_step_delayed()
	_step_aura()
	_sort_lanes()
	_step_links()
	_step_hero(dt)
	for u in players: _step_unit(u, dt)
	for u in enemies: _step_unit(u, dt)
	_step_towers(dt)
	_step_projectiles(dt)
	_step_fx(dt)
	_reap()
	stats.max_units = maxi(stats.max_units, players.size() + enemies.size())
	# both bases destroyed in the same tick resolve as a player win (01 RELEASE_DESIGN_REVIEW §3)
	if not ended and (_base_dead_enemy or _base_dead_player):
		_end(_base_dead_enemy)
	if time_limit > 0.0 and t >= time_limit and not ended:
		_end(false)

## Per-step x-ordered views of each side (insertion sort: lanes are nearly sorted step to step).
## Used by _find_target for O(log n) lookups instead of O(n) scans (08-performance P2).
func _sort_lanes() -> void:
	_sorted_into(players, _lane_p)
	_sorted_into(enemies, _lane_e)

func _sorted_into(src: Array[Unit], dst: Array[Unit]) -> void:
	# persistent, nearly-sorted lane: drop dead/dying, append newcomers, insertion sort in place (≈O(n) per step)
	var w := 0
	for r in dst.size():
		var u: Unit = dst[r]
		if u.alive and not u.dying and not u.hidden:
			dst[w] = u
			w += 1
		else:
			u.in_lane = false
	dst.resize(w)
	for u in src:
		if not u.dying and not u.in_lane and not u.hidden:
			u.in_lane = true
			dst.append(u)
	for i in range(1, dst.size()):
		var cur: Unit = dst[i]
		var j := i - 1
		while j >= 0 and dst[j].x > cur.x:
			dst[j + 1] = dst[j]
			j -= 1
		dst[j + 1] = cur

func _step_wave_announce() -> void:
	while _wave_announced < wave_times.size() and wave_times[_wave_announced] <= t:
		events.append(["wave", {"index": _wave_announced + 1, "boss": wave_boss[_wave_announced]}])
		_wave_announced += 1
	# QA-B017 / 01 D21 note: the existing counterattack toast, once, when the FIRST pressure wave arrives
	if not _pressure_announced and not pressure_times.is_empty() and pressure_times.min() <= t:
		_pressure_announced = true
		events.append(["counterattack", {"pressure": true}])

func _step_spawns() -> void:
	while not spawn_queue.is_empty() and spawn_queue[0].at <= t:
		if army_count(SIDE_ENEMY) >= caps.enemy:
			spawn_queue[0].at = t + 0.5   # overflow policy: queue
			refused_spawns += 1
			return
		var s = spawn_queue.pop_front()
		var su := _spawn_enemy(s.unit)
		var wv := int(s.get("wave", 0))
		if wv > 0:
			su.wave_tag = wv
			_wave_pending[wv - 1] -= 1
			_wave_alive[wv - 1] += 1

func _step_trickle() -> void:
	if trickle_next < 0.0 or t < trickle_next:
		return
	var pat: Array = trickle.pattern
	spawn_queue.push_front({"at": t, "unit": str(pat[trickle_i % pat.size()]), "wave": 0})
	trickle_i += 1
	var iv := maxf(float(trickle.get("interval_min", 3.0)), float(trickle.get("interval", 8.0)) - float(trickle.get("ramp_per_min", 0.0)) * (t / 60.0))
	trickle_next = t + iv
	_step_spawns()

func _spawn_enemy(unit_id: String) -> Unit:
	var d: Dictionary = content.get_unit(unit_id)
	var u := _new_unit(d, SIDE_ENEMY, enemy_base.x - BASE_HALF)
	u.hp_max *= enemy_hp_mult
	u.hp = u.hp_max
	u.atk *= enemy_atk_mult
	if d.has("link"): _link_sources += 1
	enemies.append(u)
	stats.enemy_spawned += 1
	if u.is_boss:
		events.append(["boss", {"unit": unit_id}])
	return u

func _step_ai(dt: float) -> void:
	var ai: Dictionary = round_def.enemy_ai
	var pool: Array = ai.get("pool", [])
	if pool.is_empty():
		return
	var ramp := 1.0 + float(ai.get("ramp", 0.0)) * (t / 10.0)
	ai_gold += float(ai.get("income", 0.0)) * ramp * dt
	ai_think -= dt
	if ai_think > 0.0:
		return
	ai_think = float(ai.get("think", 3.0)) * rng.randf_range(0.7, 1.3)
	var pick := str(pool[rng.randi() % pool.size()])
	var d: Dictionary = content.get_unit(pick)
	if ai_gold >= float(d.cost) and army_count(SIDE_ENEMY) < caps.enemy:
		ai_gold -= float(d.cost)
		_spawn_enemy(pick)

func _step_hp_triggers() -> void:
	var frac: float = enemy_base.hp / enemy_base.hp_max
	var trig: Array = round_def.enemy_base_spawns_on_hp
	for i in trig.size():
		if not hp_triggers_fired.has(i) and frac < float(trig[i].get("below", 0.0)):
			hp_triggers_fired[i] = true
			_queue_spawns(trig[i].get("spawns", []), t)
			events.append(["counterattack", {}])

func _step_delayed() -> void:
	var i := delayed.size() - 1
	while i >= 0:
		var d: Dictionary = delayed[i]
		if t >= float(d.at):
			if d.has("side"):
				# a zone dropped by a unit (heavy kind "lob"): hits the other side, and its base if inside
				var victim: int = -int(d.side)
				_area_damage_side(victim, float(d.x), float(d.radius), float(d.power), float(d.kb), null)
				var wall: float = (player_base.x + BASE_HALF) if victim == SIDE_PLAYER else (enemy_base.x - BASE_HALF)
				if absf(wall - float(d.x)) <= float(d.radius):
					_damage_base(victim, float(d.power) * float(d.get("struct", 1.0)))
				events.append(["lob_burst", {"x": float(d.x), "r": float(d.radius)}])
			else:
				_area_damage(float(d.x), float(d.radius), float(d.power), float(d.kb), 1.0)
			_fx(str(d.fx), float(d.x), 0.0, 0.6, float(d.radius))
			delayed.remove_at(i)
		i -= 1

func _step_aura() -> void:
	var aura: Dictionary = hero_def.get("aura", {})
	var r := float(aura.get("radius", 0.0))
	var m := float(aura.get("atk_speed_mult", 1.0))
	var hero_up := hero_respawn <= 0.0
	for u in players:
		u.aura_mul = m if hero_up and r > 0.0 and absf(u.x - hero.x) <= r else 1.0

func _step_hero(dt: float) -> void:
	if hero_respawn > 0.0:
		hero_respawn -= dt
		if hero_respawn <= 0.0:
			hero.alive = true
			hero.dying = false
			hero.hp = hero.hp_max
			hero.x = player_base.x + HERO_HOME
			hero.state = S_IDLE
			hero.windup = -1.0
			hero.invuln = float(hero_def.get("invuln_on_spawn", 0.0))
			events.append(["hero_respawn", {}])
		return
	hero.anim_t += dt
	hero.flash = maxf(0.0, hero.flash - dt)
	hero.invuln = maxf(0.0, hero.invuln - dt)
	_step_buff(hero, dt)
	_apply_kb(hero, dt)
	var tgt := _find_target(hero)
	var reach: float = float(hero.def.range) + hero.contact
	var in_reach: bool = tgt != null and absf(tgt.x - hero.x) - tgt.contact <= reach
	var ebx: float = enemy_base.x
	var base_reach: bool = (ebx - BASE_HALF) - hero.x <= reach
	var blocked: bool = tgt != null and hero_dir > 0 and (tgt.x - hero.x) <= tgt.contact + hero.contact
	var can_move: bool = bool(hero_def.get("attack_while_moving", true)) or hero.windup < 0.0
	if hero_dir != 0 and can_move and not (hero_dir > 0 and (blocked or base_reach)):
		hero.x += hero_dir * float(hero.def.speed) * hero.buff_mul * dt
		var pbx: float = player_base.x
		# up to the front of the enemy base (2026-11-15 user; the old `leash` stopped the hero at 85 % of the lane):
		# moving on stops by itself once the base is in reach (base_reach above)
		hero.x = clampf(hero.x, pbx + 10.0, maxf(pbx + 40.0, ebx - BASE_HALF))
		hero.state = S_WALK
	elif hero.windup < 0.0 and not in_reach and not base_reach:
		hero.state = S_IDLE
	_attack_logic(hero, tgt, in_reach, base_reach and not in_reach, dt)

func _step_buff(u: Unit, dt: float) -> void:
	if u.buff_t > 0.0:
		u.buff_t -= dt
		if u.buff_t <= 0.0: u.buff_mul = 1.0
	if u.shield_t > 0.0:
		u.shield_t -= dt
		if u.shield_t <= 0.0: u.shield = 0.0
	if u.cream_t > 0.0:
		u.cream_t -= dt
		if u.cream_t <= 0.0: u.cream_mul = 1.0

func _apply_kb(u: Unit, dt: float) -> void:
	if u.kb > 0.0:
		var m := minf(u.kb, KB_DECAY * dt)
		u.kb -= m
		u.x -= u.side * m
		var lo: float = player_base.x + 4.0
		var hi: float = enemy_base.x - 4.0
		u.x = clampf(u.x, lo, hi)

func _step_unit(u: Unit, dt: float) -> void:
	u.anim_t += dt
	if u.dying:
		u.dead_t -= dt
		return
	u.flash = maxf(0.0, u.flash - dt)
	_step_buff(u, dt)
	_apply_kb(u, dt)
	if u.is_boss:
		_step_boss_phase(u)
		_step_boss_summon(u, dt)
	if u.exposed_t > 0.0:
		u.exposed_t -= dt
		if u.exposed_t <= 0.0: u.exposed_mul = 1.0
	var tgt := _find_target(u)
	var reach: float = float(u.def.range) + u.contact
	var in_reach: bool = tgt != null and absf(tgt.x - u.x) - tgt.contact <= reach
	var base_x: float = (enemy_base.x - BASE_HALF) if u.side == SIDE_PLAYER else (player_base.x + BASE_HALF)
	var base_reach: bool = (base_x - u.x) * u.side <= reach
	if not u.ab.is_empty() and _step_heavy(u, tgt, in_reach or base_reach, dt):
		return
	if not in_reach and not base_reach and u.windup < 0.0 and u.kb <= 0.0 and _held_back(u):
		u.state = S_IDLE      # `hold_behind`: stays behind its own front line
	elif not in_reach and not base_reach and u.windup < 0.0 and u.kb <= 0.0:
		u.state = S_WALK
		u.x += u.side * float(u.def.speed) * u.buff_mul * dt
	_attack_logic(u, tgt, in_reach, base_reach and not in_reach, dt)

# ---- chapter 4 data rules: announced heavy attack, link protection, hold behind the front ----
## Unit key `heavy`: ONE announced action per unit at a time, as prepare -> fire -> recover (+ cancel / death).
## A Dictionary, or an Array of them that the unit uses in turn (boss variations; never two at once).
## Common keys: kind ("slam" default | "vent" | "charge" | "lob" | "burrow"), interval, first, windup, radius, power,
## knockback, recover, exposed_mult, structure_mult, interrupt_damage, interrupt_recover.
##   prepare  `windup` s. The danger zone [heavy_x - heavy_r, heavy_x + heavy_r] is fixed here (fx "telegraph",
##            event "heavy") and the hit later tests exactly that zone, so whoever leaves it takes nothing.
##   fire     slam: everything of the other side in the zone takes atk x power.      (key: offset)
##            vent: no hit; the unit only opens up (see `shell`).                    (key: always)
##            charge: dashes along the announced path and hits the FIRST unit standing in it; nothing behind
##                    that unit is touched. With the path empty it runs to its end.  (keys: trigger, dist, dash_speed)
##            lob: drops a delayed zone on its target's position; that zone gets its own marker for `delay` s
##                 and then hits what is still inside.                                (keys: trigger, delay)
##            burrow: the unit went under before (hidden: no targeted attack reaches it, area damage does), ran
##                    past the opposing front and announced where it comes up.       (keys: trigger, burrow_speed, past, burrow_max)
##   recover  `recover` s: no move, no attack, damage taken x exposed_mult.
##   cancel   death, a cut link, or interrupt_damage taken during prepare: no hit, the marker is removed.
## Returns true while the unit is busy with it.
func _step_heavy(u: Unit, tgt: Unit, engaged: bool, dt: float) -> bool:
	var h: Dictionary = u.ab
	if u.recover_t > 0.0:
		u.recover_t -= dt
		if u.anim_t > 0.5: u.state = S_IDLE
		return true
	if u.fire_t >= 0.0:
		u.fire_t -= dt
		u.x = lerpf(u.fire_x1, u.fire_x0, clampf(u.fire_t / u.fire_dur, 0.0, 1.0))
		if u.fire_t < 0.0:
			u.x = u.fire_x1
			_resolve_heavy(u, h)
		return true
	if u.heavy_t >= 0.0:
		u.heavy_t -= dt
		if u.heavy_t < 0.0: _fire_heavy(u, h)
		return true
	var kind := str(h.get("kind", "slam"))
	if u.hidden:
		_step_burrow(u, h, dt)
		return true
	u.heavy_cd -= dt
	if u.heavy_cd > 0.0 or u.windup >= 0.0 or u.kb > 0.0:
		return false
	var dist := 1e9
	if tgt != null: dist = absf(tgt.x - u.x) - tgt.contact
	var base_x: float = (enemy_base.x - BASE_HALF) if u.side == SIDE_PLAYER else (player_base.x + BASE_HALF)
	dist = minf(dist, (base_x - u.x) * u.side)
	match kind:
		"vent":
			if not engaged and not bool(h.get("always", false)): return false
		"charge", "lob":
			if dist > float(h.get("trigger", 120.0)): return false
		"burrow":
			if dist > float(h.get("trigger", 180.0)) or dist < 40.0: return false
			u.hidden = true
			u.burrow_t = 0.0
			u.state = S_WALK
			_fx("burrow_dive", u.x, 0.0, 0.4, 0.0)
			events.append(["burrow", {"unit": u.id, "uid": u.uid, "x": u.x}])
			return true
		_:
			if not engaged: return false
	if danger_gap > 0.0 and u.side == SIDE_ENEMY and kind != "vent":
		if t < _danger_free_at: return false      # another zone is announced or just hit: act normally until the lane is calm
		_claim_danger(h, kind)
	_begin_heavy(u, h, kind)
	return true

## Round key `danger_gap`: the announcing unit books the lane until its zone has hit plus `danger_gap` s, so the
## player always gets that long to walk back in before the next zone is announced.
func _claim_danger(h: Dictionary, kind: String) -> void:
	var busy := float(h.get("windup", 1.2))
	if kind == "lob": busy += float(h.get("delay", 1.2))
	_danger_free_at = t + busy + danger_gap

func _begin_heavy(u: Unit, h: Dictionary, kind: String) -> void:
	u.heavy_t = float(h.get("windup", 1.2))
	u.heavy_acc = 0.0
	u.heavy_x = u.x
	u.heavy_r = 0.0
	match kind:
		"slam":
			u.heavy_x = u.x + u.side * float(h.get("offset", 0.0))
			u.heavy_r = float(h.get("radius", 40.0))
		"burrow":
			u.heavy_r = float(h.get("radius", 30.0))
		"charge":
			# the path stops short of the opposing base wall
			var wall: float = (enemy_base.x - BASE_HALF) if u.side == SIDE_PLAYER else (player_base.x + BASE_HALF)
			var far: float = u.x + u.side * float(h.get("dist", 150.0))
			if (far - wall) * u.side > 0.0: far = wall
			u.heavy_x = (u.x + far) * 0.5
			u.heavy_r = absf(far - u.x) * 0.5
	u.state = S_IDLE
	u.anim_t = 0.0
	if u.heavy_r > 0.0:
		_fx("telegraph", u.heavy_x, 0.0, u.heavy_t, u.heavy_r, u.uid, kind)
	events.append(["heavy", {"unit": u.id, "uid": u.uid, "kind": kind, "x": u.heavy_x, "r": u.heavy_r, "windup": u.heavy_t, "boss": u.is_boss}])

## End of prepare. charge starts its dash (the hit lands when it arrives); the other kinds resolve at once.
func _fire_heavy(u: Unit, h: Dictionary) -> void:
	if str(h.get("kind", "slam")) != "charge":
		_resolve_heavy(u, h)
		return
	var lo := u.heavy_x - u.heavy_r
	var hi := u.heavy_x + u.heavy_r
	var best: Unit = null
	var best_d := 1e9
	var foes: Array[Unit] = players if u.side == SIDE_ENEMY else enemies
	for e in foes:
		if e.dying or e.hidden or e.x < lo or e.x > hi: continue
		var d := absf(e.x - u.x)
		if d < best_d:
			best_d = d
			best = e
	if u.side == SIDE_ENEMY and hero_respawn <= 0.0 and not hero.dying and hero.x >= lo and hero.x <= hi and absf(hero.x - u.x) < best_d:
		best = hero
	u.w_target = best
	u.fire_x0 = u.x
	u.fire_x1 = (best.x - u.side * (best.contact + u.contact)) if best != null else (u.heavy_x + u.side * u.heavy_r)
	if (u.fire_x1 - u.x) * u.side < 0.0: u.fire_x1 = u.x
	u.fire_dur = maxf(0.06, absf(u.fire_x1 - u.x) / maxf(60.0, float(h.get("dash_speed", 480.0))))
	u.fire_t = u.fire_dur
	u.state = S_ATTACK
	u.anim_t = 0.0
	events.append(["heavy_dash", {"unit": u.id, "uid": u.uid, "x": u.x, "to": u.fire_x1, "boss": u.is_boss}])

func _resolve_heavy(u: Unit, h: Dictionary) -> void:
	var kind := str(h.get("kind", "slam"))
	var power := u.atk * u.buff_mul * float(h.get("power", 3.0))
	var kb := float(h.get("knockback", 0.0))
	var hit_x := u.heavy_x
	match kind:
		"slam", "burrow":
			u.hidden = false
			_area_damage_side(-u.side, u.heavy_x, u.heavy_r, power, kb, null)
			var bx: float = (player_base.x + BASE_HALF) if u.side == SIDE_ENEMY else (enemy_base.x - BASE_HALF)
			if absf(bx - u.heavy_x) <= u.heavy_r:
				_damage_base(-u.side, power * float(h.get("structure_mult", 1.0)))
			_fx("explosion", u.heavy_x, -6.0, 0.4, u.heavy_r)
		"charge":
			hit_x = u.x
			var tgt := u.w_target
			if tgt != null and not tgt.dying and tgt.alive and absf(tgt.x - u.x) <= tgt.contact + u.contact + 16.0:
				_damage(tgt, power, kb)
				_fx("hit_spark", tgt.x, -12.0, 0.25, 0.0)
			elif tgt == null:
				var wall: float = (player_base.x + BASE_HALF) if u.side == SIDE_ENEMY else (enemy_base.x - BASE_HALF)
				if absf(wall - u.x) <= 2.0:
					_damage_base(-u.side, power * float(h.get("structure_mult", 1.0)))
			u.w_target = null
		"lob":
			var tx: float = u.x + u.side * float(h.get("trigger", 120.0)) * 0.6
			var foe := _find_target(u)
			if foe != null and absf(foe.x - u.x) <= float(h.get("trigger", 120.0)) * 1.3: tx = foe.x
			var delay := float(h.get("delay", 1.2))
			var r := float(h.get("radius", 40.0))
			delayed.append({"at": t + delay, "x": tx, "radius": r, "power": power, "kb": kb, "fx": "spore_burst", "side": u.side,
				"struct": float(h.get("structure_mult", 1.0))})
			_fx("telegraph", tx, 0.0, delay, r, 0, "lob")
			hit_x = tx
	u.state = S_ATTACK
	u.anim_t = 0.0
	u.heavy_cd = float(h.get("interval", 8.0))
	u.recover_t = float(h.get("recover", 2.0))
	u.exposed_t = u.recover_t
	u.exposed_mul = float(h.get("exposed_mult", 1.5))
	u.atk_cd = maxf(u.atk_cd, u.recover_t)
	events.append(["heavy_hit", {"unit": u.id, "uid": u.uid, "kind": kind, "x": hit_x, "recover": u.recover_t, "boss": u.is_boss}])
	_next_ability(u)

## Units with a list of abilities take the next one for their following cycle.
func _next_ability(u: Unit) -> void:
	var raw = u.def.get("heavy")
	if raw is Array and raw.size() > 1:
		u.ab_i = (u.ab_i + 1) % raw.size()
		u.ab = raw[u.ab_i]
		u.heavy_cd = float(u.ab.get("interval", 8.0))

## Under ground: runs past the opposing front (or for burrow_max s), then announces where it comes up.
func _step_burrow(u: Unit, h: Dictionary, dt: float) -> void:
	u.burrow_t += dt
	var foes: Array[Unit] = players if u.side == SIDE_ENEMY else enemies
	var found := false
	var front := 0.0
	for e in foes:
		if e.dying or e.hidden: continue
		if not found or (e.x - front) * u.side < 0.0:
			front = e.x
			found = true
	if u.side == SIDE_ENEMY and hero_respawn <= 0.0 and not hero.dying and (not found or hero.x > front):
		front = hero.x
		found = true
	var home: float = (player_base.x + BASE_HALF + 34.0) if u.side == SIDE_ENEMY else (enemy_base.x - BASE_HALF - 34.0)
	var dest: float = home if not found else front + u.side * float(h.get("past", 50.0))
	if (dest - home) * u.side > 0.0: dest = home
	var arrived: bool = (dest - u.x) * u.side <= 0.0
	if not arrived and u.burrow_t < float(h.get("burrow_max", 7.0)):
		u.x += u.side * float(h.get("burrow_speed", 80.0)) * dt
		u.state = S_WALK
		return
	if danger_gap > 0.0 and u.side == SIDE_ENEMY:
		if t < _danger_free_at: return             # waits under ground until the lane is calm
		_claim_danger(h, "burrow")
	_begin_heavy(u, h, "burrow")

## Drops an announcement that will not happen (unit died, its link was cut, or it was interrupted): removes the marker.
func _cancel_heavy(u: Unit) -> void:
	if u.heavy_t < 0.0:
		return
	u.heavy_t = -1.0
	if u.heavy_r > 0.0:
		for f in fxs:
			if f.alive and f.kind == "telegraph" and f.warning_owner == u.uid:
				f.alive = false

## Called for damage taken while preparing: interrupt_damage in total calls the action off and leaves the unit open.
func _interrupt_heavy(u: Unit, dmg: float) -> void:
	var need := float(u.ab.get("interrupt_damage", 0.0))
	if need <= 0.0: return
	u.heavy_acc += dmg
	if u.heavy_acc < need: return
	_cancel_heavy(u)
	u.hidden = false
	u.heavy_cd = float(u.ab.get("interval", 8.0))
	u.recover_t = float(u.ab.get("interrupt_recover", u.ab.get("recover", 2.0)))
	u.exposed_t = u.recover_t
	u.exposed_mul = float(u.ab.get("exposed_mult", 1.5))
	u.atk_cd = maxf(u.atk_cd, u.recover_t)
	events.append(["heavy_cancel", {"unit": u.id, "uid": u.uid, "x": u.x, "boss": u.is_boss}])

## Unit key `shell`: {closed_mult, pry_knockback, pry_open}. While the unit is not exposed, damage is x closed_mult.
## A hit that carries at least pry_knockback (hero skills) forces it open for pry_open s. Bosses cannot be pried.
func _pry_shell(u: Unit) -> void:
	_cancel_heavy(u)
	var open_s := float(u.def.shell.get("pry_open", 1.5))
	u.recover_t = maxf(u.recover_t, open_s)
	u.exposed_t = maxf(u.exposed_t, open_s)
	u.exposed_mul = maxf(u.exposed_mul, float(u.ab.get("exposed_mult", 1.5)))
	u.atk_cd = maxf(u.atk_cd, open_s)
	events.append(["shell_pry", {"unit": u.id, "uid": u.uid, "x": u.x}])

## Unit key `hold_behind` (px): the unit does not walk closer than this to its own side's front unit (a unit
## without the key). With nobody in front of it, it walks on like any other unit.
func _held_back(u: Unit) -> bool:
	var hb := float(u.def.get("hold_behind", 0.0))
	if hb <= 0.0:
		return false
	var mates: Array[Unit] = enemies if u.side == SIDE_ENEMY else players
	var found := false
	var front := 0.0
	for m in mates:
		if m.dying or m == u or float(m.def.get("hold_behind", 0.0)) > 0.0: continue
		if not found or (m.x - front) * u.side > 0.0:
			front = m.x
			found = true
	return found and (front - u.x) * u.side < hb

## Unit key `link`: {radius, damage_taken, max_links, prefer_boss, break_stagger, break_exposed, break_exposed_s}.
## A living source protects its `max_links` nearest side mates within `radius` (bosses first with prefer_boss):
## they take damage x damage_taken. When the source dies, each of them is staggered for break_stagger s, takes
## damage x break_exposed for break_exposed_s s, and an announced heavy attack is called off. Enemy side only.
func _step_links() -> void:
	if _link_sources <= 0 and not _links_dirty:
		return
	_links_dirty = false
	for e in enemies:
		e.guard_mul = 1.0
		e.link_src = 0
	for s in enemies:
		if _link_sources <= 0: break
		if s.dying or not s.def.has("link"): continue
		var lk: Dictionary = s.def.link
		var radius := float(lk.get("radius", 100.0))
		var mul := float(lk.get("damage_taken", 0.5))
		var prefer_boss := bool(lk.get("prefer_boss", false))
		for n in int(lk.get("max_links", 3)):
			var best: Unit = null
			var best_d := 1e9
			for e in enemies:
				if e.dying or e.hidden or e.link_src != 0 or e.def.has("link"): continue
				var d := absf(e.x - s.x)
				if d > radius: continue
				if prefer_boss and e.is_boss: d -= 10000.0
				if d < best_d:
					best_d = d
					best = e
			if best == null: break
			best.guard_mul = float(best.def.get("link_taken", mul))    # a unit may set its own protected factor (the core)
			best.link_src = s.uid
	# Unit key `link_break` {stagger, exposed, exposed_s, summon_hold}: when the LAST strand to such a unit is cut it
	# stops (no move, no attack) for `stagger` s, takes damage x `exposed` for `exposed_s` s and calls nothing for
	# `summon_hold` s. While another source still holds it, a cut only gives the source's own short break values.
	for e in enemies:
		if not e.link_lost: continue
		e.link_lost = false
		var lb = e.def.get("link_break")
		if e.dying or e.link_src != 0 or not (lb is Dictionary): continue
		var open_s := float(lb.get("exposed_s", 4.0))
		_cancel_heavy(e)
		e.heavy_cd = maxf(e.heavy_cd, open_s)
		e.recover_t = maxf(e.recover_t, float(lb.get("stagger", 2.0)))
		e.atk_cd = maxf(e.atk_cd, e.recover_t)
		e.exposed_mul = maxf(e.exposed_mul, float(lb.get("exposed", 1.5)))
		e.exposed_t = maxf(e.exposed_t, open_s)
		if not e.sm.is_empty() and lb.has("summon_hold"):      # the next call comes summon_hold s after the cut
			e.summon_t = float(e.sm.get("interval", 12.0)) - float(lb.summon_hold)
		_fx("link_break", e.x, -24.0, 0.6, 0.0)
		events.append(["core_exposed", {"x": e.x, "uid": e.uid, "s": open_s, "boss": e.is_boss}])

func _break_links(src: Unit) -> void:
	var lk: Dictionary = src.def.link
	var stagger := float(lk.get("break_stagger", 1.0))
	var n := 0
	for e in enemies:
		if e.link_src != src.uid or e.dying: continue
		n += 1
		e.link_src = 0
		e.guard_mul = 1.0
		e.link_lost = true
		e.atk_cd = maxf(e.atk_cd, stagger)
		e.exposed_mul = maxf(e.exposed_mul, float(lk.get("break_exposed", 1.3)))
		e.exposed_t = maxf(e.exposed_t, float(lk.get("break_exposed_s", 3.0)))
		if e.heavy_t >= 0.0:
			_cancel_heavy(e)
			e.heavy_cd = float(e.ab.get("interval", 8.0))
			e.recover_t = stagger
		_fx("link_break", e.x, -16.0, 0.5, 0.0)
	_links_dirty = true
	events.append(["link_break", {"x": src.x, "freed": n}])

## Boss key `phases`: [{below, heavy?, summon?, stagger?}] in falling `below` order. When hp / hp_max drops under the
## next entry's `below`, an announced attack is called off, the boss stops for `stagger` s, and from then on uses that
## entry's `heavy` and `summon` (`summon: {}` = calls nothing any more). Event "boss_phase" {phase: 2, 3, ...}.
func _step_boss_phase(u: Unit) -> void:
	var ph = u.def.get("phases")
	if not (ph is Array) or u.phase >= ph.size() or u.fire_t >= 0.0:
		return
	var p: Dictionary = ph[u.phase]
	if u.hp / u.hp_max >= float(p.get("below", 0.0)):
		return
	u.phase += 1
	_cancel_heavy(u)
	if p.get("heavy") is Dictionary:
		u.ab = p.heavy
		u.heavy_cd = float(u.ab.get("first", float(u.ab.get("interval", 8.0)) * 0.5))
	if p.get("summon") is Dictionary:
		u.sm = p.summon
		u.summon_t = float(u.sm.get("interval", 12.0)) - float(u.sm.get("first", u.sm.get("interval", 12.0)))
	var st := float(p.get("stagger", 0.0))
	if st > 0.0:
		u.recover_t = maxf(u.recover_t, st)
		u.atk_cd = maxf(u.atk_cd, st)
		u.heavy_cd = maxf(u.heavy_cd, st)
	events.append(["boss_phase", {"phase": u.phase + 1, "x": u.x, "uid": u.uid, "unit": u.id}])

func _step_boss_summon(u: Unit, dt: float) -> void:
	var sm: Dictionary = u.sm
	if sm.is_empty():
		return
	u.summon_t += dt
	if u.summon_t < float(sm.get("interval", 12.0)):
		return
	u.summon_t = 0.0
	var uid := str(sm.get("unit", ""))
	var alive := 0
	for e in enemies:
		if e.id == uid and not e.dying: alive += 1
	for i in int(sm.get("count", 1)):
		if alive < int(sm.get("max_alive", 9)) and army_count(SIDE_ENEMY) < caps.enemy and content.units.has(uid):
			var s := _spawn_enemy(uid)
			s.x = u.x + 10.0
			alive += 1

func _attack_logic(u: Unit, tgt: Unit, in_reach: bool, hit_base: bool, dt: float) -> void:
	u.atk_cd -= dt * u.aura_mul * u.cream_mul   # Rally changes damage/movement; the hero aura and cake cream change attack speed.
	if u.windup >= 0.0:
		u.windup -= dt
		if u.windup < 0.0:
			_resolve_attack(u)
		return
	if (in_reach or hit_base) and u.atk_cd <= 0.0:
		var iv := float(u.def.atk_interval)
		u.atk_cd = iv
		u.windup = clampf(iv * 0.35, 0.08, 0.4)
		u.w_target = tgt if in_reach else null
		u.w_base = hit_base
		u.state = S_ATTACK
		u.anim_t = 0.0
	elif in_reach or hit_base:
		if u.state == S_WALK: u.state = S_IDLE

func _struct_mult(u: Unit) -> float:
	if u.def.has("structure_mult"):
		return float(u.def.structure_mult)
	return 2.0 if str(u.def.get("attack_type", "")) == "siege" else 1.0

func _resolve_attack(u: Unit) -> void:
	if u.dying:
		return
	var atk := u.atk * u.buff_mul
	var kind := str(u.def.get("attack_type", "melee"))
	var ranged := kind == "ranged" or kind == "siege"
	var tgt := u.w_target
	if tgt != null and (tgt.dying or not tgt.alive):
		tgt = null
	if tgt == null and not u.w_base:
		return
	var kb := float(u.def.get("knockback", 0.0))
	if ranged:
		var p := _new_projectile()
		if p == null:
			return
		var siege := kind == "siege"
		p.side = u.side
		p.kind = str(u.def.get("projectile", "")) if str(u.def.get("projectile", "")) != "" else ("rock" if siege else "arrow")
		p.x0 = u.x + u.side * 6.0
		p.x = p.x0
		p.x1 = tgt.x if tgt else (enemy_base.x if u.side == SIDE_PLAYER else player_base.x)
		p.y = -14.0
		var dist := absf(p.x1 - p.x0)
		p.dur = clampf(dist / (180.0 if siege else 300.0), 0.12, 1.2)
		p.arc = clampf(dist * (0.35 if siege else 0.12), 4.0, 70.0)
		p.t = 0.0
		p.dmg = atk
		p.splash = float(u.def.get("splash", 0.0))
		p.struct_mult = _struct_mult(u)
		p.knockback = kb
		p.slow_mul = float(u.def.get("atk_slow_mul", 1.0))
		p.slow_s = float(u.def.get("atk_slow_s", 0.0))
		p.homing = not siege
		p.target = tgt
		p.hit_base = tgt == null
		_cue(&"shoot", p.kind, {"projectile": p.kind, "x": u.x, "pitch":float(u.def.get("audio_pitch",1.0))})
	else:
		if tgt:
			_damage(tgt, atk, kb)
			if float(u.def.get("splash", 0.0)) > 0.0:
				_area_damage_side(-u.side, tgt.x, float(u.def.get("splash", 0.0)), atk, kb, tgt)
			_fx("hit_spark", tgt.x, -12.0, 0.25, 0.0)
			var ts := "player" if tgt.side == SIDE_PLAYER else "enemy"
			_cue(&"hit", "melee:" + ts, {"kind": "melee", "x": tgt.x, "target_side": ts,"pitch":float(u.def.get("audio_pitch",1.0))})
		elif u.w_base:
			_damage_base(-u.side, atk * _struct_mult(u))
			if float(u.def.get("splash", 0.0)) > 0.0:
				var bx: float = enemy_base.x - BASE_HALF if u.side == SIDE_PLAYER else player_base.x + BASE_HALF
				_area_damage_side(-u.side, bx, float(u.def.get("splash", 0.0)), atk, kb, null)
			if u.side == SIDE_ENEMY and not u.is_boss:
				# D29 option A (push-back) and C (stagger) on enemy melee hits against the player base
				if base_defense.push_px > 0.0: u.kb = maxf(u.kb, base_defense.push_px)
				if base_defense.stagger_s > 0.0: u.atk_cd += base_defense.stagger_s
	if bool(u.def.get("self_destruct", false)):
		_fx("explosion", u.x, -6.0, 0.4, float(u.def.get("splash", 0.0)))
		u.hp = 0.0
		_kill(u, false)

## Nearest living opponent ahead of u (may overlap up to 10 px behind). Uses the per-step sorted lanes:
## binary search for the first foe with (x - u.x) * side >= -10, i.e. the minimum of that distance.
func _find_target(u: Unit) -> Unit:
	if _linear_targets:
		return _find_target_linear(u)
	var best: Unit = null
	var best_d := 1e9
	if u.side == SIDE_PLAYER:
		# foes = enemies sorted by x ascending; want min d = e.x - u.x with d >= -10.
		# Units move within a step, so the lane is only nearly sorted: binary search, then check a few neighbours.
		var lane := _lane_e
		var lo := 0
		var hi := lane.size()
		var limit := u.x - 10.0
		while lo < hi:
			var mid := (lo + hi) >> 1
			if lane[mid].x < limit: lo = mid + 1
			else: hi = mid
		var i := maxi(0, lo - 3)
		var found := 0
		while i < lane.size():
			var e: Unit = lane[i]
			i += 1
			if e.dying: continue
			var d := e.x - u.x
			if d < -10.0: continue
			if found >= 4 and d > best_d: break   # past the nearest group (ties are scanned completely)
			found += 1
			# tie-break identical to the linear scan: equal distance -> earliest spawned (lowest uid = array order)
			if d < best_d or (d == best_d and e.uid < best.uid):
				best_d = d
				best = e
	else:
		# foes = players sorted ascending; want min d = u.x - e.x with d >= -10.
		var lane2 := _lane_p
		var lo2 := 0
		var hi2 := lane2.size()
		var limit2 := u.x + 10.0
		while lo2 < hi2:
			var mid2 := (lo2 + hi2) >> 1
			if lane2[mid2].x <= limit2: lo2 = mid2 + 1
			else: hi2 = mid2
		var j := mini(lane2.size() - 1, lo2 + 2)
		var found2 := 0
		while j >= 0:
			var e2: Unit = lane2[j]
			j -= 1
			if e2.dying: continue
			var d2 := u.x - e2.x
			if d2 < -10.0: continue
			if found2 >= 4 and d2 > best_d: break
			found2 += 1
			if d2 < best_d or (d2 == best_d and e2.uid < best.uid):
				best_d = d2
				best = e2
		if hero_respawn <= 0.0 and not hero.dying:
			var d := (hero.x - u.x) * u.side
			if d >= -10.0 and d < best_d:
				best = hero
	return best

## Reference O(n) implementation kept for the selftest equivalence check.
func _find_target_linear(u: Unit) -> Unit:
	var best: Unit = null
	var best_d := 1e9
	var foes: Array[Unit] = enemies if u.side == SIDE_PLAYER else players
	for e in foes:
		if e.dying or e.hidden: continue
		var d := (e.x - u.x) * u.side
		if d >= -10.0 and d < best_d:
			best_d = d
			best = e
	if u.side == SIDE_ENEMY and hero_respawn <= 0.0 and not hero.dying:
		var d := (hero.x - u.x) * u.side
		if d >= -10.0 and d < best_d:
			best = hero
	return best

func _frontmost_enemy_x() -> float:
	var x: float = enemy_base.x
	for e in enemies:
		if not e.dying and not e.hidden and e.x < x: x = e.x
	return x

## Player-sourced area damage at x (skills): hits enemies and the enemy base if in radius.
func _area_damage(x: float, radius: float, power: float, kb: float, struct_mult: float) -> void:
	_area_damage_side(SIDE_ENEMY, x, radius, power, kb, null)
	var ebx: float = enemy_base.x - BASE_HALF
	if absf(ebx - x) <= radius:
		_damage_base(SIDE_ENEMY, power * struct_mult)

## Damage all units of `victim_side` within radius of x, excluding `skip`.
## Cake cream: every living unit of victim_side within radius gets cream on its head for `secs`; its attacks recharge
## at `mul` (bosses half as much, like frost). A new hit refreshes the time and keeps the stronger slow.
func _cream_slow(victim_side: int, x: float, radius: float, mul: float, secs: float) -> void:
	var arr: Array[Unit] = enemies if victim_side == SIDE_ENEMY else players
	var hit: Array[Unit] = []
	for e in arr:
		if not e.dying and absf(e.x - x) <= radius: hit.append(e)
	if victim_side == SIDE_PLAYER and hero_respawn <= 0.0 and absf(hero.x - x) <= radius: hit.append(hero)
	for e in hit:
		var m := 1.0 - (1.0 - mul) * (0.5 if e.is_boss else 1.0)
		e.cream_mul = minf(e.cream_mul, m)
		e.cream_t = maxf(e.cream_t, secs)

func _area_damage_side(victim_side: int, x: float, radius: float, power: float, kb: float, skip: Unit) -> void:
	var arr: Array[Unit] = enemies if victim_side == SIDE_ENEMY else players
	for e in arr:
		if e != skip and not e.dying and absf(e.x - x) <= radius:
			_damage(e, power, kb)
	if victim_side == SIDE_PLAYER and hero_respawn <= 0.0 and hero != skip and absf(hero.x - x) <= radius:
		_damage(hero, power, kb)

func _damage(target: Unit, amount: float, kb: float) -> void:
	if target.dying or target.invuln > 0.0: return
	var dmg := maxf(1.0, amount - float(target.def.get("armor", 0.0)))
	if target.guard_mul != 1.0 or target.exposed_mul != 1.0:
		dmg = maxf(1.0, dmg * target.guard_mul * target.exposed_mul)   # link protection / exposed window
	if target.shell_mul != 1.0 and target.exposed_t <= 0.0:
		dmg = maxf(1.0, dmg * target.shell_mul)                         # closed shell
		if kb > 0.0 and not target.is_boss and kb >= float(target.def.shell.get("pry_knockback", 1e9)):
			_pry_shell(target)
	if target.heavy_t >= 0.0: _interrupt_heavy(target, dmg)
	if target.shield > 0.0:
		var soak := minf(target.shield, dmg)
		target.shield -= soak
		dmg -= soak
		if dmg <= 0.0:
			target.flash = 0.06
			_text(target.x, -28.0, "0", &"shield", target.uid, 0, target.anim_set)
			return
	target.hp -= dmg
	target.flash = 0.12
	if kb > 0.0 and not target.is_boss:
		target.kb = maxf(target.kb, kb)
	_text(target.x, -28.0, str(int(dmg)), &"dmg", target.uid, int(dmg), target.anim_set)
	if target.hp <= 0.0:
		_kill(target, true)

func _kill(u: Unit, rewarded: bool) -> void:
	if u.dying: return
	u.dying = true
	u.state = S_DYING
	u.anim_t = 0.0
	u.dead_t = 0.7
	u.windup = -1.0
	_cancel_heavy(u)
	if u.side == SIDE_ENEMY and u.def.has("link"):
		_link_sources -= 1
		_break_links(u)
	if u.is_hero:
		hero_dir = 0          # a move held when the hero fell does not resume by itself at the revive
		hero_deaths += 1
		stats.hero_deaths += 1
		var rs := float(hero_def.respawn) + float(hero_def.get("respawn_per_death", 0.0)) * (hero_deaths - 1)
		hero_respawn = minf(rs, float(hero_def.get("respawn_max", 999.0)))
		events.append(["hero_dead", {"respawn": hero_respawn}])
		return
	if u.side == SIDE_ENEMY and u.wave_tag > 0:
		var wi := u.wave_tag - 1
		_wave_alive[wi] -= 1
		if _wave_alive[wi] <= 0 and _wave_pending[wi] <= 0 and not _wave_cleared[wi] and not ended:
			_wave_cleared[wi] = true
			events.append(["wave_cleared", {"index": u.wave_tag, "t": t}])
	if u.side == SIDE_ENEMY and rewarded:
		kills += 1
		kill_coins += int(u.def.get("kill_coins", 0))
		var b := int(u.def.get("bounty", 0))
		gold = minf(gold_max, gold + b)
		mana = minf(mana_max, mana + float(econ.get("mana_on_kill", 2)))
		if b > 0: _text(u.x, -40.0, "+%d" % b, &"gold")
	_cue(&"death", "player" if u.side == SIDE_PLAYER else "enemy", {"side": "player" if u.side == SIDE_PLAYER else "enemy", "x": u.x, "boss": u.is_boss})

## Coalesce audio cues: at most one per cue+kind per step (05-audio A3 performance note).
func _cue(cue: StringName, kind: String, params: Dictionary) -> void:
	var key := str(cue) + ":" + kind
	if not cues.has(key):
		cues[key] = [cue, params]

## D29 option B: at most dps_cap damage on the player base in any 1 s window. Returns the applied amount.
func _cap_player_base_damage(amount: float) -> float:
	var i := 0
	while i < _pbase_hits.size() and _pbase_hits[i] <= t - 1.0:
		i += 2
	if i > 0:
		_pbase_hits = _pbase_hits.slice(i)
	var used := 0.0
	for j in range(1, _pbase_hits.size(), 2):
		used += _pbase_hits[j]
	var applied := clampf(base_defense.dps_cap - used, 0.0, amount)
	base_dmg_capped += amount - applied
	if applied > 0.0:
		_pbase_hits.append(t)
		_pbase_hits.append(applied)
	return applied

func _damage_base(side: int, amount: float) -> void:
	var b: Dictionary = player_base if side == SIDE_PLAYER else enemy_base
	if b.hp <= 0.0: return
	if side == SIDE_PLAYER and base_defense.dps_cap > 0.0:
		amount = _cap_player_base_damage(amount)
		if amount <= 0.0:
			return   # fully absorbed this second: no HP change, no text, no shake
	b.hp = maxf(0.0, b.hp - amount)
	b.flash = 0.12
	if side == SIDE_PLAYER:
		events.append(["shake", {"amp": 2.0 if amount < 40.0 else 4.0}])
	_cue(&"base_hit", "player" if side == SIDE_PLAYER else "enemy", {"side": "player" if side == SIDE_PLAYER else "enemy"})
	_text(b.x, -88.0, str(int(amount)), &"dmg", -100 if side == SIDE_ENEMY else -101, int(amount))
	if b.hp <= 0.0:
		if side == SIDE_ENEMY: _base_dead_enemy = true
		else: _base_dead_player = true
		if not _in_step:
			_end(_base_dead_enemy)   # damage applied outside step() (commands/tests) resolves immediately

## Each base has a defensive tower (economy.base_tower). Enemy tower atk x round.enemy_tower_atk_mult.
func _step_towers(dt: float) -> void:
	if tower.is_empty():
		return
	for side: int in SIDES:
		var b: Dictionary = player_base if side == SIDE_PLAYER else enemy_base
		b.tower_cd = float(b.tower_cd) - dt
		if b.tower_cd > 0.0: continue
		var rng_px := float(tower.get("range", 130.0))
		var best: Unit = null
		var best_d := 1e9
		var foes: Array[Unit] = enemies if side == SIDE_PLAYER else players
		for e in foes:
			if e.dying or e.hidden: continue
			var d := absf(e.x - float(b.x))
			if d <= rng_px and d < best_d:
				best_d = d
				best = e
		if side == SIDE_ENEMY and best == null and hero_respawn <= 0.0 and absf(hero.x - float(b.x)) <= rng_px:
			best = hero
		if best == null: continue
		b.tower_cd = float(tower.get("atk_interval", 1.5))
		var p := _new_projectile()
		if p == null: continue
		p.side = side
		p.kind = "tower_bolt"
		p.x0 = float(b.x)
		p.x = p.x0
		p.x1 = best.x
		p.y = -60.0
		p.dur = clampf(best_d / 320.0, 0.1, 0.6)
		p.arc = 6.0
		p.t = 0.0
		p.dmg = float(tower.get("atk", 15.0)) * (enemy_tower_mult if side == SIDE_ENEMY else 1.0)
		p.splash = base_defense.tower_splash if side == SIDE_PLAYER else 0.0   # D29 option D, player tower only
		p.struct_mult = 1.0
		p.knockback = 0.0
		p.slow_mul = 1.0
		p.slow_s = 0.0
		p.homing = true
		p.target = best
		p.hit_base = false

func _step_projectiles(dt: float) -> void:
	var n := 0
	for p in projectiles:
		if not p.alive: continue
		n += 1
		if p.homing and p.target != null and not p.target.dying:
			p.x1 = p.target.x
		p.t += dt
		var k := minf(1.0, p.t / p.dur)
		p.x = lerpf(p.x0, p.x1, k)
		if k >= 1.0:
			p.alive = false
			if p.hit_base:
				_damage_base(-p.side, p.dmg * p.struct_mult)
				if p.slow_s > 0.0: _cream_slow(-p.side, p.x1, maxf(p.splash, 12.0), p.slow_mul, p.slow_s)
				if p.splash > 0.0:
					_area_damage_side(-p.side, p.x1, p.splash, p.dmg, p.knockback, null)
					_fx("cream_splat" if p.kind == "cream" else "explosion", p.x1, -6.0, 0.35, p.splash)
			else:
				var hit_any := false
				if p.target != null and not p.target.dying and (p.homing or absf(p.target.x - p.x1) <= 12.0 + p.splash):
					_damage(p.target, p.dmg, p.knockback)
					hit_any = true
				if p.slow_s > 0.0: _cream_slow(-p.side, p.x1, maxf(p.splash, 12.0), p.slow_mul, p.slow_s)
				if p.splash > 0.0:
					_area_damage_side(-p.side, p.x1, p.splash, p.dmg, p.knockback, p.target if hit_any else null)
					_fx("cream_splat" if p.kind == "cream" else "explosion", p.x1, -6.0, 0.35, p.splash)
				elif hit_any:
					_fx("hit_spark", p.x1, -12.0, 0.2, 0.0)
				if hit_any and p.kind != "tower_bolt":
					var pk := "siege" if not p.homing else "ranged"
					var pts := "enemy" if p.side == SIDE_PLAYER else "player"   # victim side
					_cue(&"hit", pk + ":" + pts, {"kind": pk, "x": p.x1, "target_side": pts})
	stats.max_projectiles = maxi(stats.max_projectiles, n)

func _step_fx(dt: float) -> void:
	for f in fxs:
		if f.alive:
			f.t += dt
			if f.t >= f.dur: f.alive = false
	for tx in texts:
		if tx.alive:
			tx.t += dt
			tx.y -= 18.0 * dt
			tx.rise += 18.0 * dt
			if tx.t >= 0.8: tx.alive = false

func _reap() -> void:
	var reaped := _reap_side(players) + _reap_side(enemies)
	if reaped == 0:
		return
	for p in projectiles:
		if p.target != null and not p.target.alive:
			p.target = null
	for u in players:
		if u.w_target != null and not u.w_target.alive: u.w_target = null
	for u in enemies:
		if u.w_target != null and not u.w_target.alive: u.w_target = null
	if hero.w_target != null and not hero.w_target.alive: hero.w_target = null

func _reap_side(arr: Array[Unit]) -> int:
	var n := 0
	var i: int = arr.size() - 1
	while i >= 0:
		var u: Unit = arr[i]
		if u.dying and u.dead_t <= 0.0:
			u.alive = false
			u.w_target = null
			_unit_pool.append(u)
			arr.remove_at(i)
			n += 1
		i -= 1
	return n

func _end(player_won: bool) -> void:
	if ended: return
	ended = true
	won = player_won
	events.append(["ended", result()])

# ================= pooling helpers =================
func _new_unit(d: Dictionary, side: int, x: float) -> Unit:
	var u: Unit = _unit_pool.pop_back() if not _unit_pool.is_empty() else Unit.new()
	_uid += 1
	u.uid = _uid
	u.alive = true
	u.dying = false
	u.side = side
	u.id = str(d.id)
	u.def = d
	u.x = x
	u.lane_y = rng.randf_range(-6.0, 6.0)
	u.hp = float(d.hp)
	u.hp_max = u.hp
	u.atk = float(d.atk)
	u.atk_cd = 0.0
	u.windup = -1.0
	u.w_target = null
	u.w_base = false
	u.state = S_WALK
	u.anim_t = rng.randf() * 0.5
	u.dead_t = 0.0
	u.buff_t = 0.0
	u.buff_mul = 1.0
	u.shield = 0.0
	u.shield_t = 0.0
	u.aura_mul = 1.0
	u.cream_t = 0.0
	u.cream_mul = 1.0
	u.flash = 0.0
	u.kb = 0.0
	u.invuln = 0.0
	u.is_hero = false
	u.is_boss = bool(d.get("is_boss", false)) or (d.get("tags", []) as Array).has("boss")
	u.summon_t = 0.0
	u.in_lane = false
	u.wave_tag = 0
	var raw_ab = d.get("heavy")
	u.ab_i = 0
	u.ab = raw_ab if raw_ab is Dictionary else (raw_ab[0] if raw_ab is Array and not raw_ab.is_empty() else {})
	u.heavy_cd = float(u.ab.get("first", float(u.ab.get("interval", 8.0)) * 0.5)) if not u.ab.is_empty() else 0.0
	u.heavy_r = 0.0
	u.heavy_acc = 0.0
	u.fire_t = -1.0
	u.hidden = false
	u.burrow_t = 0.0
	u.shell_mul = float(d.shell.get("closed_mult", 1.0)) if d.get("shell") is Dictionary else 1.0
	u.heavy_t = -1.0
	u.heavy_x = 0.0
	u.recover_t = 0.0
	u.exposed_t = 0.0
	u.exposed_mul = 1.0
	u.guard_mul = 1.0
	u.link_src = 0
	u.link_lost = false
	u.phase = 0
	u.sm = d.summon if d.get("summon") is Dictionary else {}
	u.anim_set = str(d.get("anim_set", d.id))
	u.contact = 5.0 * float(d.get("size", 1.0))
	return u

func _new_projectile() -> Projectile:
	for p in projectiles:
		if not p.alive:
			p.alive = true
			return p
	if projectiles.size() >= caps.projectiles:
		return null
	var np := Projectile.new()
	np.alive = true
	projectiles.append(np)
	return np

func _fx(kind: String, x: float, y: float, dur: float, radius: float, warning_owner := 0, warning_shape := "") -> void:
	if kind == "explosion":
		_cue(&"explosion", "", {"x": x})
	var f: Fx = null
	for e in fxs:
		if not e.alive:
			f = e
			break
	if f == null and fxs.size() >= caps.fx and kind == "telegraph":
		# A danger marker is never dropped for lack of room: it takes the place of a cosmetic effect.
		for e in fxs:
			if e.kind != "telegraph":
				f = e
				break
	if f == null:
		if fxs.size() >= caps.fx: return
		f = Fx.new()
		fxs.append(f)
	f.alive = true
	f.kind = kind
	f.warning_owner = warning_owner
	f.warning_shape = warning_shape
	f.x = x
	f.y = y
	f.t = 0.0
	f.dur = dur
	f.radius = radius
	f.warning_track = 0
	if kind == "telegraph":
		var used := [false, false, false]
		for other in fxs:
			if other == f or not other.alive or other.kind != "telegraph" or other.warning_track >= used.size(): continue
			if absf(other.x - x) < other.radius + radius + 4.0:
				used[other.warning_track] = true
		var slot := used.find(false)
		f.warning_track = slot if slot >= 0 else used.size()

func _text(x: float, y: float, s: String, kind: StringName, uid := 0, value := 0, anchor_set := "") -> void:
	# QA-B012: repeated hits on the same target within 0.35 s merge into one rising number.
	if uid != 0:
		for e in texts:
			if e.alive and e.uid == uid and e.kind == kind and e.t < (0.24 if uid < 0 else 0.35):
				e.value += value
				e.text = str(e.value)
				# A fixed window from birth: repeated base hits must not restart the
				# rise/fade clock indefinitely or make a number jump backwards.
				return
	var tx: FText = null
	for e in texts:
		if not e.alive:
			tx = e
			break
	if tx == null:
		if texts.size() >= caps.text: return
		tx = FText.new()
		texts.append(tx)
	tx.alive = true
	_text_serial += 1
	tx.serial = _text_serial
	tx.x = x + _text_rng.randf_range(-4.0, 4.0)   # separate RNG: visual-only, must not shift gameplay randomness
	tx.y = y
	tx.t = 0.0
	tx.text = s
	tx.kind = kind
	tx.uid = uid
	tx.value = value
	tx.anchor_set = anchor_set
	tx.rise = 0.0

# ================= outputs =================
func current_wave() -> Dictionary:
	var idx := 0
	var next_in := -1.0
	var boss := false
	for i in wave_times.size():
		if wave_times[i] <= t:
			idx = i + 1
			boss = wave_boss[i]
		elif next_in < 0.0:
			next_in = wave_times[i] - t
	return {"index": idx, "total": waves_total, "next_in": maxf(next_in, 0.0), "boss": boss}

func snapshot() -> Dictionary:
	var cards := []
	for id in card_ids:
		var d: Dictionary = content.get_unit(id)
		cards.append({"id": id, "cost": int(d.cost), "cd": card_cd[id], "cd_total": float(d.cooldown),
			"ready": card_cd[id] <= 0.0 and gold >= float(d.cost) and army_count(SIDE_PLAYER) < caps.ally,
			"affordable": gold >= float(d.cost)})
	var sk := []
	for id in skill_ids:
		var s: Dictionary = content.skills[id]
		sk.append({"id": id, "mana": int(s.mana), "cd": skill_cd[id], "cd_total": float(s.cooldown),
			"ready": skill_cd[id] <= 0.0 and mana >= float(s.mana) and hero_respawn <= 0.0})
	return {
		"t": t, "gold": int(gold), "gold_max": int(gold_max), "income": income(),
		"workers": workers, "workers_max": workers_max, "worker_cost": worker_cost(),
		"mana": mana, "mana_max": mana_max, "cards": cards, "skills": sk,
		"hero": {"hp": maxf(hero.hp, 0.0), "hp_max": hero.hp_max, "alive": hero_respawn <= 0.0, "respawn": maxf(hero_respawn, 0.0), "x": hero.x},
		"player_base": {"hp": player_base.hp, "hp_max": player_base.hp_max},
		"enemy_base": {"hp": enemy_base.hp, "hp_max": enemy_base.hp_max},
		"wave": current_wave(),
		"army": {"player": army_count(SIDE_PLAYER), "enemy": army_count(SIDE_ENEMY), "cap": caps.ally, "enemy_cap": caps.enemy},
		"boss": _boss_info(),
		"speed": 1.0,
		"paused": paused,
	}

func _boss_info() -> Dictionary:
	for e in enemies:
		if e.is_boss and not e.dying:
			return {"alive": true, "hp": e.hp, "hp_max": e.hp_max, "id": e.id, "name_key": str(e.def.get("name_key", "")),
				"telegraph": e.heavy_t >= 0.0, "exposed": e.exposed_t > 0.0, "linked": e.link_src != 0, "phase": e.phase + 1, "phase_marks": e.def.get("phase_marks", [])}
	return {"alive": false}

func battle_info() -> Dictionary:
	var cards := []
	for id in card_ids:
		var d: Dictionary = content.get_unit(id)
		cards.append({"id": id, "name": d.name, "name_key": str(d.get("name_key", "")), "cost": int(d.cost),
			"cooldown": float(d.cooldown), "anim_set": str(d.anim_set), "icon": {"atlas": "ui_main", "frame": "card_" + id}})
	var sk := []
	for id in skill_ids:
		var s: Dictionary = content.skills[id]
		sk.append({"id": id, "name": s.name, "name_key": str(s.get("name_key", "")), "mana": int(s.mana),
			"cooldown": float(s.cooldown), "icon": {"atlas": "ui_main", "frame": "skill_" + id}})
	return {"round_id": str(round_def.id), "round_index": int(round_def.index), "round_name": str(round_def.name),
		"round_name_key": str(round_def.get("name_key", "")), "biome": str(round_def.biome), "cards": cards, "skills": sk,
		"hero": {"id": str(hero_def.id), "name": str(hero_def.name)}, "lane_length": L,
		"tutorial": round_def.get("tutorial", []), "boss_round": bool(round_def.get("boss_round", false))}

## Coins here are the in-battle portion; App adds first-clear / 3-star bonuses using Save.
func result() -> Dictionary:
	var stars := 0
	if won:
		stars = 1
		var st: Dictionary = round_def.stars
		if player_base.hp / player_base.hp_max >= float(st.get("base_hp_2", 0.5)): stars += 1
		if t <= float(st.get("time_3", 180.0)): stars += 1
	var loss_ratio := float(econ.get("loss_coin_ratio", 0.25))
	return {"round_id": str(round_def.id), "won": won, "stars": stars, "time": t, "kills": kills,
		"kill_coins": kill_coins, "coins": kill_coins if won else int(kill_coins * loss_ratio),
		"player_base_ratio": player_base.hp / player_base.hp_max,
		"first_clear": false, "next_round_id": "", "hero_deaths": hero_deaths, "hint": "" if won else loss_hint()}

## After a defeat: the ONE thing in this battle's own record that the player can change next time (text key
## hint.loss.<id>). Ordered from the most basic habit to the least; "upgrade" only when none of them applies.
func loss_hint() -> String:
	if int(stats.deployed) == 0: return "no_units"
	if float(stats.gold_capped_s) >= 12.0: return "flour_idle"
	if int(stats.workers_bought) == 0 and workers_max > int(econ.workers_start) and t >= 40.0: return "no_baker"
	if hero_deaths >= 2: return "hero_fell"
	if not skill_ids.is_empty() and (int(stats.skills_cast) == 0 or float(stats.mana_capped_s) >= 20.0): return "no_skill"
	return "upgrade"
