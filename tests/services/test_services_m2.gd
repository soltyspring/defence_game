extends SceneTree
## 06-services M2 tests: crash/persistence, duplicate-grant edge cases, corrupt state,
## reward flow policy, bounded service telemetry, read-only diagnostics.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services_m2.gd
## Exit code 0 = all pass. Report: user://services_m2_test_report.json.
##
## Persistence here uses SaveDouble: a stand-in for 02's Save that keeps the game progress and
## the `services` section in ONE dictionary and saves it as ONE JSON string (like
## INTERFACES.md §3). "Crash" = drop memory and reload from the last saved string.
## This proves the services' ordering is safe IF 02 integrates per request S2. It does NOT
## prove anything about the real src/core/save.gd, which is not integrated yet.

const R := preload("res://src/services/service_result.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Store := preload("res://src/services/service_store.gd")
const ConsentS := preload("res://src/services/consent_service.gd")
const AdsS := preload("res://src/services/ads/rewarded_ad_service.gd")
const MockAds := preload("res://src/services/ads/mock_ad_provider.gd")
const PurchaseS := preload("res://src/services/billing/purchase_service.gd")
const MockBilling := preload("res://src/services/billing/mock_billing_provider.gd")
const MockVerifier := preload("res://src/services/billing/mock_receipt_verifier.gd")

class FakeClock extends "res://src/services/service_clock.gd":
	var t := 1_800_000_000
	var day := "2026-10-31"
	func now_unix() -> int:
		return t
	func local_day() -> String:
		return day

class FakeNet extends "res://src/services/network_probe.gd":
	var s := "unknown"
	func status() -> String:
		return s

## Stand-in for 02 Save: progress (incl. "services") saved atomically as one JSON string.
class SaveDouble:
	var progress := {}
	var disk := ""
	var fail_next := 0        # number of upcoming saves that fail (nothing written)
	var saves := 0
	func _init() -> void:
		progress = {"coins": 0, "services": {}}
		disk = JSON.stringify(progress)
	func save() -> bool:
		if fail_next > 0:
			fail_next -= 1
			return false
		disk = JSON.stringify(progress)
		saves += 1
		return true
	func crash_reload() -> void:
		var j := JSON.new()
		j.parse(disk)
		progress = j.data
		if not (progress.get("services") is Dictionary):
			progress["services"] = {}
	func disk_data() -> Dictionary:
		var j := JSON.new()
		j.parse(disk)
		return j.data
	func make_store():
		return load("res://src/services/service_store.gd").new(progress["services"], save)

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}}
var only: PackedStringArray = []

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	_group("crash_ads", test_crash_ads)
	_group("crash_iap", test_crash_iap)
	_group("duplicate_two_instances", test_two_instances)
	_group("corrupt_store", test_corrupt_store)
	_group("json_roundtrip_types", test_json_types)
	_group("reward_policy", test_reward_policy)
	_group("telemetry", test_telemetry)
	_group("diagnostics", test_diagnostics)
	report.passes = passes
	report.failures = Array(failures)
	report.pass = failures.is_empty()
	report.total_ms = Time.get_ticks_msec() - t0
	var f := FileAccess.open("user://services_m2_test_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services_m2] passes=%d failures=%d time_ms=%d" % [passes, failures.size(), report.total_ms])
	for g in report.groups:
		print("  %-26s %s" % [g, report.groups[g]])
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

func pump(svc, n: int = 30, dt: float = 0.0) -> void:
	for i in n:
		svc.tick(dt)

const ADS_CFG := {"enabled": true, "load_timeout_s": 5.0, "show_timeout_s": 30.0,
	"placements": {"ad_double_gold": {"daily_cap": 1000, "reward": {"effect": "gold_mult_2", "where": "results_win"}},
		"ad_base_repair": {"daily_cap": 3, "reward": {"effect": "player_base_heal_ratio_0_3", "where": "in_round_once_below_30pct"}}}}
