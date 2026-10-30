extends RefCounted
## Service → analytics bridge. Owner: 06-services. Contract: docs/services/ANALYTICS_EVENTS.md §3.
## Emits ad_offer / ad_result / purchase_result / restore_result from service signals.
## Bounded: at most MAX_PER_EVENT events of each name and MAX_TOTAL overall per app session,
## and an ad_offer for the same placement+context is emitted once (UI may re-render often).
## Every event still passes AnalyticsService gates (enabled, consent, schema). Analytics is
## disabled by default, so in shipped builds these calls are counted and dropped.
## Telemetry never changes service behaviour: it only listens.

const Result := preload("res://src/services/service_result.gd")

const MAX_PER_EVENT := 30
const MAX_TOTAL := 100
const MAX_OFFER_KEYS := 64

var analytics
var _per_event := {}
var _total := 0
var _offer_seen := {}
var stats := {"emitted": 0, "suppressed_cap": 0, "suppressed_dup_offer": 0, "gated": 0}

func _init(p_analytics, ads = null, purchases = null) -> void:
	analytics = p_analytics
	if ads != null:
		ads.finished.connect(_on_ad_finished)
	if purchases != null:
		purchases.purchase_finished.connect(_on_purchase_finished)
		purchases.restore_finished.connect(_on_restore_finished)

## UI (04) calls this when a "watch ad" offer becomes visible.
func offer_shown(placement_id: String, context_id: String) -> String:
	var k := placement_id + "|" + context_id
	if _offer_seen.has(k):
		stats.suppressed_dup_offer += 1
		return Result.ALREADY_GRANTED
	if _offer_seen.size() >= MAX_OFFER_KEYS:
		_offer_seen.clear()
	_offer_seen[k] = true
	return _emit("ad_offer", {"placement_id": placement_id})

func _on_ad_finished(_request_id: int, placement_id: String, code: String) -> void:
	_emit("ad_result", {"placement_id": placement_id, "result": code})

func _on_purchase_finished(product_id: String, code: String) -> void:
	_emit("purchase_result", {"product_id": product_id, "result": code})

func _on_restore_finished(summary: Dictionary) -> void:
	_emit("restore_result", {"result": str(summary.get("code", Result.ERROR)), "restored": int(summary.get("restored", 0))})

func _emit(event_name: String, params: Dictionary) -> String:
	var n := int(_per_event.get(event_name, 0))
	if n >= MAX_PER_EVENT or _total >= MAX_TOTAL:
		stats.suppressed_cap += 1
		return Result.CAP_REACHED
	var code: String = analytics.track(event_name, params)
	if code == Result.OK:
		_per_event[event_name] = n + 1
		_total += 1
		stats.emitted += 1
	else:
		stats.gated += 1
	return code
