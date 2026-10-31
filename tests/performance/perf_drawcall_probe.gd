extends SceneTree
## 08-performance draw-call breakdown probe (DESKTOP PROXY, windowed; never phone evidence).
## Boots the real game, holds both armies at caps (stress cheat, same rules as perf_frame_probe: round roster refill, base HP reset),
## then swaps 02's battle view for tests/performance/drawcall_view.gd (same drawing + category switches) and records
## RENDER_TOTAL_DRAW_CALLS_IN_FRAME / primitives per frame in interleaved phases (HUD state drifts, so every removal phase is compared
## with the reference phase measured right before it):
##   all | view_only#n, view_only-<cat> (HUD hidden; cat = background, bases, units, bars, projectiles, fx, texts)
##       | view_only#n, view_only+pagesort (experiment floor) | view_only#n, view_only+rowsort (tie-only reorder candidate)
##       | view_only#n, view_only+merge1sim / +merge2sim / +merge2sim_row (SIMULATED page merge: one or two shared textures, counts only)
##       | hud_only#n, hud_only-<child> (battle view hidden; one direct HUD child hidden; children identified by script/text in the report)
## "delta" = reference median minus phase median. Batching makes deltas non-additive. Unit page runs per frame are counted for the
## shipped pages and for hypothetical merged pages (drawcall_view.gd `runs`).
## Run (secondary monitor, e.g. --screen 1; use a git-archive snapshot with its own --import so .godot/imported matches the commit):
##   Godot_console.exe --screen 1 --resolution 1280x720 --path <snap> -s res://tests/performance/perf_drawcall_probe.gd -- \
##       --autoplay --round=r08 [--dc-warmup=35] [--dc-phase=2.5] [--dc-cycles=1] [--dc-out=<abs.json>] [--perf-contended=N]
## Owner: 08-performance.

const ViewSub := preload("res://tests/performance/drawcall_view.gd")
const VIEW_CATS := ["background", "bases", "units", "bars", "projectiles", "fx", "texts"]
var PHASES: Array = []
var _hud_root: Control = null
var _hud_children: Array = []
var _hud_info: Array = []

static func _count_desc(n: Node) -> int:
	var k := 0
	for c in n.get_children(): k += 1 + _count_desc(c)
	return k

static func _first_text(n: Node) -> String:
	for prop in ["text", "label", "title"]:
		if prop in n and typeof(n.get(prop)) == TYPE_STRING and str(n.get(prop)) != "": return str(n.get(prop)).left(24)
	for c in n.get_children():
		var t := _first_text(c)
		if t != "": return t
	return ""

var warmup := 35.0
var phase_s := 3.0
var cycles := 2
var out_path := ""
var contended := -1
## --dc-set=units : only "all", "view_only#0", "view_only-units" (repeated --dc-cycles times) for build-vs-build A/B of unit cost.
## --dc-uncapped  : vsync off + max_fps 0, so per-phase frame time is CPU+GPU cost, not the 16.7 ms pacing.
var phase_set := "full"
var uncapped := false
var _uncap_resets := 0
## --dc-window=WxH : borderless window of exactly W×H physical px (e.g. 2400x1080 = a phone at integer scale 3 with the 640×360 base).
##   The window is aligned to the secondary screen on the side away from the primary, so any overflow is OFF-SCREEN (never on the
##   primary monitor); the GPU still renders the whole W×H back buffer.
## --dc-zoom=Z     : world camera zoom Z (e.g. 1.3333 = 02's (k+1)/k at k=3), applied like 04's tests/integration/zoom_preview.gd CamFix
##   (after battle.gd each frame; ground kept 70 px above the view bottom). Test-only; 02 has no zoom flag yet.
var win_req := Vector2i.ZERO
var zoom := 1.0
var _win_done := false
var _win_info := {}
var _alpha_done := false
var _camfix: Node = null

