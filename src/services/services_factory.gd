extends RefCounted
## Builds the service bundle for a mode. Owner: 06-services.
## options:
##   mode: "disabled" (default) | "mock" | "production"
##   allow_mock: bool (required for mock; ignored in release builds)
##   meta: Dictionary (default: data/meta.json)
##   overrides: {"ads": {...}, "iap": {...}, "analytics": {...}} merged over meta config (tests)
##   store, clock, network: injected boundaries (defaults: memory store, system clock, unknown net)
##   debug_build: bool override for tests (default OS.is_debug_build())
## Returns {"mode", "requested_mode", "warnings", "consent", "ads", "purchases", "analytics",
##          "telemetry", "consent_provider", "consent_flow", "ad_provider", "billing", "verifier", "sink", "store"}.

const Config := preload("res://src/services/service_config.gd")
const Store := preload("res://src/services/service_store.gd")
const Clock := preload("res://src/services/service_clock.gd")
const Network := preload("res://src/services/network_probe.gd")
const ConsentS := preload("res://src/services/consent_service.gd")
const AdsS := preload("res://src/services/ads/rewarded_ad_service.gd")
const DisabledAds := preload("res://src/services/ads/disabled_ad_provider.gd")
const MockAds := preload("res://src/services/ads/mock_ad_provider.gd")
const PurchaseS := preload("res://src/services/billing/purchase_service.gd")
const DisabledBilling := preload("res://src/services/billing/disabled_billing_provider.gd")
const MockBilling := preload("res://src/services/billing/mock_billing_provider.gd")
const UnavailableVerifier := preload("res://src/services/billing/unavailable_receipt_verifier.gd")
const MockVerifier := preload("res://src/services/billing/mock_receipt_verifier.gd")
const AnalyticsS := preload("res://src/services/analytics/analytics_service.gd")
const NullSink := preload("res://src/services/analytics/analytics_sink.gd")
const MemorySink := preload("res://src/services/analytics/memory_sink.gd")
const Telemetry := preload("res://src/services/analytics/service_telemetry.gd")
const ConsentFlow := preload("res://src/services/consent/consent_flow.gd")
const DisabledConsent := preload("res://src/services/consent/disabled_consent_provider.gd")
const MockConsent := preload("res://src/services/consent/mock_consent_provider.gd")

const PRIVACY_POLICY_VERSION := 1

static func create(options: Dictionary = {}) -> Dictionary:
	var requested := str(options.get("mode", Config.MODE_DISABLED))
	var debug_build := bool(options.get("debug_build", OS.is_debug_build()))
	var warnings: Array[String] = []
	var mode := Config.MODE_DISABLED
	match requested:
		Config.MODE_MOCK:
			if debug_build and bool(options.get("allow_mock", false)):
				mode = Config.MODE_MOCK
			else:
				warnings.append("mock_refused: mock adapters need a debug build and allow_mock=true")
		Config.MODE_PRODUCTION:
			warnings.append("production_unavailable: no approved catalog/placements, no SDK plugin, no verification server")
		Config.MODE_DISABLED:
			pass
		_:
			warnings.append("unknown_mode:" + requested)

	var store = options.get("store", null)
	if store == null:
		store = Store.new()
		warnings.append("store_memory_only: service state not persisted until 02 integrates Save")
	var clock = options.get("clock", null)
	if clock == null:
		clock = Clock.new()
	var network = options.get("network", null)
	if network == null:
		network = Network.new()

	var meta: Dictionary = options.get("meta", Config.load_meta())
	var cfg := Config.from_meta(meta)
	var ov: Dictionary = options.get("overrides", {})
	var ads_cfg: Dictionary = cfg.ads
	var iap_cfg: Dictionary = cfg.iap
	var an_cfg := {"enabled": false}
	if mode == Config.MODE_MOCK:
		ads_cfg.merge(ov.get("ads", {}), true)
		iap_cfg.merge(ov.get("iap", {}), true)
		an_cfg.merge(ov.get("analytics", {}), true)
	else:
		ads_cfg.enabled = false
		iap_cfg.enabled = false

	var consent = ConsentS.new(store, PRIVACY_POLICY_VERSION)
	var ad_provider = MockAds.new() if mode == Config.MODE_MOCK else DisabledAds.new()
	var billing = MockBilling.new() if mode == Config.MODE_MOCK else DisabledBilling.new()
	var verifier = MockVerifier.new() if mode == Config.MODE_MOCK else UnavailableVerifier.new()
	var sink = MemorySink.new() if mode == Config.MODE_MOCK else NullSink.new()
	var ads = AdsS.new(ad_provider, consent, store, clock, network, ads_cfg)
	var purchases = PurchaseS.new(billing, verifier, store, clock, network, iap_cfg)
	var analytics = AnalyticsS.new(sink, consent, an_cfg)
	var consent_provider = MockConsent.new() if mode == Config.MODE_MOCK else DisabledConsent.new()
	return {
		"mode": mode, "requested_mode": requested, "warnings": warnings,
		"store": store, "consent": consent,
		"ad_provider": ad_provider, "billing": billing, "verifier": verifier, "sink": sink,
		"ads": ads, "purchases": purchases, "analytics": analytics,
		"telemetry": Telemetry.new(analytics, ads, purchases),
		"consent_provider": consent_provider,
		"consent_flow": ConsentFlow.new(consent_provider, consent),
	}
