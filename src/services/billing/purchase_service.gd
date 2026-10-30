extends RefCounted
## Purchase + entitlement + restore state machine. Owner: 06-services. Spec: SERVICES.md §4.
##
## User purchase flow:
##   IDLE --purchase()--> PURCHASING --store ok(purchased)--> VERIFYING --ok--> grant+commit
##     -> acknowledge/consume -> IDLE(ok)
##   PURCHASING: cancelled | offline | error | unknown_id | already_owned | pending | timeout -> IDLE
##   VERIFYING : invalid_receipt | verification_unavailable | revoked | timeout -> IDLE (no grant)
## Restore flow: restore() -> query_owned -> each owned purchase verified -> entitlements rebuilt.
## Unsolicited store updates (pending cleared later, purchase completed after our timeout) are
## processed through the same idempotent path.
##
## Invariants (tests/services/test_services.gd):
##  - Grant only on verifier "ok". No adapter returns ok for environment "production".
##  - One grant per purchase token (ledger keyed by sha256(token), never the raw token).
##  - Never acknowledge/consume an unverified or invalid purchase.
##  - Offline/failed restore never revokes; a successful store query may revoke refunded items.

const Result := preload("res://src/services/service_result.gd")

const IDLE := "idle"
const PURCHASING := "purchasing"
const VERIFYING := "verifying"
const RESTORING := "restoring"

const TYPE_NON_CONSUMABLE := "non_consumable"
const TYPE_CONSUMABLE := "consumable"

signal state_changed(state: String)
signal purchase_finished(product_id: String, code: String)
signal restore_finished(summary: Dictionary)
signal entitlement_changed(entitlement_id: String, owned: bool)
## Consumables only. grant_sink already applied it; persisted=false => save commit failed.
signal consumable_granted(product_id: String, grant: Dictionary, persisted: bool)

var provider
var verifier
var store
var clock
var network
var grant_sink: Callable   # (product_id, grant: Dictionary, purchase_key: String) -> bool, consumables

var enabled := false
var catalog := {}          # product_id -> {"type", "entitlement" (non-consumable), "grant" (consumable)}
var purchase_timeout_s := 180.0
var verify_timeout_s := 30.0
var revoke_missing_on_restore := true

var state := IDLE
var _flow := {}            # active user purchase
var _verifying := {}       # key -> {"purchase", "elapsed", "origin"}
var _restore := {}         # active restore
var _ack_inflight := {}    # key -> true while acknowledge/consume is outstanding (memory only)
var diagnostics := {"duplicate_updates": 0, "stray": 0, "unknown_product": 0, "ack_failed": 0}

func _init(p_provider, p_verifier, p_store, p_clock, p_network, config: Dictionary = {}) -> void:
	provider = p_provider
	verifier = p_verifier
	store = p_store
	clock = p_clock
	network = p_network
	enabled = bool(config.get("enabled", false))
	catalog = config.get("catalog", {}).duplicate(true)
	purchase_timeout_s = float(config.get("purchase_timeout_s", purchase_timeout_s))
	verify_timeout_s = float(config.get("verify_timeout_s", verify_timeout_s))
	revoke_missing_on_restore = bool(config.get("revoke_missing_on_restore", true))
	provider.purchase_updated.connect(_on_purchase_updated)
	provider.owned_queried.connect(_on_owned_queried)
	provider.acknowledged.connect(_on_acknowledged)
	provider.consumed.connect(_on_consumed)
	verifier.verified.connect(_on_verified)

# ---------------- public API ----------------

func has_entitlement(entitlement_id: String) -> bool:
	return _entitlements().has(entitlement_id)

func entitlements() -> Array:
	return _entitlements().keys()

func availability(product_id: String) -> String:
	if not enabled:
		return Result.DISABLED
	if not provider.is_supported():
		return Result.UNSUPPORTED
	if not catalog.has(product_id):
		return Result.UNKNOWN_ID
	var item: Dictionary = catalog[product_id]
	if str(item.get("type", "")) == TYPE_NON_CONSUMABLE and has_entitlement(str(item.get("entitlement", ""))):
		return Result.ALREADY_OWNED
	if network.is_known_offline():
		return Result.OFFLINE
	if not _flow.is_empty() or not _restore.is_empty():
		return Result.BUSY
	return Result.OK

func purchase(product_id: String) -> Dictionary:
	var code := availability(product_id)
	if code != Result.OK:
		return Result.make(code)
	_flow = {"product_id": product_id, "elapsed": 0.0, "key": ""}
	_update_state()
	provider.launch_purchase(product_id)
	return Result.make(Result.OK)

func restore() -> Dictionary:
	if not enabled:
		return Result.make(Result.DISABLED)
	if not provider.is_supported():
		return Result.make(Result.UNSUPPORTED)
	if not _flow.is_empty() or not _restore.is_empty():
		return Result.make(Result.BUSY)
	if network.is_known_offline():
		return Result.make(Result.OFFLINE)
	_restore = {"elapsed": 0.0, "queried": false, "waiting": {},
		"summary": {"restored": 0, "already": 0, "invalid": 0, "unverified": 0, "revoked": 0, "pending": 0}}
	_ack_inflight.clear()   # a restore is the retry point for acks that never answered
	_update_state()
	provider.query_owned()
	return Result.make(Result.OK)

