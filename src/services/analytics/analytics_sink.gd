extends RefCounted
## Analytics transport boundary. Owner: 06-services.
## Default = this null sink: events are validated and then discarded, nothing leaves the device.
## A remote sink is NOT implemented; it needs a user decision (vendor or own endpoint), a
## privacy policy, Play Data safety entries and the INTERNET permission (PRODUCTION_REQUIREMENTS.md).

func kind() -> String:
	return "null"

func is_remote() -> bool:
	return false

## batch: Array of envelopes. Return true when accepted (caller drops them), false to retry later.
func send(_batch: Array) -> bool:
	return true
