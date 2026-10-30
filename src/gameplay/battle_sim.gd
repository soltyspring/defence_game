extends RefCounted
## Deterministic 1-D lane battle simulation (no nodes, no autoloads) so it runs headless.
## Owner: 02-engine. Rendering lives in battle_view.gd; node wiring in battle.gd.
## Supported data keys: INTERFACES.md §2 + §2.7 (01 design extensions).

const PerfC := preload("res://src/core/perf.gd")

const SIDE_PLAYER := 1
const SIDE_ENEMY := -1
const BASE_INSET := 40.0
const BASE_HALF := 22.0
const TIME_LIMIT := 900.0
const KB_DECAY := 300.0
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
	var w_target: Unit = null
	var w_base := false
	var state := 0
	var anim_t := 0.0
	var dead_t := 0.0
	var buff_t := 0.0
	var buff_mul := 1.0
	var aura_mul := 1.0
	var flash := 0.0
	var kb := 0.0
	var invuln := 0.0
	var is_hero := false
	var is_boss := false
	var contact := 6.0
	var summon_t := 0.0

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

class Fx:
	var alive := false
	var kind := ""
	var x := 0.0
	var y := 0.0
	var t := 0.0
	var dur := 0.4
	var radius := 0.0

class FText:
	var alive := false
	var x := 0.0
	var y := 0.0
	var t := 0.0
	var text := ""
	var kind := &"dmg"

# ---- config ----
var content            # content.gd instance (autoload or standalone)
var round_def: Dictionary
var econ: Dictionary
var hero_def: Dictionary
var caps := {"ally": 30, "enemy": 40, "projectiles": 64, "fx": 32, "text": 24}
var upgrades: Dictionary = {}     # upgrade_id -> level (from Save)
var L := 1200.0
var rng := RandomNumberGenerator.new()
var gold_max := 999.0
var workers_max := 8
var enemy_hp_mult := 1.0
var enemy_atk_mult := 1.0
var tower: Dictionary = {}
var enemy_tower_mult := 1.0
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
var delayed: Array = []            # delayed skill impacts [{at, x, radius, power, kb, struct, fx}]
var _unit_pool: Array[Unit] = []
var _uid := 0
var spawn_queue: Array = []        # [{at, unit}] sorted by at
var waves_total := 0
var wave_times: Array[float] = []
var wave_boss: Array[bool] = []
var _wave_announced := 0
var ai_gold := 0.0
var ai_think := 2.0
var trickle: Dictionary = {}
var trickle_next := -1.0
var trickle_i := 0
var hp_triggers_fired: Dictionary = {}
var events: Array = []             # drained by battle.gd: [type:String, data:Dictionary]
var refused_spawns := 0
var stats := {"deployed": 0, "workers_bought": 0, "skills_cast": 0, "enemy_spawned": 0, "max_units": 0, "max_projectiles": 0, "hero_deaths": 0}

func setup(p_content, round_id: String, seed_value: int = 1, p_upgrades: Dictionary = {}) -> void:
	content = p_content
	upgrades = p_upgrades
	round_def = content.get_round(round_id)
	if round_def.is_empty():
		round_def = content.get_round(content.round_order[0])
	econ = content.economy
	hero_def = content.heroes.get(str(round_def.hero), content.heroes.values()[0])
	rng.seed = seed_value
	L = float(round_def.lane_length)
	_read_caps()
	gold_max = float(round_def.get("gold_max", econ.gold_max))
	workers_max = int(round_def.get("workers_max", econ.workers_max))
	var sc: Dictionary = round_def.get("enemy_scaling", {})
	enemy_hp_mult = float(sc.get("hp", 1.0))
	enemy_atk_mult = float(sc.get("atk", 1.0))
	tower = econ.get("base_tower", {})
	enemy_tower_mult = float(round_def.get("enemy_tower_atk_mult", 1.0))
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
	for c in content.round_cards(round_def):
		card_ids.append(str(c))
		card_cd[str(c)] = 0.0
	skill_ids.clear()
	for s in content.round_skills(round_def):
		skill_ids.append(str(s))
		skill_cd[str(s)] = 0.0
	hero = _new_unit(hero_def, SIDE_PLAYER, player_base.x + 30.0)
	hero.is_hero = true
	hero.hp_max *= hero_hp_mult
	hero.hp = hero.hp_max
	hero.atk *= hero_atk_mult
	hero.lane_y = 2.0
	# schedule waves
	spawn_queue.clear()
	wave_times.clear()
	wave_boss.clear()
	for w in round_def.waves:
		var at := float(w.get("at", 0))
		wave_times.append(at)
		wave_boss.append(bool(w.get("boss", false)))
		_queue_spawns(w.get("spawns", []), at)
	waves_total = wave_times.size()
	var ai: Dictionary = round_def.enemy_ai
	ai_gold = float(ai.get("start_gold", 0))
	ai_think = float(ai.get("think", 3.0))
	trickle = round_def.get("trickle", {})
	trickle_next = float(trickle.get("start", -1.0)) if trickle.get("pattern", []).size() > 0 else -1.0

