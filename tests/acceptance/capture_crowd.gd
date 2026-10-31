extends SceneTree
## 07-qa: r08 crowd in REAL TIME (no simulation fast-forward). Launch only via the secondary-monitor launcher:
##   .\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/acceptance/capture_crowd.gd `
##       -Resolution 1280x720 -TimeoutSec 400 -UserArgs '--autoplay','--round=r08','--shot-dir=<abs>','--locale=ko','--tag=ko_2x','--seconds=180'
## '--autoplay --round=r08' makes App start r08 with the 02 competent bot stepping at the normal fixed
## step in _process (battle.gd), i.e. game time == wall time. Every rendered frame the script samples:
## visible transient HUD messages (toast, tutorial hint, wave banner, skill tip) with their text-tight
## rectangles, pairwise overlaps, live units/projectiles/damage numbers; screenshots every --every s
## (default 3) and at the peak-unit frame. Owner: 07-qa.

const UiStyle := preload("res://src/ui/ui_style.gd")

var shot_dir := ""
var tag := "run"
var seconds := 180.0
var every := 3.0
var app: Node
var timeline := []
var overlaps := {}
var peak := {"units": -1}
var _next_shot := 1.0
var _t0 := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a.begins_with("--seconds="): seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--every="): every = float(a.get_slice("=", 1))
		elif a.begins_with("--locale="): load("res://src/ui/ui_text.gd").load_locale(a.get_slice("=", 1))
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://qa07")
		save.path = "user://qa07/crowd_save.json"
	_run.call_deferred()

func _find(n: Node, suffix: String) -> Node:
	for c in n.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(suffix): return c
		var r := _find(c, suffix)
		if r: return r
	return null

func _tight(l: Label) -> Rect2:
	var r: Rect2 = l.get_global_rect()
	var fs := l.get_theme_font_size("font_size")
	var f := l.get_theme_font("font")
	var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := f.get_height(fs)
	return Rect2(r.position.x + (r.size.x - w) / 2.0, r.position.y + (r.size.y - h) / 2.0, w, h)

func _shot(name: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(shot_dir)
	root.get_texture().get_image().save_png(shot_dir.path_join("%s_%s.png" % [tag, name]))

func _run() -> void:
	app = root.get_node("App")
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	_t0 = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - _t0) / 1000.0 < seconds:
		await process_frame
		var wall := (Time.get_ticks_msec() - _t0) / 1000.0
		var sim = app.battle.sim if app.battle else null
		var hud := _find(app.ui_layer, "ui/hud.gd")
		if sim == null or hud == null: continue
		var msgs := []
		for nm in ["toast_label", "tutorial_label", "banner_label", "skill_tip"]:
			var l = hud.get(nm)
			if l is Label and l.is_visible_in_tree() and l.modulate.a > 0.05 and str(l.text) != "":
				msgs.append({"which": nm, "text": str(l.text), "rect": _tight(l)})
		var ov := []
		for i in msgs.size():
			for j in range(i + 1, msgs.size()):
				if (msgs[i].rect as Rect2).intersects(msgs[j].rect):
					var k: String = "%s+%s" % [msgs[i].which, msgs[j].which]
					ov.append(k)
					if not overlaps.has(k): overlaps[k] = {"first_wall_s": snappedf(wall, 0.01), "frames": 0, "texts": [msgs[i].text, msgs[j].text]}
					overlaps[k].frames += 1
		var units := 0
		for u in sim.players: if not u.dying: units += 1
		for u in sim.enemies: if not u.dying: units += 1
		var proj := 0
		for p in sim.projectiles: if p.alive: proj += 1
		var txt := 0
		for tx in sim.texts: if tx.alive: txt += 1
		timeline.append([snappedf(wall, 0.01), snappedf(sim.t, 0.01), units, proj, txt, msgs.size(), ov.size()])
		if units > int(peak.units) and units >= 8:
			peak = {"units": units, "wall_s": wall, "sim_t": sim.t, "projectiles": proj, "damage_texts": txt}
			_shot("peak")
		if wall >= _next_shot:
			_next_shot += every
			_shot("t%03d" % int(wall))
		if sim.ended and wall > 2.0:
			_shot("end")
			break
	# summary
	var max_msgs := 0
	var frames_2 := 0
	var drift := 0.0
	for row in timeline:
		max_msgs = maxi(max_msgs, int(row[5]))
		if int(row[5]) >= 2: frames_2 += 1
		drift = maxf(drift, absf(float(row[0]) - float(row[1])))
	var rep := {"tag": tag, "frames": timeline.size(), "wall_s": timeline.back()[0] if timeline.size() > 0 else 0,
		"sim_t_end": timeline.back()[1] if timeline.size() > 0 else 0, "max_wall_minus_sim_s": snappedf(drift, 0.01),
		"max_simultaneous_messages": max_msgs, "frames_with_2plus_messages": frames_2, "overlaps": overlaps, "peak": peak,
		"ended": app.battle != null and app.battle.sim != null and app.battle.sim.ended,
		"won": app.battle.sim.won if app.battle and app.battle.sim else null, "timeline_cols": ["wall", "sim_t", "units", "projectiles", "damage_texts", "messages", "overlaps"], "timeline": timeline}
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join(tag + "_crowd_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(rep))
		f.close()
	rep.erase("timeline")
	print("[crowd] ", JSON.stringify(rep))
	quit(0)
