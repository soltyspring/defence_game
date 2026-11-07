extends SceneTree
## 06-services contract + state-machine tests (headless, deterministic, no network, no SDK).
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/services/test_services.gd
## Exit code 0 = all pass. Writes user://services_test_report.json.
## These tests exercise DISABLED and MOCK adapters only. They prove the state machines and
## gates; they do NOT prove that any real ad network, store or verification server works.

const R := preload("res://src/services/service_result.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Config := preload("res://src/services/service_config.gd")
const Store := preload("res://src/services/service_store.gd")
const ConsentS := preload("res://src/services/consent_service.gd")
const AdsS := preload("res://src/services/ads/rewarded_ad_service.gd")
const MockAds := preload("res://src/services/ads/mock_ad_provider.gd")
const PurchaseS := preload("res://src/services/billing/purchase_service.gd")
const MockBilling := preload("res://src/services/billing/mock_billing_provider.gd")
const MockVerifier := preload("res://src/services/billing/mock_receipt_verifier.gd")
const UnavailableVerifier := preload("res://src/services/billing/unavailable_receipt_verifier.gd")
const Schema := preload("res://src/services/analytics/event_schema.gd")
const ServicesNode := preload("res://src/services/services.gd")

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

var failures: PackedStringArray = []
var passes := 0
var current := ""
var report := {"groups": {}}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	_group("factory_config", test_factory_config)
	_group("consent", test_consent)
	_group("ads_happy_and_once_only", test_ads_once_only)
	_group("ads_failures_timeouts", test_ads_failures)
	_group("ads_gates_caps_restart", test_ads_gates)
	_group("ads_grant_persistence", test_ads_grant_persistence)
	_group("purchase_flows", test_purchase_flows)
	_group("purchase_verification", test_purchase_verification)
	_group("purchase_restore", test_purchase_restore)
	_group("purchase_consumable", test_purchase_consumable)
	_group("analytics", test_analytics)
	_group("analytics_doc_sync", test_analytics_doc_sync)
	_group("static_guards", test_static_guards)
	_group("services_node", test_services_node)
	report.passes = passes
	report.failures = Array(failures)
	report.pass = failures.is_empty()
	report.total_ms = Time.get_ticks_msec() - t0
	var f := FileAccess.open("user://services_test_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[test_services] passes=%d failures=%d time_ms=%d" % [passes, failures.size(), report.total_ms])
	for g in report.groups:
		print("  %-28s %s" % [g, report.groups[g]])
	quit(0 if failures.is_empty() else 1)

func _group(name: String, fn: Callable) -> void:
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

# ---------------------------------------------------------------- helpers

const ADS_CFG := {"enabled": true, "load_timeout_s": 5.0, "show_timeout_s": 30.0, "no_fill_cooldown_s": 0.0,
	"placements": {"ad_double_gold": {"daily_cap": 2, "reward": {"effect": "gold_mult_2"}},
		"ad_base_repair": {"daily_cap": 3, "reward": {"effect": "player_base_heal_ratio_0_3"}}}}

const IAP_CFG := {"enabled": true, "purchase_timeout_s": 10.0, "verify_timeout_s": 5.0,
	"catalog": {"test.supporter": {"type": "non_consumable", "entitlement": "remove_ads"},
		"test.coins_small": {"type": "consumable", "grant": {"coins": 100}}}}

func mock_bundle(store = null, clock = null, net = null, overrides: Dictionary = {}) -> Dictionary:
	var ov := {"ads": ADS_CFG, "iap": IAP_CFG, "analytics": {"enabled": true, "max_queue": 5, "batch_size": 3}}
	ov.merge(overrides, true)
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true,
		"store": store if store != null else Store.new(),
		"clock": clock if clock != null else FakeClock.new(),
		"network": net if net != null else FakeNet.new(),
		"overrides": ov})
	return b

func pump(svc, n: int = 30, dt: float = 0.0) -> void:
	for i in n:
		svc.tick(dt)

class AdRec:
	var grants: Array = []
	var finished: Array = []
	var ok_sink := true
	func sink(pid: String, reward: Dictionary, ctx: String) -> bool:
		if ok_sink:
			grants.append([pid, reward, ctx])
		return ok_sink
	func on_finished(rid: int, pid: String, code: String) -> void:
		finished.append([rid, pid, code])

func ads_setup(b: Dictionary) -> AdRec:
	var rec := AdRec.new()
	b.ads.grant_sink = rec.sink
	b.ads.finished.connect(rec.on_finished)
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	return rec

# ---------------------------------------------------------------- factory/config

