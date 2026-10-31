extends SceneTree
## 07-qa: narrowest safe-area layout, rendered. Launch only via 04's secondary-monitor launcher:
##   .\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/acceptance/capture_narrow.gd `
##       -Resolution 1280x720 -UserArgs '--shot-dir=<abs>','--locale=ko','--tag=ko_2x','--insets=34,0,34,0'
## Applies SafeArea.override_insets (04 test hook: left,top,right,bottom in logical px) and paints the
## unsafe strips opaque black on top (worst case: the cutout shows nothing), then captures menu, settings,
## round select, r08 HUD (5 cards + worker + 3 skills, the narrowest card slot) and the r08 result.
## Per screen it records every visible TouchButton: rect, inside-safe, drawn text, truncated flag; and the
## HUD base HP text as drawn (hud_top.base_labels). No simulation fast-forward: HUD frames are taken
## after real seconds; the result is reached by setting the enemy base HP to 0 (layout check only).
## Owner: 07-qa.

const TouchButtonS := preload("res://src/ui/touch_button.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")

var shot_dir := ""
var tag := "run"
var insets := Vector4(34, 0, 34, 0)
var app: Node
var report := {"screens": {}}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="): shot_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a.begins_with("--locale="): load("res://src/ui/ui_text.gd").load_locale(a.get_slice("=", 1))
		elif a.begins_with("--insets="):
			var p := a.get_slice("=", 1).split(",")
			insets = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	var save = root.get_node_or_null("Save")
	if save:
		DirAccess.make_dir_recursive_absolute("user://qa07")
		save.path = "user://qa07/narrow_save.json"
		save.progress = save.fresh()
		save.progress.unlocked_round = 10
		save.progress.stars = {"r01": 3, "r02": 2, "r03": 1}
		save.save_progress()
	SafeArea.override_insets = insets
	_run.call_deferred()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _frames(n := 3) -> void:
	for i in n: await process_frame

func _mask() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 128
	root.add_child(cl)
	var v := root.get_visible_rect().size
	for r in [Rect2(0, 0, insets.x, v.y), Rect2(v.x - insets.z, 0, insets.z, v.y), Rect2(0, 0, v.x, insets.y), Rect2(0, v.y - insets.w, v.x, insets.w)]:
		if r.size.x <= 0 or r.size.y <= 0: continue
		var c := ColorRect.new()
		c.color = Color.BLACK
		c.position = r.position
		c.size = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(c)

func _buttons(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		if c is Control and c.get_script() == TouchButtonS and c.is_visible_in_tree(): out.append(c)
		_buttons(c, out)
	return out

func _find(n: Node, suffix: String) -> Node:
	for c in n.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(suffix): return c
		var r := _find(c, suffix)
		if r: return r
	return null

func _record(name: String) -> void:
	await _frames(4)
	var v := root.get_visible_rect().size
	var safe := Rect2(insets.x, insets.y, v.x - insets.x - insets.z, v.y - insets.y - insets.w)
	var rows := []
	var bad := []
	for b in _buttons(app.ui_layer):
		var r: Rect2 = b.get_global_rect()
		var row := {"text": str(b.text), "drawn": str(b.get("last_text_drawn")), "truncated": bool(b.get("last_text_truncated")),
			"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "inside_safe": safe.grow(0.5).encloses(r)}
		rows.append(row)
		if row.truncated or not row.inside_safe: bad.append(row)
	var entry := {"buttons": rows, "problems": bad, "safe": [safe.position.x, safe.position.y, safe.size.x, safe.size.y]}
	var top := _find(app.ui_layer, "ui/hud_top.gd")
	if top and top.get("base_labels") is Dictionary:
		entry["base_hp_drawn"] = top.base_labels.duplicate()
		var sim = app.battle.sim if app.battle else null
		if sim:
			entry["base_hp_full"] = {"player": "%d/%d" % [ceili(sim.player_base.hp), ceili(sim.player_base.hp_max)], "enemy": "%d/%d" % [ceili(sim.enemy_base.hp), ceili(sim.enemy_base.hp_max)]}
	report.screens[name] = entry
	if shot_dir != "" and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(shot_dir)
		root.get_texture().get_image().save_png(shot_dir.path_join("%s_%s.png" % [tag, name]))

func _run() -> void:
	app = root.get_node("App")
	var main: Node = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(main)
	_mask()
	await _frames(6)
	root.size_changed.emit()
	report.view = root.get_visible_rect().size
	report.insets = [insets.x, insets.y, insets.z, insets.w]
	await _record("1_menu")
	var ev := root.get_node("Events")
	ev.cmd_open_screen.emit(&"round_select")
	await _record("2_round_select")
	ev.cmd_start_round.emit("r08")
	await _wait(3.0)            # real time; no sim fast-forward
	await _record("3_r08_hud")
	var sim = app.battle.sim if app.battle else null
	if sim:
		sim._damage_base(-1, float(sim.enemy_base.hp) + 1.0)
		await _wait(1.8)
		await _record("4_r08_result")
	var n := 0
	for s in report.screens: n += (report.screens[s].problems as Array).size()
	report.total_problems = n
	if shot_dir != "":
		var f := FileAccess.open(shot_dir.path_join(tag + "_narrow_report.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[narrow] ", JSON.stringify({"tag": tag, "problems": n, "screens": report.screens.keys()}))
	quit(0)
