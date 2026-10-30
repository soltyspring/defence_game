extends RefCounted
## Shared result codes for every service boundary (ads, billing, consent, analytics).
## Owner: 06-services. Contract: docs/services/SERVICES.md §2.
## Codes are stable strings so they can cross UI/analytics/log boundaries without enum drift.

const OK := "ok"
const DISABLED := "disabled"                       # feature switched off by config (default until 01 decides)
const UNSUPPORTED := "unsupported"                 # no adapter for this platform/build
const UNKNOWN_ID := "unknown_id"                   # placement/product not in approved catalog
const CONSENT_REQUIRED := "consent_required"       # consent unknown/denied for this purpose
const OFFLINE := "offline"
const TIMEOUT := "timeout"
const CANCELLED := "cancelled"                     # user closed ad early / cancelled purchase sheet
const NO_FILL := "no_fill"
const BUSY := "busy"                               # another flow is active
const CAP_REACHED := "cap_reached"                 # daily cap for placement
const ALREADY_GRANTED := "already_granted"         # reward for this context already given
const ALREADY_OWNED := "already_owned"
const PENDING := "pending"                         # purchase awaiting payment (e.g. cash/slow card)
const INVALID_RECEIPT := "invalid_receipt"
const VERIFICATION_UNAVAILABLE := "verification_unavailable"  # no trusted verifier: NEVER grant
const REVOKED := "revoked"                         # refunded/cancelled by store
const GRANT_FAILED := "grant_failed"               # game-side grant/persist failed; nothing recorded
const ERROR := "error"

static func make(code: String, data: Dictionary = {}) -> Dictionary:
	var d := data.duplicate()
	d["code"] = code
	return d

static func is_ok(r: Dictionary) -> bool:
	return str(r.get("code", "")) == OK