func test_factory_config() -> bool:
	var d := Factory.create({})
	eq(d.mode, "disabled", "default mode disabled")
	eq(d.ads.availability("ad_double_gold", "x"), R.DISABLED, "default ads disabled")
	eq(d.purchases.purchase("test.supporter").code, R.DISABLED, "default purchase disabled")
	eq(d.purchases.restore().code, R.DISABLED, "default restore disabled")
	eq(d.analytics.track("round_start", {"round_id": "r01", "attempt": 1}), R.DISABLED, "default analytics disabled")
	eq(d.verifier.kind(), "unavailable", "default verifier never approves")
	eq(d.ad_provider.kind(), "disabled", "default ad adapter disabled")
	eq(d.billing.kind(), "disabled", "default billing adapter disabled")
	check(d.warnings.has("store_memory_only: service state not persisted until 02 integrates Save"), "memory store warned")

	var rel := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": false, "overrides": {"ads": ADS_CFG}})
	eq(rel.mode, "disabled", "mock refused in release build")
	eq(rel.ads.availability("ad_double_gold", "x"), R.DISABLED, "release build ads stay disabled")
	var noopt := Factory.create({"mode": "mock", "debug_build": true})
	eq(noopt.mode, "disabled", "mock refused without allow_mock")
	var prod := Factory.create({"mode": "production", "overrides": {"ads": ADS_CFG, "iap": IAP_CFG}})
	eq(prod.mode, "disabled", "production falls back to disabled")
	check(str(prod.warnings).contains("production_unavailable"), "production fallback warned")
	eq(prod.purchases.availability("test.supporter"), R.DISABLED, "production overrides ignored")

	# Real 01 data: monetization is undecided, so even mock mode without overrides stays disabled.
	var meta := Config.load_meta()
	check(not meta.is_empty(), "data/meta.json readable")
	var cfg := Config.from_meta(meta)
	eq(cfg.ads.enabled, false, "meta rewarded_ads disabled (D9)")
	eq(cfg.iap.enabled, false, "meta iap disabled (D9)")
	eq(cfg.iap.catalog.size(), 0, "no approved products")
	var m := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true})
	eq(m.mode, "mock", "mock mode accepted in debug with opt-in")
	eq(m.ads.availability("ad_double_gold", "x"), R.DISABLED, "mock mode follows 01 disabled flag")
	eq(m.purchases.availability("anything"), R.DISABLED, "mock mode follows 01 empty catalog")

	var sample := {"retention_hooks": {"rewarded_ads": {"enabled": true, "placements": [
		{"id": "ad_x", "where": "results_win", "effect": "gold_mult_2", "daily_cap": 5}, {"bad": 1}]}},
		"iap_catalog": {"enabled": true, "products": [{"id": "p.one", "type": "non_consumable", "entitlement": "e"},
			{"id": "p.sub", "type": "subscription"}]}}
	var sc := Config.from_meta(sample)
	eq(sc.ads.placements.size(), 1, "invalid placement skipped")
	eq(sc.ads.placements.ad_x.daily_cap, 5, "daily cap mapped")
	eq(sc.iap.catalog.size(), 1, "subscriptions skipped")
	eq(Config.from_meta({"iap_catalog": {"enabled": true, "products": []}}).iap.enabled, false, "enabled with empty catalog -> disabled")
	return true

# ---------------------------------------------------------------- consent

func test_consent() -> bool:
	var st := Store.new()
	var c := ConsentS.new(st, 1)
	eq(c.check(ConsentS.PURPOSE_ADS), R.CONSENT_REQUIRED, "unknown blocks ads")
	eq(c.check(ConsentS.PURPOSE_ANALYTICS), R.CONSENT_REQUIRED, "unknown blocks analytics")
	c.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	eq(c.check(ConsentS.PURPOSE_ADS), R.OK, "granted ads allowed")
	c.set_choice(ConsentS.PURPOSE_ADS_PERSONALIZED, ConsentS.GRANTED)
	eq(c.personalized_ads_allowed(), false, "personalised blocked while audience unknown")
	c.audience = ConsentS.AUDIENCE_GENERAL
	eq(c.personalized_ads_allowed(), true, "personalised allowed for general audience + consent")
	c.audience = ConsentS.AUDIENCE_CHILD
	eq(c.check(ConsentS.PURPOSE_ADS), R.CONSENT_REQUIRED, "child audience blocks ads by default")
	eq(c.personalized_ads_allowed(), false, "child never personalised")
	check(not c.set_choice("location", ConsentS.GRANTED), "unknown purpose rejected")
	check(not c.set_choice(ConsentS.PURPOSE_ADS, "yes"), "invalid value rejected")
	var c_same := ConsentS.new(st, 1)
	eq(c_same.get_choice(ConsentS.PURPOSE_ADS), ConsentS.GRANTED, "choice persists in store")
	var c2 := ConsentS.new(st, 2)
	eq(c2.get_choice(ConsentS.PURPOSE_ADS), ConsentS.UNKNOWN, "new policy version resets choices")
	c2.set_choice(ConsentS.PURPOSE_ANALYTICS, ConsentS.GRANTED)
	c2.withdraw_all()
	eq(c2.check(ConsentS.PURPOSE_ANALYTICS), R.CONSENT_REQUIRED, "withdraw_all blocks")
	eq(c2.apply_external({"ads": "granted", "analytics": "bogus", "x": "granted"}), 1, "external result: only valid keys applied")
	return true

