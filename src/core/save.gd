extends Node
## Progress persistence. Contract: INTERFACES.md §3. Owner: 02-engine.
##
## Files: <path> (main), <path>.bak (previous good main), <path>.tmp (write staging),
##        <path>.corrupt-<unix>[-n] (quarantined unreadable mains, never loaded, never rotated into .bak; newest 3 kept),
##        <base>.pre-<content_version>.json (copy of the save before a content migration wrote it; newest 2 kept).
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
const CORRUPT_KEEP := 3                   # quarantined .corrupt-* copies kept per save file (newest)
const PRE_BACKUPS_KEEP := 2               # pre-migration backups <base>.pre-<content_version>.json kept (newest)
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
		"clears": 0, "tutorial_done": [], "upgrades": {}, "upgrade_paid": {}, "applied_battles": [],
		"settings": {"fps_cap": 60, "sfx": 1.0, "music": 0.8, "show_damage": true, "screen_shake": true}}

# ---------------------------------------------------------------- load
func load_progress() -> void:
	recovered = false
	migration_log = []
	last_migration = {}
	_migration_pending = false
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
	_apply_content_migration()

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
		# 10 v0.28 (P3): bound the space used by quarantined copies (07 TP-13 left 19 x 50 MiB)
		_prune(file.get_base_dir(), file.get_file() + ".corrupt-", "", CORRUPT_KEEP, dst.get_file())

## Delete all but the newest `keep` files in dir_path whose names start with prefix and end with suffix.
## `protect` (the file just written) is always kept and counts as the newest; the rest are ordered by modified time,
## then by name (both quarantine and backup names grow over time).
func _prune(dir_path: String, prefix: String, suffix: String, keep: int, protect: String) -> void:
	var files := []
	for fn in DirAccess.get_files_at(dir_path):
		if fn != protect and fn.begins_with(prefix) and fn.ends_with(suffix):
			files.append([FileAccess.get_modified_time(dir_path.path_join(fn)), fn])
	files.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	for i in range(maxi(0, keep - 1), files.size()):
		DirAccess.remove_absolute(dir_path.path_join(files[i][1]))

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
	# upgrade_paid {id: {"<level reached>": coins paid}} (10 v0.21 A, 01 D32): keys 2..current level, values ints >= 0
	var paid := {}
	for id in p.upgrade_paid:
		var rec = p.upgrade_paid[id]
		if not (rec is Dictionary): continue
		var lvl := int(ups.get(str(id), 1))
		var clean := {}
		for k in rec:
			var ks := str(k)
			var v = rec[k]
			if not ks.is_valid_int() or not (v is int or v is float) or float(v) < 0.0: continue
			var L := ks.to_int()
			if L >= 2 and L <= mini(99, lvl):
				clean[str(L)] = mini(int(v), coins_cap)
		if not clean.is_empty(): paid[str(id)] = clean
	p.upgrade_paid = paid
	if p.has("migrations_applied"):
		var ma: Array = []
		if p.migrations_applied is Array:
			for k in p.migrations_applied:
				if k is String and not ma.has(k): ma.append(k)
		p.migrations_applied = ma
	if p.has("open_rounds"):
		var orr: Array = []
		if p.open_rounds is Array:
			for k in p.open_rounds:
				if k is String and not orr.has(k): orr.append(k)
		if orr.is_empty(): p.erase("open_rounds")
		else: p.open_rounds = orr.slice(0, 64)
	if p.has("migration_notice"):
		var n = p.migration_notice
		if n is Dictionary and (n.get("levels") is int or n.get("levels") is float) and (n.get("coins") is int or n.get("coins") is float):
			p.migration_notice = {"levels": maxi(0, int(n.levels)), "coins": clampi(int(n.coins), 0, coins_cap),
				"from": str(n.get("from", "")), "to": str(n.get("to", ""))}
		else:
			p.erase("migration_notice")
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
	_stamp_content()
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
	var had_open = progress.get("open_rounds")
	if had_open is Array: before["open_rounds"] = had_open.duplicate()
	var rid := str(result.round_id)
	if bool(result.won):
		# 10 v0.34: a win inside the playable prefix (or a forced/dev win of a locked round) advances the prefix as before;
		# a win of a round open only by id (a hole after a content update) opens the next round by its star, without
		# unlocking the rounds in between.
		var hole := round_index_in_order >= int(progress.unlocked_round) and is_unlocked(round_index_in_order)
		var prev := int(progress.stars.get(rid, 0))
		progress.stars[rid] = maxi(prev, int(result.stars))
		var bt := float(progress.best_time.get(rid, 1e9))
		progress.best_time[rid] = minf(bt, float(result.time))
		var prefix := int(progress.unlocked_round) if hole else maxi(int(progress.unlocked_round), round_index_in_order + 2)
		var c := _content()
		if c != null and c.round_order.size() > 0:
			var keep := {}
			for k in progress.get("open_rounds", []): keep[str(k)] = true
			_set_unlock_state(_unlock_state(Array(c.round_order), prefix, keep, prefix > c.round_order.size()))
		else:
			progress.unlocked_round = prefix
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
		if not (had_open is Array): progress.erase("open_rounds")
		return false
	return true

