extends "res://src/services/ads/ad_provider.gd"
## MOCK rewarded-ad adapter for tests and debug builds ONLY. Shows no ad, contacts no network,
## earns no money. Owner: 06-services.
## Each load/show consumes the next scripted scenario (default "complete"). Callbacks are queued
## and delivered on poll(), like a real async SDK, so services cannot rely on re-entrancy.
##
## Scenarios:
##   complete          load ok -> started -> earned -> closed
##   cancel            load ok -> started -> closed (no reward)
##   no_fill           load no_fill
##   offline           load offline
##   load_hang         load never answers (service load timeout)
##   show_hang         load ok -> started, never closes (service show timeout)
##   earned_no_close   load ok -> started -> earned, never closes
##   show_fail         load ok -> show_failed(error)
##   earned_twice      load ok -> started -> earned -> earned -> closed -> closed
##   late_earned       load ok -> started -> closed -> earned (reward after dismissal)

var scenarios: Array[String] = []
var _queue: Array = []          # [signal_name, args]
var _current := "complete"
var loads := 0
var shows := 0
var last_personalized := false

func kind() -> String:
	return KIND_MOCK

func is_supported() -> bool:
	return true

func set_scenarios(list: Array) -> void:
	scenarios.clear()
	for s in list:
		scenarios.append(str(s))

func load_ad(placement_id: String, personalized: bool) -> void:
	loads += 1
	last_personalized = personalized
	_current = scenarios.pop_front() if not scenarios.is_empty() else "complete"
	match _current:
		"no_fill":
			_push("load_finished", [placement_id, "no_fill"])
		"offline":
			_push("load_finished", [placement_id, "offline"])
		"load_hang":
			pass
		_:
			_push("load_finished", [placement_id, "ok"])

func show_ad(placement_id: String) -> void:
	shows += 1
	match _current:
		"show_fail":
			_push("show_failed", [placement_id, "error"])
		"cancel":
			_push("show_started", [placement_id])
			_push("closed", [placement_id])
		"show_hang":
			_push("show_started", [placement_id])
		"earned_no_close":
			_push("show_started", [placement_id])
			_push("reward_earned", [placement_id])
		"earned_twice":
			_push("show_started", [placement_id])
			_push("reward_earned", [placement_id])
			_push("reward_earned", [placement_id])
			_push("closed", [placement_id])
			_push("closed", [placement_id])
		"late_earned":
			_push("show_started", [placement_id])
			_push("closed", [placement_id])
			_push("reward_earned", [placement_id])
		_:
			_push("show_started", [placement_id])
			_push("reward_earned", [placement_id])
			_push("closed", [placement_id])

## Inject an arbitrary callback (e.g. a stray SDK event while idle).
func inject(signal_name: String, args: Array) -> void:
	_push(signal_name, args)

func pending_callbacks() -> int:
	return _queue.size()

func _push(sig: String, args: Array) -> void:
	_queue.append([sig, args])

## Delivers ONE queued callback per poll so tests can interleave timeouts between callbacks.
func poll() -> void:
	if _queue.is_empty():
		return
	var e: Array = _queue.pop_front()
	var args: Array = e[1]
	match str(e[0]):
		"load_finished": load_finished.emit(args[0], args[1])
		"show_started": show_started.emit(args[0])
		"reward_earned": reward_earned.emit(args[0])
		"show_failed": show_failed.emit(args[0], args[1])
		"closed": closed.emit(args[0])
