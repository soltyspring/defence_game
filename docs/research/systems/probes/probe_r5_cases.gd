extends SceneTree
## Research probe (10-research-systems): engine acceptance for 02's R5 content migration (7f2886c, PROVISIONAL rules).
## Cases E1, E4j, E5–E8 from DATA_AND_BACKEND_ANALYSIS.md §9.14 (adapted to 02's `content_snapshot` design), plus
## R2m (two data changes in a row), R6r (retired upgrade), DL (legacy save above max), DS (same content_version
## above max) and F2 checks (a successful ordinary save after a FAILED migration save).
## Data changes are emulated IN MEMORY on the Content autoload (meta + content_version); no data file is edited.
## The save goes to user://probe10/r5_save.json of the renamed snapshot project; the real save is never touched.
## Run in a full snapshot (autoloads kept): ... --headless --path <snap> -s res://docs/research/systems/probes/probe_r5_cases.gd
## Output: "PROBE10_R5 <json>". Exit 0. 120 s watchdog.

const DIR := "user://probe10"
const P := DIR + "/r5_save.json"
const UID := "up_melee_basic"

var save
var content
var orig_meta: Dictionary
var orig_cv: String
var orig_mig: Dictionary

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	create_timer(120.0).timeout.connect(func(): print("PROBE10_R5 {\"watchdog\":true}"); quit(0))
	_run.call_deferred()

