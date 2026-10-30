extends RefCounted
## Consent gate for ads and analytics. Owner: 06-services. Spec: docs/services/SERVICES.md §5.
## Default is privacy-preserving: every purpose starts UNKNOWN and UNKNOWN blocks the purpose.
## Choices come from (a) a 04-owned consent UI calling set_choice(), or (b) a future platform
## consent adapter (e.g. Google UMP for EEA/UK) calling apply_external(). Neither exists yet.
## Audience (child-directed or not) is a user decision (ECONOMY.md Q5); until answered it is
## UNKNOWN and personalised ads are always denied.

const Result := preload("res://src/services/service_result.gd")

const UNKNOWN := "unknown"
const GRANTED := "granted"
const DENIED := "denied"
const NOT_REQUIRED := "not_required"   # only set by a regional consent adapter, never by default

const PURPOSE_ADS := "ads"                       # serve any ad (non-personalised)
const PURPOSE_ADS_PERSONALIZED := "ads_personalized"
const PURPOSE_ANALYTICS := "analytics"
const PURPOSES := [PURPOSE_ADS, PURPOSE_ADS_PERSONALIZED, PURPOSE_ANALYTICS]

const AUDIENCE_UNKNOWN := "unknown"
const AUDIENCE_GENERAL := "general"
const AUDIENCE_CHILD := "child"

signal consent_changed(purpose: String, value: String)

var store
var policy_version: int
var audience := AUDIENCE_UNKNOWN
var child_ads_allowed := false  # Families policy: needs certified SDK + user decision; off by default

func _init(service_store, current_policy_version: int = 1) -> void:
	store = service_store
	policy_version = current_policy_version
	var sec: Dictionary = store.section("consent")
	# A new privacy policy version invalidates earlier choices.
	if int(sec.get("policy_version", -1)) != policy_version:
		sec.clear()
		sec["policy_version"] = policy_version
		sec["choices"] = {}
	if not (sec.get("choices") is Dictionary):
		sec["choices"] = {}

func get_choice(purpose: String) -> String:
	var choices: Dictionary = store.section("consent").get("choices", {})
	return str(choices.get(purpose, UNKNOWN))

func set_choice(purpose: String, value: String) -> bool:
	if not PURPOSES.has(purpose) or not [GRANTED, DENIED, UNKNOWN, NOT_REQUIRED].has(value):
		return false
	var sec: Dictionary = store.section("consent")
	var choices: Dictionary = sec.get("choices", {})
	choices[purpose] = value
	sec["choices"] = choices
	store.commit()
	consent_changed.emit(purpose, value)
	return true

## Map a platform consent adapter result: {"ads":..., "ads_personalized":..., "analytics":...}.
## Unknown keys and invalid values are ignored.
func apply_external(result: Dictionary) -> int:
	var applied := 0
	for p in PURPOSES:
		if result.has(p) and set_choice(p, str(result[p])):
			applied += 1
	return applied

## Withdraw everything (settings "reset privacy choices").
func withdraw_all() -> void:
	for p in PURPOSES:
		set_choice(p, DENIED)

func _allowed(v: String) -> bool:
	return v == GRANTED or v == NOT_REQUIRED

## Returns Result.OK or Result.CONSENT_REQUIRED.
func check(purpose: String) -> String:
	match purpose:
		PURPOSE_ADS:
			if audience == AUDIENCE_CHILD and not child_ads_allowed:
				return Result.CONSENT_REQUIRED
			return Result.OK if _allowed(get_choice(PURPOSE_ADS)) else Result.CONSENT_REQUIRED
		PURPOSE_ADS_PERSONALIZED:
			if audience != AUDIENCE_GENERAL:
				return Result.CONSENT_REQUIRED
			if check(PURPOSE_ADS) != Result.OK:
				return Result.CONSENT_REQUIRED
			return Result.OK if _allowed(get_choice(PURPOSE_ADS_PERSONALIZED)) else Result.CONSENT_REQUIRED
		PURPOSE_ANALYTICS:
			return Result.OK if _allowed(get_choice(PURPOSE_ANALYTICS)) else Result.CONSENT_REQUIRED
	return Result.CONSENT_REQUIRED

## Ad request flag a production adapter must pass to the SDK (non-personalised when false).
func personalized_ads_allowed() -> bool:
	return check(PURPOSE_ADS_PERSONALIZED) == Result.OK