func _read_caps() -> void:
	var gc: Dictionary = content.config.get("caps", {})
	caps.ally = clampi(int(gc.get("max_ally_units", 30)), 1, PerfC.CAP_UNITS_PER_SIDE)
	caps.enemy = clampi(int(gc.get("max_enemy_units", 40)), 1, PerfC.CAP_UNITS_PER_SIDE)
	caps.projectiles = clampi(int(gc.get("max_projectiles", 64)), 8, PerfC.CAP_PROJECTILES)
	caps.fx = clampi(int(gc.get("max_vfx", 32)), 8, PerfC.CAP_FX)
	caps.text = clampi(int(gc.get("max_damage_popups", 24)), 0, PerfC.CAP_FLOATING_TEXT)

func _upgrade_level(target: String) -> int:
	for u in content.meta.get("upgrades", []):
		if str(u.get("target", "")) == target:
			return int(upgrades.get(str(u.id), 1))
	return 1

func _upgrade_mult(target: String, key: String) -> float:
	for u in content.meta.get("upgrades", []):
		if str(u.get("target", "")) == target:
			var lvl := int(upgrades.get(str(u.id), 1))
			return 1.0 + float(u.get("per_level", {}).get(key, 0.0)) * (lvl - 1)
	return 1.0

func _upgrade_add(target: String, key: String) -> float:
	for u in content.meta.get("upgrades", []):
		if str(u.get("target", "")) == target:
			var lvl := int(upgrades.get(str(u.id), 1))
			return float(u.get("per_level", {}).get(key, 0.0)) * (lvl - 1)
	return 0.0

func _queue_spawns(spawns: Array, at: float) -> void:
	for s in spawns:
		var n := int(s.get("count", 1))
		var iv := float(s.get("interval", 1.0))
		for i in n:
			spawn_queue.append({"at": at + i * iv, "unit": str(s.unit)})
	spawn_queue.sort_custom(func(a, b): return a.at < b.at)

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
	t += dt
	gold = minf(gold_max, gold + income() * dt)
	mana = minf(mana_max, mana + mana_regen * dt)
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
	dst.resize(src.size())
	var n := 0
	for u in src:
		if u.dying: continue
		var i := n
		while i > 0 and dst[i - 1].x > u.x:
			dst[i] = dst[i - 1]
			i -= 1
		dst[i] = u
		n += 1
	dst.resize(n)

func _step_wave_announce() -> void:
	while _wave_announced < wave_times.size() and wave_times[_wave_announced] <= t:
		events.append(["wave", {"index": _wave_announced + 1, "boss": wave_boss[_wave_announced]}])
		_wave_announced += 1

func _step_spawns() -> void:
	while not spawn_queue.is_empty() and spawn_queue[0].at <= t:
		if army_count(SIDE_ENEMY) >= caps.enemy:
			spawn_queue[0].at = t + 0.5   # overflow policy: queue
			refused_spawns += 1
			return
		var s = spawn_queue.pop_front()
		_spawn_enemy(s.unit)

func _step_trickle() -> void:
	if trickle_next < 0.0 or t < trickle_next:
		return
	var pat: Array = trickle.pattern
	spawn_queue.push_front({"at": t, "unit": str(pat[trickle_i % pat.size()])})
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
			hero.x = player_base.x + 30.0
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
		hero.x = clampf(hero.x, pbx + 10.0, maxf(pbx + 40.0, L * float(hero_def.leash)))
		hero.state = S_WALK
	elif hero.windup < 0.0 and not in_reach and not base_reach:
		hero.state = S_IDLE
	_attack_logic(hero, tgt, in_reach, base_reach and not in_reach, dt)

