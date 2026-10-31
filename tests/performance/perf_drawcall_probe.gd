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
	_started = true

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
	for k in VIEW_CATS + ["+pagesort", "+rowsort", "+merge1sim", "+merge2sim", "+merge2sim_row"]:
		PHASES.append("view_only#%d" % n)
		PHASES.append(("view_only-" + k) if not k.begins_with("+") else "view_only" + k)   # +pagesort / +rowsort: drawcall_view.gd sort modes
		n += 1
	for c in _hud_children:
		PHASES.append("hud_only#%d" % n)
		PHASES.append("hud_only-" + str(c.name))
		n += 1
	for ph in PHASES: samples[ph] = {"dc": PackedInt32Array(), "prims": PackedInt32Array(), "units": PackedInt32Array(), "proj": PackedInt32Array(), "fx": PackedInt32Array(), "texts": PackedInt32Array(),
		"runs_real": PackedInt32Array(), "runs_row": PackedInt32Array(), "runs_merge2": PackedInt32Array(), "runs_merge1": PackedInt32Array(), "runs_row_merge2": PackedInt32Array()}

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
			"unit_page_runs_median": {"real": _med(s.runs_real), "row": _med(s.runs_row), "merge2": _med(s.runs_merge2), "merge1": _med(s.runs_merge1), "row_merge2": _med(s.runs_row_merge2)}})
		if is_ref and ph != "all":
			prev_ref = _med(s.dc)
			prev_name = ph
	var v := Engine.get_version_info()
	var rep := {"evidence_class": "CONTENDED_DESKTOP_PROXY" if contended > 0 else ("DESKTOP_PROXY" if contended == 0 else "DESKTOP_PROXY_UNVERIFIED_ISOLATION"),
		"concurrent_godot_processes": contended,
		"note": "Draw calls are counted by the renderer per frame (whole frame incl. HUD). Deltas are not additive (batching). Desktop debug binary, GL Compatibility; phone GPUs/drivers may batch differently.",
		"env": {"engine": "%s.%s.%s" % [v.major, v.minor, v.patch], "gpu": RenderingServer.get_video_adapter_name(), "window": DisplayServer.window_get_size(),
			"args": Array(OS.get_cmdline_user_args()), "time": Time.get_datetime_string_from_system(false, true)},
		"config": {"warmup": warmup, "phase_s": phase_s, "cycles": cycles}, "rows": rows, "timeline": timeline,
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
	for h in _hud_info:
		print("[drawcalls] hud child %-14s %-14s %-34s desc=%3d rect=%s text=%s" % [h.name, h["class"], h.script, h.descendants, str(h.get("rect", [])), h.text])
	print("[drawcalls] report ", out_path)
	quit(0)
