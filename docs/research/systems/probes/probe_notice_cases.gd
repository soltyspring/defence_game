extends SceneTree
## Research probe (10-research-systems, v0.33): the content-migration NOTICE on REAL process boots, complementing 04's
## tests/integration/test_migration_notice.gd (which emulates data changes in memory and "relaunches" in-process).
## Here every step is a separate Godot process started by docs/research/systems/probes/isolated_godot.ps1 (private
## APPDATA) on a snapshot whose data/ files really differ. The Save autoload migrates during its own _ready(),
## before App mounts the menu, exactly as on a player's first boot of an update. Uses the default user://save.json
## of the private user dir. Visual appearance is NOT judged (headless); only node/file state.
## Modes (user args after --):
##   --mode=make         fresh save, buy up_melee_basic to L5 with real buy_upgrade (paid records)
##   --mode=legacy       write a save with melee L5 but NO upgrade_paid and NO content_snapshot (refund-0 case)
##   --mode=menu         mount the real main scene, report the menu notice; quit WITHOUT closing it
##   --mode=pause        like menu, then App._notification(APPLICATION_PAUSED) (App saves), report; no close
##   --mode=ack          like menu, then tap the notice's close button (UI ack path), report
## Output: "PROBE10_NOTICE <json>". Exit 0.

const UP := "up_melee_basic"
var emitted: Array = []
var acks := 0

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): print("PROBE10_NOTICE {\"watchdog\":true}"); quit(0))
	_run.call_deferred()

func _mode() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--mode="): return str(a).substr(7)
	return "menu"

func _payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var env = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (env is Dictionary) or not (env.get("payload") is String): return {"unreadable": true}
	var p = JSON.parse_string(env.payload)
	return p if p is Dictionary else {"unreadable": true}

func _env_txt(p: Dictionary) -> String:
	var txt := JSON.stringify(p, "", true)
	return JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt}, "", true)

func _menu(app) -> Control:
	if app == null or app.get("ui_layer") == null: return null
	for c in app.ui_layer.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path == "res://src/ui/main_menu.gd" and not c.is_queued_for_deletion():
			return c
	return null

func _run() -> void:
	var save = root.get_node("Save")
	var app = root.get_node_or_null("App")
	var events = root.get_node_or_null("Events")
	var content = root.get_node("Content")
	if events:
		if events.has_signal("content_migrated"): events.content_migrated.connect(func(info): emitted.append(info))
		if events.has_signal("cmd_ack_content_migrated"): events.cmd_ack_content_migrated.connect(func(): acks += 1)
	var mode := _mode()
	var path := str(save.path)
	var out := {"mode": mode, "user_data_dir": OS.get_user_data_dir(), "data_content_version": str(content.content_version),
		"boot": {"migration_log": save.get("migration_log"), "recovery_source": str(save.recovery_source),
			"notice_after_boot": save.call("migration_notice") if save.has_method("migration_notice") else "no_api"}}
	var max_l := 1
	for u in content.meta.get("upgrades", []):
		if str(u.id) == UP: max_l = int(u.max_level)
	out["meta_max_level"] = max_l
	var codes := []
	if mode == "make":
		save.progress = load("res://src/core/save.gd").fresh()
		save.progress.coins = 2000
		save.progress.unlocked_round = 6
		save.progress.stars = {"r01": 3, "r02": 3, "r03": 2, "r04": 3, "r05": 1}
		save.save_progress()
		for lv in range(2, 6): codes.append("L%d %s" % [lv, save.buy_upgrade(UP, lv)])
	elif mode == "legacy":
		var p: Dictionary = load("res://src/core/save.gd").fresh()
		p.coins = 1000
		p.unlocked_round = 6
		p.stars = {"r01": 3, "r02": 3}
		p.upgrades = {UP: 5}
		p.erase("upgrade_paid")
		p["content_version"] = "c1-legacy0000"   # an old version with NO snapshot and NO paid records
		var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(_env_txt(p)); f.close()
		codes.append("legacy_written")
	else:
		root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
		for i in 5: await process_frame
		var m = _menu(app)
		out["menu_mounted"] = m != null
		if m != null:
			out["shown_before_action"] = {"visible": bool(m.notice_dialog.visible), "text": str(m.notice_dialog.text)}
			if mode == "pause" and app:
				app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
				for i in 2: await process_frame
				codes.append("paused")
			elif mode == "ack":
				m.notice_dialog.btn_close.tapped.emit()
				for i in 2: await process_frame
				codes.append("closed")
			out["shown_after_action"] = {"visible": bool(m.notice_dialog.visible), "text": str(m.notice_dialog.text),
				"menu_acks": int(m.get("migration_acks"))}
	out["codes"] = codes
	out["content_migrated_emitted"] = emitted
	out["ack_signals"] = acks
	var pl := _payload(path)
	out["file"] = {"rev": pl.get("revision", null), "coins": pl.get("coins", null),
		"melee": (pl.get("upgrades", {}) as Dictionary).get(UP, null) if pl.get("upgrades") is Dictionary else null,
		"content_version": pl.get("content_version", null), "migration_notice": pl.get("migration_notice", null),
		"has_paid": pl.has("upgrade_paid"), "sha12": FileAccess.get_sha256(path).substr(0, 12) if FileAccess.file_exists(path) else ""}
	var pre := []
	var d := DirAccess.open(path.get_base_dir())
	if d:
		for n in d.get_files():
			if str(n).begins_with("save.pre-"): pre.append("%s:%s" % [n, FileAccess.get_sha256(path.get_base_dir().path_join(n)).substr(0, 12)])
	out["pre_backups"] = pre
	print("PROBE10_NOTICE ", JSON.stringify(out))
	quit(0)
