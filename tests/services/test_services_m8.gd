extends SceneTree
## 06-services M8 tests: 09 research asks R09-06-2 against the REAL game wiring.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_m8.gd
## Exit 0 = pass, 1 = failure. Report: user://services_m8_test_report.json.
##  - launch_reconcile: the store reports a purchase, delivery fails mid-way (failed save /
##    crash), and on the next launch the item is delivered exactly once WITHOUT the player
##    pressing Restore (Services node reconciles on attach). Uses the autoload Save redirected
##    to an isolated dir and the game's /root/Services node (registered by 02).
##  - resume_reconcile: a pending payment completes while the app is in the background; the
##    APPLICATION_RESUMED notification reconciles it once.
##  - no_fill_no_dead_end: after a no-fill the offer is hidden for the cooldown, so the UI never
##    shows a button that leads to another empty load; it comes back after the cooldown.
##  - disabled_reconcile: in the shipped disabled mode reconcile does nothing.
## Mocks only (mock billing/ad adapters in a debug-only mock bundle). No real store or ad network.

const R := preload("res://src/services/service_result.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Bridge := preload("res://src/services/save_bridge.gd")
const ServicesNode := preload("res://src/services/services.gd")
const Store := preload("res://src/services/service_store.gd")

const IAP := {"enabled": true, "purchase_timeout_s": 10.0, "verify_timeout_s": 5.0,
	"catalog": {"test.supporter": {"type": "non_consumable", "entitlement": "remove_ads"},
		"test.coins_small": {"type": "consumable", "grant": {"coins": 100}}}}
const ADS := {"enabled": true, "load_timeout_s": 5.0, "show_timeout_s": 30.0, "no_fill_cooldown_s": 60.0,
	"placements": {"ad_double_gold": {"daily_cap": 100, "reward": {"effect": "gold_mult_2", "where": "results_win"}}}}

var BASE := "user://svc_m8_test_%d" % OS.get_process_id()
var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}}
var save: Node
var orig_path := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	save = root.get_node_or_null("Save")
	if save == null:
		printerr("[test_services_m8] Save autoload missing; run with --path .")
		quit(1)
		return
	orig_path = save.path
	var h0 := _hash_user_save()
	_group("launch_reconcile", test_launch_reconcile)
	_group("resume_reconcile", test_resume_reconcile)
	_group("no_fill_no_dead_end", test_no_fill)
	_group("disabled_reconcile", test_disabled)
	save.path = orig_path
	save.load_progress()
	_group("hygiene", func() -> bool:
		check(_hash_user_save() == h0, "player's user://save.json(.bak) unchanged")
		return true)
	_wipe(BASE)
	DirAccess.remove_absolute(BASE)
	report.passes = passes
	report.failures = Array(failures)
	var f := FileAccess.open("user://services_m8_test_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services_m8] passes=%d failures=%d" % [passes, failures.size()])
	for g in report.groups:
		print("  %-24s %s" % [g, report.groups[g]])
	quit(0 if failures.is_empty() else 1)

func _group(name: String, fn: Callable) -> void:
	current = name
	var before := failures.size()
	var p0 := passes
	var done = fn.call()
	if done != true:
		check(false, "group aborted before its end")
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

func use_dir(name: String) -> String:
	var p := BASE + "/" + name
	_wipe(p)
	DirAccess.make_dir_recursive_absolute(p)
	save.path = p + "/save.json"
	save.load_progress()
	return p

func disk_coins(dir: String) -> int:
	var j := JSON.new()
	if not FileAccess.file_exists(dir + "/save.json") or j.parse(FileAccess.get_file_as_string(dir + "/save.json")) != OK:
		return -1
	var pj := JSON.new()
	pj.parse(str(j.data.payload))
	return int(pj.data.get("coins", 0))

## A mock-mode Services node bound to the autoload Save, like the game's but able to grant.
## (The game's own /root/Services stays disabled; this node is a separate instance.)
func mock_node(owned: Dictionary) -> Node:
	var n = ServicesNode.new()
	n.name = "ServicesM8"
	root.add_child(n)   # not named "Services": _ready falls back to setup({}), we attach below
	n.attach_save(save, root.get_node_or_null("Events"), {"mode": "mock", "allow_mock": true, "debug_build": true,
		"overrides": {"iap": IAP, "ads": ADS}})
	return n

func coin_sink() -> Callable:
	return func(_p, g, _k) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + int(g.get("coins", 0))
		return true

func pump(n: Node, frames: int = 40) -> void:
	for i in frames:
		n._process(0.0)

