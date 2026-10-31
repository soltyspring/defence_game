extends RefCounted
## Save fault-tolerance acceptance for 10-research-systems TP-01/02/06/13/14 (DATA_AND_BACKEND_ANALYSIS.md §7).
## No fault-injection hook exists yet (10→02 R6), so crash points are reproduced as the exact on-disk
## file states a kill would leave, built from real save.gd output. Owner: 07-qa.

const Q := preload("res://tests/acceptance/qa_lib.gd")
const SaveS := preload("res://src/core/save.gd")
const DIR := "user://qa07/faults"

var _holder: Node
var _nodes: Array = []

func _mk(name: String, clean := true):
	DirAccess.make_dir_recursive_absolute(DIR)
	var s = SaveS.new()
	s.path = DIR + "/" + name + ".json"
	if clean:
		for suf in ["", ".bak", ".tmp"]:
			Q.rm(s.path + suf)
	_holder.add_child(s)
	_nodes.append(s)
	return s

func _good(s, unlocked: int, coins: int) -> void:
	s.progress = SaveS.fresh()
	s.progress.unlocked_round = unlocked
	s.progress.coins = coins
	s.save_progress()

func _mv(a: String, b: String) -> void:
	DirAccess.rename_absolute(a, b)

func _valid(path: String) -> bool:
	var probe = SaveS.new()
	var ok: bool = probe._read(path) != null
	probe.free()
	return ok

