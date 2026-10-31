extends SceneTree
## 06-services GAME INTEGRATION gate. Owner: 06-services. Runnable by 02 and 07 as is:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_integration.gd
## Exit codes:  0 = all checks pass AND the game binding is integrated
##              2 = no failures, but integration is BLOCKED (02 S1/S2 not done)  <- expected today
##              1 = at least one failure
## Report: user://services_integration_report.json (row-by-row, binding kind, blockers).
##
## Runs with the game's real autoloads (Events, Save, App, ...). The AUTOLOAD Save is redirected
## to user://svc_int_test/<case>/ for every write; the player's user://save.json is hashed before
## and after and must be unchanged. Grants use a MOCK service bundle built on the binding's
## store; the game's own Services node (if registered) is never switched out of its mode.
##
## Binding kinds:
##   game              /root/Services exists and its store is bound to Save.progress["services"]
##   bridge_simulated  not integrated: a save_bridge store on the autoload Save stands in, so the
##                     expected results are visible. These rows are NOT game evidence.
##   services_node_simulated  run with `-- --simulate-integration`: the test itself adds a
##                     services.gd node as /root/Services (what 02 S1 would register) to exercise
##                     the game-binding path. Still NOT game evidence; exit code stays 2 (I1).

const R := preload("res://src/services/service_result.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Config := preload("res://src/services/service_config.gd")
const Bridge := preload("res://src/services/save_bridge.gd")
const Diag := preload("res://src/services/service_diagnostics.gd")
const Policy := preload("res://src/services/ads/reward_policy.gd")
const Child := preload("res://tests/services/integration_child.gd")

const BASE := "user://svc_int_test"
const ADS := {"enabled": true, "placements": {"ad_double_gold": {"daily_cap": 1000, "reward": {"effect": "gold_mult_2", "where": "results_win"}}}}
const IAP := {"enabled": true, "purchase_timeout_s": 10.0, "verify_timeout_s": 5.0,
	"catalog": {"test.coins_small": {"type": "consumable", "grant": {"coins": 100}}}}

## Must match docs/services/REWARD_STATE_TABLE.md (checked in state_table_sync).
## Value: case function run here on the binding ("" = evidenced only by isolated suites).
const TABLE := {
	"R1": "row_r1", "R2": "row_r2", "R3": "row_r3", "R4": "death:kill_before_commit",
	"R5": "death:kill_after_commit", "R6": "row_r6", "R7": "death:sink_saves_then_kill",
	"R8": "row_r8", "R9": "row_r9", "R10": "", "R11": "", "R12": "", "R13": "", "R14": "row_r14",
	"R15": "row_r15", "R16": "", "P1": "row_p1", "P2": "", "P3": "", "P4": "", "P5": "", "P6": "",
	"D1": "disabled", "D2": "disabled", "D3": "disabled", "D4": "disabled", "D5": "disabled", "D6": "disabled",
}

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}, "rows": {}, "integration": {}, "blockers": []}
var save: Node
var events: Node
var orig_path := ""
var binding_kind := ""
var simulated := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	save = root.get_node_or_null("Save")
	events = root.get_node_or_null("Events")
	if save == null or events == null:
		printerr("[test_services_integration] Save/Events autoloads missing: run with --path . (project autoloads)")
		quit(1)
		return
	orig_path = save.path
	var h0 := _hash_user_save()
	simulated = OS.get_cmdline_user_args().has("--simulate-integration")
	report.simulated = simulated
	if simulated and root.get_node_or_null("Services") == null:
		var n = load("res://src/services/services.gd").new()
		n.name = "Services"
		root.add_child(n)   # _ready auto-attaches to /root/Save (no write)
	_wipe(BASE)
	DirAccess.make_dir_recursive_absolute(BASE)
	_group("disabled_mode", test_disabled_mode)
	_group("integration_contract", test_integration_contract)
	_group("binding_failure_injection", test_failure_injection)
	_group("binding_process_death", test_process_death)
	_group("state_table_sync", test_state_table_sync)
	_group("readiness_doc_sync", test_readiness_doc_sync)
	# Hygiene: put the autoload Save back on the player's file (read only) and prove no write.
	save.path = orig_path
	save.load_progress()
	_group("hygiene", func() -> bool:
		eq(_hash_user_save(), h0, "player's user://save.json(.bak) unchanged by this test")
		return true)
	_wipe(BASE)
	DirAccess.remove_absolute(BASE)
	report.binding = binding_kind
	report.passes = passes
	report.failures = Array(failures)
	report.total_ms = Time.get_ticks_msec() - t0
	var code := 1 if not failures.is_empty() else (2 if not report.blockers.is_empty() else 0)
	report.exit_code = code
	report.verdict = ["PASS_INTEGRATED", "FAIL", "BLOCKED_NOT_INTEGRATED"][[0, 1, 2].find(code)]
	var f := FileAccess.open("user://services_integration_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services_integration] verdict=%s exit=%d passes=%d failures=%d blockers=%d binding=%s time_ms=%d" % [
		report.verdict, code, passes, failures.size(), report.blockers.size(), binding_kind, report.total_ms])
	for g in report.groups:
		print("  %-28s %s" % [g, report.groups[g]])
	for b in report.blockers:
		print("  BLOCKED: " + str(b))
	quit(code)

