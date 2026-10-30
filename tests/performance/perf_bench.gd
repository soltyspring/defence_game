extends SceneTree
## 08-performance headless CPU/memory bench (DESKTOP PROXY — never phone evidence).
## Run from workspace root (or via tools/perf/run_perf.ps1):
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/performance/perf_bench.gd -- [--out=<abs.json>] [--quick] [--strict] [--git=<sha>]
## Never imports, never opens an editor, never touches the real save (uses user://perf/ only).
## Measures: content load latency, per-round sim step distribution (bot-driven), sustained combat at
## N units per side (scaling curve up to caps), HUD snapshot cost, object/static-memory drift (leak and
## pooling proxy), save/load latency and size. Budgets are PROVISIONAL (docs/performance/BUDGETS.md).
## Exit: 0 = harness ran (budget results in JSON); 1 = harness error, or with --strict an ADOPTED check failed, or with
## --strict-all ANY check failed. Checks are tagged "adopted" (release invariants already in contracts: no leaked or unpooled
## objects, ENGINE.md §7) or "provisional" (numeric targets awaiting device data). --strict never fails on provisional targets.
## Owner: 08-performance.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const SaveS := preload("res://src/core/save.gd")

const STEP := 1.0 / 60.0
## Assumed desktop->mid-tier-phone CPU slowdown for GDScript. UNCALIBRATED ASSUMPTION until a real
## device run (docs/performance/ANDROID_PROFILING.md §5) replaces it.
const PHONE_SLOWDOWN_ASSUMED := 4.0
## ENGINE.md §7: battle sim <= 2 ms/frame on mid tier at cap. Desktop proxy gate = 2.0 / slowdown.
const SIM_BUDGET_MID_MS := 2.0
const SAVE_BUDGET_MS := 50.0        # provisional: save must not hitch a frame visibly on lifecycle pause
const CONTENT_LOAD_BUDGET_MS := 200.0

var report := {}
var checks := []
var quick := false
var strict := false
var strict_all := false
var out_path := ""

func _initialize() -> void:
	_run.call_deferred()   # root (and autoloads) are inside the tree only after _initialize returns

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	quick = args.has("--quick")
	strict_all = args.has("--strict-all")
	strict = args.has("--strict") or strict_all
	var git_sha := ""
	var contended := -1
	var selfcheck := ""
	for a in args:
		if a.begins_with("--out="): out_path = a.get_slice("=", 1)
		if a.begins_with("--git="): git_sha = a.get_slice("=", 1)
		if a.begins_with("--contended="): contended = int(a.get_slice("=", 1))
		if a.begins_with("--selfcheck="): selfcheck = a.get_slice("=", 1)
	if out_path == "":
		out_path = ProjectSettings.globalize_path("res://build/perf/bench_latest.json")
	var t0 := Time.get_ticks_msec()
	# CONTENDED = other Godot/CLI processes were running (count supplied by tools/perf/run_perf.ps1). Such runs are
	# diagnostics for relative cost/scaling only, never an isolated baseline.
	report.evidence_class = "CONTENDED_DESKTOP_PROXY" if contended > 0 else ("DESKTOP_PROXY" if contended == 0 else "DESKTOP_PROXY_UNVERIFIED_ISOLATION")
	report.concurrent_godot_processes = contended
	report.note = "Desktop headless numbers from a DEBUG editor binary. Not phone evidence. Phone gate uses an UNCALIBRATED x%.1f slowdown assumption." % PHONE_SLOWDOWN_ASSUMED
	report.env = _env(git_sha)
	report.mode = "quick" if quick else "full"
	if selfcheck != "":
		# Exit-semantics regression mode (tests/performance/test_bench_semantics.ps1): no measurements, one synthetic check.
		report.mode = "selfcheck"
		# pass | fail (a provisional check fails) | fail_adopted (an adopted check fails)
		_check("selfcheck_provisional", 1.0 if selfcheck == "fail" else 0.0, 0.5, "synthetic")
		_check("selfcheck_adopted", 1.0 if selfcheck == "fail_adopted" else 0.0, 0.5, "synthetic", true)
		_finish(0, t0)
		return
	report.noise = _noise_floor()
	var content = _bench_content_load()
	if content == null:
		_finish(1, t0)
		return
	_bench_rounds(content)
	_bench_scaling(content)
	_bench_sections(content)
	_bench_snapshot(content)
	_bench_leak(content)
	_bench_save()
	content.free()
	_finish(0, t0)

