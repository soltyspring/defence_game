extends SceneTree
## Read-only research probe (10-research-systems): what each meta-upgrade level does in battle, computed with
## the REAL engine code (src/gameplay/battle_sim.gd setup/deploy/_spawn_enemy/income) on data/** only.
## No battle is simulated over time, no win rate, play time or retention. Writes nothing.
## Run (needs no autoloads):
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://docs/research/systems/probes/probe_upgrade_effect.gd --quit-after 600
## Output: "UE <section> <json>" lines and "PROBE10_UPGRADE_EFFECT <json>". Exit 0.
## Labels: ENGINE = value read from a BattleSim instance; DATA = data arithmetic;
## FORMULA = hits = ceil(target_hp / max(1, atk - target_armor)) from battle_sim._damage (ignores aura, rally,
## crit, knockback, splash, focus fire); ASSUME = worker counts 0/3/max for income; LOWPATH = 01's greedy
## LOW first-clear purchase path (upgrade_budgets.json policy, reproduced in probe_economy_flow).

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")

var content
var ups: Array = []

func _emit(s: String, d) -> void:
	print("UE %s %s" % [s, JSON.stringify(d)])

func _sim(rid: String, levels: Dictionary):
	var s = SimS.new()
	s.setup(content, rid, 1, levels)
	return s

func _ally(rid: String, uid: String, levels: Dictionary) -> Dictionary:
	var s = _sim(rid, levels)
	s.gold = 1e9
	s.card_cd[uid] = 0.0          # allow any player unit for measurement, even if not a card in this round
	if s.deploy(uid) != "": return {}
	var u = s.players.back()
	return {"hp": u.hp_max, "atk": u.atk, "armor": float(u.def.get("armor", 0.0))}

func _enemy(rid: String, eid: String) -> Dictionary:
	var s = _sim(rid, {})
	var u = s._spawn_enemy(eid)
	return {"hp": u.hp_max, "atk": u.atk, "armor": float(u.def.get("armor", 0.0))}

func _hits(hp: float, atk: float, armor: float) -> int:
	return ceili(hp / maxf(1.0, atk - armor))

func _round_enemies(r: Dictionary) -> Array:
	var ids := {}
	for w in r.get("waves", []):
		for sp in w.get("spawns", []): ids[str(sp.unit)] = true
	for h in r.get("enemy_base_spawns_on_hp", []):
		for sp in h.get("spawns", []): ids[str(sp.unit)] = true
	for p in r.get("trickle", {}).get("pattern", []): ids[str(p)] = true
	for id in ids.keys():
		var sm = content.get_unit(id).get("summon")
		if sm is Dictionary: ids[str(sm.unit)] = true
	var out := ids.keys()
	out.sort()
	return out

func _visible(up: Dictionary, k: int) -> bool:
	var t := str(up.target)
	if t.begins_with("unit:"): return int(content.get_unit(t.substr(5)).get("unlock_round", 1)) <= k
	if t == "resource:energy":
		for s in content.skills.values():
			if int(s.get("unlock_round", 1)) <= k: return true
		return false
	return true

func _lowpath() -> Dictionary:
	var level := {}
	for up in ups: level[str(up.id)] = 1
	var bal := 0
	var out := {}
	var order: Array = content.round_order
	for k in range(1, order.size() + 1):
		if k >= 2:
			var rw: Dictionary = content.get_round(str(order[k - 2])).get("reward", {})
			bal += int(rw.get("first_clear_coins", rw.get("coins", 0)))
		while true:
			var best = null
			var bc := 1 << 30
			for up in ups:
				var lv: int = level[str(up.id)]
				if lv >= int(up.max_level) or not _visible(up, k): continue
				var c := int(up.costs[lv - 1])
				if c <= bal and c < bc: best = up; bc = c
			if best == null: break
			bal -= bc
			level[str(best.id)] += 1
		out[str(order[k - 1])] = level.duplicate()
	return out

