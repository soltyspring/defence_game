extends SceneTree
## 01 D29/R8 acceptance probe for the player-base defence (economy.base_defense) and the F0 control. Headless, deterministic.
## Run with a PRIVATE APPDATA (Save boots as an autoload and may rewrite the real user://save.json, 10 v0.26):
##   $env:APPDATA=<private dir> for the child process, or
##   & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @('--headless','--path','.','-s','res://src/core/diag/base_damage_probe.gd','--','--out=<abs json>')
## Args (all optional):
##   --out=<abs json>            rows (+ summary) as JSON
##   --configs=off,f0,b25,a30,b25a30   which configs to run (default all)
##   --idle=1|0                  also run the idle policy (no bot) once per config except f0 (default 1)
##   --rounds=r02,r03,...        default r02,r03,r04,r05,r10 (idle adds r01)
##   --budgets=none,low,low2r    docs/design/balance/upgrade_budgets.json sets (default none,low,low2r)
##   --policies=competent,casual default both; competent = bot skill 2, casual = bot skill 1
##   --seeds=1,2,3,4,5           default 1..5, r05 1..10 (01 R8)
##   --merge=<a.json>,<b.json>   no simulation: merge shard files and print the summary table; --md=<abs md> writes it
## Configs (in memory only; data/economy.json is not touched):
##   off    every base_defense key 0 = behaviour before D29
##   f0     off + 09 R09-02-6 control: when >= 3 enemies are within 60 px of the player base x, the bot walks the hero back
##          to the base and casts skill_slam (no new rule, a player-skill answer)
##   b25    dps_cap 25 (option B);  a30  push_px 30 (option A);  b25a30  both (D29 default)
## Bot timing noise = 01 multi_seed_sim (D30 fix): first act after U(0,3) s, then every U(0,0.35) s with the real elapsed time.
## Owner: 02-engine.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const CONFIGS := {
	"off": {"dps_cap": 0.0, "push_px": 0.0, "f0": false},
	"f0": {"dps_cap": 0.0, "push_px": 0.0, "f0": true},
	"b25": {"dps_cap": 25.0, "push_px": 0.0, "f0": false},
	"a30": {"dps_cap": 0.0, "push_px": 30.0, "f0": false},
	"b25a30": {"dps_cap": 25.0, "push_px": 30.0, "f0": false},
}
const STEP := 1.0 / 60.0
const NEAR_BASE_PX := 60.0

var budgets := {}

