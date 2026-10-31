extends SceneTree
## 04-client REAL-ENGINE test of the menu notice for a content migration (01 D32, 02 52f9fa3). Exit 0 = pass.
##   Run it only with a private APPDATA (it writes user:// files), e.g. inside coordination/heavy_run_detached.ps1:
##   . .\tools\build\common.ps1; $p = Enter-IsolatedAppData "$PWD\build\godot_appdata_mig"; & $GodotConsole --headless --path . -s res://tests/integration/test_migration_notice.gd; Exit-IsolatedAppData $p
##   (tools/build/verify_and_publish.ps1 runs it that way.)
## Data changes are emulated IN MEMORY on the Content autoload, the same way as 02's selftest _check_content_migration
## (meta + content_version, restored at the end); data files are never written. The save lives in a per-process
## user:// file; 04 runners also give Godot a private APPDATA (be2abb3), so the real player save is never touched.
## Checks: buy up_melee_basic to its cap → lower the cap by 1 → Save migrates (1 level, refund of the paid price) →
## the real App mounts the 04 menu → the notice shows 01's text with those numbers → "relaunch" before the ack
## (save re-read from disk, App session flag reset, menu remounted) shows it AGAIN → close sends
## cmd_ack_content_migrated → the save file no longer holds it → relaunch after the ack shows nothing.

var TEST_SAVE := "user://test_migration_notice_%d.json" % OS.get_process_id()
const UP := "up_melee_basic"
var failures := PackedStringArray()
var passes := 0
var app: Node
var events: Node
var save: Node
var content: Node
var emitted := []
var acks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  ok   " + msg)
	else:
		failures.append(msg)
		printerr("FAIL: " + msg)

func _frames(n := 2) -> void:
	for i in n:
		await process_frame

func _menu() -> Control:
	for c in app.ui_layer.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path == "res://src/ui/main_menu.gd" and not c.is_queued_for_deletion():
			return c
	return null

func _up_def(meta: Dictionary, id: String) -> Dictionary:
	for u in meta.get("upgrades", []):
		if u is Dictionary and str(u.get("id", "")) == id:
			return u
	return {}

## The save file is an envelope {"version", "checksum", "payload": "<progress JSON text>"} (save.gd _write).
func _file_has_notice() -> bool:
	var env = JSON.parse_string(FileAccess.get_file_as_string(save.path))
	if not (env is Dictionary) or not (env.get("payload") is String):
		return false
	var p = JSON.parse_string(env.payload)
	return p is Dictionary and (p as Dictionary).has("migration_notice")

## "Relaunch": read the save from disk again and remount the menu in a new App session (the per-session flag reset).
func _relaunch() -> Control:
	save.load_progress()
	app._migration_notice_sent = false
	app.show_screen(&"menu")
	await _frames(3)
	return _menu()