## Machine jitter: a constant ~0.2 ms GDScript workload timed repeatedly. Large max/p99 versus p50 here
## means OS preemption (other CLIs/Godot instances), so sim max values must be read against this floor.
func _noise_floor() -> Dictionary:
	var us := PackedFloat32Array()
	var acc := 0.0
	for r in (600 if quick else 3000):
		var t := Time.get_ticks_usec()
		for i in 2000: acc += sqrt(float(i))
		us.append(float(Time.get_ticks_usec() - t))
	var st := _stats(us)
	st.workload = "2000x sqrt+add per sample"
	st.p99_over_p50 = snappedf(st.p99_ms / maxf(0.0001, st.p50_ms), 0.01)
	st.sink = acc > 0.0
	return st

func _env(git_sha: String) -> Dictionary:
	var v := Engine.get_version_info()
	return {
		"engine": "%s.%s.%s.%s" % [v.major, v.minor, v.patch, v.status],
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "cpu_threads": OS.get_processor_count(),
		"debug_build": OS.is_debug_build(), "display": DisplayServer.get_name(),
		"time": Time.get_datetime_string_from_system(false, true), "git": git_sha,
		"step_s": STEP,
	}

func _finish(code: int, t0: int) -> void:
	report.checks = checks
	var fails := 0
	for c in checks:
		if c.result == "FAIL": fails += 1
	report.budget_fails = fails
	var adopted_fails := 0
	for c in checks:
		if c.result == "FAIL" and c.status == "adopted": adopted_fails += 1
	report.adopted_fails = adopted_fails
	report.provisional_fails = fails - adopted_fails
	var failed_ids := PackedStringArray()
	for c in checks:
		if c.result == "FAIL": failed_ids.append(c.id)
	report.failed_checks = Array(failed_ids)
	report.harness = "OK" if code == 0 else "ERROR"
	report.budgets = "PASS" if fails == 0 else "FAIL"
	report.strict = "all" if strict_all else ("adopted" if strict else "off")
	if code == 0 and ((strict_all and fails > 0) or (strict and adopted_fails > 0)):
		code = 1
	report.exit_code = code
	report.total_ms = Time.get_ticks_msec() - t0
	var txt := JSON.stringify(report, "  ")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
	else:
		printerr("cannot write ", out_path)
	print(txt)
	for c in checks:
		print("[perf] %-4s %-11s %s: %s (budget %s)" % [c.result, c.status, c.id, str(c.value), str(c.budget)])
	print("[perf] report ", out_path)

	# Harness completion and budget verdict are reported separately: "harness=OK budgets=FAIL" is NOT a pass.
	# Default exit 0 = harness ran. --strict: exit 1 on ADOPTED failures only. --strict-all: exit 1 on any failure.
	print("PERF_BENCH harness=%s budgets=%s fails=%d adopted_fails=%d provisional_fails=%d [%s] class=%s strict=%s exit=%d" % [
		report.harness, report.budgets, fails, adopted_fails, fails - adopted_fails, ",".join(failed_ids), report.evidence_class, report.strict, code])
	quit(code)

func _check(id: String, value: float, budget: float, note := "", adopted := false) -> void:
	checks.append({"id": id, "value": snappedf(value, 0.0001), "budget": budget, "status": "adopted" if adopted else "provisional",
		"result": "PASS" if value <= budget else "FAIL", "note": note})