func _initialize() -> void:
	var out_path := ""
	var md_path := ""
	var merge: Array = []
	var cfgs: Array = CONFIGS.keys()
	var rounds: Array = ["r02", "r03", "r04", "r05", "r10"]
	var budget_names: Array = ["none", "low", "low2r"]
	var policies: Array = ["competent", "casual"]
	var seeds_arg: Array = []
	var with_idle := true
	var custom := {}
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--out="): out_path = v
		elif a.begins_with("--md="): md_path = v
		elif a.begins_with("--merge="): merge = Array(v.split(","))
		elif a.begins_with("--configs="): cfgs = Array(v.split(","))
		elif a.begins_with("--rounds="): rounds = Array(v.split(","))
		elif a.begins_with("--budgets="): budget_names = Array(v.split(","))
		elif a.begins_with("--policies="): policies = Array(v.split(","))
		elif a.begins_with("--seeds="): seeds_arg = Array(v.split(",")).map(func(x): return int(x))
		elif a.begins_with("--idle="): with_idle = v != "0"
		# ad-hoc config: --cap=40 --push=30 [--f0=1] runs as config "custom"
		elif a.begins_with("--cap="): custom["dps_cap"] = float(v)
		elif a.begins_with("--push="): custom["push_px"] = float(v)
		elif a.begins_with("--f0="): custom["f0"] = v == "1"
	if not merge.is_empty():
		var all_rows := []
		for p in merge:
			var j = JSON.parse_string(FileAccess.get_file_as_string(str(p)))
			if j is Dictionary: all_rows.append_array(j.get("rows", []))
		var md := _summary(all_rows)
		print(md)
		if md_path != "":
			var mf := FileAccess.open(md_path, FileAccess.WRITE)
			if mf: mf.store_string(md)
		if out_path != "":
			var of := FileAccess.open(out_path, FileAccess.WRITE)
			if of: of.store_string(JSON.stringify({"rows": all_rows, "merged_from": merge.map(func(x): return str(x).get_file())}))
		print("BASE_DAMAGE_MERGE rows=%d files=%d" % [all_rows.size(), merge.size()])
		quit(0)
		return
	var cfg_table := CONFIGS.duplicate(true)
	if not custom.is_empty():
		cfg_table["custom"] = {"dps_cap": float(custom.get("dps_cap", 0.0)), "push_px": float(custom.get("push_px", 0.0)), "f0": bool(custom.get("f0", false))}
		cfgs = ["custom"]
	var bj = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/balance/upgrade_budgets.json"))
	budgets = bj if bj is Dictionary else {}
	var c = ContentS.new()
	c.load_all("res://data")
	var rows := []
	var t0 := Time.get_ticks_msec()
	for cfg in cfgs:
		for rid in rounds:
			var seeds: Array = seeds_arg if not seeds_arg.is_empty() else ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10] if rid == "r05" else [1, 2, 3, 4, 5])
			for b in budget_names:
				for pol in policies:
					for s in seeds:
						rows.append(_run(c, rid, cfg, cfg_table[cfg], pol, b, int(s)))
		# idle: no bot, so f0 is identical to off and is skipped; one seed (the sim has no random enemy AI)
		if with_idle and not bool(cfg_table[cfg].f0):
			for rid in ["r01"] + rounds:
				rows.append(_run(c, rid, cfg, cfg_table[cfg], "idle", "none", 1))
	# determinism: the first bot case twice
	var det := true
	if not rows.is_empty():
		var r0: Dictionary = rows[0]
		if r0.policy != "idle":
			var again := _run(c, r0.round, r0.cfg, cfg_table[r0.cfg], r0.policy, r0.budget, r0.seed)
			det = again.end_ratio == r0.end_ratio and again.t == r0.t and again.won == r0.won and again.peak_loss_pct_s == r0.peak_loss_pct_s
	var report := {"rows": rows, "deterministic_first_row": det, "ms": Time.get_ticks_msec() - t0, "configs": cfgs,
		"data_hash": _data_hash(), "summary": _summary(rows)}
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(report))
	print(report.summary)
	print("BASE_DAMAGE_PROBE rows=%d deterministic=%s ms=%d data=%s out=%s" % [rows.size(), det, report.ms, report.data_hash, out_path])
	c.free()
	quit(0)

func _levels(set_name: String, rid: String) -> Dictionary:
	if set_name == "none": return {}
	var s = budgets.get(set_name, {})
	if s is Dictionary and s.get(rid) is Dictionary:
		var lv = s[rid].get("levels", {})
		if lv is Dictionary: return lv
	return {}

## Hash of the round/economy/unit data actually loaded, so a result can be tied to one data version.
func _data_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for dir in ["res://data", "res://data/rounds", "res://data/units", "res://data/skills", "res://data/heroes"]:
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for fn in files:
			if str(fn).ends_with(".json"):
				ctx.update(FileAccess.get_file_as_bytes(dir + "/" + str(fn)))
	return ctx.finish().hex_encode().substr(0, 12)

