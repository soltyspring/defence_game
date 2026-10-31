extends Node
## Services facade node. Owner: 06-services.
## Intended as autoload `Services` registered AFTER `Save` (02 decision, request S1). As an
## autoload it binds itself to /root/Save in _ready (attach_save) and rebinds after every
## Save.load_progress(). Until registered nothing in the game uses it. Mode is always DISABLED
## by default; nothing here enables real ads, billing, consent SDKs or remote analytics.
##
## Read-only API for UI (04) / gameplay (02):
##   Services.mode                          "disabled" | "mock"
##   Services.ads.availability(pid, ctx)    -> code; Services.ads.request(pid, ctx)
##   Services.ads.offer_for(pid, situation) / request_for(pid, situation)   (reward_policy.gd)
##   Services.purchases.has_entitlement(id); purchase(pid); restore()
##   Services.analytics.track(name, params); Services.telemetry.offer_shown(pid, ctx)
##   Services.consent.check(purpose); set_choice(purpose, value)
##   Services.diagnostics() -> detached JSON-safe Dictionary (no tokens/ids)
## Signals are on the individual services (ads.finished, purchases.purchase_finished, ...).

const Factory := preload("res://src/services/services_factory.gd")
const Diag := preload("res://src/services/service_diagnostics.gd")
const Bridge := preload("res://src/services/save_bridge.gd")

var bundle := {}
var mode := "disabled"
var ads
var purchases
var analytics
var consent
var telemetry
var consent_flow
var _save: Node = null
var _events: Node = null
var _options := {}
var rebinds := 0
var _flush_t := 0.0
const FLUSH_INTERVAL_S := 60.0

func _ready() -> void:
	if not bundle.is_empty():
		return
	# Registered as autoload "Services" AFTER "Save" (02 S1): bind to the game save at once.
	var save := get_node_or_null("/root/Save")
	if name == "Services" and get_parent() == get_tree().root and save != null:
		attach_save(save, get_node_or_null("/root/Events"))
	else:
		setup({})

## Recommended 02 integration (request S2): ONE call after the Save autoload is ready:
##     Services.attach_save(Save, Events)
## Binds service state to Save.progress["services"] through save_bridge.gd and REBINDS
## automatically whenever Save.load_progress() replaced the progress Dictionary (checked every
## frame and by ensure_bound()). Mode stays "disabled" unless options say otherwise.
func attach_save(save: Node, events: Node = null, options: Dictionary = {}) -> bool:
	_save = save
	_events = events
	_options = options.duplicate()
	return _bind()

## Rebind if the save was reloaded since binding. Returns true when bound to current data.
## In-flight ad/purchase sessions of the old binding are dropped (their grants would be refused
## anyway as stale); the ledger prevents duplicates and restore recovers purchases.
func ensure_bound() -> bool:
	if _save == null:
		return false
	var st = bundle.get("store")
	if st != null and st.is_usable() and is_same(st.data, _save.progress.get("services")):
		return true
	rebinds += 1
	return _bind()

func _bind() -> bool:
	var st = Bridge.make_store(_save, _events)
	if st == null:
		push_warning("[Services] attach_save: object does not look like src/core/save.gd")
		return false
	var o := _options.duplicate()
	o["store"] = st
	setup(o)
	# Launch reconciliation: deliver purchases completed while the app was not running.
	# In disabled mode this returns "disabled" and does nothing.
	purchases.reconcile()
	return true

## Low-level: setup({"store": <ServiceStore>, ...}). Prefer attach_save().
func setup(options: Dictionary) -> void:
	bundle = Factory.create(options)
	mode = bundle.mode
	ads = bundle.ads
	purchases = bundle.purchases
	analytics = bundle.analytics
	consent = bundle.consent
	telemetry = bundle.telemetry
	consent_flow = bundle.consent_flow
	for w in bundle.warnings:
		print_verbose("[Services] " + w)

func diagnostics() -> Dictionary:
	return Diag.snapshot(bundle)

func _process(delta: float) -> void:
	if bundle.is_empty():
		return
	if _save != null:
		ensure_bound()
	ads.tick(delta)
	purchases.tick(delta)
	analytics.tick(delta)
	consent_flow.tick(delta)
	_flush_t += delta
	if _flush_t >= FLUSH_INTERVAL_S:
		_flush_t = 0.0
		analytics.flush()

func _notification(what: int) -> void:
	if bundle.is_empty():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		analytics.flush()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		purchases.reconcile()   # Play: re-query purchases on resume (pending -> purchased while away)
