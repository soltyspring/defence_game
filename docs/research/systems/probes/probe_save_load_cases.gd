extends SceneTree
## Read-only research probe (10-research-systems): load-path robustness of src/core/save.gd for damaged files.
## Writes ONLY under user://probe10/ (run it inside a renamed snapshot project so user:// is not the game's).
## Run:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path <snapshot> -s res://docs/research/systems/probes/probe_save_load_cases.gd --quit-after 600
## A 60 s in-script watchdog also quits. Prints "PROBE10_SAVE_LOAD {json}" and exits 0.

const SaveS := preload("res://src/core/save.gd")
const DIR := "user://probe10"
const GOOD := {"version": 1, "unlocked_round": 6, "coins": 900, "stars": {"r01": 3}, "best_time": {}, "settings": {}}
const NEWER := {"version": 1, "unlocked_round": 8, "coins": 1500, "stars": {"r01": 3, "r02": 3}, "best_time": {}, "settings": {}}

func _env(p: Dictionary, version_override = null) -> String:
	var txt := JSON.stringify(p, "", true)
	var e := {"version": 1, "checksum": txt.sha256_text(), "payload": txt}
	if version_override != null: e.version = version_override
	return JSON.stringify(e, "", true)

func _w(path: String, s: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(s); f.close()

func _wb(path: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_buffer(b); f.close()

func _clean(p: String) -> void:
	for fn in DirAccess.get_files_at(DIR):
		if fn.begins_with(p.get_file()): DirAccess.remove_absolute(DIR + "/" + fn)

func _files(p: String) -> Array:
	var out: Array = []
	for fn in DirAccess.get_files_at(DIR):
		if fn.begins_with(p.get_file()): out.append(fn.substr(p.get_file().length()))
	out.sort()
	return out

func _load(p: String) -> Node:
	var s = SaveS.new()
	s.path = p
	root.add_child(s)
	s.load_progress()
	return s

func _case(name: String, setup: Callable, try_save := false) -> Dictionary:
	var p := DIR + "/" + name + ".json"
	_clean(p)
	setup.call(p)
	var before := _files(p)
	var main_bytes := FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else PackedByteArray()
	var s = _load(p)
	var r := {"files_before": before, "unlocked": int(s.progress.get("unlocked_round", -1)), "coins": int(s.progress.get("coins", -1)),
		"recovered": s.recovered, "source": s.recovery_source, "read_only": s.read_only, "quarantined": s.quarantined.size(),
		"last_error": s.last_error, "files_after_load": _files(p)}
	if try_save:
		var ok: bool = s.save_progress()
		r.save_ok = ok
		r.files_after_save = _files(p)
		r.main_bytes_unchanged = FileAccess.file_exists(p) and FileAccess.get_file_as_bytes(p) == main_bytes
		var s2 = _load(p)
		r.reload_unlocked = int(s2.progress.get("unlocked_round", -1))
		r.reload_source = s2.recovery_source
		s2.free()
	s.free()
	return r

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	create_timer(60.0).timeout.connect(func(): print("PROBE10_SAVE_LOAD {\"watchdog\":true}"); quit(0))
	var out := {}
	out.L01_main_zero_byte_bak_good = _case("l01", func(p): _w(p, ""); _w(p + ".bak", _env(GOOD)), true)
	out.L02_main_truncated_half_bak_good = _case("l02", func(p): var t := _env(NEWER); _w(p, t.substr(0, t.length() / 2)); _w(p + ".bak", _env(GOOD)), true)
	out.L03_main_checksum_mismatch_bak_good = _case("l03", func(p):
		var real_txt := JSON.stringify(NEWER, "", true)
		var edited := NEWER.duplicate(true); edited.coins = 999999      # payload edited by hand, checksum left stale
		_w(p, JSON.stringify({"version": 1, "checksum": real_txt.sha256_text(), "payload": JSON.stringify(edited, "", true)})); _w(p + ".bak", _env(GOOD)))
	out.L04_main_payload_not_object = _case("l04", func(p):
		var txt := "[1,2,3]"
		_w(p, JSON.stringify({"version": 1, "checksum": txt.sha256_text(), "payload": txt})); _w(p + ".bak", _env(GOOD)))
	out.L05_main_missing_tmp_newer_bak_older = _case("l05", func(p): _w(p + ".tmp", _env(NEWER)); _w(p + ".bak", _env(GOOD)), true)
	out.L06_main_missing_tmp_torn_bak_good = _case("l06", func(p): var t := _env(NEWER); _w(p + ".tmp", t.substr(0, 40)); _w(p + ".bak", _env(GOOD)))
	out.L07_all_three_corrupt = _case("l07", func(p): _w(p, "{x"); _w(p + ".tmp", "{y"); _w(p + ".bak", "\u0000\u0000"), true)
	out.L08_main_over_2MiB_bak_good = _case("l08", func(p):
		var big := GOOD.duplicate(true); big.pad = "x".repeat(2 * 1024 * 1024 + 10)
		_w(p, _env(big)); _w(p + ".bak", _env(GOOD)))
	out.L09_newer_version_99 = _case("l09", func(p): var nv := NEWER.duplicate(true); nv.version = 99; _w(p, _env(nv)), true)
	out.L09b_envelope_version_99_payload_v1 = _case("l09b", func(p): _w(p, _env(NEWER, 99)), true)
	out.L10_legacy_no_version_field = _case("l10", func(p):
		var legacy := {"unlocked_round": 4, "coins": 300, "stars": {"r01": 2}}
		var txt := JSON.stringify(legacy)
		_w(p, JSON.stringify({"checksum": txt.sha256_text(), "payload": txt})), true)
	out.L11_utf8_bom_prefix = _case("l11", func(p):
		var b := PackedByteArray([0xEF, 0xBB, 0xBF]); b.append_array(_env(NEWER).to_utf8_buffer()); _wb(p, b); _w(p + ".bak", _env(GOOD)))
	out.L12_plain_json_no_envelope = _case("l12", func(p): _w(p, JSON.stringify(NEWER)); _w(p + ".bak", _env(GOOD)))
	out.L13_fresh_install_nothing = _case("l13", func(_p): pass, true)
	print("PROBE10_SAVE_LOAD ", JSON.stringify(out))
	for fn in DirAccess.get_files_at(DIR): DirAccess.remove_absolute(DIR + "/" + fn)
	quit(0)