# ---------------------------------------------------------------- ads

func test_ads_once_only() -> bool:
	var b := mock_bundle()
	var rec := ads_setup(b)
	var r: Dictionary = b.ads.request("ad_double_gold", "result:r01:a1")
	eq(r.code, R.OK, "request accepted")
	eq(b.ads.state, AdsS.LOADING, "loading after request")
	eq(b.ad_provider.last_personalized, false, "non-personalised requested (audience unknown)")
	pump(b.ads)
	eq(rec.grants.size(), 1, "complete: exactly one grant")
	eq(rec.finished.size(), 1, "complete: one finished")
	eq(rec.finished[0][2], R.OK, "complete: ok")
	eq(rec.grants[0][1].effect, "gold_mult_2", "reward payload from config")
	eq(b.ads.state, AdsS.IDLE, "idle after finish")

	b.ad_provider.set_scenarios(["earned_twice"])
	b.ads.request("ad_double_gold", "result:r01:a2")
	pump(b.ads)
	eq(rec.grants.size(), 2, "earned_twice: still one grant for this request")
	eq(rec.finished.size(), 2, "earned_twice: one finished signal")
	eq(b.ads.diagnostics.duplicate_reward, 1, "duplicate reward counted")
	check(b.ads.diagnostics.late_or_stray >= 1, "duplicate close counted as stray")

	# Same context id again (e.g. double-tap / repeated callback path) -> already granted.
	eq(b.ads.request("ad_double_gold", "result:r01:a2").code, R.ALREADY_GRANTED, "context rewarded once only")
	eq(b.ad_provider.loads, 2, "no SDK load for already granted context")

	# Stray callbacks while idle are ignored.
	var stray0: int = b.ads.diagnostics.late_or_stray
	b.ad_provider.inject("reward_earned", ["ad_double_gold"])
	b.ad_provider.inject("closed", ["ad_double_gold"])
	pump(b.ads)
	eq(rec.grants.size(), 2, "stray earned while idle grants nothing")
	eq(b.ads.diagnostics.late_or_stray, stray0 + 2, "stray callbacks counted")
	return true

func test_ads_failures() -> bool:
	var b := mock_bundle()
	var rec := ads_setup(b)
	b.ad_provider.set_scenarios(["cancel", "no_fill", "offline", "show_fail", "load_hang", "show_hang", "earned_no_close", "late_earned"])
	b.ads.request("ad_base_repair", "c1"); pump(b.ads)
	eq(rec.finished[-1][2], R.CANCELLED, "cancel -> cancelled")
	b.ads.request("ad_base_repair", "c2"); pump(b.ads)
	eq(rec.finished[-1][2], R.NO_FILL, "no fill")
	b.ads.request("ad_base_repair", "c3"); pump(b.ads)
	eq(rec.finished[-1][2], R.OFFLINE, "sdk offline")
	b.ads.request("ad_base_repair", "c4"); pump(b.ads)
	eq(rec.finished[-1][2], R.ERROR, "show failed")
	eq(rec.grants.size(), 0, "no grants from failures")

	b.ads.request("ad_base_repair", "c5")
	pump(b.ads, 4, 1.0)
	eq(b.ads.state, AdsS.LOADING, "still loading before timeout")
	pump(b.ads, 2, 1.0)
	eq(rec.finished[-1][2], R.TIMEOUT, "load timeout")
	# Late load callback after timeout must not start a show.
	b.ad_provider.inject("load_finished", ["ad_base_repair", "ok"])
	pump(b.ads)
	eq(b.ads.state, AdsS.IDLE, "late load ignored")
	eq(b.ad_provider.shows, 2, "no show for late load")

	b.ads.request("ad_base_repair", "c6")
	pump(b.ads, 40, 1.0)
	eq(rec.finished[-1][2], R.TIMEOUT, "show hang -> timeout")
	eq(rec.grants.size(), 0, "show hang no reward")

	b.ads.request("ad_base_repair", "c7")
	pump(b.ads, 40, 1.0)
	eq(rec.finished[-1][2], R.OK, "earned then hang -> ok after timeout, reward kept")
	eq(rec.grants.size(), 1, "earned_no_close granted once")

	b.ads.request("ad_double_gold", "c8")
	pump(b.ads)
	eq(rec.finished[-1][2], R.CANCELLED, "reward after dismissal -> cancelled (dropped)")
	eq(rec.grants.size(), 1, "late reward not granted")
	eq(b.ads.diagnostics.timeouts, 3, "three timeouts counted")

	# Busy: second request while first active.
	b.ad_provider.set_scenarios(["load_hang"])
	b.ads.request("ad_double_gold", "c9")
	eq(b.ads.request("ad_base_repair", "c10").code, R.BUSY, "busy while active")
	pump(b.ads, 10, 1.0)
	return true

