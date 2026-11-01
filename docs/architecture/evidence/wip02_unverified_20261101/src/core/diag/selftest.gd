extends SceneTree
## Headless engine self-test. Run with a PRIVATE APPDATA (the Save autoload boots and may rewrite the real
## user://save.json after a data change, 10 v0.26):
##   & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @('--headless','--path','.','-s','res://src/core/diag/selftest.gd')
## (plain: tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/selftest.gd)
## Exit code 0 = all checks pass. Writes a JSON report to user://selftest_report.json and prints it.
## Owner: 02-engine.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const SaveS := preload("res://src/core/save.gd")

var failures: PackedStringArray = []
var balance_flags: PackedStringArray = []
var report := {}

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_check_scripts()
	var content = ContentS.new()
	content.load_all("res://data")
	report.content_warnings = Array(content.warnings)
	report.rounds = content.round_order.duplicate()
	_check_fallback_content()
	_check_rounds(content)
	_check_caps(content)
	_check_find_target(content)
	_check_rules(content)
	_check_tutorial(content)
	_check_waves_and_pools(content)
	_check_buy_upgrade(content)
	_check_content_migration(content)
	_check_view_rules(content)
	_check_unlock_rules()
	_check_save()
	_check_save_faults()
	content.free()
	report.total_ms = Time.get_ticks_msec() - t0
	report.failures = Array(failures)
	report.balance_flags = Array(balance_flags)
	var summary := []
	for row in report.get("round_results", []):
		summary.append("%s competent %d/3 %s | casual %s | passive lost@%ss" % [row.round, row.competent_wins, str(row.competent_times), "W" if row.casual.won else "L", row.passive.t])
	report.summary = summary
	report.pass = failures.is_empty()
	var txt := JSON.stringify(report, "  ")
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f:
		f.store_string(txt)
	for line in report.summary: print("  ", line)
	print("cap_test ", JSON.stringify(report.get("cap_test", {})))
	print("save_tests ", JSON.stringify(report.get("save_tests", {})))
	print("save_faults ", JSON.stringify(report.get("save_faults", {})))
	print("find_target ", JSON.stringify(report.get("find_target_equivalence", {})))
	print("rules ", JSON.stringify(report.get("rules", {})))
	print("tutorial ", JSON.stringify(report.get("tutorial", {})))
	print("waves_and_pools ", JSON.stringify(report.get("waves_and_pools", {})))
	print("buy_upgrade ", JSON.stringify(report.get("buy_upgrade", {})))
	print("base_defense ", JSON.stringify(report.get("base_defense", {})))
	print("content_migration ", JSON.stringify(report.get("content_migration", {})))
	print("view_rules ", JSON.stringify(report.get("view_rules", {})))
	print("unlock_rules ", JSON.stringify(report.get("unlock_rules", {})))
	print("scripts ok %d/%d, scenes %d, foreign errors %s" % [report.scripts_ok, report.scripts_total, report.scenes_total, str(report.foreign_script_errors)])
	for b in balance_flags: print("BALANCE: ", b)
	print("report: ", ProjectSettings.globalize_path("user://selftest_report.json"))
	print("SELFTEST ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("FAIL: ", msg)

## Every .gd under src/ and scenes/ must load (parse + compile) without error.
func _check_scripts() -> void:
	var files := _list("res://src", ".gd") + _list("res://scenes", ".gd")
	var ok := 0
	var foreign := PackedStringArray()
	for p in files:
		var s = load(p)
		if s == null or not (s is GDScript) or not s.can_instantiate():
			if p.begins_with("res://src/ui") or p.begins_with("res://scenes/ui"):
				foreign.append(p)   # 04-owned; reported, not an engine failure
			else:
				_fail("script failed to compile: " + p)
		else:
			ok += 1
	report.foreign_script_errors = Array(foreign)
	var scenes := _list("res://scenes", ".tscn")
	for p in scenes:
		var ps = load(p)
		if ps == null or not (ps is PackedScene):
			_fail("scene failed to load: " + p)
	report.scripts_ok = ok
	report.scripts_total = files.size()
	report.scenes_total = scenes.size()

func _list(root: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(root)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(root + "/" + f)
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_list(root + "/" + sub, ext))
	return out

## Content must stay playable with an empty data folder.
func _check_fallback_content() -> void:
	var c = ContentS.new()
	c.load_all("res://__no_such_data__")
	if c.round_order.size() < 3:
		_fail("fallback content has < 3 rounds")
	var sim = SimS.new()
	sim.setup(c, c.round_order[0], 3)
	var bot = BotS.new(2, 3)
	_run(sim, bot, 600.0)
	if not sim.ended:
		_fail("fallback round did not finish")
	report.fallback_round = {"won": sim.won, "t": snappedf(sim.t, 0.1)}
	c.free()

func _run(sim, bot, max_t: float) -> float:
	var step := 1.0 / 60.0
	var us0 := Time.get_ticks_usec()
	var steps := 0
	while not sim.ended and sim.t < max_t:
		if bot: bot.act(sim, step)
		sim.step(step)
		steps += 1
	var us := Time.get_ticks_usec() - us0
	return float(us) / maxf(1.0, steps) / 1000.0   # ms per step

func _check_rounds(content) -> void:
	var rows := []
	for rid in content.round_order:
		var row := {"round": rid}
		# competent bot over 3 seeds must win at least 2
		var wins := 0
		var times := []
		var ms_max := 0.0
		for seed_v in [11, 22, 33]:
			var sim = SimS.new()
			sim.setup(content, rid, seed_v)
			var ms := _run(sim, BotS.new(2, seed_v), 900.0)
			ms_max = maxf(ms_max, ms)
			if sim.won: wins += 1
			times.append(snappedf(sim.t, 0.1))
			row["stats_%d" % seed_v] = sim.stats.duplicate()
			row["stars_%d" % seed_v] = sim.result().stars
			_validate_events(sim, rid)
		row.competent_wins = wins
		row.competent_times = times
		row.sim_ms_per_step_avg_max = snappedf(ms_max, 0.0001)
		# P0 rounds (first 3) must be winnable by the competent bot; later rounds are balance flags for 01.
		if wins < 2:
			if content.round_order.find(rid) < 3:
				_fail("round %s: competent bot won only %d/3" % [rid, wins])
			else:
				balance_flags.append("round %s: competent bot won %d/3" % [rid, wins])
		# passive player must lose (enemy can actually destroy the base)
		var ps = SimS.new()
		ps.setup(content, rid, 5)
		_run(ps, BotS.new(0, 5), 900.0)
		row.passive = {"won": ps.won, "ended": ps.ended, "t": snappedf(ps.t, 0.1)}
		if ps.won or not ps.ended:
			_fail("round %s: passive player did not lose" % rid)
		# casual bot result recorded (difficulty curve evidence, not asserted)
		var cs = SimS.new()
		cs.setup(content, rid, 9)
		_run(cs, BotS.new(1, 9), 900.0)
		row.casual = {"won": cs.won, "t": snappedf(cs.t, 0.1)}
		rows.append(row)
	report.round_results = rows

func _validate_events(sim, rid: String) -> void:
	var ended_ev := 0
	for e in sim.events:
		if e[0] == "ended": ended_ev += 1
	if ended_ev != 1:
		_fail("round %s: expected exactly 1 ended event, got %d" % [rid, ended_ev])
	var snap: Dictionary = sim.snapshot()
	for k in ["gold", "workers", "cards", "skills", "hero", "player_base", "enemy_base", "wave", "army"]:
		if not snap.has(k):
			_fail("snapshot missing key " + k)

## Spam both sides past caps and check pooling/caps hold.
func _check_caps(content) -> void:
	var sim = SimS.new()
	sim.setup(content, content.round_order[content.round_order.size() - 1], 1)
	sim.gold = 99999.0
	sim.gold_max = 999999.0
	var foe: String = content._first_enemy_id()
	for uid in content.units:   # prefer a ranged enemy so projectiles are stressed too
		if str(content.units[uid].faction) == "enemy" and str(content.units[uid].attack_type) == "ranged":
			foe = uid
			break
	var refused := 0
	for i in 200:
		for id in sim.card_ids:
			sim.card_cd[id] = 0.0
			if sim.deploy(id) == "army_full": refused += 1
		for j in 3:
			if sim.army_count(-1) < sim.caps.enemy:
				var e = sim._spawn_enemy(foe)
				e.x = sim.player_base.x + 260.0 + j * 20.0   # force contact so combat/projectiles are stressed
		sim.step(1.0 / 60.0)
	var max_ms := 0.0
	var samples := PackedFloat32Array()
	for k in 600:
		var us := Time.get_ticks_usec()
		sim.step(1.0 / 60.0)
		var ms := (Time.get_ticks_usec() - us) / 1000.0
		samples.append(ms)
		max_ms = maxf(max_ms, ms)
		for id in sim.card_ids:
			sim.card_cd[id] = 0.0
			sim.deploy(id)
	samples.sort()
	var avg := 0.0
	for s in samples: avg += s
	avg /= samples.size()
	report.cap_test = {"refused_deploys": refused, "max_units_seen": sim.stats.max_units,
		"max_projectiles": sim.stats.max_projectiles, "pool_free": sim._unit_pool.size(),
		"alive_player": sim.army_count(1), "alive_enemy": sim.army_count(-1),
		"step_ms_avg_desktop": snappedf(avg, 0.001), "step_ms_p99_desktop": snappedf(samples[int(samples.size() * 0.99)], 0.001),
		"worst_step_ms_desktop": snappedf(max_ms, 0.001)}
	if sim.army_count(1) > sim.caps.ally or sim.army_count(-1) > sim.caps.enemy:
		_fail("unit cap exceeded")
	if refused == 0:
		_fail("cap never refused a deploy")
	if sim.projectiles.size() > sim.caps.projectiles:
		_fail("projectile cap exceeded")

func _check_save() -> void:
	var s = SaveS.new()
	s.path = "user://selftest_save.json"
	for f in [s.path, s.path + ".bak", s.path + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	s.load_progress()
	if s.recovered: _fail("fresh save flagged recovered")
	s.progress.coins = 123
	s.progress.stars["r01"] = 3
	if not s.save_progress(): _fail("save failed: " + s.last_error)
	s.progress.coins = 456
	s.save_progress()   # now .bak holds coins=123
	var s2 = SaveS.new()
	s2.path = s.path
	s2.load_progress()
	if int(s2.progress.coins) != 456: _fail("save roundtrip mismatch")
	# corrupt main file -> must recover from .bak
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string("{ corrupted")
	f.close()
	var s3 = SaveS.new()
	s3.path = s.path
	s3.load_progress()
	if not s3.recovered or int(s3.progress.coins) != 123:
		_fail("corruption recovery failed (recovered=%s coins=%s)" % [s3.recovered, s3.progress.coins])
	# tampered checksum -> rejected
	var env: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(s.path + ".bak"))
	env.payload = str(env.payload).replace("123", "999")
	var g := FileAccess.open(s.path + ".bak", FileAccess.WRITE)
	g.store_string(JSON.stringify(env))
	g.close()
	var s4 = SaveS.new()
	s4.path = s.path
	s4.load_progress()
	if int(s4.progress.coins) == 999: _fail("tampered save accepted")
	# legacy v0 payload migrates
	var legacy := {"unlocked_round": 2}
	var lt := JSON.stringify(legacy)
	var h := FileAccess.open(s.path, FileAccess.WRITE)
	h.store_string(JSON.stringify({"checksum": lt.sha256_text(), "payload": lt}))
	h.close()
	var s5 = SaveS.new()
	s5.path = s.path
	s5.load_progress()
	if int(s5.progress.version) != 1 or not s5.progress.has("settings") or int(s5.progress.unlocked_round) != 2:
		_fail("migration v0->v1 failed")
	report.save_tests = {"roundtrip": true, "corruption_recovery": s3.recovered, "tamper_rejected": int(s4.progress.coins) != 999, "migration": int(s5.progress.version)}
	for n in [s, s2, s3, s4, s5]: n.free()

## Sorted-lane target lookup must pick a target at the same distance as the O(n) reference scan.
func _check_find_target(content) -> void:
	var sim = SimS.new()
	sim.setup(content, content.round_order[content.round_order.size() - 1], 4)
	sim.gold = 99999.0
	sim.gold_max = 999999.0
	var checked := 0
	var mismatches := 0
	for i in 900:
		for id in sim.card_ids:
			sim.card_cd[id] = 0.0
			sim.deploy(id)
		sim.step(1.0 / 60.0)
		if sim.ended: break
		if i % 15 == 0:
			sim._sort_lanes()   # fresh lanes: results must match exactly by distance
			var all: Array = sim.players + sim.enemies + [sim.hero]
			for u in all:
				if u.dying: continue
				var a = sim._find_target(u)
				var b = sim._find_target_linear(u)
				checked += 1
				var da: float = 1e9 if a == null else (a.x - u.x) * u.side
				var db: float = 1e9 if b == null else (b.x - u.x) * u.side
				if absf(da - db) > 0.0001 or a != b:
					mismatches += 1
	report.find_target_equivalence = {"checked": checked, "mismatches": mismatches}
	if checked < 100: _fail("find_target equivalence: too few samples (%d)" % checked)
	if mismatches > 0: _fail("find_target sorted lookup mismatched linear scan %d/%d" % [mismatches, checked])

## 01 RELEASE_DESIGN_REVIEW §3 rules + round skill gating (01 R2 C2).
func _check_rules(content) -> void:
	var sim = SimS.new()
	sim.setup(content, content.round_order[0], 1)
	sim.player_base.hp = 1.0
	sim.enemy_base.hp = 1.0
	sim._in_step = true
	sim._damage_base(-1, 10.0)
	sim._damage_base(1, 10.0)
	sim._in_step = false
	sim.step(1.0 / 60.0)
	var both_ok: bool = sim.ended and sim.won
	if not both_ok: _fail("both bases destroyed same tick must be a player win")
	var gating := {}
	for rid in content.round_order:
		gating[rid] = content.round_skills(content.get_round(rid))
	var r01: Array = gating[content.round_order[0]]
	if not r01.is_empty(): _fail("r01 must have no skills, got %s" % str(r01))
	var roster: Array = content.round_enemy_roster(content.get_round(content.round_order[0]))
	report.rules = {"same_tick_both_bases_player_win": both_ok, "skills_by_round": gating, "r01_enemy_roster": roster}
	if roster.is_empty(): _fail("r01 enemy roster empty")
	_check_base_defense(content)

## 01 D29 option B: player-base damage cap over a sliding 1 s window (economy.base_defense.dps_cap).
func _check_base_defense(content) -> void:
	var sim = SimS.new()
	sim.setup(content, content.round_order[0], 1)
	var econ_bd = content.economy.get("base_defense", {})
	var read_ok := true
	for k in ["dps_cap", "push_px", "stagger_s", "tower_splash"]:
		var want := float(econ_bd.get(k, 0.0)) if econ_bd is Dictionary and (econ_bd.get(k) is int or econ_bd.get(k) is float) else 0.0
		if not is_equal_approx(float(sim.base_defense.get(k, -1.0)), want): read_ok = false
	if not read_ok: _fail("base_defense not read from economy.json: %s" % str(sim.base_defense))
	sim.base_defense = {"dps_cap": 25.0, "push_px": 0.0, "stagger_s": 0.0, "tower_splash": 0.0}
	sim.player_base.hp = 1000.0
	sim.events.clear()
	sim.t = 10.0
	var hp := []
	for i in 3:
		sim._damage_base(1, 20.0)       # 20 applied, then 5 (cap 25 reached), then 0 (absorbed)
		hp.append(sim.player_base.hp)
	sim.t = 11.01                       # the first two hits left the 1 s window
	sim._damage_base(1, 20.0)
	hp.append(sim.player_base.hp)
	var shakes := 0
	for ev in sim.events:
		if ev[0] == "shake": shakes += 1
	var cap_ok: bool = hp == [980.0, 975.0, 975.0, 955.0] and is_equal_approx(sim.base_dmg_capped, 35.0) and shakes == 3
	if not cap_ok: _fail("dps_cap: hp %s capped %s shakes %d (want 980/975/975/955, 35, 3)" % [str(hp), str(sim.base_dmg_capped), shakes])
	# enemy base is never capped
	var eb: float = sim.enemy_base.hp
	sim._damage_base(-1, 100.0)
	var enemy_ok: bool = is_equal_approx(sim.enemy_base.hp, eb - 100.0)
	if not enemy_ok: _fail("dps_cap must not apply to the enemy base")
	report.base_defense = {"read_from_economy": read_ok, "cap_hp": hp, "capped": sim.base_dmg_capped, "shakes": shakes, "enemy_base_uncapped": enemy_ok}

## Drives TutorialDirector the way battle.gd does, with the competent bot on the first round.
func _check_tutorial(content) -> void:
	var TutS = load("res://src/gameplay/tutorial_director.gd")
	var rid: String = content.round_order[0]
	var rd: Dictionary = content.get_round(rid)
	var sim = SimS.new()
	sim.setup(content, rid, 7)
	var bot = BotS.new(2, 7)
	var tut = TutS.new()
	tut.setup(rd.get("tutorial", []), [])
	var shown_seq: Array = []
	var cue_counts := {}
	var dt := 1.0 / 60.0
	while not sim.ended and sim.t < 600.0:
		bot.act(sim, dt)
		if sim.hero_dir != 0: tut.moved = true
		sim.step(dt)
		for k in sim.cues:
			var c: String = str(sim.cues[k][0])
			cue_counts[c] = int(cue_counts.get(c, 0)) + 1
		sim.cues.clear()
		for e in sim.events:
			match e[0]:
				"deploy":
					tut.deployed += 1
					tut.deployed_kinds[str(e[1].unit)] = true
				"worker": tut.workers_bought += 1
				"skill":
					tut.skills_cast += 1
					tut.cast_ids[str(e[1].skill)] = true
				"boss": tut.boss_seen = true
		sim.events.clear()
		var k = tut.update(sim, dt)
		if k != null and str(k) != "":
			shown_seq.append([str(k), snappedf(sim.t, 0.1)])
	report.tutorial = {"round": rid, "steps": rd.get("tutorial", []), "shown": shown_seq, "done": tut.done, "cues": cue_counts}
	var steps: Array = rd.get("tutorial", [])
	if shown_seq.size() != steps.size():
		_fail("tutorial: shown %d of %d steps" % [shown_seq.size(), steps.size()])
	for i in mini(shown_seq.size(), steps.size()):
		if shown_seq[i][0] != str(steps[i]): _fail("tutorial order mismatch at %d" % i)
	for c in ["hit", "death", "base_hit"]:
		if int(cue_counts.get(c, 0)) == 0: _fail("no '%s' audio cues in a full battle" % c)

func _new_save(name: String):
	var s = SaveS.new()
	s.path = "user://selftest_faults/" + name + ".json"
	DirAccess.make_dir_recursive_absolute("user://selftest_faults")
	var d := DirAccess.open("user://selftest_faults")
	for f in d.get_files():
		if f.begins_with(name + ".json"):
			d.remove(f)
	s.load_progress()
	return s

func _reload(s):
	var r = SaveS.new()
	r.path = s.path
	r.load_progress()
	return r

func _commit(s, unlocked: int, coins: int) -> bool:
	s.progress.unlocked_round = unlocked
	s.progress.coins = coins
	return s.save_progress()

## QA-B004 / SV-1 double fault, R6 fault hooks, R3 battle_uid idempotency, B003/B005/B006/B007.
func _check_save_faults() -> void:
	var out := {}
	var tmp_nodes: Array = []
	# 1) B004 probe A2: corrupt main, recover (6), save once, corrupt main again -> must still load 6
	var a = _new_save("b004")
	_commit(a, 5, 100); _commit(a, 6, 900)
	FileAccess.open(a.path, FileAccess.WRITE).store_string("{ corrupt")
	var a1 = _reload(a)
	var rec1: bool = a1.recovered
	a1.save_progress()
	FileAccess.open(a.path, FileAccess.WRITE).store_string("{ corrupt again")
	var a2 = _reload(a)
	out.b004_double_fault = {"first_recovered": rec1, "first_source": a1.recovery_source, "recovered_value": int(a1.progress.unlocked_round), "unlocked_after_second_fault": int(a2.progress.unlocked_round), "recovered": a2.recovered, "source": a2.recovery_source}
	# the recovered state (from .bak = 5) must survive the second fault; before the fix this became 1 (fresh)
	if int(a2.progress.unlocked_round) != int(a1.progress.unlocked_round) or not a2.recovered: _fail("B004 double fault lost progress: %s" % str(out.b004_double_fault))
	tmp_nodes.append_array([a, a1, a2])
	# 2) every fault point during the first save after a recovery and during a normal save
	var points := {}
	for pre in ["normal", "after_recovery"]:
		for fp in SaveS.FAULT_POINTS:
			var s = _new_save("fp_%s_%s" % [pre, fp])
			_commit(s, 5, 50); _commit(s, 6, 60)
			var w = s
			var committed := 6
			if pre == "after_recovery":
				FileAccess.open(s.path, FileAccess.WRITE).store_string("{ corrupt")
				w = _reload(s)     # recovered from .bak (state 5)
				committed = int(w.progress.unlocked_round)
				tmp_nodes.append(w)
			w.progress.unlocked_round = 7
			w._fault = fp
			var ok: bool = w.save_progress()
			var r = _reload(s)
			var u := int(r.progress.unlocked_round)
			points["%s/%s" % [pre, fp]] = {"save_ok": ok, "fired": w.fault_fired, "unlocked": u, "recovered": r.recovered, "source": r.recovery_source}
			if ok or w.fault_fired != fp: _fail("fault %s/%s did not fire" % [pre, fp])
			if u < committed: _fail("fault %s/%s lost committed progress (unlocked %d < %d)" % [pre, fp, u, committed])
			# a non-main source must be reported (QA-B004 "no recovered notice")
			if r.recovery_source != "main" and not r.recovered: _fail("fault %s/%s silent recovery" % [pre, fp])
			tmp_nodes.append_array([s, r])
	out.fault_points = points
	# 3) R3 battle_uid idempotency
	var b = _new_save("r3")
	var res := {"round_id": "r01", "won": true, "stars": 2, "time": 80.0, "coins": 50, "battle_uid": "selftest-uid-1"}
	var first: bool = b.record_result(res, 0)
	var second: bool = b.record_result(res, 0)
	var b2 = _reload(b)
	var third: bool = b2.record_result(res, 0)   # after a restart the ledger still blocks it
	var b3 = _reload(b)
	out.r3 = {"first": first, "second": second, "after_reload": third, "coins": int(b3.progress.coins), "clears": int(b3.progress.clears)}
	if not first or second or third or int(b3.progress.coins) != 50 or int(b3.progress.clears) != 1:
		_fail("R3 duplicate battle_uid applied twice: %s" % str(out.r3))
	# write failure rolls back and is surfaced
	var c = _new_save("rollback")
	_commit(c, 3, 10)
	c._fault = "after_tmp_write"
	var okc: bool = c.record_result({"round_id": "r03", "won": true, "stars": 1, "time": 99.0, "coins": 70, "battle_uid": "selftest-uid-2"}, 2)
	out.rollback = {"ok": okc, "coins_in_memory": int(c.progress.coins), "uid_recorded": c.was_applied("selftest-uid-2")}
	if okc or int(c.progress.coins) != 10 or c.was_applied("selftest-uid-2"): _fail("record_result rollback failed: %s" % str(out.rollback))
	tmp_nodes.append_array([b, b2, b3, c])
	# 4) B003 hostile types, B007 clamps, B006 newer version read-only
	var h = _new_save("hostile")
	var bad := {"version": 1, "unlocked_round": "abc", "coins": -50, "stars": [3, 2], "best_time": null, "settings": "loud", "services": {"keep": 1}}
	var bt := JSON.stringify(bad)
	FileAccess.open(h.path, FileAccess.WRITE).store_string(JSON.stringify({"checksum": bt.sha256_text(), "payload": bt}))
	var h2 = _reload(h)
	var okh: bool = h2.record_result({"round_id": "r01", "won": true, "stars": 2, "time": 80.0, "coins": 5}, 0)
	out.hostile = {"types_ok": h2.progress.stars is Dictionary and h2.progress.best_time is Dictionary and h2.progress.settings is Dictionary, "coins": h2.progress.coins, "unlocked": h2.progress.unlocked_round, "record_ok": okh, "unknown_kept": h2.progress.has("services")}
	if not out.hostile.types_ok or not okh or not out.hostile.unknown_kept: _fail("hostile save not normalised: %s" % str(out.hostile))
	var big := {"version": 1, "unlocked_round": 1e12, "coins": 9999999999.0, "stars": {"r01": "x", "r02": 99}}
	var bgt := JSON.stringify(big)
	FileAccess.open(h.path, FileAccess.WRITE).store_string(JSON.stringify({"checksum": bgt.sha256_text(), "payload": bgt}))
	var h3 = _reload(h)
	out.clamp = {"unlocked": h3.progress.unlocked_round, "coins": h3.progress.coins, "stars": h3.progress.stars}
	if int(h3.progress.coins) > SaveS.COINS_CAP_DEFAULT or h3.progress.stars.has("r01") or int(h3.progress.stars.get("r02", 0)) > 3: _fail("clamp failed: %s" % str(out.clamp))
	var nv := {"version": 99, "unlocked_round": 5, "future": {"x": 1}}
	var nvt := JSON.stringify(nv)
	var orig := JSON.stringify({"version": 99, "checksum": nvt.sha256_text(), "payload": nvt})
	FileAccess.open(h.path, FileAccess.WRITE).store_string(orig)
	var h4 = _reload(h)
	var oks: bool = h4.save_progress()
	out.newer = {"read_only": h4.read_only, "save_ok": oks, "byte_identical": FileAccess.get_file_as_string(h.path) == orig}
	if not h4.read_only or oks or not out.newer.byte_identical: _fail("newer-version save rewritten: %s" % str(out.newer))
	tmp_nodes.append_array([h, h2, h3, h4])
	report.save_faults = out
	for n in tmp_nodes: n.free()

## 01 D21 wave_cleared, pressure waves excluded from wave counts, caps single source, preallocated pools.
func _check_waves_and_pools(content) -> void:
	var out := {}
	var rid: String = content.round_order[0]
	var rd: Dictionary = content.get_round(rid)
	var scripted := 0
	var pressure := 0
	for w in rd.waves:
		if bool(w.get("pressure", false)): pressure += 1
		else: scripted += 1
	for seed_v in [11, 22, 33]:
		var sim = SimS.new()
		sim.setup(content, rid, seed_v)
		var bot = BotS.new(2, seed_v)
		var pools := [sim.projectiles.size(), sim.fxs.size(), sim.texts.size()]
		var cleared: Array = []
		var announced: Array = []
		var dt := 1.0 / 60.0
		while not sim.ended and sim.t < 600.0:
			bot.act(sim, dt)
			sim.step(dt)
			for e in sim.events:
				if e[0] == "wave_cleared": cleared.append([int(e[1].index), snappedf(float(e[1].t), 0.01)])
				if e[0] == "wave": announced.append(int(e[1].index))
			sim.events.clear()
			sim.cues.clear()
		var grown: bool = sim.projectiles.size() != pools[0] or sim.fxs.size() != pools[1] or sim.texts.size() != pools[2]
		var w1 := []
		for c in cleared:
			if c[0] == 1: w1.append(c[1])
		out["seed_%d" % seed_v] = {"cleared": cleared, "announced": announced, "wave_total": sim.waves_total, "pools": pools, "pools_grew": grown}
		if w1.size() != 1: _fail("wave_cleared(1) count %d in %s seed %d" % [w1.size(), rid, seed_v])
		else:
			var last_spawn: float = sim.wave_times[0]
			for s in rd.waves[0].get("spawns", []):
				last_spawn = maxf(last_spawn, float(sim.wave_times[0]) + (int(s.get("count", 1)) - 1) * float(s.get("interval", 1.0)))
			if float(w1[0]) < last_spawn: _fail("wave_cleared(1) at %.2f s before the wave's last spawn %.2f s" % [w1[0], last_spawn])
			# 01 D16 design target (data question for 01/09, not an engine rule): first wave broken at 25–45 s
			if float(w1[0]) < 25.0 or float(w1[0]) > 45.0:
				balance_flags.append("r01 seed %d: wave_cleared(1) at %.2f s, outside D16 25–45 s (competent bot)" % [seed_v, w1[0]])
		var prev := 0
		for c in cleared:
			if c[0] < prev: _fail("wave_cleared out of order: %s" % str(cleared))
			prev = c[0]
		if sim.waves_total != scripted: _fail("wave total %d != scripted waves %d (pressure %d)" % [sim.waves_total, scripted, pressure])
		for a in announced:
			if a > scripted: _fail("pressure wave announced (index %d)" % a)
		var seen := {}
		for c in cleared:
			if seen.has(c[0]): _fail("wave_cleared(%d) fired twice" % c[0])
			seen[c[0]] = true
		if grown: _fail("pools grew mid-battle: %s" % str(out["seed_%d" % seed_v]))
	# no wave_cleared after a loss: passive player in r03 loses; any clear must precede the end
	var ls = SimS.new()
	ls.setup(content, content.round_order[2], 5)
	var last_clear_t := -1.0
	while not ls.ended and ls.t < 900.0:
		ls.step(1.0 / 60.0)
		for e in ls.events:
			if e[0] == "wave_cleared": last_clear_t = float(e[1].t)
		ls.events.clear()
		ls.cues.clear()
	out.loss_case = {"won": ls.won, "end_t": snappedf(ls.t, 0.1), "last_clear_t": last_clear_t}
	if last_clear_t > ls.t: _fail("wave_cleared after battle end")
	# caps: one source (data/game_config.json caps, clamped by perf.gd)
	var gc: Dictionary = content.config.get("caps", {})
	var cp: Dictionary = content.caps()
	out.caps = {"data": gc, "effective": cp}
	var sim2 = SimS.new()
	sim2.setup(content, rid, 1)
	if sim2.caps != cp: _fail("sim caps differ from Content.caps()")
	out.scripted_waves = scripted
	out.pressure_waves = pressure
	report.waves_and_pools = out

## Save.buy_upgrade (10 R3 contract C1–C5 + locked / invalid / unknown). Needs /root/Content, so the Save node joins the tree.
func _check_buy_upgrade(content) -> void:
	var s = SaveS.new()
	s.path = "user://selftest_faults/upg.json"
	DirAccess.make_dir_recursive_absolute("user://selftest_faults")
	for suf in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(s.path + suf): DirAccess.remove_absolute(s.path + suf)
	root.add_child(s)
	s.content_ref = content
	s.load_progress()
	var up := "up_melee_basic"
	var cost: int = s.upgrade_cost(up, 2)
	var out := {"cost_to_2": cost}
	var fails := []
	s.progress.coins = 500; s.save_progress()
	var c1 := [s.buy_upgrade(up, 2), s.buy_upgrade(up, 2)]
	var r = _reload(s)
	out.C1 = {"codes": c1, "disk_coins": r.progress.coins, "disk_level": r.progress.upgrades.get(up, 1)}
	if c1 != ["ok", "already_applied"] or int(r.progress.coins) != 500 - cost or int(r.progress.upgrades.get(up, 1)) != 2: fails.append("C1")
	r.free()
	s._fault = "after_tmp_write"
	var c2: String = s.buy_upgrade(up, 3)
	var r2 = _reload(s)
	out.C2 = {"code": c2, "mem_coins": s.progress.coins, "mem_level": s.upgrade_level(up), "disk_level": r2.progress.upgrades.get(up, 1)}
	if c2 != "save_failed" or int(s.progress.coins) != 500 - cost or s.upgrade_level(up) != 2 or int(r2.progress.upgrades.get(up, 1)) != 2: fails.append("C2")
	r2.free()
	s._fault = "before_final_rename"
	var c3: String = s.buy_upgrade(up, 3)
	var r3 = _reload(s)
	var lv3 := int(r3.progress.upgrades.get(up, 1))
	out.C3 = {"code": c3, "disk_level": lv3, "disk_coins": r3.progress.coins}
	if c3 != "save_uncertain" or not ((lv3 == 2 and int(r3.progress.coins) == 500 - cost) or (lv3 == 3 and int(r3.progress.coins) == 500 - cost - s.upgrade_cost(up, 3))): fails.append("C3")
	r3.free()
	s.load_progress()   # adopt whatever disk holds, like a relaunch
	s.progress.upgrades.erase(up); s.progress.coins = cost - 1; s.save_progress()
	var c4 := [s.buy_upgrade(up, 2)]
	s.progress.coins = cost; s.save_progress()
	c4.append(s.buy_upgrade(up, 2))
	out.C4 = {"codes": c4, "coins": s.progress.coins}
	if c4 != ["not_enough_coins", "ok"] or int(s.progress.coins) != 0: fails.append("C4")
	s.progress.coins = 99999; s.save_progress()
	out.invalid = s.buy_upgrade(up, 4)
	if out.invalid != "invalid_level": fails.append("invalid")
	out.unknown = s.buy_upgrade("up_does_not_exist", 2)
	if out.unknown != "unknown_id": fails.append("unknown")
	var max_l := 1
	for u in content.meta.get("upgrades", []):
		if str(u.id) == up: max_l = int(u.max_level)
	s.progress.upgrades[up] = max_l; s.save_progress()
	out.C5 = s.buy_upgrade(up, max_l + 1)
	if out.C5 != "max_level" or int(s.progress.coins) != 99999: fails.append("C5")
	# locked: a unit whose unlock_round is beyond unlocked_round
	var locked_id := ""
	for u in content.meta.get("upgrades", []):
		var tgt := str(u.get("target", ""))
		if tgt.begins_with("unit:") and content.units.has(tgt.trim_prefix("unit:")) and int(content.units[tgt.trim_prefix("unit:")].get("unlock_round", 1)) > 1:
			locked_id = str(u.id); break
	if locked_id != "":
		s.progress.unlocked_round = 1
		out.locked = [locked_id, s.buy_upgrade(locked_id, 2)]
		if out.locked[1] != "locked": fails.append("locked")
	report.buy_upgrade = out
	for f in fails: _fail("buy_upgrade %s: %s" % [f, str(out)])
	s.free()

static func _up_def(meta: Dictionary, id: String) -> Dictionary:
	for u in meta.get("upgrades", []):
		if u is Dictionary and str(u.get("id", "")) == id: return u
	return {}

## Emulates a data change in memory: price of L4 + l4_extra, max_level cut (costs trimmed), one upgrade retired.
static func _mig_data(content, orig_meta: Dictionary, cv: String, up: String, l4_extra: int, max_l: int, retire: String) -> void:
	content.meta = orig_meta.duplicate(true)
	content.content_version = cv
	var u := _up_def(content.meta, up)
	if l4_extra != 0: u.costs[2] = int(u.costs[2]) + l4_extra
	if max_l > 0:
		u.max_level = max_l
		u.costs = (u.costs as Array).slice(0, max_l - 1)
	if retire != "":
		var keep := []
		for x in content.meta.upgrades:
			if str(x.id) != retire: keep.append(x)
		content.meta.upgrades = keep

static func _mig_restore(s, bytes: PackedByteArray) -> void:
	for suf in [".bak", ".tmp"]:
		if FileAccess.file_exists(s.path + suf): DirAccess.remove_absolute(s.path + suf)
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

static func _count_files(dir: String, prefix: String) -> int:
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix): n += 1
	return n