## 10 v0.34: round order[i] is playable iff i < unlocked_round (the playable prefix), or i == 0, or it has a star record,
## or order[i-1] has one, or its id is in progress.open_rounds (kept open by a content update beyond the prefix).
## In normal play only the prefix matters; the rest keeps cleared rounds open after rounds are inserted, moved or
## renamed. UI should use this (or round_reach()) instead of reading unlocked_round directly.
func is_unlocked(order_index: int) -> bool:
	if order_index < 0: return false
	var c := _content()
	if c != null and order_index >= c.round_order.size(): return false
	if order_index + 1 <= int(progress.unlocked_round):
		return true
	if c == null or order_index < 0 or order_index >= c.round_order.size():
		return false
	var rid := str(c.round_order[order_index])
	var st: Dictionary = progress.get("stars", {})
	if int(st.get(rid, 0)) > 0 or (order_index > 0 and int(st.get(str(c.round_order[order_index - 1]), 0)) > 0):
		return true
	var extra = progress.get("open_rounds")
	return extra is Array and (extra as Array).has(rid)

## 1-based index of the furthest playable round (>= unlocked_round). For "unit unlocked by round k" checks (U5).
func round_reach() -> int:
	var reach := int(progress.unlocked_round)
	var c := _content()
	if c == null:
		return reach
	for i in range(c.round_order.size() - 1, reach - 1, -1):
		if is_unlocked(i):
			return i + 1
	return reach

## See is_unlocked(). Returns {"unlocked": leading playable run (+1 when every round is playable and the last one is
## cleared, or the save was already past the end), "extra": ids playable beyond that run only because of `keep`}.
func _unlock_state(order: Array, prefix: int, keep: Dictionary, beyond_end: bool) -> Dictionary:
	var st: Dictionary = progress.get("stars", {})
	var n := order.size()
	var run := 0
	var in_run := true
	var extra: Array = []
	for i in n:
		var rid := str(order[i])
		var by_rule: bool = i == 0 or i < prefix or int(st.get(rid, 0)) > 0 or (i > 0 and int(st.get(str(order[i - 1]), 0)) > 0)
		var open: bool = by_rule or keep.has(rid)
		if in_run and open:
			run = i + 1
		else:
			in_run = false
			if open and not by_rule:
				extra.append(rid)
	var unl := maxi(1, run)
	for rid in keep:
		if not order.has(rid) and not extra.has(rid): extra.append(rid)
	if n > 0 and run == n and (beyond_end or int(st.get(str(order[n - 1]), 0)) > 0):
		unl = n + 1
	return {"unlocked": unl, "extra": extra}

func _set_unlock_state(res: Dictionary) -> void:
	progress.unlocked_round = int(res.unlocked)
	if (res.extra as Array).is_empty():
		progress.erase("open_rounds")
	else:
		progress["open_rounds"] = res.extra

