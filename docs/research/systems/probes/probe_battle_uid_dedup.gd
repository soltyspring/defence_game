extends SceneTree
## Read-only research probe (10-research-systems), R3 in DATA_AND_BACKEND_ANALYSIS.md §6.4 (SV-3).
## Question: if the SAME battle result (same battle_uid) reaches the persistence path twice, are rewards/progress
## applied twice? Uses the real autoloads (App, Save, Content) like 07's acceptance runner, but redirects the Save
## autoload to user://probe10/ BEFORE anything can write, so the developer's user://save.json is never written.
## Run:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_battle_uid_dedup.gd --quit-after 900
## Prints one JSON line "PROBE10_BATTLE_UID ..." and exits 0. Evidence for 02/07, not a test suite.

const SaveS := preload("res://src/core/save.gd")
const DIR := "user://probe10"
const P_APP := DIR + "/r3_app_save.json"
const P_SAVE := DIR + "/r3_direct_save.json"

func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for p in [P_APP, P_SAVE]:
		for suf in ["", ".bak", ".tmp"]: _rm(p + suf)
	var save := root.get_node_or_null("Save")
	if save:
		save.path = P_APP          # isolate before any write
	_run.call_deferred()

func _run() -> void:
	var out := {}
	var app := root.get_node_or_null("App")
	var save := root.get_node_or_null("Save")
	var content := root.get_node_or_null("Content")
	out["autoloads"] = {"App": app != null, "Save": save != null, "Content": content != null}
	if app == null or save == null or content == null:
		print("PROBE10_BATTLE_UID ", JSON.stringify(out))
		quit(0)
		return
	out["save_path_isolated"] = save.path == P_APP
	var rid: String = str(content.round_order[0])
	var rw: Dictionary = content.get_round(rid).get("reward", {})
	out["round"] = rid
	out["reward_data"] = rw
	var raw := {"round_id": rid, "won": true, "stars": 3, "time": 80.0, "kills": 20, "coins": 12,
		"battle_uid": "probe10-dup-0001"}

	# Layer 1: Save.record_result twice with an identical result (already reward-resolved), isolated instance.
	var s = SaveS.new()
	s.path = P_SAVE
	root.add_child(s)
	s.progress = SaveS.fresh()
	var resolved := raw.duplicate()
	resolved["coins"] = 100
	s.record_result(resolved, 0)
	var l1_after1 := {"coins": int(s.progress.coins), "clears": int(s.progress.clears)}
	s.record_result(resolved, 0)
	var l1_after2 := {"coins": int(s.progress.coins), "clears": int(s.progress.clears)}
	out["L1_save_record_result"] = {"after_first": l1_after1, "after_duplicate": l1_after2,
		"duplicate_applied": l1_after2.coins != l1_after1.coins or l1_after2.clears != l1_after1.clears}

	# Layer 2: App._on_battle_finished twice with the same raw sim result (same battle_uid).
	save.progress = SaveS.fresh()
	app._on_battle_finished(raw.duplicate())
	var l2_after1 := {"coins": int(save.progress.coins), "clears": int(save.progress.clears),
		"first_clear_reported": bool(app.last_result.get("first_clear", false)), "result_coins": int(app.last_result.get("coins", 0))}
	app._on_battle_finished(raw.duplicate())
	var l2_after2 := {"coins": int(save.progress.coins), "clears": int(save.progress.clears),
		"first_clear_reported": bool(app.last_result.get("first_clear", false)), "result_coins": int(app.last_result.get("coins", 0))}
	var expected_once := int(raw.coins) + int(rw.get("first_clear_coins", rw.get("coins", 0))) + int(rw.get("three_star_bonus_coins", 0))
	out["L2_app_on_battle_finished"] = {"expected_coins_if_idempotent": expected_once, "expected_clears_if_idempotent": 1,
		"after_first": l2_after1, "after_duplicate": l2_after2,
		"duplicate_applied": l2_after2.coins != l2_after1.coins or l2_after2.clears != l2_after1.clears}
	var disk := SaveS.new()
	disk.path = P_APP
	root.add_child(disk)
	disk.load_progress()
	out["L2_persisted"] = {"coins": int(disk.progress.coins), "clears": int(disk.progress.clears),
		"has_applied_battles_key": disk.progress.has("applied_battles")}
	out["save_gd_has_fault_hook"] = "_fault" in save
	print("PROBE10_BATTLE_UID ", JSON.stringify(out))
	s.free()
	disk.free()
	quit(0)