func tick(dt: float) -> void:
	provider.poll()
	verifier.poll()
	if not _flow.is_empty():
		_flow.elapsed = float(_flow.elapsed) + dt
		if str(_flow.key) == "" and _flow.elapsed >= purchase_timeout_s:
			_finish_flow(Result.TIMEOUT)
	for key in _verifying.keys():
		var v: Dictionary = _verifying[key]
		v.elapsed = float(v.elapsed) + dt
		if v.elapsed >= verify_timeout_s:
			_on_verify_result(key, Result.VERIFICATION_UNAVAILABLE)
	if not _restore.is_empty():
		_restore.elapsed = float(_restore.elapsed) + dt
		if not _restore.queried and _restore.elapsed >= verify_timeout_s:
			_finish_restore(Result.TIMEOUT)

func is_active() -> bool:
	return state != IDLE

# ---------------- store callbacks ----------------

func _on_purchase_updated(code: String, purchases: Array) -> void:
	if code != Result.OK:
		if not _flow.is_empty() and str(_flow.key) == "":
			_finish_flow(code if [Result.CANCELLED, Result.OFFLINE, Result.ALREADY_OWNED, Result.UNKNOWN_ID].has(code) else Result.ERROR)
		else:
			diagnostics.stray += 1
		return
	for p in purchases:
		if p is Dictionary:
			_handle_purchase(p, "update")

func _on_owned_queried(code: String, purchases: Array) -> void:
	if _restore.is_empty() or _restore.queried:
		diagnostics.stray += 1
		return
	_restore.queried = true
	if code != Result.OK:
		_finish_restore(code if code == Result.OFFLINE else Result.ERROR)
		return
	var seen := {}
	for p in purchases:
		if p is Dictionary:
			seen[_key(str(p.get("token", "")))] = true
			_handle_purchase(p, "restore")
	if revoke_missing_on_restore:
		for ent in _entitlements().keys():
			var e: Dictionary = _entitlements()[ent]
			if not seen.has(str(e.get("key", ""))):
				_revoke_key(str(e.get("key", "")))
				_restore.summary.revoked += 1
	_maybe_finish_restore()

func _on_acknowledged(token: String, code: String) -> void:
	var led := _ledger()
	var key := _key(token)
	_ack_inflight.erase(key)
	if not led.has(key):
		diagnostics.stray += 1
		return
	if code == Result.OK:
		led[key]["acknowledged"] = true
		store.commit()
	else:
		diagnostics.ack_failed += 1   # retried on next restore (store re-reports unacknowledged)

func _on_consumed(token: String, code: String) -> void:
	var key := _key(token)
	_ack_inflight.erase(key)
	if _ledger().has(key) and code == Result.OK:
		_ledger()[key]["acknowledged"] = true
		store.commit()

func _on_verified(token: String, code: String, _info: Dictionary) -> void:
	var key := _key(token)
	if not _verifying.has(key):
		diagnostics.stray += 1
		return
	_on_verify_result(key, code)

# ---------------- core ----------------

func _handle_purchase(p: Dictionary, origin: String) -> void:
	var pid := str(p.get("product_id", ""))
	var token := str(p.get("token", ""))
	if not catalog.has(pid) or token.is_empty():
		diagnostics.unknown_product += 1
		return
	var key := _key(token)
	if _flow_waiting_for(pid) and origin == "update":
		_flow.key = key
	if str(p.get("state", "")) == "pending":
		if origin == "restore":
			_restore.summary.pending += 1
		if _flow_waiting_for(pid) and str(_flow.key) == key:
			_finish_flow(Result.PENDING)
		return
	var led := _ledger()
	if led.has(key):
		var entry: Dictionary = led[key]
		match str(entry.get("state", "")):
			"granted":
				diagnostics.duplicate_updates += 1
				_ensure_entitlement(pid, key)
				if not bool(p.get("acknowledged", false)) or not bool(entry.get("acknowledged", false)):
					_ack(pid, token)
				if origin == "restore":
					_restore.summary.already += 1
				if _flow_waiting_for(pid) and str(_flow.key) == key:
					_finish_flow(Result.OK)
				return
			"invalid", "revoked":
				diagnostics.duplicate_updates += 1
				if origin == "restore":
					_restore.summary.invalid += 1
				if _flow_waiting_for(pid) and str(_flow.key) == key:
					_finish_flow(Result.INVALID_RECEIPT if entry.state == "invalid" else Result.REVOKED)
				return
	if _verifying.has(key):
		diagnostics.duplicate_updates += 1
		if origin == "restore":
			_verifying[key].origin = "restore"
			_restore.waiting[key] = true
		return
	_verifying[key] = {"purchase": p.duplicate(), "elapsed": 0.0, "origin": origin}
	if origin == "restore":
		_restore.waiting[key] = true
	_update_state()
	verifier.verify(p)