# ---------------------------------------------------------------- content migration (10 R5; rules 01 D32)
## Every successful save records `content_version` and a small `content_snapshot` of the data it was made with
## (upgrade id -> {target, costs, max_level}, round order); every purchase records the price paid in `upgrade_paid`.
## When a later build loads the save with different data (content_version differs), in ONE atomic save:
##  1. upgrade renames: data/migrations.json `upgrade_renames {old: new}` (01); otherwise an id that disappeared is
##     matched to a NEW id with the same `target` (PROVISIONAL heuristic). Higher level wins on collision.
##  2. retired upgrades (id no longer in meta.json and not renamed): refund every level, then remove the id (D32 (2)).
##  3. clamp levels to the current max_level and refund the removed levels (D32 (1)).
##     Price of level L = `upgrade_paid[id][L]` (actually paid), else the snapshot price (what the save was last made
##     with), else 0 + warning "content/refund_unknown". Once per (content_version, id) via `migrations_applied`.
##     Coins are clamped to the currency cap once.
##  4. round renames: migrations.json `round_renames {old: new}` for stars/best_time (higher stars, lower time).
##  5. unlocks by round id: order[i] is open iff i == 0, or it has stars, or order[i-1] has stars; unlocked_round =
##     length of the open prefix. Only when the save HAS a previous content_version (legacy/test saves without one
##     are never re-locked).
##  Unknown round ids are kept. If meta.json has no upgrades (missing/broken data), upgrades are not touched.
##  Nothing to change -> NO write during the load (10 X1); the next ordinary save stamps the new version.
##  Before the write, the loaded file is copied to <base>.pre-<old content_version>.json (10 v0.27; never rotated).
##  On a failed write memory is restored and `_migration_pending` keeps ordinary saves from stamping the new version
##  on the un-migrated data (10 F2), so the next load retries. Levels removed / coins refunded are kept in
##  `migration_notice` (persisted) until the UI acknowledges it (Events.content_migrated, D32 (3)).
const MIGRATION_KEYS_KEEP := 64

func _content_snapshot(c) -> Dictionary:
	var ups := {}
	for u in c.meta.get("upgrades", []):
		if u is Dictionary and u.has("id"):
			ups[str(u.id)] = {"target": str(u.get("target", "")), "costs": (u.get("costs", []) as Array).duplicate(), "max_level": int(u.get("max_level", 1))}
	return {"version": str(c.content_version), "upgrades": ups, "order": Array(c.round_order)}

func _stamp_content() -> void:
	if _migration_pending:
		return   # F2 (10 v0.25): keep the OLD version + snapshot on un-migrated data so the next load migrates again
	var c := _content()
	if c == null or str(c.get("content_version")) == "":
		return
	progress["content_version"] = str(c.content_version)
	progress["content_snapshot"] = _content_snapshot(c)

