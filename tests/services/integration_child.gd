extends SceneTree
## Child process for test_services_integration.gd process-death rows (R4, R5, R7).
## Runs with the game's autoloads. Uses the AUTOLOAD Save (/root/Save) redirected to an isolated
## directory, and the game's own service store if 02 has integrated Services (binding "game"),
## otherwise a save_bridge store on the autoload Save (binding "bridge_simulated").
## A MOCK service bundle is built on that store for the grant; the game's Services node, if any,
## stays in its own (disabled) mode. Kills itself with OS.kill(own pid) at the chosen phase.
## Args: -- --dir=user://... --phase=kill_before_commit|kill_after_commit|sink_saves_then_kill

const Factory := preload("res://src/services/services_factory.gd")
const Bridge := preload("res://src/services/save_bridge.gd")

var dir := ""
var phase := ""
var simulate := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): dir = a.substr(6)
		elif a.begins_with("--phase="): phase = a.substr(8)
		elif a == "--simulate-integration": simulate = true
	_run.call_deferred()

func _marker(text: String) -> void:
	var f := FileAccess.open(dir + "/phase.txt", FileAccess.WRITE)
	f.store_string(text)
	f.flush()
	f.close()

func _die() -> void:
	OS.kill(OS.get_process_id())
	OS.delay_msec(5000)
	quit(3)

static func game_store(tree_root: Node, save: Node):
	var svc = tree_root.get_node_or_null("Services")
	if svc == null or not ("bundle" in svc) or not (svc.bundle is Dictionary):
		return null
	if svc.has_method("ensure_bound"):
		svc.ensure_bound()   # what the game's next frame would do after a reload
	var st = svc.bundle.get("store")
	if st == null or not st.is_persistent() or not is_same(st.data, save.progress.get("services")):
		return null
	return st

func _run() -> void:
	var save = root.get_node_or_null("Save")
	if save == null:
		_marker("no_save_autoload")
		quit(5)
		return
	if simulate and root.get_node_or_null("Services") == null:
		var n = load("res://src/services/services.gd").new()
		n.name = "Services"
		root.add_child(n)
	save.path = dir + "/save.json"
	save.load_progress()
	var store = game_store(root, save)
	var binding := "services_node_simulated" if simulate else "game"
	if store == null:
		binding = "bridge_simulated"
		store = Bridge.make_store(save, root.get_node_or_null("Events"))
	var b := Factory.create({"mode": "mock", "allow_mock": true, "debug_build": true, "store": store,
		"overrides": {"ads": {"enabled": true, "placements": {"ad_double_gold": {"daily_cap": 100, "reward": {"effect": "gold_mult_2", "where": "results_win"}}}}}})
	b.consent.set_choice("ads", "granted")
	match phase:
		"kill_before_commit", "sink_saves_then_kill":
			store.commit_fn = func() -> bool:
				_marker(phase + " binding=" + binding)
				_die()
				return false
		"kill_after_commit":
			b.ads.reward_granted.connect(func(_p, _r, _c, persisted):
				_marker("after_commit persisted=%s binding=%s" % [str(persisted), binding])
				_die())
	b.ads.grant_sink = func(_p, _r, _c) -> bool:
		save.progress["coins"] = int(save.progress["coins"]) + 100
		if phase == "sink_saves_then_kill":
			save.save_progress()
		return true
	b.ads.request("ad_double_gold", "result:death")
	for i in 40:
		b.ads.tick(0.0)
	_marker("no_kill binding=" + binding)
	quit(4)
