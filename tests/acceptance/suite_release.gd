extends RefCounted
## Release-readiness probes that can be verified on desktop: project/mobile settings, audio presence,
## monetization kept disabled (D9), export presets. Device-only items are recorded NOT_TESTED.
## Owner: 07-qa.

const Q := preload("res://tests/acceptance/qa_lib.gd")

func _grep(root: String, needles: Array, hits: Array) -> void:
	var d := DirAccess.open(root)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".cfg"):
			var t := FileAccess.get_file_as_string(root + "/" + f)
			for n in needles:
				if t.findn(n) >= 0: hits.append("%s/%s: %s" % [root, f, n])
	for sub in d.get_directories():
		if not sub.begins_with("."): _grep(root + "/" + sub, needles, hits)

func run(q, _tree) -> void:
	q.current_suite = "release"
	var ps := {
		"display/window/handheld/orientation": [4, "sensor_landscape"],
		"application/config/quit_on_go_back": [false, "back handled in-app"],
		"rendering/renderer/rendering_method.mobile": ["gl_compatibility", "Compatibility renderer"],
		"input_devices/pointing/emulate_touch_from_mouse": [true, "desktop touch emulation"],
		"display/window/stretch/mode": ["canvas_items", "stretch"],
		"display/window/stretch/aspect": ["expand", "wide phones"],
	}
	var bad := []
	for k in ps:
		var v = ProjectSettings.get_setting(k)
		if v != ps[k][0]: bad.append("%s=%s (want %s)" % [k, v, ps[k][0]])
	q.check("REL-01", "mobile project settings match ENGINE.md §4", bad.is_empty(), "; ".join(bad))
	# audio (05-audio) — assets/manifest on disk, then runtime wiring
	var am = Q.read_json("res://assets/audio/audio_manifest.json")
	if not (am is Dictionary):
		q.record("AUD-01", Q.NOT_IMPL, "audio manifest + assets (05-audio)", "assets/audio/audio_manifest.json absent")
	else:
		var missing := []
		var n := 0
		for cue in am.get("cues", {}):
			for f in am.cues[cue].get("files", []):
				n += 1
				if not FileAccess.file_exists(str(f)): missing.append(str(f))
		for mk in am.get("music", {}):
			var mf = am.music[mk]
			var mp := str(mf.get("file", mf.get("path", ""))) if mf is Dictionary else str(mf)
			if mp != "":
				n += 1
				if not FileAccess.file_exists(mp): missing.append(mp)
		q.check("AUD-01", "audio manifest cue/music files exist (%d refs)" % n, n > 0 and missing.is_empty(), "missing: %s" % [missing])
	var audio_autoload := ProjectSettings.has_setting("autoload/Audio")
	if not audio_autoload:
		q.record("AUD-02", Q.NOT_IMPL, "audio manager wired into the game (autoload Audio + event bridge)",
			"src/audio/audio_manager.gd exists=%s but no autoload/Audio in project.godot: game is silent; wiring requested from 02" % FileAccess.file_exists("res://src/audio/audio_manager.gd"))
	else:
		q.record("AUD-02", Q.PASS, "audio manager registered as autoload Audio")
	q.record("AUD-03", Q.NOT_TESTED, "cues play on gameplay events and honour sfx/music settings + pause", "verified after AUD-02 is wired (cue_played signal hook exists)")
	# monetization disabled (D9)
	var meta = Q.read_json("res://data/meta.json")
	var enabled := []
	if meta is Dictionary:
		for c in meta.get("currencies", []):
			if c is Dictionary and bool(c.get("enabled", true)) and str(c.get("id", "")).findn("gem") >= 0: enabled.append("currency " + str(c.id))
		var rh: Dictionary = meta.get("retention_hooks", {})
		for k in rh:
			if rh[k] is Dictionary and bool(rh[k].get("enabled", false)) and k == "rewarded_ads": enabled.append("rewarded_ads")
		var iap: Dictionary = meta.get("iap_catalog", {})
		if bool(iap.get("enabled", false)): enabled.append("iap_catalog")
	q.check("MON-01", "monetization disabled in data (premium currency, rewarded ads, real IAP) per D9", meta is Dictionary and enabled.is_empty(), "enabled: %s" % [enabled])
	var hits := []
	_grep("res://src", ["GodotGooglePlayBilling", "AdMob", "Engine.get_singleton(", "Engine.has_singleton("], hits)
	_grep("res://scenes", ["GodotGooglePlayBilling", "AdMob"], hits)
	q.check("MON-02", "no live ad/billing SDK (Android plugin singleton) calls in runtime code", hits.is_empty(), "; ".join(hits))
	if FileAccess.file_exists("res://src/services/services.gd"):
		var svc = load("res://src/services/services.gd").new()
		_tree.root.add_child(svc)
		var mode := str(svc.get("mode"))
		var registered := ProjectSettings.has_setting("autoload/Services")
		svc.queue_free()
		q.check("MON-03", "06-services facade defaults to mode=disabled", mode == "disabled", "mode=%s" % mode, {"autoload_registered": registered})
		if not registered:
			q.record("MON-04", Q.NOT_IMPL, "services wired into game/UI (autoload Services)", "not registered in project.godot; no ad/IAP UI reachable (consistent with D9)")
	else:
		q.record("MON-03", Q.NOT_IMPL, "06-services mock ad/IAP adapters with disabled/failure states", "src/services/ absent")
	# platform
	if FileAccess.file_exists("res://export_presets.cfg"):
		var t := FileAccess.get_file_as_string("res://export_presets.cfg")
		var perm_bad := []
		for p in ["com.android.vending.BILLING", "AD_ID", "ACCESS_FINE_LOCATION", "READ_CONTACTS"]:
			if t.find(p) >= 0: perm_bad.append(p)
		q.check("PLAT-01", "Android export preset exists without billing/ad/location permissions", t.find("platform=\"Android\"") >= 0 and perm_bad.is_empty(), "android=%s perms=%s" % [t.find("platform=\"Android\"") >= 0, perm_bad])
		q.check("PLAT-02", "no signing secrets in export_presets.cfg", t.find("keystore/release_password=\"\"") >= 0 or t.find("release_password") < 0, "release_password appears non-empty")
	else:
		q.record("PLAT-01", Q.NOT_IMPL, "Android export preset (export_presets.cfg)", "file absent; no APK can be built")
	q.record("PLAT-03", Q.NOT_TESTED, "on-device Android: install, touch, lifecycle, safe area, perf, thermals", "desktop headless run only; this report is NOT Android release certification")