class CamFix extends Node:
	var battle: Node
	var view: Node
	var z := 1.0
	func _process(_d: float) -> void:
		if battle == null or not is_instance_valid(battle) or battle.sim == null or view == null: return
		var vs: Vector2 = battle.get_viewport_rect().size
		var half := vs.x * 0.5 / z
		var cx := clampf(float(battle.cam.position.x), -90.0 + half, float(battle.sim.L) + 50.0 - half)
		var gy: float = view.ground_y
		var cy := gy - (vs.y * 0.5 - 70.0) / z
		battle.cam.zoom = Vector2(z, z)
		battle.cam.position = Vector2(roundf(cx), cy)
		view.view_w = vs.x / z
		view.cam_x = cx
		view.view_top = cy - vs.y * 0.5 / z
		view.view_bottom = cy + vs.y * 0.5 / z
var _vp_rid := RID()
var _t := 0.0
var _started := false
var _done := false
var _mine = null
var _orig = null
var _ids: Array = []
var _phase_i := -1
var _cycle := 0
var _phase_t := 0.0
var samples := {}          # phase -> {"dc": [], "prims": [], "counts": [..]}
var timeline := []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dc-warmup="): warmup = float(a.get_slice("=", 1))
		elif a.begins_with("--dc-phase="): phase_s = float(a.get_slice("=", 1))
		elif a.begins_with("--dc-cycles="): cycles = int(a.get_slice("=", 1))
		elif a.begins_with("--dc-out="): out_path = a.get_slice("=", 1)
		elif a.begins_with("--perf-contended="): contended = int(a.get_slice("=", 1))
		elif a.begins_with("--dc-set="): phase_set = a.get_slice("=", 1)
		elif a == "--dc-uncapped": uncapped = true
		elif a.begins_with("--dc-window="):
			var wh := a.get_slice("=", 1).split("x")
			if wh.size() == 2: win_req = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--dc-zoom="): zoom = float(a.get_slice("=", 1))
	if out_path == "":
		out_path = ProjectSettings.globalize_path("res://build/perf/drawcalls_latest.json")
	_boot.call_deferred()

func _boot() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("perf_drawcall_probe needs a window")
		quit(1)
		return
	if change_scene_to_file("res://scenes/gameplay/main.tscn") != OK:
		quit(1)
		return
	_vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	if uncapped:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_started = true

## Borderless window of win_req physical px on the current (secondary) screen; overflow goes to the side away from the primary
## screen, so it is off-screen and never on the primary monitor.
func _apply_window() -> void:
	_win_done = true
	var scr := DisplayServer.window_get_current_screen()
	var sp := DisplayServer.screen_get_position(scr)
	var ss := DisplayServer.screen_get_size(scr)
	var prim := DisplayServer.get_primary_screen()
	var pp := DisplayServer.screen_get_position(prim)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	var x := sp.x if sp.x >= pp.x else sp.x + ss.x - win_req.x
	DisplayServer.window_set_size(win_req)
	DisplayServer.window_set_position(Vector2i(x, sp.y))
	_win_info = {"requested": win_req, "screen": scr, "screen_pos": sp, "screen_size": ss, "primary": prim, "primary_pos": pp,
		"set_position": Vector2i(x, sp.y), "on_primary_screen": scr == prim}

## Alpha statistics of every character-page frame: destination quad = frame rect; bbox = used (alpha > 0) rect; opaque = alpha > 0
## pixel count. drawcall_view.gd sums them for the frames actually drawn, so the report gives quad / bbox / opaque fill per frame.
var _alpha := {}   # tex rid id -> {Vector4i(x, y, w, h): Vector3i(quad, bbox, opaque)}
var _alpha_ms := 0
func _precompute_alpha() -> void:
	var atlas = root.get_node_or_null("Atlas")
	if atlas == null: return
	var t0 := Time.get_ticks_msec()
	for id in atlas.pages:
		if not str(id).begins_with("char_"): continue
		var p = atlas.pages[id]
		if p.tex == null: continue
		var img: Image = p.tex.get_image()
		if img == null: continue
		if img.is_compressed(): img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8: img.convert(Image.FORMAT_RGBA8)
		var table := {}
		for fname in p.frames:
			var f = p.frames[fname]
			var r := Rect2i(int(f.x), int(f.y), int(f.w), int(f.h))
			var k := Vector4i(r.position.x, r.position.y, r.size.x, r.size.y)
			if table.has(k): continue
			var sub := img.get_region(r)
			var used := sub.get_used_rect()
			var data := sub.get_data()
			var opaque := 0
			var i := 3
			while i < data.size():
				if data[i] > 0: opaque += 1
				i += 4
			table[k] = Vector3i(r.size.x * r.size.y, used.size.x * used.size.y, opaque)
		_alpha[p.tex.get_rid().get_id()] = table
	_alpha_ms = Time.get_ticks_msec() - t0