func test_ads_gates() -> bool:
	var clock := FakeClock.new()
	var net := FakeNet.new()
	var st := Store.new()
	var b := mock_bundle(st, clock, net)
	var rec := AdRec.new()
	b.ads.grant_sink = rec.sink
	b.ads.finished.connect(rec.on_finished)
	eq(b.ads.request("ad_double_gold", "g1").code, R.CONSENT_REQUIRED, "consent gate")
	eq(b.ad_provider.loads, 0, "no SDK call without consent")
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.DENIED)
	eq(b.ads.availability("ad_double_gold", "g1"), R.CONSENT_REQUIRED, "denied blocks")
	b.consent.set_choice(ConsentS.PURPOSE_ADS, ConsentS.GRANTED)
	net.s = "offline"
	eq(b.ads.request("ad_double_gold", "g1").code, R.OFFLINE, "known offline gate")
	eq(b.ad_provider.loads, 0, "no SDK call offline")
	net.s = "online"
	eq(b.ads.request("ad_nope", "g1").code, R.UNKNOWN_ID, "unknown placement")
	eq(b.ads.request("ad_double_gold", "").code, R.ERROR, "empty context rejected")
	b.ads.request("ad_double_gold", "g1"); pump(b.ads)
	b.ads.request("ad_double_gold", "g2"); pump(b.ads)
	eq(rec.grants.size(), 2, "two grants under cap")
	eq(b.ads.request("ad_double_gold", "g3").code, R.CAP_REACHED, "daily cap 2 reached")
	eq(b.ads.availability("ad_base_repair", "g3"), R.OK, "cap is per placement")
	clock.day = "2026-11-01"
	eq(b.ads.availability("ad_double_gold", "g3"), R.OK, "cap resets next local day")
	eq(b.ads.availability("ad_double_gold", "g1"), R.ALREADY_GRANTED, "ledger survives day change")

	# Restart: new service on same store keeps ledger + cap.
	clock.day = "2026-10-31"
	var b2 := mock_bundle(st, clock, net)
	eq(b2.ads.availability("ad_double_gold", "g1"), R.ALREADY_GRANTED, "ledger survives restart")
	eq(b2.ads.availability("ad_double_gold", "g9"), R.CAP_REACHED, "cap survives restart")
	# Ledger pruning after LEDGER_KEEP_DAYS.
	clock.day = "2026-11-20"
	var b3 := mock_bundle(st, clock, net)
	var rec3 := ads_setup(b3)
	var r20: Dictionary = b3.ads.request("ad_double_gold", "g20"); pump(b3.ads)
	eq(r20.code, R.OK, "request after 20 days accepted")
	eq(rec3.grants.size(), 1, "granted after 20 days")
	check(not st.section("ads").granted_contexts.has("g1"), "old ledger entries pruned")
	check(st.section("ads").granted_contexts.has("g20"), "new ledger entry kept")
	return true

func test_ads_grant_persistence() -> bool:
	# Grant sink refuses (e.g. battle already ended) -> grant_failed, nothing recorded, retry possible.
	var b := mock_bundle()
	var rec := ads_setup(b)
	rec.ok_sink = false
	b.ads.request("ad_base_repair", "p1"); pump(b.ads)
	eq(rec.finished[-1][2], R.GRANT_FAILED, "sink refusal -> grant_failed")
	eq(b.ads.availability("ad_base_repair", "p1"), R.OK, "refused grant not recorded in ledger")
	eq(b.ads.diagnostics.grant_failed, 1, "grant_failed counted")

	# Commit fails -> persisted=false but ledger still in memory, so no double grant this session.
	var commits_ok := [false]
	var st := Store.new({}, func() -> bool: return commits_ok[0])
	var b2 := mock_bundle(st)
	var rec2 := ads_setup(b2)
	var persisted: Array = []
	b2.ads.reward_granted.connect(func(_p, _r, _c, ok): persisted.append(ok))
	b2.ads.request("ad_base_repair", "p2"); pump(b2.ads)
	eq(persisted, [false], "reward_granted reports persisted=false on commit failure")
	eq(b2.ads.availability("ad_base_repair", "p2"), R.ALREADY_GRANTED, "in-memory ledger blocks repeat")
	check(st.failed_commits >= 1, "failed commit counted")
	commits_ok[0] = true
	b2.ads.request("ad_base_repair", "p3"); pump(b2.ads)
	eq(persisted, [false, true], "next grant persisted")
	eq(rec2.grants.size(), 2, "two distinct contexts granted")
	return true

# ---------------------------------------------------------------- purchases

