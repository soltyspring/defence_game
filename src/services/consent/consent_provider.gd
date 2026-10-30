extends RefCounted
## Platform consent boundary (Google UMP-like: consent info update + consent form).
## Owner: 06-services. Spec: docs/services/SERVICES.md §5.1.
## No production adapter exists (no ad SDK / UMP plugin is approved or installed).
##
## Callbacks:
##   info_updated(code, requirement)   code: ok | offline | error
##                                     requirement: required | not_required | obtained | unknown
##   form_closed(code, choices)        code: ok | cancelled | error
##                                     choices: {"ads": v, "ads_personalized": v} (ads purposes only)

signal info_updated(code: String, requirement: String)
signal form_closed(code: String, choices: Dictionary)

func kind() -> String:
	return "disabled"

func is_supported() -> bool:
	return false

func request_info_update() -> void:
	pass

func show_form() -> void:
	pass

## Platform-side reset (UMP has reset() for testing / withdrawal re-prompt).
func reset() -> void:
	pass

func poll() -> void:
	pass