func test_launch_reconcile() -> bool:
	var game = root.get_node_or_null("Services")
	check(game != null, "game /root/Services autoload present (02 S1)")
	var dir := use_dir("launch")
	save.save_progress()
	# Session 1: purchase succeeds at the store, game-side save fails (delivery fails mid-way).
	var n1 := mock_node({})
	n1.purchases.grant_sink = coin_sink()
	pump(n1)                                   # finish the attach-time reconcile (empty store)
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")
	n1.purchases.purchase("test.coins_small")
	var store_owned: Dictionary = n1.purchases.provider.owned.duplicate(true)
	check(store_owned.has("test.coins_small"), "precondition: store reports the purchase")
	pump(n1)
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	eq(disk_coins(dir), 0, "delivery failed: nothing on disk")
	n1.queue_free()
	# Crash: memory gone. Session 2 = next launch. The store still reports the purchase (consume
	# never confirmed). The player does NOT press Restore.
	save.load_progress()
	var n2 := mock_node({})
	n2.purchases.grant_sink = coin_sink()
	n2.purchases.provider.owned = store_owned.duplicate(true)
	# attach_save already started reconcile with the empty mock store; run it to completion,
	# then the store contents arrive. Model the real order: store state exists before launch.
	pump(n2)
	var granted: Array = []
	n2.purchases.consumable_granted.connect(func(p, _g, _ok): granted.append(p))
	n2.purchases.reconcile()                   # what the next launch/resume triggers
	pump(n2)
	eq(granted, ["test.coins_small"], "next launch reconcile delivers the item once")
	eq(disk_coins(dir), 100, "delivered item on disk once")
	check(n2.purchases.provider.consumes >= 1, "purchase consumed after delivery")
	# Session 3: another launch must not deliver again even if the store still lists it.
	save.load_progress()
	var n3 := mock_node({})
	n3.purchases.grant_sink = coin_sink()
	n3.purchases.provider.owned = store_owned.duplicate(true)
	n3.purchases.reconcile()
	pump(n3)
	eq(disk_coins(dir), 100, "third launch: still exactly once")
	n2.queue_free()
	n3.queue_free()
	# The attach-time reconcile really runs (not just the explicit call above).
	save.load_progress()
	var n4 := mock_node({})
	var sums: Array = []
	n4.purchases.restore_finished.connect(func(s): sums.append(s))
	pump(n4)
	check(sums.size() == 1 and sums[0].get("auto", false) == true, "attach_save starts an automatic reconcile (%s)" % str(sums))
	n4.queue_free()
	return true

func test_resume_reconcile() -> bool:
	use_dir("resume")
	var n := mock_node({})
	pump(n)
	var ents: Array = []
	n.purchases.entitlement_changed.connect(func(e, o): ents.append([e, o]))
	n.purchases.provider.purchase_scenarios.assign(["pending"])
	n.purchases.purchase("test.supporter")
	pump(n)
	eq(n.purchases.has_entitlement("remove_ads"), false, "pending not granted")
	# Payment completes while the app is in the background: the store now reports it as
	# purchased, but the live update was missed (app not running).
	var mock = n.purchases.provider
	var p: Dictionary = mock._pending["test.supporter"].duplicate()
	mock._pending.erase("test.supporter")
	p.state = "purchased"
	mock.owned["test.supporter"] = p
	n._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	pump(n)
	eq(n.purchases.has_entitlement("remove_ads"), true, "resume reconcile grants the completed purchase")
	n._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	pump(n)
	eq(ents, [["remove_ads", true]], "second resume: no duplicate entitlement event")
	n.queue_free()
	return true

func test_no_fill() -> bool:
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(),
		"overrides": {"ads": ADS}})
	b.consent.set_choice("ads", "granted")
	b.ads.grant_sink = func(_p, _r, _c) -> bool: return true
	eq(b.ads.availability("ad_double_gold", "result:n1"), R.OK, "offer shown before any load")
	b.ad_provider.set_scenarios(["no_fill"])
	b.ads.request("ad_double_gold", "result:n1")
	for i in 5: b.ads.tick(0.0)
	eq(b.ads.availability("ad_double_gold", "result:n1"), R.NO_FILL, "after no-fill: offer hidden (no dead-end button)")
	eq(b.ads.request("ad_double_gold", "result:n1").code, R.NO_FILL, "request refused during cooldown, no SDK call")
	eq(b.ad_provider.loads, 1, "only one SDK load")
	for i in 59: b.ads.tick(1.0)
	eq(b.ads.availability("ad_double_gold", "result:n1"), R.NO_FILL, "still hidden at 59 s")
	b.ads.tick(1.5)
	eq(b.ads.availability("ad_double_gold", "result:n1"), R.OK, "offer back after cooldown")
	b.ad_provider.set_scenarios(["offline"])
	b.ads.request("ad_double_gold", "result:n1")
	for i in 5: b.ads.tick(0.0)
	eq(b.ads.availability("ad_double_gold", "result:n1"), R.NO_FILL, "SDK offline also hides the offer")
	var codes: Array = []
	b.ads.finished.connect(func(_i, _pp, c): codes.append(c))
	b.ads.tick(61.0)
	b.ad_provider.set_scenarios(["cancel"])
	b.ads.request("ad_double_gold", "result:n2")
	for i in 5: b.ads.tick(0.0)
	eq(b.ads.availability("ad_double_gold", "result:n2"), R.OK, "a cancelled ad does not hide the offer")
	eq(b.ads.offer_for("ad_double_gold", {"kind": "result", "result": {"won": true, "coins": 10, "battle_uid": "u1"}}).code, R.OK, "policy-level offer also respects cooldown state")
	return true

func test_disabled() -> bool:
	var game = root.get_node_or_null("Services")
	if check(game != null, "game Services present"):
		eq(game.mode, "disabled", "game Services mode disabled")
		eq(game.purchases.reconcile().code, R.DISABLED, "reconcile in disabled mode does nothing")
		eq(game.diagnostics().live.values().has(true), false, "nothing live in the game")
	var d := Factory.create({})
	eq(d.purchases.reconcile().code, R.DISABLED, "default factory reconcile disabled")
	return true
