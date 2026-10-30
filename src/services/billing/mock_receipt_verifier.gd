extends "res://src/services/billing/receipt_verifier.gd"
## MOCK verifier for tests/debug ONLY. Owner: 06-services.
## Accepts ONLY purchases created by mock_billing_provider.gd (environment "mock" AND a token
## that matches the mock token derivation). Any "production" purchase is answered
## verification_unavailable: this class can never approve real money.

const Result := preload("res://src/services/service_result.gd")
const MockBilling := preload("res://src/services/billing/mock_billing_provider.gd")

var revoked_tokens := {}   # token -> true: simulate refunds
var hang := false          # never answer (verifier timeout)
var force_unavailable := false
var _queue: Array = []
var calls := 0

func kind() -> String:
	return "mock"

func verify(purchase: Dictionary) -> void:
	calls += 1
	if hang:
		return
	var token := str(purchase.get("token", ""))
	var code := Result.OK
	if force_unavailable or str(purchase.get("environment", "")) != "mock":
		code = Result.VERIFICATION_UNAVAILABLE
	elif token != MockBilling.mock_token(str(purchase.get("product_id", "")), str(purchase.get("order_id", ""))):
		code = Result.INVALID_RECEIPT
	elif str(purchase.get("state", "")) != "purchased":
		code = Result.INVALID_RECEIPT
	elif revoked_tokens.has(token):
		code = Result.REVOKED
	_queue.append([token, code])

func poll() -> void:
	while not _queue.is_empty():
		var e: Array = _queue.pop_front()
		verified.emit(e[0], e[1], {"verifier": "mock"})
