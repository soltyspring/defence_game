extends Node
## MOCK ADAPTER — NOT GAMEPLAY. Owner: 04-client.
## Stands in for 02's App/BattleSim so UI can be previewed, screenshotted and tested before/without
## the real engine. It only implements the INTERFACES.md §1 signal contract with fake numbers:
## gold regen, card cooldowns, mana, base HP decay, waves, win/loss. Never shipped as gameplay;
## the real router is res://scenes/gameplay/main.tscn (02).

var bus: Node
var info: Dictionary = {}
var t := 0.0
var gold := 100.0
var workers := 1
var mana := 30.0
var cds := {}
var skill_cds := {}
var hero_dir := 0
var hero_x := 80.0
var hero_alive := true
var respawn := 0.0
var army := 0
var player_hp := 1500.0
var enemy_hp := 1200.0
var paused := false
var running := false
var _accum := 0.0
var cmd_log: Array = []          # every command received: [name, args]
var auto_play := false       # when true, enemy base takes passive damage so battles end
var round_id := "r01"
var boss_alive := false     # preview: show a boss HP bar

const ROUNDS := [
	{"id": "r01", "index": 1, "name": "Meadow Gate", "biome": "meadow"},
	{"id": "r02", "index": 2, "name": "Swarm", "biome": "meadow"},
	{"id": "r03", "index": 3, "name": "Spitters", "biome": "meadow"},
	{"id": "r04", "index": 4, "name": "Brute", "biome": "forest"},
	{"id": "r05", "index": 5, "name": "Warlord", "biome": "forest"},
	{"id": "r06", "index": 6, "name": "Walls", "biome": "forest"},
	{"id": "r07", "index": 7, "name": "Bombers", "biome": "desert"},
	{"id": "r08", "index": 8, "name": "Endless", "biome": "desert"},
	{"id": "r09", "index": 9, "name": "Assault", "biome": "desert"},
	{"id": "r10", "index": 10, "name": "Overlord", "biome": "desert"},
	{"id": "r11", "index": 11, "name": "Extra 1", "biome": "snow"},
]

static func sample_info(n_cards := 5, n_skills := 3) -> Dictionary:
	var all_cards := [
		{"id": "melee_basic", "name": "Infantry", "cost": 50, "cooldown": 3.0},
		{"id": "ranged_basic", "name": "Archer", "cost": 75, "cooldown": 4.0},
		{"id": "tank", "name": "Shield", "cost": 120, "cooldown": 6.0},
		{"id": "fast", "name": "Raider", "cost": 90, "cooldown": 4.0},
		{"id": "siege", "name": "Catapult", "cost": 200, "cooldown": 10.0},
	]
	var all_skills := [
		{"id": "skill_slam", "name": "Slam", "mana": 40, "cooldown": 8.0},
		{"id": "skill_rally", "name": "Rally", "mana": 30, "cooldown": 12.0},
		{"id": "skill_barrage", "name": "Barrage", "mana": 60, "cooldown": 15.0},
	]
	return {"round_id": "r01", "round_index": 1, "round_name": "Meadow Gate", "biome": "meadow",
		"cards": all_cards.slice(0, n_cards), "skills": all_skills.slice(0, n_skills),
		"hero": {"id": "hero_captain", "name": "Captain"}, "lane_length": 1600.0}

func attach(p_bus: Node) -> void:
	bus = p_bus
	for s in [&"cmd_start_round", &"cmd_deploy_unit", &"cmd_buy_worker", &"cmd_hero_move", &"cmd_hero_skill",
			&"cmd_set_paused", &"cmd_retry", &"cmd_next_round", &"cmd_open_screen", &"cmd_set_setting"]:
		bus.connect(s, _on_cmd.bind(s))

func _on_cmd(a0 = null, a1 = null, a2 = null) -> void:
	# bound signal name arrives as the last non-null argument
	var args := [a0, a1, a2].filter(func(x): return x != null)
	var sig: StringName = args.pop_back()
	cmd_log.append([sig, args])
	match sig:
		&"cmd_start_round": start(str(args[0]))
		&"cmd_retry": start(round_id)
		&"cmd_next_round": start("r%02d" % (int(round_id.substr(1)) + 1))
		&"cmd_deploy_unit": _deploy(str(args[0]))
		&"cmd_buy_worker": _buy_worker()
		&"cmd_hero_move": hero_dir = int(args[0])
		&"cmd_hero_skill": _skill(str(args[0]))
		&"cmd_set_paused":
			paused = bool(args[0])
			bus.battle_paused.emit(paused)
	if running:
		_emit_snapshot()