const IAP_CFG := {"enabled": true, "purchase_timeout_s": 10.0, "verify_timeout_s": 5.0,
	"catalog": {"test.supporter": {"type": "non_consumable", "entitlement": "remove_ads"},
		"test.coins_small": {"type": "consumable", "grant": {"coins": 100}}}}

func bundle(store, clock = null, net = null, extra: Dictionary = {}) -> Dictionary:
	var ov := {"ads": ADS_CFG, "iap": IAP_CFG, "analytics": {"enabled": true}}
	ov.merge(extra, true)
	return Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": store,
		"clock": clock if clock != null else FakeClock.new(),
		"network": net if net != null else FakeNet.new(), "overrides": ov})

# ------------------------------------------------------------------ crash: ads

## Game-side sink that applies +100 coins per rewarded context into SaveDouble.progress.
class CoinSink:
	var sd
	var save_inside := false   # contract violation: sink saves on its own
	var applied := 0
	func _init(p_sd) -> void:
		sd = p_sd
	func ads(_pid: String, _reward: Dictionary, _ctx: String) -> bool:
		sd.progress["coins"] = int(sd.progress["coins"]) + 100
		applied += 1
		if save_inside:
			sd.save()
		return true
	func iap(_pid: String, grant: Dictionary, _key: String) -> bool:
		sd.progress["coins"] = int(sd.progress["coins"]) + int(grant.get("coins", 0))
		applied += 1
		if save_inside:
			sd.save()
		return true

func _disk_ledger_size(sd) -> int:
	var d: Dictionary = sd.disk_data()
	return d.get("services", {}).get("ads", {}).get("granted_contexts", {}).size()

func test_crash_ads() -> bool:
	var clock := FakeClock.new()
	# A. Save fails during grant (crash before commit): disk has neither reward nor ledger.
	var sd := SaveDouble.new()
	var b := bundle(sd.make_store(), clock)
	var sink := CoinSink.new(sd)
	b.ads.grant_sink = sink.ads
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	sd.fail_next = 1
	b.ads.request("ad_double_gold", "result:u1"); pump(b.ads)
	sd.crash_reload()
	eq(int(sd.progress.coins), 0, "A: crash before commit -> reward not on disk")
	eq(_disk_ledger_size(sd), 0, "A: crash before commit -> ledger not on disk")
	var b2 := bundle(sd.make_store(), clock)
	b2.ads.grant_sink = sink.ads
	eq(b2.ads.availability("ad_double_gold", "result:u1"), R.OK, "A: after crash the same context can be retried")
	b2.ads.request("ad_double_gold", "result:u1"); pump(b2.ads)
	sd.crash_reload()
	eq(int(sd.progress.coins), 100, "A: retry granted once on disk")
	eq(_disk_ledger_size(sd), 1, "A: ledger on disk after retry")

	# B. Sink saves inside the grant (contract violation). Ledger must already be in memory so
	#    the sink's own save carries it; then a crash cannot allow a second grant.
	var sd2 := SaveDouble.new()
	var b3 := bundle(sd2.make_store(), clock)
	var sink2 := CoinSink.new(sd2)
	sink2.save_inside = true
	b3.ads.grant_sink = sink2.ads
	b3.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	sd2.save()
	sd2.fail_next = 0
	# Make the service's own commit fail so only the sink's save reaches disk.
	b3.store.commit_fn = func() -> bool: return false
	b3.ads.request("ad_double_gold", "result:u2"); pump(b3.ads)
	sd2.crash_reload()
	eq(int(sd2.progress.coins), 100, "B: sink's own save persisted the reward")
	eq(_disk_ledger_size(sd2), 1, "B: ledger persisted together with sink's save (ledger-first)")
	var b4 := bundle(sd2.make_store(), clock)
	b4.ads.grant_sink = sink2.ads
	eq(b4.ads.availability("ad_double_gold", "result:u2"), R.ALREADY_GRANTED, "B: no second grant after crash")

	# C. Property: random save failures and crashes; every context ends rewarded exactly once.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6061
	var sd3 := SaveDouble.new()
	var sink3 := CoinSink.new(sd3)
	var contexts := 40
	var attempts := 0
	var crashes := 0
	var b5 := bundle(sd3.make_store(), clock)
	b5.ads.grant_sink = sink3.ads
	b5.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	for i in contexts:
		var ctx := "result:p%d" % i
		var guard := 0
		while guard < 20:
			guard += 1
			if b5.ads.availability("ad_double_gold", ctx) == R.ALREADY_GRANTED:
				break
			attempts += 1
			if rng.randf() < 0.3:
				sd3.fail_next = 1
			sink3.save_inside = rng.randf() < 0.2
			b5.ad_provider.set_scenarios([["complete", "cancel", "earned_twice", "late_earned", "earned_no_close"][rng.randi() % 5]])
			b5.ads.request("ad_double_gold", ctx)
			pump(b5.ads, 40, 1.0)
			if rng.randf() < 0.4:
				crashes += 1
				sd3.crash_reload()
				b5 = bundle(sd3.make_store(), clock)
				b5.ads.grant_sink = sink3.ads
		sd3.save()
	sd3.crash_reload()
	var led_n := _disk_ledger_size(sd3)
	eq(led_n, contexts, "C: every context rewarded on disk (attempts=%d crashes=%d)" % [attempts, crashes])
	eq(int(sd3.progress.coins), 100 * led_n, "C: coins on disk == 100 x ledger entries (no duplicate, no orphan)")
	check(crashes > 5, "C: property run exercised crashes (%d)" % crashes)
	report["crash_ads_property"] = {"contexts": contexts, "attempts": attempts, "crashes": crashes, "seed": 6061}
	return true