func _rm(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _clean() -> void:
	for suf in ["", ".bak", ".tmp"]: _rm(P + suf)

func _raw(path := P) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var env = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (env is Dictionary) or not env.has("payload"): return {}
	var p = JSON.parse_string(str(env.payload))
	return p if p is Dictionary else {}

func _env_txt(p: Dictionary) -> String:
	var txt := JSON.stringify(p, "", true)
	return JSON.stringify({"version": int(p.get("version", 1)), "checksum": txt.sha256_text(), "payload": txt}, "", true)

func _wfile(path: String, s: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(s); f.close()

func _up(meta: Dictionary, id: String) -> Dictionary:
	for u in meta.get("upgrades", []):
		if str(u.id) == id: return u
	return {}

## Switch the Content autoload to a mutated copy of the original data, in memory only.
func _set_content(cv: String, mut := Callable()) -> void:
	content.meta = orig_meta.duplicate(true)
	if mut.is_valid(): mut.call(content.meta)
	content.content_version = cv
	content.migrations = orig_mig.duplicate(true)

func _restore() -> void:
	content.meta = orig_meta.duplicate(true)
	content.content_version = orig_cv
	content.migrations = orig_mig.duplicate(true)

func _fresh(coins: int, ups: Dictionary) -> Dictionary:
	var S = load("res://src/core/save.gd")
	var p: Dictionary = S.fresh()
	p.coins = coins
	p.unlocked_round = 3
	p.stars = {"r01": 3, "r02": 2}
	p.upgrades = ups.duplicate()
	return p

## Stamp a save under the CURRENT (possibly mutated) content via the real save path.
func _stamp(coins: int, ups: Dictionary) -> void:
	_clean()
	save._fault = ""
	save.read_only = false
	save.progress = _fresh(coins, ups)
	save.save_progress()

func _state(p: Dictionary) -> Dictionary:
	return {"coins": int(p.get("coins", -1)), "upgrades": (p.get("upgrades", {}) as Dictionary).duplicate(),
		"content_version": str(p.get("content_version", "")), "applied": (p.get("migrations_applied", []) as Array).duplicate()}

func _cap3(m: Dictionary) -> void:
	var u := _up(m, UID); u.max_level = 3; u.costs = [u.costs[0], u.costs[1]]

func _run() -> void:
	save = root.get_node("Save")
	content = root.get_node("Content")
	save.path = P
	orig_meta = (content.meta as Dictionary).duplicate(true)
	orig_cv = str(content.content_version)
	orig_mig = (content.migrations as Dictionary).duplicate(true)
	var costs_now: Array = _up(orig_meta, UID).costs
	var out := {"isolated": save.path == P, "content_version": orig_cv, "melee_costs": costs_now}
	var rows := {}

	# E1: a successful purchase stamps content_version + snapshot with the current prices
	_restore(); _stamp(500, {})
	var c1: String = save.buy_upgrade(UID, 2)
	var r1 := _raw()
	var snap_costs = r1.get("content_snapshot", {}).get("upgrades", {}).get(UID, {}).get("costs", [])
	rows["E1_stamp_on_buy"] = {"code": c1, "disk": _state(r1), "snapshot_costs": snap_costs,
		"pass": c1 == "ok" and int(r1.coins) == 500 - int(costs_now[0]) and str(r1.get("content_version", "")) == orig_cv and snap_costs == costs_now}

	# E5: cap 5 -> 3 after a version change: refund at the snapshot's prices once
	_restore(); _stamp(1234, {UID: 5})
	_set_content("c1-r5test0000b", _cap3)
	save.load_progress()
	var m5 := _state(save.progress)
	var log5: Array = save.migration_log.duplicate()
	save.load_progress()
	var m5b := _state(save.progress)
	var exp5 := 1234 + int(costs_now[2]) + int(costs_now[3])
	rows["E5_cap_refund_once"] = {"after_load": m5, "second_load": m5b, "disk": _state(_raw()), "log": log5,
		"expected_coins": exp5, "pass": m5.coins == exp5 and int(m5.upgrades[UID]) == 3 and m5b.coins == exp5 and _state(_raw()).coins == exp5}

	# E6: migration save fails (after_tmp_write): disk untouched, retried once on the next load
	_restore(); _stamp(1234, {UID: 5})
	_set_content("c1-r5test0000b", _cap3)
	save._fault = "after_tmp_write"
	save.load_progress()
	var e6_mem := _state(save.progress)
	var e6_log: Array = save.migration_log.duplicate()
	var e6_disk := _state(_raw())
	save._fault = ""
	save.load_progress()
	var e6_retry := _state(save.progress)
	save.load_progress()
	var e6_again := _state(save.progress)
	rows["E6_fail_then_retry"] = {"memory_after_fail": e6_mem, "log": e6_log, "disk_after_fail": e6_disk,
		"after_retry": e6_retry, "after_third_load": e6_again,
		"pass": e6_disk.coins == 1234 and int(e6_disk.upgrades[UID]) == 5 and e6_retry.coins == exp5 and e6_again.coins == exp5}

	# F2a: after the failed migration save, an ordinary successful save in the same session (settings)
	_restore(); _stamp(1234, {UID: 5})
	_set_content("c1-r5test0000b", _cap3)
	save._fault = "after_tmp_write"
	save.load_progress()
	save._fault = ""
	var f2a_ok: bool = save.save_progress()     # e.g. set_setting / record_result path
	var f2a_disk := _state(_raw())
	save.load_progress()
	var f2a_load := _state(save.progress)
	rows["F2a_ordinary_save_after_failed_migration"] = {"ordinary_save_ok": f2a_ok, "disk": f2a_disk, "after_reload": f2a_load,
		"expected_if_correct": {"coins": exp5, "level": 3},
		"pass": f2a_load.coins == exp5 and int(f2a_load.upgrades[UID]) == 3}

	# E7: migration save outcome unknown (before_final_rename): next load adopts .tmp, no second refund
	_restore(); _stamp(1234, {UID: 5})
	_set_content("c1-r5test0000b", _cap3)
	save._fault = "before_final_rename"
	save.load_progress()
	var e7_mem := _state(save.progress)
	save._fault = ""
	save.load_progress()
	var e7_load := _state(save.progress)
	var e7_src := str(save.recovery_source)
	save.load_progress()
	var e7_again := _state(save.progress)
	rows["E7_unknown_then_adopt"] = {"memory_after_fault": e7_mem, "after_reload": e7_load, "recovery_source": e7_src,
		"after_third_load": e7_again, "pass": e7_load.coins == exp5 and e7_again.coins == exp5 and int(e7_again.upgrades[UID]) == 3}

	# F2b: same as E7 but an ordinary successful save happens before the restart
	_restore(); _stamp(1234, {UID: 5})
	_set_content("c1-r5test0000b", _cap3)
	save._fault = "before_final_rename"
	save.load_progress()
	save._fault = ""
	var f2b_ok: bool = save.save_progress()
	save.load_progress()
	var f2b_load := _state(save.progress)
	rows["F2b_ordinary_save_after_unknown_migration"] = {"ordinary_save_ok": f2b_ok, "after_reload": f2b_load,
		"expected_if_correct": {"coins": exp5, "level": 3}, "pass": f2b_load.coins == exp5 and int(f2b_load.upgrades[UID]) == 3}

	# E8: newer save version (read_only): no migration and no write
	_restore()
	_clean()
	var p8 := _fresh(1234, {UID: 5}); p8.version = 99; p8.content_version = orig_cv
	var t8 := _env_txt(p8)
	_wfile(P, t8)
	_set_content("c1-r5test0000b", _cap3)
	save.load_progress()
	var e8_bytes_same := FileAccess.get_file_as_string(P) == t8
	rows["E8_read_only"] = {"read_only": save.read_only, "bytes_unchanged": e8_bytes_same, "memory": _state(save.progress),
		"pass": save.read_only and e8_bytes_same and int(save.progress.upgrades[UID]) == 5}
	save.read_only = false

	# E4j: junk snapshot prices / junk snapshot type: no crash, clamp, refund 0 for unknown prices
	_restore()
	_clean()
	var p4 := _fresh(1234, {UID: 7}); p4.content_version = "c1-junk000000"
	p4.content_snapshot = {"upgrades": {UID: {"target": "unit:melee_basic", "max_level": 7, "costs": ["x", "y", "z", "w", "v", "u"]}}}
	_wfile(P, _env_txt(p4))
	save.load_progress()
	var e4a := _state(save.progress)
	var e4a_log: Array = save.migration_log.duplicate()
	_clean()
	var p4b := _fresh(1234, {UID: 7}); p4b.content_version = "c1-junk000000"; p4b.content_snapshot = "junk"
	_wfile(P, _env_txt(p4b))
	save.load_progress()
	var e4b := _state(save.progress)
	rows["E4j_junk_snapshot"] = {"string_prices": e4a, "string_prices_log": e4a_log, "snapshot_not_dict": e4b,
		"pass": int(e4a.upgrades[UID]) == 5 and int(e4b.upgrades[UID]) == 5 and e4b.coins == 1234}

	# R2m: price change first (L5 250 -> 190), then a cap 5 -> 3. D26 says "coins actually paid".
	_restore()
	_set_content("c1-r5test000a2", func(m): _up(m, UID).costs = [60, 100, 160, 250])
	_stamp(1234, {UID: 5})
	_set_content("c1-r5test000b2", func(m): _up(m, UID).costs = [60, 100, 160, 190])
	save.load_progress()
	var r2_mid := _state(save.progress)
	_set_content("c1-r5test000c2", _cap3)
	save.load_progress()
	var r2 := _state(save.progress)
	rows["R2m_price_change_then_cap"] = {"after_price_change": r2_mid, "after_cap": r2, "log": save.migration_log.duplicate(),
		"refund_actually_paid_D26": 160 + 250, "refund_snapshot": 160 + 190, "matches_D26": r2.coins == 1234 + 410}

	# R6r: an upgrade removed from meta.json (no same-target replacement). D26 says refund the removed levels.
	_restore(); _stamp(1234, {"up_worker": 4})
	_set_content("c1-r5test000r6", func(m):
		var keep: Array = []
		for u in m.upgrades:
			if str(u.id) != "up_worker": keep.append(u)
		m.upgrades = keep)
	save.load_progress()
	var r6 := _state(save.progress)
	var wc: Array = _up(orig_meta, "up_worker").costs
	rows["R6r_retired_upgrade"] = {"after_load": r6, "log": save.migration_log.duplicate(),
		"D26_expected_coins": 1234 + int(wc[0]) + int(wc[1]) + int(wc[2]), "matches_D26": r6.coins == 1234 + int(wc[0]) + int(wc[1]) + int(wc[2])}

	# DL: legacy save (no content_version) with a level above max -> clamp, unknown price -> refund 0
	_restore()
	_clean()
	_wfile(P, _env_txt(_fresh(1234, {UID: 9})))
	save.load_progress()
	var dl := _state(save.progress)
	var SimS = load("res://src/gameplay/battle_sim.gd")
	var sim = SimS.new()
	sim.setup(content, str(content.round_order[0]), 1, save.progress.upgrades)
	var per := float(_up(orig_meta, UID).get("per_level", {}).get("hp_mult", 0.0))
	rows["DL_legacy_above_max"] = {"after_load": dl, "log": save.migration_log.duplicate(), "disk": _state(_raw()),
		"sim_hp_mult": snappedf(sim._upgrade_mult("unit:melee_basic", "hp_mult"), 0.0001),
		"expected_hp_mult": snappedf(1.0 + per * 4, 0.0001),
		"pass": int(dl.upgrades[UID]) == 5 and dl.coins == 1234 and _state(_raw()).content_version == orig_cv}

	# DS: same content_version, level above max (only by editing the file): old part D shape
	_restore()
	_clean()
	var pds := _fresh(1234, {UID: 9}); pds.content_version = orig_cv
	_wfile(P, _env_txt(pds))
	save.load_progress()
	var sim2 = SimS.new()
	sim2.setup(content, str(content.round_order[0]), 1, save.progress.upgrades)
	rows["DS_same_version_above_max"] = {"after_load": _state(save.progress),
		"sim_hp_mult": snappedf(sim2._upgrade_mult("unit:melee_basic", "hp_mult"), 0.0001),
		"note": "only reachable by editing the save; R5 does not run when content_version matches"}

	_restore()
	_clean()
	var n_pass := 0
	var n_check := 0
	for k in rows:
		if rows[k].has("pass"):
			n_check += 1
			if rows[k].pass: n_pass += 1
	out["rows"] = rows
	out["summary"] = {"pass": n_pass, "checked": n_check}
	print("PROBE10_R5 ", JSON.stringify(out))
	quit(0)
