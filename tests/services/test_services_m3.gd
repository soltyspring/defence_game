extends SceneTree
## 06-services M3 tests against the REAL src/core/save.gd script (not a double), with isolated
## user://svc_m3_test/<case>/ directories, plus consent flow and billing transitions.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_m3.gd
## Exit code 0 = all pass. Report: user://services_m3_test_report.json.
##
## What this proves: given the proposed SaveBridge wiring (request 06-services-to-02-engine S2),
## the real save.gd envelope (tmp -> rename, .bak, checksum) never ends up with a reward without
## its ledger entry or a ledger entry without its reward, including real process death
## (child Godot process killed with OS.kill at a chosen phase).
## What it does NOT prove: that the game wires it this way (02 has not integrated), Android
## process death/storage behaviour, or anything about real ads/billing (mocks only).

const R := preload("res://src/services/service_result.gd")
const SaveScript := preload("res://src/core/save.gd")
const EventsScript := preload("res://src/core/events.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Bridge := preload("res://src/services/save_bridge.gd")
const Store := preload("res://src/services/service_store.gd")
const ConsentS := preload("res://src/services/consent_service.gd")
const Flow := preload("res://src/services/consent/consent_flow.gd")
const MockConsent := preload("res://src/services/consent/mock_consent_provider.gd")
const DisabledConsent := preload("res://src/services/consent/disabled_consent_provider.gd")
const MockBilling := preload("res://src/services/billing/mock_billing_provider.gd")

const BASE := "user://svc_m3_test"
const ADS := {"enabled": true, "placements": {"ad_double_gold": {"daily_cap": 1000, "reward": {"effect": "gold_mult_2", "where": "results_win"}}}}
const IAP := {"enabled": true, "purchase_timeout_s": 10.0, "verify_timeout_s": 5.0,
	"catalog": {"test.supporter": {"type": "non_consumable", "entitlement": "remove_ads"},
		"test.coins_small": {"type": "consumable", "grant": {"coins": 100}}}}

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}}
var only: PackedStringArray = []
var events: Node
var saves_created: Array = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	events = root.get_node_or_null("Events")
	report["events_source"] = "autoload" if events != null else "local"
	if events == null:
		events = EventsScript.new()
		events.name = "Events"
		root.add_child(events)
	_wipe(BASE)
	DirAccess.make_dir_recursive_absolute(BASE)
	_group("real_save_roundtrip", test_roundtrip)
	_group("real_save_failed_commit", test_failed_commit)
	_group("sink_saves_then_fails", test_sink_saves_then_fails)
	_group("bak_and_checksum_recovery", test_recovery)
	_group("two_save_instances", test_two_saves)
	_group("migrate_keeps_services", test_migrate)
	_group("stale_store_after_reload", test_stale)
	_group("consumable_real_save", test_consumable)
	_group("process_death", test_process_death)
	_group("consent_flow", test_consent_flow)
	_group("billing_transitions", test_billing_transitions)
	for s in saves_created:
		if is_instance_valid(s):
			s.queue_free()
	_wipe(BASE)
	DirAccess.remove_absolute(BASE)
	report.passes = passes
	report.failures = Array(failures)
	report.pass = failures.is_empty()
	report.total_ms = Time.get_ticks_msec() - t0
	var f := FileAccess.open("user://services_m3_test_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services_m3] passes=%d failures=%d time_ms=%d events=%s" % [passes, failures.size(), report.total_ms, report.events_source])
	for g in report.groups:
		print("  %-28s %s" % [g, report.groups[g]])
	quit(0 if failures.is_empty() else 1)

func _group(name: String, fn: Callable) -> void:
	if not only.is_empty() and not only.has(name):
		return
	current = name
	var before := failures.size()
	var p0 := passes
	var completed = fn.call()
	if completed != true:
		check(false, "group aborted before its end (script error or early exit)")
	report.groups[name] = "PASS (%d checks)" % (passes - p0) if failures.size() == before else "FAIL"

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(current + ": " + msg)
		printerr("FAIL [%s] %s" % [current, msg])

func eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])

# ------------------------------------------------------------------ helpers

func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_wipe(dir + "/" + sub)
		d.remove(sub)

func case_dir(name: String) -> String:
	var p := BASE + "/" + name
	_wipe(p)
	DirAccess.make_dir_recursive_absolute(p)
	return p