class PRec:
	var finished: Array = []
	var ents: Array = []
	var restores: Array = []
	var consumables: Array = []
	var sink_ok := true
	func on_finished(pid: String, code: String) -> void:
		finished.append([pid, code])
	func on_ent(e: String, owned: bool) -> void:
		ents.append([e, owned])
	func on_restore(s: Dictionary) -> void:
		restores.append(s)
	func sink(pid: String, grant: Dictionary, key: String) -> bool:
		if sink_ok:
			consumables.append([pid, grant, key])
		return sink_ok

func p_setup(b: Dictionary) -> PRec:
	var rec := PRec.new()
	b.purchases.purchase_finished.connect(rec.on_finished)
	b.purchases.entitlement_changed.connect(rec.on_ent)
	b.purchases.restore_finished.connect(rec.on_restore)
	b.purchases.grant_sink = rec.sink
	return rec

func test_purchase_flows() -> bool:
	var st := Store.new()
	var b := mock_bundle(st)
	var rec := p_setup(b)
	var ps = b.purchases
	eq(ps.purchase("test.unknown").code, R.UNKNOWN_ID, "unknown product refused")
	b.billing.purchase_scenarios.assign(["cancel", "offline", "error", "item_unavailable", "success"])
	for expected in [R.CANCELLED, R.OFFLINE, R.ERROR, R.UNKNOWN_ID]:
		eq(ps.purchase("test.supporter").code, R.OK, "launch accepted")
		eq(ps.purchase("test.supporter").code, R.BUSY, "busy during flow")
		pump(ps)
		eq(rec.finished[-1][1], expected, "flow result " + expected)
	eq(ps.has_entitlement("remove_ads"), false, "no entitlement after failures")
	eq(b.billing.acks, 0, "nothing acknowledged after failures")
	ps.purchase("test.supporter"); pump(ps)
	eq(rec.finished[-1][1], R.OK, "success")
	eq(ps.has_entitlement("remove_ads"), true, "entitlement granted")
	eq(rec.ents, [["remove_ads", true]], "entitlement_changed once")
	eq(b.billing.acks, 1, "acknowledged once")
	var tok: String = b.billing.owned["test.supporter"].token
	check(not JSON.stringify(st.data).contains(tok), "raw purchase token not persisted")
	eq(ps.availability("test.supporter"), R.ALREADY_OWNED, "already owned gate")
	eq(b.billing.launches, 5, "no store launch when already owned")

	# Store says already owned (e.g. bought on another device) -> recommend restore.
	var b2 := mock_bundle()
	var rec2 := p_setup(b2)
	b2.billing.purchase_scenarios.assign(["already_owned"])
	b2.purchases.purchase("test.supporter"); pump(b2.purchases)
	eq(rec2.finished[-1][1], R.ALREADY_OWNED, "store already_owned surfaced")

	# Pending -> no grant -> clears later (unsolicited) -> granted once.
	var b3 := mock_bundle()
	var rec3 := p_setup(b3)
	b3.billing.purchase_scenarios.assign(["pending"])
	b3.purchases.purchase("test.supporter"); pump(b3.purchases)
	eq(rec3.finished[-1][1], R.PENDING, "pending surfaced")
	eq(b3.purchases.has_entitlement("remove_ads"), false, "pending not granted")
	eq(b3.billing.acks, 0, "pending not acknowledged")
	b3.billing.complete_pending("test.supporter"); pump(b3.purchases)
	eq(b3.purchases.has_entitlement("remove_ads"), true, "cleared pending granted via unsolicited update")
	eq(b3.billing.acks, 1, "cleared pending acknowledged")

	# Duplicate update -> single grant / single ack.
	var b4 := mock_bundle()
	var rec4 := p_setup(b4)
	b4.billing.purchase_scenarios.assign(["duplicate"])
	b4.purchases.purchase("test.supporter"); pump(b4.purchases)
	eq(rec4.ents.size(), 1, "duplicate update one entitlement event")
	eq(rec4.finished.size(), 1, "duplicate update one finished")
	eq(b4.billing.acks, 1, "duplicate update one ack")
	check(b4.purchases.diagnostics.duplicate_updates >= 1, "duplicate counted")

	# Store never answers -> timeout; late success afterwards still processed idempotently.
	var b5 := mock_bundle()
	var rec5 := p_setup(b5)
	b5.billing.purchase_scenarios.assign(["hang"])
	b5.purchases.purchase("test.supporter")
	pump(b5.purchases, 12, 1.0)
	eq(rec5.finished[-1][1], R.TIMEOUT, "purchase timeout")
	var late: Dictionary = b5.billing._make("test.supporter", "purchased")
	b5.billing.owned["test.supporter"] = late
	b5.billing.purchase_updated.emit("ok", [late.duplicate()])
	pump(b5.purchases)
	eq(b5.purchases.has_entitlement("remove_ads"), true, "late success after timeout granted")
	b5.billing.purchase_updated.emit("ok", [late.duplicate()])
	pump(b5.purchases)
	eq(rec5.ents.size(), 1, "late duplicate not regranted")

	# Disabled / offline gates.
	var net := FakeNet.new()
	net.s = "offline"
	var b6 := mock_bundle(null, null, net)
	eq(b6.purchases.purchase("test.supporter").code, R.OFFLINE, "known offline purchase gate")
	eq(b6.purchases.restore().code, R.OFFLINE, "known offline restore gate")
	eq(b6.billing.launches, 0, "no launch offline")
	return true