func _group(name: String, fn: Callable) -> void:
	current = name
	var before := failures.size()
	var p0 := passes
	var completed = fn.call()
	if completed != true:
		check(false, "group aborted before its end (script error or early exit)")
	report.groups[name] = "PASS (%d checks)" % (passes - p0) if failures.size() == before else "FAIL"

func check(cond: bool, msg: String) -> bool:
	if cond:
		passes += 1
	else:
		failures.append(current + ": " + msg)
		printerr("FAIL [%s] %s" % [current, msg])
	return cond

func eq(a: Variant, b: Variant, msg: String) -> bool:
	return check(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])

func blocked(id: String, why: String) -> void:
	report.integration[id] = "BLOCKED"
	report.blockers.append("%s: %s" % [id, why])

func row(id: String, ok: bool, detail: Variant = "") -> void:
	report.rows[id] = {"status": "PASS" if ok else "FAIL", "binding": binding_kind if binding_kind != "" else "n/a",
		"game_evidence": ok and binding_kind == "game" and not simulated, "detail": detail}

# ------------------------------------------------------------------ helpers

func _hash_user_save() -> String:
	var s := ""
	for p in ["user://save.json", "user://save.json.bak"]:
		s += (FileAccess.get_file_as_string(p).sha256_text() if FileAccess.file_exists(p) else "absent") + ";"
	return s

func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_wipe(dir + "/" + sub)
		d.remove(sub)

## Redirect the AUTOLOAD Save to a fresh isolated dir and load (fresh progress).
func use_dir(name: String) -> String:
	var p := BASE + "/" + name
	_wipe(p)
	DirAccess.make_dir_recursive_absolute(p)
	save.path = p + "/save.json"
	save.load_progress()
	return p

## Simulated crash: drop memory, reload the autoload Save from disk.
func crash_reload() -> void:
	save.load_progress()

func game_store():
	return Child.game_store(root, save)

## Same as game_store() but WITHOUT calling ensure_bound(): observes what the game holds now.
func raw_game_store():
	var svc = root.get_node_or_null("Services")
	if svc == null or not ("bundle" in svc) or not (svc.bundle is Dictionary):
		return null
	var st = svc.bundle.get("store")
	if st == null or not st.is_persistent() or not st.is_usable() or not is_same(st.data, save.progress.get("services")):
		return null
	return st