func start(id: String, p_info: Dictionary = {}) -> void:
	round_id = id
	info = p_info if not p_info.is_empty() else sample_info()
	info.round_id = id
	t = 0.0; gold = 100.0; workers = 1; mana = 30.0; army = 0
	player_hp = 1500.0; enemy_hp = 1200.0; paused = false; hero_alive = true; hero_x = 80.0
	cds.clear(); skill_cds.clear()
	running = true
	bus.battle_started.emit(info)
	_emit_snapshot()

func _deploy(id: String) -> void:
	var c := _card(id)
	if c.is_empty():
		return
	if army >= 36:
		bus.toast.emit("army_full", {})
	elif float(cds.get(id, 0.0)) > 0.0:
		bus.toast.emit("on_cooldown", {})
	elif gold < float(c.cost):
		bus.toast.emit("not_enough_gold", {})
	else:
		gold -= float(c.cost)
		cds[id] = float(c.cooldown)
		army += 1

func _worker_cost() -> int:
	return int(60 * pow(1.3, workers - 1))

func _buy_worker() -> void:
	if workers >= 8:
		bus.toast.emit("worker_max", {})
	elif gold < _worker_cost():
		bus.toast.emit("not_enough_gold", {})
	else:
		gold -= _worker_cost()
		workers += 1

func _skill(id: String) -> void:
	for s in info.get("skills", []):
		if s.id == id:
			if not hero_alive:
				bus.toast.emit("hero_dead", {})
			elif float(skill_cds.get(id, 0.0)) > 0:
				bus.toast.emit("on_cooldown", {})
			elif mana < float(s.mana):
				bus.toast.emit("not_enough_mana", {})
			else:
				mana -= float(s.mana)
				skill_cds[id] = float(s.cooldown)
				enemy_hp -= 60

func _card(id: String) -> Dictionary:
	for c in info.get("cards", []):
		if c.id == id:
			return c
	return {}

## Advance the fake battle by dt seconds (called from _process, or directly by tests).
func step(dt: float) -> void:
	if not running or paused:
		return
	t += dt
	var income := 4.0 + workers * 2.0
	gold = minf(999.0, gold + income * dt)
	mana = minf(100.0, mana + 4.0 * dt)
	for k in cds.keys():
		cds[k] = maxf(0.0, cds[k] - dt)
	for k in skill_cds.keys():
		skill_cds[k] = maxf(0.0, skill_cds[k] - dt)
	hero_x = clampf(hero_x + hero_dir * 70.0 * dt, 40.0, 900.0)
	if auto_play:
		enemy_hp -= (8.0 + army * 3.0) * dt
		player_hp -= 6.0 * dt
	if enemy_hp <= 0 or player_hp <= 0:
		running = false
		var won := enemy_hp <= 0
		bus.battle_ended.emit({"round_id": round_id, "won": won, "stars": 3 if player_hp > 750 else 2 if won else 0,
			"time": t, "kills": int(t * 0.5), "coins": 60 if won else 10, "first_clear": won,
			"next_round_id": "r%02d" % (int(round_id.substr(1)) + 1) if won else ""})

func _process(delta: float) -> void:
	if not running:
		return
	step(delta)
	_accum += delta
	if _accum >= 0.1:
		_accum = 0.0
		_emit_snapshot()

func snapshot() -> Dictionary:
	var cards := []
	for c in info.get("cards", []):
		var cd := float(cds.get(c.id, 0.0))
		cards.append({"id": c.id, "cost": c.cost, "cd": cd, "cd_total": c.cooldown, "ready": cd <= 0 and gold >= c.cost and army < 36, "affordable": gold >= c.cost})
	var skills := []
	for s in info.get("skills", []):
		var cd := float(skill_cds.get(s.id, 0.0))
		skills.append({"id": s.id, "mana": s.mana, "cd": cd, "cd_total": s.cooldown, "ready": cd <= 0 and mana >= s.mana and hero_alive})
	var wave_i := mini(5, 1 + int(t / 20.0))
	return {"t": t, "gold": int(gold), "gold_max": 999, "income": 4.0 + workers * 2.0,
		"workers": workers, "workers_max": 8, "worker_cost": _worker_cost(),
		"mana": mana, "mana_max": 100.0, "cards": cards, "skills": skills,
		"hero": {"hp": 420, "hp_max": 600, "alive": hero_alive, "respawn": respawn, "x": hero_x},
		"player_base": {"hp": player_hp, "hp_max": 1500}, "enemy_base": {"hp": enemy_hp, "hp_max": 1200},
		"wave": {"index": wave_i, "total": 5, "next_in": 20.0 - fmod(t, 20.0), "boss": wave_i == 5},
		"army": {"player": army, "enemy": 9, "cap": 36}, "paused": paused,
		"boss": {"alive": boss_alive, "hp": 820.0, "hp_max": 1400.0, "id": "boss_warlord", "name_key": "enemy.boss_warlord.name"}}

func _emit_snapshot() -> void:
	bus.hud_snapshot.emit(snapshot())