func test_purchase_verification() -> bool:
	# Forged token -> invalid, never granted or acknowledged.
	var b := mock_bundle()
	var rec := p_setup(b)
	b.billing.purchase_scenarios.assign(["tampered"])
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	eq(rec.finished[-1][1], R.INVALID_RECEIPT, "tampered -> invalid_receipt")
	eq(b.purchases.has_entitlement("remove_ads"), false, "invalid not granted")
	eq(b.billing.acks, 0, "invalid not acknowledged")

	# A production-environment purchase can never be approved by the mock verifier.
	var b2 := mock_bundle()
	var rec2 := p_setup(b2)
	b2.billing.purchase_scenarios.assign(["hang"])
	b2.purchases.purchase("test.supporter")
	var fake_real := {"product_id": "test.supporter", "token": "real-looking-token", "order_id": "GPA.1234",
		"state": "purchased", "acknowledged": false, "environment": "production", "signed_data": "{}", "signature": "x"}
	b2.billing.purchase_updated.emit("ok", [fake_real])
	pump(b2.purchases)
	eq(rec2.finished[-1][1], R.VERIFICATION_UNAVAILABLE, "production purchase not verifiable by mock")
	eq(b2.purchases.has_entitlement("remove_ads"), false, "production purchase not granted")
	eq(b2.billing.acks, 0, "production purchase not acknowledged")

	# Production-default verifier never approves anything, including valid-looking mock purchases.
	var st := Store.new()
	var billing := MockBilling.new()
	var unv := UnavailableVerifier.new()
	var ps := PurchaseS.new(billing, unv, st, FakeClock.new(), FakeNet.new(), IAP_CFG)
	var got: Array = []
	ps.purchase_finished.connect(func(_p, c): got.append(c))
	ps.purchase("test.supporter"); pump(ps)
	eq(got, [R.VERIFICATION_UNAVAILABLE], "unavailable verifier -> verification_unavailable")
	eq(ps.has_entitlement("remove_ads"), false, "unavailable verifier never grants")
	eq(billing.acks, 0, "unavailable verifier never acknowledges")
	check(not st.section("iap").get("ledger", {}).values().any(func(e): return e.state == "granted"), "nothing recorded as granted")

	# Verifier hang -> timeout -> unverified, then restore with working verifier grants.
	var st2 := Store.new()
	var b3 := mock_bundle(st2)
	var rec3 := p_setup(b3)
	b3.verifier.hang = true
	b3.purchases.purchase("test.supporter")
	pump(b3.purchases, 8, 1.0)
	eq(rec3.finished[-1][1], R.VERIFICATION_UNAVAILABLE, "verifier timeout -> unavailable")
	eq(b3.purchases.has_entitlement("remove_ads"), false, "verifier timeout no grant")
	b3.verifier.hang = false
	b3.purchases.restore(); pump(b3.purchases)
	eq(b3.purchases.has_entitlement("remove_ads"), true, "restore retries verification and grants")
	eq(rec3.restores[-1].restored, 1, "restore summary counts restored")

	# Verifier says revoked -> entitlement removed.
	b3.verifier.revoked_tokens[b3.billing.owned["test.supporter"].token] = true
	b3.purchases._ledger().clear()   # force re-verify path as after reinstall with stale cache
	b3.purchases.restore(); pump(b3.purchases)
	eq(b3.purchases.has_entitlement("remove_ads"), false, "revoked purchase removes entitlement")
	eq(rec3.ents[-1], ["remove_ads", false], "entitlement_changed false on revoke")
	return true