## The store the binding provides right now (game if integrated, else bridge on autoload Save).
func binding_store():
	var st = game_store()
	if st != null:
		binding_kind = "services_node_simulated" if simulated else "game"
		return st
	binding_kind = "bridge_simulated"
	return Bridge.make_store(save, events)

func mock_on(store) -> Dictionary:
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": store,
		"overrides": {"ads": ADS, "iap": IAP}})
	b.consent.set_choice("ads", "granted")
	return b

func disk(dir: String, file: String = "save.json") -> Dictionary:
	var p := dir + "/" + file
	if not FileAccess.file_exists(p):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK or not (j.data is Dictionary):
		return {"_corrupt": true}
	var payload := str(j.data.get("payload", ""))
	if payload.sha256_text() != str(j.data.get("checksum", "")):
		return {"_corrupt": true}
	var pj := JSON.new()
	pj.parse(payload)
	return pj.data

func cl(p: Dictionary) -> Array:
	return [int(p.get("coins", 0)), p.get("services", {}).get("ads", {}).get("granted_contexts", {}).size()]

func sink(saves_itself: bool = false, result: bool = true) -> Callable:
	return func(_p, _r, _c) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + 100
		if saves_itself:
			save.save_progress()
		return result

func pump(svc, n: int = 40) -> void:
	for i in n:
		svc.tick(0.0)

# ------------------------------------------------------------------ D1–D6 disabled mode

func test_disabled_mode() -> bool:
	var ok := true
	# D1 default factory + Services node (if registered)
	var d := Factory.create({})
	var s := Diag.snapshot(d)
	ok = eq(d.mode, "disabled", "D1 default factory mode") and ok
	ok = eq(s.live, {"real_ads": false, "real_billing": false, "trusted_verifier": false, "remote_analytics": false}, "D1 nothing live") and ok
	ok = eq([s.adapters.ads, s.adapters.billing, s.adapters.verifier, s.adapters.analytics_sink], ["disabled", "disabled", "unavailable", "null"], "D1 adapter kinds") and ok
	var svc = root.get_node_or_null("Services")
	if svc != null:
		var sd: Dictionary = svc.diagnostics()
		ok = eq(sd.get("mode"), "disabled", "D1 game Services node mode") and ok
		ok = eq(sd.get("live", {}).values().has(true), false, "D1 game Services: nothing live") and ok
		ok = eq(svc.ads.availability("ad_double_gold", "result:x"), R.DISABLED, "D1 game ads disabled") and ok
		ok = eq(svc.purchases.availability("any"), R.DISABLED, "D1 game purchases disabled") and ok
		ok = eq(svc.analytics.track("round_start", {"round_id": "r01", "attempt": 1}), R.DISABLED, "D1 game analytics disabled") and ok
	report.services_node_registered = svc != null
	row("D1", ok)
	# D2 01 flags on, mode disabled
	var meta := {"retention_hooks": {"rewarded_ads": {"enabled": true, "placements": [{"id": "ad_double_gold", "where": "results_win", "effect": "gold_mult_2", "daily_cap": 5}]}},
		"iap_catalog": {"enabled": true, "products": [{"id": "p.one", "type": "non_consumable", "entitlement": "remove_ads"}]}}
	var d2 := Factory.create({"meta": meta})
	var ok2 := eq(d2.ads.availability("ad_double_gold", "result:x"), R.DISABLED, "D2 ads stay disabled with 01 flags on")
	ok2 = eq(d2.purchases.availability("p.one"), R.DISABLED, "D2 purchases stay disabled with 01 flags on") and ok2
	var real_cfg := Config.from_meta(Config.load_meta())
	report.meta_flags = {"rewarded_ads_enabled": real_cfg.ads.enabled, "iap_enabled": real_cfg.iap.enabled, "products": real_cfg.iap.catalog.size()}
	row("D2", ok2, report.meta_flags)
	# D3 release / production
	var rel := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": false, "overrides": {"ads": ADS}})
	var prod := Factory.create({"mode": "production", "overrides": {"ads": ADS, "iap": IAP}})
	var ok3 := eq([rel.mode, prod.mode], ["disabled", "disabled"], "D3 release mock + production -> disabled")
	ok3 = eq(prod.ads.availability("ad_double_gold", "result:x"), R.DISABLED, "D3 production overrides ignored") and ok3
	row("D3", ok3)
	# D4 consent flow
	var c_before: String = d.consent.get_choice("ads")
	var ok4 := eq(d.consent_flow.start(), R.UNSUPPORTED, "D4 consent flow unsupported in default build")
	ok4 = eq(d.consent.get_choice("ads"), c_before, "D4 no consent choice changed") and ok4
	if svc != null and "consent_flow" in svc and svc.consent_flow != null:
		ok4 = eq(svc.consent_flow.provider.kind(), "disabled", "D4 game consent provider disabled") and ok4
	row("D4", ok4)
	# D5 no production adapters / identifiers in src/services
	var files := _list_gd("res://src/services")
	var bad: Array = []
	for f in files:
		var name := f.get_file().to_lower()
		if name.contains("admob") or name.contains("play_billing") or name.contains("ump") or name.begins_with("production"):
			bad.append(f)
		var txt := FileAccess.get_file_as_string(f)
		for needle in ["ca-app-pub-", "BEGIN PRIVATE KEY", "https://", "http://", "OS.get_unique_id"]:
			if txt.contains(needle):
				bad.append(f + ":" + needle)
	var ok5 := eq(bad, [], "D5 no production adapter files, keys, URLs or device ids (%d scripts scanned)" % files.size())
	row("D5", ok5)
	# D6 Android INTERNET permission off while services are disabled (read-only check of 02/04 file)
	var inet := "missing"
	if FileAccess.file_exists("res://export_presets.cfg"):
		for line in FileAccess.get_file_as_string("res://export_presets.cfg").split("\n"):
			if line.strip_edges().begins_with("permissions/internet="):
				inet = line.strip_edges().get_slice("=", 1)
	var ok6 := check(inet == "false" or inet == "missing", "D6 Android INTERNET permission is %s (must stay off until ads/billing approved)" % inet)
	row("D6", ok6, {"permissions/internet": inet})
	return true