# ------------------------------------------------------------------ crash: iap

func test_crash_iap() -> bool:
	var clock := FakeClock.new()
	var billing_state := {}   # store-side ownership survives app crashes
	# A. Consumable: crash before commit -> restore regrants exactly once.
	var sd := SaveDouble.new()
	var sink := CoinSink.new(sd)
	var b := bundle(sd.make_store(), clock)
	b.purchases.grant_sink = sink.iap
	sd.fail_next = 10
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	sd.fail_next = 0
	billing_state = b.billing.owned.duplicate(true)
	sd.crash_reload()
	eq(int(sd.progress.coins), 0, "A: consumable not on disk after crash")
	var b2 := bundle(sd.make_store(), clock)
	b2.purchases.grant_sink = sink.iap
	# Mock consumed it already in-process; a real store only consumes after the consume call
	# succeeds, which the crash may have prevented. Model the store as still holding it.
	if billing_state.is_empty():
		billing_state = {"test.coins_small": _owned_like(b.billing, "test.coins_small")}
	b2.billing.owned = billing_state.duplicate(true)
	b2.purchases.restore(); pump(b2.purchases)
	sd.crash_reload()
	eq(int(sd.progress.coins), 100, "A: restore after crash regrants once")
	var b3 := bundle(sd.make_store(), clock)
	b3.purchases.grant_sink = sink.iap
	b3.billing.owned = billing_state.duplicate(true)  # consume answer lost again
	b3.purchases.restore(); pump(b3.purchases)
	sd.crash_reload()
	eq(int(sd.progress.coins), 100, "A: second restore after committed grant does not regrant")
	check(b3.billing.consumes >= 1, "A: committed-but-unconsumed purchase is consumed on restore")

	# B. Consumable sink saves inside grant (contract violation) + service commit fails.
	var sd2 := SaveDouble.new()
	var sink2 := CoinSink.new(sd2)
	sink2.save_inside = true
	var b4 := bundle(sd2.make_store(), clock)
	b4.purchases.grant_sink = sink2.iap
	b4.store.commit_fn = func() -> bool: return false
	b4.purchases.purchase("test.coins_small")
	# Capture store ownership BEFORE the mock consumes it in-process (M3 fix: the old capture
	# after tick() was always empty, which made the no-regrant check below vacuous).
	var owned_copy: Dictionary = b4.billing.owned.duplicate(true)
	check(owned_copy.has("test.coins_small"), "B: precondition: store reports purchase")
	pump(b4.purchases)
	sd2.crash_reload()
	eq(int(sd2.progress.coins), 100, "B: sink's own save persisted consumable")
	var b5 := bundle(sd2.make_store(), clock)
	b5.purchases.grant_sink = sink2.iap
	b5.billing.owned = owned_copy
	b5.purchases.restore(); pump(b5.purchases)
	sd2.crash_reload()
	eq(int(sd2.progress.coins), 100, "B: no regrant after crash (ledger-first)")

	# C. Non-consumable: crash before commit -> restore rebuilds entitlement once.
	var sd3 := SaveDouble.new()
	var b6 := bundle(sd3.make_store(), clock)
	sd3.fail_next = 10
	b6.purchases.purchase("test.supporter"); pump(b6.purchases)
	sd3.fail_next = 0
	var owned_nc: Dictionary = b6.billing.owned.duplicate(true)
	sd3.crash_reload()
	var b7 := bundle(sd3.make_store(), clock)
	eq(b7.purchases.has_entitlement("remove_ads"), false, "C: entitlement lost with crash before commit")
	b7.billing.owned = owned_nc
	var ents: Array = []
	b7.purchases.entitlement_changed.connect(func(e, o): ents.append([e, o]))
	b7.purchases.restore(); pump(b7.purchases)
	b7.purchases.restore(); pump(b7.purchases)
	eq(ents, [["remove_ads", true]], "C: restore rebuilds entitlement once")
	sd3.crash_reload()
	var b8 := bundle(sd3.make_store(), clock)
	eq(b8.purchases.has_entitlement("remove_ads"), true, "C: entitlement on disk after restore")
	return true

