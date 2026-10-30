extends SceneTree
## Child process for test_services_m3.gd "process death" cases. Not a standalone test.
## Uses the REAL src/core/save.gd at an isolated user:// directory, grants one rewarded-ad
## context through mock services, and kills ITSELF (OS.kill on own pid) at a chosen phase:
##   kill_before_commit   sink applied reward in memory, process dies before the service commit
##   kill_after_commit    service commit succeeded, process dies right after
##   sink_saves_then_kill sink saves on its own (contract violation), process dies before commit
## Writes <dir>/phase.txt just before dying so the parent can prove the phase was reached.
## Args: -- --dir=user://... --phase=... --ctx=...

const SaveScript := preload("res://src/core/save.gd")
const EventsScript := preload("res://src/core/events.gd")
const Factory := preload("res://src/services/services_factory.gd")
const Bridge := preload("res://src/services/save_bridge.gd")

var dir := ""
var phase := ""
var ctx := "result:child"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): dir = a.substr(6)
		elif a.begins_with("--phase="): phase = a.substr(8)
		elif a.begins_with("--ctx="): ctx = a.substr(6)
	_run.call_deferred()

func _marker(text: String) -> void:
	var f := FileAccess.open(dir + "/phase.txt", FileAccess.WRITE)
	f.store_string(text)
	f.flush()
	f.close()

func _die() -> void:
	OS.kill(OS.get_process_id())
	OS.delay_msec(5000)   # never reached if the kill works
	quit(3)

func _run() -> void:
	var ev = root.get_node_or_null("Events")
	if ev == null:
		ev = EventsScript.new()
		ev.name = "Events"
		root.add_child(ev)
	var save = SaveScript.new()
	save.path = dir + "/save.json"
	root.add_child(save)
	save.load_progress()
	var store = Bridge.make_store(save, ev)
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": store,
		"overrides": {"ads": {"enabled": true, "placements": {"ad_double_gold": {"daily_cap": 100, "reward": {"effect": "gold_mult_2", "where": "results_win"}}}}}})
	b.consent.set_choice("ads", "granted")
	var real_commit: Callable = store.commit_fn
	match phase:
		"kill_before_commit":
			store.commit_fn = func() -> bool:
				_marker("before_commit")
				_die()
				return false
		"kill_after_commit":
			b.ads.reward_granted.connect(func(_p, _r, _c, persisted):
				_marker("after_commit persisted=%s" % str(persisted))
				_die())
		"sink_saves_then_kill":
			store.commit_fn = func() -> bool:
				_marker("sink_saved_then_before_commit")
				_die()
				return false
	b.ads.grant_sink = func(_p, _r, _c) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + 100
		if phase == "sink_saves_then_kill":
			save.save_progress()   # real atomic save by the sink itself
		return true
	b.ads.request("ad_double_gold", ctx)
	for i in 40:
		b.ads.tick(0.0)
	_marker("no_kill")
	quit(4)
