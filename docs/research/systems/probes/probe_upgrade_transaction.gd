extends SceneTree
## Research probe (10-research-systems), R3 "generic transaction" for meta upgrade purchases.
## Question: does buying an upgrade deduct coins and raise the level in ONE atomic save, idempotently?
## Uses the real autoloads; redirects the Save autoload to user://probe10/ before anything can write.
## Run:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_upgrade_transaction.gd --quit-after 900
## Prints "PROBE10_UPGRADE_TX {json}" and exits 0. Evidence for 02/07, not a test suite.
##
## Part A (always): looks for a purchase API on Save/App. If none exists, reports NOT_IMPLEMENTED.
## Part B (always): shows, with the REAL save.gd, what a caller that edits Save.progress directly and calls
##   save_progress() gets when the write fails (R6 hook). This is the pattern any purchase must avoid.
## Part C (only if an API exists): the acceptance cases proposed to 02. Expected contract (proposal):
##   Save.buy_upgrade(upgrade_id: String, to_level: int) -> String code
##   codes: ok | already_applied | max_level | not_enough_coins | unknown_id | locked | save_failed | read_only

const DIR := "user://probe10"
const P := DIR + "/upg_save.json"
const CANDIDATES := ["buy_upgrade", "purchase_upgrade", "apply_upgrade", "try_buy_upgrade"]