func _apply_content_migration() -> void:
	if read_only:
		return
	var c := _content()
	if c == null or str(c.get("content_version")) == "":
		return
	var cur_cv := str(c.content_version)
	var prev_cv := str(progress.get("content_version", ""))
	if prev_cv == cur_cv:
		return
	if recovery_source == "fresh":
		return   # nothing was on disk: never create a save file during a load (07 SAVE-03)
	var changed := false
	# Unknown extension data is preserved but never mutated by migration. Deep-copy only the
	# sanitized containers we change: cloning an arbitrary nested extension hits Godot's
	# recursive-duplicate limit even though the save itself is valid JSON.
	var before := progress.duplicate()
	for key in ["upgrades", "upgrade_paid", "stars", "best_time", "migrations_applied"]:
		var value = progress.get(key)
		if value is Dictionary or value is Array: before[key] = value.duplicate(true)
	var snap: Dictionary = progress.get("content_snapshot") if progress.get("content_snapshot") is Dictionary else {}
	# Rename inference adds aliases locally; the old snapshot must stay intact for rollback.
	var snap_ups: Dictionary = snap.upgrades.duplicate() if snap.get("upgrades") is Dictionary else {}
	var keys: Array = progress.get("migrations_applied") if progress.get("migrations_applied") is Array else []
	if not (progress.get("upgrade_paid") is Dictionary):
		progress["upgrade_paid"] = {}
	var paid_all: Dictionary = progress.upgrade_paid
	var log := []
	var levels_removed := 0
	var refunded := 0
	var meta_ups := {}
	for u in c.meta.get("upgrades", []):
		if u is Dictionary and u.has("id"): meta_ups[str(u.id)] = u
	var ups: Dictionary = progress.upgrades
	if meta_ups.is_empty():
		if not ups.is_empty(): log.append("meta has no upgrades: upgrades left untouched")
	else:
		# 1. upgrade renames
		var renames: Dictionary = {}
		var mig_up = c.migrations.get("upgrade_renames", {})
		if mig_up is Dictionary:
			for k in mig_up: renames[str(k)] = str(mig_up[k])
		for old_id in ups.keys():
			if meta_ups.has(old_id) or renames.has(old_id): continue
			var tgt := str(snap_ups.get(old_id, {}).get("target", "")) if snap_ups.get(old_id) is Dictionary else ""
			if tgt == "": continue
			for nid in meta_ups:
				if str(meta_ups[nid].get("target", "")) == tgt and not snap_ups.has(nid) and not ups.has(nid):
					renames[old_id] = nid
					log.append("upgrade_rename_by_target %s->%s" % [old_id, nid])
					break
		for old_id in renames:
			var nid: String = renames[old_id]
			if ups.has(old_id) and old_id != nid:
				changed = true
				var old_wins := int(ups[old_id]) >= int(ups.get(nid, 1))
				ups[nid] = maxi(int(ups.get(nid, 1)), int(ups[old_id]))
				ups.erase(old_id)
				if paid_all.has(old_id):
					if old_wins: paid_all[nid] = paid_all[old_id]
					paid_all.erase(old_id)
				if snap_ups.has(old_id) and not snap_ups.has(nid): snap_ups[nid] = snap_ups[old_id]
				keys.append("mig:%s:%s:%s" % [cur_cv, old_id, nid])
		# 2. retired upgrades: refund every level, then remove (01 D32 (2))
		for id in ups.keys():
			if meta_ups.has(id): continue
			changed = true
			var lvl := int(ups[id])
			var refund := 0
			var rkey := "retire:%s:%s" % [cur_cv, id]
			if not keys.has(rkey):
				refund = _refund_levels(id, 1, lvl, paid_all, snap_ups, log)
				keys.append(rkey)
			refunded += refund
			levels_removed += maxi(0, lvl - 1)
			ups.erase(id)
			paid_all.erase(id)
			log.append("retire %s L%d +%d" % [id, lvl, refund])
		# 3. clamp to max_level + refund the removed levels (01 D32 (1))
		for id in ups.keys():
			var max_l := maxi(1, int(meta_ups[id].get("max_level", 1)))
			var lvl := int(ups[id])
			if lvl <= max_l: continue
			changed = true
			var refund := 0
			var rkey := "refund:%s:%s" % [cur_cv, id]
			if not keys.has(rkey):
				refund = _refund_levels(id, max_l, lvl, paid_all, snap_ups, log)
				keys.append(rkey)
			refunded += refund
			levels_removed += lvl - max_l
			ups[id] = max_l
			var rec = paid_all.get(id)
			if rec is Dictionary:
				for L in range(max_l + 1, lvl + 1): rec.erase(str(L))
				if rec.is_empty(): paid_all.erase(id)
			log.append("refund %s L%d->L%d +%d" % [id, lvl, max_l, refund])
		if refunded > 0:
			progress.coins = clampi(int(progress.coins) + refunded, 0, _coins_cap())
	# 4. round renames
	var mig_r = c.migrations.get("round_renames", {})
	if mig_r is Dictionary:
		for old_r in mig_r:
			var nr := str(mig_r[old_r])
			if progress.stars.has(old_r) or progress.best_time.has(old_r):
				changed = true
			if progress.stars.has(old_r):
				progress.stars[nr] = maxi(int(progress.stars.get(nr, 0)), int(progress.stars[old_r]))
				progress.stars.erase(old_r)
			if progress.best_time.has(old_r):
				progress.best_time[nr] = minf(float(progress.best_time.get(nr, 1e9)), float(progress.best_time[old_r]))
				progress.best_time.erase(old_r)
	# 5. unlocks by round id (10 v0.34 U1–U5; only when the data the save was made with is known)
	if prev_cv != "":
		var old_order: Array = snap.get("order") if snap.get("order") is Array else Array(c.round_order)
		var renamed := {}
		if mig_r is Dictionary:
			for k in mig_r: renamed[str(k)] = str(mig_r[k])
		var old_unl := int(progress.unlocked_round)
		var keep := {}                   # ids playable before the update (U2), after round_renames
		for i in mini(old_unl, old_order.size()):
			keep[str(renamed.get(str(old_order[i]), str(old_order[i])))] = true
		for rid in progress.get("open_rounds", []):
			keep[str(renamed.get(str(rid), str(rid)))] = true
		var res := _unlock_state(Array(c.round_order), 0, keep, old_unl > old_order.size())
		var old_extra: Array = progress.get("open_rounds", [])
		if int(res.unlocked) != old_unl or res.extra != old_extra:
			log.append("unlocked_round %d->%d open_rounds %s" % [old_unl, int(res.unlocked), str(res.extra)])
			changed = true
		_set_unlock_state(res)
	migration_log = log
	if not changed:
		return   # X1 (10 v0.26): nothing to fix -> no write during load; the next ordinary save stamps the version
	if levels_removed > 0 or refunded > 0:
		var n := {"levels": levels_removed, "coins": refunded, "from": prev_cv, "to": cur_cv}
		var old_n = progress.get("migration_notice")
		if old_n is Dictionary:   # an earlier notice the player has not seen yet: add up
			n["levels"] = levels_removed + int(old_n.get("levels", 0))
			n["coins"] = refunded + int(old_n.get("coins", 0))
			n["from"] = str(old_n.get("from", prev_cv))
		progress["migration_notice"] = n
	progress["migrations_applied"] = keys.slice(maxi(0, keys.size() - MIGRATION_KEYS_KEEP))
	var backup := _pre_migration_backup(prev_cv, before)
	if backup != "":
		migration_log.append("backup " + backup.get_file())
	if save_progress():   # stamps the new content_version + snapshot
		last_migration = {"from": prev_cv, "to": cur_cv, "levels": levels_removed, "coins": refunded, "backup": backup}
	else:
		progress = before
		_migration_pending = true
		migration_log.append("save_failed: migration will retry on next load")