func _owned_like(billing, pid: String) -> Dictionary:
	# Rebuild the purchase the mock issued first (order MOCK.0001) for the crash model.
	var order := "MOCK.0001"
	return {"product_id": pid, "token": MockBilling.mock_token(pid, order), "order_id": order,
		"state": "purchased", "acknowledged": false, "environment": "mock", "signed_data": "", "signature": ""}

# ------------------------------------------------------------------ two instances

func test_two_instances() -> bool:
	# Two live service instances on one store (e.g. setup() called twice without teardown),
	# both pass availability for the same context before either is rewarded.
	var st := Store.new()
	var clock := FakeClock.new()
	var a := bundle(st, clock)
	var b := bundle(st, clock)
	var grants := [0]
	var sinkf := func(_p, _r, _c) -> bool:
		grants[0] += 1
		return true
	a.ads.grant_sink = sinkf
	b.ads.grant_sink = sinkf
	a.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	eq(a.ads.request("ad_double_gold", "result:same").code, R.OK, "instance A request")
	eq(b.ads.request("ad_double_gold", "result:same").code, R.OK, "instance B request (both passed availability)")
	var codes: Array = []
	a.ads.finished.connect(func(_i, _p, c): codes.append(c))
	b.ads.finished.connect(func(_i, _p, c): codes.append(c))
	pump(a.ads); pump(b.ads)
	eq(grants[0], 1, "only one of two concurrent sessions grants the same context")
	check(codes.has(R.OK), "one session ok")
	check(codes.has(R.ALREADY_GRANTED) or codes.has(R.GRANT_FAILED), "other session reports not granted")

	# Two purchase services on one store, same purchase update delivered to both.
	var st2 := Store.new()
	var p1 := bundle(st2, clock)
	var p2 := bundle(st2, clock)
	var n := [0]
	var csink := func(_p, _g, _k) -> bool:
		n[0] += 1
		return true
	p1.purchases.grant_sink = csink
	p2.purchases.grant_sink = csink
	var pur: Dictionary = p1.billing._make("test.coins_small", "purchased")
	p1.billing.purchase_updated.emit("ok", [pur.duplicate()])
	p2.billing.purchase_updated.emit("ok", [pur.duplicate()])
	pump(p1.purchases); pump(p2.purchases)
	eq(n[0], 1, "same consumable token granted once across two instances")
	return true