## A real save.gd node at an isolated path, in the tree (so it emits /root/Events.progress_changed).
func new_save(dir: String) -> Node:
	var s = SaveScript.new()
	s.path = dir + "/save.json"
	root.add_child(s)   # _ready -> load_progress() at the isolated path
	saves_created.append(s)
	return s

func bundle_for(save: Node, with_epoch: bool = true, billing_owned: Dictionary = {}) -> Dictionary:
	var st = Bridge.make_store(save, events if with_epoch else null)
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": st,
		"overrides": {"ads": ADS, "iap": IAP}})
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	if not billing_owned.is_empty():
		b.billing.owned = billing_owned.duplicate(true)
	return b

## Raw on-disk payload read independently of save.gd (verifies checksum itself).
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

func ledger_n(p: Dictionary) -> int:
	return p.get("services", {}).get("ads", {}).get("granted_contexts", {}).size()

func coins(p: Dictionary) -> int:
	return int(p.get("coins", 0))

func coin_sink(save: Node, saves_itself: bool = false, result: bool = true) -> Callable:
	return func(_p, _r, _c) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + 100
		if saves_itself:
			save.save_progress()
		return result

func pump(svc, n: int = 40, dt: float = 0.0) -> void:
	for i in n:
		svc.tick(dt)

# ------------------------------------------------------------------ real Save tests

func test_roundtrip() -> bool:
	var dir := case_dir("roundtrip")
	var s := new_save(dir)
	check(s.progress is Dictionary and s.recovered == false, "fresh save at isolated path")
	var b := bundle_for(s)
	eq(b.store.is_persistent(), true, "bridge store persistent")
	var e0: int = b.store.save_epoch()
	check(e0 >= 0, "epoch source bound to /root/Events (consent commit already counted: %d)" % e0)
	b.ads.grant_sink = coin_sink(s)
	b.ads.request("ad_double_gold", "result:a1"); pump(b.ads)
	eq(b.store.save_epoch(), e0 + 1, "service commit = exactly one real save")
	var d := disk(dir)
	eq(coins(d), 100, "reward on disk")
	eq(ledger_n(d), 1, "ledger on disk")
	var s2 := new_save(dir)
	var b2 := bundle_for(s2)
	eq(b2.ads.availability("ad_double_gold", "result:a1"), R.ALREADY_GRANTED, "reloaded real save blocks same context")
	check(FileAccess.file_exists(dir + "/save.json"), "save.json written")
	check(not FileAccess.file_exists(dir + "/save.json.tmp"), "no tmp left behind")
	return true

func test_failed_commit() -> bool:
	var dir := case_dir("failed_commit")
	var s := new_save(dir)
	s.save_progress()   # baseline on disk
	var b := bundle_for(s)
	b.ads.grant_sink = coin_sink(s)
	# Make the real atomic save fail: a directory where save.json.tmp must be created.
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")
	var persisted: Array = []
	b.ads.reward_granted.connect(func(_p, _r, _c, ok): persisted.append(ok))
	b.ads.request("ad_double_gold", "result:f1"); pump(b.ads)
	eq(persisted, [false], "real save failure reported as persisted=false")
	check(s.last_error != "", "save.gd recorded an error (%s)" % s.last_error)
	var d := disk(dir)
	eq(coins(d), 0, "failed commit: reward not on disk")
	eq(ledger_n(d), 0, "failed commit: ledger not on disk")
	eq(b.ads.availability("ad_double_gold", "result:f1"), R.ALREADY_GRANTED, "same session still blocks repeat (memory)")
	# Simulated crash now: reload from disk -> context retryable, granted once.
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	var s2 := new_save(dir)
	var b2 := bundle_for(s2)
	b2.ads.grant_sink = coin_sink(s2)
	eq(b2.ads.availability("ad_double_gold", "result:f1"), R.OK, "after crash the lost grant is retryable")
	b2.ads.request("ad_double_gold", "result:f1"); pump(b2.ads)
	d = disk(dir)
	eq([coins(d), ledger_n(d)], [100, 1], "retry: exactly one reward and one ledger entry on disk")
	# No crash path: the next successful save writes reward and ledger together.
	var dir2 := case_dir("failed_commit_nocrash")
	var s3 := new_save(dir2)
	s3.save_progress()
	var b3 := bundle_for(s3)
	b3.ads.grant_sink = coin_sink(s3)
	DirAccess.make_dir_absolute(dir2 + "/save.json.tmp")
	b3.ads.request("ad_double_gold", "result:f2"); pump(b3.ads)
	DirAccess.remove_absolute(dir2 + "/save.json.tmp")
	s3.save_progress()   # e.g. the game's next routine save
	d = disk(dir2)
	eq([coins(d), ledger_n(d)], [100, 1], "next routine save persists both together")
	return true