func _list_gd(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_list_gd(dir + "/" + sub))
	return out

# ------------------------------------------------------------------ I1–I6 integration contract

func test_integration_contract() -> bool:
	# I1 autoload registered after Save
	var names: Array = []
	for line in FileAccess.get_file_as_string("res://project.godot").split("\n"):
		var m := RegEx.create_from_string("^(\\w+)=\"\\*res://").search(line)
		if m:
			names.append(m.get_string(1))
	report.autoloads = names
	if names.has("Services"):
		report.integration["I1"] = "PASS" if check(names.find("Services") > names.find("Save"), "I1 Services autoload registered after Save") else "FAIL"
	else:
		blocked("I1", "Services autoload not registered in project.godot (02 S1)" + (" [simulated node added by test]" if simulated else ""))
	# I2 store bound to Save.progress.services, persistent, commits through Save
	use_dir("contract")
	var st = game_store()
	if st != null:
		report.integration["I2"] = "PASS_SIMULATED" if simulated else "PASS"
		passes += 1
	else:
		blocked("I2", "Services store not bound to Save.progress[\"services\"] (02 S1/S2: register autoload Services after Save; services.gd then auto-attaches, or call Services.attach_save(Save, Events))")
	# I3 save epoch available (sink contract enforcement)
	if st != null:
		report.integration["I3"] = "PASS" if check(st.save_epoch() >= 0, "I3 save epoch bound to /root/Events") else "FAIL"
	else:
		blocked("I3", "no game store, save epoch cannot be checked")
	# I4 rebinding after every Save.load_progress()
	# Stale right after the reload; bound again after ONE game frame (Services._process),
	# without the test calling ensure_bound() itself.
	crash_reload()
	if st != null:
		var stale_now: bool = raw_game_store() == null
		root.get_node("Services")._process(0.0)
		var rebound: bool = raw_game_store() != null
		report.integration["I4"] = "PASS" if check(rebound, "I4 Services rebinds within one frame after Save.load_progress() (stale before frame: %s)" % str(stale_now)) else "FAIL"
	else:
		blocked("I4", "rebinding after Save.load_progress() cannot be checked without the game binding (02 S1/S2)")
	# I5 grant sinks provided by the game (required only once 01 enables placements/products)
	var svc = root.get_node_or_null("Services")
	var cfg := Config.from_meta(Config.load_meta())
	if svc != null and svc.ads != null and svc.ads.grant_sink.is_valid():
		report.integration["I5"] = "PASS"
		passes += 1
	elif not cfg.ads.enabled and not cfg.iap.enabled:
		report.integration["I5"] = "NOT_REQUIRED_YET"   # 01 has no enabled placement/product (D9)
	else:
		blocked("I5", "01 enabled a placement/product but the game provides no grant sink (02 S3)")
	# I6 battle_uid from the real generator is accepted by the offer policy (02 S4 done in battle.gd)
	var BattleS = load("res://src/gameplay/battle.gd")
	var uid := ""
	if BattleS != null:
		var bn = BattleS.new()
		if bn.has_method("_make_battle_uid"):
			uid = bn._make_battle_uid()
		bn.free()
	if uid != "":
		var ev := Policy.evaluate({"reward": {"where": "results_win"}}, {"kind": "result", "result": {"won": true, "coins": 10, "battle_uid": uid}})
		report.integration["I6"] = "PASS" if check(ev.eligible and ev.context_id == "result:" + uid, "I6 real battle_uid (%s) accepted by reward policy" % uid) else "FAIL"
		var uid2 = BattleS.new()
		var u2: String = uid2._make_battle_uid()
		uid2.free()
		check(u2 != uid, "I6 two battle_uids differ")
	else:
		blocked("I6", "battle.gd _make_battle_uid() not found (02 S4)")
	return true