func run(q, tree) -> void:
	q.current_suite = "faults"
	_holder = Node.new()
	tree.root.add_child(_holder)
	# TP-01 kill points (state after each step of tmp-write → bak-rename → final-rename)
	var res := {}
	for point in ["after_tmp_write", "after_bak_rename", "torn_tmp"]:
		var s = _mk("tp01_" + point)
		_good(s, 2, 10)            # committed state A (main) ...
		_good(s, 3, 20)            # ... committed state B (main), A in .bak
		var p: String = s.path
		match point:
			"after_tmp_write":   # new state C written to tmp, nothing renamed
				Q.write_text(p + ".tmp", Q.save_envelope({"version": 1, "unlocked_round": 4, "coins": 30}))
			"after_bak_rename":  # B moved to .bak, C still only in tmp
				Q.rm(p + ".bak"); _mv(p, p + ".bak")
				Q.write_text(p + ".tmp", Q.save_envelope({"version": 1, "unlocked_round": 4, "coins": 30}))
			"torn_tmp":          # power loss while writing tmp
				Q.write_text(p + ".tmp", "{\"version\":1,\"checksum\":\"ab")
		var r = _mk("tp01_" + point, false)
		r.load_progress()
		res[point] = int(r.progress.unlocked_round)
	var tp01_ok := true
	for k in res:
		if res[k] < 3: tp01_ok = false
	q.check("TP-01", "kill during save (after tmp write / after bak rename / torn tmp) never resets progress", tp01_ok,
		"unlocked after reload per kill point: %s (committed state = 3, older = 2, fresh = 1)" % res, res)
	# TP-02 corrupt main -> recover from .bak -> save: backup rotation must keep a valid copy
	var a = _mk("tp02")
	_good(a, 2, 10)
	_good(a, 3, 20)                 # main = B(3), bak = A(2)
	Q.write_text(a.path, "{ corrupted main")
	var b = _mk("tp02", false)
	b.load_progress()               # recovered from .bak -> A(2)
	var recovered_val := int(b.progress.unlocked_round)
	b.save_progress()               # rotation: corrupt main -> .bak, new -> main
	var bak_valid := _valid(a.path + ".bak")
	q.check("TP-02a", "after recovering from .bak and saving once, a valid backup still exists", bak_valid,
		"recovered unlocked=%d; .bak now valid=%s (the corrupt main was rotated into .bak, the only good copy was deleted)" % [recovered_val, bak_valid])
	# crash at "after_bak_rename" during that first post-recovery save: main missing, tmp = new, bak = old main
	var c = _mk("tp02c")
	_good(c, 2, 10); _good(c, 3, 20)
	Q.write_text(c.path, "{ corrupted main")
	var c2 = _mk("tp02c", false)
	c2.load_progress()
	c2.save_progress()
	_mv(c.path, c.path + ".tmp")    # reconstruct the kill point from real save output
	var c3 = _mk("tp02c", false)
	c3.load_progress()
	q.check("TP-02b", "SV-1 double fault: corrupt main, recover, kill during next save -> progress kept (not fresh)", int(c3.progress.unlocked_round) >= 2,
		"unlocked after reload=%d recovered=%s (.bak=%s, .tmp valid=%s)" % [c3.progress.unlocked_round, c3.recovered, _valid(c.path + ".bak"), _valid(c.path + ".tmp")])
	# TP-06 newer-version save must not be rewritten
	var d = _mk("tp06")
	var orig := Q.save_envelope({"version": 99, "unlocked_round": 5, "coins": 7, "future": {"x": 1}})
	Q.write_text(d.path, orig)
	var d2 = _mk("tp06", false)
	d2.load_progress()
	d2.save_progress()
	var after := FileAccess.get_file_as_string(d.path)
	q.check("TP-06", "save from a newer build (v99) is left byte-identical (no downgrade write)", after == orig,
		"file rewritten as version %s, unknown field kept=%s" % [str(JSON.parse_string(str(JSON.parse_string(after).payload)).get("version")), after.find("future") >= 0])
	# TP-13 tampered / abnormal saves
	var e = _mk("tp13")
	Q.write_text(e.path, Q.save_envelope({"version": 1, "unlocked_round": 1e12, "coins": 9999999999.0, "stars": {"r01": "x", "r02": 99}}))
	var e2 = _mk("tp13", false)
	e2.load_progress()
	var st: Dictionary = e2.progress.stars if e2.progress.stars is Dictionary else {}
	var coin_cap := 999999
	var meta = Q.read_json("res://data/meta.json")
	if meta is Dictionary:
		for cur in meta.get("currencies", []):
			if cur is Dictionary and str(cur.get("id", "")) == "gold": coin_cap = int(cur.get("max", coin_cap))
	var clamp_ok: bool = int(e2.progress.unlocked_round) <= Array(tree.root.get_node("Content").round_order).size() + 1 and int(e2.progress.coins) <= coin_cap and (not st.has("r02") or int(st.r02) <= 3) and (not st.has("r01") or typeof(st.r01) != TYPE_STRING)
	q.check("TP-13a", "out-of-range values clamped (unlocked <= rounds+1, coins <= data/meta.json gold max, stars 0..3 ints)", clamp_ok,
		"unlocked=%s coins=%s (cap %d) stars=%s" % [e2.progress.unlocked_round, e2.progress.coins, coin_cap, st])
	var deep := "1"
	for i in 600: deep = "[" + deep + "]"
	Q.write_text(e.path, Q.save_envelope({"version": 1, "unlocked_round": 2, "junk": JSON.parse_string(deep)}) if JSON.parse_string(deep) != null else "{}")
	var e3 = _mk("tp13", false)
	e3.load_progress()
	q.check("TP-13b", "deeply nested payload loads without crash", e3.progress is Dictionary, "", {"unlocked": e3.progress.get("unlocked_round")})
	var big := "x".repeat(50 * 1024 * 1024)
	Q.write_text(e.path, Q.save_envelope({"version": 1, "unlocked_round": 2, "pad": big}))
	big = ""
	var t0 := Time.get_ticks_msec()
	var e4 = _mk("tp13", false)
	e4.load_progress()
	var ms := Time.get_ticks_msec() - t0
	q.record("TP-13c", Q.PASS if e4.progress is Dictionary else Q.FAIL, "50 MB save loads without crash (load time recorded; limit owned by 08)",
		"", {"load_ms_desktop": ms, "unlocked": e4.progress.get("unlocked_round"), "note": "no size guard: whole file is read and parsed"})
	# TP-14 write failure: previous good file kept and the player is told
	var f = _mk("tp14")
	_good(f, 3, 20)
	var before := FileAccess.get_file_as_string(f.path)
	DirAccess.make_dir_recursive_absolute(f.path + ".tmp")   # a directory where the tmp file must go -> open fails
	var toasts := []
	var ev = tree.root.get_node_or_null("Events")
	var cb := func(k, _a): toasts.append(str(k))
	if ev: ev.toast.connect(cb)
	f.progress.coins = 999
	var ok: bool = f.save_progress()
	if ev: ev.toast.disconnect(cb)
	DirAccess.remove_absolute(f.path + ".tmp")
	q.check("TP-14a", "write failure: save_progress returns false and the previous file is intact", not ok and FileAccess.get_file_as_string(f.path) == before,
		"ok=%s intact=%s err=%s" % [ok, FileAccess.get_file_as_string(f.path) == before, f.last_error])
	q.check("TP-14b", "write failure is surfaced to the player (toast/signal)", not toasts.is_empty(), "no toast or signal emitted; last_error only ('%s')" % f.last_error)
	for n in _nodes: n.free()
	_nodes.clear()
	_holder.free()
