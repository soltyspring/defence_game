extends SceneTree
## Read-only research probe (10-research-systems): meta-coin faucets and sinks for r01..r10 computed ONLY from
## data/** (+ 01's docs/design/balance/upgrade_budgets.json for comparison). No simulation, no play time,
## no retention. Writes nothing.
## Run:
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_economy_flow.gd --quit-after 600
## Output lines: "EF <section> <json>" and a final "PROBE10_ECONOMY_FLOW <json>". Exit 0.
##
## Provenance labels used in the output:
##   DATA   = read directly from data/** or arithmetic on it.
##   RULE   = reward rule from src/core/app.gd _on_battle_finished (first clear replaces coins; 3-star bonus once;
##            kill_coins added on win; loss keeps loss_coin_ratio of kill coins) and meta.json upgrade_rules.
##   ASSUME = an assumption chosen here (named in each block).
##   INTENT = a design intention quoted from docs/design/ECONOMY.md text (not a data file).

const INTENT_CHECKPOINTS := {"r03": 240, "r05": 660, "r10": 2500}   # ECONOMY.md §2 "Intended spend checkpoints: before R3 ≈ 240, before R5 ≈ 660, before R10 ≈ 2,500"

var units := {}
var skills := {}
var rounds := {}
var order: Array = []
var meta := {}
var econ := {}

func _load(p: String) -> Variant:
	if not FileAccess.file_exists(p): return null
	return JSON.parse_string(FileAccess.get_file_as_string(p))

func _emit(section: String, d: Variant) -> void:
	print("EF %s %s" % [section, JSON.stringify(d)])

func _visible(up: Dictionary, k: int) -> bool:
	# ASSUME(visibility): meta.json says "visible only when its target is unlocked". Interpreted as: before playing
	# round index k, unit:<id> is visible if unit.unlock_round <= k; resource:energy if any skill has
	# unlock_round <= k; hero/supply/worker/base always. Checked against 01's budgets below.
	var t := str(up.target)
	if t.begins_with("unit:"):
		var u = units.get(t.substr(5))
		return u != null and int(u.get("unlock_round", 1)) <= k
	if t == "resource:energy":
		for s in skills.values():
			if int(s.get("unlock_round", 1)) <= k: return true
		return false
	return true

func _kill_ceiling(r: Dictionary) -> int:
	# ASSUME(kills): every SCRIPTED spawn (waves + enemy_base_spawns_on_hp) is killed once. Trickle and boss summons
	# are time-dependent and excluded, so this is neither a minimum nor a maximum of real play. It is the scripted part only.
	var tot := 0
	var lists: Array = []
	for w in r.get("waves", []): lists.append(w.get("spawns", []))
	for h in r.get("enemy_base_spawns_on_hp", []): lists.append(h.get("spawns", []))
	for sp_list in lists:
		for sp in sp_list:
			var u = units.get(str(sp.get("unit", "")))
			if u != null: tot += int(sp.get("count", 1)) * int(u.get("kill_coins", 0))
	return tot

func _greedy(with_star: bool, extra_per_round: Dictionary) -> Dictionary:
	# Replicates 01's policy text in upgrade_budgets.json: "before each round, greedily buy the cheapest affordable
	# unlocked upgrade (ties: meta.json order)". Income before round k = rewards of round k-1 (first clear [+3-star]).
	var ups: Array = meta.get("upgrades", [])
	var level := {}
	for up in ups: level[str(up.id)] = int(meta.get("upgrade_level_start", 1))
	var bal := 0
	var spent_levels := 0
	var out := {}
	for k in range(1, order.size() + 1):
		if k >= 2:
			var prev: Dictionary = rounds[str(order[k - 2])].get("reward", {})
			bal += int(prev.get("first_clear_coins", prev.get("coins", 0)))
			if with_star: bal += int(prev.get("three_star_bonus_coins", 0))
			bal += int(extra_per_round.get(str(order[k - 2]), 0))
		while true:
			var best = null
			var best_cost := 1 << 30
			for up in ups:
				var id := str(up.id)
				var lv: int = level[id]
				if lv >= int(up.max_level) or not _visible(up, k): continue
				var c := int(up.costs[lv - 1])
				if c <= bal and c < best_cost:
					best = up
					best_cost = c
			if best == null: break
			bal -= best_cost
			level[str(best.id)] += 1
			spent_levels += 1
		var lv_out := {}
		for id in level:
			if level[id] > 1: lv_out[id] = level[id]
		out[str(order[k - 1])] = {"levels": lv_out, "spent_levels": spent_levels, "leftover": bal}
	return out