static func _stats(us: PackedFloat32Array) -> Dictionary:
	if us.is_empty():
		return {"n": 0}
	var a := us.duplicate()
	a.sort()
	var s := 0.0
	for x in a: s += x
	var n := a.size()
	return {"n": n, "avg_ms": snappedf(s / n / 1000.0, 0.0001),
		"p50_ms": snappedf(a[n / 2] / 1000.0, 0.0001),
		"p95_ms": snappedf(a[mini(n - 1, int(n * 0.95))] / 1000.0, 0.0001),
		"p99_ms": snappedf(a[mini(n - 1, int(n * 0.99))] / 1000.0, 0.0001),
		"max_ms": snappedf(a[n - 1] / 1000.0, 0.0001)}

# ---------------------------------------------------------------- content
func _bench_content_load():
	var times := PackedFloat32Array()
	var content = null
	var reps := 5 if quick else 20
	for i in reps:
		var us := Time.get_ticks_usec()
		var c = ContentS.new()
		c.load_all("res://data")
		times.append(float(Time.get_ticks_usec() - us))
		if content == null:
			content = c
		else:
			c.free()
	if content == null or content.round_order.is_empty():
		printerr("content load failed")
		return null
	var st := _stats(times)
	st.first_ms = snappedf(times[0] / 1000.0, 0.001)
	st.rounds = content.round_order.size()
	st.units = content.units.size()
	st.warnings = Array(content.warnings)
	report.content_load = st
	_check("content_load_first_ms", st.first_ms, CONTENT_LOAD_BUDGET_MS, "JSON parse of data/**, desktop")
	return content

# ---------------------------------------------------------------- rounds
## Records every step; keeps the SPIKE_KEEP slowest steps with context for root-cause analysis.
const SPIKE_KEEP := 5
func _run_timed(sim, bot, max_t: float, step_us: PackedFloat32Array, spikes: Array, label: String) -> void:
	while not sim.ended and sim.t < max_t:
		if bot: bot.act(sim, STEP)
		var ev0: int = sim.events.size()
		var us := Time.get_ticks_usec()
		sim.step(STEP)
		var d := float(Time.get_ticks_usec() - us)
		step_us.append(d)
		if spikes.size() < SPIKE_KEEP or d > spikes[spikes.size() - 1].us:
			var evs := []
			for i in range(ev0, sim.events.size()): evs.append(str(sim.events[i][0]))
			spikes.append({"us": d, "where": label, "t": snappedf(sim.t, 0.01), "step_index": step_us.size() - 1,
				"units": sim.players.size() + sim.enemies.size(), "spawn_queue": sim.spawn_queue.size(), "events": evs})
			spikes.sort_custom(func(a, b): return a.us > b.us)
			if spikes.size() > SPIKE_KEEP: spikes.pop_back()

func _bench_rounds(content) -> void:
	var rows := []
	var all_us := PackedFloat32Array()
	var seeds := [11] if quick else [11, 22, 33]
	for rid in content.round_order:
		var us := PackedFloat32Array()
		var row := {"round": rid, "seeds": seeds, "won": [], "t": [], "max_units": 0, "max_projectiles": 0, "refused_spawns": 0}
		var spikes := []
		for sv in seeds:
			var sim = SimS.new()
			sim.setup(content, rid, sv)
			_run_timed(sim, BotS.new(2, sv), 900.0, us, spikes, "%s/seed%d" % [rid, sv])
			row.won.append(sim.won)
			row.t.append(snappedf(sim.t, 0.1))
			row.max_units = maxi(row.max_units, sim.stats.max_units)
			row.max_projectiles = maxi(row.max_projectiles, sim.stats.max_projectiles)
			row.refused_spawns += sim.refused_spawns
		row.step = _stats(us)
		for s in spikes:
			s.ms = snappedf(s.us / 1000.0, 0.001)
			s.erase("us")
		row.spikes = spikes
		all_us.append_array(us)
		rows.append(row)
	report.rounds = rows
	report.rounds_all_steps = _stats(all_us)
	_check("round_step_p99_ms_desktop", report.rounds_all_steps.p99_ms, SIM_BUDGET_MID_MS / PHONE_SLOWDOWN_ASSUMED,
		"competent bot, all rounds; gate = mid-tier 2 ms / assumed slowdown")

