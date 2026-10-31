extends SceneTree
## 01 R10/R11 probe: why does the competent bot stay at the enemy base past 200 s in r02–r04 while the casual bot wins
## at ~115 s? Runs bot variants on the same seeds and logs where the time goes. Headless, deterministic.
## Harness = 01 multi_seed_sim after the D30 fix (first act after U(0,3) s, then every U(0,0.35) s with the real
## elapsed time), budgets from docs/design/balance/upgrade_budgets.json, engine time limit 900 s.
## Run with a PRIVATE APPDATA, one heavy run at a time:
##   & .\coordination\heavy_run.ps1 -Label '02-bot-stall' -Script { & docs/research/systems/probes/isolated_godot.ps1
##     -GodotArgs @('--headless','--path','.','-s','res://src/core/diag/bot_stall_probe.gd','--','--out=<abs json>') }
## Args: --plan="r02+r03:comp+casual;r05:comp" | --variants=a,b --rounds=r02,r03 ; --seeds=1,2 (default 1-5, r05 1-10)
##       --budget=low --out=<abs json>
## Variants ("comp" / "casual" = the current defaults of skill 2 / skill 1; suffixes combine):
##   _old = BotPlayer.use_legacy_policy() (before 2026-11-01); _econ = legacy + worker-saving fix only;
##   _hero = legacy + hurt-hero fix only; cheap = cheapest card first; noreserve = no worker reserve; w3 = 3 workers
## Output: one "BOT_STALL <json>" line with per-run rows and a per-variant summary. Owner: 02-engine.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const STEP := 1.0 / 60.0
const AT_BASE_PX := 60.0

func _initialize() -> void:
	var variants: Array = ["comp", "casual", "comp_old", "casual_old", "comp_econ", "comp_hero"]
	var rounds: Array = ["r02", "r03", "r04"]
	var seeds: Array = []
	var budget := "low"
	var out_path := ""
	var plan_arg := ""
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--variants="): variants = Array(v.split(","))
		elif a.begins_with("--rounds="): rounds = Array(v.split(","))
		elif a.begins_with("--seeds="): seeds = Array(v.split(",")).map(func(x): return int(x))
		elif a.begins_with("--budget="): budget = v
		elif a.begins_with("--out="): out_path = v
		elif a.begins_with("--plan="): plan_arg = v
	# plan: "r02+r03:comp+casual;r05:comp" (overrides --rounds/--variants); default = rounds x variants
	var plan := []
	if plan_arg != "":
		for part in plan_arg.split(";"):
			if part.strip_edges() == "": continue
			plan.append([Array(part.get_slice(":", 0).split("+")), Array(part.get_slice(":", 1).split("+"))])
	else:
		plan.append([rounds, variants])
	var bj = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/balance/upgrade_budgets.json"))
	var budgets: Dictionary = bj if bj is Dictionary else {}
	var c = ContentS.new()
	c.load_all("res://data")
	var rows := []
	var t0 := Time.get_ticks_msec()
	for entry in plan:
		for rid in entry[0]:
			var lv := {}
			if budget != "none" and budgets.get(budget, {}).get(rid) is Dictionary:
				lv = budgets[budget][rid].get("levels", {})
			var sd: Array = seeds if not seeds.is_empty() else ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10] if rid == "r05" else [1, 2, 3, 4, 5])
			for var_name in entry[1]:
				for s in sd:
					rows.append(_run(c, str(rid), str(var_name), int(s), lv))
	var summary := {}
	for r in rows:
		var key := "%s|%s" % [r.round, r.variant]
		if not summary.has(key): summary[key] = {"t": [], "wins": 0, "n": 0, "first_at_base": [], "at_base_s": []}
		var g: Dictionary = summary[key]
		g.t.append(r.t)
		g.n += 1
		if r.won: g.wins += 1
		g.first_at_base.append(r.first_at_base_t)
		g.at_base_s.append(r.at_base_s)
	for k in summary:
		var g: Dictionary = summary[k]
		g["t_median"] = _median(g.t)
		g["first_at_base_median"] = _median(g.first_at_base)
		g["at_base_s_median"] = _median(g.at_base_s)
	var out := {"rows": rows, "summary": summary, "budget": budget, "ms": Time.get_ticks_msec() - t0}
	var txt := JSON.stringify(out)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f: f.store_string(txt)
	for k in summary:
		var g: Dictionary = summary[k]
		print("BOT_STALL_SUMMARY %s wins %d/%d t %s median %.1f first_at_base median %.1f at_base median %.1f" % [k, g.wins, g.n, str(g.t), g.t_median, g.first_at_base_median, g.at_base_s_median])
	print("BOT_STALL rows=%d ms=%d out=%s" % [rows.size(), out.ms, out_path])
	c.free()
	quit(0)

func _bot(var_name: String, seed_v: int):
	var b = BotS.new(1 if var_name.begins_with("casual") else 2, seed_v)
	if var_name.contains("_old"): b.use_legacy_policy()
	if var_name.contains("_econ"):    # economy fix only
		b.use_legacy_policy()
		b.reserve_ratio = 1.0
		b.threat_px = 350.0
		b.cap_want_by_max = true
	if var_name.contains("_hero"):    # hero fix only
		b.use_legacy_policy()
		b.hurt_hold_behind = 60.0
	if var_name.contains("cheap"): b.expensive_first = false
	if var_name.contains("noreserve"): b.reserve_ratio = 0.0
	if var_name.contains("w3"): b.want_workers = 3
	return b

