extends RefCounted
## Store billing boundary (Google Play Billing first). Owner: 06-services. Spec: SERVICES.md §4.
## A production adapter is NOT written: no product catalog is approved and no billing plugin is
## installed. When approved, 04 adds a Godot Android billing plugin (Play Billing Library 8+)
## and 06 writes play_billing_provider.gd that maps its callbacks onto these signals.
##
## Purchase dictionary (all adapters):
##   {"product_id": String, "token": String, "order_id": String,
##    "state": "purchased" | "pending", "acknowledged": bool,
##    "environment": "mock" | "production",
##    "signed_data": String, "signature": String}   # raw store payload for server verification
##
## Codes for purchase_updated / owned_queried: ok | cancelled | offline | error |
##   already_owned | unknown_id (item unavailable)

const KIND_DISABLED := "disabled"
const KIND_MOCK := "mock"
const KIND_PRODUCTION := "production"

signal purchase_updated(code: String, purchases: Array)   # also fires unsolicited (pending -> paid)
signal owned_queried(code: String, purchases: Array)      # currently owned, unconsumed purchases
signal acknowledged(token: String, code: String)
signal consumed(token: String, code: String)

func kind() -> String:
	return KIND_DISABLED

func is_supported() -> bool:
	return false

func launch_purchase(_product_id: String) -> void:
	pass

func query_owned() -> void:
	pass

func acknowledge(_token: String) -> void:
	pass

func consume(_token: String) -> void:
	pass

func poll() -> void:
	pass
