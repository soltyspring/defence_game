extends RefCounted
## Rewarded-ad state machine. Owner: 06-services. Spec: docs/services/SERVICES.md §3.
##
##   IDLE --request()--> LOADING --load ok--> SHOWING --closed--> IDLE (ok | cancelled | grant_failed)
##                         |  load fail/timeout -> IDLE      |  show_failed / show timeout -> IDLE
##
## Guarantees (covered by tests/services/test_services.gd):
##  - A reward is granted at most once per request AND at most once per context_id
##    (e.g. "rescue:<battle_uid>"), across duplicate SDK callbacks and app restarts (given a
##    persistent store).
##  - No reward without an SDK reward_earned callback inside the active session.
##  - Callbacks after the session finished (late, duplicate, stray) are counted and ignored.
##  - Gates run before any SDK call: enabled, adapter, placement, context, consent, offline,
##    daily cap, busy.
## The service never changes game state itself. It calls grant_sink(placement_id, reward,
## context_id) -> bool, provided by 02, which applies the reward in memory. Then it commits
## the store, which (after 02 integration) saves reward + ledger in one atomic write.

const Result := preload("res://src/services/service_result.gd")
const Consent := preload("res://src/services/consent_service.gd")
const Policy := preload("res://src/services/ads/reward_policy.gd")

const IDLE := "idle"
const LOADING := "loading"
const SHOWING := "showing"

const LEDGER_KEEP_DAYS := 7

signal state_changed(state: String)
## persisted=false means the in-memory grant happened but the save commit failed; both reward
## and ledger stay in memory and are written together by the next successful save.
signal reward_granted(placement_id: String, reward: Dictionary, context_id: String, persisted: bool)
signal finished(request_id: int, placement_id: String, code: String)
## A grant sink broke its contract.
## kind: ads_sink_saved | ads_sink_saved_then_failed | ads_repair_commit_failed
signal contract_violation(kind: String)

var provider
var consent
var store
var clock
var network
var grant_sink: Callable

var enabled := false
var placements := {}           # id -> {"daily_cap": int, "reward": Dictionary}
var load_timeout_s := 15.0
var show_timeout_s := 120.0

var state := IDLE
var _session := {}
var _next_request_id := 1
var diagnostics := {"duplicate_reward": 0, "late_or_stray": 0, "timeouts": 0, "grant_failed": 0, "contract_violation": 0}

func _init(p_provider, p_consent, p_store, p_clock, p_network, config: Dictionary = {}) -> void:
	provider = p_provider
	consent = p_consent
	store = p_store
	clock = p_clock
	network = p_network
	enabled = bool(config.get("enabled", false))
	placements = config.get("placements", {}).duplicate(true)
	load_timeout_s = float(config.get("load_timeout_s", load_timeout_s))
	show_timeout_s = float(config.get("show_timeout_s", show_timeout_s))
	provider.load_finished.connect(_on_load_finished)
	provider.show_started.connect(_on_show_started)
	provider.reward_earned.connect(_on_reward_earned)
	provider.show_failed.connect(_on_show_failed)
	provider.closed.connect(_on_closed)
	_sanitize()

## Cheap check for UI: should a "watch ad" button be offered? Does not call the SDK.
func availability(placement_id: String, context_id: String) -> String:
	if not enabled:
		return Result.DISABLED
	if provider == null or not provider.is_supported():
		return Result.UNSUPPORTED
	if not placements.has(placement_id):
		return Result.UNKNOWN_ID
	if not store.is_usable():
		return Result.ERROR   # stale store (save reloaded after binding)
	if context_id.is_empty():
		return Result.ERROR
	if _ledger().has(context_id):
		return Result.ALREADY_GRANTED
	if consent.check(Consent.PURPOSE_ADS) != Result.OK:
		return Result.CONSENT_REQUIRED
	if network.is_known_offline():
		return Result.OFFLINE
	if _granted_today(placement_id) >= int(placements[placement_id].get("daily_cap", 0)):
		return Result.CAP_REACHED
	if state != IDLE:
		return Result.BUSY
	return Result.OK

## Policy-aware check: is an offer allowed in this situation (reward_policy.gd) AND does the
## service allow it? Returns {"code", "context_id", "reason", "constraints"}.
## code "not_eligible" means the policy said no (reason explains); other codes come from availability().
func offer_for(placement_id: String, situation: Dictionary) -> Dictionary:
	if not enabled:
		return Result.make(Result.DISABLED, {"context_id": "", "reason": "", "constraints": {}})
	if not placements.has(placement_id):
		return Result.make(Result.UNKNOWN_ID, {"context_id": "", "reason": "", "constraints": {}})
	var ev := Policy.evaluate(placements[placement_id], situation)
	if not ev.eligible:
		return Result.make(Result.NOT_ELIGIBLE, {"context_id": "", "reason": ev.reason, "constraints": {}})
	var code := availability(placement_id, ev.context_id)
	return Result.make(code, {"context_id": ev.context_id, "reason": "", "constraints": ev.constraints})