func _on_verify_result(key: String, code: String) -> void:
	var v: Dictionary = _verifying[key]
	_verifying.erase(key)
	var p: Dictionary = v.purchase
	var pid := str(p.product_id)
	var final_code := code
	match code:
		Result.OK:
			final_code = _grant(p, key)
		Result.INVALID_RECEIPT:
			_ledger()[key] = {"product_id": pid, "state": "invalid", "acknowledged": false}
			store.commit()
		Result.REVOKED:
			_ledger()[key] = {"product_id": pid, "state": "revoked", "acknowledged": false}
			_revoke_key(key)
			store.commit()
		_:
			final_code = Result.VERIFICATION_UNAVAILABLE   # not recorded: retry on next restore
	if _restore.has("waiting") and _restore.waiting.has(key):
		_restore.waiting.erase(key)
		match final_code:
			Result.OK: _restore.summary.restored += 1
			Result.INVALID_RECEIPT: _restore.summary.invalid += 1
			Result.REVOKED: _restore.summary.revoked += 1
			_: _restore.summary.unverified += 1
	if _flow_waiting_for(pid) and str(_flow.key) == key:
		_finish_flow(final_code)
	_maybe_finish_restore()
	_update_state()

func _grant(p: Dictionary, key: String) -> String:
	var pid := str(p.product_id)
	var item: Dictionary = catalog[pid]
	var persisted := true
	if str(item.get("type", "")) == TYPE_CONSUMABLE:
		var g: Dictionary = item.get("grant", {}).duplicate(true)
		if not grant_sink.is_valid() or not bool(grant_sink.call(pid, g, key)):
			return Result.GRANT_FAILED     # not acknowledged/consumed -> store may refund
		_ledger()[key] = {"product_id": pid, "state": "granted", "acknowledged": false}
		persisted = store.commit()
		consumable_granted.emit(pid, g, persisted)
		provider.consume(str(p.token))
	else:
		_ledger()[key] = {"product_id": pid, "state": "granted", "acknowledged": false}
		_ensure_entitlement(pid, key)
		persisted = store.commit()
		_ack(pid, str(p.token))
	return Result.OK

func _ensure_entitlement(pid: String, key: String) -> void:
	var item: Dictionary = catalog.get(pid, {})
	if str(item.get("type", "")) != TYPE_NON_CONSUMABLE:
		return
	var ent := str(item.get("entitlement", ""))
	if ent.is_empty():
		return
	var ents := _entitlements()
	if ents.has(ent) and str(ents[ent].get("key", "")) == key:
		return
	var was := ents.has(ent)
	ents[ent] = {"product_id": pid, "key": key, "granted_at": clock.now_unix()}
	store.commit()
	if not was:
		entitlement_changed.emit(ent, true)

func _revoke_key(key: String) -> void:
	var ents := _entitlements()
	for ent in ents.keys():
		if str(ents[ent].get("key", "")) == key:
			ents.erase(ent)
			if _ledger().has(key):
				_ledger()[key]["state"] = "revoked"
			store.commit()
			entitlement_changed.emit(ent, false)

func _ack(pid: String, token: String) -> void:
	var key := _key(token)
	if _ack_inflight.has(key):
		return   # duplicate store update while the first ack is still outstanding
	_ack_inflight[key] = true
	if str(catalog.get(pid, {}).get("type", "")) == TYPE_CONSUMABLE:
		provider.consume(token)
	else:
		provider.acknowledge(token)

func _flow_waiting_for(pid: String) -> bool:
	return not _flow.is_empty() and str(_flow.product_id) == pid

func _finish_flow(code: String) -> void:
	var pid := str(_flow.get("product_id", ""))
	_flow = {}
	_update_state()
	purchase_finished.emit(pid, code)

func _maybe_finish_restore() -> void:
	if not _restore.is_empty() and _restore.queried and _restore.waiting.is_empty():
		_finish_restore(Result.OK)

func _finish_restore(code: String) -> void:
	var summary: Dictionary = _restore.get("summary", {}).duplicate()
	summary["code"] = code
	_restore = {}
	_update_state()
	restore_finished.emit(summary)

func _update_state() -> void:
	var s := IDLE
	if not _verifying.is_empty() or str(_flow.get("key", "")) != "":
		s = VERIFYING
	elif not _flow.is_empty():
		s = PURCHASING
	elif not _restore.is_empty():
		s = RESTORING
	if s != state:
		state = s
		state_changed.emit(s)

func _iap() -> Dictionary:
	return store.section("iap")

func _ledger() -> Dictionary:
	var s := _iap()
	if not (s.get("ledger") is Dictionary):
		s["ledger"] = {}
	return s["ledger"]

func _entitlements() -> Dictionary:
	var s := _iap()
	if not (s.get("entitlements") is Dictionary):
		s["entitlements"] = {}
	return s["entitlements"]

## Ledger key: hash of the purchase token. Raw tokens are never persisted by 06.
static func _key(token: String) -> String:
	return token.sha256_text().substr(0, 32)