# ------------------------------------------------------------------ failure injection on the binding

func test_failure_injection() -> bool:
	for id in ["R1", "R2", "R3", "R6", "R8", "R9", "R14", "R15", "P1"]:
		var fn: String = TABLE[id]
		var completed = call(fn)
		if completed != true:
			check(false, id + " case aborted")
			row(id, false, "aborted")
	return true

func row_r1() -> bool:
	var dir := use_dir("r1")
	var b := mock_on(binding_store())
	b.ads.grant_sink = sink()
	b.ads.request("ad_double_gold", "result:r1"); pump(b.ads)
	var ok := eq(cl(disk(dir)), [100, 1], "R1 disk after ok save")
	crash_reload()
	var b2 := mock_on(binding_store())
	ok = eq(b2.ads.availability("ad_double_gold", "result:r1"), R.ALREADY_GRANTED, "R1 blocked after reload") and ok
	row("R1", ok, cl(disk(dir)))
	return true

func row_r2() -> bool:
	var dir := use_dir("r2")
	save.save_progress()
	var b := mock_on(binding_store())
	b.ads.grant_sink = sink()
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")   # fault injection: tmp cannot be created
	b.ads.request("ad_double_gold", "result:r2"); pump(b.ads)
	var mid := cl(disk(dir))
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	save.save_progress()   # next routine save
	var ok := eq(mid, [0, 0], "R2 nothing on disk while save fails") and eq(cl(disk(dir)), [100, 1], "R2 next save writes both")
	row("R2", ok, cl(disk(dir)))
	return true

