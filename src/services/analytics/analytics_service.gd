extends RefCounted
## Privacy-preserving analytics gate. Owner: 06-services. Spec: docs/services/ANALYTICS_EVENTS.md.
## Order of gates for track(): enabled -> consent(analytics) -> schema validation -> bounded queue.
## Events blocked by a gate are dropped, NOT queued for later (no "collect now, ask later").
## Consent withdrawal purges the queue. Session id is random per app launch and never persisted.

const Result := preload("res://src/services/service_result.gd")
const Schema := preload("res://src/services/analytics/event_schema.gd")
const Consent := preload("res://src/services/consent_service.gd")

var sink
var consent
var enabled := false
var max_queue := 100
var batch_size := 20

var session_id := ""
var _seq := 0
var _session_t := 0.0
var _queue: Array = []
var stats := {"accepted": 0, "dropped_disabled": 0, "dropped_consent": 0, "rejected_schema": 0,
	"dropped_overflow": 0, "send_failed": 0, "sent": 0}
var last_reject_reason := ""

func _init(p_sink, p_consent, config: Dictionary = {}, rng_seed: int = -1) -> void:
	sink = p_sink
	consent = p_consent
	enabled = bool(config.get("enabled", false))
	max_queue = int(config.get("max_queue", max_queue))
	batch_size = int(config.get("batch_size", batch_size))
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	session_id = "%08x%08x" % [rng.randi(), rng.randi()]
	consent.consent_changed.connect(_on_consent_changed)

## Returns a Result code string. Never throws, never blocks gameplay.
func track(event_name: String, params: Dictionary = {}) -> String:
	if not enabled:
		stats.dropped_disabled += 1
		return Result.DISABLED
	if consent.check(Consent.PURPOSE_ANALYTICS) != Result.OK:
		stats.dropped_consent += 1
		return Result.CONSENT_REQUIRED
	var v := Schema.validate(event_name, params)
	if not v.ok:
		stats.rejected_schema += 1
		last_reject_reason = str(v.reason)
		return Result.ERROR
	_seq += 1
	_queue.append({"v": Schema.VERSION, "name": event_name, "params": v.params,
		"session": session_id, "seq": _seq, "t_s": int(_session_t)})
	while _queue.size() > max_queue:
		_queue.pop_front()
		stats.dropped_overflow += 1
	stats.accepted += 1
	return Result.OK

func tick(dt: float) -> void:
	_session_t += dt

func queued() -> int:
	return _queue.size()

## Send up to one batch. Call on pause/background and periodically (Services node).
func flush() -> String:
	if _queue.is_empty():
		return Result.OK
	var n := mini(batch_size, _queue.size())
	var batch := _queue.slice(0, n)
	if sink.send(batch):
		_queue = _queue.slice(n)
		stats.sent += n
		return Result.OK
	stats.send_failed += 1
	return Result.ERROR

func _on_consent_changed(purpose: String, value: String) -> void:
	if purpose == Consent.PURPOSE_ANALYTICS and value != Consent.GRANTED and value != Consent.NOT_REQUIRED:
		_queue.clear()
