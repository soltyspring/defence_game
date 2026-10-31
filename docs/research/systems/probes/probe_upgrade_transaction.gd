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