# ---------------------------------------------------------------- scaling
## Holds N living units per side (refilled before every step) in two modes:
##   walk  = units spawn at their bases and march (targeting scans only),
##   clash = units spawn in mid-lane so melee, projectiles, fx and damage text are all active.
func _bench_scaling(content) -> void:
	var player_ids := []
	var enemy_ids := []
	for u in content.units.values():
		var tags: Array = u.get("tags", [])
		if tags.has("boss"): continue
		if str(u.faction) == "player": player_ids.append(str(u.id))
		elif str(u.faction) == "enemy": enemy_ids.append(str(u.id))
	if player_ids.is_empty() or enemy_ids.is_empty():
		report.scaling = {"skipped": "no player/enemy unit ids"}
		return
	var last_round: String = content.round_order[content.round_order.size() - 1]
	var ns := [6, 18, 36] if quick else [6, 12, 18, 24, 30, 36]
	var measured := 300 if quick else 1200
	var out := {"round": last_round, "measured_steps": measured, "warmup_steps": 240}
	for mode in ["walk", "clash"]:
		var rows := []
		for n in ns:
			# best-of-R by p95 (standard practice against OS preemption); spread kept for honesty
			var best: Dictionary = {}
			var p95s := []
			for r in (1 if quick else 3):
				var row := _scale_row(content, last_round, mode, n, measured, player_ids, enemy_ids)
				p95s.append(row.p95_ms)
				if best.is_empty() or row.p95_ms < best.p95_ms: best = row
			best.p95_runs = p95s
			rows.append(best)
		out[mode] = rows
	report.scaling = out
	var cap_row: Dictionary = out.clash[out.clash.size() - 1]
	_check("cap_clash_step_p95_ms_desktop", cap_row.p95_ms, SIM_BUDGET_MID_MS / PHONE_SLOWDOWN_ASSUMED,
		"36/side sustained mid-lane combat, best-of-runs; gate = mid-tier 2 ms / assumed slowdown")
	_check("cap_clash_step_avg_ms_desktop", cap_row.avg_ms, SIM_BUDGET_MID_MS / PHONE_SLOWDOWN_ASSUMED, "mean step at cap")
	_check("cap_clash_unexplained_object_drift", absf(cap_row.object_drift_unexplained), 0.0, "objects not held by sim pools (ENGINE.md §7 pooling)", true)

