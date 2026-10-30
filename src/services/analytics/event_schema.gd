extends RefCounted
## Allow-listed analytics event contract v1. Owner: 06-services.
## Human-readable contract + data inventory: docs/services/ANALYTICS_EVENTS.md (keep in sync;
## tests/services checks the doc lists every event below).
## Rules: no free text, no device/advertising IDs, no names/emails/IP, no precise timestamps.
## Every param is an int range, bool, enum, or a short ID matching a strict pattern.

const VERSION := 1

const RESULT_CODES := ["ok", "disabled", "unsupported", "unknown_id", "consent_required", "offline",
	"timeout", "cancelled", "no_fill", "busy", "cap_reached", "already_granted", "already_owned",
	"pending", "invalid_receipt", "verification_unavailable", "revoked", "grant_failed", "not_eligible", "error"]

const EVENTS := {
	"session_start": {
		"app_version": {"type": "id", "pattern": "^\\d+\\.\\d+\\.\\d+$"},
		"build": {"type": "enum", "values": ["debug", "release"]},
		"lang": {"type": "enum", "values": ["ko", "en", "other"]},
	},
	"round_start": {
		"round_id": {"type": "id", "pattern": "^r\\d{2}$"},
		"attempt": {"type": "int", "min": 1, "max": 99, "clamp": true},
	},
	"round_end": {
		"round_id": {"type": "id", "pattern": "^r\\d{2}$"},
		"won": {"type": "bool"},
		"stars": {"type": "int", "min": 0, "max": 3},
		"duration_s": {"type": "int", "min": 0, "max": 3600, "clamp": true, "bucket": 10},
		"kills": {"type": "int", "min": 0, "max": 999, "clamp": true},
	},
	"upgrade_buy": {
		"upgrade_id": {"type": "id", "pattern": "^up_[a-z_]{1,32}$"},
		"level": {"type": "int", "min": 1, "max": 10},
	},
	"ad_offer": {
		"placement_id": {"type": "id", "pattern": "^ad_[a-z_]{1,32}$"},
	},
	"ad_result": {
		"placement_id": {"type": "id", "pattern": "^ad_[a-z_]{1,32}$"},
		"result": {"type": "enum", "values": RESULT_CODES},
	},
	"purchase_result": {
		"product_id": {"type": "id", "pattern": "^[a-z0-9_.]{1,64}$"},
		"result": {"type": "enum", "values": RESULT_CODES},
	},
	"restore_result": {
		"result": {"type": "enum", "values": RESULT_CODES},
		"restored": {"type": "int", "min": 0, "max": 50, "clamp": true},
	},
	"error": {
		"area": {"type": "enum", "values": ["save", "ads", "billing", "analytics", "content", "other"]},
		"code": {"type": "id", "pattern": "^[a-z_]{1,32}$"},
	},
}

## Returns {"ok": bool, "params": sanitised Dictionary, "reason": String}.
## Every declared param is required; undeclared params reject the event (no silent passthrough).
static func validate(event_name: String, params: Dictionary) -> Dictionary:
	if not EVENTS.has(event_name):
		return {"ok": false, "params": {}, "reason": "unknown_event"}
	var spec: Dictionary = EVENTS[event_name]
	for k in params:
		if not spec.has(str(k)):
			return {"ok": false, "params": {}, "reason": "unknown_param:" + str(k)}
	var out := {}
	for k in spec:
		if not params.has(k):
			return {"ok": false, "params": {}, "reason": "missing_param:" + k}
		var r := _check(spec[k], params[k])
		if not r.ok:
			return {"ok": false, "params": {}, "reason": "bad_param:" + k}
		out[k] = r.value
	return {"ok": true, "params": out, "reason": ""}

static func _check(s: Dictionary, v: Variant) -> Dictionary:
	match str(s.type):
		"bool":
			return {"ok": v is bool, "value": v}
		"int":
			if not (v is int or v is float) or (v is float and (is_nan(v) or is_inf(v))):
				return {"ok": false, "value": null}
			var n := int(v)
			var lo := int(s.get("min", -2147483648))
			var hi := int(s.get("max", 2147483647))
			if n < lo or n > hi:
				if not bool(s.get("clamp", false)):
					return {"ok": false, "value": null}
				n = clampi(n, lo, hi)
			var b := int(s.get("bucket", 0))
			if b > 1:
				n = (n / b) * b
			return {"ok": true, "value": n}
		"enum":
			return {"ok": v is String and s.values.has(v), "value": v}
		"id":
			if not (v is String) or (v as String).length() > 64:
				return {"ok": false, "value": null}
			var re := RegEx.create_from_string(str(s.pattern))
			return {"ok": re.search(v) != null, "value": v}
	return {"ok": false, "value": null}
