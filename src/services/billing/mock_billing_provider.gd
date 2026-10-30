extends "res://src/services/billing/billing_provider.gd"
## MOCK billing adapter for tests/debug ONLY. No store, no money, no network. Owner: 06-services.
## Purchases are tagged environment "mock"; only mock_receipt_verifier.gd accepts them.
## Callbacks are queued and delivered on poll() (one batch per poll).
##
## launch_purchase scenarios (consumed in order, default "success"):
##   success, cancel, offline, error, item_unavailable, already_owned,
##   pending   (pending now; call complete_pending(product_id) later for the paid update)
##   duplicate (same purchased update delivered twice)
##   hang      (no callback at all; service purchase timeout)
##   tampered  (purchased update with a forged token)
## query_owned scenarios: "ok" (default) or "offline".
## ack scenarios: set ack_fail = true to fail acknowledgements.

const MOCK_KEY := "mock-only-not-a-secret"

var purchase_scenarios: Array[String] = []
var query_scenarios: Array[String] = []
var ack_fail := false
var owned := {}          # product_id -> purchase dict (simulated store-side ownership)
var _pending := {}       # product_id -> purchase dict
var _queue: Array = []
var _order_seq := 0
var acks := 0
var consumes := 0
var launches := 0

static func mock_token(product_id: String, order_id: String) -> String:
	return "mock-" + (product_id + "|" + order_id + "|" + MOCK_KEY).sha256_text().substr(0, 24)

func kind() -> String:
	return KIND_MOCK

func is_supported() -> bool:
	return true

func _make(product_id: String, state: String) -> Dictionary:
	_order_seq += 1
	var order := "MOCK.%04d" % _order_seq
	return {"product_id": product_id, "token": mock_token(product_id, order), "order_id": order,
		"state": state, "acknowledged": false, "environment": "mock",
		"signed_data": "", "signature": ""}

func launch_purchase(product_id: String) -> void:
	launches += 1
	var sc: String = purchase_scenarios.pop_front() if not purchase_scenarios.is_empty() else "success"
	match sc:
		"cancel": _push("purchase_updated", ["cancelled", []])
		"offline": _push("purchase_updated", ["offline", []])
		"error": _push("purchase_updated", ["error", []])
		"item_unavailable": _push("purchase_updated", ["unknown_id", []])
		"already_owned": _push("purchase_updated", ["already_owned", []])
		"hang": pass
		"pending":
			var p := _make(product_id, "pending")
			_pending[product_id] = p
			_push("purchase_updated", ["ok", [p.duplicate()]])
		"tampered":
			var t := _make(product_id, "purchased")
			t.token = "mock-forged-token"
			_push("purchase_updated", ["ok", [t]])
		"duplicate":
			var d := _make(product_id, "purchased")
			owned[product_id] = d
			_push("purchase_updated", ["ok", [d.duplicate()]])
			_push("purchase_updated", ["ok", [d.duplicate()]])
		_:
			var s := _make(product_id, "purchased")
			owned[product_id] = s
			_push("purchase_updated", ["ok", [s.duplicate()]])

## Simulate a pending payment clearing later (unsolicited update, maybe after restart).
func complete_pending(product_id: String) -> void:
	if not _pending.has(product_id):
		return
	var p: Dictionary = _pending[product_id]
	_pending.erase(product_id)
	p.state = "purchased"
	owned[product_id] = p
	_push("purchase_updated", ["ok", [p.duplicate()]])

## Simulate a refund: store no longer reports the product as owned.
func refund(product_id: String) -> void:
	owned.erase(product_id)

func query_owned() -> void:
	var sc: String = query_scenarios.pop_front() if not query_scenarios.is_empty() else "ok"
	if sc == "offline":
		_push("owned_queried", ["offline", []])
		return
	var list: Array = []
	for k in owned:
		list.append(owned[k].duplicate())
	_push("owned_queried", ["ok", list])

func acknowledge(token: String) -> void:
	acks += 1
	if not ack_fail:
		for k in owned:
			if owned[k].token == token:
				owned[k].acknowledged = true
	_push("acknowledged", [token, "error" if ack_fail else "ok"])

func consume(token: String) -> void:
	consumes += 1
	for k in owned.keys():
		if owned[k].token == token:
			owned.erase(k)
	_push("consumed", [token, "ok"])

func pending_callbacks() -> int:
	return _queue.size()

func _push(sig: String, args: Array) -> void:
	_queue.append([sig, args])

func poll() -> void:
	if _queue.is_empty():
		return
	var e: Array = _queue.pop_front()
	var a: Array = e[1]
	match str(e[0]):
		"purchase_updated": purchase_updated.emit(a[0], a[1])
		"owned_queried": owned_queried.emit(a[0], a[1])
		"acknowledged": acknowledged.emit(a[0], a[1])
		"consumed": consumed.emit(a[0], a[1])
