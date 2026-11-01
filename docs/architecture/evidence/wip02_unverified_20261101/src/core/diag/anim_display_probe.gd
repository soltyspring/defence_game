extends SceneTree
## 07 QA-B025 / QA-O006 probe: which animation does battle_view draw for each unit, frame by frame, in real battles?
## Uses BattleView.anim_for() and BattleView.death_alpha() (the functions _draw_unit uses) on a headless battle with the
## Atlas autoload, competent bot, App autoplay seed, 60 frames/s. No rendering.
## Run with a PRIVATE APPDATA, one heavy run at a time:
##   & docs/research/systems/probes/isolated_godot.ps1 -GodotArgs @('--headless','--path','.','-s','res://src/core/diag/anim_display_probe.gd','--','--rounds=r06,r08')
## Output: "ANIM_DISPLAY <json>". Owner: 02-engine.

const SimS := preload("res://src/gameplay/battle_sim.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const ViewS := preload("res://src/gameplay/battle_view.gd")

func _initialize() -> void:
	_run.call_deferred()   # autoloads (Content, Atlas) finish _ready first

func _run() -> void:
	var rounds: Array = ["r06", "r08"]
	var seconds := 240.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="): rounds = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--seconds="): seconds = float(a.get_slice("=", 1))
	var content = root.get_node("Content")
	var atlas = root.get_node("Atlas")
	var out := {"rounds": {}}
	for rid in rounds:
		out.rounds[rid] = _battle(content, atlas, str(rid), seconds)
	print("ANIM_DISPLAY ", JSON.stringify(out))
	quit(0)

func _battle(content, atlas, rid: String, seconds: float) -> Dictionary:
	var idx: int = content.round_order.find(rid)
	var seed_v := int(content.config.get("combat", {}).get("deterministic_seed_default", 12345)) + idx
	var sim = SimS.new()
	sim.setup(content, rid, seed_v, {})
	var bot = BotS.new(2, seed_v)
	var dt := 1.0 / 60.0
	var per := {}          # anim_set -> {anim -> frames drawn}
	var deaths := {}       # anim_set -> {"n", "anim_s", "full_alpha_s", "half_alpha_s", "old_full_s", "old_half_s"}
	var casts := 0
	var frames := 0
	var hero_deaths := 0
	var hero_death_frames := 0
	var prev_casts := 0
	while sim.t < seconds and not sim.ended:
		bot.act(sim, dt)
		sim.step(dt)
		sim.events.clear()
		sim.cues.clear()
		frames += 1
		if int(sim.stats.skills_cast) > prev_casts:
			casts += int(sim.stats.skills_cast) - prev_casts
			prev_casts = int(sim.stats.skills_cast)
		var units: Array = []
		units.append_array(sim.players)
		units.append_array(sim.enemies)
		if sim.hero_respawn <= 0.0 or (sim.hero.dying and sim.hero.dead_t > 0.0):
			units.append(sim.hero)
		for u in units:
			var sel: Array = ViewS.anim_for(u, atlas)
			var rec = sel[0]
			if rec == null: continue
			var name := _name_of(atlas, u.anim_set, rec)
			if not per.has(u.anim_set): per[u.anim_set] = {}
			per[u.anim_set][name] = int(per[u.anim_set].get(name, 0)) + 1
			if u.dying:
				var alen: float = float(rec.rects.size()) / maxf(1.0, float(rec.fps))
				var td: float = SimS.DEATH_TIME - u.dead_t
				if u.is_hero:
					hero_death_frames += 1
					if td <= dt * 1.5: hero_deaths += 1
				if not deaths.has(u.anim_set):
					deaths[u.anim_set] = {"anim_s": snappedf(alen, 0.001), "frames_in_anim": 0, "full_alpha": 0, "half_alpha": 0, "old_full": 0, "old_half": 0}
				var d: Dictionary = deaths[u.anim_set]
				if td < alen:
					d.frames_in_anim += 1
					var a := ViewS.death_alpha(td, alen)
					var old_a := clampf(1.0 - td / 0.7, 0.0, 1.0)   # before: alpha = dead_t / 0.7
					if a >= 0.99: d.full_alpha += 1
					if a >= 0.5: d.half_alpha += 1
					if old_a >= 0.99: d.old_full += 1
					if old_a >= 0.5: d.old_half += 1
	for k in deaths:
		var d: Dictionary = deaths[k]
		var n := maxf(1.0, float(d.frames_in_anim))
		d["share_full_alpha"] = snappedf(d.full_alpha / n, 0.001)
		d["share_half_alpha"] = snappedf(d.half_alpha / n, 0.001)
		d["old_share_full_alpha"] = snappedf(d.old_full / n, 0.001)
		d["old_share_half_alpha"] = snappedf(d.old_half / n, 0.001)
	var cast_rec = atlas.anim_rec(sim.hero.anim_set, "cast")
	var cast_len: float = float(cast_rec.rects.size()) / float(cast_rec.fps) if cast_rec != null else 0.0
	return {"seed": seed_v, "frames": frames, "t": snappedf(sim.t, 0.1), "won": sim.won, "anim_frames": per, "deaths": deaths,
		"casts": casts, "cast_frames_expected_max": int(round(casts * cast_len * 60.0)),
		"hero_deaths": hero_deaths, "hero_death_frames": hero_death_frames}

## Name of the anim `rec` belongs to (rec objects are cached per set + name in Atlas).
func _name_of(atlas, anim_set: String, rec) -> String:
	for n in ["death", "cast", "attack", "hit", "walk", "idle"]:
		if atlas.anim_rec(anim_set, n) == rec: return n
	return "?"