func test_purchase_restore() -> bool:
	var st := Store.new()
	var b := mock_bundle(st)
	p_setup(b)
	b.purchases.purchase("test.supporter"); pump(b.purchases)
	check(b.purchases.has_entitlement("remove_ads"), "bought")
	# Reinstall: fresh store, store still reports ownership.
	var b2 := mock_bundle(Store.new())
	var rec2 := p_setup(b2)
	b2.billing.owned = b.billing.owned.duplicate(true)
	eq(b2.purchases.has_entitlement("remove_ads"), false, "fresh install has no entitlement")
	eq(b2.purchases.restore().code, R.OK, "restore started")
	eq(b2.purchases.restore().code, R.BUSY, "restore busy")
	pump(b2.purchases)
	eq(b2.purchases.has_entitlement("remove_ads"), true, "restore grants owned non-consumable")
	eq(rec2.restores[-1].code, R.OK, "restore ok")
	eq(rec2.restores[-1].restored, 1, "restored count")
	# Repeat restore: idempotent.
	b2.purchases.restore(); pump(b2.purchases)
	eq(rec2.restores[-1].already, 1, "second restore: already owned")
	eq(rec2.ents.size(), 1, "second restore no new entitlement event")
	# Restore offline (store reports offline): keep cached entitlements.
	b2.billing.query_scenarios.assign(["offline"])
	b2.purchases.restore(); pump(b2.purchases)
	eq(rec2.restores[-1].code, R.OFFLINE, "restore offline surfaced")
	eq(b2.purchases.has_entitlement("remove_ads"), true, "offline restore never revokes")
	# Store query never answers -> timeout, keep entitlements.
	b2.billing.query_scenarios.assign(["ok"])
	b2.purchases.restore()
	b2.billing._queue.clear()   # drop the answer: simulate a hung store connection
	pump(b2.purchases, 8, 1.0)
	eq(rec2.restores[-1].code, R.TIMEOUT, "restore timeout")
	eq(b2.purchases.has_entitlement("remove_ads"), true, "timeout restore never revokes")
	# Refund: store no longer reports ownership -> successful query revokes.
	b2.billing.refund("test.supporter")
	b2.purchases.restore(); pump(b2.purchases)
	eq(b2.purchases.has_entitlement("remove_ads"), false, "refunded entitlement revoked on successful restore")
	eq(rec2.restores[-1].revoked, 1, "revoked count")

	# Acknowledge failure: entitlement kept, ack retried on restore.
	var b3 := mock_bundle()
	p_setup(b3)
	b3.billing.ack_fail = true
	b3.purchases.purchase("test.supporter"); pump(b3.purchases)
	check(b3.purchases.has_entitlement("remove_ads"), "granted despite ack failure")
	eq(b3.purchases.diagnostics.ack_failed, 1, "ack failure counted")
	b3.billing.ack_fail = false
	b3.purchases.restore(); pump(b3.purchases)
	eq(b3.billing.acks, 2, "ack retried on restore")
	var led: Dictionary = b3.purchases._ledger()
	check(led.values().all(func(e): return e.acknowledged == true), "ledger acknowledged after retry")

	# Invalid receipt owned in store is not restored.
	var b4 := mock_bundle()
	var rec4 := p_setup(b4)
	var forged: Dictionary = b4.billing._make("test.supporter", "purchased")
	forged.token = "mock-forged"
	b4.billing.owned["test.supporter"] = forged
	b4.purchases.restore(); pump(b4.purchases)
	eq(b4.purchases.has_entitlement("remove_ads"), false, "forged owned purchase not restored")
	eq(rec4.restores[-1].invalid, 1, "invalid counted in restore summary")
	return true

func test_purchase_consumable() -> bool:
	var st := Store.new()
	var b := mock_bundle(st)
	var rec := p_setup(b)
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.finished[-1][1], R.OK, "consumable ok")
	eq(rec.consumables.size(), 1, "consumable granted once")
	eq(rec.consumables[0][1].coins, 100, "consumable grant payload")
	eq(b.billing.consumes, 1, "consumed once")
	eq(b.purchases.availability("test.coins_small"), R.OK, "consumable can be bought again")
	b.purchases.restore(); pump(b.purchases)
	eq(rec.consumables.size(), 1, "restore after consume does not regrant")
	# Duplicate consumable update -> one grant.
	b.billing.purchase_scenarios.assign(["duplicate"])
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.consumables.size(), 2, "duplicate consumable update granted once")
	# Sink refuses -> grant_failed, not consumed, so the store can refund / retry.
	rec.sink_ok = false
	var c0: int = b.billing.consumes
	b.purchases.purchase("test.coins_small"); pump(b.purchases)
	eq(rec.finished[-1][1], R.GRANT_FAILED, "consumable sink refusal -> grant_failed")
	eq(b.billing.consumes, c0, "not consumed when not granted")
	rec.sink_ok = true
	b.purchases.restore(); pump(b.purchases)
	eq(rec.consumables.size(), 3, "unconsumed purchase granted on restore retry")
	eq(b.billing.consumes, c0 + 1, "consumed after successful retry")
	return true

# ---------------------------------------------------------------- analytics

