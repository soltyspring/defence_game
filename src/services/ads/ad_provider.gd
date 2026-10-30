extends RefCounted
## Rewarded-ad SDK boundary. Owner: 06-services. Spec: docs/services/SERVICES.md §3.
## A production adapter (not written: no ad network approved, no SDK installed) wraps a Godot
## Android plugin and re-emits its callbacks as these signals. Callbacks may arrive late,
## twice, or out of order; RewardedAdService is responsible for tolerating that.
##
## Callback contract (all carry the placement id the service asked for):
##   load_finished(placement_id, code)   code: ok | no_fill | offline | error
##   show_started(placement_id)
##   reward_earned(placement_id)          SDK says the user completed the ad
##   show_failed(placement_id, code)
##   closed(placement_id)                 full-screen ad dismissed

const KIND_DISABLED := "disabled"
const KIND_MOCK := "mock"
const KIND_PRODUCTION := "production"

signal load_finished(placement_id: String, code: String)
signal show_started(placement_id: String)
signal reward_earned(placement_id: String)
signal show_failed(placement_id: String, code: String)
signal closed(placement_id: String)

func kind() -> String:
	return KIND_DISABLED

func is_supported() -> bool:
	return false

## personalized: false => adapter must request non-personalised ads (consent gate result).
func load_ad(_placement_id: String, _personalized: bool) -> void:
	pass

func show_ad(_placement_id: String) -> void:
	pass

## Called from RewardedAdService.tick(). Real adapters ignore it; the mock delivers queued callbacks.
func poll() -> void:
	pass