func _step_buff(u: Unit, dt: float) -> void:
	if u.buff_t > 0.0:
		u.buff_t -= dt
		if u.buff_t <= 0.0: u.buff_mul = 1.0

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
		_step_boss_summon(u, dt)
	var tgt := _find_target(u)
	var reach: float = float(u.def.range) + u.contact
	var in_reach: bool = tgt != null and absf(tgt.x - u.x) - tgt.contact <= reach
	var base_x: float = (enemy_base.x - BASE_HALF) if u.side == SIDE_PLAYER else (player_base.x + BASE_HALF)
	var base_reach: bool = (base_x - u.x) * u.side <= reach
	if not in_reach and not base_reach and u.windup < 0.0 and u.kb <= 0.0:
		u.state = S_WALK
		u.x += u.side * float(u.def.speed) * u.buff_mul * dt
	_attack_logic(u, tgt, in_reach, base_reach and not in_reach, dt)

func _step_boss_summon(u: Unit, dt: float) -> void:
	var sm = u.def.get("summon")
	if not (sm is Dictionary):
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
	u.atk_cd -= dt * u.buff_mul * u.aura_mul
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
		p.homing = not siege
		p.target = tgt
		p.hit_base = tgt == null
		_cue(&"shoot", p.kind, {"projectile": p.kind, "x": u.x})
	else:
		if tgt:
			_damage(tgt, atk, kb)
			if float(u.def.get("splash", 0.0)) > 0.0:
				_area_damage_side(-u.side, tgt.x, float(u.def.get("splash", 0.0)), atk, kb, tgt)
			_fx("hit_spark", tgt.x, -12.0, 0.25, 0.0)
			_cue(&"hit", "melee", {"kind": "melee", "x": tgt.x})
		elif u.w_base:
			_damage_base(-u.side, atk * _struct_mult(u))
			if float(u.def.get("splash", 0.0)) > 0.0:
				var bx: float = enemy_base.x - BASE_HALF if u.side == SIDE_PLAYER else player_base.x + BASE_HALF
				_area_damage_side(-u.side, bx, float(u.def.get("splash", 0.0)), atk, kb, null)
	if bool(u.def.get("self_destruct", false)):
		_fx("explosion", u.x, -6.0, 0.4, float(u.def.get("splash", 0.0)))
		u.hp = 0.0
		_kill(u, false)

## Nearest living opponent ahead of u (may overlap slightly behind).
func _find_target(u: Unit) -> Unit:
	var best: Unit = null
	var best_d := 1e9
	var foes: Array[Unit] = enemies if u.side == SIDE_PLAYER else players
	for e in foes:
		if e.dying: continue
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
		if not e.dying and e.x < x: x = e.x
	return x

## Player-sourced area damage at x (skills): hits enemies and the enemy base if in radius.
func _area_damage(x: float, radius: float, power: float, kb: float, struct_mult: float) -> void:
	_area_damage_side(SIDE_ENEMY, x, radius, power, kb, null)
	var ebx: float = enemy_base.x - BASE_HALF
	if absf(ebx - x) <= radius:
		_damage_base(SIDE_ENEMY, power * struct_mult)

## Damage all units of `victim_side` within radius of x, excluding `skip`.
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
	target.hp -= dmg
	target.flash = 0.12
	if kb > 0.0 and not target.is_boss:
		target.kb = maxf(target.kb, kb)
	_text(target.x, -28.0, str(int(dmg)), &"dmg")
	if target.hp <= 0.0:
		_kill(target, true)

func _kill(u: Unit, rewarded: bool) -> void:
	if u.dying: return
	u.dying = true
	u.state = S_DYING
	u.anim_t = 0.0
	u.dead_t = 0.7
	u.windup = -1.0
	if u.is_hero:
		hero_deaths += 1
		stats.hero_deaths += 1
		var rs := float(hero_def.respawn) + float(hero_def.get("respawn_per_death", 0.0)) * (hero_deaths - 1)
		hero_respawn = minf(rs, float(hero_def.get("respawn_max", 999.0)))
		events.append(["hero_dead", {"respawn": hero_respawn}])
		return
	if u.side == SIDE_ENEMY and rewarded:
		kills += 1
		kill_coins += int(u.def.get("kill_coins", 0))
		var b := int(u.def.get("bounty", 0))
		gold = minf(gold_max, gold + b)
		mana = minf(mana_max, mana + float(econ.get("mana_on_kill", 2)))
		if b > 0: _text(u.x, -40.0, "+%d" % b, &"gold")