func _rm(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _clean() -> void:
	for suf in ["", ".bak", ".tmp"]: _rm(P + suf)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	create_timer(120.0).timeout.connect(func(): print("PROBE10_UPGRADE_TX {\"watchdog\":true}"); quit(0))
	var save := root.get_node_or_null("Save")
	if save: save.path = P
	_run.call_deferred()

func _disk() -> Dictionary:
	var S = load("res://src/core/save.gd")
	var s = S.new()
	s.path = P
	root.add_child(s)
	s.load_progress()
	var d := {"coins": int(s.progress.coins), "upgrades": (s.progress.get("upgrades", {}) as Dictionary).duplicate()}
	s.free()
	return d

func _run() -> void:
	var out := {}
	var save = root.get_node_or_null("Save")
	var app = root.get_node_or_null("App")
	var content = root.get_node_or_null("Content")
	out["isolated"] = save != null and save.path == P
	var up: Dictionary = {}
	for u in content.meta.get("upgrades", []):
		if str(u.id) == "up_melee_basic": up = u
	var cost2 := int(up.costs[0])
	out["upgrade"] = {"id": "up_melee_basic", "cost_to_level_2": cost2, "max_level": int(up.max_level)}

	# ---- A: API discovery ----
	var api := ""
	var owner := ""
	for n in CANDIDATES:
		if save.has_method(n): api = n; owner = "Save"; break
		if app and app.has_method(n): api = n; owner = "App"; break
	var signal_cmd := root.get_node_or_null("Events") != null and root.get_node("Events").has_signal("cmd_buy_upgrade")
	out["A_api"] = {"found": api != "", "name": api, "owner": owner, "events_cmd_buy_upgrade": signal_cmd,
		"status": "IMPLEMENTED" if api != "" else "NOT_IMPLEMENTED"}

	# ---- B: naive direct edit + save_progress() with an injected write failure (real save.gd) ----
	save.progress = save.fresh()
	save.progress.coins = 100
	save.save_progress()
	var b_disk0 := _disk()
	save.progress.coins = int(save.progress.coins) - cost2          # what a caller without a transaction does
	save.progress.upgrades["up_melee_basic"] = 2
	save._fault = "after_tmp_write"
	var b_ok: bool = save.save_progress()
	var b_mem := {"coins": int(save.progress.coins), "level": int(save.progress.upgrades.get("up_melee_basic", 1))}
	var b_disk1 := _disk()
	# an unrelated later save (e.g. a settings change) persists the "failed" purchase
	save.set_setting("sfx", 0.9)
	var b_disk2 := _disk()
	out["B_naive_failed_write"] = {"save_returned": b_ok, "fault_fired": str(save.fault_fired),
		"disk_before": b_disk0, "memory_after_failed_save": b_mem, "disk_after_failed_save": b_disk1,
		"disk_after_unrelated_set_setting": b_disk2,
		"memory_rolled_back": b_mem.coins == 100 and b_mem.level == 1,
		"phantom_purchase_persisted_later": int(b_disk2.coins) == 100 - cost2 and int((b_disk2.upgrades as Dictionary).get("up_melee_basic", 1)) == 2}

	# ---- C: acceptance cases (only with an API) ----
	if api != "":
		var target = save if owner == "Save" else app
		var rows := {}
		# C1 duplicate call
		_clean(); save.progress = save.fresh(); save.progress.coins = 500; save.save_progress()
		var r1 = target.call(api, "up_melee_basic", 2)
		var r2 = target.call(api, "up_melee_basic", 2)
		var d := _disk()
		rows["C1_duplicate"] = {"codes": [str(r1), str(r2)], "disk": d,
			"pass": int(d.coins) == 500 - cost2 and int(d.upgrades.get("up_melee_basic", 1)) == 2}
		# C2 write failure: memory and disk unchanged
		_clean(); save.progress = save.fresh(); save.progress.coins = 500; save.save_progress()
		save._fault = "after_tmp_write"
		var r3 = target.call(api, "up_melee_basic", 2)
		d = _disk()
		rows["C2_write_failure"] = {"code": str(r3), "memory": {"coins": int(save.progress.coins), "level": int(save.progress.upgrades.get("up_melee_basic", 1))}, "disk": d,
			"pass": int(save.progress.coins) == 500 and int(save.progress.upgrades.get("up_melee_basic", 1)) == 1 and int(d.coins) == 500}
		# C3 kill before final rename: reload state must be a consistent pair
		_clean(); save.progress = save.fresh(); save.progress.coins = 500; save.save_progress()
		save._fault = "before_final_rename"
		target.call(api, "up_melee_basic", 2)
		d = _disk()
		var lv := int(d.upgrades.get("up_melee_basic", 1))
		rows["C3_kill_before_final_rename"] = {"disk": d,
			"pass": (lv == 1 and int(d.coins) == 500) or (lv == 2 and int(d.coins) == 500 - cost2)}
		# C4 boundary: exactly enough, and one short
		_clean(); save.progress = save.fresh(); save.progress.coins = cost2; save.save_progress()
		var r4 = target.call(api, "up_melee_basic", 2)
		var d4 := _disk()
		_clean(); save.progress = save.fresh(); save.progress.coins = cost2 - 1; save.save_progress()
		var r5 = target.call(api, "up_melee_basic", 2)
		var d5 := _disk()
		rows["C4_boundary"] = {"exact": {"code": str(r4), "disk": d4}, "short_by_1": {"code": str(r5), "disk": d5},
			"pass": int(d4.coins) == 0 and int(d4.upgrades.get("up_melee_basic", 1)) == 2 and int(d5.coins) == cost2 - 1 and int(d5.upgrades.get("up_melee_basic", 1)) == 1}
		# C5 max level
		_clean(); save.progress = save.fresh(); save.progress.coins = 99999
		save.progress.upgrades["up_melee_basic"] = int(up.max_level); save.save_progress()
		var r6 = target.call(api, "up_melee_basic", int(up.max_level) + 1)
		d = _disk()
		rows["C5_max_level"] = {"code": str(r6), "pass": int(d.coins) == 99999}
		out["C_rows"] = rows
	# ---- E (v0.19): C6–C13, only if the API exists. Fault injection via Save._fault (R6 hook). ----
	if api != "" and owner == "Save":
		out["E_rows"] = _part_e(save, app, cost2)

	# ---- D (R5 evidence): a saved level above the CURRENT max_level (e.g. after a rebalance lowers it) ----
	_clean()
	var S = load("res://src/core/save.gd")
	var sv = S.new()
	sv.path = P
	root.add_child(sv)
	sv.progress = S.fresh()
	sv.progress.upgrades = {"up_melee_basic": int(up.max_level) + 4, "up_retired_xyz": 3}
	sv.progress.stars = {"r01": 3, "r99_retired": 3}
	sv.save_progress()
	sv.load_progress()
	var lvl_after_load := int(sv.progress.upgrades.get("up_melee_basic", 1))
	var SimS = load("res://src/gameplay/battle_sim.gd")
	var sim = SimS.new()
	sim.setup(content, str(content.round_order[0]), 1, sv.progress.upgrades)
	var per := float(up.get("per_level", {}).get("hp_mult", 0.0))
	out["D_level_above_max"] = {"saved_level": int(up.max_level) + 4, "max_level": int(up.max_level),
		"level_after_load": lvl_after_load, "unknown_upgrade_kept": sv.progress.upgrades.has("up_retired_xyz"),
		"unknown_round_star_kept": sv.progress.stars.has("r99_retired"),
		"sim_hp_mult": snappedf(sim._upgrade_mult("unit:melee_basic", "hp_mult"), 0.0001),
		"expected_hp_mult_at_max": snappedf(1.0 + per * (int(up.max_level) - 1), 0.0001),
		"save_has_content_version": sv.progress.has("content_version")}
	sv.free()
	print("PROBE10_UPGRADE_TX ", JSON.stringify(out))
	quit(0)

# =========================== v0.19: C6–C13 ===========================
const UID := "up_melee_basic"

func _env_txt(p: Dictionary) -> String:
	var txt := JSON.stringify(p, "", true)
	return JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt}, "", true)