func _run(c, rid: String, cfg: String, cfg_v: Dictionary, pol: String, budget: String, seed_v: int) -> Dictionary:
	var sim = SimS.new()
	sim.setup(c, rid, seed_v, _levels(budget, rid))
	sim.base_defense = {"dps_cap": float(cfg_v.dps_cap), "push_px": float(cfg_v.push_px), "stagger_s": 0.0, "tower_splash": 0.0}
	sim.time_limit = 0.0 if pol == "idle" else 900.0
	var bot = null
	if pol == "competent": bot = BotS.new(2, seed_v)
	elif pol == "casual": bot = BotS.new(1, seed_v)
	var f0: bool = bool(cfg_v.f0) and bot != null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	var wait := rng.randf_range(0.0, 3.0)
	var since_act := 0.0
	var hp_max: float = sim.player_base.hp_max
	var ring := PackedFloat64Array()
	ring.resize(60)
	ring.fill(float(sim.player_base.hp))
	var ri := 0
	var peak_loss := 0.0
	var max_at_base := 0
	var f0_calls := 0
	var f0_casts := 0
	while not sim.ended and sim.t < 1200.0:
		if bot != null:
			wait -= STEP
			since_act += STEP
			if wait <= 0.0:
				bot.act(sim, since_act)
				if f0:
					var r := _f0(sim)
					f0_calls += r[0]
					f0_casts += r[1]
				since_act = 0.0
				wait = rng.randf_range(0.0, 0.35)
		sim.step(STEP)
		sim.events.clear()
		sim.cues.clear()
		var hp: float = sim.player_base.hp
		peak_loss = maxf(peak_loss, ring[ri] - hp)   # ring[ri] = hp 60 steps (1 s) ago
		ring[ri] = hp
		ri = (ri + 1) % 60
		var n := 0
		for e in sim.enemies:
			if not e.dying and e.x - sim.player_base.x <= NEAR_BASE_PX: n += 1
		max_at_base = maxi(max_at_base, n)
	return {"round": rid, "cfg": cfg, "policy": pol, "budget": budget, "seed": seed_v, "won": sim.won, "ended": sim.ended,
		"t": snappedf(sim.t, 0.1), "end_ratio": snappedf(sim.player_base.hp / hp_max, 0.001),
		"peak_loss_pct_s": snappedf(peak_loss / hp_max * 100.0, 0.01), "capped": snappedf(sim.base_dmg_capped, 0.1),
		"max_enemies_at_base": max_at_base, "f0_calls": f0_calls, "f0_casts": f0_casts}

## F0 control, applied right after the bot's own decision. Returns [active 0/1, slam cast 0/1].
func _f0(sim) -> Array:
	var n := 0
	for e in sim.enemies:
		if not e.dying and e.x - sim.player_base.x <= NEAR_BASE_PX: n += 1
	if n < 3: return [0, 0]
	var near_base: bool = sim.hero.x <= sim.player_base.x + 40.0
	sim.set_hero_dir(0 if near_base else -1)
	var cast := 0
	if sim.hero.x <= sim.player_base.x + NEAR_BASE_PX and sim.skill_cd.has("skill_slam"):
		if sim.cast("skill_slam") == "": cast = 1
	return [1, cast]

func _median(a: Array) -> float:
	if a.is_empty(): return -1.0
	var s := a.duplicate()
	s.sort()
	var m := int(s.size() / 2.0)
	return float(s[m]) if s.size() % 2 == 1 else (float(s[m - 1]) + float(s[m])) * 0.5

func _summary(rows: Array) -> String:
	var groups := {}
	var order := []
	for r in rows:
		var key := "%s|%s|%s|%s" % [r.round, r.policy, r.budget, r.cfg]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(r)
	var lines := ["| round | policy | budget | cfg | wins | end min | end median | t median (s) | peak loss %/s max | peak median | max at base | capped HP median | f0 casts median |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
	for key in order:
		var g: Array = groups[key]
		var wins := 0
		var ends := []
		var ts := []
		var peaks := []
		var caps := []
		var casts := []
		var mab := 0
		for r in g:
			if r.won: wins += 1
			ends.append(float(r.end_ratio))
			ts.append(float(r.t))
			peaks.append(float(r.peak_loss_pct_s))
			caps.append(float(r.capped))
			casts.append(float(r.get("f0_casts", 0)))
			mab = maxi(mab, int(r.max_enemies_at_base))
		var p: PackedStringArray = str(key).split("|")
		lines.append("| %s | %s | %s | %s | %d/%d | %.3f | %.3f | %.1f | %.2f | %.2f | %d | %.0f | %.0f |" % [p[0], p[1], p[2], p[3], wins, g.size(),
			ends.min(), _median(ends), _median(ts), peaks.max(), _median(peaks), mab, _median(caps), _median(casts)])
	return "\n".join(lines)