## 10 F2 / X1 and 01 D32 content migration on a private save. Data changes are emulated in memory on `content`
## (meta + content_version) and restored at the end.
func _check_content_migration(content) -> void:
	var orig_meta: Dictionary = content.meta.duplicate(true)
	var orig_cv: String = content.content_version
	var up := "up_melee_basic"
	var wk := "up_worker"
	var out := {}
	var fails := []
	var dir := "user://selftest_faults"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("mig."): DirAccess.remove_absolute(dir.path_join(f))
	var s = SaveS.new()
	s.path = dir + "/mig.json"
	root.add_child(s)
	s.content_ref = content
	s.load_progress()
	var costs: Array = _up_def(orig_meta, up).get("costs", [])
	var wcosts: Array = _up_def(orig_meta, wk).get("costs", [])
	if costs.size() < 3 or wcosts.size() < 2 or int(_up_def(orig_meta, wk).get("max_level", 1)) < 3:
		_fail("content migration check needs %s with >= 4 levels and %s with >= 3" % [up, wk])
		s.free()
		return
	# purchases record the price paid (D32 (1))
	s.progress.coins = 5000
	s.progress.unlocked_round = 3
	s.progress.stars = {"r01": 3, "r02": 2}
	s.save_progress()
	var codes := []
	for L in [2, 3, 4]: codes.append(s.buy_upgrade(up, L))
	for L in [2, 3]: codes.append(s.buy_upgrade(wk, L))
	var paid: Dictionary = s.progress.upgrade_paid.get(up, {})
	out.paid = {"codes": codes, "record": paid.duplicate()}
	if codes != ["ok", "ok", "ok", "ok", "ok"] or int(paid.get("2", -1)) != int(costs[0]) or int(paid.get("4", -1)) != int(costs[2]): fails.append("paid_record")
	var coins0 := int(s.progress.coins)
	var a_bytes := FileAccess.get_file_as_bytes(s.path)
	# X1: price change only (nothing to migrate) -> the load writes nothing
	var cv_b := orig_cv + "-b"
	_mig_data(content, orig_meta, cv_b, up, 77, 0, "")
	var rev0 := int(s.progress.revision)
	s.load_progress()
	var pre_a: String = s.path.get_basename() + ".pre-" + orig_cv.validate_filename() + ".json"
	out.X1 = {"bytes_same": FileAccess.get_file_as_bytes(s.path) == a_bytes, "revision": int(s.progress.revision), "backup": FileAccess.file_exists(pre_a)}
	if not out.X1.bytes_same or int(s.progress.revision) != rev0 or out.X1.backup: fails.append("X1")
	s.save_progress()   # ordinary save under B: snapshot has the new L4 price, upgrade_paid keeps the real one
	var b_bytes := FileAccess.get_file_as_bytes(s.path)
	# D32 (1): cap 4 -> 3 refunds the PAID price of L4, once; notice + pre-migration backup
	var expect := coins0 + int(costs[2])
	_mig_data(content, orig_meta, orig_cv + "-c", up, 77, 3, "")
	s.load_progress()
	var pre_b: String = s.path.get_basename() + ".pre-" + cv_b.validate_filename() + ".json"
	var n1: Dictionary = s.migration_notice()
	out.cap = {"coins": int(s.progress.coins), "expect": expect, "level": s.upgrade_level(up), "paid": s.progress.upgrade_paid.get(up, {}).duplicate(),
		"notice": n1, "backup_is_pre_state": FileAccess.file_exists(pre_b) and FileAccess.get_file_as_bytes(pre_b) == b_bytes, "log": s.migration_log.duplicate()}
	s.load_progress()
	out.cap["coins_after_reload"] = int(s.progress.coins)
	if int(out.cap.coins) != expect or out.cap.level != 3 or out.cap.paid.has("4") or int(n1.get("levels", -1)) != 1 or int(n1.get("coins", -1)) != int(costs[2]) \
		or not out.cap.backup_is_pre_state or out.cap.coins_after_reload != expect: fails.append("cap_refund_paid")
	# F2a: migration save fails, an ordinary save follows in the same session, then a relaunch
	_mig_restore(s, b_bytes)
	s._fault = "after_tmp_write"
	s.load_progress()
	var pending: bool = s._migration_pending
	s._fault = ""
	var f2a_save: bool = s.save_progress()
	s.load_progress()
	out.F2a = {"pending": pending, "ordinary_save": f2a_save, "coins": int(s.progress.coins), "level": s.upgrade_level(up)}
	if not pending or not f2a_save or int(s.progress.coins) != expect or s.upgrade_level(up) != 3: fails.append("F2a")
	# F2b: outcome unknown (verified .tmp, main rotated away), ordinary save, relaunch
	_mig_restore(s, b_bytes)
	s._fault = "before_final_rename"
	s.load_progress()
	s._fault = ""
	var f2b_save: bool = s.save_progress()
	s.load_progress()
	out.F2b = {"ordinary_save": f2b_save, "coins": int(s.progress.coins), "level": s.upgrade_level(up)}
	if not f2b_save or int(s.progress.coins) != expect or s.upgrade_level(up) != 3: fails.append("F2b")
	# D32 (2): retired upgrade is refunded at the paid prices and removed; the unseen notice adds up
	_mig_data(content, orig_meta, orig_cv + "-d", up, 77, 3, wk)
	s.load_progress()
	var exp_d := expect + int(wcosts[0]) + int(wcosts[1])
	var n2: Dictionary = s.migration_notice()
	out.retire = {"coins": int(s.progress.coins), "expect": exp_d, "has_level": s.progress.upgrades.has(wk), "has_paid": s.progress.upgrade_paid.has(wk), "notice": n2}
	if int(s.progress.coins) != exp_d or out.retire.has_level or out.retire.has_paid or int(n2.get("levels", -1)) != 3 \
		or int(n2.get("coins", -1)) != int(costs[2]) + int(wcosts[0]) + int(wcosts[1]): fails.append("retire")
	# notice acknowledged -> gone after a relaunch; pre-migration backups bounded
	s.ack_migration_notice()
	s.load_progress()
	out.ack_cleared = s.migration_notice().is_empty()
	out.pre_backups = _count_files(dir, "mig.pre-")
	if not out.ack_cleared: fails.append("ack")
	if out.pre_backups < 1 or out.pre_backups > SaveS.PRE_BACKUPS_KEEP: fails.append("pre_backups")
	# 10 v0.28: quarantined copies are bounded
	for i in 5:
		var f := FileAccess.open(s.path, FileAccess.WRITE)
		f.store_string("{ corrupt %d" % i)
		f.close()
		s.load_progress()
		s.save_progress()
	out.corrupt_kept = _count_files(dir, "mig.json.corrupt-")
	if out.corrupt_kept != SaveS.CORRUPT_KEEP: fails.append("corrupt_prune")
	content.meta = orig_meta
	content.content_version = orig_cv
	report.content_migration = out
	for f in fails: _fail("content_migration %s: %s" % [f, str(out)])
	s.free()