func _run() -> void:
	app = root.get_node_or_null("App")
	events = root.get_node_or_null("Events")
	save = root.get_node_or_null("Save")
	content = root.get_node_or_null("Content")
	if app == null or events == null or save == null or content == null:
		check(false, "autoloads App/Events/Save/Content present"); _finish(); return
	print("[migration_notice] user_data_dir=%s" % OS.get_user_data_dir())
	check(events.has_signal("content_migrated") and events.has_signal("cmd_ack_content_migrated") and save.has_method("migration_notice"),
		"engine exposes content_migrated / cmd_ack_content_migrated / Save.migration_notice (02 52f9fa3)")
	events.content_migrated.connect(func(info): emitted.append(info))
	events.cmd_ack_content_migrated.connect(func(): acks += 1)
	var orig_meta: Dictionary = content.meta.duplicate(true)
	var orig_cv: String = content.content_version
	# 1) a save that owns the top level of UP
	save.path = TEST_SAVE
	for f in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	save.load_progress()
	var def := _up_def(orig_meta, UP)
	var max_l := int(def.get("max_level", 1))
	var costs: Array = def.get("costs", [])
	save.progress.coins = 5000
	save.progress.unlocked_round = 10
	save.save_progress()
	var codes := []
	for L in range(2, max_l + 1):
		codes.append(save.buy_upgrade(UP, L))
	check(save.upgrade_level(UP) == max_l and not codes.has("save_failed"), "bought %s to its cap %d (%s)" % [UP, max_l, codes])
	var top_price := int(costs[max_l - 2])
	# 2) emulate a data update that lowers the cap by one (02 selftest _mig_data), then load
	content.meta = orig_meta.duplicate(true)
	content.content_version = orig_cv + "-04test"
	var u := _up_def(content.meta, UP)
	u.max_level = max_l - 1
	u.costs = (u.costs as Array).slice(0, max_l - 2)
	save.load_progress()
	var n: Dictionary = save.migration_notice()
	check(int(n.get("levels", -1)) == 1 and int(n.get("coins", -1)) == top_price, "migration notice pending: 1 level, refund %d (got %s)" % [top_price, n])
	check(_file_has_notice(), "notice persisted in the save file before any UI")
	# 3) first launch: the real App mounts the 04 menu and shows the notice
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await _frames(4)
	var m := _menu()
	check(m != null, "04 main menu mounted by the real App")
	if m == null:
		_restore(orig_meta, orig_cv); _finish(); return
	var want: String = load("res://src/ui/notice_dialog.gd").format_notice(n)
	check(want.contains(str(top_price)) and want.contains("1") and not want.contains("{"), "01 text formatted with the engine numbers: '%s'" % want)
	check(m.notice_dialog.visible and m.notice_dialog.text == want, "menu shows the notice once (visible=%s, '%s')" % [m.notice_dialog.visible, m.notice_dialog.text])
	check(emitted.size() == 1, "App emitted content_migrated once this session (%d)" % emitted.size())
	var dlg: Control = m.notice_dialog
	var vs: Vector2 = root.get_visible_rect().size
	check(not dlg.truncated and dlg.lines.size() <= 3 and Rect2(Vector2.ZERO, vs).encloses(dlg.panel), "notice fits: %d line(s), not truncated, panel %s inside %s" % [dlg.lines.size(), dlg.panel, vs])
	# 4) quit BEFORE the ack, then relaunch: shown again
	check(acks == 0 and _file_has_notice(), "no ack yet; notice still in the file")
	m = await _relaunch()
	check(m != null and m.notice_dialog.visible and m.notice_dialog.text == want, "relaunch before the ack: notice shown again")
	check(emitted.size() == 2, "content_migrated emitted again in the new session (%d)" % emitted.size())
	# 5) close → ack → cleared in memory and on disk
	m.notice_dialog.btn_close.tapped.emit()
	await _frames(2)
	check(acks == 1 and m.migration_acks == 1 and not m.notice_dialog.visible, "close sends cmd_ack_content_migrated once (acks=%d) and hides the notice" % acks)
	check(save.migration_notice().is_empty() and not _file_has_notice(), "ack clears the notice in memory and in the save file")
	# 6) relaunch after the ack: nothing
	m = await _relaunch()
	check(m != null and not m.notice_dialog.visible and emitted.size() == 2, "relaunch after the ack: no notice (emits=%d)" % emitted.size())
	# 7) Android back on the notice = seen (ack), and never opens the quit dialog with the same press
	save.progress["migration_notice"] = {"levels": 2, "coins": 50, "from": "a", "to": "b"}
	save.save_progress()
	m = await _relaunch()
	load("res://src/ui/ui_screen.gd").reset_back_claim()
	m._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	check(not m.notice_dialog.visible and not m.quit_layer.visible and acks == 2 and save.migration_notice().is_empty(), "back closes the notice and acks (acks=%d), quit dialog stays closed" % acks)
	_restore(orig_meta, orig_cv)
	_finish()

func _restore(meta: Dictionary, cv: String) -> void:
	content.meta = meta
	content.content_version = cv

func _finish() -> void:
	for f in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	# 10 v0.33 P3: Save also keeps a pre-migration copy "<name>.pre-<content_version>.json"; the pid in the name means
	# save.gd's keep-2 pruning never removes it, so delete this run's copies here.
	var pre := TEST_SAVE.get_file().get_basename() + ".pre-"
	var d := DirAccess.open("user://")
	if d != null:
		for fn in d.get_files():
			if fn.begins_with(pre) and fn.ends_with(".json"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + fn))
		var left := 0
		for fn in d.get_files():
			if fn.begins_with(TEST_SAVE.get_file().get_basename()):
				left += 1
		check(left == 0, "no test save files left in user:// (left=%d)" % left)
	print("[migration_notice] passed=%d failed=%d" % [passes, failures.size()])
	quit(1 if failures.size() > 0 else 0)