func _stress(sim) -> void:
	if sim.ended or sim.paused: return
	if _ids.is_empty():
		var content = root.get_node_or_null("Content")
		if content and content.has_method("round_enemy_roster"):
			for id in content.round_enemy_roster(sim.round_def):
				var d: Dictionary = content.get_unit(str(id))
				if not ((d.get("tags", []) as Array).has("boss") or bool(d.get("is_boss", false))): _ids.append(str(id))
	sim.gold = sim.gold_max
	for id in sim.card_ids:
		sim.card_cd[id] = 0.0
		sim.deploy(id)
	var g := 0
	while not _ids.is_empty() and sim.army_count(-1) < sim.caps.enemy and g < 4:
		sim._spawn_enemy(str(_ids[(int(_t * 60.0) + g) % _ids.size()]))
		g += 1
	sim.player_base.hp = sim.player_base.hp_max
	sim.enemy_base.hp = sim.enemy_base.hp_max

func _swap_view(battle) -> void:
	_orig = battle.view
	_mine = ViewSub.new()
	_mine.name = "View08"
	battle.add_child(_mine)
	battle.move_child(_mine, _orig.get_index() + 1)
	_mine.setup(battle.sim, root.get_node("Atlas"), _orig.ground_y, _orig.biome)
	_mine.show_damage = _orig.show_damage
	_mine.analyze_runs = phase_set != "units"
	_mine.alpha_stats = _alpha
	_mine.cam_x = _orig.cam_x
	_mine.view_w = _orig.view_w
	_mine.view_top = _orig.view_top
	_mine.view_bottom = _orig.view_bottom
	if absf(zoom - 1.0) > 0.001:
		_camfix = CamFix.new()
		_camfix.name = "CamFix08"
		_camfix.battle = battle
		_camfix.view = _mine
		_camfix.z = zoom
		_camfix.process_priority = 1000   # after battle.gd's camera update in the same frame
		battle.add_child(_camfix)
	_win_info["actual_window"] = DisplayServer.window_get_size()
	_win_info["actual_position"] = DisplayServer.window_get_position()
	_win_info["view_size"] = root.get_visible_rect().size
	_win_info["canvas_scale"] = root.get_final_transform().get_scale().x
	_orig.visible = false
	var app := root.get_node("App")
	if app.ui_layer:
		for c in app.ui_layer.get_children():
			if c is Control and (c as Control).visible: _hud_root = c
	if _hud_root:
		for c in _hud_root.get_children():
			if c is CanvasItem and (c as CanvasItem).visible and _hud_children.size() < 40: _hud_children.append(c)
	# Identify auto-named children (@Control@2 ...) by class, script and descendants so the report says which HUD part costs what.
	for c in _hud_children:
		var scr = c.get_script()
		var info := {"name": str(c.name), "class": c.get_class(), "script": scr.resource_path if scr else "",
			"descendants": _count_desc(c), "text": _first_text(c)}
		if c is Control:
			info["rect"] = [int(c.position.x), int(c.position.y), int(c.size.x), int(c.size.y)]
		_hud_info.append(info)
	# Interleaved references (A B A C A D ...): HUD/scene state drifts over time, so each removal phase is compared with the reference
	# phase measured immediately before it. Reference phases get a "#n" suffix so every phase has its own samples.
	PHASES = ["all"]
	var n := 0
	if phase_set == "units":
		PHASES = ["all", "view_only#0", "view_only-units"]
	else:
		for k in VIEW_CATS + ["+pagesort", "+rowsort", "+merge1sim", "+merge2sim", "+merge2sim_row"]:
			PHASES.append("view_only#%d" % n)
			PHASES.append(("view_only-" + k) if not k.begins_with("+") else "view_only" + k)   # +pagesort / +rowsort: drawcall_view.gd sort modes
			n += 1
		for c in _hud_children:
			PHASES.append("hud_only#%d" % n)
			PHASES.append("hud_only-" + str(c.name))
			n += 1
	for ph in PHASES: samples[ph] = {"dc": PackedInt32Array(), "prims": PackedInt32Array(), "units": PackedInt32Array(), "proj": PackedInt32Array(), "fx": PackedInt32Array(), "texts": PackedInt32Array(),
		"runs_real": PackedInt32Array(), "runs_row": PackedInt32Array(), "runs_merge2": PackedInt32Array(), "runs_merge1": PackedInt32Array(), "runs_row_merge2": PackedInt32Array(),
		"frame_ms": PackedFloat32Array(), "draw_us": PackedInt32Array(), "unit_us": PackedInt32Array(), "gpu_ms": PackedFloat32Array(), "rcpu_ms": PackedFloat32Array(), "unit_px": PackedInt32Array(), "unit_bbox": PackedInt32Array(), "unit_opaque": PackedInt32Array(), "on_px": PackedInt32Array(), "on_bbox": PackedInt32Array(), "on_opaque": PackedInt32Array()}

