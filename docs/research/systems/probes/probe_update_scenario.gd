extends SceneTree
## Research probe (10-research-systems): the R5 "update" scenario on a REAL boot (no in-memory data emulation).
## Run it only through docs/research/systems/probes/isolated_godot.ps1 (private APPDATA), once per step, against
## snapshot copies that hold v1 or v2 data. The Save autoload does its own boot load/migration BEFORE this script
## runs, exactly as for a player who installs an update.
## Modes (user args after --):
##   --mode=make     v1: build a progressed save with real Save.buy_upgrade calls
##   --mode=inspect  report the state after boot; writes nothing
##   --mode=touch    one ordinary save (Save.set_setting), then report (shows the .bak rotation)
##   --mode=rebuy    buy melee/ranged back up to the make levels with the coins the player now has, then report
## Output: "PROBE10_UPDATE <json>". Exit 0.

const MAKE_LEVELS := {"up_melee_basic": 5, "up_ranged_basic": 4, "up_worker": 4}

var toasts: Array = []

func _initialize() -> void:
	var ev = root.get_node_or_null("Events")
	if ev: ev.toast.connect(func(k, a): toasts.append({"key": str(k), "args": a}))
	create_timer(60.0).timeout.connect(func(): print("PROBE10_UPDATE {\"watchdog\":true}"); quit(0))
	_run.call_deferred()

func _mode() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--mode="): return str(a).substr(7)
	return "inspect"

func _payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var env = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (env is Dictionary) or not env.has("payload"): return {"unreadable": true}
	var p = JSON.parse_string(str(env.payload))
	if not (p is Dictionary): return {"unreadable": true}
	return {"coins": int(p.get("coins", -1)), "upgrades": p.get("upgrades", {}), "content_version": str(p.get("content_version", "")),
		"revision": int(p.get("revision", -1)), "migrations_applied": p.get("migrations_applied", [])}

func _state(save) -> Dictionary:
	var ups := {}
	for k in MAKE_LEVELS: ups[k] = int(save.progress.get("upgrades", {}).get(k, 1))
	return {"coins": int(save.progress.coins), "levels": ups, "content_version": str(save.progress.get("content_version", "")),
		"migrations_applied": save.progress.get("migrations_applied", []), "revision": int(save.progress.get("revision", 0))}

func _run() -> void:
	var save = root.get_node("Save")
	var content = root.get_node("Content")
	var mode := _mode()
	var out := {"mode": mode, "user_data_dir": OS.get_user_data_dir(), "data_content_version": str(content.content_version),
		"boot": {"migration_log": save.get("migration_log"), "recovery_source": str(save.recovery_source), "read_only": bool(save.read_only)},
		"meta_max_level": {}}
	for u in content.meta.get("upgrades", []):
		if MAKE_LEVELS.has(str(u.id)): out.meta_max_level[str(u.id)] = int(u.max_level)
	var codes := []
	if mode == "make":
		save.progress = load("res://src/core/save.gd").fresh()
		save.progress.coins = 2000
		save.progress.unlocked_round = 6
		save.progress.stars = {"r01": 3, "r02": 3, "r03": 2, "r04": 3, "r05": 1}
		save.save_progress()
		for id in MAKE_LEVELS:
			for lv in range(2, int(MAKE_LEVELS[id]) + 1): codes.append("%s L%d %s" % [id, lv, save.buy_upgrade(id, lv)])
	elif mode == "touch":
		save.set_setting("sfx", 0.9)
	elif mode == "rebuy":
		for id in ["up_melee_basic", "up_ranged_basic"]:
			var cur := int(save.progress.upgrades.get(id, 1))
			for lv in range(cur + 1, int(MAKE_LEVELS[id]) + 1): codes.append("%s L%d %s" % [id, lv, save.buy_upgrade(id, lv)])
	out["codes"] = codes
	out["state"] = _state(save)
	out["disk_main"] = _payload(str(save.path))
	out["disk_bak"] = _payload(str(save.path) + ".bak")
	await process_frame
	await process_frame
	out["toasts_seen_after_boot"] = toasts
	print("PROBE10_UPDATE ", JSON.stringify(out))
	quit(0)
