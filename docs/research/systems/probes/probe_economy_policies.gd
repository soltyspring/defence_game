extends SceneTree
## Read-only research probe (10-research-systems): economy yardstick for 01's "upgrade-gated" round design.
## For each round r01..rNN, at round ENTRY (after the previous rounds' first clears), three purchase policies:
##   P0 none       : never buy. Coins accumulate (first-clear coins only).
##   P1 first-clear: income = first-clear coins only; before each round buy greedily the cheapest available next level.
##   P2 max        : income = first-clear + first 3-star bonus + scripted kill coins (ASSUME: every wave/HP-trigger
##                   spawn killed once; trickle/summons excluded); same cheapest-first rule. Cheapest-first maximises
##                   the NUMBER of levels for a budget because costs never decrease within a track (exchange
##                   argument). "Max" means max level count, not proven best for winning.
## Availability: unit tracks need unit.unlock_round <= round index; energy needs a skill unlocked; others always
## (same rule that reproduces 01's upgrade_budgets.json). No battle is simulated; no play time, win rate or retention.
## Output: "EP <json>" rows and "PROBE10_ECON_POLICIES <json>". Exit 0. Writes nothing.
## Run via docs/research/systems/probes/run_economy_policies.ps1 (snapshot, no autoloads).

var units := {}
var skills := {}
var rounds := {}
var order: Array = []
var ups: Array = []

func _load(p: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null

func _visible(up: Dictionary, k: int) -> bool:
	var t := str(up.target)
	if t.begins_with("unit:"):
		var u = units.get(t.substr(5))
		return u != null and int(u.get("unlock_round", 1)) <= k
	if t == "resource:energy":
		for s in skills.values():
			if int(s.get("unlock_round", 1)) <= k: return true
		return false
	return true

func _kills(r: Dictionary) -> int:
	var tot := 0
	var lists: Array = []
	for w in r.get("waves", []): lists.append(w.get("spawns", []))
	for h in r.get("enemy_base_spawns_on_hp", []): lists.append(h.get("spawns", []))
	for l in lists:
		for sp in l:
			var u = units.get(str(sp.get("unit", "")))
			if u != null: tot += int(sp.get("count", 1)) * int(u.get("kill_coins", 0))
	return tot

func _mult(up: Dictionary, lv: int, key: String) -> float:
	return 1.0 + float(up.get("per_level", {}).get(key, 0.0)) * (lv - 1)

func _policy(name: String) -> Array:
	var level := {}
	for up in ups: level[str(up.id)] = 1
	var coins := 0
	var rows: Array = []
	for k in range(1, order.size() + 1):
		var rid := str(order[k - 1])
		if k >= 2:
			var prev: Dictionary = rounds[str(order[k - 2])]
			var rw: Dictionary = prev.get("reward", {})
			coins += int(rw.get("first_clear_coins", rw.get("coins", 0)))
			if name == "P2_max":
				coins += int(rw.get("three_star_bonus_coins", 0)) + _kills(prev)
		var entry := coins
		var bought := 0
		if name != "P0_none":
			while true:
				var best = null
				var bc := 1 << 30
				for up in ups:
					var lv: int = level[str(up.id)]
					if lv >= int(up.max_level) or not _visible(up, k): continue
					var c := int(up.costs[lv - 1])
					if c <= coins and c < bc: best = up; bc = c
				if best == null: break
				coins -= bc
				level[str(best.id)] += 1
				bought += 1
		var r: Dictionary = rounds[rid]
		var sc: Dictionary = r.get("enemy_scaling", {})
		var card_hp: Array = []
		for c in r.get("cards", []):
			for up in ups:
				if str(up.target) == "unit:" + str(c): card_hp.append(_mult(up, int(level[str(up.id)]), "hp_mult"))
		var mean_hp := 1.0
		if not card_hp.is_empty():
			mean_hp = 0.0
			for x in card_hp: mean_hp += x
			mean_hp /= card_hp.size()
		var hero_mult := 1.0
		for up in ups:
			if str(up.target).begins_with("hero:"): hero_mult = _mult(up, int(level[str(up.id)]), "hp_mult")
		var lv_str := []
		for up in ups:
			if int(level[str(up.id)]) > 1: lv_str.append("%s%d" % [str(up.id).replace("up_", ""), int(level[str(up.id)])])
		var total_lv := 0
		for v in level.values(): total_lv += int(v) - 1
		rows.append({"round": rid, "coins_at_entry": entry, "bought_now": bought, "left_after": coins, "levels_total": total_lv,
			"levels": " ".join(lv_str), "card_hp_mult_mean": snappedf(mean_hp, 0.001), "hero_mult": snappedf(hero_mult, 0.001),
			"enemy_hp": float(sc.get("hp", 1.0)), "enemy_atk": float(sc.get("atk", 1.0)),
			"card_minus_enemy_hp": snappedf(mean_hp - float(sc.get("hp", 1.0)), 0.001)})
	return rows

func _initialize() -> void:
	for u in _load("res://data/units/units.json").get("units", []): units[str(u.id)] = u
	for fn in DirAccess.get_files_at("res://data/skills"):
		if fn.ends_with(".json"):
			var s = _load("res://data/skills/" + fn); skills[str(s.id)] = s
	order = _load("res://data/rounds/order.json").get("rounds", [])
	for rid in order: rounds[str(rid)] = _load("res://data/rounds/%s.json" % rid)
	ups = _load("res://data/meta.json").get("upgrades", [])
	var total := 0
	for up in ups:
		for c in up.costs: total += int(c)
	var summary := {"rounds": order.size(), "total_upgrade_cost": total}
	for pname in ["P0_none", "P1_first_clear", "P2_max"]:
		var rows := _policy(pname)
		for r in rows: print("EP ", JSON.stringify({"policy": pname, "row": r}))
		summary[pname + "_levels_before_last"] = rows[-1].levels_total
	print("PROBE10_ECON_POLICIES ", JSON.stringify(summary))
	quit(0)
