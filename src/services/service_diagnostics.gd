extends RefCounted
## Read-only diagnostics for debug overlays (04), QA reports (07) and bug reports.
## Owner: 06-services. Returns a JSON-safe deep copy; mutating it never affects services.
## Excludes purchase tokens, ledger keys, context ids and the analytics session id, so the
## snapshot can be pasted into a bug report. `live` flags are derived from adapter kinds and
## are false unless a production adapter is actually installed (none exists today).

const SCHEMA := 1

static func snapshot(bundle: Dictionary) -> Dictionary:
	if bundle.is_empty():
		return {"schema": SCHEMA, "ready": false}
	var ads = bundle.get("ads")
	var ps = bundle.get("purchases")
	var an = bundle.get("analytics")
	var consent = bundle.get("consent")
	var store = bundle.get("store")
	var out := {
		"schema": SCHEMA, "ready": true,
		"mode": str(bundle.get("mode", "")), "requested_mode": str(bundle.get("requested_mode", "")),
		"warnings": Array(bundle.get("warnings", [])).duplicate(),
		"adapters": {
			"ads": _kind(bundle.get("ad_provider")), "billing": _kind(bundle.get("billing")),
			"verifier": _kind(bundle.get("verifier")), "analytics_sink": _kind(bundle.get("sink")),
		},
		"live": {
			"real_ads": _kind(bundle.get("ad_provider")) == "production",
			"real_billing": _kind(bundle.get("billing")) == "production",
			"trusted_verifier": _kind(bundle.get("verifier")) == "production",
			"remote_analytics": bundle.get("sink") != null and bundle.sink.is_remote(),
		},
		"store": {"persistent": store != null and store.is_persistent(),
			"commits": store.commits if store != null else 0,
			"failed_commits": store.failed_commits if store != null else 0},
	}
	if consent != null:
		out["consent"] = {"audience": consent.audience, "policy_version": consent.policy_version,
			"ads": consent.get_choice("ads"), "ads_personalized": consent.get_choice("ads_personalized"),
			"analytics": consent.get_choice("analytics")}
	if ads != null:
		var today := {}
		for pid in ads.placements:
			today[pid] = {"granted_today": ads._granted_today(pid), "daily_cap": int(ads.placements[pid].get("daily_cap", 0))}
		out["ads"] = {"enabled": ads.enabled, "state": ads.state, "placements": today,
			"ledger_size": ads._ledger().size(), "counters": ads.diagnostics.duplicate(true)}
	if ps != null:
		var by_state := {}
		for k in ps._ledger():
			var e = ps._ledger()[k]
			var s := str(e.get("state", "?")) if e is Dictionary else "corrupt"
			by_state[s] = int(by_state.get(s, 0)) + 1
		out["purchases"] = {"enabled": ps.enabled, "state": ps.state, "catalog_size": ps.catalog.size(),
			"entitlements": ps.entitlements(), "ledger_by_state": by_state,
			"verifying": ps._verifying.size(), "counters": ps.diagnostics.duplicate(true)}
	if an != null:
		out["analytics"] = {"enabled": an.enabled, "queued": an.queued(), "stats": an.stats.duplicate(true),
			"last_reject_reason": an.last_reject_reason}
	var tel = bundle.get("telemetry")
	if tel != null:
		out["telemetry"] = tel.stats.duplicate(true)
	# Deep copy of primitives/arrays/dicts only: detached and JSON-serialisable (tests check both).
	return out.duplicate(true)

static func _kind(o: Variant) -> String:
	if o == null or not (o is Object) or not o.has_method("kind"):
		return "none"
	return str(o.kind())
