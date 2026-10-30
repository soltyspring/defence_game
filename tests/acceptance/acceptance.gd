extends SceneTree
## 07-qa acceptance runner (headless). Exit code: 0 = no FAIL, 1 = at least one FAIL, 2 = watchdog/crash.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/acceptance/acceptance.gd -- --qa-out=<abs dir> [--only=data,assets,sim,save,flow,release]
## Preferred entry: tools/qa/run_acceptance.ps1 (lock + logs under build/qa07/, git-ignored).
## Writes <out>/acceptance_report.json and acceptance_report.md. Never touches user://save.json.
## Owner: 07-qa.

const Q := preload("res://tests/acceptance/qa_lib.gd")
const SUITES := ["data", "assets", "sim", "save", "faults", "flow", "release"]

var q = Q.new()
var out_dir := "user://qa07"
var only: Array = []
var t0 := 0
var _done := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-out="): out_dir = a.get_slice("=", 1)
		if a.begins_with("--only="): only = Array(a.get_slice("=", 1).split(","))
	t0 = Time.get_ticks_msec()
	# isolate the Save autoload from the developer's real save before anything can write it
	var save := root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://qa07")
		save.path = "user://qa07/flow_save.json"
	_watchdog.call_deferred()
	_run.call_deferred()

func _watchdog() -> void:
	await create_timer(900.0).timeout
	if not _done:
		q.current_suite = "runner"
		q.record("RUN-WATCHDOG", Q.FAIL, "acceptance run finished within 900 s", "watchdog fired; a suite hung")
		_write()
		quit(2)

func _run() -> void:
	print("[acceptance] godot=%s display=%s out=%s" % [Engine.get_version_info().string, DisplayServer.get_name(), out_dir])
	for s in SUITES:
		if not only.is_empty() and not only.has(s):
			continue
		var script = load("res://tests/acceptance/suite_%s.gd" % s)
		if script == null or not script.can_instantiate():
			q.current_suite = s
			q.record("RUN-%s" % s.to_upper(), Q.FAIL, "suite_%s.gd loads" % s, "parse/compile error (see godot.log)")
			continue
		var suite = script.new()
		if s == "flow":
			suite.report_cb = _write
		var n0: int = q.results.size()
		await suite.run(q, self)
		print("[acceptance] suite %s: %d checks" % [s, q.results.size() - n0])
	_done = true
	_write()
	var c: Dictionary = q.counts()
	print("[acceptance] PASS=%d FAIL=%d NOT_IMPLEMENTED=%d NOT_TESTED=%d BLOCKED=%d (%d ms)" % [c.PASS, c.FAIL, c.NOT_IMPLEMENTED, c.NOT_TESTED, c.BLOCKED, Time.get_ticks_msec() - t0])
	quit(1 if q.failed() else 0)

func _write() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var meta := {"generated_unix": Time.get_unix_time_from_system(), "godot": Engine.get_version_info().string,
		"display": DisplayServer.get_name(), "os": OS.get_name(), "elapsed_ms": Time.get_ticks_msec() - t0,
		"counts": q.counts(), "scope": "desktop headless acceptance; NOT Android device certification"}
	var f := FileAccess.open(out_dir.path_join("acceptance_report.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"meta": meta, "results": q.results}, "  "))
		f.close()
	var md := "# Acceptance report (generated)\n\n%s\n\n| ID | Suite | Status | Check | Detail |\n|---|---|---|---|---|\n" % JSON.stringify(meta.counts)
	for r in q.results:
		md += "| %s | %s | %s | %s | %s |\n" % [r.id, r.suite, r.status, str(r.title).replace("|", "/"), str(r.detail).replace("|", "/").replace("\n", " ").left(300)]
	var g := FileAccess.open(out_dir.path_join("acceptance_report.md"), FileAccess.WRITE)
	if g:
		g.store_string(md)
		g.close()
