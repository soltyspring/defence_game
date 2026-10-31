extends Node
## Progress persistence. Contract: INTERFACES.md §3. Owner: 02-engine.
##
## Files: <path> (main), <path>.bak (previous good main), <path>.tmp (write staging),
##        <path>.corrupt-<unix>[-n] (quarantined unreadable mains, never loaded, never rotated into .bak).
## Write order (save_progress): write+flush tmp -> verify tmp -> [main known good] remove .bak, rename main -> .bak
##   | [main unreadable] quarantine main -> rename tmp -> main.
## Load order (load_progress): valid main -> else valid tmp (only exists past verify, so it is the newest state)
##   -> else valid .bak -> else fresh. Any non-main source sets recovered = true and recovery_source.
## A main that fails to read is quarantined at load, so the next save can never push it into .bak (QA-B004 / SV-1).
## Newer-version saves (version > VERSION) are loaded read-only and never rewritten (QA-B006).
## record_result is idempotent per battle_uid (applied_battles ring buffer) and transactional: on a failed
## write the in-memory progress is rolled back (10 R3).
## Debug-only fault injection (10 R6): set `_fault` to one of FAULT_POINTS; save_progress stops there and
## returns false exactly as a killed process would leave the files. Ignored when OS.is_debug_build() is false.

const VERSION := 1
const MAX_BYTES := 2 * 1024 * 1024        # PROVISIONAL size guard (08 owns the final limit)
const APPLIED_KEEP := 32
const FAULT_POINTS := ["after_tmp_write", "after_bak_rename", "before_final_rename", "torn_tmp"]
const COINS_CAP_DEFAULT := 9999999        # data/meta.json currencies.gold.max

var path := "user://save.json"
var progress: Dictionary = {}
var recovered := false
var recovery_source := "main"             # main | tmp | bak | fresh
var read_only := false                    # true when the file came from a newer build
var last_error := ""
var _fault := ""                          # debug-only, one-shot
var fault_fired := ""                     # last fault point that fired (for tests)
var _main_good := false                   # main on disk is known to be a valid envelope
var quarantined: Array[String] = []       # files moved aside during the last load

func _ready() -> void:
	load_progress()

static func fresh() -> Dictionary:
	return {"version": VERSION, "revision": 0, "unlocked_round": 1, "stars": {}, "best_time": {}, "coins": 0,
		"clears": 0, "tutorial_done": [], "upgrades": {}, "applied_battles": [],
		"settings": {"fps_cap": 60, "sfx": 1.0, "music": 0.8, "show_damage": true, "screen_shake": true}}

# ---------------------------------------------------------------- load
func load_progress() -> void:
	recovered = false
	recovery_source = "main"
	read_only = false
	quarantined.clear()
	_main_good = false
	var main_exists := FileAccess.file_exists(path)
	var p = _read(path)
	if p != null:
		_main_good = true
	else:
		if main_exists:
			_quarantine(path)          # unreadable main must never become the next .bak
		p = _read(path + ".tmp")
		if p != null:
			recovery_source = "tmp"
		else:
			p = _read(path + ".bak")
			recovery_source = "bak" if p != null else "fresh"
		# Recovered = progress did not come from a healthy main although something was on disk.
		recovered = main_exists or recovery_source != "fresh"
		if p == null:
			p = fresh()
	var from_v := int(p.get("version", 0)) if (p.get("version") is int or p.get("version") is float) else 0
	if from_v > VERSION:
		read_only = true               # keep the newer build's data untouched
		progress = p
		return
	progress = _migrate(p, from_v)

func _quarantine(file: String) -> void:
	var base := "%s.corrupt-%d" % [file, int(Time.get_unix_time_from_system())]
	var dst := base
	var n := 1
	while FileAccess.file_exists(dst):
		dst = "%s-%d" % [base, n]
		n += 1
	var dir := DirAccess.open(file.get_base_dir())
	if dir and dir.rename(file.get_file(), dst.get_file()) == OK:
		quarantined.append(dst)

