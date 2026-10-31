extends SceneTree
## 06-services M10: multi-quantity consumable purchases. Mock billing only; crash cases use the
## game's AUTOLOAD Save redirected to an isolated user:// dir (player save hashed, unchanged).
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_m10.gd
## Exit 0 = pass, 1 = failure. Report: user://services_m10_test_report.json.
##
## Play model (developer.android.com/google/play/billing/integrate, "Handle multi-quantity
## purchases"): one purchase token carries a quantity; the app grants per quantity; one consume
## of the token makes the product purchasable again. So for quantity N the contract is:
##   grant = catalog grant × N, delivered ONCE; ONE ledger entry recording N; ONE consume.
## Quantities above the catalog's max_quantity (default 1) or invalid values fail closed:
## nothing granted, nothing recorded, nothing consumed (Play refunds after the ack window).

const R := preload("res://src/services/service_result.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Store := preload("res://src/services/service_store.gd")
const ServicesNode := preload("res://src/services/services.gd")
const PurchaseS := preload("res://src/services/billing/purchase_service.gd")
const Config := preload("res://src/services/service_config.gd")

const IAP := {"enabled": true, "purchase_timeout_s": 10.0, "verify_timeout_s": 5.0,
	"catalog": {"test.coins_small": {"type": "consumable", "grant": {"coins": 100, "label": "small"}, "max_quantity": 10},
		"test.coins_single": {"type": "consumable", "grant": {"coins": 100}},
		"test.supporter": {"type": "non_consumable", "entitlement": "remove_ads"}}}

var BASE := "user://svc_m10_test_%d" % OS.get_process_id()
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
		printerr("[test_services_m10] Save autoload missing; run with --path .")
		quit(1)
		return
	orig_path = save.path
	var h0 := _hash_user_save()
	_group("quantity_one", test_quantity_one)
	_group("quantity_three", test_quantity_three)
	_group("duplicate_callbacks", test_duplicates)
	_group("invalid_quantity", test_invalid)
	_group("crash_during_grant", test_crash)
	_group("sink_saves_then_fails", test_sink_saved_failed)
	_group("config_and_non_consumable", test_config_nc)
	save.path = orig_path
	save.load_progress()
	_group("hygiene", func() -> bool:
		check(_hash_user_save() == h0, "player's user://save.json(.bak) unchanged")
		return true)
	_wipe(BASE)
	DirAccess.remove_absolute(BASE)
	report.passes = passes
	report.failures = Array(failures)
	var f := FileAccess.open("user://services_m10_test_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services_m10] passes=%d failures=%d" % [passes, failures.size()])
	for g in report.groups:
		print("  %-26s %s" % [g, report.groups[g]])
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

## In-memory mock bundle + recorder.
class Rec:
	var grants: Array = []       # [product_id, grant]
	var finished: Array = []
	var coins := 0
	func sink(pid: String, g: Dictionary, _key: String) -> bool:
		grants.append([pid, g.duplicate()])
		coins += int(g.get("coins", 0))
		return true

func bundle() -> Array:
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": Store.new(),
		"overrides": {"iap": IAP}})
	var rec := Rec.new()
	b.purchases.grant_sink = rec.sink
	b.purchases.purchase_finished.connect(func(_p, c): rec.finished.append(c))
	return [b, rec]

func pump(ps, n: int = 40) -> void:
	for i in n:
		ps.tick(0.0)

func ledger_entries(ps) -> Array:
	return ps._ledger().values()

# ------------------------------------------------------------------ cases

func test_quantity_one() -> bool:
	var a := bundle(); var b: Dictionary = a[0]; var rec: Rec = a[1]
	b.billing.purchase_quantity = 1
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.finished, [R.OK], "q=1 ok")
	eq(rec.coins, 100, "q=1 grants 100")
	eq(rec.grants.size(), 1, "q=1 one grant call")
	eq(rec.grants[0][1].get("quantity"), 1, "grant carries quantity 1")
	eq(rec.grants[0][1].get("label"), "small", "non-numeric grant fields copied, not scaled")
	eq(b.billing.consumes, 1, "q=1 one consume")
	var l := ledger_entries(b.purchases)
	eq(l.size(), 1, "one ledger entry")
	eq(int(l[0].get("quantity", -1)), 1, "ledger records quantity 1")
	# Missing quantity field (single-quantity purchase from an older plugin) behaves like 1.
	var a2 := bundle(); var b2: Dictionary = a2[0]; var rec2: Rec = a2[1]
	var p: Dictionary = b2.billing._make("test.coins_small", "purchased")
	p.erase("quantity")
	b2.billing.purchase_updated.emit("ok", [p])
	pump(b2.purchases)
	eq(rec2.coins, 100, "missing quantity = 1")
	return true