# ------------------------------------------------------------------ corrupt state

func test_corrupt_store() -> bool:
	var clock := FakeClock.new()
	var bad := {
		"consent": {"policy_version": 1, "choices": "garbage"},
		"ads": {"granted_contexts": {"result:x": "not-a-dict", "result:y": 7}, "daily": {"day": "2026-10-31", "counts": "garbage"}},
		"iap": {"ledger": {"k": "bad"}, "entitlements": {"remove_ads": "bad", "other": {"key": 5}}},
	}
	var st := Store.new(bad)
	var b := bundle(st, clock)
	var g := [0]
	b.ads.grant_sink = func(_p, _r, _c) -> bool:
		g[0] += 1
		return true
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	eq(b.consent.check(ConsentS.PURPOSE_ADS), R.OK, "consent recovers from corrupt choices")
	eq(b.ads.availability("ad_double_gold", "result:x"), R.ALREADY_GRANTED, "corrupt ledger entry still blocks its context")
	eq(b.ads.availability("ad_double_gold", "result:new"), R.OK, "corrupt daily counts do not crash")
	b.ads.request("ad_double_gold", "result:new"); pump(b.ads)
	eq(g[0], 1, "grant works with corrupt neighbours")
	clock.day = "2026-12-31"
	b.ads.request("ad_double_gold", "result:new2"); pump(b.ads)
	eq(g[0], 2, "pruning tolerates corrupt ledger entries")
	eq(b.purchases.has_entitlement("remove_ads"), false, "corrupt entitlement entry is not trusted")
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	eq(b.purchases.has_entitlement("remove_ads"), true, "purchase repairs corrupt entitlement")
	b.purchases.restore(); pump(b.purchases)
	check(true, "restore over corrupt iap section did not crash")
	return true

# ------------------------------------------------------------------ JSON round trip

func test_json_types() -> bool:
	# The real save is JSON: ints come back as floats. Services must behave identically.
	var clock := FakeClock.new()
	var sd := SaveDouble.new()
	var b := bundle(sd.make_store(), clock)
	b.ads.grant_sink = func(_p, _r, _c) -> bool: return true
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	for i in 3:
		b.ads.request("ad_base_repair", "rescue:j%d" % i); pump(b.ads)
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	sd.save()
	sd.crash_reload()
	check(sd.progress.services.ads.daily.counts.ad_base_repair is float, "JSON reload yields float counts (precondition)")
	var b2 := bundle(sd.make_store(), clock)
	eq(b2.consent.get_choice(ConsentS.PURPOSE_ADS), ConsentS.GRANTED, "consent survives JSON (policy_version float)")
	eq(b2.ads.availability("ad_base_repair", "rescue:j9"), R.CAP_REACHED, "cap survives JSON floats")
	eq(b2.purchases.has_entitlement("remove_ads"), true, "entitlement survives JSON")
	eq(b2.purchases.availability("test.supporter"), R.ALREADY_OWNED, "already owned after JSON reload")
	return true

# ------------------------------------------------------------------ reward policy
const Policy := preload("res://src/services/ads/reward_policy.gd")
const Diag := preload("res://src/services/service_diagnostics.gd")
const Schema := preload("res://src/services/analytics/event_schema.gd")

func _snap(hp: float, hp_max: float) -> Dictionary:
	return {"player_base": {"hp": hp, "hp_max": hp_max}}