func row_r3() -> bool:
	var dir := use_dir("r3")
	save.save_progress()
	var b := mock_on(binding_store())
	b.ads.grant_sink = sink()
	var persisted: Array = []
	b.ads.reward_granted.connect(func(_p, _r, _c, p): persisted.append(p))
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")
	b.ads.request("ad_double_gold", "result:r3"); pump(b.ads)
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	var ok := eq(persisted, [false], "R3 commit reported not persisted")
	ok = eq(cl(disk(dir)), [0, 0], "R3 disk after failed save") and ok
	crash_reload()
	var b2 := mock_on(binding_store())
	b2.ads.grant_sink = sink()
	ok = eq(b2.ads.availability("ad_double_gold", "result:r3"), R.OK, "R3 retryable after crash") and ok
	b2.ads.request("ad_double_gold", "result:r3"); pump(b2.ads)
	ok = eq(cl(disk(dir)), [100, 1], "R3 retry lands once") and ok
	row("R3", ok, cl(disk(dir)))
	return true

func row_r6() -> bool:
	var dir := use_dir("r6")
	var st = binding_store()
	var b := mock_on(st)
	var kinds: Array = []
	b.ads.contract_violation.connect(func(k): kinds.append(k))
	b.ads.grant_sink = sink(true, true)
	b.ads.request("ad_double_gold", "result:r6"); pump(b.ads)
	var ok := eq(cl(disk(dir)), [100, 1], "R6 disk")
	ok = check(kinds.has("ads_sink_saved") or st.save_epoch() < 0, "R6 violation flagged (%s)" % str(kinds)) and ok
	row("R6", ok, {"disk": cl(disk(dir)), "violations": kinds, "epoch_known": st.save_epoch() >= 0})
	return true

func row_r8() -> bool:
	var dir := use_dir("r8")
	var b := mock_on(binding_store())
	var codes: Array = []
	b.ads.finished.connect(func(_i, _p, c): codes.append(c))
	b.ads.grant_sink = sink(true, false)
	b.ads.request("ad_double_gold", "result:r8"); pump(b.ads)
	var d := disk(dir)
	var ok := eq(codes, [R.GRANT_FAILED], "R8 grant_failed")
	ok = eq(cl(d)[1], 1, "R8 ledger on disk") and ok
	ok = check(cl(d)[0] <= 100 * cl(d)[1], "R8 never coins without ledger") and ok
	crash_reload()
	var b2 := mock_on(binding_store())
	ok = eq(b2.ads.availability("ad_double_gold", "result:r8"), R.ALREADY_GRANTED, "R8 no duplicate after reload") and ok
	row("R8", ok, cl(d))
	return true

func row_r9() -> bool:
	var dir := use_dir("r9")
	save.save_progress()
	var b := mock_on(binding_store())
	b.ads.grant_sink = func(_p, _r, _c) -> bool: return false
	b.ads.request("ad_double_gold", "result:r9"); pump(b.ads)
	var ok := eq(cl(disk(dir)), [0, 0], "R9 disk unchanged")
	ok = eq(b.ads.availability("ad_double_gold", "result:r9"), R.OK, "R9 retryable") and ok
	row("R9", ok, cl(disk(dir)))
	return true

func row_r14() -> bool:
	var dir := use_dir("r14")
	var b := mock_on(binding_store())
	b.ads.grant_sink = sink()
	var codes: Array = []
	b.ads.finished.connect(func(_i, _p, c): codes.append(c))
	b.ads.request("ad_double_gold", "result:r14")
	crash_reload()   # Save.load_progress() while the ad is showing
	pump(b.ads)
	save.save_progress()
	var ok := eq(codes, [R.GRANT_FAILED], "R14 grant refused on stale store")
	ok = eq(cl(disk(dir)), [0, 0], "R14 disk consistent") and ok
	var b2 := mock_on(binding_store())
	ok = eq(b2.ads.availability("ad_double_gold", "result:r14"), R.OK, "R14 retryable with current binding") and ok
	row("R14", ok, cl(disk(dir)))
	return true

