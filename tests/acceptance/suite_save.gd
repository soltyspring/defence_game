extends RefCounted
## Save corruption / recovery acceptance beyond 02's selftest. Uses isolated files under
## user://qa07/ only; never touches the real user://save.json. Owner: 07-qa. Contract: INTERFACES.md §3.

const Q := preload("res://tests/acceptance/qa_lib.gd")
const SaveS := preload("res://src/core/save.gd")
const DIR := "user://qa07"

var _nodes: Array = []
var _holder: Node

func _fresh(name: String):
	DirAccess.make_dir_recursive_absolute(DIR)
	var s = SaveS.new()
	s.path = DIR + "/" + name + ".json"
	for suf in ["", ".bak", ".tmp"]:
		Q.rm(s.path + suf)
	_nodes.append(s)
	_holder.add_child(s)   # in-tree like the autoload (save_progress looks up /root/Events)
	return s

func _reload(path: String):
	var s = SaveS.new()
	s.path = path
	_holder.add_child(s)   # _ready() -> load_progress()
	_nodes.append(s)
	return s

func run(q, _tree) -> void:
	q.current_suite = "save"
	_holder = Node.new()
	_holder.name = "QaSaveHolder"
	_tree.root.add_child(_holder)
	# SAVE-01 both copies corrupt -> defaults, flagged, and the next save is clean
	var a = _fresh("both_corrupt")
	Q.write_text(a.path, "{ broken")
	Q.write_text(a.path + ".bak", "\u0000\u0000garbage")
	a.load_progress()
	var ok1: bool = a.recovered and int(a.progress.unlocked_round) == 1 and int(a.progress.coins) == 0
	var saved: bool = a.save_progress()
	var a2 = _reload(a.path)
	q.check("SAVE-01", "main+bak corrupt -> fresh defaults, recovered=true, next save loads clean", ok1 and saved and not a2.recovered,
		"recovered=%s unlocked=%s saved=%s reload_recovered=%s err=%s" % [a.recovered, a.progress.get("unlocked_round"), saved, a2.recovered, a.last_error])
	# SAVE-02 zero-byte main file (power loss during write), no bak
	var b = _fresh("zero_byte")
	Q.write_text(b.path, "")
	b.load_progress()
	q.check("SAVE-02", "zero-byte save, no .bak -> defaults with recovered=true (user is told)", b.recovered and int(b.progress.unlocked_round) == 1, "recovered=%s" % b.recovered)
	# SAVE-03 crash between renames: main missing, .bak (older) + .tmp (newer) present
	var c = _fresh("mid_rename")
	Q.write_text(c.path + ".bak", Q.save_envelope({"version": 1, "unlocked_round": 2, "coins": 10, "stars": {"r01": 1}}))
	Q.write_text(c.path + ".tmp", Q.save_envelope({"version": 1, "unlocked_round": 3, "coins": 20, "stars": {"r01": 1, "r02": 2}}))
	c.load_progress()
	var got := int(c.progress.unlocked_round)
	q.check("SAVE-03", "main missing after interrupted rename -> progress restored from .bak (no reset to round 1)", got >= 2,
		"unlocked_round=%d (bak=2, newer verified tmp=3)" % got, {"restored_unlocked": got, "note": "tmp newer than bak is ignored; acceptable but loses last write"})
	var c_saved: bool = c.save_progress()
	q.check("SAVE-04", "save succeeds when a stale .tmp is left over", c_saved and not FileAccess.file_exists(c.path + ".tmp"), "saved=%s tmp_left=%s err=%s" % [c_saved, FileAccess.file_exists(c.path + ".tmp"), c.last_error])
	# SAVE-05 checksum-valid payload with hostile types (edited/old build/partial migration)
	var d = _fresh("hostile_types")
	Q.write_text(d.path, Q.save_envelope({"version": 1, "unlocked_round": "abc", "coins": -50, "stars": [3, 2], "best_time": null, "settings": "loud"}))
	d.load_progress()
	var types_ok: bool = d.progress.stars is Dictionary and d.progress.best_time is Dictionary and d.progress.settings is Dictionary \
		and int(d.progress.coins) >= 0 and int(d.progress.unlocked_round) >= 1
	q.check("SAVE-05", "wrong-typed fields in a valid envelope are normalised (stars/best_time/settings dicts, coins>=0)", types_ok,
		"stars=%s best_time=%s settings=%s coins=%s unlocked=%s" % [type_string(typeof(d.progress.stars)), type_string(typeof(d.progress.best_time)), type_string(typeof(d.progress.settings)), d.progress.coins, d.progress.unlocked_round])
	if types_ok:
		d.record_result({"round_id": "r01", "won": true, "stars": 2, "time": 80.0, "coins": 5}, 0)
		var d2 = _reload(d.path)
		q.check("SAVE-06", "record_result after normalisation persists stars/unlock", int(d2.progress.stars.get("r01", 0)) == 2 and int(d2.progress.unlocked_round) >= 2)
	else:
		q.record("SAVE-06", Q.BLOCKED, "record_result after hostile-type load", "SAVE-05 failed; calling record_result would hit a script error (Array.get / null.get)")
	# SAVE-07 result recording semantics
	var e = _fresh("semantics")
	e.load_progress()
	e.record_result({"round_id": "r01", "won": true, "stars": 3, "time": 70.0, "coins": 100}, 0)
	e.record_result({"round_id": "r01", "won": true, "stars": 1, "time": 99.0, "coins": 30}, 0)
	e.record_result({"round_id": "r02", "won": false, "stars": 0, "time": 40.0, "coins": 4}, 1)
	var e2 = _reload(e.path)
	var p: Dictionary = e2.progress
	q.check("SAVE-07", "best stars kept, best time kept, loss does not unlock/award stars, coins accumulate, persisted", int(p.stars.get("r01", 0)) == 3 \
		and is_equal_approx(float(p.best_time.get("r01", 0)), 70.0) and not p.stars.has("r02") and int(p.unlocked_round) == 2 and int(p.coins) == 134,
		"stars=%s best=%s unlocked=%s coins=%s" % [p.stars, p.best_time, p.unlocked_round, p.coins])
	# SAVE-08 future version file (downgrade): must not crash; report behaviour
	var f = _fresh("future")
	Q.write_text(f.path, Q.save_envelope({"version": 99, "unlocked_round": 5, "coins": 7, "new_field": {"x": 1}}))
	f.load_progress()
	q.record("SAVE-08", Q.PASS if int(f.progress.unlocked_round) == 5 else Q.FAIL, "save from newer build (v99) loads without losing progress",
		"" if int(f.progress.unlocked_round) == 5 else "unlocked=%s" % f.progress.unlocked_round,
		{"version_after_load": f.progress.version, "kept_unknown_field": f.progress.has("new_field"), "note": "version is rewritten to 1 on next save; downgrade policy unspecified"})
	for n in _nodes:
		n.free()
	_nodes.clear()
	_holder.free()