func _read(file: String) -> Variant:
	if not FileAccess.file_exists(file):
		return null
	var f := FileAccess.open(file, FileAccess.READ)
	if f == null:
		last_error = "open failed: " + file
		return null
	if f.get_length() > MAX_BYTES:
		last_error = "file too large (%d bytes): %s" % [f.get_length(), file]
		return null
	var txt := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
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

## Fill missing keys, replace wrong-typed values, clamp ranges (QA-B003 / QA-B007). Unknown keys are kept
## (06-services stores `services` here).
func _migrate(p: Dictionary, _from_version: int) -> Dictionary:
	var base := fresh()
	for k in base:
		if not p.has(k) or not _same_kind(p[k], base[k]):
			p[k] = base[k].duplicate(true) if (base[k] is Dictionary or base[k] is Array) else base[k]
	for k in base.settings:
		if not p.settings.has(k):
			p.settings[k] = base.settings[k]
	var rounds_n := 999
	var coins_cap := COINS_CAP_DEFAULT
	if is_inside_tree():
		var c := get_node_or_null("/root/Content")
		if c:
			rounds_n = maxi(1, c.round_order.size())
			for cur in c.meta.get("currencies", []):
				if str(cur.get("id", "")) == "gold" and cur.has("max"):
					coins_cap = int(cur.max)
	p.unlocked_round = clampi(_to_int(p.unlocked_round, 1), 1, rounds_n + 1)
	p.coins = clampi(_to_int(p.coins, 0), 0, coins_cap)
	p.clears = maxi(0, _to_int(p.clears, 0))
	p.revision = maxi(0, _to_int(p.revision, 0))
	var stars := {}
	for k in p.stars:
		var v = p.stars[k]
		if v is int or v is float:
			stars[str(k)] = clampi(int(v), 0, 3)
	p.stars = stars
	var bt := {}
	for k in p.best_time:
		var v = p.best_time[k]
		if (v is int or v is float) and float(v) >= 0.0:
			bt[str(k)] = float(v)
	p.best_time = bt
	var ups := {}
	for k in p.upgrades:
		var v = p.upgrades[k]
		if v is int or v is float:
			ups[str(k)] = clampi(int(v), 1, 99)
	p.upgrades = ups
	var td: Array = []
	for k in p.tutorial_done:
		if k is String and not td.has(k): td.append(k)
	p.tutorial_done = td
	var ab: Array = []
	for k in p.applied_battles:
		if k is String: ab.append(k)
	p.applied_battles = ab.slice(maxi(0, ab.size() - APPLIED_KEEP))
	p.version = VERSION
	return p

static func _same_kind(a, b) -> bool:
	var na := a is int or a is float
	var nb := b is int or b is float
	if na or nb:
		return na and nb
	return typeof(a) == typeof(b)

static func _to_int(v, dflt: int) -> int:
	if v is int: return v
	if v is float:
		if is_nan(v) or is_inf(v): return dflt
		return int(clampf(v, -2147483648.0, 2147483647.0))
	return dflt

# ---------------------------------------------------------------- save
func _fault_here(point: String) -> bool:
	if _fault == point and OS.is_debug_build():
		_fault = ""
		fault_fired = point
		last_error = "fault:" + point
		return true
	return false

func save_progress() -> bool:
	if read_only:
		last_error = "read_only: save from newer version %s" % str(progress.get("version"))
		return false
	var old_rev := int(progress.get("revision", 0))
	progress.revision = old_rev + 1
	last_write_stage = "start"
	var ok := _write()
	if not ok:
		progress.revision = old_rev
		# F1 (10): decide "uncertain" from what is ON DISK, exactly as the next load_progress() would choose:
		# main unreadable/missing + valid .tmp => the next launch adopts this write.
		last_failure_uncertain = _read(path) == null and _read(path + ".tmp") != null
	else:
		last_failure_uncertain = false
	return ok