func test_quantity_three() -> bool:
	var a := bundle(); var b: Dictionary = a[0]; var rec: Rec = a[1]
	var signals: Array = []
	b.purchases.consumable_granted.connect(func(pid, g, persisted): signals.append([pid, g.coins, g.quantity, persisted]))
	b.billing.purchase_quantity = 3
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.finished, [R.OK], "q=3 ok")
	eq(rec.coins, 300, "q=3 grants exactly 3 x 100")
	eq(rec.grants.size(), 1, "q=3 delivered in ONE grant call (not 3, not 0)")
	eq(signals, [["test.coins_small", 300, 3, true]], "consumable_granted once with scaled grant")
	eq(b.billing.consumes, 1, "q=3 ONE consume (Play consumes the whole token)")
	var l := ledger_entries(b.purchases)
	eq(l.size(), 1, "q=3 one ledger entry")
	eq(int(l[0].get("quantity", -1)), 3, "ledger records quantity 3")
	eq(b.purchases.availability("test.coins_small"), R.OK, "purchasable again after consume")
	# A second, separate q=3 purchase is a new token: another 300.
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.coins, 600, "second q=3 purchase grants another 300")
	eq(b.billing.consumes, 2, "two consumes for two tokens")
	# Float quantity from a JSON-based plugin (3.0) is accepted as 3.
	var a2 := bundle(); var b2: Dictionary = a2[0]; var rec2: Rec = a2[1]
	b2.billing.purchase_quantity = 3.0
	b2.purchases.purchase("test.coins_small"); pump(b2.purchases)
	eq(rec2.coins, 300, "quantity 3.0 accepted as 3")
	return true

func test_duplicates() -> bool:
	var a := bundle(); var b: Dictionary = a[0]; var rec: Rec = a[1]
	b.billing.purchase_quantity = 3
	b.billing.purchase_scenarios.assign(["duplicate"])
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.coins, 300, "duplicate update q=3: 300 once")
	eq(rec.grants.size(), 1, "duplicate update: one grant call")
	eq(b.billing.consumes, 1, "duplicate update: one consume")
	eq(rec.finished.size(), 1, "duplicate update: one finished")
	# Same token re-delivered later with a different quantity (corrupt or tampered update).
	var p: Dictionary = b.billing._make("test.coins_small", "purchased")
	p.quantity = 3
	b.billing.purchase_updated.emit("ok", [p.duplicate()]); pump(b.purchases)
	var before := rec.coins
	var p5 := p.duplicate()
	p5.quantity = 5
	b.billing.owned["test.coins_small"] = p5
	b.billing.purchase_updated.emit("ok", [p5.duplicate()]); pump(b.purchases)
	eq(rec.coins, before, "same token with quantity 5 later: no extra grant")
	check(int(b.purchases.diagnostics.quantity_mismatch) >= 1, "quantity mismatch counted")
	# Restore while the q=3 purchase is still owned (consume answer lost): consume, never regrant.
	var a2 := bundle(); var b2: Dictionary = a2[0]; var rec2: Rec = a2[1]
	b2.billing.purchase_quantity = 3
	b2.purchases.purchase("test.coins_small")
	var owned: Dictionary = b2.billing.owned.duplicate(true)
	pump(b2.purchases)
	b2.billing.owned = owned
	var c0: int = b2.billing.consumes
	b2.purchases.restore(); pump(b2.purchases)
	b2.purchases.reconcile(); pump(b2.purchases)
	eq(rec2.coins, 300, "restore + reconcile of consumed-but-still-listed q=3: still 300")
	check(b2.billing.consumes > c0, "still-listed purchase consumed again")
	return true

func test_invalid() -> bool:
	for v in [0, -2, 2.5, "3", null, 11]:
		var a := bundle(); var b: Dictionary = a[0]; var rec: Rec = a[1]
		b.billing.purchase_quantity = v
		b.purchases.purchase("test.coins_small"); pump(b.purchases)
		var tag := "quantity %s" % str(v)
		eq(rec.coins, 0, tag + ": nothing granted")
		eq(b.billing.consumes, 0, tag + ": not consumed (Play refunds)")
		eq(ledger_entries(b.purchases).size(), 0, tag + ": no ledger entry")
		eq(rec.finished, [R.GRANT_FAILED], tag + ": grant_failed")
		check(int(b.purchases.diagnostics.invalid_quantity) >= 1, tag + ": counted")
	# Product without max_quantity (default 1) rejects q=2.
	var a2 := bundle(); var b2: Dictionary = a2[0]; var rec2: Rec = a2[1]
	b2.billing.purchase_quantity = 2
	b2.purchases.purchase("test.coins_single"); pump(b2.purchases)
	eq(rec2.coins, 0, "default max_quantity 1: q=2 refused")
	eq(b2.billing.consumes, 0, "default max_quantity 1: not consumed")
	# Exactly at the limit is accepted.
	var a3 := bundle(); var b3: Dictionary = a3[0]; var rec3: Rec = a3[1]
	b3.billing.purchase_quantity = 10
	b3.purchases.purchase("test.coins_small"); pump(b3.purchases)
	eq(rec3.coins, 1000, "q = max_quantity (10) accepted")
	return true

## Mock-mode Services node on the autoload Save (separate from the game's disabled node).
func mock_node() -> Node:
	var n = ServicesNode.new()
	n.name = "ServicesM10"
	root.add_child(n)
	n.attach_save(save, root.get_node_or_null("Events"), {"mode": "mock", "allow_mock": true, "debug_build": true,
		"overrides": {"iap": IAP}})
	n.purchases.grant_sink = func(_p, g, _k) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + int(g.get("coins", 0))
		return true
	return n

