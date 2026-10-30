extends SceneTree
## Read-only research probe (10-research-systems). Reproduces SV-1 from DATA_AND_BACKEND_ANALYSIS.md §6.4
## against the UNMODIFIED src/core/save.gd. It uses isolated files under user://probe10/ only and never
## touches user://save.json. Run:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_save_rotation.gd --quit-after 600
## Exit code 0 = probe ran (findings printed as JSON). It is evidence for 02/07, not a test suite.

const SaveS := preload("res://src/core/save.gd")
const DIR := "user://probe10"

func _env(p: Dictionary) -> String:
	var txt := JSON.stringify(p, "", true)
	return JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt}, "", true)

func _w(path: String, s: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(s)
	f.close()

func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _mk(path: String) -> Node:
	var s = SaveS.new()
	s.path = path
	root.add_child(s)
	s.load_progress()   # explicit, independent of _ready timing
	return s

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var out := {}
	var good := {"version": 1, "unlocked_round": 6, "coins": 900, "stars": {"r01": 3}, "best_time": {}, "settings": {}}

	# A: corrupt main + good bak -> load recovers from bak; then ONE successful save.
	var pa := DIR + "/a.json"
	for suf in ["", ".bak", ".tmp"]: _rm(pa + suf)
	_w(pa, "{ corrupt")
	_w(pa + ".bak", _env(good))
	var a = _mk(pa)
	out["A_recovered"] = a.recovered
	out["A_unlocked_after_load"] = int(a.progress.unlocked_round)
	out["A_save_ok"] = a.save_progress()
	var bak_txt := FileAccess.get_file_as_string(pa + ".bak")
	out["A_bak_is_corrupt_after_save"] = bak_txt.begins_with("{ corrupt")
	# A2: a second, independent fault (main corrupted again) -> what does the next load see?
	_w(pa, "{ corrupt again")
	var a2 = _mk(pa)
	out["A2_unlocked_after_second_fault"] = int(a2.progress.unlocked_round)
	out["A2_recovered"] = a2.recovered

	# B: EMULATED crash window. Same file operations save.gd performs, stopped before the final rename:
	#    remove .bak, rename main -> .bak, (tmp written) ... process dies.
	var pb := DIR + "/b.json"
	for suf in ["", ".bak", ".tmp"]: _rm(pb + suf)
	_w(pb, "{ corrupt")
	_w(pb + ".bak", _env(good))
	var b = _mk(pb)          # recovers from .bak, like A
	out["B_recovered"] = b.recovered
	var d := DirAccess.open(DIR)
	_w(pb + ".tmp", _env(b.progress))     # tmp written and verified
	d.remove("b.json.bak")                # save.gd: remove old .bak (the GOOD one)
	d.rename("b.json", "b.json.bak")      # save.gd: main (CORRUPT) -> .bak
	# -- crash here, before tmp -> main --
	var b2 = _mk(pb)
	out["B_unlocked_after_crash_reload"] = int(b2.progress.unlocked_round)
	out["B_recovered_after_crash_reload"] = b2.recovered
	out["B_note"] = "emulation of save.gd step order; not a fault injected inside save.gd"

	print("PROBE10_SAVE_ROTATION ", JSON.stringify(out))
	for n in root.get_children():
		if n is Node and n.get_script() == SaveS: n.free()
	quit(0)