## battle_view pure rules: death fade (07 QA-B025), clear-rect segments (08 P11), `opaque` biome layers really opaque.
func _check_view_rules(_content) -> void:
	var ViewS = load("res://src/gameplay/battle_view.gd")
	var out := {}
	var fails := []
	# death: alpha 1 for the whole animation, then DEATH_FADE on the last frame, ended by DEATH_TIME
	var da := [ViewS.death_alpha(0.0, 0.75), ViewS.death_alpha(0.75, 0.75), ViewS.death_alpha(0.9, 0.75), ViewS.death_alpha(1.05, 0.75),
		ViewS.death_alpha(1.0, 1.143), ViewS.death_alpha(SimS.DEATH_TIME, 1.143)]
	out.death_alpha = da.map(func(x): return snappedf(x, 0.001))
	if not (is_equal_approx(da[0], 1.0) and is_equal_approx(da[1], 1.0) and is_equal_approx(da[2], 0.5) and da[3] == 0.0 and is_equal_approx(da[4], 1.0) and da[5] == 0.0):
		fails.append("death_alpha")
	# clear segments
	var segs = ViewS.clear_segments(-8.0, 368.0, [[0.0, 360.0]])
	var segs2 = ViewS.clear_segments(64.5, 350.5, [[0.0, 360.0]])
	var segs3 = ViewS.clear_segments(-98.0, 458.0, [[280.0, 360.0], [0.0, 360.0]])
	out.clear_segments = [segs, segs2, segs3]
	if segs != [[-8.0, 0.0], [360.0, 368.0]] or segs2 != [] or segs3 != [[-98.0, 0.0], [360.0, 458.0]]:
		fails.append("clear_segments")
	# biome layers flagged opaque must be fully opaque in the atlas PNG (source only exists in dev trees)
	var checked := {}
	var mf = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	var biomes: Dictionary = mf.get("biomes", {}) if mf is Dictionary else {}
	for bid in biomes:
		var b: Dictionary = biomes[bid]
		var aj = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlases/%s.json" % str(b.get("atlas", ""))))
		if not (aj is Dictionary): continue
		var img_path := "res://assets/atlases/%s" % str(aj.get("image", str(b.atlas) + ".png"))
		var img: Image = null
		for layer in b.get("layers", []):
			var fr = aj.get("frames", {}).get(str(layer.get("frame", "")))
			if not (fr is Dictionary): continue
			if img == null and FileAccess.file_exists(img_path):
				img = Image.load_from_file(ProjectSettings.globalize_path(img_path))
			if img == null: break
			var minimum := 255
			for yy in int(fr.h):
				for xx in int(fr.w):
					minimum = mini(minimum, int(img.get_pixel(int(fr.x) + xx, int(fr.y) + yy).a8))
			checked["%s/%s" % [bid, layer.frame]] = {"min_alpha": minimum, "flag": bool(layer.get("opaque", false))}
			if bool(layer.get("opaque", false)) and minimum < 255:
				fails.append("opaque flag on %s/%s but min alpha %d" % [bid, layer.frame, minimum])
	out.biome_layers = checked
	report.view_rules = out
	for f in fails: _fail("view_rules %s: %s" % [f, str(out)])