func _damage_base(side: int, amount: float) -> void:
	var b: Dictionary = player_base if side == SIDE_PLAYER else enemy_base
	if b.hp <= 0.0: return
	b.hp = maxf(0.0, b.hp - amount)
	b.flash = 0.12
	if side == SIDE_PLAYER:
		events.append(["shake", {"amp": 2.0 if amount < 40.0 else 4.0}])
	_text(b.x, -70.0, str(int(amount)), &"dmg")
	if b.hp <= 0.0:
		_end(side == SIDE_ENEMY)

## Each base has a defensive tower (economy.base_tower). Enemy tower atk x round.enemy_tower_atk_mult.
func _step_towers(dt: float) -> void:
	if tower.is_empty():
		return
	for side in [SIDE_PLAYER, SIDE_ENEMY]:
		var b: Dictionary = player_base if side == SIDE_PLAYER else enemy_base
		b.tower_cd = float(b.tower_cd) - dt
		if b.tower_cd > 0.0: continue
		var rng_px := float(tower.get("range", 130.0))
		var best: Unit = null
		var best_d := 1e9
		var foes: Array[Unit] = enemies if side == SIDE_PLAYER else players
		for e in foes:
			if e.dying: continue
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
		p.splash = 0.0
		p.struct_mult = 1.0
		p.knockback = 0.0
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
				if p.splash > 0.0:
					_area_damage_side(-p.side, p.x1, p.splash, p.dmg, p.knockback, null)
					_fx("explosion", p.x1, -6.0, 0.35, p.splash)
			else:
				var hit_any := false
				if p.target != null and not p.target.dying and (p.homing or absf(p.target.x - p.x1) <= 12.0 + p.splash):
					_damage(p.target, p.dmg, p.knockback)
					hit_any = true
				if p.splash > 0.0:
					_area_damage_side(-p.side, p.x1, p.splash, p.dmg, p.knockback, p.target if hit_any else null)
					_fx("explosion", p.x1, -6.0, 0.35, p.splash)
				elif hit_any:
					_fx("hit_spark", p.x1, -12.0, 0.2, 0.0)
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
			if tx.t >= 0.8: tx.alive = false

func _reap() -> void:
	for arr in [players, enemies]:
		var i: int = arr.size() - 1
		while i >= 0:
			var u: Unit = arr[i]
			if u.dying and u.dead_t <= 0.0:
				u.alive = false
				u.w_target = null
				_unit_pool.append(u)
				arr.remove_at(i)
			i -= 1
	for p in projectiles:
		if p.target != null and not p.target.alive:
			p.target = null
	for arr2 in [players, enemies]:
		for u in arr2:
			if u.w_target != null and not u.w_target.alive:
				u.w_target = null

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
	u.aura_mul = 1.0
	u.flash = 0.0
	u.kb = 0.0
	u.invuln = 0.0
	u.is_hero = false
	u.is_boss = bool(d.get("is_boss", false)) or (d.get("tags", []) as Array).has("boss")
	u.summon_t = 0.0
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

func _fx(kind: String, x: float, y: float, dur: float, radius: float) -> void:
	var f: Fx = null
	for e in fxs:
		if not e.alive:
			f = e
			break
	if f == null:
		if fxs.size() >= caps.fx: return
		f = Fx.new()
		fxs.append(f)
	f.alive = true
	f.kind = kind
	f.x = x
	f.y = y
	f.t = 0.0
	f.dur = dur
	f.radius = radius

func _text(x: float, y: float, s: String, kind: StringName) -> void:
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
	tx.x = x + rng.randf_range(-4.0, 4.0)
	tx.y = y
	tx.t = 0.0
	tx.text = s
	tx.kind = kind

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
			return {"alive": true, "hp": e.hp, "hp_max": e.hp_max, "id": e.id, "name_key": str(e.def.get("name_key", ""))}
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
		"first_clear": false, "next_round_id": "", "hero_deaths": hero_deaths}