func row_r15() -> bool:
	var dir := use_dir("r15")
	var b := mock_on(binding_store())
	b.ads.grant_sink = sink()
	b.ads.request("ad_double_gold", "result:a"); pump(b.ads)
	b.ads.request("ad_double_gold", "result:b"); pump(b.ads)
	var f := FileAccess.open(dir + "/save.json", FileAccess.WRITE)
	f.store_string("{\"version\":1,\"checksum\":\"x\",\"payl")   # torn write
	f.close()
	crash_reload()
	var ok := eq(save.recovered, true, "R15 game Save recovered from .bak")
	var p: Dictionary = save.progress
	ok = eq(int(p.coins), 100 * p.get("services", {}).get("ads", {}).get("granted_contexts", {}).size(), "R15 recovered state consistent") and ok
	var b2 := mock_on(binding_store())
	ok = eq(b2.ads.availability("ad_double_gold", "result:a"), R.ALREADY_GRANTED, "R15 context in .bak blocked") and ok
	ok = eq(b2.ads.availability("ad_double_gold", "result:b"), R.OK, "R15 context lost with main file retryable") and ok
	row("R15", ok, {"recovered": save.recovered, "coins": int(p.coins)})
	return true

func row_p1() -> bool:
	var dir := use_dir("p1")
	save.save_progress()
	var b := mock_on(binding_store())
	b.purchases.grant_sink = func(_p, g, _k) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + int(g.coins)
		return true
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")
	b.purchases.purchase("test.coins_small")
	var owned: Dictionary = b.billing.owned.duplicate(true)
	pump(b.purchases)
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	var ok := eq(int(disk(dir).get("coins", 0)), 0, "P1 not on disk after failed save")
	crash_reload()
	for i in 2:
		var b2 := mock_on(binding_store())
		b2.billing.owned = owned.duplicate(true)
		b2.purchases.grant_sink = func(_p, g, _k) -> bool:
			save.progress["coins"] = int(save.progress["coins"]) + int(g.coins)
			return true
		b2.purchases.restore(); pump(b2.purchases)
		crash_reload()
	ok = eq(int(disk(dir).get("coins", 0)), 100, "P1 two restores after crash: granted exactly once") and ok
	row("P1", ok, {"coins": int(disk(dir).get("coins", 0))})
	return true

# ------------------------------------------------------------------ process death on the binding

func test_process_death() -> bool:
	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var want := {"kill_before_commit": [0, 0], "kill_after_commit": [100, 1], "sink_saves_then_kill": [100, 1]}
	var ids := {"kill_before_commit": "R4", "kill_after_commit": "R5", "sink_saves_then_kill": "R7"}
	for phase in want:
		var p: String = BASE + "/death_" + str(phase)
		_wipe(p)
		DirAccess.make_dir_recursive_absolute(p)
		var out: Array = []
		var code := OS.execute(exe, ["--headless", "--path", proj, "-s", "res://tests/services/integration_child.gd", "--",
			"--dir=" + p, "--phase=" + phase] + (["--simulate-integration"] if simulated else []), out, true)
		var marker := FileAccess.get_file_as_string(p + "/phase.txt") if FileAccess.file_exists(p + "/phase.txt") else ""
		var ok := check(marker.begins_with(phase) or marker.begins_with("after_commit"), "%s child reached phase (marker=%s exit=%d)" % [phase, marker, code])
		ok = check(code != 3 and code != 4 and code != 5, "%s child killed, not a normal quit (exit=%d)" % [phase, code]) and ok
		var d := disk(p)
		ok = check(not d.get("_corrupt", false), "%s save readable after kill" % phase) and ok
		ok = eq(cl(d), want[phase], "%s disk after process death" % phase) and ok
		var child_binding := "bridge_simulated"
		if marker.contains("binding=game"):
			child_binding = "game"
		elif marker.contains("binding=services_node_simulated"):
			child_binding = "services_node_simulated"
		report.rows[ids[phase]] = {"status": "PASS" if ok else "FAIL", "binding": child_binding,
			"game_evidence": ok and child_binding == "game" and not simulated, "detail": {"exit": code, "marker": marker, "disk": cl(d)}}
	return true