func test_sink_saves_then_fails() -> bool:
	# Regression for the handoff risk: grant sink saves on its own, then returns false.
	for with_epoch in [true, false]:
		var tag := "epoch" if with_epoch else "noepoch"
		var dir := case_dir("sink_saves_fail_" + tag)
		var s := new_save(dir)
		var b := bundle_for(s, with_epoch)
		var kinds: Array = []
		b.ads.contract_violation.connect(func(k): kinds.append(k))
		var codes: Array = []
		b.ads.finished.connect(func(_i, _p, c): codes.append(c))
		b.ads.grant_sink = coin_sink(s, true, false)   # saves, then reports failure
		b.ads.request("ad_double_gold", "result:s1"); pump(b.ads)
		eq(codes, [R.GRANT_FAILED], tag + ": finished grant_failed")
		check(kinds.has("ads_sink_saved_then_failed" if with_epoch else "ads_failed_epoch_unknown"), tag + ": contract violation reported (%s)" % str(kinds))
		var d := disk(dir)
		eq(coins(d), 100, tag + ": the sink's own save put the reward on disk")
		eq(ledger_n(d), 1, tag + ": ledger kept on disk with it (never reward without ledger)")
		check(d.get("services", {}).get("ads", {}).get("granted_contexts", {}).get("result:s1", {}).get("grant_unknown", false) == true, tag + ": entry marked grant_unknown")
		eq(b.ads.availability("ad_double_gold", "result:s1"), R.ALREADY_GRANTED, tag + ": no retry in this session")
		var s2 := new_save(dir)
		var b2 := bundle_for(s2, with_epoch)
		eq(b2.ads.availability("ad_double_gold", "result:s1"), R.ALREADY_GRANTED, tag + ": no duplicate after restart")
		check(b.ads.diagnostics.contract_violation >= 1, tag + ": violation counted in diagnostics")
	# Sink fails WITHOUT saving (epoch known): normal rollback, retry allowed, disk untouched.
	var dir3 := case_dir("sink_fails_clean")
	var s3 := new_save(dir3)
	s3.save_progress()
	var b3 := bundle_for(s3)
	var ep0: int = b3.store.save_epoch()
	b3.ads.grant_sink = func(_p, _r, _c) -> bool: return false
	b3.ads.request("ad_double_gold", "result:s2"); pump(b3.ads)
	eq(b3.store.save_epoch(), ep0, "clean failure: no save happened")
	eq(b3.ads.availability("ad_double_gold", "result:s2"), R.OK, "clean failure: retry allowed")
	eq(b3.ads.diagnostics.contract_violation, 0, "clean failure: no violation")
	# Sink saves AND succeeds: safe (ledger-first), still flagged as a violation.
	var dir4 := case_dir("sink_saves_ok")
	var s4 := new_save(dir4)
	var b4 := bundle_for(s4)
	var k4: Array = []
	b4.ads.contract_violation.connect(func(k): k4.append(k))
	b4.ads.grant_sink = coin_sink(s4, true, true)
	b4.ads.request("ad_double_gold", "result:s3"); pump(b4.ads)
	var d4 := disk(dir4)
	eq([coins(d4), ledger_n(d4)], [100, 1], "sink save + success: both on disk once")
	eq(k4, ["ads_sink_saved"], "sink save + success flagged")
	return true