func _scale_row(content, rid: String, mode: String, n: int, measured: int, pids: Array, eids: Array) -> Dictionary:
	var sim = SimS.new()
	sim.setup(content, rid, 77)
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	sim.ai_think = 1e12
	for b in [sim.player_base, sim.enemy_base]:
		b.hp = 1e12
		b.hp_max = 1e12
	var na: int = mini(n, sim.caps.ally)
	var ne: int = mini(n, sim.caps.enemy)
	var us := PackedFloat32Array()
	var obj0 := 0
	var mem0 := 0
	var pool0 := 0
	var units_seen := 0
	var proj_alive_max := 0
	var refills := 0
	for i in 240 + measured:
		refills += _refill(sim, pids, eids, na, ne, i, mode == "clash")
		if i == 240:
			obj0 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			mem0 = OS.get_static_memory_usage()
			pool0 = _pooled_objects(sim)
			refills = 0
		var t := Time.get_ticks_usec()
		sim.step(STEP)
		var d := float(Time.get_ticks_usec() - t)
		sim.events.clear()   # battle.gd drains events every frame; keep harness memory flat
		if i >= 240:
			us.append(d)
			units_seen = maxi(units_seen, sim.players.size() + sim.enemies.size())
			var pa := 0
			for p in sim.projectiles:
				if p.alive: pa += 1
			proj_alive_max = maxi(proj_alive_max, pa)
	var row := _stats(us)
	row.mode = mode
	row.n_per_side = n
	row.units_max_seen = units_seen
	row.respawns_per_s = snappedf(refills / (measured * STEP), 0.1)
	row.projectiles_alive_max = proj_alive_max
	row.pool_sizes = {"projectiles": sim.projectiles.size(), "fx": sim.fxs.size(), "text": sim.texts.size(), "unit_free": sim._unit_pool.size()}
	var drift := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - obj0
	row.object_drift = drift
	row.pool_growth = _pooled_objects(sim) - pool0
	row.object_drift_unexplained = drift - row.pool_growth   # objects not held by any sim pool = leak/churn
	row.static_mem_drift_bytes = OS.get_static_memory_usage() - mem0
	return row

## Objects owned by sim containers (live + free pools + hero). Lazy pool growth up to caps is expected.
static func _pooled_objects(sim) -> int:
	return sim.players.size() + sim.enemies.size() + sim._unit_pool.size() + sim.projectiles.size() + sim.fxs.size() + sim.texts.size() + 1

## Tops both sides up to na/ne living units. Returns number of units created.
func _refill(sim, pids: Array, eids: Array, na: int, ne: int, k: int, clash: bool) -> int:
	var made := 0
	var mid: float = sim.L * 0.5
	var guard := 0
	while sim.army_count(1) < na and guard < 64:
		var id: String = pids[(k + guard) % pids.size()]
		var off := float((k + guard) % 9) * 4.0
		var x: float = (mid - 24.0 - off) if clash else (sim.player_base.x + 22.0 + off)
		sim.players.append(sim._new_unit(sim.content.get_unit(id), 1, x))
		guard += 1
		made += 1
	guard = 0
	while sim.army_count(-1) < ne and guard < 64:
		var u2 = sim._spawn_enemy(eids[(k + guard) % eids.size()])
		var off2 := float((k + guard) % 9) * 4.0
		u2.x = (mid + 24.0 + off2) if clash else (u2.x - off2)
		guard += 1
		made += 1
	return made

# ---------------------------------------------------------------- sections
## Per-subsystem cost at cap (36/side clash). Mirrors BattleSim.step() section by section; the mirror is
## verified against the real step() on an identical seed/state and flagged STALE if 02 changes step().
func _bench_sections(content) -> void:
	var pids := []
	var eids := []
	for u in content.units.values():
		if (u.get("tags", []) as Array).has("boss"): continue
		if str(u.faction) == "player": pids.append(str(u.id))
		elif str(u.faction) == "enemy": eids.append(str(u.id))
	if pids.is_empty() or eids.is_empty(): return
	var rid: String = content.round_order[content.round_order.size() - 1]
	var a = _stress_sim(content, rid)
	var b = _stress_sim(content, rid)
	for i in 240:
		_refill(a, pids, eids, 36, 36, i, true)
		_refill(b, pids, eids, 36, 36, i, true)
		a.step(STEP)
		_mirror_step(b, STEP, {})
		a.events.clear()
		b.events.clear()
	var fidelity := _state_hash(a) == _state_hash(b)
	var acc := {}
	var scan_us := PackedFloat32Array()
	var count_us := PackedFloat32Array()
	var steps := 300 if quick else 1200
	for i in steps:
		_refill(b, pids, eids, 36, 36, 240 + i, true)
		# isolated micro-costs on the current state (read-only calls)
		var t := Time.get_ticks_usec()
		for u in b.players: b._find_target(u)
		for u in b.enemies: b._find_target(u)
		scan_us.append(float(Time.get_ticks_usec() - t))
		t = Time.get_ticks_usec()
		for r in 10: b.army_count(1)
		count_us.append(float(Time.get_ticks_usec() - t) / 10.0)
		_mirror_step(b, STEP, acc)
		b.events.clear()
	var total := 0.0
	for k in acc: total += acc[k]
	var rows := {}
	for k in acc:
		rows[k] = {"avg_ms": snappedf(acc[k] / steps / 1000.0, 0.0001), "share": snappedf(acc[k] / maxf(1.0, total), 0.001)}
	report.sections = {"mirror_matches_step": fidelity, "status": "OK" if fidelity else "STALE_MIRROR (numbers indicative only)",
		"state": "36/side clash, round %s" % rid, "steps": steps, "sections": rows,
		"step_total_avg_ms": snappedf(total / steps / 1000.0, 0.0001),
		"find_target_all_units": _stats(scan_us), "army_count_one_call": _stats(count_us),
		"units_avg": b.players.size() + b.enemies.size()}

