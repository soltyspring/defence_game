extends SceneTree
## PREVIEW ONLY (Codex review of e3c871c): what the proposed lane changes would cost, before 01/02/03 decide.
## Owner: 04-client. Changes are made at RUNTIME in this process only. No 02/03 file is edited (snapshot or tree):
##   combo "current"  : the game as it is (camera x snapped to hero + 60 for all combos, so they are comparable)
##   combo "zoom"     : world camera zoom 4/3 (02 option B); HUD unchanged; ground kept 70 px above the view bottom
##   combo "zoom_big" : zoom 4/3 + regular unit sprites upscaled x1.5 nearest (≈ 32 px bodies, stand-in for 03 option A)
## Same seed, same scripted inputs, sim stepped by this script (battle.time_scale = 0), so every combo plays the
## identical battle; metrics are sampled every 0.25 s of sim time and one frame is captured at --shot-t.
## Visible runs only (DISPLAY2 via tools/build/visible_launch.ps1, with -IsolateAppData). User args:
##   --out=<abs dir> --combo=current|zoom|zoom_big --target=44 --safe=34,0,34,0 --round=r06 --shot-t=46 --end-t=90

const ThreatMarker := preload("res://src/ui/threat_marker.gd")
const ZOOM := 4.0 / 3.0
const BIG := 1.5
const BIG_SETS := ["worker", "melee_basic", "ranged_basic", "tank", "fast", "e_grunt", "e_spitter", "e_swarm", "e_brute", "e_bomber"]
const GROUND_FROM_BOTTOM := 70.0
const DT := 1.0 / 60.0

var out_dir := ""
var combo := "current"
var round_id := "r06"
var shot_t := 46.0
var end_t := 90.0
var app: Node
var events: Node
var zoom := 1.0
var TEST_SAVE := "user://zoom_preview_save_%d.json" % OS.get_process_id()

## Runs after battle.gd each frame (higher process_priority) and re-applies the preview camera.
class CamFix extends Node:
	var battle: Node
	var z := 1.0
	func _process(_d: float) -> void:
		if battle == null or not is_instance_valid(battle) or battle.sim == null:
			return
		var vs: Vector2 = battle.get_viewport_rect().size
		var half := vs.x * 0.5 / z
		var cx := clampf(float(battle.sim.hero.x) + 60.0, -90.0 + half, float(battle.sim.L) + 50.0 - half)
		var gy: float = battle.view.ground_y
		var cy := gy - (vs.y * 0.5 - GROUND_FROM_BOTTOM) / z      # ground stays 70 px above the view bottom
		battle.cam.zoom = Vector2(z, z)
		battle.cam.position = Vector2(roundf(cx), cy)
		battle.view.view_w = vs.x / z
		battle.view.cam_x = cx
		battle.view.view_top = cy - vs.y * 0.5 / z
		battle.view.view_bottom = cy + vs.y * 0.5 / z

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 2) -> void:
	for i in n:
		await process_frame