func test_recovery() -> bool:
	var dir := case_dir("recovery")
	var s := new_save(dir)
	var b := bundle_for(s)
	b.ads.grant_sink = coin_sink(s)
	b.ads.request("ad_double_gold", "result:r1"); pump(b.ads)
	b.ads.request("ad_double_gold", "result:r2"); pump(b.ads)
	var bak := disk(dir, "save.json.bak")
	eq([coins(bak), ledger_n(bak)], [100, 1], ".bak = state after first grant (consistent)")
	# Corrupt main file (torn write / storage damage).
	var f := FileAccess.open(dir + "/save.json", FileAccess.WRITE)
	f.store_string("{\"version\":1,\"checksum\":\"x\",\"payl")
	f.close()
	var s2 := new_save(dir)
	eq(s2.recovered, true, "real save.gd recovered from .bak")
	eq(coins(s2.progress), 100 * ledger_n(s2.progress), "recovered state consistent: coins == 100 x ledger")
	var b2 := bundle_for(s2)
	b2.ads.grant_sink = coin_sink(s2)
	eq(b2.ads.availability("ad_double_gold", "result:r1"), R.ALREADY_GRANTED, "context in .bak still blocked")
	eq(b2.ads.availability("ad_double_gold", "result:r2"), R.OK, "context lost with main file retryable (its reward was lost too)")
	b2.ads.request("ad_double_gold", "result:r2"); pump(b2.ads)
	var d := disk(dir)
	eq([coins(d), ledger_n(d)], [200, 2], "after re-grant: each context once")
	# Checksum tamper (payload edited without fixing checksum) -> .bak.
	var raw := FileAccess.get_file_as_string(dir + "/save.json")
	var j := JSON.new()
	j.parse(raw)
	var env: Dictionary = j.data
	var pj := JSON.new()
	pj.parse(str(env.payload))
	var tampered: Dictionary = pj.data
	tampered["coins"] = 99999
	env.payload = JSON.stringify(tampered, "", true)   # old checksum kept
	check(str(env.payload).contains("99999") and str(env.payload).sha256_text() != str(env.checksum), "tamper applied, checksum now stale")
	f = FileAccess.open(dir + "/save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	var s3 := new_save(dir)
	eq(s3.recovered, true, "checksum mismatch -> recovered from .bak")
	check(coins(s3.progress) != 99999, "tampered coins rejected")
	eq(coins(s3.progress), 100 * ledger_n(s3.progress), "recovered state consistent after tamper")
	return true

func test_two_saves() -> bool:
	# Two live Save instances on one file (e.g. duplicate bootstrap): last writer wins.
	var dir := case_dir("two_saves")
	var a := new_save(dir)
	var bsv := new_save(dir)
	var ba := bundle_for(a)
	var bb := bundle_for(bsv)
	ba.ads.grant_sink = coin_sink(a)
	bb.ads.grant_sink = coin_sink(bsv)
	ba.ads.request("ad_double_gold", "result:same"); pump(ba.ads)
	bb.ads.request("ad_double_gold", "result:same"); pump(bb.ads)
	var d := disk(dir)
	eq([coins(d), ledger_n(d)], [100, 1], "same context from two instances: one reward on disk")
	ba.ads.request("ad_double_gold", "result:x1"); pump(ba.ads)
	bb.ads.request("ad_double_gold", "result:x2"); pump(bb.ads)
	d = disk(dir)
	eq(coins(d), 100 * ledger_n(d), "different contexts: last writer wins but disk stays consistent (no reward without ledger)")
	report["two_saves_note"] = "last-writer-wins loses the other instance's grant entirely; requires single Save instance (02)"
	return true

func test_migrate() -> bool:
	var dir := case_dir("migrate")
	var s := new_save(dir)
	var b := bundle_for(s)
	b.ads.grant_sink = coin_sink(s)
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	b.ads.request("ad_double_gold", "result:m1"); pump(b.ads)
	# Write a v0 (no version) payload that still carries services, like an old/edited save.
	var p: Dictionary = disk(dir)
	p.erase("version")
	p.erase("settings")
	var txt := JSON.stringify(p)
	var f := FileAccess.open(dir + "/save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 0, "checksum": txt.sha256_text(), "payload": txt}))
	f.close()
	var s2 := new_save(dir)
	eq(s2.recovered, false, "v0 payload loaded without recovery")
	check(s2.progress.get("services") is Dictionary, "_migrate kept services key")
	var b2 := bundle_for(s2)
	eq(b2.purchases.has_entitlement("remove_ads"), true, "entitlement survives migration")
	eq(b2.ads.availability("ad_double_gold", "result:m1"), R.ALREADY_GRANTED, "ledger survives migration")
	# Save without services (pre-06 save): bridge adds an empty section.
	var dir2 := case_dir("migrate_none")
	var s3 := new_save(dir2)
	s3.progress.erase("services")
	s3.save_progress()
	var s4 := new_save(dir2)
	var b4 := bundle_for(s4)
	check(s4.progress.get("services") is Dictionary, "bridge adds services to a pre-06 save")
	eq(b4.ads.availability("ad_double_gold", "result:n1"), R.OK, "pre-06 save usable")
	return true

func test_stale() -> bool:
	var dir := case_dir("stale")
	var s := new_save(dir)
	var b := bundle_for(s)
	b.ads.grant_sink = coin_sink(s)
	s.load_progress()   # replaces s.progress: the store is now bound to a stale Dictionary
	eq(b.store.is_usable(), false, "bridge detects reload")
	eq(b.ads.availability("ad_double_gold", "result:st1"), R.ERROR, "stale store: no offer")
	# Reload during an active ad.
	var dir2 := case_dir("stale_mid_ad")
	var s2 := new_save(dir2)
	var b2 := bundle_for(s2)
	b2.ads.grant_sink = coin_sink(s2)
	var codes: Array = []
	b2.ads.finished.connect(func(_i, _p, c): codes.append(c))
	b2.ads.request("ad_double_gold", "result:st2")
	s2.load_progress()
	pump(b2.ads)
	eq(codes, [R.GRANT_FAILED], "reload during ad -> grant refused")
	eq(coins(s2.progress), 0, "no reward applied to new progress")
	s2.save_progress()
	var d := disk(dir2)
	eq([coins(d), ledger_n(d)], [0, 0], "disk consistent after refused stale grant")
	var b3 := bundle_for(s2)
	b3.ads.grant_sink = coin_sink(s2)
	eq(b3.ads.availability("ad_double_gold", "result:st2"), R.OK, "fresh store after reload works")
	return true

func test_consumable() -> bool:
	var dir := case_dir("consumable")
	var s := new_save(dir)
	s.save_progress()
	var b := bundle_for(s)
	b.purchases.grant_sink = coin_sink(s)
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")
	b.purchases.purchase("test.coins_small")
	# Store-side ownership right after payment (the mock consumes in-process; a real crash
	# before the consume call leaves the store still reporting it).
	var owned_at_grant: Dictionary = b.billing.owned.duplicate(true)
	check(owned_at_grant.has("test.coins_small"), "precondition: store reports purchase")
	pump(b.purchases)
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	var d := disk(dir)
	eq(coins(d), 0, "consumable: failed real save -> not on disk")
	# Crash, then the store still reports the purchase (consume never confirmed): restore.
	var s2 := new_save(dir)
	var b2 := bundle_for(s2, true, owned_at_grant)
	b2.purchases.grant_sink = coin_sink(s2)
	b2.purchases.restore(); pump(b2.purchases)
	eq(coins(disk(dir)), 100, "restore after crash grants once")
	var s3 := new_save(dir)
	var b3 := bundle_for(s3, true, owned_at_grant)
	b3.purchases.grant_sink = coin_sink(s3)
	b3.purchases.restore(); pump(b3.purchases)
	eq(coins(disk(dir)), 100, "second restore does not regrant")
	check(b3.billing.consumes >= 1, "restore consumes the still-owned purchase")
	# Consumable sink saves then fails: never regrant, never consume.
	var dir2 := case_dir("consumable_sink_fail")
	var s4 := new_save(dir2)
	var b4 := bundle_for(s4)
	var kinds: Array = []
	b4.purchases.contract_violation.connect(func(k): kinds.append(k))
	b4.purchases.grant_sink = coin_sink(s4, true, false)
	var codes: Array = []
	b4.purchases.purchase_finished.connect(func(_p, c): codes.append(c))
	b4.purchases.purchase("test.coins_small")
	var owned2: Dictionary = b4.billing.owned.duplicate(true)
	check(owned2.has("test.coins_small"), "precondition: store reports purchase")
	pump(b4.purchases)
	check(b4.billing.owned.has("test.coins_small"), "grant_unknown purchase still owned in store (not consumed)")
	eq(codes, [R.GRANT_FAILED], "consumable saved-then-failed -> grant_failed")
	check(kinds.has("iap_sink_saved_then_failed"), "iap violation reported")
	eq(b4.billing.consumes, 0, "not consumed (store can refund)")
	var s5 := new_save(dir2)
	var b5 := bundle_for(s5, true, owned2)
	b5.purchases.grant_sink = coin_sink(s5)
	b5.purchases.restore(); pump(b5.purchases)
	eq(coins(disk(dir2)), 100, "restore does not regrant a grant_unknown purchase")
	eq(b5.billing.consumes, 0, "grant_unknown purchase never consumed")
	return true

func test_process_death() -> bool:
	# TP-08 (10-research): real process death between reward and commit. Child Godot process
	# uses the real save.gd and kills itself with OS.kill(own pid).
	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var cases := {
		"kill_before_commit": [0, 0],     # neither reward nor ledger
		"kill_after_commit": [100, 1],    # both
		"sink_saves_then_kill": [100, 1], # both, thanks to ledger-first
	}
	var results := {}
	for phase in cases:
		var dir := case_dir("death_" + phase)
		var out: Array = []
		var code := OS.execute(exe, ["--headless", "--path", proj, "-s", "res://tests/services/m3_child.gd", "--",
			"--dir=" + dir, "--phase=" + phase, "--ctx=result:death"], out, true)
		var marker := FileAccess.get_file_as_string(dir + "/phase.txt") if FileAccess.file_exists(dir + "/phase.txt") else ""
		check(marker != "" and not marker.begins_with("no_kill"), "%s: child reached kill phase (marker=%s exit=%d)" % [phase, marker, code])
		# The child only exits normally via quit(3) (kill failed) or quit(4) (phase not reached).
		check(code != 3 and code != 4, "%s: child terminated by OS.kill, not a normal quit (exit=%d)" % [phase, code])
		var d := disk(dir)
		check(not d.get("_corrupt", false), "%s: save on disk readable after kill" % phase)
		var s := new_save(dir)
		var got := [coins(s.progress), ledger_n(s.progress)]
		eq(got, cases[phase], "%s: disk after process death" % phase)
		eq(coins(s.progress), 100 * ledger_n(s.progress), "%s: invariant coins == 100 x ledger" % phase)
		var b := bundle_for(s)
		var expect := R.OK if cases[phase][1] == 0 else R.ALREADY_GRANTED
		eq(b.ads.availability("ad_double_gold", "result:death"), expect, "%s: retry allowed only if nothing persisted" % phase)
		results[phase] = {"exit": code, "marker": marker, "coins": got[0], "ledger": got[1]}
	report["process_death"] = results
	return true

# ------------------------------------------------------------------ consent flow

func flow_setup(cfg: Dictionary = {}) -> Array:
	var st := Store.new()
	var c := ConsentS.new(st, 1)
	var p := MockConsent.new()
	var f := Flow.new(p, c, cfg)
	return [f, p, c]

func test_consent_flow() -> bool:
	# Disabled provider: unsupported, nothing changes.
	var c0 := ConsentS.new(Store.new(), 1)
	var f0 := Flow.new(DisabledConsent.new(), c0)
	eq(f0.start(), R.UNSUPPORTED, "disabled provider -> unsupported")
	eq(c0.get_choice("ads"), ConsentS.UNKNOWN, "disabled provider changes nothing")
	eq(Factory.create({}).consent_flow.start(), R.UNSUPPORTED, "default build consent flow unsupported")

	# required -> form accept_all
	var a := flow_setup(); var f: Flow = a[0]; var p = a[1]; var c = a[2]
	eq(f.start(), R.OK, "start")
	eq(f.state, Flow.CHECKING, "checking")
	eq(f.start(), R.BUSY, "busy while checking")
	f.tick(0.0)
	eq(f.state, Flow.FORM_REQUIRED, "required -> form_required")
	eq(c.check("ads"), R.CONSENT_REQUIRED, "ads still blocked before form")
	eq(f.show_form(), R.OK, "show form")
	f.tick(0.0)
	eq(f.state, Flow.DONE, "form ok -> done")
	eq([c.get_choice("ads"), c.get_choice("ads_personalized")], ["granted", "granted"], "accept_all applied")
	eq(c.get_choice("analytics"), ConsentS.UNKNOWN, "platform form never sets analytics")

	# required -> dismissed -> ads_only
	a = flow_setup(); f = a[0]; p = a[1]; c = a[2]
	p.form_scenarios.assign(["dismissed", "ads_only"])
	f.start(); f.tick(0.0); f.show_form(); f.tick(0.0)
	eq([f.state, f.last_code], [Flow.FORM_REQUIRED, R.CANCELLED], "dismissed -> back to form_required")
	eq(c.get_choice("ads"), ConsentS.UNKNOWN, "dismissed changes nothing")
	f.show_form(); f.tick(0.0)
	eq([c.get_choice("ads"), c.get_choice("ads_personalized")], ["granted", "denied"], "ads_only: non-personalised")

	# not_required: only unknown ads purposes become not_required; explicit denial kept.
	a = flow_setup(); f = a[0]; p = a[1]; c = a[2]
	c.set_choice("ads_personalized", "denied")
	p.info_scenarios.assign(["not_required"])
	var fin: Array = []
	f.finished.connect(func(code, req): fin.append([code, req]))
	f.start(); f.tick(0.0)
	eq(fin, [[R.OK, "not_required"]], "not_required finishes ok")
	eq(c.get_choice("ads"), ConsentS.NOT_REQUIRED, "unknown ads -> not_required")
	eq(c.get_choice("ads_personalized"), "denied", "explicit denial never overridden")
	eq(c.get_choice("analytics"), ConsentS.UNKNOWN, "not_required does not touch analytics")
	eq(c.check("ads"), R.OK, "ads allowed when not required")

	# offline / error / timeout: nothing changes, ads stay blocked.
	for sc in ["offline", "error"]:
		a = flow_setup(); f = a[0]; p = a[1]; c = a[2]
		p.info_scenarios.assign([sc])
		f.start(); f.tick(0.0)
		eq([f.state, f.last_code], [Flow.DONE, R.OFFLINE if sc == "offline" else R.ERROR], sc + " -> done with code")
		eq(c.check("ads"), R.CONSENT_REQUIRED, sc + ": ads stay blocked")
	a = flow_setup({"info_timeout_s": 3.0}); f = a[0]; p = a[1]; c = a[2]
	p.info_scenarios.assign(["hang"])
	f.start()
	for i in 4: f.tick(1.0)
	eq([f.state, f.last_code], [Flow.DONE, R.TIMEOUT], "info timeout")
	p.inject("info", "ok", "not_required"); f.tick(0.0)
	eq(c.get_choice("ads"), ConsentS.UNKNOWN, "late info after timeout ignored")
	eq(f.diagnostics.stray, 1, "late info counted as stray")
	a = flow_setup({"form_timeout_s": 3.0}); f = a[0]; p = a[1]; c = a[2]
	p.form_scenarios.assign(["hang"])
	f.start(); f.tick(0.0); f.show_form()
	for i in 4: f.tick(1.0)
	eq([f.state, f.last_code], [Flow.FORM_REQUIRED, R.TIMEOUT], "form timeout -> form_required")
	p.inject("form", "ok", {"ads": "granted"}); f.tick(0.0)
	eq(c.get_choice("ads"), ConsentS.UNKNOWN, "late form result ignored")
	p.form_scenarios.assign(["error"])
	f.show_form(); f.tick(0.0)
	eq([f.state, f.last_code], [Flow.FORM_REQUIRED, R.ERROR], "form error -> form_required")

	# obtained earlier: done without form. Privacy options re-open the form.
	a = flow_setup(); f = a[0]; p = a[1]; c = a[2]
	c.set_choice("ads", "granted")
	p.info_scenarios.assign(["obtained"])
	f.start(); f.tick(0.0)
	eq(f.state, Flow.DONE, "obtained -> done")
	eq(p.form_calls, 0, "no form when obtained")
	p.form_scenarios.assign(["reject_all"])
	eq(f.show_privacy_options(), R.OK, "privacy options open form")
	f.tick(0.0)
	eq(c.check("ads"), R.CONSENT_REQUIRED, "reject via privacy options blocks ads")

	# withdrawal: everything denied, platform reset, next start re-checks.
	a = flow_setup(); f = a[0]; p = a[1]; c = a[2]
	f.start(); f.tick(0.0); f.show_form(); f.tick(0.0)
	c.set_choice("analytics", "granted")
	f.withdraw()
	eq([c.get_choice("ads"), c.get_choice("ads_personalized"), c.get_choice("analytics")], ["denied", "denied", "denied"], "withdraw denies all")
	eq(p.resets, 1, "platform consent reset")
	eq(f.state, Flow.IDLE, "withdraw -> idle")
	p.info_scenarios.assign(["not_required"])
	f.start(); f.tick(0.0)
	eq(c.get_choice("ads"), "denied", "after withdrawal not_required does not re-enable ads")

	# Ads integration: an ad request is still blocked until the flow grants or not_required.
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(),
		"overrides": {"ads": ADS}})
	b.ads.grant_sink = func(_p, _r, _c) -> bool: return true
	eq(b.ads.availability("ad_double_gold", "result:c1"), R.CONSENT_REQUIRED, "before flow: blocked")
	b.consent_provider.info_scenarios.assign(["not_required"])
	b.consent_flow.start(); b.consent_flow.tick(0.0)
	eq(b.ads.availability("ad_double_gold", "result:c1"), R.OK, "after not_required: allowed")
	eq(b.consent.personalized_ads_allowed(), false, "audience unknown -> still non-personalised")
	return true