## Coins for levels from_l+1..to_l of `id` (01 D32: price actually paid, else the snapshot price, else 0 + warning).
func _refund_levels(id: String, from_l: int, to_l: int, paid_all: Dictionary, snap_ups: Dictionary, log: Array) -> int:
	var coins := 0
	var unknown := []
	var rec = paid_all.get(id)
	var s = snap_ups.get(id)
	var costs: Array = s.costs if s is Dictionary and s.get("costs") is Array else []
	for L in range(from_l + 1, to_l + 1):
		var v = rec.get(str(L)) if rec is Dictionary else null
		if not (v is int or v is float):
			v = costs[L - 2] if L - 2 >= 0 and L - 2 < costs.size() else null
		if (v is int or v is float) and float(v) >= 0.0:
			coins += int(v)
		else:
			unknown.append(L)
	if not unknown.is_empty():
		push_warning("[Save] content/refund_unknown %s levels %s (no recorded price)" % [id, str(unknown)])
		log.append("refund_unknown %s %s" % [id, str(unknown)])
	return coins

## 10 v0.27: copy the file this load came from to <base>.pre-<old content_version>.json before a migration writes.
## Ordinary saves never touch it. An existing backup for the same old version is kept (it holds the earlier state,
## e.g. after an update -> rollback -> update cycle). Keeps the newest PRE_BACKUPS_KEEP. Returns the path or "".
func _pre_migration_backup(prev_cv: String, state: Dictionary) -> String:
	var tag := (prev_cv if prev_cv != "" else "legacy").validate_filename()
	var dst := "%s.pre-%s.json" % [path.get_basename(), tag]
	if FileAccess.file_exists(dst):
		return dst
	var src := path if recovery_source == "main" else "%s.%s" % [path, recovery_source]
	var bytes := FileAccess.get_file_as_bytes(src) if FileAccess.file_exists(src) else PackedByteArray()
	if bytes.is_empty():   # source vanished: write the loaded state in the normal envelope instead
		var payload_txt := JSON.stringify(state, "", true)
		bytes = JSON.stringify({"version": VERSION, "checksum": payload_txt.sha256_text(), "payload": payload_txt}, "", true).to_utf8_buffer()
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		push_warning("[Save] pre-migration backup failed: %s (%d)" % [dst, FileAccess.get_open_error()])
		return ""
	f.store_buffer(bytes)
	f.close()
	_prune(path.get_base_dir(), path.get_basename().get_file() + ".pre-", ".json", PRE_BACKUPS_KEEP, dst.get_file())
	return dst

func _coins_cap() -> int:
	var c := _content()
	if c:
		for cur in c.meta.get("currencies", []):
			if cur is Dictionary and str(cur.get("id", "")) == "gold" and cur.has("max"):
				return int(cur.max)
	return COINS_CAP_DEFAULT