func test_reward_policy() -> bool:
	var win: Dictionary = ADS_CFG.placements.ad_double_gold
	var rescue: Dictionary = ADS_CFG.placements.ad_base_repair
	var ok_result := {"kind": "result", "result": {"round_id": "r01", "won": true, "coins": 60, "battle_uid": "1800000000-7"}}
	var e := Policy.evaluate(win, ok_result)
	eq(e.eligible, true, "results_win: won with coins + uid eligible")
	eq(e.context_id, "result:1800000000-7", "results_win context id from battle_uid")
	var cases := [
		[{"kind": "result", "result": {"won": false, "coins": 60, "battle_uid": "u"}}, "not_won"],
		[{"kind": "result", "result": {"won": true, "coins": 0, "battle_uid": "u"}}, "no_coins_to_double"],
		[{"kind": "result", "result": {"won": true, "coins": 60}}, "missing_battle_uid"],
		[{"kind": "result", "result": {"won": true, "coins": 60, "battle_uid": "bad uid with spaces"}}, "missing_battle_uid"],
		[{"kind": "result", "result": {"won": "true", "coins": 60, "battle_uid": "u"}}, "not_won"],
		[{"kind": "result"}, "missing_result"],
		[{"kind": "battle", "battle_uid": "u", "snapshot": _snap(100, 1500)}, "wrong_situation"],
	]
	for c in cases:
		eq(Policy.evaluate(win, c[0]).reason, c[1], "results_win rejects: " + c[1])
		eq(Policy.evaluate(win, c[0]).eligible, false, "results_win not eligible: " + c[1])
	var bt := {"kind": "battle", "battle_uid": "1800000000-7", "snapshot": _snap(400, 1500), "ended": false}
	var r := Policy.evaluate(rescue, bt)
	eq(r.eligible, true, "rescue: base below 30% eligible")
	eq(r.context_id, "rescue:1800000000-7", "rescue context id")
	eq(r.constraints.max_stars, 2, "rescue reports 2-star cap constraint (01 rule)")
	var rcases := [
		[{"kind": "battle", "battle_uid": "u", "snapshot": _snap(450, 1500)}, "base_hp_not_low"],   # exactly 30%
		[{"kind": "battle", "battle_uid": "u", "snapshot": _snap(0, 1500)}, "base_destroyed"],
		[{"kind": "battle", "battle_uid": "u", "snapshot": _snap(100, 0)}, "bad_base_hp"],
		[{"kind": "battle", "battle_uid": "u", "snapshot": {"player_base": {"hp": "low", "hp_max": 1500}}}, "bad_base_hp"],
		[{"kind": "battle", "battle_uid": "u", "snapshot": {}}, "missing_snapshot"],
		[{"kind": "battle", "snapshot": _snap(100, 1500)}, "missing_battle_uid"],
		[{"kind": "battle", "battle_uid": "u", "snapshot": _snap(100, 1500), "ended": true}, "battle_ended"],
		[ok_result, "wrong_situation"],
	]
	for c in rcases:
		eq(Policy.evaluate(rescue, c[0]).reason, c[1], "rescue rejects: " + c[1])
	eq(Policy.evaluate({"reward": {"where": "interstitial_mid_round"}}, ok_result).reason, "unknown_rule", "unknown rule fails closed")
	eq(Policy.evaluate({}, ok_result).reason, "unknown_rule", "missing rule fails closed")

	# Service integration: offer_for / request_for apply policy then service gates.
	var st := Store.new()
	var b := bundle(st)
	var g: Array = []
	b.ads.grant_sink = func(p, rw, ctx) -> bool:
		g.append(ctx)
		return true
	eq(b.ads.offer_for("ad_base_repair", bt).code, R.CONSENT_REQUIRED, "policy ok but consent gate still applies")
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	var o: Dictionary = b.ads.offer_for("ad_base_repair", bt)
	eq(o.code, R.OK, "offer ok")
	eq(o.constraints.max_stars, 2, "offer carries constraints")
	var no: Dictionary = b.ads.offer_for("ad_base_repair", {"kind": "battle", "battle_uid": "u", "snapshot": _snap(1400, 1500)})
	eq(no.code, R.NOT_ELIGIBLE, "healthy base -> not_eligible")
	eq(no.reason, "base_hp_not_low", "reason passed through")
	eq(b.ad_provider.loads, 0, "no SDK load from offer checks")
	var rq: Dictionary = b.ads.request_for("ad_base_repair", bt)
	eq(rq.code, R.OK, "request_for starts")
	pump(b.ads)
	eq(g, ["rescue:1800000000-7"], "granted with policy context")
	eq(b.ads.offer_for("ad_base_repair", bt).code, R.ALREADY_GRANTED, "rescue once per battle")
	var bt2 := bt.duplicate(true)
	bt2.battle_uid = "1800000000-8"
	eq(b.ads.offer_for("ad_base_repair", bt2).code, R.OK, "next battle eligible again")
	eq(b.ads.request_for("ad_base_repair", {"kind": "battle", "snapshot": _snap(10, 1500)}).code, R.NOT_ELIGIBLE, "request_for refuses without uid")
	var d := Factory.create({})
	eq(d.ads.offer_for("ad_base_repair", bt).code, R.DISABLED, "default build: disabled before policy")
	check(Schema.RESULT_CODES.has(R.NOT_ELIGIBLE), "not_eligible accepted by analytics result enum")
	return true

