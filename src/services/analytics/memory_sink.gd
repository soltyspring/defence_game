extends "res://src/services/analytics/analytics_sink.gd"
## Local in-memory sink for tests and debug overlays. Never leaves the process. Owner: 06-services.

var received: Array = []
var fail := false   # simulate transport failure
var max_keep := 500

func kind() -> String:
	return "memory"

func send(batch: Array) -> bool:
	if fail:
		return false
	for e in batch:
		received.append(e)
	while received.size() > max_keep:
		received.pop_front()
	return true