# ------------------------------------------------------------------ billing transitions

func test_billing_transitions() -> bool:
	for notify in [false, true]:
		var tag := "notify" if notify else "silent"
		var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(), "overrides": {"iap": IAP}})
		var fin: Array = []
		b.purchases.purchase_finished.connect(func(_p, c): fin.append(c))
		var ents: Array = []
		b.purchases.entitlement_changed.connect(func(e, o): ents.append([e, o]))
		b.billing.purchase_scenarios.assign(["pending"])
		b.purchases.purchase("test.supporter"); pump(b.purchases)
		eq(fin, [R.PENDING], tag + ": pending")
		b.purchases.restore(); pump(b.purchases)
		var rs := [0]
		b.purchases.restore_finished.connect(func(s): rs[0] = int(s.pending))
		b.purchases.restore(); pump(b.purchases)
		eq(rs[0], 1, tag + ": restore reports pending (Play returns pending in owned query)")
		b.billing.cancel_pending("test.supporter", notify)
		pump(b.purchases)
		eq(b.purchases.has_entitlement("remove_ads"), false, tag + ": cancelled pending never granted")
		eq(b.billing.acks, 0, tag + ": cancelled pending never acknowledged")
		eq(b.purchases._ledger().size(), 0, tag + ": no ledger entry for cancelled pending")
		if notify:
			eq(b.purchases.diagnostics.unknown_state, 1, "notify: unspecified-state update counted, not granted")
		b.purchases.restore(); pump(b.purchases)
		eq(b.purchases.has_entitlement("remove_ads"), false, tag + ": restore after cancel grants nothing")
		eq(b.purchases.availability("test.supporter"), R.OK, tag + ": product can be bought again")
		b.purchases.purchase("test.supporter"); pump(b.purchases)
		eq(b.purchases.has_entitlement("remove_ads"), true, tag + ": new purchase after cancel works")
		eq(ents, [["remove_ads", true]], tag + ": one entitlement event")

	# A pending purchase cancelled while the purchase flow is still waiting (notify update).
	var b2 := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(), "overrides": {"iap": IAP}})
	var f2: Array = []
	b2.purchases.purchase_finished.connect(func(_p, c): f2.append(c))
	b2.billing.purchase_scenarios.assign(["hang"])
	b2.purchases.purchase("test.supporter")
	var u: Dictionary = b2.billing._make("test.supporter", "unspecified")
	b2.billing.purchase_updated.emit("ok", [u])
	pump(b2.purchases)
	eq(f2, [R.CANCELLED], "unspecified state during flow -> cancelled, not granted")
	eq(b2.purchases.has_entitlement("remove_ads"), false, "unspecified never grants")

	# Acknowledged elsewhere: reinstall + restore where the store already shows acknowledged.
	var b3 := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(), "overrides": {"iap": IAP}})
	b3.purchases.purchase("test.supporter"); pump(b3.purchases)
	eq(b3.billing.acks, 1, "first device acknowledged once")
	var b4 := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(), "overrides": {"iap": IAP}})
	b4.billing.owned = b3.billing.owned.duplicate(true)
	b4.billing.acknowledge_elsewhere("test.supporter")
	b4.purchases.restore(); pump(b4.purchases)
	eq(b4.purchases.has_entitlement("remove_ads"), true, "ack-elsewhere purchase restored")
	eq(b4.billing.acks, 0, "no redundant acknowledge for ack-elsewhere")
	eq(b4.purchases.diagnostics.ack_elsewhere, 1, "ack_elsewhere counted")
	var led: Dictionary = b4.purchases._ledger()
	check(led.values().all(func(e): return e.acknowledged == true), "ledger records acknowledged=true")
	# Our own ack failed earlier, then another device acknowledged: restore records it without re-ack.
	var b5 := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(), "overrides": {"iap": IAP}})
	b5.billing.ack_fail = true
	b5.purchases.purchase("test.supporter"); pump(b5.purchases)
	b5.billing.ack_fail = false
	b5.billing.acknowledge_elsewhere("test.supporter")
	var acks0: int = b5.billing.acks
	b5.purchases.restore(); pump(b5.purchases)
	eq(b5.billing.acks, acks0, "failed own ack + acknowledged elsewhere: no retry needed")
	check(b5.purchases._ledger().values().all(func(e): return e.acknowledged == true), "ledger marked acknowledged")
	return true