func _initialize() -> void:
	content = ContentS.new()
	content.load_all("res://data")
	ups = content.meta.get("upgrades", [])
	var order: Array = content.round_order
	var last := str(order[-1])

	# ---- 1. per-level stat effect (ENGINE) ----
	var lv_rows: Array = []
	for up in ups:
		var id := str(up.id)
		var t := str(up.target)
		var row := {"id": id, "target": t, "levels": []}
		for L in range(1, int(up.max_level) + 1):
			var lv := {id: L}
			var s = _sim(last, lv)
			var e := {"L": L}
			if t.begins_with("unit:"):
				var a := _ally(last, t.substr(5), lv)
				e.hp = snappedf(a.hp, 0.01); e.atk = snappedf(a.atk, 0.01)
			elif t.begins_with("hero:"):
				e.hp = snappedf(s.hero.hp_max, 0.01); e.atk = snappedf(s.hero.atk, 0.01)
			elif t == "resource:supply":
				e.income_w0 = snappedf(s.income(), 0.01); e.gold_max = s.gold_max
			elif t == "resource:energy":
				e.mana_regen = snappedf(s.mana_regen, 0.01); e.mana_max = s.mana_max
			elif t == "worker":
				for w in [1, 3, int(s.workers_max)]:
					s.workers = w
					e["income_w%d" % w] = snappedf(s.income(), 0.01)
			elif t == "base:player":
				e.base_hp = s.player_base.hp_max
			if L < int(up.max_level): e.next_cost = int(up.costs[L - 1])
			row.levels.append(e)
		lv_rows.append(row)
	_emit("levels_r10_context", lv_rows)

	# ---- 2. supply income share (ENGINE, worker counts ASSUME) ----
	var inc: Array = []
	for L in range(1, 6):
		var s = _sim(last, {"up_supply_regen": L})
		var r := {"supply_L": L}
		for w in [0, 3, int(s.workers_max)]:
			s.workers = w
			r["w%d" % w] = snappedf(s.income(), 0.01)
		inc.append(r)
	_emit("supply_income_by_workers", inc)

	# ---- 3. hit-count breakpoints for unit and hero tracks (ENGINE stats + FORMULA) ----
	var bp: Array = []
	for up in ups:
		var t := str(up.target)
		if not (t.begins_with("unit:") or t.begins_with("hero:")): continue
		var first_round := "r01"
		if t.begins_with("unit:"):
			var ur := int(content.get_unit(t.substr(5)).get("unlock_round", 1))
			first_round = str(order[ur - 1])
		for rid in [first_round, last] if first_round != last else [last]:
			var r: Dictionary = content.get_round(rid)
			for eid in _round_enemies(r):
				var en := _enemy(rid, eid)
				var off: Array = []
				var dfn: Array = []
				for L in range(1, int(up.max_level) + 1):
					var a: Dictionary
					if t.begins_with("unit:"):
						a = _ally(rid, t.substr(5), {str(up.id): L})
					else:
						var s = _sim(rid, {str(up.id): L})
						a = {"hp": s.hero.hp_max, "atk": s.hero.atk, "armor": float(s.hero.def.get("armor", 0.0))}
					off.append(_hits(en.hp, a.atk, en.armor))
					dfn.append(_hits(a.hp, en.atk, a.armor))
				var off_bp: Array = []
				var def_bp: Array = []
				for i in range(1, off.size()):
					if off[i] < off[i - 1]: off_bp.append(i + 1)
					if dfn[i] > dfn[i - 1]: def_bp.append(i + 1)
				bp.append({"track": str(up.id), "round": rid, "enemy": eid,
					"ally_hits_to_kill": off, "enemy_hits_to_kill_ally": dfn,
					"offense_breakpoint_levels": off_bp, "defense_breakpoint_levels": def_bp})
	_emit("breakpoints", bp)

	# ---- 4. LOW path levels vs that round's enemy scaling (LOWPATH + DATA) ----
	var lp := _lowpath()
	var cmp: Array = []
	for rid in order:
		var r: Dictionary = content.get_round(str(rid))
		var sc: Dictionary = r.get("enemy_scaling", {})
		var lv: Dictionary = lp[str(rid)]
		var unit_mults := {}
		for up in ups:
			var t := str(up.target)
			if t.begins_with("unit:") or t.begins_with("hero:"):
				var L := int(lv[str(up.id)])
				var per: Dictionary = up.get("per_level", {})
				unit_mults[str(up.id)] = {"L": L, "hp": snappedf(1.0 + float(per.get("hp_mult", 0.0)) * (L - 1), 0.001),
					"atk": snappedf(1.0 + float(per.get("atk_mult", 0.0)) * (L - 1), 0.001)}
		cmp.append({"round": str(rid), "enemy_hp": float(sc.get("hp", 1.0)), "enemy_atk": float(sc.get("atk", 1.0)), "low_path": unit_mults,
			"base_hp_L": int(lv.get("up_base_hp", 1)), "supply_L": int(lv.get("up_supply_regen", 1)), "worker_L": int(lv.get("up_worker", 1))})
	_emit("lowpath_vs_scaling", cmp)

	# ---- 5. r01 context for QA-J2 (DATA): r01 is played before any coins exist ----
	var r1: Dictionary = content.get_round(str(order[0]))
	_emit("r01_context", {"enemy_scaling": r1.get("enemy_scaling", {}), "coins_before_first_play": 0,
		"note": "first r01 play has all tracks at L1 (no income yet); upgrades only affect r01 replays"})
	print("PROBE10_UPGRADE_EFFECT ", JSON.stringify({"tracks": ups.size(), "rounds": order.size(), "breakpoint_rows": bp.size()}))
	quit(0)
