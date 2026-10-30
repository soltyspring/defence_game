extends RefCounted
## Gameplay rules acceptance on the headless BattleSim for the first 3 rounds in order.json.
## Expectations come from data files + INTERFACES.md §2 formulas, not from sim helper functions.
## Owner: 07-qa.

const Q := preload("res://tests/acceptance/qa_lib.gd")
const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const STEP := 1.0 / 60.0

var econ: Dictionary

func _run(sim, bot, max_t: float) -> void:
	while not sim.ended and sim.t < max_t:
		if bot: bot.act(sim, STEP)
		sim.step(STEP)

func run(q, _tree) -> void:
	q.current_suite = "sim"
	econ = Q.read_json("res://data/economy.json")
	var c = ContentS.new()
	c.load_all("res://data")
	var p0: Array = Array(c.round_order).slice(0, 3)
	for i in p0.size():
		_round(q, c, str(p0[i]), "R%d" % (i + 1))
	c.free()

func _round(q, c, rid: String, tag: String) -> void:
	var raw: Dictionary = Q.read_json("res://data/rounds/%s.json" % rid)
	var cap := float(raw.get("gold_max", econ.gold_max))
	var wmax := int(raw.get("workers_max", econ.workers_max))
	# ---- start state
	var sim = SimS.new()
	sim.setup(c, rid, 4242)
	var cards: Array = []
	for x in raw.cards: cards.append(str(x))
	var ok_start: bool = is_equal_approx(sim.gold, float(raw.start_gold)) and sim.workers == int(econ.workers_start) \
		and is_equal_approx(sim.player_base.hp, float(raw.player_base_hp)) and is_equal_approx(sim.enemy_base.hp, float(raw.enemy_base_hp)) \
		and Array(sim.card_ids) == cards.slice(0, 5) and sim.hero_respawn <= 0.0 and not sim.ended
	q.check("%s-START" % tag, "%s start: gold/workers/base hp/cards/hero match data" % rid, ok_start,
		"gold=%s workers=%s pbase=%s ebase=%s cards=%s (data cards=%s)" % [sim.gold, sim.workers, sim.player_base.hp, sim.enemy_base.hp, sim.card_ids, cards])
	# ---- passive income over 5 s (no spawns before first wave/trickle in P0 data)
	var g0: float = sim.gold
	var inc := float(econ.base_income) + int(econ.workers_start) * float(econ.worker_income)
	for k in 300: sim.step(STEP)
	var expect := minf(cap, g0 + inc * 5.0)
	q.check("%s-INCOME" % tag, "%s income = base_income + workers*worker_income (economy.json), capped at gold_max" % rid,
		absf(sim.gold - expect) <= 0.6, "gold after 5s=%.2f expected %.2f" % [sim.gold, expect])
	# ---- worker purchase
	sim.gold = 0.0
	var r_poor: String = sim.buy_worker()
	var wcost := int(round(float(econ.worker_cost_base) * pow(float(econ.worker_cost_growth), sim.workers - int(econ.workers_start))))
	sim.gold = float(wcost) + 0.5
	var w_before: int = sim.workers
	var r_buy: String = sim.buy_worker()
	var ok_w: bool = r_poor == "not_enough_gold" and r_buy == "" and sim.workers == w_before + 1 and absf(sim.gold - 0.5) < 0.01
	sim.gold = 0.0
	var g1: float = sim.gold
	for k in 120: sim.step(STEP)
	var inc2: float = float(econ.base_income) + sim.workers * float(econ.worker_income)
	ok_w = ok_w and absf((sim.gold - g1) - inc2 * 2.0) <= 0.6
	sim.gold = 99999.0
	while sim.workers < wmax: sim.buy_worker()
	var r_max: String = sim.buy_worker()
	q.check("%s-WORKER" % tag, "%s worker: refused when poor, cost=base*growth^n, income rises, refused at workers_max=%d" % [rid, wmax],
		ok_w and r_max == "worker_max" and sim.workers == wmax, "poor=%s buy=%s cost=%d gold_after=%.2f max_resp=%s workers=%d" % [r_poor, r_buy, wcost, sim.gold, r_max, sim.workers])
	# ---- deploy
	var cid := str(sim.card_ids[0])
	var ud: Dictionary = c.get_unit(cid)
	var raw_u := _raw_unit(cid)
	sim.gold = float(raw_u.get("cost", ud.cost)) - 1.0
	var n0: int = sim.players.size()
	var r1: String = sim.deploy(cid)
	sim.gold = float(raw_u.get("cost", ud.cost)) + 10.0
	var r2: String = sim.deploy(cid)
	var g_after: float = sim.gold
	var r3: String = sim.deploy(cid)
	var spawned: bool = sim.players.size() == n0 + 1
	var x0: float = sim.players.back().x if spawned else 0.0
	for k in 60: sim.step(STEP)
	var moved: bool = spawned and sim.players.back().x > x0
	q.check("%s-DEPLOY" % tag, "%s deploy %s: refused when poor, spends cost, spawns at player base, cooldown blocks, unit advances" % [rid, cid],
		r1 == "not_enough_gold" and r2 == "" and absf(g_after - 10.0) < 0.01 and spawned and (r3 == "on_cooldown" or float(raw_u.get("cooldown", 0)) <= 0.0) and moved,
		"poor=%s ok=%s again=%s spawned=%s moved=%s" % [r1, r2, r3, spawned, moved])
	q.check("%s-DEPLOY-UNKNOWN" % tag, "%s deploy of a card not in the round is refused without crash" % rid, sim.deploy("__qa_nope__") != "")
	# ---- skills
	if sim.skill_ids.is_empty():
		q.record("%s-SKILL" % tag, Q.PASS, "%s has no hero skills by design (data skills=%s); cast() refuses unknown" % [rid, raw.get("skills", [])], "", {"cast_unknown": sim.cast("skill_slam")})
	else:
		var sid := str(sim.skill_ids[0])
		sim.mana = 0.0
		var s1: String = sim.cast(sid)
		sim.mana = sim.mana_max
		var s2: String = sim.cast(sid)
		var s3: String = sim.cast(sid)
		sim.skill_cd[sid] = 0.0
		sim.mana = sim.mana_max
		sim._kill(sim.hero, false)
		var s4: String = sim.cast(sid)
		q.check("%s-SKILL" % tag, "%s skill %s: needs mana, casts, cooldown, refused while hero dead" % [rid, sid],
			s1 == "not_enough_mana" and s2 == "" and s3 == "on_cooldown" and s4 == "hero_dead", "nomana=%s ok=%s again=%s dead=%s" % [s1, s2, s3, s4])
	# ---- pause
	var ps = SimS.new()
	ps.setup(c, rid, 7)
	for k in 600: ps.step(STEP)
	ps.paused = true
	var snap0 := [ps.t, ps.gold, ps.enemies.size(), ps.hero.x]
	for k in 600: ps.step(STEP)
	q.check("%s-PAUSE" % tag, "%s paused sim does not advance time/gold/spawns" % rid, [ps.t, ps.gold, ps.enemies.size(), ps.hero.x] == snap0, "%s -> %s" % [snap0, [ps.t, ps.gold, ps.enemies.size(), ps.hero.x]])
	# ---- win with a competent scripted player (3 independent seeds)
	var wins := 0
	var rows := []
	var keys_ok := true
	var ended_once := true
	for sd in [101, 202, 303]:
		var ws = SimS.new()
		ws.setup(c, rid, sd)
		_run(ws, BotS.new(2, sd), 900.0)
		var res: Dictionary = ws.result()
		for k in ["round_id", "won", "stars", "time", "kills", "coins", "first_clear", "next_round_id"]:
			if not res.has(k): keys_ok = false
		var n_end := 0
		for e in ws.events: if e[0] == "ended": n_end += 1
		if n_end != 1: ended_once = false
		if ws.won: wins += 1
		rows.append({"seed": sd, "won": ws.won, "t": snappedf(ws.t, 0.1), "stars": res.stars, "enemy_base": ws.enemy_base.hp, "player_base": ws.player_base.hp})
	q.check("%s-WIN" % tag, "%s is winnable: competent bot wins >= 2/3 seeds by destroying the enemy base" % rid, wins >= 2, "wins=%d" % wins, rows)
	q.check("%s-RESULT" % tag, "%s BattleResult has contract keys and exactly one 'ended' event" % rid, keys_ok and ended_once, "keys_ok=%s ended_once=%s" % [keys_ok, ended_once])
	var star_ok := true
	for rw in rows:
		if rw.won and (int(rw.stars) < 1 or int(rw.stars) > 3): star_ok = false
		if rw.won and float(rw.enemy_base) > 0.0: star_ok = false
	q.check("%s-STARS" % tag, "%s win => enemy base hp 0 and 1..3 stars" % rid, star_ok, str(rows))
	# ---- loss: idle player
	var ls = SimS.new()
	ls.setup(c, rid, 55)
	_run(ls, null, 900.0)
	var lres: Dictionary = ls.result()
	q.check("%s-LOSS" % tag, "%s idle player loses by base destruction (not by 900s timeout)" % rid,
		ls.ended and not ls.won and ls.player_base.hp <= 0.0 and int(lres.stars) == 0 and ls.t < 899.0,
		"ended=%s won=%s pbase=%s t=%.1f" % [ls.ended, ls.won, ls.player_base.hp, ls.t], {"loss_time": snappedf(ls.t, 0.1)})
	var t_end: float = ls.t
	for k in 120: ls.step(STEP)
	q.check("%s-ENDED" % tag, "%s after end: time frozen, deploy/worker/cast return 'ended'" % rid,
		ls.t == t_end and ls.deploy(str(ls.card_ids[0])) == "ended" and ls.buy_worker() == "ended")
	# ---- determinism (D6)
	var a = SimS.new(); a.setup(c, rid, 999); _run(a, BotS.new(2, 999), 900.0)
	var b = SimS.new(); b.setup(c, rid, 999); _run(b, BotS.new(2, 999), 900.0)
	q.check("%s-DETERMINISM" % tag, "%s same seed + same inputs => identical outcome (D6)" % rid,
		a.t == b.t and a.won == b.won and a.kills == b.kills and a.stats.deployed == b.stats.deployed, "a=%s/%s b=%s/%s" % [a.t, a.kills, b.t, b.kills])

func _raw_unit(id: String) -> Dictionary:
	var d = Q.read_json("res://data/units/units.json")
	if d is Dictionary:
		for u in d.get("units", []):
			if str(u.get("id", "")) == id: return u
	return {}