func _wfile(path: String, s: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(s); f.close()

func _base(coins: int, extra := {}) -> Dictionary:
	var S = load("res://src/core/save.gd")
	var p: Dictionary = S.fresh()
	p.coins = coins
	p.unlocked_round = 3
	for k in extra: p[k] = extra[k]
	return p

func _prep(save, mode: String, coins := 500) -> void:
	# healthy: valid main. after_recovery: corrupt main + valid .bak (first save after recovery).
	_clean()
	if mode == "healthy":
		_wfile(P, _env_txt(_base(coins)))
	else:
		_wfile(P, "{ corrupt")
		_wfile(P + ".bak", _env_txt(_base(coins)))
	save.load_progress()

func _pair(d: Dictionary) -> Array:
	return [int(d.coins), int((d.upgrades as Dictionary).get(UID, 1))]

func _part_e(save, app, cost: int) -> Dictionary:
	var rows := {}
	var ev = root.get_node_or_null("Events")
	var rec := {"results": [], "toasts": []}
	if ev:
		if ev.has_signal("upgrade_result"): ev.upgrade_result.connect(func(r): rec.results.append(r))
		ev.toast.connect(func(k, _a): rec.toasts.append(str(k)))
	var before := [500, 1]
	var after := [500 - cost, 2]

	# C6: every fault point x {healthy, after_recovery}: disk pair is before or after, memory matches the code
	var c6 := {}
	var c6_pass := true
	for point in save.FAULT_POINTS:
		for mode in ["healthy", "after_recovery"]:
			_prep(save, mode)
			save._fault = point
			var code: String = save.buy_upgrade(UID, 2)
			var mem := [int(save.progress.coins), save.upgrade_level(UID)]
			var disk := _pair(_disk())
			var mem_ok: bool = (mem == after) if code == "ok" else (mem == before)
			var ok: bool = (disk == before or disk == after) and mem_ok and str(save.fault_fired) == point and code != "ok"
			c6_pass = c6_pass and ok
			c6["%s/%s" % [point, mode]] = {"code": code, "memory": mem, "disk_after_reload": disk, "pass": ok}
			save.load_progress()      # re-sync the autoload with disk before the next case
	rows["C6_fault_points"] = {"pass": c6_pass, "cases": c6}

	# C7: read_only (payload version 99)
	_clean()
	var nv := _base(500); nv.version = 99
	_wfile(P, _env_txt(nv))
	var bytes0 := FileAccess.get_file_as_bytes(P)
	save.load_progress()
	var c7code: String = save.buy_upgrade(UID, 2)
	rows["C7_read_only"] = {"code": c7code, "memory": [int(save.progress.coins), save.upgrade_level(UID)],
		"bytes_unchanged": FileAccess.get_file_as_bytes(P) == bytes0,
		"pass": c7code == "read_only" and int(save.progress.coins) == 500 and FileAccess.get_file_as_bytes(P) == bytes0}

	# C8: first purchase after .bak recovery: .bak afterwards is a valid envelope, purchase persists
	_prep(save, "after_recovery")
	var c8code: String = save.buy_upgrade(UID, 2)
	var S = load("res://src/core/save.gd")
	var b = S.new(); b.path = P + ".bak"; root.add_child(b); b.load_progress()
	var bak_ok: bool = b.recovery_source == "main" and int(b.progress.coins) == 500
	b.free()
	var d8 := _pair(_disk())
	rows["C8_after_recovery"] = {"code": c8code, "bak_valid_and_previous": bak_ok, "disk": d8,
		"pass": c8code == "ok" and bak_ok and d8 == after}

	# C9: never negative; exact, one short, near the cap
	var c9 := {}
	for c in [cost, cost - 1, 9999999]:
		_prep(save, "healthy", c)
		var code: String = save.buy_upgrade(UID, 2)
		var d := _pair(_disk())
		var exp_coins: int = c - cost if c >= cost else c
		c9[str(c)] = {"code": code, "memory_coins": int(save.progress.coins), "disk": d,
			"pass": int(save.progress.coins) >= 0 and d[0] >= 0 and d[0] == exp_coins}
	var c9_pass := true
	for k in c9: c9_pass = c9_pass and bool(c9[k].pass)
	rows["C9_never_negative"] = {"pass": c9_pass, "cases": c9}

	# C10: App path: failure / uncertain must not look like success (code + save_failed toast)
	var c10 := {}
	for point in ["", "after_tmp_write", "before_final_rename"]:
		_prep(save, "healthy")
		rec.results.clear(); rec.toasts.clear()
		if point != "": save._fault = point
		ev.cmd_buy_upgrade.emit(UID, 2)
		var r: Dictionary = rec.results.back() if not rec.results.is_empty() else {}
		var code := str(r.get("code", ""))
		var toast_failed: bool = rec.toasts.has("save_failed")
		var ok: bool = (code == "ok" and not toast_failed) if point == "" else (code != "ok" and toast_failed and int(r.get("coins", -1)) == 500)
		c10[point if point != "" else "no_fault"] = {"code": code, "toast_save_failed": toast_failed, "reported_coins": r.get("coins"), "pass": ok}
		save.load_progress()
	var c10_pass := true
	for k in c10: c10_pass = c10_pass and bool(c10[k].pass)
	rows["C10_ui_signal"] = {"pass": c10_pass, "cases": c10, "note": "signal level only; no rendered UI checked"}

	# C11: double tap in the same frame (two commands, same to_level)
	_prep(save, "healthy")
	rec.results.clear()
	ev.cmd_buy_upgrade.emit(UID, 2)
	ev.cmd_buy_upgrade.emit(UID, 2)
	var codes11: Array = rec.results.map(func(x): return str(x.code))
	var d11 := _pair(_disk())
	rows["C11_double_tap"] = {"codes": codes11, "disk": d11, "pass": d11 == after and codes11 == ["ok", "already_applied"]}

	# C12: failed purchase then successful result; failed result then successful purchase
	_prep(save, "healthy")
	save._fault = "after_tmp_write"
	var c12a: String = save.buy_upgrade(UID, 2)
	var res := {"round_id": "r01", "won": true, "stars": 1, "time": 99.0, "coins": 100, "battle_uid": "probe10-c12-a"}
	var rr_a: bool = save.record_result(res, 0)
	var da := _disk()
	_prep(save, "healthy")
	save._fault = "after_tmp_write"
	var res_b := res.duplicate(); res_b.battle_uid = "probe10-c12-b"
	var rr_b: bool = save.record_result(res_b, 0)
	var c12b: String = save.buy_upgrade(UID, 2)
	var db := _disk()
	var S2 = load("res://src/core/save.gd")
	var chk = S2.new(); chk.path = P; root.add_child(chk); chk.load_progress()
	var b_clears := int(chk.progress.clears); var b_applied: Array = chk.progress.applied_battles
	chk.free()
	rows["C12_cross_rollback"] = {
		"buy_fail_then_result": {"buy": c12a, "result_saved": rr_a, "disk": _pair(da), "pass": c12a == "save_failed" and rr_a and _pair(da) == [600, 1]},
		"result_fail_then_buy": {"result_saved": rr_b, "buy": c12b, "disk": _pair(db), "clears": b_clears, "applied": b_applied,
			"pass": not rr_b and c12b == "ok" and _pair(db) == after and b_clears == 0 and b_applied.is_empty()}}
	rows["C12_cross_rollback"]["pass"] = rows["C12_cross_rollback"].buy_fail_then_result.pass and rows["C12_cross_rollback"].result_fail_then_buy.pass

	# C13: purchase then app pause (desktop emulation: App._notification(NOTIFICATION_APPLICATION_PAUSED))
	_prep(save, "healthy")
	var c13code: String = save.buy_upgrade(UID, 2)
	var rev0 := int(save.progress.revision)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var rev_delta := int(save.progress.revision) - rev0      # measured immediately (v0.19 fix)
	var d13 := _pair(_disk())
	_prep(save, "healthy")
	save._fault = "before_final_rename"
	var c13u: String = save.buy_upgrade(UID, 2)
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var d13u := _pair(_disk())
	rows["C13_pause_after_purchase"] = {"ok_case": {"code": c13code, "disk": d13, "revision_delta": rev_delta},
		"uncertain_case": {"code": c13u, "disk_after_pause_save": d13u, "memory": [int(save.progress.coins), save.upgrade_level(UID)]},
		"pass": c13code == "ok" and d13 == after and c13u == "save_uncertain" and d13u == before,
		"note": "desktop emulation of the pause path; no device test"}

	# extra: locked target (ranged unlock_round 2 with unlocked_round 1)
	_clean()
	var lp := _base(500); lp.unlocked_round = 1
	_wfile(P, _env_txt(lp)); save.load_progress()
	var lc: String = save.buy_upgrade("up_ranged_basic", 2)
	rows["C5b_locked"] = {"code": lc, "pass": lc == "locked" and int(save.progress.coins) == 500}
	return rows
