extends SceneTree
## 08-performance windowed frame/render probe (DESKTOP PROXY — never phone evidence).
## Boots the real game (scenes/gameplay/main.tscn, real autoloads, real renderer) in autoplay and samples
## every frame. Run (windowed; NOT headless, rendering must be real):
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/performance/perf_frame_probe.gd -- \
##       --autoplay --round=r06 [--perf-seconds=40] [--perf-warmup=3] [--perf-uncapped] [--perf-stress] [--perf-out=<abs.json>]
## --autoplay/--round are consumed by App (src/core/app.gd). --perf-* are consumed here only.
##   --perf-uncapped : vsync off + max_fps 0 after boot -> measures headroom instead of paced 60 fps.
##   --perf-stress   : keeps both armies at the entity caps (gold + cooldown cheats on the live sim) to measure
##                     worst-case draw calls and frame cost. Test-only mutation of the running sim.
##   --perf-ab-view  : alternates 2 s phases with the battle view drawn/hidden to attribute CPU to _draw().
##   --perf-ab-ui    : same, toggling the UI CanvasLayer (visible + process_mode) to attribute HUD cost.
## Performance.TIME_PROCESS is the WORST process time of the previous second (engine updates it once per second),
## so it is reported as process_ms_worst_per_second. Per-frame CPU cost = frame_ms in --perf-uncapped mode.
## Output JSON: per-frame distribution (frame/render CPU/GPU ms), draw calls, primitives, texture/video
## memory, static memory, object/node counts, entity counts, atlas residency. Owner: 08-performance.

var seconds := 40.0
var warmup := 3.0
var uncapped := false
var stress := false
var out_path := ""
var contended := -1   # other Godot processes running (supplied by tools/perf/run_perf.ps1)
var _t := 0.0
var _frames := 0
var _vp_rid: RID
var frame_ms := PackedFloat32Array()
var proc_ms := PackedFloat32Array()
var rcpu_ms := PackedFloat32Array()
var rgpu_ms := PackedFloat32Array()
var sim_ms := PackedFloat32Array()
var draw_calls := PackedInt32Array()
var prims := PackedInt32Array()
var units := PackedInt32Array()
var peak := {"tex_mem": 0, "video_mem": 0, "static_mem": 0, "objects": 0, "nodes": 0, "units": 0, "projectiles": 0, "fx": 0}
var start := {}
var over_budget_frames := {"16.7": 0, "33.3": 0, "50": 0}
var _started := false
var _done := false
var ab_view := false
var ab_target := "view"   # "view" = battle_view node, "ui" = App.ui_layer (HUD/menus)
var _phase_hidden := false
var proc_visible := PackedFloat32Array()
var proc_hidden := PackedFloat32Array()
var frame_visible := PackedFloat32Array()
var frame_hidden := PackedFloat32Array()

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-seconds="): seconds = float(a.get_slice("=", 1))
		elif a.begins_with("--perf-warmup="): warmup = float(a.get_slice("=", 1))
		elif a == "--perf-uncapped": uncapped = true
		elif a == "--perf-stress": stress = true
		elif a == "--perf-ab-view": ab_view = true
		elif a == "--perf-ab-ui":
			ab_view = true
			ab_target = "ui"
		elif a.begins_with("--perf-out="): out_path = a.get_slice("=", 1)
		elif a.begins_with("--perf-contended="): contended = int(a.get_slice("=", 1))
	if out_path == "":
		out_path = ProjectSettings.globalize_path("res://build/perf/frame_latest.json")
	_boot.call_deferred()

func _boot() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("perf_frame_probe needs a window (run without --headless)")
		quit(1)
		return
	var err := change_scene_to_file("res://scenes/gameplay/main.tscn")
	if err != OK:
		printerr("cannot load main scene: ", err)
		quit(1)
		return
	_vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	start = _mon()
	_started = true

func _mon() -> Dictionary:
	return {
		"tex_mem": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"video_mem": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"static_mem": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}