func pump_node(n: Node, frames: int = 40) -> void:
	for i in frames:
		n._process(0.0)

func test_crash() -> bool:
	var dir := use_dir("crash")
	save.save_progress()
	var n1 := mock_node()
	pump_node(n1)
	n1.purchases.provider.purchase_quantity = 3
	DirAccess.make_dir_absolute(dir + "/save.json.tmp")   # real save.gd write fails mid-grant
	n1.purchases.purchase("test.coins_small")
	var owned: Dictionary = n1.purchases.provider.owned.duplicate(true)
	check(owned.has("test.coins_small") and int(owned["test.coins_small"].quantity) == 3, "precondition: store reports q=3 purchase")
	pump_node(n1)
	DirAccess.remove_absolute(dir + "/save.json.tmp")
	eq(disk_coins(dir), 0, "crash before commit: nothing on disk")
	n1.queue_free()
	# Next launch: memory gone, store still lists the purchase (consume never confirmed).
	save.load_progress()
	var n2 := mock_node()
	n2.purchases.provider.owned = owned.duplicate(true)
	pump_node(n2)                              # finish attach-time reconcile (empty mock state)
	n2.purchases.reconcile(); pump_node(n2)
	eq(disk_coins(dir), 300, "next launch: 3 x 100 delivered once")
	var l: Array = n2.purchases._ledger().values()
	eq(l.size(), 1, "one ledger entry on reload")
	eq(int(l[0].get("quantity", -1)), 3, "ledger quantity 3 persisted")
	check(n2.purchases.provider.consumes >= 1, "consumed after delivery")
	n2.queue_free()
	# Third launch, store still lists it: no regrant.
	save.load_progress()
	var n3 := mock_node()
	n3.purchases.provider.owned = owned.duplicate(true)
	n3.purchases.reconcile(); pump_node(n3)
	eq(disk_coins(dir), 300, "third launch: still exactly 300")
	n3.queue_free()
	return true

func test_sink_saved_failed() -> bool:
	var dir := use_dir("sinkfail")
	var n := mock_node()
	pump_node(n)
	var kinds: Array = []
	n.purchases.contract_violation.connect(func(k): kinds.append(k))
	n.purchases.grant_sink = func(_p, g, _k) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + int(g.get("coins", 0))
		save.save_progress()   # contract violation: sink saves, then reports failure
		return false
	n.purchases.provider.purchase_quantity = 3
	n.purchases.purchase("test.coins_small")
	var owned: Dictionary = n.purchases.provider.owned.duplicate(true)
	pump_node(n)
	check(kinds.has("iap_sink_saved_then_failed"), "violation reported (%s)" % str(kinds))
	eq(n.purchases.provider.consumes, 0, "grant_unknown q=3 never consumed")
	var e: Array = n.purchases._ledger().values()
	eq([str(e[0].state), int(e[0].quantity)], ["grant_unknown", 3], "ledger grant_unknown with quantity 3")
	n.queue_free()
	save.load_progress()
	var n2 := mock_node()
	n2.purchases.provider.owned = owned.duplicate(true)
	n2.purchases.reconcile(); pump_node(n2)
	eq(disk_coins(dir), 300, "reload: only the sink's own 300, never regranted")
	eq(n2.purchases.provider.consumes, 0, "still not consumed after reload")
	n2.queue_free()
	return true

func test_config_nc() -> bool:
	var meta := {"iap_catalog": {"enabled": true, "products": [
		{"id": "p.coins", "type": "consumable", "grant": {"coins": 50}, "max_quantity": 5},
		{"id": "p.coins_default", "type": "consumable", "grant": {"coins": 50}},
		{"id": "p.bad", "type": "consumable", "grant": {"coins": 50}, "max_quantity": -3}]}}
	var cfg := Config.from_meta(meta)
	eq(cfg.iap.catalog["p.coins"].max_quantity, 5, "data max_quantity mapped")
	eq(cfg.iap.catalog["p.coins_default"].max_quantity, 1, "default max_quantity 1")
	eq(cfg.iap.catalog["p.bad"].max_quantity, 1, "invalid max_quantity clamped to 1")
	eq(PurchaseS.scaled_grant({"coins": 50, "gems": 1.5, "tag": "x"}, 4), {"coins": 200, "gems": 6.0, "tag": "x", "quantity": 4}, "scaled_grant")
	# Non-consumable: quantity does not multiply an entitlement; granted once.
	var a := bundle(); var b: Dictionary = a[0]
	var ents: Array = []
	b.purchases.entitlement_changed.connect(func(e, o): ents.append([e, o]))
	b.billing.purchase_quantity = 2
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	eq(ents, [["remove_ads", true]], "non-consumable with quantity 2: one entitlement")
	eq(b.billing.acks, 1, "non-consumable acknowledged once")
	# Real 01 data still has no products: nothing enabled.
	eq(Config.from_meta(Config.load_meta()).iap.enabled, false, "data/meta.json iap still disabled")
	return true
