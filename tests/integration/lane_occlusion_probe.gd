extends SceneTree
## Lane occlusion probe on the REAL engine (Codex follow-up to 13aade1, 07 QA-J1). Owner: 04-client.
## Measures, in logical screen px, how much of each lane unit's sprite is covered by the bottom HUD row:
##   lane_bottom = lowest sprite bottom on screen, hud_top = top of the bottom-row rects (worker, cards,
##   move, skills; plus a stacked skill column if any), occluded = rows of a sprite under a HUD rect that
##   overlaps it horizontally. Also captures one frame.
## Visible runs only (secondary monitor, via tools/build/visible_launch.ps1). User args:
##   --out=<abs dir> --tag=<name> --target=<logical px> --safe=L,T,R,B --round=r08 --seconds=6
## Exit 0 = measured (the numbers are the result, not a pass/fail), 1 = could not run.

var out_dir := ""
var tag := "probe"
var round_id := "r08"
var seconds := 6.0
var fullscreen := false   # --fullscreen: same window mode as tests/integration/store_capture.gd (1920x1080 on DISPLAY2)
var app: Node
var events: Node
var TEST_SAVE := "user://lane_probe_save_%d.json" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _frames(n := 2) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame

func _hud() -> Control:
	for c in app.ui_layer.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path == "res://src/ui/hud.gd" and not c.is_queued_for_deletion():
			return c
	return null

## Screen rect (logical px) of a unit sprite, from the same AnimRec/pivot the battle view draws with.
func _sprite_rect(view: Node2D, u, xf: Transform2D, atlas: Node) -> Rect2:
	var rec = atlas.anim_rec(u.anim_set, view._anim_name(u))
	if rec == null:
		rec = atlas.anim_rec(u.anim_set, "walk")
	if rec == null:
		return Rect2()
	var fi: int = atlas.rec_index(rec, u.anim_t)
	var r: Rect2 = rec.rects[fi]
	var pv: Vector2 = rec.pivots[fi]
	var pos := Vector2(roundf(u.x), roundf(view.ground_y + u.lane_y))
	var world := Rect2(pos - pv, r.size)
	var tl := xf * world.position
	return Rect2(tl, world.size * xf.get_scale())

func _run() -> void:
	app = root.get_node_or_null("App")
	events = root.get_node_or_null("Events")
	var save := root.get_node_or_null("Save")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a.begins_with("--round="): round_id = a.get_slice("=", 1)
		elif a.begins_with("--seconds="): seconds = float(a.get_slice("=", 1))
		elif a == "--fullscreen": fullscreen = true
		elif a.begins_with("--target="): load("res://src/ui/safe_area.gd").override_target = float(a.get_slice("=", 1))
		elif a.begins_with("--safe="):
			var p := a.get_slice("=", 1).split(",")
			load("res://src/ui/safe_area.gd").override_insets = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	if app == null or save == null or out_dir == "" or DisplayServer.get_name() == "headless":
		printerr("[lane] needs a visible run with --out")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(out_dir)
	save.path = TEST_SAVE
	for f in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	save.load_progress()
	var content: Node = root.get_node("Content")
	var tut: Array = []
	for rid in content.round_order:
		for k in content.get_round(str(rid)).get("tutorial", []):
			tut.append(str(k))
	save.progress["tutorial_done"] = tut
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await _frames(3)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		await _seconds(1.5)
	app.start_round(round_id, true)
	await _frames(4)
	var sim = app.battle.sim
	var view: Node2D = app.battle.view
	var atlas: Node = root.get_node("Atlas")
	# fill the lane: every card type twice, then fast-forward to the first contact, hero with the army
	for rep in 2:
		for id in sim.card_ids:
			sim.gold = maxf(sim.gold, 500.0)
			sim.card_cd[id] = 0.0
			events.cmd_deploy_unit.emit(id)
			for k in 50:
				sim.step(1.0 / 60.0)
			await process_frame
	var guard := 0
	while guard < 300 and not sim.ended:
		var contact := false
		for e in sim.enemies:
			for p in sim.players:
				if e.alive and p.alive and not p.is_hero and absf(e.x - p.x) < 60.0:
					contact = true
		if contact: break
		var front := 0.0
		for p in sim.players:
			if p.alive and not p.is_hero: front = maxf(front, p.x)
		for k in 30:
			sim.set_hero_dir(1 if sim.hero.x < front - 140.0 else 0)
			sim.step(1.0 / 60.0)
		guard += 1
		await process_frame
	sim.set_hero_dir(0)
	await _seconds(1.0)
	var hud := _hud()
	var l: Dictionary = hud.layout
	var bottom: Array = [l.worker, l.move_left, l.move_right] + l.cards + l.skills
	var hud_top := 1e9
	for r in bottom:
		hud_top = minf(hud_top, (r as Rect2).position.y)
	var vsz: Vector2 = root.get_visible_rect().size
	var ground_screen: float = (view.get_canvas_transform() * Vector2(0, view.ground_y)).y
	var worst := 0.0
	var lane_bottom := 0.0
	var samples := 0
	var units_seen := 0
	var occluded_units := 0
	var per_kind := {}
	var t_end := Time.get_ticks_msec() + int(seconds * 1000.0)
	var shot_done := false
	while Time.get_ticks_msec() < t_end:
		await process_frame
		if sim.ended: break
		var xf: Transform2D = view.get_canvas_transform()
		samples += 1
		var all: Array = []
		all.append_array(sim.players)
		all.append_array(sim.enemies)
		for u in all:
			if not u.alive: continue
			var sr := _sprite_rect(view, u, xf, atlas)
			if sr.size == Vector2.ZERO or sr.end.x < 0 or sr.position.x > vsz.x: continue
			units_seen += 1
			lane_bottom = maxf(lane_bottom, sr.end.y)
			var occ := 0.0
			for r in bottom:
				var hr: Rect2 = r
				if sr.position.x < hr.end.x and hr.position.x < sr.end.x:
					occ = maxf(occ, sr.end.y - hr.position.y)
			occ = maxf(occ, 0.0)
			if occ > 0.0: occluded_units += 1
			worst = maxf(worst, occ)
			var k := str(u.id)
			per_kind[k] = maxf(float(per_kind.get(k, 0.0)), occ)
		if not shot_done:
			shot_done = true
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(out_dir.path_join("lane_%s.png" % tag))
	var res := {"tag": tag, "window": DisplayServer.window_get_size(), "view": vsz, "target": hud.target, "safe": hud.safe,
		"display_safe_area": DisplayServer.get_display_safe_area(), "screen": DisplayServer.window_get_current_screen(),
		"ground_screen_y": ground_screen, "lane_bottom_y": lane_bottom, "hud_top_y": hud_top,
		"worst_occluded_px": worst, "occluded_unit_samples": occluded_units, "unit_samples": units_seen, "frames": samples,
		"per_unit_worst_px": per_kind, "card_h": (l.worker as Rect2).size.y, "skills_in_row": l.skills_in_row}
	print("[lane] " + JSON.stringify(res))
	var f := FileAccess.open(out_dir.path_join("lane_%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(res, "  "))
	f.close()
	for fp in [TEST_SAVE, TEST_SAVE + ".bak", TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(fp): DirAccess.remove_absolute(ProjectSettings.globalize_path(fp))
	quit(0)
