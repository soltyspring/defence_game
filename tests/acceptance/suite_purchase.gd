extends RefCounted
## Upgrade purchase fault tolerance (Save.buy_upgrade, 02). Independent re-implementation of the
## 10-research-systems C6–C13 cases (DATA_AND_BACKEND_ANALYSIS.md §9.10) inside the 07 acceptance run.
## Isolated files under user://qa07/purchase/; uses 02's debug fault hook Save._fault. Owner: 07-qa.

const Q := preload("res://tests/acceptance/qa_lib.gd")
const SaveS := preload("res://src/core/save.gd")
const DIR := "user://qa07/purchase"
const UID := "up_melee_basic"

var _holder: Node
var _nodes: Array = []

func _mk(name: String, clean := true):
	DirAccess.make_dir_recursive_absolute(DIR)
	var s = SaveS.new()
	s.path = DIR + "/" + name + ".json"
	if clean:
		for suf in ["", ".bak", ".tmp"]: Q.rm(s.path + suf)
	_holder.add_child(s)
	_nodes.append(s)
	return s

func _seed(s, coins: int) -> void:
	s.progress = SaveS.fresh()
	s.progress.coins = coins
	s.progress.unlocked_round = 3
	s.save_progress()

func _disk(path: String) -> Array:
	var r = _mk(path.get_file().get_basename(), false)
	r.path = path
	r.load_progress()
	return [int(r.progress.coins), int(r.upgrade_level(UID))]