## 10 v0.34 U1–U4: Save._unlock_state on synthetic orders (no files). r01–r05 cleared, r06 playable (unlocked 6).
func _check_unlock_rules() -> void:
	var s = SaveS.new()
	s.progress = SaveS.fresh()
	s.progress.stars = {"r01": 3, "r02": 3, "r03": 2, "r04": 3, "r05": 1}
	var old := ["r01", "r02", "r03", "r04", "r05", "r06", "r07", "r08", "r09", "r10"]
	var keep := {}
	for i in 6: keep[old[i]] = true
	var cases := {
		"insert2": ["r01", "r02", "n1", "n2", "r03", "r04", "r05", "r06", "r07", "r08", "r09", "r10"],
		"move_r03_end": ["r01", "r02", "r04", "r05", "r06", "r07", "r08", "r09", "r10", "r03"],
		"insert_before_r06": ["r01", "r02", "r03", "r04", "r05", "n1", "r06", "r07", "r08", "r09", "r10"],
		"same": old,
	}
	var out := {}
	var fails := []
	for k in cases:
		var order: Array = cases[k]
		var res: Dictionary = s._unlock_state(order, 0, keep, false)
		var open := []
		var p0 = s.progress.duplicate(true)
		s._set_unlock_state(res)
		for i in order.size():
			# same rule as Save.is_unlocked, on this synthetic order
			var rid := str(order[i])
			var o: bool = i + 1 <= int(s.progress.unlocked_round) or s.progress.stars.has(rid) or (i > 0 and s.progress.stars.has(str(order[i - 1]))) or (s.progress.get("open_rounds", []) as Array).has(rid)
			if o: open.append(rid)
		s.progress = p0
		out[k] = {"unlocked": res.unlocked, "extra": res.extra, "open": open}
		for rid in s.progress.stars:
			if order.has(rid) and not open.has(rid): fails.append("%s: cleared %s locked" % [k, rid])
		if order.has("r06") and not open.has("r06"): fails.append("%s: r06 was playable, now locked" % k)
		if open.has("r07"): fails.append("%s: r07 opened without being earned" % k)
	if int(out.same.unlocked) != 6 or not (out.same.extra as Array).is_empty(): fails.append("same order changed the state")
	# all cleared (unlocked 11) stays 11 when the order is unchanged (U4: no 11 -> 10 rewrite)
	s.progress.stars = {}
	for r in old: s.progress.stars[r] = 2
	var all_keep := {}
	for r in old: all_keep[r] = true
	var full: Dictionary = s._unlock_state(old, 0, all_keep, true)
	out["all_cleared"] = full
	if int(full.unlocked) != 11: fails.append("all cleared: %d" % int(full.unlocked))
	report.unlock_rules = out
	for f in fails: _fail("unlock_rules " + f)
	s.free()