## Start an ad for a situation. Same result shape as request() plus context_id/constraints.
func request_for(placement_id: String, situation: Dictionary) -> Dictionary:
	var o := offer_for(placement_id, situation)
	if o.code != Result.OK:
		o["request_id"] = 0
		return o
	var r := request(placement_id, o.context_id)
	r["context_id"] = o.context_id
	r["constraints"] = o.constraints
	return r

## Start load+show. Returns {"code", "request_id"}; final outcome arrives via `finished`.
func request(placement_id: String, context_id: String) -> Dictionary:
	var code := availability(placement_id, context_id)
	if code != Result.OK:
		return Result.make(code, {"request_id": 0})
	var rid := _next_request_id
	_next_request_id += 1
	_session = {"request_id": rid, "placement_id": placement_id, "context_id": context_id,
		"elapsed": 0.0, "started": false, "granted": false, "grant_failed": false}
	_set_state(LOADING)
	provider.load_ad(placement_id, consent.personalized_ads_allowed())
	return Result.make(Result.OK, {"request_id": rid})

## Drive from _process (Services node) or tests. Delivers adapter callbacks and timeouts.
func tick(dt: float) -> void:
	provider.poll()
	if state == IDLE:
		return
	_session.elapsed = float(_session.elapsed) + dt
	if state == LOADING and _session.elapsed >= load_timeout_s:
		diagnostics.timeouts += 1
		_finish(Result.TIMEOUT)
	elif state == SHOWING and _session.elapsed >= show_timeout_s:
		diagnostics.timeouts += 1
		_finish(Result.OK if _session.granted else Result.TIMEOUT)

func is_active() -> bool:
	return state != IDLE

func _matches(placement_id: String, wanted_state: String) -> bool:
	if state != wanted_state or str(_session.get("placement_id", "")) != placement_id:
		diagnostics.late_or_stray += 1
		return false
	return true

func _on_load_finished(placement_id: String, code: String) -> void:
	if not _matches(placement_id, LOADING):
		return
	if code == Result.OK:
		_session.elapsed = 0.0
		_set_state(SHOWING)
		provider.show_ad(placement_id)
	elif code == Result.NO_FILL or code == Result.OFFLINE:
		_finish(code)
	else:
		_finish(Result.ERROR)

func _on_show_started(placement_id: String) -> void:
	if _matches(placement_id, SHOWING):
		_session.started = true

func _on_reward_earned(placement_id: String) -> void:
	if not _matches(placement_id, SHOWING):
		return
	if _session.granted or _session.grant_failed or _session.get("already", false):
		diagnostics.duplicate_reward += 1
		return
	_grant()

func _on_show_failed(placement_id: String, _code: String) -> void:
	if not _matches(placement_id, SHOWING):
		return
	_finish(Result.OK if _session.granted else Result.ERROR)

func _on_closed(placement_id: String) -> void:
	if not _matches(placement_id, SHOWING):
		return
	if _session.granted:
		_finish(Result.OK)
	elif _session.get("already", false):
		_finish(Result.ALREADY_GRANTED)
	elif _session.grant_failed:
		_finish(Result.GRANT_FAILED)
	else:
		_finish(Result.CANCELLED)