func run(q, tree) -> void:
	q.current_suite = "purchase"
	_holder = Node.new()
	tree.root.add_child(_holder)
	var probe = _mk("probe")
	if not probe.has_method("buy_upgrade"):
		q.record("PUR-00", Q.NOT_IMPL, "Save.buy_upgrade exists", "method absent")
		_done(); return
	_seed(probe, 1000)
	var cost: int = int(probe.upgrade_cost(UID, 2))
	var lv0: int = int(probe.upgrade_level(UID))
	if cost <= 0 or lv0 != 1:
		q.record("PUR-00", Q.BLOCKED, "upgrade %s level 1 -> 2 purchasable" % UID, "cost=%d level=%d" % [cost, lv0])
		_done(); return
	var before := [500, 1]
	var after := [500 - cost, 2]
	# PUR-C6: 4 fault points x (normal | right after .bak recovery)
	var c6 := {}
	var c6_ok := true
	for mode in ["normal", "after_recovery"]:
		for fp in SaveS.FAULT_POINTS:
			var s = _mk("c6_%s_%s" % [mode, fp])
			_seed(s, 500)
			if mode == "after_recovery":
				s.save_progress()
				Q.write_text(s.path, "{ corrupt")
				s.load_progress()
			s._fault = str(fp)
			var code: String = s.buy_upgrade(UID, 2)
			var mem := [int(s.progress.coins), int(s.upgrade_level(UID))]
			var disk := _disk(s.path)
			var pair_ok: bool = disk == before or disk == after
			var mem_ok: bool = (mem == after) if code == SaveS.UPG_OK else (mem == before)
			c6["%s/%s" % [mode, fp]] = {"code": code, "fired": s.fault_fired, "mem": mem, "disk": disk}
			if not (pair_ok and mem_ok and s.fault_fired == str(fp)): c6_ok = false
	q.check("PUR-C6", "purchase killed at every fault point (normal and right after recovery): disk is (before) or (after), never half; memory matches the return code", c6_ok, str(c6), c6)
	# PUR-C7 read-only (newer version) save
	var r = _mk("c7")
	var env := Q.save_envelope({"version": 99, "unlocked_round": 3, "coins": 500})
	Q.write_text(r.path, env)
	r.load_progress()
	var c7code: String = r.buy_upgrade(UID, 2)
	q.check("PUR-C7", "purchase on a newer-version (read-only) save is refused; memory and file bytes unchanged",
		c7code == SaveS.UPG_READ_ONLY and int(r.progress.coins) == 500 and FileAccess.get_file_as_string(r.path) == env, "code=%s coins=%s bytes_same=%s" % [c7code, r.progress.coins, FileAccess.get_file_as_string(r.path) == env])
	# PUR-C8 first purchase right after recovery: ok, .bak not the corrupt file, reload shows purchase
	var b = _mk("c8")
	_seed(b, 500); b.save_progress()
	Q.write_text(b.path, "{ corrupt")
	b.load_progress()
	var c8code: String = b.buy_upgrade(UID, 2)
	var bak_ok := false
	var probe2 = SaveS.new(); bak_ok = probe2._read(b.path + ".bak") != null; probe2.free()
	q.check("PUR-C8", "first purchase after .bak recovery succeeds, leaves a valid .bak, and persists", c8code == SaveS.UPG_OK and bak_ok and _disk(b.path) == after,
		"code=%s bak_valid=%s disk=%s" % [c8code, bak_ok, _disk(b.path)])
	# PUR-C9 balance edges
	var e1 = _mk("c9a"); _seed(e1, cost)
	var e2 = _mk("c9b"); _seed(e2, cost - 1)
	var e3 = _mk("c9c"); _seed(e3, 9999999)
	var k1: String = e1.buy_upgrade(UID, 2)
	var k2: String = e2.buy_upgrade(UID, 2)
	var k3: String = e3.buy_upgrade(UID, 2)
	q.check("PUR-C9", "balance = cost buys to 0, cost-1 refused, near cap deducts exactly; never negative on disk",
		k1 == SaveS.UPG_OK and _disk(e1.path)[0] == 0 and k2 == SaveS.UPG_COINS and _disk(e2.path) == [cost - 1, 1] and k3 == SaveS.UPG_OK and _disk(e3.path)[0] == 9999999 - cost,
		"=cost:%s %s  -1:%s %s  cap:%s %s" % [k1, _disk(e1.path), k2, _disk(e2.path), k3, _disk(e3.path)])
	# PUR-C11 double tap in the same frame
	var d = _mk("c11"); _seed(d, 500)
	var t1: String = d.buy_upgrade(UID, 2)
	var t2: String = d.buy_upgrade(UID, 2)
	q.check("PUR-C11", "two identical taps: one charge, second returns already_applied", t1 == SaveS.UPG_OK and t2 == SaveS.UPG_ALREADY and _disk(d.path) == after,
		"codes=%s,%s disk=%s" % [t1, t2, _disk(d.path)])
	# PUR-C12 failed purchase then successful result, and the reverse
	var f = _mk("c12a"); _seed(f, 500)
	f._fault = "after_tmp_write"
	var fc: String = f.buy_upgrade(UID, 2)
	var rr: bool = f.record_result({"round_id": "r01", "won": true, "stars": 3, "time": 100.0, "coins": 100, "battle_uid": "qa07-c12a"}, 0)
	var fd := _disk(f.path)
	var g = _mk("c12b"); _seed(g, 500)
	g._fault = "after_tmp_write"
	var gr = g.record_result({"round_id": "r01", "won": true, "stars": 3, "time": 100.0, "coins": 100, "battle_uid": "qa07-c12b"}, 0)
	var gc: String = g.buy_upgrade(UID, 2)
	var gd := _disk(g.path)
	q.check("PUR-C12", "failed purchase + later result keeps only the result; failed result + later purchase keeps only the purchase",
		fc != SaveS.UPG_OK and fd == [600, 1] and gc == SaveS.UPG_OK and gd == after,
		"A: buy=%s result=%s disk=%s | B: result=%s buy=%s disk=%s" % [fc, rr, fd, gr, gc, gd])
	# PUR-C13 app pause right after purchase (App._notification -> Save.save_progress on the autoload)
	var save_al = tree.root.get_node_or_null("Save")
	var app = tree.root.get_node_or_null("App")
	if save_al and app:
		var old_path: String = save_al.path
		save_al.path = DIR + "/c13.json"
		for suf in ["", ".bak", ".tmp"]: Q.rm(save_al.path + suf)
		_seed(save_al, 500)
		var hc: String = save_al.buy_upgrade(UID, 2)
		app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		var hd := _disk(save_al.path)
		q.check("PUR-C13", "app pause right after a purchase does not apply it twice (desktop simulation; device NOT tested)", hc == SaveS.UPG_OK and hd == after, "code=%s disk=%s" % [hc, hd])
		save_al.path = old_path
		save_al.load_progress()
	else:
		q.record("PUR-C13", Q.BLOCKED, "pause after purchase", "Save/App autoload missing")
	_done()

func _done() -> void:
	for n in _nodes:
		if is_instance_valid(n): n.free()
	_nodes.clear()
	if is_instance_valid(_holder): _holder.free()