# ------------------------------------------------------------------ doc sync

func test_state_table_sync() -> bool:
	var path := "res://docs/services/REWARD_STATE_TABLE.md"
	if not check(FileAccess.file_exists(path), "REWARD_STATE_TABLE.md exists"):
		return true
	var ids: Array = []
	var re := RegEx.create_from_string("^\\| ([RPD]\\d+) \\|")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var m := re.search(line)
		if m:
			ids.append(m.get_string(1))
	var doc_ids := ids.duplicate()
	doc_ids.sort()
	var tab_ids: Array = TABLE.keys()
	tab_ids.sort()
	eq(doc_ids, tab_ids, "state table rows == test TABLE ids")
	for id in TABLE:
		if TABLE[id] != "":
			check(report.rows.has(id), "row %s has a result in this run" % id)
	report.table_rows = tab_ids.size()
	return true

# ------------------------------------------------------------------ release readiness doc sync

## RELEASE_READINESS_SERVICES.md: §1 requirements and §2 gap table must list the same IDs; every
## §1 row needs an official https source and a 2026 check date; §2 statuses come from a fixed set.
## OPEN_DECISIONS.md: user questions U1..Un are numbered consecutively (01 asks them in order).
func test_readiness_doc_sync() -> bool:
	var path := "res://docs/services/RELEASE_READINESS_SERVICES.md"
	if not check(FileAccess.file_exists(path), "RELEASE_READINESS_SERVICES.md exists"):
		return true
	var section := 0
	var req := {}
	var gap := {}
	var re := RegEx.create_from_string("^\\| ([BAVC]\\d+) \\|")
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("## 1."):
			section = 1
		elif line.begins_with("## 2."):
			section = 2
		elif line.begins_with("## "):
			section = 0
		var m := re.search(line)
		if m == null:
			continue
		if section == 1:
			req[m.get_string(1)] = line
		elif section == 2:
			gap[m.get_string(1)] = line
	var rk: Array = req.keys()
	rk.sort()
	var gk: Array = gap.keys()
	gk.sort()
	check(rk.size() >= 20, "readiness: at least 20 requirement rows (%d)" % rk.size())
	eq(gk, rk, "readiness: gap table IDs == requirement IDs")
	for id in req:
		check(str(req[id]).contains("https://"), "readiness %s has an official https source" % id)
		check(RegEx.create_from_string("\\| 2026-\\d\\d-\\d\\d").search(str(req[id])) != null, "readiness %s has a check date" % id)
	var allowed := ["MET", "MET (mock)", "PARTIAL", "MISSING", "N/A-YET", "UNVERIFIED", "MET (today) / MISSING (ads)"]
	for id in gap:
		var cells: PackedStringArray = str(gap[id]).split("|")
		var status := cells[2].strip_edges() if cells.size() > 2 else ""
		check(allowed.has(status), "readiness %s gap status '%s' is from the fixed set" % [id, status])
	var dpath := "res://docs/services/OPEN_DECISIONS.md"
	if check(FileAccess.file_exists(dpath), "OPEN_DECISIONS.md exists"):
		var ure := RegEx.create_from_string("^\\| U(\\d+) \\|")
		var nums: Array = []
		for line in FileAccess.get_file_as_string(dpath).split("\n"):
			var um := ure.search(line)
			if um:
				nums.append(int(um.get_string(1)))
		check(nums.size() >= 5, "open decisions: at least 5 user questions (%d)" % nums.size())
		var expect: Array = []
		for i in nums.size():
			expect.append(i + 1)
		eq(nums, expect, "open decisions: U1..Un consecutive, asked in order")
	report.readiness_rows = rk.size()
	return true