## What the last content migration did (for QA/probes); empty when nothing ran.
var migration_log: Array = []
## Last successful content migration this session: {"from", "to", "levels", "coins", "backup"} or {}.
var last_migration: Dictionary = {}
## True after a migration write failed this session (10 F2): ordinary saves keep the old content_version.
var _migration_pending := false

## 01 D32 (3) menu notice after a content migration that removed levels or refunded coins. Persisted in the save
## until the UI acknowledges it. {"levels": int, "coins": int, "from": String, "to": String} or {}.
func migration_notice() -> Dictionary:
	var n = progress.get("migration_notice")
	return (n as Dictionary).duplicate() if n is Dictionary else {}

## The UI showed the notice: drop it and save (if that write fails, the notice may show again next launch).
func ack_migration_notice() -> void:
	if read_only or not progress.has("migration_notice"):
		return
	progress.erase("migration_notice")
	save_progress()

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
	return int(c.units[uid].get("unlock_round", 1)) > round_reach()

## For UI (04 upgrade panel): true while the upgrade's target unit is not unlocked yet. An upgrade the player already
## bought (level >= 2) is never locked again, whatever a content update did to the round order (10 v0.34 U5).
func upgrade_locked(upgrade_id: String) -> bool:
	var u := _upgrade_def(upgrade_id)
	if u.is_empty() or upgrade_level(upgrade_id) >= 2:
		return false
	return _upgrade_locked(u)

## Late campaign tiers are gated independently of the original unit unlock.
## Previously purchased levels remain valid through content migrations.
func upgrade_level_unlock_round(upgrade_id: String, to_level: int) -> int:
	var gates: Dictionary = _upgrade_def(upgrade_id).get("level_unlock_rounds",{})
	return int(gates.get(str(to_level),1))

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
	if cur < 2 and _upgrade_locked(u): return UPG_LOCKED
	if round_reach() < upgrade_level_unlock_round(upgrade_id,to_level): return UPG_LOCKED
	var cost := upgrade_cost(upgrade_id, to_level)
	if cost < 0: return UPG_MAX
	var coins := int(progress.coins)
	if coins < cost: return UPG_COINS
	var ups: Dictionary = progress.upgrades
	var had_key := ups.has(upgrade_id)
	if not (progress.get("upgrade_paid") is Dictionary):
		progress["upgrade_paid"] = {}
	var paid_all: Dictionary = progress.upgrade_paid
	var had_rec := paid_all.has(upgrade_id)
	var rec: Dictionary = paid_all.get(upgrade_id, {})
	var lkey := str(to_level)
	var prev_paid = rec.get(lkey)
	progress.coins = coins - cost
	ups[upgrade_id] = to_level
	rec[lkey] = cost             # 01 D32: the price actually paid, written in the same atomic save
	paid_all[upgrade_id] = rec
	if save_progress():
		return UPG_OK
	progress.coins = coins
	if had_key: ups[upgrade_id] = cur
	else: ups.erase(upgrade_id)
	if prev_paid != null: rec[lkey] = prev_paid
	else: rec.erase(lkey)
	if not had_rec: paid_all.erase(upgrade_id)
	return UPG_SAVE_UNCERTAIN if last_failure_uncertain else UPG_SAVE_FAILED

const GoldShopCatalog := preload("res://src/core/gold_shop_catalog.gd")
var _gold_shop_uncertain := false

## Preview credit uses the same wallet as upgrades. A full pack is saved once,
## or the balance is left unchanged. Real payments must never call this path.
func buy_preview_gold(amount: int) -> String:
	if not GoldShopCatalog.enabled() or amount not in GoldShopCatalog.PACKS: return "unavailable"
	if read_only: return "read_only"
	if _gold_shop_uncertain: return "save_uncertain"
	var old := int(progress.coins)
	if amount > _coins_cap() - old: return "wallet_full"
	progress.coins = old + amount
	if save_progress(): return "ok"
	progress.coins = old
	_gold_shop_uncertain = last_failure_uncertain
	return "save_uncertain" if _gold_shop_uncertain else "save_failed"

func set_setting(key: String, value: Variant) -> void:
	progress.settings[key] = value
	save_progress()
