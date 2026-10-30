extends "res://src/services/consent/consent_provider.gd"
## MOCK consent provider for tests/debug ONLY. Shows no form, contacts nothing. Owner: 06-services.
## info scenarios (consumed in order, default "required"):
##   required, not_required, obtained, offline, error, hang
## form scenarios (default "accept_all"):
##   accept_all, reject_all, ads_only (non-personalised), dismissed, error, hang

var info_scenarios: Array[String] = []
var form_scenarios: Array[String] = []
var _queue: Array = []
var info_calls := 0
var form_calls := 0
var resets := 0

func kind() -> String:
	return "mock"

func is_supported() -> bool:
	return true

func request_info_update() -> void:
	info_calls += 1
	var sc: String = info_scenarios.pop_front() if not info_scenarios.is_empty() else "required"
	match sc:
		"not_required": _queue.append(["info", "ok", "not_required"])
		"obtained": _queue.append(["info", "ok", "obtained"])
		"offline": _queue.append(["info", "offline", "unknown"])
		"error": _queue.append(["info", "error", "unknown"])
		"hang": pass
		_: _queue.append(["info", "ok", "required"])

func show_form() -> void:
	form_calls += 1
	var sc: String = form_scenarios.pop_front() if not form_scenarios.is_empty() else "accept_all"
	match sc:
		"reject_all": _queue.append(["form", "ok", {"ads": "denied", "ads_personalized": "denied"}])
		"ads_only": _queue.append(["form", "ok", {"ads": "granted", "ads_personalized": "denied"}])
		"dismissed": _queue.append(["form", "cancelled", {}])
		"error": _queue.append(["form", "error", {}])
		"hang": pass
		_: _queue.append(["form", "ok", {"ads": "granted", "ads_personalized": "granted"}])

func reset() -> void:
	resets += 1

## Inject an arbitrary callback (late/duplicate/stray).
func inject(kind_name: String, code: String, payload: Variant) -> void:
	_queue.append([kind_name, code, payload])

func poll() -> void:
	if _queue.is_empty():
		return
	var e: Array = _queue.pop_front()
	if e[0] == "info":
		info_updated.emit(e[1], e[2])
	else:
		form_closed.emit(e[1], e[2])