# ------------------------------------------------------------------ telemetry

func test_telemetry() -> bool:
	# Default build: telemetry exists but everything is gated.
	var d := Factory.create({})
	eq(d.telemetry.offer_shown("ad_double_gold", "result:u"), R.DISABLED, "default telemetry gated (analytics disabled)")
	eq(d.analytics.queued(), 0, "default nothing queued")

	var b := bundle(Store.new(), null, null, {"analytics": {"enabled": true, "max_queue": 500, "batch_size": 500}})
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	b.ads.grant_sink = func(_p, _r, _c) -> bool: return true
	b.purchases.grant_sink = func(_p, _g, _k) -> bool: return true
	b.ads.request("ad_double_gold", "result:t1"); pump(b.ads)
	eq(b.analytics.queued(), 0, "service results not recorded without analytics consent")
	eq(b.telemetry.stats.gated, 1, "gated counted")
	b.consent.set_choice(ConsentS.PURPOSE_ANALYTICS, ConsentS.GRANTED)
	b.ad_provider.set_scenarios(["cancel"])
	b.ads.request("ad_double_gold", "result:t2"); pump(b.ads)
	b.billing.purchase_scenarios.assign(["cancel"])
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	b.purchases.restore(); pump(b.purchases)
	eq(b.telemetry.offer_shown("ad_double_gold", "result:t3"), R.OK, "offer emitted")
	eq(b.telemetry.offer_shown("ad_double_gold", "result:t3"), R.ALREADY_GRANTED, "same offer emitted once")
	b.analytics.flush()
	var names: Array = b.sink.received.map(func(e): return e.name)
	eq(names, ["ad_result", "purchase_result", "restore_result", "ad_offer"], "service events in order")
	eq(b.sink.received[0].params, {"placement_id": "ad_double_gold", "result": "cancelled"}, "ad_result params")
	eq(b.sink.received[1].params, {"product_id": "test.supporter", "result": "cancelled"}, "purchase_result params")
	eq(b.sink.received[2].params.result, "ok", "restore_result result")
	for e in b.sink.received:
		check(Schema.validate(e.name, e.params).ok, "emitted %s passes schema" % e.name)
		var s := JSON.stringify(e)
		check(not s.contains("result:t"), "no context ids in telemetry")
		check(not s.contains("mock-"), "no purchase tokens in telemetry")
	# Bounded per session.
	for i in 50:
		b.ad_provider.set_scenarios(["no_fill"])
		b.ads.request("ad_double_gold", "result:n%d" % i); pump(b.ads)
	b.analytics.flush()
	var ad_results: int = b.sink.received.filter(func(e): return e.name == "ad_result").size()
	eq(ad_results, Telemetry.MAX_PER_EVENT, "ad_result capped per session")
	check(b.telemetry.stats.suppressed_cap >= 20, "cap suppression counted")
	for i in 200:
		b.telemetry.offer_shown("ad_base_repair", "rescue:o%d" % i)
	b.analytics.flush()
	check(b.sink.received.size() <= Telemetry.MAX_TOTAL, "total telemetry per session bounded (%d)" % b.sink.received.size())
	# Telemetry never changes outcomes: identical runs with/without telemetry grant the same.
	var x := bundle(Store.new())
	var y := bundle(Store.new())
	y.analytics.enabled = false
	for bb in [x, y]:
		bb.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
		bb.consent.set_choice(ConsentS.PURPOSE_ANALYTICS, ConsentS.GRANTED)
		bb.ads.grant_sink = func(_p, _r, _c) -> bool: return true
		bb.ad_provider.set_scenarios(["complete", "cancel", "earned_twice"])
		for i in 3:
			bb.ads.request("ad_base_repair", "rescue:z%d" % i); pump(bb.ads)
	eq(x.ads._ledger().keys(), y.ads._ledger().keys(), "telemetry on/off: same grants")
	return true