## After a failed save_progress(): true if the next launch will still load the state of that write
## (callers report save_uncertain / "outcome unknown" instead of save_failed).
var last_failure_uncertain := false

## Furthest point the last write reached: start | tmp_verified | done. After "tmp_verified" a failed save may
## still be adopted on the next launch (load prefers a verified .tmp when main is missing), so callers must treat
## that failure as "outcome unknown".
var last_write_stage := "start"

func _write() -> bool:
	var payload_txt := JSON.stringify(progress, "", true)
	var env_txt := JSON.stringify({"version": VERSION, "checksum": payload_txt.sha256_text(), "payload": payload_txt}, "", true)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("open tmp failed: %d" % FileAccess.get_open_error())
	if _fault_here("torn_tmp"):
		f.store_string(env_txt.substr(0, env_txt.length() / 2))
		f.close()
		return false
	f.store_string(env_txt)
	f.flush()
	f.close()
	if _fault_here("after_tmp_write"): return false
	if _read(tmp) == null:
		return _fail("tmp verify failed")
	last_write_stage = "tmp_verified"
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return _fail("open dir failed")
	var fname := path.get_file()
	if FileAccess.file_exists(path):
		if _main_good or _read(path) != null:
			# rotate the known-good main into .bak (only now is the old .bak dropped)
			if FileAccess.file_exists(path + ".bak"):
				dir.remove(fname + ".bak")
			if dir.rename(fname, fname + ".bak") != OK:
				return _fail("rotate main->bak failed")
		else:
			_quarantine(path)      # unreadable main: keep the existing good .bak
			if FileAccess.file_exists(path):
				return _fail("could not move unreadable main aside")
	if _fault_here("after_bak_rename"): return false
	if _fault_here("before_final_rename"): return false
	var err := dir.rename(fname + ".tmp", fname)
	if err != OK:
		return _fail("rename tmp->main failed: %d" % err)
	_main_good = true
	last_write_stage = "done"
	var ev := _events()
	if ev:
		ev.progress_changed.emit(progress)
	return true

func _fail(msg: String) -> bool:
	last_error = msg
	var ev := _events()
	if ev:
		ev.toast.emit("save_failed", {"error": msg})   # QA-B005: surface write failures
	return false

func _events() -> Node:
	return get_node_or_null("/root/Events") if is_inside_tree() else null

# ---------------------------------------------------------------- domain
func was_applied(battle_uid: String) -> bool:
	return battle_uid != "" and (progress.get("applied_battles", []) as Array).has(battle_uid)

## Apply a battle result once per battle_uid in one atomic save. Returns true if applied and saved,
## false if it was a duplicate (no change) or the write failed (progress rolled back).
func record_result(result: Dictionary, round_index_in_order: int) -> bool:
	var uid := str(result.get("battle_uid", ""))
	if was_applied(uid):
		last_error = "duplicate battle_uid " + uid
		return false
	var before := {}
	for k in ["unlocked_round", "clears", "coins"]:
		before[k] = progress[k]
	before.stars = progress.stars.duplicate()
	before.best_time = progress.best_time.duplicate()
	before.applied_battles = progress.applied_battles.duplicate()
	var rid := str(result.round_id)
	if bool(result.won):
		var prev := int(progress.stars.get(rid, 0))
		progress.stars[rid] = maxi(prev, int(result.stars))
		var bt := float(progress.best_time.get(rid, 1e9))
		progress.best_time[rid] = minf(bt, float(result.time))
		progress.unlocked_round = maxi(int(progress.unlocked_round), round_index_in_order + 2)
		progress.clears = int(progress.clears) + 1
	progress.coins = int(progress.coins) + int(result.get("coins", 0))
	if uid != "":
		var ab: Array = progress.applied_battles
		ab.append(uid)
		if ab.size() > APPLIED_KEEP:
			progress.applied_battles = ab.slice(ab.size() - APPLIED_KEEP)
	if not save_progress():
		for k in before:      # roll back only what this result touched; keeps nested refs (06 services) intact
			progress[k] = before[k]
		return false
	return true

