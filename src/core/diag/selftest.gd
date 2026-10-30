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
	_check_save()
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
	var refused := 0
	for i in 200:
		for id in sim.card_ids:
			sim.card_cd[id] = 0.0
			if sim.deploy(id) == "army_full": refused += 1
		for j in 3:
			if sim.army_count(-1) < sim.caps.enemy:
				sim._spawn_enemy(foe)
		sim.step(1.0 / 60.0)
	var max_ms := 0.0
	for k in 600:
		var us := Time.get_ticks_usec()
		sim.step(1.0 / 60.0)
		max_ms = maxf(max_ms, (Time.get_ticks_usec() - us) / 1000.0)
		for id in sim.card_ids:
			sim.card_cd[id] = 0.0
			sim.deploy(id)
	report.cap_test = {"refused_deploys": refused, "max_units_seen": sim.stats.max_units,
		"max_projectiles": sim.stats.max_projectiles, "pool_free": sim._unit_pool.size(),
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
