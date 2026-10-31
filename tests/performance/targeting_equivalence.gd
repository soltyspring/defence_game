extends SceneTree
## 08-performance check: does 02's sorted-lane _find_target (e9dfaa4) reproduce the linear scan's battle outcomes?
## Same build, same data, same seeds; only BattleSim._linear_targets differs (02's A/B switch). Headless, ~1–2 min.
##   Godot_console.exe --headless --path . -s res://tests/performance/targeting_equivalence.gd -- [--out=<abs.json>] [--seeds=11,22,33]
## For every round x seed: winner, end time, kills, and the first step where the two sims' unit states diverge
## (state hash of x/hp per unit), plus target disagreements counted per step until divergence.
## Exit 0 = ran (verdict in output, "EQUIVALENT" or "DIVERGES"); 1 = harness error / switch missing. Owner: 08-performance.

const ContentS := preload("res://src/core/content.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	var out_path := ProjectSettings.globalize_path("res://build/perf/targeting_equivalence.json")
	var seeds := [11, 22, 33]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_path = a.get_slice("=", 1)
		if a.begins_with("--seeds="):
			seeds = []
			for s in a.get_slice("=", 1).split(","): seeds.append(int(s))
	var content = ContentS.new()
	content.load_all("res://data")
	var probe = SimS.new()
	if not ("_linear_targets" in probe):
		printerr("BattleSim has no _linear_targets switch; nothing to compare")
		quit(1)
		return
	var rows := []
	var diverged := 0
	var outcome_changed := 0
	for rid in content.round_order:
		for sv in seeds:
			var a = SimS.new()
			var b = SimS.new()
			a.setup(content, rid, sv)
			b.setup(content, rid, sv)
			b._linear_targets = true
			var ba = BotS.new(2, sv)
			var bb = BotS.new(2, sv)
			var first_div := -1
			var disagree_steps := 0
			var first_disagree := {}
			var n := 0
			while (not a.ended or not b.ended) and n < 54000:
				if first_div < 0:
					# compare target choice of every living unit on identical states (before stepping)
					if a.has_method("_sort_lanes"): a._sort_lanes()
					var dis := 0
					var samples := []
					for i in mini(a.players.size(), b.players.size()):
						var ta = a._find_target(a.players[i])
						var tb = b._find_target(b.players[i])
						if _tid(ta) != _tid(tb):
							dis += 1
							if samples.size() < 3: samples.append(_why(a.players[i], ta, tb))
					for i in mini(a.enemies.size(), b.enemies.size()):
						var ta2 = a._find_target(a.enemies[i])
						var tb2 = b._find_target(b.enemies[i])
						if _tid(ta2) != _tid(tb2):
							dis += 1
							if samples.size() < 3: samples.append(_why(a.enemies[i], ta2, tb2))
					if dis > 0:
						disagree_steps += 1
						if first_disagree.is_empty():
							first_disagree = {"step": n, "t": snappedf(a.t, 0.01), "units": a.players.size() + a.enemies.size(), "disagreements": dis, "samples": samples}
				if not a.ended:
					ba.act(a, STEP)
					a.step(STEP)
				if not b.ended:
					bb.act(b, STEP)
					b.step(STEP)
				a.events.clear()
				b.events.clear()
				n += 1
				if first_div < 0 and _hash(a) != _hash(b):
					first_div = n
			var same: bool = a.won == b.won and is_equal_approx(a.t, b.t) and a.kills == b.kills
			if first_div >= 0: diverged += 1
			if a.won != b.won: outcome_changed += 1
			rows.append({"round": rid, "seed": sv, "sorted": {"won": a.won, "t": snappedf(a.t, 0.1), "kills": a.kills},
				"linear": {"won": b.won, "t": snappedf(b.t, 0.1), "kills": b.kills}, "identical": same,
				"first_state_divergence_step": first_div, "first_target_disagreement": first_disagree,
				"steps_with_target_disagreement_before_divergence": disagree_steps})
			print("[equiv] %s seed%d sorted(won=%s t=%.1f k=%d) linear(won=%s t=%.1f k=%d) div_step=%d first_disagree=%s" % [
				rid, sv, str(a.won), a.t, a.kills, str(b.won), b.t, b.kills, first_div, JSON.stringify(first_disagree)])
	var verdict := "EQUIVALENT" if diverged == 0 else "DIVERGES"
	var rep := {"evidence_class": "DESKTOP_HEADLESS_DETERMINISM", "verdict": verdict, "runs": rows.size(), "diverged_runs": diverged,
		"winner_changed_runs": outcome_changed, "seeds": seeds,
		"note": "Only _linear_targets differs. Divergence means the sorted lookup picks a different target than the linear scan in some state."}
	rep.rows = rows
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rep, "  "))
		f.close()
	print("TARGETING_EQUIVALENCE verdict=%s diverged=%d/%d winner_changed=%d report=%s" % [verdict, diverged, rows.size(), outcome_changed, out_path])
	content.free()
	quit(0)

static func _tid(u) -> int:
	return -1 if u == null else int(u.uid)

## Why two picks differ: signed forward distance d = (target.x - u.x) * side of each pick (linear keeps the minimum d >= -10,
## first in array order on ties).
static func _why(u, sorted_t, linear_t) -> Dictionary:
	var f := func(t): return {} if t == null else {"uid": t.uid, "id": t.id, "x": snappedf(t.x, 0.01), "d": snappedf((t.x - u.x) * u.side, 0.01), "hero": t.is_hero}
	return {"unit": {"uid": u.uid, "id": u.id, "side": u.side, "x": snappedf(u.x, 0.01)}, "sorted": f.call(sorted_t), "linear": f.call(linear_t)}

static func _hash(sim) -> int:
	var h := hash([sim.t, sim.gold, sim.players.size(), sim.enemies.size(), sim.enemy_base.hp, sim.player_base.hp])
	for u in sim.players: h = hash([h, u.uid, snappedf(u.x, 0.001), snappedf(u.hp, 0.001)])
	for u in sim.enemies: h = hash([h, u.uid, snappedf(u.x, 0.001), snappedf(u.hp, 0.001)])
	return h