func _visible_remaining(k: int, level: Dictionary) -> int:
	var tot := 0
	for up in meta.get("upgrades", []):
		if not _visible(up, k): continue
		var lv: int = level.get(str(up.id), 1)
		for i in range(lv - 1, int(up.max_level) - 1): tot += int(up.costs[i])
	return tot

func _initialize() -> void:
	var ud = _load("res://data/units/units.json")
	for u in ud.get("units", []): units[str(u.id)] = u
	for fn in DirAccess.get_files_at("res://data/skills"):
		if fn.ends_with(".json"):
			var s = _load("res://data/skills/" + fn)
			skills[str(s.id)] = s
	order = _load("res://data/rounds/order.json").get("rounds", [])
	for rid in order: rounds[str(rid)] = _load("res://data/rounds/%s.json" % rid)
	meta = _load("res://data/meta.json")
	econ = _load("res://data/economy.json")
	var budgets = _load("res://docs/design/balance/upgrade_budgets.json")

	# ---- 1. per-round faucets (DATA + RULE; kill column ASSUME) ----
	var rows: Array = []
	var cum_low := 0
	var cum_high := 0
	var kill_by_round := {}
	for i in order.size():
		var rid := str(order[i])
		var r: Dictionary = rounds[rid]
		var rw: Dictionary = r.get("reward", {})
		var fc := int(rw.get("first_clear_coins", rw.get("coins", 0)))
		var rp := int(rw.get("coins", 0))
		var st := int(rw.get("three_star_bonus_coins", 0))
		var kc := _kill_ceiling(r)
		kill_by_round[rid] = kc
		cum_low += fc
		cum_high += fc + st
		rows.append({"round": rid, "first_clear": fc, "replay": rp, "replay_pct_of_first": snappedf(100.0 * rp / maxf(1, fc), 0.1),
			"star3_bonus": st, "kill_scripted_ceiling": kc, "cum_first_clear": cum_low, "cum_first_plus_star": cum_high})
	_emit("faucets", rows)

	# ---- 2. sinks (DATA) ----
	var track_rows: Array = []
	var total_cost := 0
	for up in meta.get("upgrades", []):
		var s := 0
		for c in up.costs: s += int(c)
		total_cost += s
		var unlock := 1
		var t := str(up.target)
		if t.begins_with("unit:"): unlock = int(units[t.substr(5)].get("unlock_round", 1))
		var unlock_rid := str(order[unlock - 1])
		var rp_unlock := int(rounds[unlock_rid].reward.get("coins", 0))
		var rp_last := int(rounds[str(order[-1])].reward.get("coins", 0))
		var per_level: Array = []
		for li in up.costs.size():
			var c := int(up.costs[li])
			per_level.append({"to_level": li + 2, "cost": c,
				"replays_of_unlock_round_from_zero": ceili(float(c) / maxf(1, rp_unlock)),
				"replays_of_last_round_from_zero": ceili(float(c) / maxf(1, rp_last))})
		track_rows.append({"id": str(up.id), "target": t, "visible_from": unlock_rid, "max_level": int(up.max_level),
			"track_total": s, "per_level": per_level})
	_emit("sinks", {"total_cost_all_tracks": total_cost, "tracks": track_rows})

	# ---- 3. totals and full max-out deficit ----
	var last_rp := int(rounds[str(order[-1])].reward.get("coins", 0))
	var last_kc := int(kill_by_round[str(order[-1])])
	var kill_sum := 0
	for v in kill_by_round.values(): kill_sum += int(v)
	var scen := {
		"LOW_first_clear_only": cum_low,
		"HIGH_first_plus_star": cum_high,
		"HIGH_plus_kill_scripted_ceiling": cum_high + kill_sum}
	var maxout := {}
	for name in scen:
		var deficit: int = maxi(0, total_cost - int(scen[name]))
		maxout[name] = {"income_r01_r10": scen[name], "coverage_pct": snappedf(100.0 * scen[name] / total_cost, 0.1), "deficit": deficit,
			"r10_replays_to_max_all (replay coins only)": ceili(float(deficit) / last_rp),
			"r10_replays_to_max_all (replay + scripted kills, ASSUME)": ceili(float(deficit) / (last_rp + last_kc))}
	_emit("maxout", maxout)

	# ---- 4. design-intent checkpoints vs data income (INTENT vs DATA) ----
	var cps: Array = []
	for cp_rid in INTENT_CHECKPOINTS:
		var k := order.find(cp_rid) + 1
		var inc_low := 0
		var inc_high := 0
		var best_replay := 0
		for j in range(k - 1):
			var rw: Dictionary = rounds[str(order[j])].reward
			inc_low += int(rw.get("first_clear_coins", 0))
			inc_high += int(rw.get("first_clear_coins", 0)) + int(rw.get("three_star_bonus_coins", 0))
			best_replay = maxi(best_replay, int(rw.get("coins", 0)))
		var target := int(INTENT_CHECKPOINTS[cp_rid])
		cps.append({"before": cp_rid, "intent_spend": target, "income_low": inc_low, "income_high": inc_high,
			"gap_low": target - inc_low, "gap_high": target - inc_high, "best_replay_available": best_replay,
			"replays_needed_low": maxi(0, ceili(float(target - inc_low) / maxf(1, best_replay))),
			"replays_needed_high": maxi(0, ceili(float(target - inc_high) / maxf(1, best_replay)))})
	_emit("intent_checkpoints", cps)

	# ---- 5. surplus check: could income exceed everything purchasable at that point? ----
	var surplus: Array = []
	var cum := 0
	for k in range(1, order.size() + 1):
		if k >= 2:
			var rw: Dictionary = rounds[str(order[k - 2])].reward
			cum += int(rw.get("first_clear_coins", 0)) + int(rw.get("three_star_bonus_coins", 0)) + int(kill_by_round[str(order[k - 2])])
		var vis := _visible_remaining(k, {})
		surplus.append({"before": str(order[k - 1]), "income_upper_HIGH_plus_kills": cum, "visible_unbought_cost": vis,
			"surplus": cum > vis})
	_emit("surplus", surplus)

	# ---- 6. replicate 01's greedy budgets and diff ----
	var mine := {"low": _greedy(false, {}), "high": _greedy(true, {})}
	var diffs: Array = []
	if budgets is Dictionary:
		for scen_name in ["low", "high"]:
			for rid in mine[scen_name]:
				var a: Dictionary = mine[scen_name][rid]
				var b = budgets.get(scen_name, {}).get(rid)
				if b == null:
					diffs.append({"scenario": scen_name, "round": rid, "diff": "missing in budgets"})
					continue
				var bl := {}
				for k2 in b.levels: bl[str(k2)] = int(b.levels[k2])
				if JSON.stringify(a.levels) != JSON.stringify(bl) and not _same_levels(a.levels, bl) or int(a.leftover) != int(b.leftover) or int(a.spent_levels) != int(b.spent_levels):
					diffs.append({"scenario": scen_name, "round": rid, "probe": a, "budgets": b})
	_emit("budgets_replication", {"matches": diffs.is_empty(), "diff_count": diffs.size(), "diffs": diffs.slice(0, 6),
		"probe_r10_low": mine.low[str(order[-1])], "probe_r10_high": mine.high[str(order[-1])]})
	# what the greedy budgets look like if scripted kill coins are added (ASSUME kills)
	var with_kills := _greedy(true, kill_by_round)
	_emit("budgets_high_plus_kills_r10", with_kills[str(order[-1])])

	print("PROBE10_ECONOMY_FLOW ", JSON.stringify({"total_cost": total_cost, "income_low": cum_low, "income_high": cum_high,
		"kill_scripted_sum": kill_sum, "budgets_match": diffs.is_empty()}))
	quit(0)

func _same_levels(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for k in a:
		if not b.has(k) or int(a[k]) != int(b[k]): return false
	return true