func _stress_sim(content, rid: String):
	var sim = SimS.new()
	sim.setup(content, rid, 77)
	sim.spawn_queue.clear()
	sim.trickle_next = -1.0
	sim.ai_think = 1e12
	for bb in [sim.player_base, sim.enemy_base]:
		bb.hp = 1e12
		bb.hp_max = 1e12
	return sim

static func _state_hash(sim) -> String:
	var s := "%f|%f|%f|%d|%d" % [sim.t, sim.gold, sim.mana, sim.players.size(), sim.enemies.size()]
	for u in sim.players: s += "|%.3f,%.3f" % [u.x, u.hp]
	for u in sim.enemies: s += "|%.3f,%.3f" % [u.x, u.hp]
	for p in sim.projectiles: s += "|%s%.3f" % [p.alive, p.x]
	return s.sha256_text()

## Exact copy of BattleSim.step() (src/gameplay/battle_sim.gd) with timers between subsystems.
func _mirror_step(s, dt: float, acc: Dictionary) -> void:
	if s.ended or s.paused:
		return
	var t0 := Time.get_ticks_usec()
	s.t += dt
	s.gold = minf(s.gold_max, s.gold + s.income() * dt)
	s.mana = minf(s.mana_max, s.mana + s.mana_regen * dt)
	for k in s.card_cd: s.card_cd[k] = maxf(0.0, s.card_cd[k] - dt)
	for k in s.skill_cd: s.skill_cd[k] = maxf(0.0, s.skill_cd[k] - dt)
	s.player_base.flash = maxf(0.0, s.player_base.flash - dt)
	s.enemy_base.flash = maxf(0.0, s.enemy_base.flash - dt)
	s._step_wave_announce()
	s._step_spawns()
	s._step_trickle()
	s._step_ai(dt)
	s._step_hp_triggers()
	s._step_delayed()
	var t1 := Time.get_ticks_usec()
	s._step_aura()
	var t2 := Time.get_ticks_usec()
	s._step_hero(dt)
	var t3 := Time.get_ticks_usec()
	for u in s.players: s._step_unit(u, dt)
	for u in s.enemies: s._step_unit(u, dt)
	var t4 := Time.get_ticks_usec()
	s._step_towers(dt)
	var t5 := Time.get_ticks_usec()
	s._step_projectiles(dt)
	var t6 := Time.get_ticks_usec()
	s._step_fx(dt)
	var t7 := Time.get_ticks_usec()
	s._reap()
	s.stats.max_units = maxi(s.stats.max_units, s.players.size() + s.enemies.size())
	if s.t >= s.TIME_LIMIT and not s.ended:
		s._end(false)
	var t8 := Time.get_ticks_usec()
	if acc != null:
		for pair in [["economy_waves_ai", t1 - t0], ["aura", t2 - t1], ["hero", t3 - t2], ["units", t4 - t3],
				["towers", t5 - t4], ["projectiles", t6 - t5], ["fx_text", t7 - t6], ["reap", t8 - t7]]:
			acc[pair[0]] = acc.get(pair[0], 0.0) + float(pair[1])