func is_unlocked(order_index: int) -> bool:
	return order_index + 1 <= int(progress.unlocked_round)

# ---------------------------------------------------------------- meta upgrades (10 R3 contract)
## Result codes of buy_upgrade().
const UPG_OK := "ok"
const UPG_ALREADY := "already_applied"   # to_level <= current level (repeat of a completed purchase)
const UPG_MAX := "max_level"
const UPG_COINS := "not_enough_coins"
const UPG_UNKNOWN := "unknown_id"
const UPG_LOCKED := "locked"             # target unit not unlocked yet (unlock_round > unlocked_round)
const UPG_INVALID := "invalid_level"     # to_level skips levels (must be current + 1)
const UPG_SAVE_FAILED := "save_failed"   # nothing changed, in memory or on disk
const UPG_SAVE_UNCERTAIN := "save_uncertain"  # memory rolled back, but the verified .tmp may be adopted next launch
const UPG_READ_ONLY := "read_only"

func _content() -> Node:
	if content_ref != null:
		return content_ref
	return get_node_or_null("/root/Content") if is_inside_tree() else null

## Optional explicit Content (tests / tools); default is the /root/Content autoload.
var content_ref: Node = null

func _upgrade_def(upgrade_id: String) -> Dictionary:
	var c := _content()
	if c == null:
		return {}
	for u in c.meta.get("upgrades", []):
		if u is Dictionary and str(u.get("id", "")) == upgrade_id:
			return u
	return {}

func upgrade_level(upgrade_id: String) -> int:
	return int(progress.get("upgrades", {}).get(upgrade_id, 1))

## Coins needed to go from to_level-1 to to_level (data/meta.json costs[i] = price from level i+1 to i+2), or -1.
func upgrade_cost(upgrade_id: String, to_level: int) -> int:
	var u := _upgrade_def(upgrade_id)
	var costs: Array = u.get("costs", [])
	var i := to_level - 2
	if i < 0 or i >= costs.size():
		return -1
	return int(costs[i])

func _upgrade_locked(u: Dictionary) -> bool:
	var target := str(u.get("target", ""))
	if not target.begins_with("unit:"):
		return false
	var uid := target.trim_prefix("unit:")
	var c := _content()
	if c == null or not c.units.has(uid):
		return false
	return int(c.units[uid].get("unlock_round", 1)) > int(progress.unlocked_round)

## Buy one upgrade level: validate, then deduct coins and raise the level in ONE atomic save.
## On a failed write both are rolled back in memory. Synchronous, so a second identical call in the same frame
## sees the new level and returns already_applied.
func buy_upgrade(upgrade_id: String, to_level: int) -> String:
	if read_only: return UPG_READ_ONLY
	var u := _upgrade_def(upgrade_id)
	if u.is_empty(): return UPG_UNKNOWN
	var cur := upgrade_level(upgrade_id)
	var max_l := int(u.get("max_level", 1))
	if to_level <= cur: return UPG_ALREADY
	if to_level > max_l or cur >= max_l: return UPG_MAX
	if to_level != cur + 1: return UPG_INVALID
	if _upgrade_locked(u): return UPG_LOCKED
	var cost := upgrade_cost(upgrade_id, to_level)
	if cost < 0: return UPG_MAX
	var coins := int(progress.coins)
	if coins < cost: return UPG_COINS
	var ups: Dictionary = progress.upgrades
	var had_key := ups.has(upgrade_id)
	progress.coins = coins - cost
	ups[upgrade_id] = to_level
	if save_progress():
		return UPG_OK
	progress.coins = coins
	if had_key: ups[upgrade_id] = cur
	else: ups.erase(upgrade_id)
	return UPG_SAVE_UNCERTAIN if last_failure_uncertain else UPG_SAVE_FAILED

func set_setting(key: String, value: Variant) -> void:
	progress.settings[key] = value
	save_progress()
