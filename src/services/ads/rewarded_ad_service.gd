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

const IDLE := "idle"
const LOADING := "loading"
const SHOWING := "showing"

const LEDGER_KEEP_DAYS := 7

signal state_changed(state: String)
## persisted=false means the in-memory grant happened but the save commit failed; both reward
## and ledger stay in memory and are written together by the next successful save.
signal reward_granted(placement_id: String, reward: Dictionary, context_id: String, persisted: bool)
signal finished(request_id: int, placement_id: String, code: String)

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
var diagnostics := {"duplicate_reward": 0, "late_or_stray": 0, "timeouts": 0, "grant_failed": 0}

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

## Cheap check for UI: should a "watch ad" button be offered? Does not call the SDK.
func availability(placement_id: String, context_id: String) -> String:
	if not enabled:
		return Result.DISABLED
	if provider == null or not provider.is_supported():
		return Result.UNSUPPORTED
	if not placements.has(placement_id):
		return Result.UNKNOWN_ID
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
	if _session.granted or _session.grant_failed:
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
	elif _session.grant_failed:
		_finish(Result.GRANT_FAILED)
	else:
		_finish(Result.CANCELLED)

func _grant() -> void:
	var pid: String = _session.placement_id
	var ctx: String = _session.context_id
	var reward: Dictionary = placements[pid].get("reward", {}).duplicate(true)
	# Re-check the ledger: another path (restart, second device of same save) may have granted it.
	if _ledger().has(ctx):
		diagnostics.duplicate_reward += 1
		_session.grant_failed = true
		return
	var applied := false
	if grant_sink.is_valid():
		applied = bool(grant_sink.call(pid, reward, ctx))
	if not applied:
		diagnostics.grant_failed += 1
		_session.grant_failed = true
		return
	var day: String = clock.local_day()
	_ledger()[ctx] = {"placement_id": pid, "day": day}
	var daily := _daily()
	if str(daily.get("day", "")) != day:
		daily.clear()
		daily["day"] = day
		daily["counts"] = {}
	var counts: Dictionary = daily.get("counts", {})
	counts[pid] = int(counts.get(pid, 0)) + 1
	daily["counts"] = counts
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
	return int(daily.get("counts", {}).get(placement_id, 0))

## Keep ledger bounded. Context ids must be unique within LEDGER_KEEP_DAYS (battle uid etc).
func _prune_ledger() -> void:
	var cutoff := _day_index(clock.local_day()) - LEDGER_KEEP_DAYS
	var led := _ledger()
	for k in led.keys():
		if _day_index(str(led[k].get("day", ""))) < cutoff:
			led.erase(k)

static func _day_index(day: String) -> int:
	var parts := day.split("-")
	if parts.size() != 3:
		return 0
	var t := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 0, "minute": 0, "second": 0})
	return int(t / 86400)
