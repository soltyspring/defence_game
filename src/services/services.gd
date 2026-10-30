extends Node
## Services facade node. Owner: 06-services.
## Intended as autoload `Services` (registration is 02's decision, see
## coordination/requests/06-services-to-02-engine.md). Until registered nothing in the game
## uses it, so it has no runtime effect. Default mode is DISABLED.
##
## Read-only API for UI (04) / gameplay (02):
##   Services.mode                          "disabled" | "mock"
##   Services.ads.availability(pid, ctx)    -> code; Services.ads.request(pid, ctx)
##   Services.purchases.has_entitlement(id); purchase(pid); restore()
##   Services.analytics.track(name, params)
##   Services.consent.check(purpose); set_choice(purpose, value)
## Signals are on the individual services (ads.finished, purchases.purchase_finished, ...).

const Factory := preload("res://src/services/services_factory.gd")

var bundle := {}
var mode := "disabled"
var ads
var purchases
var analytics
var consent
var _flush_t := 0.0
const FLUSH_INTERVAL_S := 60.0

func _ready() -> void:
	if bundle.is_empty():
		setup({})

## 02 calls setup({"store": <ServiceStore over Save.progress.services>, ...}) after Save loads.
func setup(options: Dictionary) -> void:
	bundle = Factory.create(options)
	mode = bundle.mode
	ads = bundle.ads
	purchases = bundle.purchases
	analytics = bundle.analytics
	consent = bundle.consent
	for w in bundle.warnings:
		print_verbose("[Services] " + w)

func _process(delta: float) -> void:
	if bundle.is_empty():
		return
	ads.tick(delta)
	purchases.tick(delta)
	analytics.tick(delta)
	_flush_t += delta
	if _flush_t >= FLUSH_INTERVAL_S:
		_flush_t = 0.0
		analytics.flush()

func _notification(what: int) -> void:
	if bundle.is_empty():
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		analytics.flush()