# ---------------------------------------------------------------- snapshot
func _bench_snapshot(content) -> void:
	var sim = SimS.new()
	sim.setup(content, content.round_order[content.round_order.size() - 1], 5)
	var bot = BotS.new(2, 5)
	for i in 3600:
		bot.act(sim, STEP)
		sim.step(STEP)
		if sim.ended: break
	var us := PackedFloat32Array()
	for i in (200 if quick else 1000):
		var t := Time.get_ticks_usec()
		var s: Dictionary = sim.snapshot()
		us.append(float(Time.get_ticks_usec() - t))
		if s.is_empty(): break
	var st := _stats(us)
	st.at_t = snappedf(sim.t, 0.1)
	st.units = sim.players.size() + sim.enemies.size()
	st.rate_hz_engine = 10
	report.hud_snapshot = st

# ---------------------------------------------------------------- leak
## Runs full battles back-to-back; objects must return to baseline after sims are released.
func _bench_leak(content) -> void:
	var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem0 := OS.get_static_memory_usage()
	var reps := 2 if quick else 5
	for r in reps:
		var sim = SimS.new()
		sim.setup(content, content.round_order[r % content.round_order.size()], 100 + r)
		var bot = BotS.new(2, 100 + r)
		while not sim.ended and sim.t < 900.0:
			bot.act(sim, STEP)
			sim.step(STEP)
		sim = null
		bot = null
	var obj1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var mem1 := OS.get_static_memory_usage()
	report.leak = {"battles": reps, "object_delta": obj1 - obj0, "static_mem_delta_bytes": mem1 - mem0,
		"note": "after releasing the sim; >0 means objects outlive a battle (RefCounted cycle or cache)"}
	_check("battle_object_leak", absf(obj1 - obj0), 0.0, "objects retained after %d full battles" % reps, true)

# ---------------------------------------------------------------- save
func _bench_save() -> void:
	DirAccess.make_dir_recursive_absolute("user://perf")
	var s = SaveS.new()
	s.path = "user://perf/perf_save.json"
	for f in [s.path, s.path + ".bak", s.path + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(f)
	root.add_child(s)   # in-tree like the real autoload (save emits Events.progress_changed); _ready loads the perf path
	s.load_progress()
	# realistic late-game payload: 30 rounds of stars/best times, upgrades, settings
	for i in 30:
		var rid := "r%02d" % (i + 1)
		s.progress.stars[rid] = 3
		s.progress.best_time[rid] = 95.5 + i
	s.progress["upgrades"] = {}
	for i in 12:
		s.progress.upgrades["up_%d" % i] = 5
	var reps := 10 if quick else 50
	var su := PackedFloat32Array()
	var lu := PackedFloat32Array()
	for i in reps:
		s.progress.coins = i
		var t := Time.get_ticks_usec()
		if not s.save_progress():
			report.save = {"error": s.last_error}
			s.free()
			return
		su.append(float(Time.get_ticks_usec() - t))
	for i in reps:
		var t2 := Time.get_ticks_usec()
		s.load_progress()
		lu.append(float(Time.get_ticks_usec() - t2))
	var size := 0
	var fa := FileAccess.open(s.path, FileAccess.READ)
	if fa:
		size = fa.get_length()
		fa.close()
	report.save = {"save": _stats(su), "load": _stats(lu), "file_bytes": size, "recovered": s.recovered,
		"path": ProjectSettings.globalize_path(s.path),
		"note": "desktop SSD/NTFS; phone flash + fsync behaviour differs, measure on device"}
	_check("save_p95_ms_desktop", report.save.save.p95_ms, SAVE_BUDGET_MS, "atomic tmp+verify+rename")
	s.free()
