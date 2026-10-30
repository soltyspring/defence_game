extends Node
## Progress persistence with atomic write, checksum, .bak recovery and migration.
## Contract: INTERFACES.md §3. Owner: 02-engine.

const VERSION := 1
var path := "user://save.json"
var progress: Dictionary = {}
var recovered := false
var last_error := ""

func _ready() -> void:
	load_progress()

static func fresh() -> Dictionary:
	return {"version": VERSION, "unlocked_round": 1, "stars": {}, "best_time": {}, "coins": 0,
		"clears": 0, "settings": {"fps_cap": 60, "sfx": 1.0, "music": 0.8, "show_damage": true, "screen_shake": true}}

func load_progress() -> void:
	recovered = false
	var p = _read(path)
	if p == null:
		var had_main := FileAccess.file_exists(path)
		p = _read(path + ".bak")
		recovered = had_main or p != null
		if p == null:
			p = fresh()
			recovered = had_main
	progress = _migrate(p, int(p.get("version", 0)))

func _read(file: String) -> Variant:
	if not FileAccess.file_exists(file):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(file)) != OK:
		last_error = "parse error in " + file
		return null
	var d = j.data
	if not (d is Dictionary and d.get("payload") is String):
		last_error = "bad envelope in " + file
		return null
	var payload_txt: String = d.payload
	if str(d.get("checksum", "")) != payload_txt.sha256_text():
		last_error = "checksum mismatch in " + file
		return null
	var pj := JSON.new()
	if pj.parse(payload_txt) != OK or not (pj.data is Dictionary):
		last_error = "payload parse error in " + file
		return null
	return pj.data

func _migrate(p: Dictionary, from_version: int) -> Dictionary:
	var base := fresh()
	# v0 (no version) -> v1: just fill missing keys. Future migrations go here, step by step.
	for k in base:
		if not p.has(k):
			p[k] = base[k]
	if p.settings is Dictionary:
		for k in base.settings:
			if not p.settings.has(k):
				p.settings[k] = base.settings[k]
	else:
		p.settings = base.settings
	p.unlocked_round = maxi(1, int(p.unlocked_round))
	p.coins = maxi(0, int(p.coins))
	p.version = VERSION
	return p

func save_progress() -> bool:
	var payload_txt := JSON.stringify(progress, "", true)
	var env := {"version": VERSION, "checksum": payload_txt.sha256_text(), "payload": payload_txt}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "open tmp failed: %d" % FileAccess.get_open_error()
		return false
	f.store_string(JSON.stringify(env, "", true))
	f.flush()
	f.close()
	# verify tmp before swapping in
	if _read(tmp) == null:
		last_error = "tmp verify failed"
		return false
	var dir := DirAccess.open(path.get_base_dir())
	var fname := path.get_file()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			dir.remove(fname + ".bak")
		dir.rename(fname, fname + ".bak")
	var err := dir.rename(fname + ".tmp", fname)
	if err != OK:
		last_error = "rename failed: %d" % err
		return false
	var ev := get_node_or_null("/root/Events")
	if ev:
		ev.progress_changed.emit(progress)
	return true

## Apply a battle result; returns coins granted.
func record_result(result: Dictionary, round_index_in_order: int) -> void:
	var rid: String = result.round_id
	if result.won:
		var prev := int(progress.stars.get(rid, 0))
		progress.stars[rid] = maxi(prev, int(result.stars))
		var bt := float(progress.best_time.get(rid, 1e9))
		progress.best_time[rid] = minf(bt, float(result.time))
		progress.unlocked_round = maxi(int(progress.unlocked_round), round_index_in_order + 2)
		progress.clears = int(progress.clears) + 1
	progress.coins = int(progress.coins) + int(result.coins)
	save_progress()

func is_unlocked(order_index: int) -> bool:
	return order_index + 1 <= int(progress.unlocked_round)

func set_setting(key: String, value: Variant) -> void:
	progress.settings[key] = value
	save_progress()
