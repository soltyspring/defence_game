extends RefCounted
## Release configuration boundary for services. Owner: 06-services. Spec: SERVICES.md §6.
## Reads (never writes) 01-owned data/meta.json and maps it to service configs.
##
## Modes:
##   disabled    default for every build. All features off, disabled adapters.
##   mock        debug builds only (OS.is_debug_build()) AND explicit opt-in. Mock adapters,
##               mock verifier. Features still follow 01 data flags (currently all false).
##   production  requested but NOT implemented: no approved products, no SDKs, no server.
##               Falls back to disabled and reports why. Never silently enables mocks.

const MODE_DISABLED := "disabled"
const MODE_MOCK := "mock"
const MODE_PRODUCTION := "production"

## data/meta.json -> {"ads": {...}, "iap": {...}}
static func from_meta(meta: Dictionary) -> Dictionary:
	var ads := {"enabled": false, "placements": {}}
	var hooks: Dictionary = meta.get("retention_hooks", {}) if meta.get("retention_hooks") is Dictionary else {}
	var ra: Dictionary = hooks.get("rewarded_ads", {}) if hooks.get("rewarded_ads") is Dictionary else {}
	ads.enabled = bool(ra.get("enabled", false))
	for p in ra.get("placements", []):
		if p is Dictionary and str(p.get("id", "")) != "":
			ads.placements[str(p.id)] = {"daily_cap": maxi(0, int(p.get("daily_cap", 0))),
				"reward": {"effect": str(p.get("effect", "")), "where": str(p.get("where", ""))}}
	var iap := {"enabled": false, "catalog": {}}
	var cat: Dictionary = meta.get("iap_catalog", {}) if meta.get("iap_catalog") is Dictionary else {}
	iap.enabled = bool(cat.get("enabled", false))
	for p in cat.get("products", []):
		if not (p is Dictionary) or str(p.get("id", "")) == "":
			continue
		var t := str(p.get("type", ""))
		if t != "non_consumable" and t != "consumable":
			continue   # subscriptions are out of scope until 01 asks for them
		iap.catalog[str(p.id)] = {"type": t, "entitlement": str(p.get("entitlement", "")),
			"max_quantity": maxi(1, int(p.get("max_quantity", 1))),
			"grant": p.get("grant", {}) if p.get("grant") is Dictionary else {}}
	if iap.catalog.is_empty():
		iap.enabled = false
	if ads.placements.is_empty():
		ads.enabled = false
	return {"ads": ads, "iap": iap}

static func load_meta(path: String = "res://data/meta.json") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return {}
	return j.data
