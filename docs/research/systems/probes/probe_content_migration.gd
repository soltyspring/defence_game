extends SceneTree
## Research probe (10-research-systems): what happens to an EXISTING save when the content data changes
## (post-launch rebalance). Uses the real autoloads (Content, Save) and BattleSim. Never touches the real
## save: it reads/writes only the --fixture path given on the command line. Intended to be run by the
## PowerShell driver in DATA_AND_BACKEND_ANALYSIS.md §9.6 inside throwaway snapshot copies, one copy per data
## mutation (round removed / added / reordered, upgrade max_level lowered, unit id renamed, upgrade id renamed).
## Modes (user args after --):
##   --mode=make --fixture=<abs path>   write a legacy save under the current (baseline) data
##   --mode=load --fixture=<abs path> --label=<name>   load that save under the current (mutated) data,
##                                      report, then save + reload once to see what is persisted
## Prints "PROBE10_MIGRATION <json>" and exits 0.

const SimS := preload("res://src/gameplay/battle_sim.gd")
const FIXTURE_PROGRESS := {
	"unlocked_round": 7, "coins": 1234, "clears": 20,
	"stars": {"r01": 3, "r02": 3, "r03": 2, "r04": 3, "r05": 1, "r06": 2},
	"best_time": {"r01": 90.0, "r02": 120.0, "r03": 150.0, "r04": 170.0, "r05": 230.0, "r06": 240.0},
	"upgrades": {"up_melee_basic": 5, "up_ranged_basic": 3, "up_tank": 2},
	"applied_battles": ["fixture-b1", "fixture-b2"], "tutorial_done": ["tut_move_hero"]}

var args := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var save := root.get_node_or_null("Save")
	if save: save.path = str(args.get("fixture", "user://probe10_unused.json"))
	_run.call_deferred()

func _snapshot(save, content) -> Dictionary:
	var order: Array = content.round_order
	var per_round: Array = []
	var cleared_but_locked: Array = []
	var unlocked_without_clear_prev: Array = []
	for i in order.size():
		var rid := str(order[i])
		var un: bool = save.is_unlocked(i)
		var has_star: bool = save.progress.stars.has(rid)
		per_round.append([rid, un, int(save.progress.stars.get(rid, 0))])
		if has_star and not un: cleared_but_locked.append(rid)
		if un and i > 0 and not save.progress.stars.has(str(order[i - 1])): unlocked_without_clear_prev.append(rid)
	var orphan_stars: Array = []
	for k in save.progress.stars:
		if not order.has(str(k)): orphan_stars.append(str(k))
	var meta_ids := {}
	for u in content.meta.get("upgrades", []): meta_ids[str(u.id)] = u
	var orphan_ups: Array = []
	var over_max := {}
	var eff := {}
	var sim = SimS.new()
	sim.setup(content, str(order[0]), 1, save.progress.upgrades)
	for k in save.progress.upgrades:
		if not meta_ids.has(str(k)):
			orphan_ups.append(str(k))
			continue
		var u: Dictionary = meta_ids[str(k)]
		var lv := int(save.progress.upgrades[k])
		if lv > int(u.max_level): over_max[str(k)] = [lv, int(u.max_level)]
		var t := str(u.target)
		if t.begins_with("unit:") and content.units.has(t.substr(5)):
			eff[str(k)] = snappedf(sim._upgrade_mult(t, "hp_mult"), 0.0001)
	var total_stars := 0
	for k in save.progress.stars:
		if order.has(str(k)): total_stars += int(save.progress.stars[k])
	return {"order": order, "unlocked_round": int(save.progress.unlocked_round), "coins": int(save.progress.coins),
		"rounds": per_round, "cleared_but_locked": cleared_but_locked, "unlocked_without_clearing_previous": unlocked_without_clear_prev,
		"orphan_stars_kept": orphan_stars, "chapter_stars_counted": total_stars,
		"upgrades": save.progress.upgrades.duplicate(), "orphan_upgrades_kept": orphan_ups, "levels_above_max": over_max,
		"engine_hp_mult": eff, "content_version_in_save": save.progress.has("content_version"),
		"recovered": save.recovered, "read_only": save.read_only}

func _run() -> void:
	var save = root.get_node_or_null("Save")
	var content = root.get_node_or_null("Content")
	var out := {"mode": str(args.get("mode", "")), "label": str(args.get("label", "")), "fixture": str(args.get("fixture", ""))}
	if save == null or content == null or out.fixture == "":
		out.error = "missing Save/Content or --fixture"
		print("PROBE10_MIGRATION ", JSON.stringify(out)); quit(0); return
	if out.mode == "make":
		save.progress = save.fresh()
		for k in FIXTURE_PROGRESS: save.progress[k] = FIXTURE_PROGRESS[k].duplicate(true) if FIXTURE_PROGRESS[k] is Dictionary or FIXTURE_PROGRESS[k] is Array else FIXTURE_PROGRESS[k]
		out.saved = save.save_progress()
		out.state = _snapshot(save, content)
	else:
		save.load_progress()
		out.after_load = _snapshot(save, content)
		out.saved_again = save.save_progress()
		save.load_progress()
		out.after_save_reload = _snapshot(save, content)
		out.content_warnings = content.warnings.slice(0, 5)
	print("PROBE10_MIGRATION ", JSON.stringify(out))
	quit(0)