func _run(c, rid: String, var_name: String, seed_v: int, lv: Dictionary) -> Dictionary:
	var sim = SimS.new()
	sim.setup(c, rid, seed_v, lv)
	var bot = _bot(var_name, seed_v)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	var wait := rng.randf_range(0.0, 3.0)
	var since_act := 0.0
	var base_front: float = sim.enemy_base.x - SimS.BASE_HALF
	var leash_x: float = sim.L * float(sim.hero_def.get("leash", 1.0))
	var first_at_base := -1.0
	var at_base_s := 0.0
	var gold_capped_s := 0.0
	var hero_hurt_s := 0.0
	var hero_at_leash_s := 0.0
	var hero_dead_s := 0.0
	var ebase_hp_at_first := -1.0
	var deployed := {}
	var worker_t := []
	var workers_prev: int = sim.workers
	var army_sum := 0.0
	var ranged_share_sum := 0.0
	var samples := 0
	var enemies_at_base_sum := 0.0
	var at_base_samples := 0
	var ebase_dmg_while_at_base := 0.0
	var prev_ebase: float = sim.enemy_base.hp
	var prev_dep: int = int(sim.stats.deployed)
	var tl := []
	var next_tl := 0.0
	while not sim.ended and sim.t < 1000.0:
		wait -= STEP
		since_act += STEP
		if wait <= 0.0:
			var before := {}
			for u in sim.players: before[u] = true
			bot.act(sim, since_act)
			if int(sim.stats.deployed) > prev_dep:
				for u in sim.players:
					if not before.has(u): deployed[u.id] = int(deployed.get(u.id, 0)) + 1
				prev_dep = int(sim.stats.deployed)
			since_act = 0.0
			wait = rng.randf_range(0.0, 0.35)
		sim.step(STEP)
		sim.events.clear()
		sim.cues.clear()
		if sim.workers > workers_prev:
			worker_t.append(snappedf(sim.t, 0.1))
			workers_prev = sim.workers
		var front := -1.0
		var n := 0
		var nr := 0
		for u in sim.players:
			if u.dying: continue
			n += 1
			if str(u.def.get("attack_type", "")) == "ranged": nr += 1
			front = maxf(front, u.x)
		var at_base: bool = front >= 0.0 and base_front - front <= AT_BASE_PX
		if at_base:
			at_base_s += STEP
			if first_at_base < 0.0:
				first_at_base = sim.t
				ebase_hp_at_first = sim.enemy_base.hp
			ebase_dmg_while_at_base += maxf(0.0, prev_ebase - sim.enemy_base.hp)
		prev_ebase = sim.enemy_base.hp
		if sim.gold >= float(sim.gold_max) - 0.01: gold_capped_s += STEP
		if sim.hero_respawn > 0.0: hero_dead_s += STEP
		else:
			if sim.hero.hp < sim.hero.hp_max * 0.3: hero_hurt_s += STEP
			if sim.hero.x >= leash_x - 1.0: hero_at_leash_s += STEP
		samples += 1
		army_sum += n
		if n > 0: ranged_share_sum += float(nr) / n
		if at_base:
			var ne := 0
			for e in sim.enemies:
				if not e.dying and e.x >= base_front - 150.0: ne += 1
			enemies_at_base_sum += ne
			at_base_samples += 1
		if sim.t >= next_tl:
			next_tl += 20.0
			tl.append([snappedf(sim.t, 1.0), roundi(front), n, nr, roundi(sim.enemy_base.hp), roundi(sim.gold), sim.workers, roundi(sim.hero.x), snappedf(sim.hero.hp / sim.hero.hp_max, 0.01), sim.enemies.filter(func(e): return not e.dying).size()])
	var hp_max: float = sim.enemy_base.hp_max
	return {"round": rid, "variant": var_name, "seed": seed_v, "won": sim.won, "t": snappedf(sim.t, 0.1),
		"first_at_base_t": snappedf(first_at_base, 0.1), "at_base_s": snappedf(at_base_s, 0.1),
		"ebase_ratio_at_first": snappedf(ebase_hp_at_first / hp_max, 0.001) if ebase_hp_at_first >= 0.0 else -1.0,
		"ebase_dps_while_at_base": snappedf(ebase_dmg_while_at_base / maxf(0.01, at_base_s), 0.01),
		"enemies_near_ebase_mean": snappedf(enemies_at_base_sum / maxf(1.0, at_base_samples), 0.01),
		"army_mean": snappedf(army_sum / maxf(1.0, samples), 0.1), "ranged_share_mean": snappedf(ranged_share_sum / maxf(1.0, samples), 0.01),
		"deployed": deployed, "worker_t": worker_t, "gold_capped_s": snappedf(gold_capped_s, 0.1),
		"hero_hurt_s": snappedf(hero_hurt_s, 0.1), "hero_at_leash_s": snappedf(hero_at_leash_s, 0.1), "hero_dead_s": snappedf(hero_dead_s, 0.1),
		"timeline_cols": ["t", "front_x", "army", "ranged", "ebase_hp", "gold", "workers", "hero_x", "hero_hp", "enemies"], "timeline": tl}

func _median(a: Array) -> float:
	var s: Array = a.filter(func(x): return float(x) >= 0.0)
	if s.is_empty(): return -1.0
	s.sort()
	var m := int(s.size() / 2.0)
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5