func test_analytics() -> bool:
	var b := mock_bundle()
	var an = b.analytics
	var sink = b.sink
	eq(an.track("round_start", {"round_id": "r01", "attempt": 1}), R.CONSENT_REQUIRED, "analytics needs consent")
	eq(an.queued(), 0, "blocked event not queued")
	b.consent.set_choice(ConsentS.PURPOSE_ANALYTICS, ConsentS.GRANTED)
	eq(an.track("round_start", {"round_id": "r01", "attempt": 1}), R.OK, "valid event accepted")
	eq(an.track("round_end", {"round_id": "r01", "won": true, "stars": 3, "duration_s": 97.6, "kills": 5000}), R.OK, "round_end accepted")
	an.tick(12.7)
	eq(an.flush(), R.OK, "flush ok")
	eq(sink.received.size(), 2, "sink got 2")
	var e: Dictionary = sink.received[1]
	eq(e.params.duration_s, 90, "duration bucketed to 10s")
	eq(e.params.kills, 999, "kills clamped")
	eq(e.keys().size(), 6, "envelope has exactly v,name,params,session,seq,t_s")
	for k in ["v", "name", "params", "session", "seq", "t_s"]:
		check(e.has(k), "envelope key " + k)
	# Rejections
	eq(an.track("player_name", {"name": "kim"}), R.ERROR, "unknown event rejected")
	eq(an.track("round_start", {"round_id": "r01", "attempt": 1, "email": "a@b.c"}), R.ERROR, "unknown param rejected")
	eq(an.track("round_start", {"round_id": "r01"}), R.ERROR, "missing param rejected")
	eq(an.track("round_start", {"round_id": "hello world", "attempt": 1}), R.ERROR, "free text id rejected")
	eq(an.track("round_end", {"round_id": "r01", "won": "yes", "stars": 1, "duration_s": 1, "kills": 1}), R.ERROR, "bad type rejected")
	eq(an.track("round_end", {"round_id": "r01", "won": true, "stars": 9, "duration_s": 1, "kills": 1}), R.ERROR, "out of range non-clamped rejected")
	eq(an.track("error", {"area": "save", "code": "Checksum Mismatch!"}), R.ERROR, "error code pattern enforced")
	eq(an.stats.rejected_schema, 7, "rejections counted")
	# Overflow bounded (max_queue 5)
	for i in 8:
		an.track("ad_offer", {"placement_id": "ad_double_gold"})
	eq(an.queued(), 5, "queue bounded")
	eq(an.stats.dropped_overflow, 3, "overflow counted")
	# Send failure keeps the queue
	sink.fail = true
	eq(an.flush(), R.ERROR, "flush failure reported")
	eq(an.queued(), 5, "queue kept on failure")
	sink.fail = false
	an.flush()
	eq(an.queued(), 2, "batch of 3 sent")
	# Withdrawal purges
	b.consent.set_choice(ConsentS.PURPOSE_ANALYTICS, ConsentS.DENIED)
	eq(an.queued(), 0, "consent withdrawal purges queue")
	eq(an.track("ad_offer", {"placement_id": "ad_double_gold"}), R.CONSENT_REQUIRED, "blocked after withdrawal")
	# Session id is not persisted anywhere in the store.
	check(not JSON.stringify(b.store.data).contains(an.session_id), "session id not persisted")
	check(an.session_id.length() == 16, "session id 64-bit random hex")
	return true

func test_analytics_doc_sync() -> bool:
	var path := "res://docs/services/ANALYTICS_EVENTS.md"
	check(FileAccess.file_exists(path), "ANALYTICS_EVENTS.md exists")
	if not FileAccess.file_exists(path):
		return true
	var doc := FileAccess.get_file_as_string(path)
	check(doc.contains("Schema version: %d" % Schema.VERSION), "doc schema version matches")
	for ev in Schema.EVENTS:
		check(doc.contains("`%s`" % ev), "doc lists event " + ev)
		for p in Schema.EVENTS[ev]:
			check(doc.contains("`%s`" % p), "doc lists param %s.%s" % [ev, p])
	return true

func test_static_guards() -> bool:
	# Privacy/secret guards over 06-owned source: no device IDs, no ad unit IDs, no keys, no URLs.
	var forbidden := ["OS.get_unique_id", "get_unique_id(", "ca-app-pub-", "BEGIN PRIVATE KEY", "http://", "https://",
		"advertising_id", "OS.get_model_name"]
	var files := _list_gd("res://src/services")
	check(files.size() >= 15, "found service scripts (%d)" % files.size())
	for f in files:
		var txt := FileAccess.get_file_as_string(f)
		for bad in forbidden:
			check(not txt.contains(bad), "%s must not contain %s" % [f, bad])
	# The only verifier allowed to emit "ok" must check environment == "mock".
	var mv := FileAccess.get_file_as_string("res://src/services/billing/mock_receipt_verifier.gd")
	check(mv.contains("!= \"mock\""), "mock verifier gates on mock environment")
	var uv := FileAccess.get_file_as_string("res://src/services/billing/unavailable_receipt_verifier.gd")
	check(not uv.contains("Result.OK"), "unavailable verifier never returns OK")
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

func test_services_node() -> bool:
	var n = ServicesNode.new()
	root.add_child(n)
	check(n.is_node_ready(), "Services is initialized by the active scene tree")
	eq(n.mode, "disabled", "Services node defaults to disabled")
	eq(n.ads.availability("ad_double_gold", "x"), R.DISABLED, "node ads disabled")
	eq(n.purchases.has_entitlement("remove_ads"), false, "node no entitlements")
	n._process(0.016)
	n.queue_free()
	return true