func _apply_phase(app, name: String) -> void:
	for k in _mine.cats: _mine.cats[k] = true
	_mine.visible = true
	if app.ui_layer: app.ui_layer.visible = true
	for c in _hud_children: c.visible = true
	_mine.set_sort_mode("page" if name == "view_only+pagesort" else ("row" if (name == "view_only+rowsort" or name == "view_only+merge2sim_row") else "lane"))
	_mine.tex_mode = "merge1" if name == "view_only+merge1sim" else ("merge2" if name.begins_with("view_only+merge2sim") else "real")   # SIMULATED binding, counts only
	if name.begins_with("view_only"):   # "view_only#n" = reference
		if app.ui_layer: app.ui_layer.visible = false
		if name.begins_with("view_only-"): _mine.cats[name.substr(10)] = false   # "+pagesort" / "#n" keep all cats on
	elif name.begins_with("hud_only"):
		_mine.visible = false
		if name.begins_with("hud_only-"):
			for c in _hud_children:
				if "hud_only-" + str(c.name) == name: c.visible = false

func _process(delta: float) -> bool:
	if not _started or _done: return false
	_t += delta
	var app := root.get_node_or_null("App")
	if app == null or app.battle == null or app.battle.sim == null: return false
	# the Perf autoload re-applies the settings fps cap (clamped 30..60) after boot, so hold the uncapped state every frame
	if uncapped and Engine.max_fps != 0:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		_uncap_resets += 1
	if win_req != Vector2i.ZERO and not _win_done and _t > 1.0:
		_apply_window()
	if not _alpha_done and _t > warmup * 0.5:
		_alpha_done = true
		_precompute_alpha()
	var battle = app.battle
	_stress(battle.sim)
	if _mine == null:
		if _t < warmup: return false
		_swap_view(battle)
		_phase_i = 0
		_phase_t = 0.0
		_apply_phase(app, PHASES[0])
		timeline.append({"t": snappedf(_t, 0.01), "phase": PHASES[0], "cycle": 0})
		return false
	if _camfix == null:   # zoom mode: CamFix08 sets the view fields after battle.gd each frame
		_mine.cam_x = _orig.cam_x
		_mine.view_w = _orig.view_w
		_mine.view_top = _orig.view_top
		_mine.view_bottom = _orig.view_bottom
	_phase_t += delta
	# skip the first 0.5 s of each phase (canvas re-record + settle), then sample every frame
	if _phase_t > 0.5:
		var ph: String = PHASES[_phase_i]
		var s: Dictionary = samples[ph]
		s.dc.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		s.prims.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		var sim = battle.sim
		var na := 0
		for p in sim.projectiles: if p.alive: na += 1
		var nf := 0
		for f in sim.fxs: if f.alive: nf += 1
		var nt := 0
		for x in sim.texts: if x.alive: nt += 1
		s.units.append(sim.players.size() + sim.enemies.size())
		s.proj.append(na)
		s.fx.append(nf)
		s.texts.append(nt)
		if _mine.visible and _mine.cats.units:   # hidden view => _draw not called, runs would be stale
			for k in ["real", "row", "merge2", "merge1", "row_merge2"]: s["runs_" + k].append(int(_mine.runs[k]))
		s.frame_ms.append(delta * 1000.0)
		if _mine.visible:
			s.draw_us.append(int(_mine.draw_us))
			if _mine.cats.units:
				s.unit_us.append(int(_mine.unit_us))
				s.unit_px.append(int(_mine.unit_quad_px))
				s.unit_bbox.append(int(_mine.unit_bbox_px))
				s.unit_opaque.append(int(_mine.unit_opaque_px))
				s.on_px.append(int(_mine.unit_onscreen_px))
				s.on_bbox.append(int(_mine.unit_onscreen_bbox_px))
				s.on_opaque.append(int(_mine.unit_onscreen_opaque_px))
		s.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
		s.rcpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu())
	if _phase_t >= phase_s:
		_phase_i += 1
		if _phase_i >= PHASES.size():
			_phase_i = 0
			_cycle += 1
			if _cycle >= cycles:
				_finish(app)
				return false
		_phase_t = 0.0
		_apply_phase(app, PHASES[_phase_i])
		timeline.append({"t": snappedf(_t, 0.01), "phase": PHASES[_phase_i], "cycle": _cycle})
	return false

