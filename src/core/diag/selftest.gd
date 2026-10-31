extends SceneTree
## Headless engine self-test. Run:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://src/core/diag/selftest.gd
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
				if absf(da - db) > 0.0001:
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
