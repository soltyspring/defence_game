extends SceneTree
## Research probe (10-research-systems, v0.34): does a content update re-lock rounds the player already cleared?
## Run ONLY through docs/research/systems/probes/isolated_godot.ps1 (private APPDATA). Uses the default user://save.json.
## The Save autoload migrates in its own _ready() (save.gd _apply_content_migration step 5, id-based unlocks) before
## this script runs, exactly like a player's first boot of an update; this script only reports the result.
## Modes (user args after --):
##   --mode=make_mid        fresh save; win r01..r05 through the REAL Save.record_result (stars 3,3,2,3,1); buy
##                          up_melee_basic L2 and up_fast L2 (fast unlocks at round 4) -> unlocked_round 6
##   --mode=make_complete   fresh save; win r01..r10 (stars 2 each) -> unlocked_round 11 (= rounds + 1)
##   --mode=make_incons     fresh save; unlocked_round 6 but stars only r01, r02 (the v0.33 L1 shape), saved normally
##   --mode=make_new        fresh save written before any clear (unlocked_round 1, has content_version) (v0.35)
##   --mode=report          only report (the boot already migrated)
## Output: "PROBE10_RELOCK <json>". Exit 0. Visual appearance is not judged.

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): print("PROBE10_RELOCK {\"watchdog\":true}"); quit(0))
	_run.call_deferred()

func _mode() -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--mode="): return str(a).substr(7)
	return "report"

func _win(save, content, rid: String, stars: int, n: int) -> bool:
	var idx: int = content.round_order.find(rid)
	return save.record_result({"round_id": rid, "won": true, "stars": stars, "time": 100.0, "coins": 50,
		"battle_uid": "p10-%s-%d" % [rid, n]}, idx)

func _run() -> void:
	var save = root.get_node("Save")
	var content = root.get_node("Content")
	var mode := _mode()
	var out := {"mode": mode, "data_content_version": str(content.content_version), "order": Array(content.round_order),
		"boot": {"migration_log": save.get("migration_log"), "recovery_source": str(save.recovery_source),
			"last_migration": save.get("last_migration")}}
	var codes := []
	if mode.begins_with("make"):
		save.progress = load("res://src/core/save.gd").fresh()
		save.progress.coins = 3000
		save.save_progress()
		if mode == "make_mid":
			var st := [3, 3, 2, 3, 1]
			for i in 5: codes.append("%s:%s" % [content.round_order[i], _win(save, content, str(content.round_order[i]), st[i], i)])
			codes.append("melee L2 " + str(save.buy_upgrade("up_melee_basic", 2)))
			codes.append("fast L2 " + str(save.buy_upgrade("up_fast", 2)))
		elif mode == "make_complete":
			for i in content.round_order.size(): codes.append("%s:%s" % [content.round_order[i], _win(save, content, str(content.round_order[i]), 2, i)])
		elif mode == "make_incons":
			save.progress.unlocked_round = 6
			save.progress.stars = {"r01": 3, "r02": 3}
			codes.append("saved:%s" % save.save_progress())
		elif mode == "make_new":   # v0.35: a save written on the old build before any clear (unlocked 1)
			codes.append("saved:%s" % save.save_progress())
	out["codes"] = codes
	var mig = content.get("migrations")
	out["round_renames"] = (mig.get("round_renames", {}) if mig is Dictionary else {})
	var p: Dictionary = save.progress
	var order: Array = content.round_order
	var open := []
	var cleared_locked := []
	var uncleared_open := []
	for i in order.size():
		var rid := str(order[i])
		var un: bool = save.is_unlocked(i)
		if un: open.append(rid)
		if p.stars.has(rid) and not un: cleared_locked.append(rid)
		if un and not p.stars.has(rid): uncleared_open.append(rid)
	var orphan := []
	for k in p.stars:
		if not order.has(str(k)): orphan.append(str(k))
	var locked_ups := []
	for u in content.meta.get("upgrades", []):
		if u is Dictionary and bool(save.call("_upgrade_locked", u)): locked_ups.append("%s(L%d)" % [str(u.id), save.upgrade_level(str(u.id))])
	out["state"] = {"unlocked_round": int(p.unlocked_round), "stars": p.stars, "open": open, "cleared_but_locked": cleared_locked,
		"uncleared_open": uncleared_open, "orphan_stars": orphan, "locked_upgrades": locked_ups,
		"upgrades": p.get("upgrades", {}), "coins": int(p.coins), "notice": save.call("migration_notice")}
	var path := str(save.path)
	var f := {}
	if FileAccess.file_exists(path):
		var env = JSON.parse_string(FileAccess.get_file_as_string(path))
		var pl = JSON.parse_string(env.payload) if env is Dictionary and env.get("payload") is String else null
		if pl is Dictionary:
			f = {"rev": pl.get("revision"), "unlocked_round": pl.get("unlocked_round"), "content_version": pl.get("content_version"),
				"migration_notice": pl.get("migration_notice", null), "sha12": FileAccess.get_sha256(path).substr(0, 12)}
	out["file"] = f
	var pre := []
	var d := DirAccess.open(path.get_base_dir())
	if d:
		for n in d.get_files():
			if str(n).begins_with("save.pre-"): pre.append("%s:%s" % [n, FileAccess.get_sha256(path.get_base_dir().path_join(n)).substr(0, 12)])
	out["pre_backups"] = pre
	print("PROBE10_RELOCK ", JSON.stringify(out))
	quit(0)
