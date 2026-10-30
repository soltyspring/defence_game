extends RefCounted
## Consent flow state machine on top of ConsentService. Owner: 06-services. Spec: SERVICES.md §5.1.
##
##   IDLE --start()--> CHECKING --required--> FORM_REQUIRED --show_form()--> SHOWING_FORM --ok--> DONE
##                        | not_required / obtained -> DONE        | dismissed -> FORM_REQUIRED (cancelled)
##                        | offline / error / timeout -> DONE      | error / timeout -> FORM_REQUIRED (error)
##   DONE --show_privacy_options()--> SHOWING_FORM (re-open to change choices)
##   any --withdraw()--> IDLE (all purposes denied, platform reset; next start() re-checks)
##
## Rules (fail-closed):
##  - The platform flow only covers ADS purposes. Analytics consent comes from our own UI.
##  - not_required marks ads purposes `not_required` ONLY if they are still `unknown`; an
##    explicit user `denied` is never overridden.
##  - offline / error / timeout change nothing: unknown stays unknown, so ads stay blocked.
##  - dismissed form changes nothing.
##  - Late, duplicate and stray callbacks are counted and ignored.

const Result := preload("res://src/services/service_result.gd")
const Consent := preload("res://src/services/consent_service.gd")

const IDLE := "idle"
const CHECKING := "checking"
const FORM_REQUIRED := "form_required"
const SHOWING_FORM := "showing_form"
const DONE := "done"

const ADS_PURPOSES := [Consent.PURPOSE_ADS, Consent.PURPOSE_ADS_PERSONALIZED]

signal state_changed(state: String)
signal finished(code: String, requirement: String)
signal form_result(code: String)

var provider
var consent
var info_timeout_s := 10.0
var form_timeout_s := 300.0
var state := IDLE
var requirement := "unknown"
var last_code := ""
var _elapsed := 0.0
var diagnostics := {"stray": 0, "timeouts": 0}

func _init(p_provider, p_consent, config: Dictionary = {}) -> void:
	provider = p_provider
	consent = p_consent
	info_timeout_s = float(config.get("info_timeout_s", info_timeout_s))
	form_timeout_s = float(config.get("form_timeout_s", form_timeout_s))
	provider.info_updated.connect(_on_info)
	provider.form_closed.connect(_on_form)

func start() -> String:
	if not provider.is_supported():
		_set_state(DONE)
		last_code = Result.UNSUPPORTED
		finished.emit(Result.UNSUPPORTED, requirement)
		return Result.UNSUPPORTED
	if state == CHECKING or state == SHOWING_FORM:
		return Result.BUSY
	_elapsed = 0.0
	_set_state(CHECKING)
	provider.request_info_update()
	return Result.OK

func show_form() -> String:
	if state != FORM_REQUIRED:
		return Result.BUSY if state == CHECKING or state == SHOWING_FORM else Result.ERROR
	return _open_form()

## Settings "privacy options": re-open the form after the flow finished.
func show_privacy_options() -> String:
	if not provider.is_supported():
		return Result.UNSUPPORTED
	if state != DONE and state != FORM_REQUIRED:
		return Result.BUSY
	return _open_form()

func withdraw() -> void:
	consent.withdraw_all()
	provider.reset()
	requirement = "unknown"
	_set_state(IDLE)

func tick(dt: float) -> void:
	provider.poll()
	if state == CHECKING or state == SHOWING_FORM:
		_elapsed += dt
		if state == CHECKING and _elapsed >= info_timeout_s:
			diagnostics.timeouts += 1
			_done(Result.TIMEOUT)
		elif state == SHOWING_FORM and _elapsed >= form_timeout_s:
			diagnostics.timeouts += 1
			_set_state(FORM_REQUIRED if requirement == "required" else DONE)
			last_code = Result.TIMEOUT
			form_result.emit(Result.TIMEOUT)

func _open_form() -> String:
	_elapsed = 0.0
	_set_state(SHOWING_FORM)
	provider.show_form()
	return Result.OK

func _on_info(code: String, req: String) -> void:
	if state != CHECKING:
		diagnostics.stray += 1
		return
	if code != Result.OK:
		_done(Result.OFFLINE if code == Result.OFFLINE else Result.ERROR)
		return
	requirement = req
	match req:
		"required":
			_set_state(FORM_REQUIRED)
			last_code = Result.OK
		"not_required":
			for p in ADS_PURPOSES:
				if consent.get_choice(p) == Consent.UNKNOWN:
					consent.set_choice(p, Consent.NOT_REQUIRED)
			_done(Result.OK)
		"obtained":
			_done(Result.OK)
		_:
			_done(Result.ERROR)

func _on_form(code: String, choices: Dictionary) -> void:
	if state != SHOWING_FORM:
		diagnostics.stray += 1
		return
	if code == Result.OK:
		var filtered := {}
		for p in ADS_PURPOSES:
			if choices.has(p):
				filtered[p] = choices[p]
		consent.apply_external(filtered)
		last_code = Result.OK
		_done(Result.OK)
		form_result.emit(Result.OK)
		return
	last_code = Result.CANCELLED if code == Result.CANCELLED else Result.ERROR
	_set_state(FORM_REQUIRED if requirement == "required" else DONE)
	form_result.emit(last_code)

func _done(code: String) -> void:
	last_code = code
	_set_state(DONE)
	finished.emit(code, requirement)

func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)