const Telemetry := preload("res://src/services/analytics/service_telemetry.gd")

# ------------------------------------------------------------------ diagnostics

func test_diagnostics() -> bool:
	var d := Factory.create({})
	var s := Diag.snapshot(d)
	eq(s.mode, "disabled", "diag mode")
	eq(s.live, {"real_ads": false, "real_billing": false, "trusted_verifier": false, "remote_analytics": false}, "diag: nothing live by default")
	eq(s.adapters.verifier, "unavailable", "diag verifier kind")
	eq(s.store.persistent, false, "diag reports memory-only store")
	eq(Diag.snapshot({}).ready, false, "empty bundle")

	var sd := SaveDouble.new()
	var b := bundle(sd.make_store())
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	b.ads.grant_sink = func(_p, _r, _c) -> bool: return true
	b.ads.request("ad_base_repair", "rescue:d1"); pump(b.ads)
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	var tok: String = b.billing.owned["test.supporter"].token
	var m := Diag.snapshot(b)
	eq(m.mode, "mock", "mock diag")
	eq(m.live.real_billing, false, "mock is not real billing")
	eq(m.store.persistent, true, "persistent store reported")
	eq(m.ads.placements.ad_base_repair.granted_today, 1, "granted today")
	eq(m.ads.ledger_size, 1, "ledger size")
	eq(m.purchases.entitlements, ["remove_ads"], "entitlements listed")
	eq(m.purchases.ledger_by_state, {"granted": 1}, "ledger by state")
	var txt := JSON.stringify(m)
	check(not txt.contains(tok), "diag has no raw token")
	check(not txt.contains(PurchaseS._key(tok)), "diag has no ledger key")
	check(not txt.contains("rescue:d1"), "diag has no context ids")
	check(not txt.contains(b.analytics.session_id), "diag has no session id")
	# Detached: mutating the snapshot changes nothing.
	m.ads.placements.ad_base_repair.granted_today = 99
	m.purchases.entitlements.clear()
	m.ads.counters.timeouts = 99
	eq(b.ads._granted_today("ad_base_repair"), 1, "snapshot mutation does not affect cap")
	eq(b.purchases.has_entitlement("remove_ads"), true, "snapshot mutation does not affect entitlements")
	eq(b.ads.diagnostics.timeouts, 0, "snapshot mutation does not affect counters")
	# Read-only: taking snapshots does not commit or change store.
	var before := JSON.stringify(sd.progress)
	var saves0: int = sd.saves
	for i in 5:
		Diag.snapshot(b)
	eq(JSON.stringify(sd.progress), before, "snapshot does not mutate store")
	eq(sd.saves, saves0, "snapshot does not save")
	# Services node exposes it.
	var n = load("res://src/services/services.gd").new()
	n.setup({})
	eq(n.diagnostics().mode, "disabled", "Services.diagnostics()")
	n.free()
	return true