func _grant() -> void:
	var pid: String = _session.placement_id
	var ctx: String = _session.context_id
	var reward: Dictionary = placements[pid].get("reward", {}).duplicate(true)
	if not store.is_usable():
		# Save reloaded during the ad: granting now would put the reward in the new progress
		# and the ledger in the old one. Refuse; the player can retry with a fresh store.
		diagnostics.grant_failed += 1
		_session.grant_failed = true
		_violation("ads_stale_store")
		return
	# Re-check the ledger: another path (restart, second instance on the same save) may have granted it.
	if _ledger().has(ctx):
		diagnostics.duplicate_reward += 1
		_session.already = true
		return
	# Ledger-first: record the grant BEFORE calling the sink, so any save that happens while
	# the sink runs (even one the sink triggers itself) carries reward and ledger together.
	var day: String = clock.local_day()
	var daily := _daily()
	var daily_before := daily.duplicate(true)
	_ledger()[ctx] = {"placement_id": pid, "day": day}
	if str(daily.get("day", "")) != day or not (daily.get("counts") is Dictionary):
		daily.clear()
		daily["day"] = day
		daily["counts"] = {}
	var counts: Dictionary = daily["counts"]
	counts[pid] = _num(counts.get(pid, 0)) + 1
	var applied := false
	var epoch0: int = store.save_epoch()
	if grant_sink.is_valid():
		applied = bool(grant_sink.call(pid, reward, ctx))
	var sink_saved := _sink_saved(epoch0)
	# Persistent store without a save-epoch source: a sink save cannot be ruled out, so a
	# failure is handled like saved-then-failed (conservative, no duplicate possible).
	var cannot_tell: bool = store.is_persistent() and store.save_epoch() < 0
	if sink_saved and applied:
		_violation("ads_sink_saved")   # safe thanks to ledger-first, but still a violation
	if not applied:
		diagnostics.grant_failed += 1
		_session.grant_failed = true
		if sink_saved or cannot_tell:
			# Contract violation (or unknown): the sink saved (our ledger-first entry is on disk) and then
			# reported failure. We cannot know whether its reward also reached disk. Removing
			# the ledger could leave reward-without-ledger (duplicate on retry), so keep the
			# ledger, mark it, and persist that: no duplicate; the player may lose this reward.
			_ledger()[ctx]["grant_unknown"] = true
			_violation("ads_sink_saved_then_failed" if sink_saved else "ads_failed_epoch_unknown")
			if not store.commit():
				_violation("ads_repair_commit_failed")
			return
		# Normal failure: roll back in memory. Nothing was committed by the service.
		_ledger().erase(ctx)
		daily.clear()
		daily.merge(daily_before)
		return
	_prune_ledger()
	_session.granted = true
	var persisted: bool = store.commit()
	reward_granted.emit(pid, reward, ctx, persisted)

func _finish(code: String) -> void:
	var rid := int(_session.get("request_id", 0))
	var pid := str(_session.get("placement_id", ""))
	_session = {}
	_set_state(IDLE)
	finished.emit(rid, pid, code)

func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)

func _ads() -> Dictionary:
	return store.section("ads")

func _ledger() -> Dictionary:
	var a := _ads()
	if not (a.get("granted_contexts") is Dictionary):
		a["granted_contexts"] = {}
	return a["granted_contexts"]

func _daily() -> Dictionary:
	var a := _ads()
	if not (a.get("daily") is Dictionary):
		a["daily"] = {}
	return a["daily"]

func _granted_today(placement_id: String) -> int:
	var daily := _daily()
	if str(daily.get("day", "")) != clock.local_day():
		return 0
	var counts = daily.get("counts", {})
	if not (counts is Dictionary):
		return 0
	return _num(counts.get(placement_id, 0))

static func _num(v: Variant) -> int:
	return int(v) if (v is int or v is float) else 0

## Grant-sink contract (SERVICES.md §3): the sink applies the reward in memory and must NOT
## save. Violations are detected through the store's save epoch, counted, reported via the
## `contract_violation` signal and push_warning, and handled safely (ledger-first + repair).
func _sink_saved(epoch0: int) -> bool:
	var e1: int = store.save_epoch()
	return epoch0 >= 0 and e1 >= 0 and e1 != epoch0

func _violation(kind: String) -> void:
	diagnostics.contract_violation = int(diagnostics.get("contract_violation", 0)) + 1
	push_warning("[Services] grant contract violation: " + kind)
	contract_violation.emit(kind)

## Repair a store section loaded from a damaged/edited save. Corrupt ledger entries are kept
## (conservative: they still block their context) and re-dated to today so they age out.
func _sanitize() -> void:
	var led := _ledger()
	for k in led.keys():
		var e = led[k]
		if not (e is Dictionary) or not (e.get("day") is String) or _day_index(str(e.day)) == 0:
			led[k] = {"placement_id": str(e.get("placement_id", "")) if e is Dictionary else "", "day": clock.local_day(), "repaired": true}
	var daily := _daily()
	if not (daily.get("counts") is Dictionary):
		daily.clear()

## Keep ledger bounded. Context ids must be unique within LEDGER_KEEP_DAYS (battle uid etc).
func _prune_ledger() -> void:
	var cutoff := _day_index(clock.local_day()) - LEDGER_KEEP_DAYS
	var led := _ledger()
	for k in led.keys():
		var e = led[k]
		if e is Dictionary and _day_index(str(e.get("day", ""))) < cutoff:
			led.erase(k)

static func _day_index(day: String) -> int:
	var parts := day.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return 0
	var t := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 0, "minute": 0, "second": 0})
	return int(t / 86400)