static func _med(a: PackedInt32Array) -> float:
	if a.is_empty(): return -1.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2])

static func _mean(a: PackedInt32Array) -> float:
	if a.is_empty(): return -1.0
	var t := 0
	for x in a: t += x
	return snappedf(float(t) / a.size(), 0.01)

## p50 / p95 / mean of a float series (frame or render times, ms)
static func _fdist(a: PackedFloat32Array) -> Dictionary:
	if a.is_empty(): return {}
	var s := a.duplicate()
	s.sort()
	var t := 0.0
	for x in s: t += x
	return {"n": s.size(), "p50": snappedf(s[s.size() / 2], 0.001), "p95": snappedf(s[mini(s.size() - 1, int(s.size() * 0.95))], 0.001),
		"mean": snappedf(t / s.size(), 0.001)}

static func _idist(a: PackedInt32Array) -> Dictionary:
	if a.is_empty(): return {}
	var f := PackedFloat32Array()
	for x in a: f.append(float(x))
	return _fdist(f)

func _finish(app) -> void:
	_done = true
	var rows := []
	var ref_all := _med(samples["all"].dc) if samples.has("all") else -1.0
	var prev_ref := ref_all
	var prev_name := "all"
	for ph in PHASES:
		var s: Dictionary = samples[ph]
		var is_ref: bool = ph == "all" or ph.contains("#")
		var ref := prev_ref
		var ref_name := prev_name
		if is_ref:
			ref = ref_all
			ref_name = "all"
		rows.append({"phase": ph, "frames": s.dc.size(), "draw_calls_median": _med(s.dc), "draw_calls_mean": _mean(s.dc),
			"primitives_median": _med(s.prims), "delta_vs_ref": (ref - _med(s.dc)) if ph != "all" else 0.0,
			"ref": ref_name,
			"units_median": _med(s.units), "projectiles_median": _med(s.proj), "fx_median": _med(s.fx), "texts_median": _med(s.texts),
			"unit_page_runs_median": {"real": _med(s.runs_real), "row": _med(s.runs_row), "merge2": _med(s.runs_merge2), "merge1": _med(s.runs_merge1), "row_merge2": _med(s.runs_row_merge2)},
			"frame_ms": _fdist(s.frame_ms), "view_draw_us": _idist(s.draw_us), "unit_draw_us": _idist(s.unit_us), "unit_quad_px": _idist(s.unit_px), "unit_bbox_px": _idist(s.unit_bbox), "unit_opaque_px": _idist(s.unit_opaque), "onscreen_quad_px": _idist(s.on_px), "onscreen_bbox_px": _idist(s.on_bbox), "onscreen_opaque_px": _idist(s.on_opaque),
			"render_gpu_ms": _fdist(s.gpu_ms), "render_cpu_ms": _fdist(s.rcpu_ms)})
		if is_ref and ph != "all":
			prev_ref = _med(s.dc)
			prev_name = ph
	var v := Engine.get_version_info()
	var rep := {"evidence_class": "CONTENDED_DESKTOP_PROXY" if contended > 0 else ("DESKTOP_PROXY" if contended == 0 else "DESKTOP_PROXY_UNVERIFIED_ISOLATION"),
		"concurrent_godot_processes": contended,
		"note": "Draw calls are counted by the renderer per frame (whole frame incl. HUD). Deltas are not additive (batching). Desktop debug binary, GL Compatibility; phone GPUs/drivers may batch differently.",
		"env": {"engine": "%s.%s.%s" % [v.major, v.minor, v.patch], "gpu": RenderingServer.get_video_adapter_name(), "window": DisplayServer.window_get_size(),
			"args": Array(OS.get_cmdline_user_args()), "time": Time.get_datetime_string_from_system(false, true)},
		"config": {"warmup": warmup, "phase_s": phase_s, "cycles": cycles, "phase_set": phase_set, "uncapped": uncapped, "max_fps": Engine.max_fps,
			"uncap_resets": _uncap_resets, "vsync": DisplayServer.window_get_vsync_mode(), "zoom": zoom, "window": _win_info, "alpha_precompute_ms": _alpha_ms, "alpha_pages": _alpha.size()}, "rows": rows, "timeline": timeline,
		"last_drawn_counts": _mine.drawn if _mine else {}, "last_page_units": _mine.page_units if _mine else {}, "hud_children": _hud_info}
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(rep, "  "))
		f.close()
	for r in rows:
		var pr: Dictionary = r.unit_page_runs_median
		print("[drawcalls] %-28s median=%5.0f mean=%7.2f delta=%5.0f (vs %s) prims=%6.0f units=%3.0f proj=%2.0f fx=%2.0f texts=%2.0f runs real/row/m2/m1/row_m2=%.0f/%.0f/%.0f/%.0f/%.0f frames=%d" % [
			r.phase, r.draw_calls_median, r.draw_calls_mean, r.delta_vs_ref, r.ref, r.primitives_median, r.units_median, r.projectiles_median, r.fx_median, r.texts_median,
			pr.real, pr.row, pr.merge2, pr.merge1, pr.row_merge2, r.frames])
	print("[drawcalls] last frame units per page ", _mine.page_units if _mine else {})
	for r in rows:
		if (r.frame_ms as Dictionary).is_empty(): continue
		print("[timing] %-20s frame_ms p50=%.3f p95=%.3f mean=%.3f | view_draw_us p50=%s | unit_draw_us p50=%s | gpu_ms p50=%s | render_cpu_ms p50=%s" % [
			r.phase, r.frame_ms.p50, r.frame_ms.p95, r.frame_ms.mean, str(r.view_draw_us.get("p50", "-")), str(r.unit_draw_us.get("p50", "-")),
			str(r.render_gpu_ms.get("p50", "-")), str(r.render_cpu_ms.get("p50", "-"))])
	for h in _hud_info:
		print("[drawcalls] hud child %-14s %-14s %-34s desc=%3d rect=%s text=%s" % [h.name, h["class"], h.script, h.descendants, str(h.get("rect", [])), h.text])
	print("[drawcalls] report ", out_path)
	quit(0)
