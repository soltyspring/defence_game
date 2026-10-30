extends "res://src/services/billing/receipt_verifier.gd"
## Production default verifier until a verification server exists. Owner: 06-services.
## Always answers verification_unavailable, so PurchaseService never grants a real-money
## purchase without a trusted verdict (and never acknowledges it, so Play auto-refunds an
## unacknowledged purchase after its acknowledgement window instead of charging for nothing).

const Result := preload("res://src/services/service_result.gd")

var _queue: Array[String] = []

func kind() -> String:
	return "unavailable"

func verify(purchase: Dictionary) -> void:
	_queue.append(str(purchase.get("token", "")))

func poll() -> void:
	while not _queue.is_empty():
		verified.emit(_queue.pop_front(), Result.VERIFICATION_UNAVAILABLE, {"reason": "no_verification_server"})