func _process(delta: float) -> bool:
	if not _started or _done:
		return false
	_t += delta
	_frames += 1
	var app := root.get_node_or_null("App")
	var perf := root.get_node_or_null("Perf")
	if uncapped and _frames == 30:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if stress and app and app.battle and app.battle.sim:
		_stress(app.battle.sim)
	if ab_view and app:
		# alternate 2 s phases: target drawn/processed vs hidden (hidden = no _draw, no sprite submission)
		var hide := int(_t / 2.0) % 2 == 1
		if ab_target == "ui" and app.ui_layer:
			app.ui_layer.visible = not hide
			app.ui_layer.process_mode = Node.PROCESS_MODE_DISABLED if hide else Node.PROCESS_MODE_INHERIT
		elif app.battle and app.battle.view:
			app.battle.view.visible = not hide
		_phase_hidden = hide
	if _t < warmup:
		return false
	var fm := delta * 1000.0
	frame_ms.append(fm)
	var pm := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	proc_ms.append(pm)
	if ab_view:
		(proc_hidden if _phase_hidden else proc_visible).append(pm)
		(frame_hidden if _phase_hidden else frame_visible).append(fm)
	rcpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu())
	rgpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
	draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	prims.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	for k in over_budget_frames:
		if fm > float(k): over_budget_frames[k] += 1
	if perf:
		sim_ms.append(float(perf.sim_ms_last))
		units.append(int(perf.counts.units))
		peak.units = maxi(peak.units, int(perf.counts.units))
		peak.projectiles = maxi(peak.projectiles, int(perf.counts.projectiles))
		peak.fx = maxi(peak.fx, int(perf.counts.fx))
	if app and app.battle and app.battle.sim:
		_readability(app.battle.sim, fm)
	var m := _mon()
	for k in ["tex_mem", "video_mem", "static_mem", "objects", "nodes"]:
		peak[k] = maxi(peak[k], m[k])
	if _t >= warmup + seconds:
		_finish(app)
	return false

## Keep both sides at caps: test-only cheat on the live sim.
func _stress(sim) -> void:
	if sim.ended or sim.paused: return
	sim.gold = sim.gold_max
	for id in sim.card_ids:
		sim.card_cd[id] = 0.0
		sim.deploy(id)
	if sim.army_count(-1) < sim.caps.enemy and not sim.round_def.enemy_ai.get("pool", []).is_empty():
		sim._spawn_enemy(str(sim.round_def.enemy_ai.pool[_frames % sim.round_def.enemy_ai.pool.size()]))
	sim.player_base.hp = sim.player_base.hp_max
	sim.enemy_base.hp = sim.enemy_base.hp_max

## R09-08-1 (09-research): simultaneous damage popups / fx / projectiles per frame vs caps, with the frame time of the
## busiest frame. Counted directly from the live sim pools (alive flags), not from Perf.counts.
var readability := {"frames": 0, "max": {"texts": 0, "fx": 0, "projectiles": 0}, "frames_at_cap": {"texts": 0, "fx": 0, "projectiles": 0},
	"caps": {}, "peak_frame": {}}

func _readability(sim, fm: float) -> void:
	var n := {"texts": 0, "fx": 0, "projectiles": 0}
	for x in sim.texts:
		if x.alive: n.texts += 1
	for x in sim.fxs:
		if x.alive: n.fx += 1
	for x in sim.projectiles:
		if x.alive: n.projectiles += 1
	var caps := {"texts": int(sim.caps.text), "fx": int(sim.caps.fx), "projectiles": int(sim.caps.projectiles)}
	readability.caps = caps
	readability.frames += 1
	var load_sum := 0
	for k in n:
		readability.max[k] = maxi(readability.max[k], n[k])
		if n[k] >= caps[k]: readability.frames_at_cap[k] += 1
		load_sum += n[k]
	if readability.peak_frame.is_empty() or load_sum > int(readability.peak_frame.get("sum", -1)):
		readability.peak_frame = {"sum": load_sum, "counts": n, "frame_ms": snappedf(fm, 0.001), "t": snappedf(_t, 0.01),
			"units": sim.players.size() + sim.enemies.size()}