## Stand-in for 03's bigger bodies: copy each regular unit's atlas page with a x1.5 nearest texture and scaled
## frame rects/pivots, and point only those anim sets at the copy (hero, siege, bosses keep their pages).
func _upscale_units(atlas: Node) -> Array:
	var done := []
	var copies := {}
	for s in BIG_SETS:
		var pid := str(atlas.anim_sets.get(s, ""))
		if pid == "" or not atlas.pages.has(pid):
			continue
		if not copies.has(pid):
			var p: Dictionary = atlas.pages[pid]
			if p.tex == null:
				atlas.acquire(pid)
			var img: Image = (p.tex as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			img.resize(int(img.get_width() * BIG), int(img.get_height() * BIG), Image.INTERPOLATE_NEAREST)
			var frames := {}
			for fn in p.frames:
				var f: Dictionary = p.frames[fn]
				var w := float(f.get("w", 0)); var h := float(f.get("h", 0))
				var pv = f.get("pivot", [w * 0.5, h])
				frames[fn] = {"x": float(f.x) * BIG, "y": float(f.y) * BIG, "w": w * BIG, "h": h * BIG, "pivot": [float(pv[0]) * BIG, float(pv[1]) * BIG]}
			var nid := pid + "__preview_x15"
			atlas.pages[nid] = {"meta": p.meta, "frames": frames, "anims": p.anims, "tex": ImageTexture.create_from_image(img), "refs": 1, "loaded": true, "source": "preview"}
			copies[pid] = nid
		atlas.anim_sets[s] = copies[pid]
		done.append(s)
	atlas._invalidate_recs()
	return done

func _run() -> void:
	app = root.get_node_or_null("App")
	events = root.get_node_or_null("Events")
	var save := root.get_node_or_null("Save")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		elif a.begins_with("--combo="): combo = a.get_slice("=", 1)
		elif a.begins_with("--round="): round_id = a.get_slice("=", 1)
		elif a.begins_with("--shot-t="): shot_t = float(a.get_slice("=", 1))
		elif a.begins_with("--end-t="): end_t = float(a.get_slice("=", 1))
		elif a.begins_with("--target="): load("res://src/ui/safe_area.gd").override_target = float(a.get_slice("=", 1))
		elif a.begins_with("--safe="):
			var q := a.get_slice("=", 1).split(",")
			load("res://src/ui/safe_area.gd").override_insets = Vector4(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
	if app == null or save == null or out_dir == "" or DisplayServer.get_name() == "headless":
		printerr("[zoom] needs a visible run with --out"); quit(1); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	save.path = TEST_SAVE
	save.load_progress()
	var content: Node = root.get_node("Content")
	var tut: Array = []
	for rid in content.round_order:
		for k in content.get_round(str(rid)).get("tutorial", []):
			tut.append(str(k))
	save.progress["tutorial_done"] = tut
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await _frames(3)
	seed(4242)                                   # App.start_round draws its battle seed from randi()
	app.start_round(round_id, true)
	await _frames(3)
	var battle: Node = app.battle
	var sim = battle.sim
	battle.time_scale = 0.0                      # this script steps the sim; same battle in every combo
	var atlas: Node = root.get_node("Atlas")
	var big_sets: Array = []
	zoom = ZOOM if combo != "current" else 1.0
	if combo == "zoom_big":
		big_sets = _upscale_units(atlas)
	var fix := CamFix.new()
	fix.battle = battle
	fix.z = zoom
	fix.process_priority = 1000
	root.add_child(fix)
	var vs: Vector2 = root.get_visible_rect().size
	var half := vs.x * 0.5 / zoom
	# scripted player: fixed deploy schedule (sim time), hero follows the front at 150 px
	var plan := [[2.0, "melee_basic"], [4.0, "tank"], [6.0, "ranged_basic"], [9.0, "melee_basic"], [12.0, "fast"], [15.0, "siege"],
		[20.0, "ranged_basic"], [24.0, "tank"], [28.0, "melee_basic"], [33.0, "fast"], [38.0, "ranged_basic"], [44.0, "melee_basic"],
		[50.0, "tank"], [56.0, "ranged_basic"], [62.0, "melee_basic"], [70.0, "siege"], [78.0, "fast"]]
	var pi := 0
	var m := {"samples": 0, "ally_vis_sum": 0, "enemy_vis_sum": 0, "ally_vis_max": 0, "enemy_vis_max": 0,
		"both_vis": 0, "pbase_vis": 0, "ebase_vis": 0, "marker_any": 0, "marker_enemy": 0, "marker_nest": 0, "marker_left": 0}
	var first_vis := {}
	var engaged := {}
	var shot_done := false
	while sim.t < end_t and not sim.ended:
		# advance 0.25 s of sim time per rendered frame
		for k in 15:
			while pi < plan.size() and sim.t >= float(plan[pi][0]):
				sim.gold = maxf(sim.gold, 300.0)
				sim.card_cd[str(plan[pi][1])] = 0.0
				sim.deploy(str(plan[pi][1]))
				pi += 1
			var front := 0.0
			for p in sim.players:
				if p.alive and not p.is_hero: front = maxf(front, p.x)
			if sim.hero != null:
				sim.set_hero_dir(1 if sim.hero.x < front - 150.0 - 6.0 else (-1 if sim.hero.x > front - 150.0 + 30.0 else 0))
			sim.step(DT)
		# ---- metrics with the preview camera rule (same as CamFix)
		var cx := clampf(float(sim.hero.x) + 60.0, -90.0 + half, float(sim.L) + 50.0 - half)
		var vl := cx - half
		var vr := cx + half
		var av := 0
		var ev := 0
		var e_right := -1.0
		var e_left := -1.0
		for p in sim.players:
			if p.alive and not p.dying and not p.is_hero and p.x >= vl and p.x <= vr: av += 1
		for e in sim.enemies:
			if not e.alive or e.dying: continue
			var vis: bool = e.x >= vl and e.x <= vr
			if vis:
				ev += 1
				if not first_vis.has(e.uid): first_vis[e.uid] = sim.t
			elif e.x > vr and (e_right < 0.0 or e.x < e_right): e_right = e.x
			elif e.x < vl and (e_left < 0.0 or e.x > e_left): e_left = e.x
			if e.state == 1 and not engaged.has(e.uid):          # S_ATTACK: first engagement
				engaged[e.uid] = {"t": sim.t, "visible": vis}
		m.samples += 1
		m.ally_vis_sum += av; m.enemy_vis_sum += ev
		m.ally_vis_max = maxi(m.ally_vis_max, av); m.enemy_vis_max = maxi(m.enemy_vis_max, ev)
		if av > 0 and ev > 0: m.both_vis += 1
		if absf(float(sim.player_base.x) - cx) <= half + 30.0: m.pbase_vis += 1
		if absf(float(sim.enemy_base.x) - cx) <= half + 30.0: m.ebase_vis += 1
		var thr := {"view_left": vl, "view_right": vr, "nest_left": float(sim.enemy_base.x) - 48.0, "enemy_visible": ev > 0}
		if e_right >= 0.0: thr["enemy_right"] = e_right
		if e_left >= 0.0: thr["enemy_left"] = e_left
		var mk: Dictionary = ThreatMarker.compute(thr)
		if mk.right.kind != "" or mk.left.kind != "": m.marker_any += 1
		if mk.right.kind == "enemy": m.marker_enemy += 1
		if mk.right.kind == "nest": m.marker_nest += 1
		if mk.left.kind != "": m.marker_left += 1
		await process_frame
		if not shot_done and sim.t >= shot_t:
			shot_done = true
			await _frames(2)
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var dark := 0; var tot := 0
			for y in range(0, img.get_height(), 16):
				for x in range(0, img.get_width(), 16):
					tot += 1
					if img.get_pixel(x, y).get_luminance() < 0.02: dark += 1
			img.save_png(out_dir.path_join("zoom_preview_%s.png" % combo))
			m["shot_t"] = sim.t
			m["shot_dark_pct"] = 100.0 * dark / maxf(1.0, float(tot))
			m["shot_state"] = {"allies": sim.players.filter(func(u): return u.alive).size(), "enemies": sim.enemies.filter(func(u): return u.alive).size(), "kills": sim.kills, "hero_x": sim.hero.x}
	# approach time: from first visible to first engagement, per enemy that engaged
	var appr := []
	var offscreen_engage := 0
	for uid in engaged:
		var eg: Dictionary = engaged[uid]
		if first_vis.has(uid) and float(first_vis[uid]) <= float(eg.t):
			appr.append(float(eg.t) - float(first_vis[uid]))
		else:
			offscreen_engage += 1
	appr.sort()
	var n := float(maxi(1, m.samples))
	var res := {"combo": combo, "round": round_id, "view": vs, "window": DisplayServer.window_get_size(), "zoom": zoom,
		"lane_width_on_screen": vs.x / zoom, "big_sets": big_sets, "sim_t_end": sim.t, "kills": sim.kills,
		"enemy_approach_visible_s_mean": (appr.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, float(appr.size()))) if appr.size() > 0 else -1.0,
		"enemy_approach_visible_s_median": appr[appr.size() / 2] if appr.size() > 0 else -1.0,
		"enemies_engaged": engaged.size(), "enemies_engaged_offscreen": offscreen_engage,
		"allies_visible_mean": m.ally_vis_sum / n, "enemies_visible_mean": m.enemy_vis_sum / n,
		"allies_visible_max": m.ally_vis_max, "enemies_visible_max": m.enemy_vis_max,
		"both_sides_visible_pct": 100.0 * m.both_vis / n,
		"player_base_on_screen_pct": 100.0 * m.pbase_vis / n, "enemy_base_on_screen_pct": 100.0 * m.ebase_vis / n,
		"marker_needed_pct": 100.0 * m.marker_any / n, "marker_enemy_right_pct": 100.0 * m.marker_enemy / n,
		"marker_nest_pct": 100.0 * m.marker_nest / n, "marker_enemy_left_pct": 100.0 * m.marker_left / n,
		"samples": m.samples, "shot_t": m.get("shot_t", -1.0), "shot_dark_pct": m.get("shot_dark_pct", -1.0), "shot_state": m.get("shot_state", {}),
		"user_data_dir": OS.get_user_data_dir()}
	print("[zoom] " + JSON.stringify(res))
	var f := FileAccess.open(out_dir.path_join("zoom_preview_%s.json" % combo), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	quit(0)