static func _dist(a: PackedFloat32Array) -> Dictionary:
	if a.is_empty(): return {"n": 0}
	var s := a.duplicate()
	s.sort()
	var tot := 0.0
	for x in s: tot += x
	var n := s.size()
	return {"n": n, "avg": snappedf(tot / n, 0.001), "p50": snappedf(s[n / 2], 0.001),
		"p95": snappedf(s[mini(n - 1, int(n * 0.95))], 0.001), "p99": snappedf(s[mini(n - 1, int(n * 0.99))], 0.001),
		"max": snappedf(s[n - 1], 0.001)}

static func _idist(a: PackedInt32Array) -> Dictionary:
	var f := PackedFloat32Array()
	for x in a: f.append(float(x))
	return _dist(f)

func _finish(app) -> void:
	_done = true
	var v := Engine.get_version_info()
	var atlas := root.get_node_or_null("Atlas")
	var rep := {
		"evidence_class": "CONTENDED_DESKTOP_PROXY" if contended > 0 else ("DESKTOP_PROXY" if contended == 0 else "DESKTOP_PROXY_UNVERIFIED_ISOLATION"),
		"concurrent_godot_processes": contended,
		"note": "Windowed desktop run of a DEBUG editor binary; GPU/driver differ from phones. Not phone evidence.",
		"env": {"engine": "%s.%s.%s.%s" % [v.major, v.minor, v.patch, v.status], "os": OS.get_name(),
			"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
			"gpu_vendor": RenderingServer.get_video_adapter_vendor(), "renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
			"window": DisplayServer.window_get_size(), "viewport": root.get_visible_rect().size,
			"screen_refresh": DisplayServer.screen_get_refresh_rate(), "debug_build": OS.is_debug_build(),
			"time": Time.get_datetime_string_from_system(false, true), "args": Array(OS.get_cmdline_user_args())},
		"config": {"seconds": seconds, "warmup": warmup, "uncapped": uncapped, "stress": stress, "max_fps": Engine.max_fps},
		"frames_measured": frame_ms.size(),
		"frame_ms": _dist(frame_ms), "process_ms_worst_per_second": _dist(proc_ms),
		"render_cpu_ms": _dist(rcpu_ms), "render_gpu_ms": _dist(rgpu_ms), "battle_loop_ms": _dist(sim_ms),
		"draw_calls": _idist(draw_calls), "primitives": _idist(prims), "units": _idist(units),
		"frames_over_ms": over_budget_frames,
		"readability_load": readability,
		"ab": {"target": ab_target, "frame_ms_shown": _dist(frame_visible), "frame_ms_hidden": _dist(frame_hidden),
			"process_worst_per_s_shown": _dist(proc_visible), "process_worst_per_s_hidden": _dist(proc_hidden),
			"note": "difference = CPU cost of the target (view = battle_view._draw, 02; ui = HUD/menus, 04 or 02 fallback)"} if ab_view else {},
		"start": start, "end": _mon(), "peak": peak,
		"screen": str(app.screen) if app else "",
		"ui_source": app.ui_source if app else {},
		"atlas": atlas.texture_report() if atlas else {},
		"atlas_warnings": Array(atlas.warnings) if atlas else [],
	}
	var txt := JSON.stringify(rep, "  ")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
	print(txt)
	print("[frame_probe] frames=%d frame_p95=%.2fms gpu_p95=%.2fms draw_calls_p95=%s units_max=%d tex=%.2fMiB -> %s" % [
		frame_ms.size(), rep.frame_ms.get("p95", 0.0), rep.render_gpu_ms.get("p95", 0.0), str(rep.draw_calls.get("p95", 0)),
		peak.units, peak.tex_mem / 1048576.0, out_path])
	quit(0)
