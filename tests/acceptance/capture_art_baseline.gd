extends SceneTree
## 07-qa independent graphics baseline: a FIXED capture set that any later art change can be compared against.
## Visible runs only, through 04's secondary-monitor launcher (isolated APPDATA by default), inside heavy_run.ps1:
##   .\tools\build\visible_launch.ps1 -ProjectPath $env:TEMP\qa07_head -Script res://tests/acceptance/capture_art_baseline.gd `
##       -Resolution 800x360 -UserArgs '--out=<abs dir>','--tag=ko_1x','--locale=ko','--safe=34,0,34,0','--target=44'
## 393x873 dp phone condition (04 docs/qa/ZOOM_PREVIEW.md): 800x360 logical view, notches 34/34, touch target 44.
## 1x = 800x360 window, 2x = 1600x720 window (same layout). --dry: headless self-check (no images).
## Scenes (same frames on every re-run: the sim is stepped ONLY by this script with a fixed step count, the battle seed
## is fixed with seed(4242) before App.start_round, the camera is snapped to hero x + 60 every frame, screen shake
## offset is zeroed, transient toasts are allowed to expire before each capture, tutorials are marked done):
##   1_menu                 main menu after boot
##   2_r01_t10, 3_r01_t30   r01, competent bot (bot_player policy 2), LOW upgrades, 600 / 1800 steps
##   4_r06_t46              04's scenario exactly: r06, no upgrades, 17 scripted deploys, hero 150 px behind the
##                          front, 2760 steps (04/03 captured at t = 46.02 because their first frames ran in real time)
##   5_r08_peak             r08, competent bot, LOW upgrades; step chosen by a pure-sim pre-pass = most units inside
##                          the camera (0.25 s grid, t >= 20 s, earliest on ties); the run checks it got the same state
##   6_r10_boss             r10, competent bot, LOW upgrades; 1 s after the boss first enters the camera (pre-pass);
##                          if it never does, camera follows the boss (recorded as camera = "boss")
##   7_result               r01 result panel after the bot's win, 4 s after the end (panel and star animation done)
## Battle scenes also save layer frames to <out>/layers/: _h (UI layer hidden), _ht (+ damage numbers hidden),
## _htf (+ effects and projectiles hidden), _bg (+ units and hero hidden). tools/qa/art_metrics.py turns them into
## pixel masks. <out>/<tag>_art_report.json holds every unit's screen rect, HP-bar rect, camera, counts and card icon
## rects. Owner: 07-qa. Read-only for the game (in-memory test state only); never touches the real user folder.

const BotS := preload("res://src/gameplay/bot_player.gd")
const SimS := preload("res://src/gameplay/battle_sim.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")
const TouchButtonS := preload("res://src/ui/touch_button.gd")
const DT := 1.0 / 60.0
const CHUNK := 120                      # sim steps per rendered frame while advancing (rendering does not touch the sim)
const SEED := 4242
const SETTLE_S := 3.0                   # real seconds after the last step: HUD snapshot catches up, toasts expire

var out_dir := ""
var tag := "run"
var dry := false
var anim := false                      # --anim: per-unit pose crops in scenes 4-6 (1x tag only; see _anim_pass)
var anim_done := {}
var app: Node
var content: Node
var atlas: Node
var budgets: Dictionary = {}
var report := {"scenes": {}, "notes": []}
var fix: CamFix

class NoopBot extends RefCounted:
	## Stand-in for battle.autoplay_bot: battle.gd then leaves the hero direction alone (it would reset it to the
	## absent touch input every frame) and this script's own bot keeps full control. act() does nothing.
	func act(_s, _d) -> void:
		pass

class CamFix extends Node:
	## Runs after battle.gd (process_priority 1000): camera x = hero x + 60 (clamped like battle.gd), or a fixed
	## world x when follow_x is set; vertical framing exactly as battle.gd; no shake offset.
	var battle: Node
	var follow_x := NAN
	func _process(_d: float) -> void:
		if battle == null or not is_instance_valid(battle) or battle.sim == null:
			return
		var vs: Vector2 = battle.get_viewport_rect().size
		var half := vs.x * 0.5
		var want: float = (float(battle.sim.hero.x) + 60.0) if is_nan(follow_x) else follow_x
		var cx := clampf(want, -90.0 + half, maxf(-90.0 + half, float(battle.sim.L) + 50.0 - half))
		var gy: float = battle.view.ground_y
		var cy := roundf(gy - (vs.y * 0.5 - 70.0))
		battle.cam.zoom = Vector2.ONE
		battle.cam.position = Vector2(roundf(cx), cy)
		battle.cam.offset = Vector2.ZERO
		battle.view.view_w = vs.x
		battle.view.cam_x = cx
		battle.view.view_top = cy - vs.y * 0.5
		battle.view.view_bottom = cy + vs.y * 0.5

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out_dir = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a == "--dry": dry = true
		elif a == "--anim": anim = true
		elif a.begins_with("--locale="): load("res://src/ui/ui_text.gd").load_locale(a.get_slice("=", 1))
		elif a.begins_with("--target="): SafeArea.override_target = float(a.get_slice("=", 1))
		elif a.begins_with("--safe="):
			var q := a.get_slice("=", 1).split(",")
			SafeArea.override_insets = Vector4(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
	_run.call_deferred()

func _frames(n := 2) -> void:
	for i in n:
		await process_frame

func _grab(path: String) -> void:
	await _frames(2)
	if dry or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)

func _run() -> void:
	app = root.get_node("App")
	content = root.get_node("Content")
	atlas = root.get_node("Atlas")
	var save := root.get_node("Save")
	if out_dir == "":
		printerr("[art] --out is required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("layers"))
	var bj = JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/balance/upgrade_budgets.json"))
	budgets = bj if bj is Dictionary else {}
	# isolated test save (user:// is the launcher's private APPDATA): returning player, every tutorial done
	DirAccess.make_dir_recursive_absolute("user://qa07")
	save.path = "user://qa07/art_baseline_save.json"
	for suf in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save.path + suf): DirAccess.remove_absolute(save.path + suf)
	save.progress = save.fresh()
	save.progress.unlocked_round = 10
	var tut: Array = []
	for rid in content.round_order:
		for k in content.get_round(str(rid)).get("tutorial", []): tut.append(str(k))
	save.progress.tutorial_done = tut
	root.add_child(load("res://scenes/gameplay/main.tscn").instantiate())
	await _frames(30)
	var vs := root.get_visible_rect().size
	report.view = [vs.x, vs.y]
	report.window = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y] if DisplayServer.get_name() != "headless" else [0, 0]
	report.tag = tag
	report.safe = [SafeArea.override_insets.x, SafeArea.override_insets.y, SafeArea.override_insets.z, SafeArea.override_insets.w]
	report.seed_call = SEED
	report.script_sha256 = FileAccess.get_file_as_string("res://tests/acceptance/capture_art_baseline.gd").trim_prefix(char(0xFEFF)).replace("\r\n", "\n").sha256_text()   # line-end independent (LF/CRLF checkouts hash the same)
	report.anim = {}
	await create_timer(SETTLE_S).timeout
	await _grab(out_dir.path_join("%s_1_menu.png" % tag))
	report.scenes["1_menu"] = {"kind": "ui", "layout": _layout_dump()}
	fix = CamFix.new()
	fix.process_priority = 1000
	root.add_child(fix)
	# ---- r01: t = 10 s, 30 s, then the result
	var b := await _start("r01", "low")
	var bot = BotS.new(2, int(b.sim.rng.seed))
	await _advance(b.sim, bot, 600, null)
	await _capture_battle("2_r01_t10", b, "low", {"bot": "competent"})
	await _advance(b.sim, bot, 1200, null)
	await _capture_battle("3_r01_t30", b, "low", {"bot": "competent"})
	var guard := 0
	while not b.sim.ended and guard < 54000:
		await _advance(b.sim, bot, CHUNK, null)
		guard += CHUNK
	await create_timer(4.0).timeout
	await _grab(out_dir.path_join("%s_7_result.png" % tag))
	report.scenes["7_result"] = {"kind": "ui", "round": "r01", "won": b.sim.won, "sim_t": snappedf(b.sim.t, 0.01), "screen": str(app.get("screen")), "layout": _layout_dump()}
	# ---- r06: 04's ZOOM_PREVIEW scenario (no upgrades, scripted deploys)
	b = await _start("r06", "none")
	var plan := {"items": [[2.0, "melee_basic"], [4.0, "tank"], [6.0, "ranged_basic"], [9.0, "melee_basic"], [12.0, "fast"], [15.0, "siege"],
		[20.0, "ranged_basic"], [24.0, "tank"], [28.0, "melee_basic"], [33.0, "fast"], [38.0, "ranged_basic"], [44.0, "melee_basic"],
		[50.0, "tank"], [56.0, "ranged_basic"], [62.0, "melee_basic"], [70.0, "siege"], [78.0, "fast"]], "i": 0}
	await _advance(b.sim, null, 2760, plan)
	await _capture_battle("4_r06_t46", b, "none", {"bot": "04 zoom_preview plan (17 deploys, hero 150 px behind the front)"})
	# ---- r08 peak
	b = await _start("r08", "low")
	var pk := _prepass("r08", int(b.sim.rng.seed), _levels("r08", "low"), "peak", vs.x * 0.5)
	bot = BotS.new(2, int(b.sim.rng.seed))
	await _advance(b.sim, bot, int(pk.step), null)
	await _capture_battle("5_r08_peak", b, "low", {"bot": "competent", "prepass": pk})
	# ---- r10 boss
	b = await _start("r10", "low")
	var bs := _prepass("r10", int(b.sim.rng.seed), _levels("r10", "low"), "boss", vs.x * 0.5)
	bot = BotS.new(2, int(b.sim.rng.seed))
	await _advance(b.sim, bot, int(bs.step), null)
	if str(bs.get("camera", "hero")) == "boss":
		for e in b.sim.enemies:
			if e.is_boss and not e.dying: fix.follow_x = float(e.x)
	await _capture_battle("6_r10_boss", b, "low", {"bot": "competent", "prepass": bs})
	fix.follow_x = NAN
	var f := FileAccess.open(out_dir.path_join(tag + "_art_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("[art] ", JSON.stringify({"tag": tag, "dry": dry, "scenes": report.scenes.keys(), "view": report.view, "window": report.window,
		"user_data_dir": OS.get_user_data_dir()}))
	quit(0)

func _levels(rid: String, budget: String) -> Dictionary:
	if budget == "none" or not budgets.has(budget) or not budgets[budget].has(rid): return {}
	return (budgets[budget][rid].get("levels", {}) as Dictionary).duplicate()

## Fixed battle start: upgrades from 01's budget file, seed(SEED) so App.start_round's randi() is fixed, and the
## battle clock stopped in the same call (no real-time step ever happens).
func _start(rid: String, budget: String) -> Node:
	var save := root.get_node("Save")
	save.progress.upgrades = _levels(rid, budget)
	seed(SEED)
	app.start_round(rid, true)
	var b: Node = app.battle
	b.time_scale = 0.0
	b.autoplay_bot = NoopBot.new()
	fix.battle = b
	fix.follow_x = NAN
	await _frames(3)
	return b

## Advance exactly `steps` sim steps (CHUNK per rendered frame). bot != null: bot.act every step with the real
## interval DT. plan != null: 04's scripted player.
func _advance(sim, bot, steps: int, plan) -> void:
	var done := 0
	while done < steps and not sim.ended:
		var n := mini(CHUNK, steps - done)
		for k in n:
			if plan != null:
				_plan_step(sim, plan)
			elif bot != null:
				bot.act(sim, DT)
			sim.step(DT)
			done += 1
			if sim.ended: break
		await process_frame

func _plan_step(sim, plan: Dictionary) -> void:
	var items: Array = plan["items"]
	while int(plan["i"]) < items.size() and sim.t >= float(items[int(plan["i"])][0]):
		var cid := str(items[int(plan["i"])][1])
		sim.gold = maxf(sim.gold, 300.0)
		sim.card_cd[cid] = 0.0
		sim.deploy(cid)
		plan["i"] = int(plan["i"]) + 1
	var front := 0.0
	for p in sim.players:
		if p.alive and not p.is_hero: front = maxf(front, p.x)
	if sim.hero != null:
		sim.set_hero_dir(1 if sim.hero.x < front - 150.0 - 6.0 else (-1 if sim.hero.x > front - 150.0 + 30.0 else 0))

## Pure-sim pre-pass with the same seed, upgrades and bot: picks the capture step on a 15-step (0.25 s) grid.
func _prepass(rid: String, sv: int, lv: Dictionary, mode: String, half: float) -> Dictionary:
	var s = SimS.new()
	s.setup(content, rid, sv, lv)
	var bot = BotS.new(2, sv)
	var best := {"step": 0, "count": -1, "t": 0.0}
	var first_boss := -1
	var boss_alive_step := -1
	var step := 0
	while not s.ended and step < 54000:
		bot.act(s, DT)
		s.step(DT)
		step += 1
		if step % 15 != 0: continue
		var cx := clampf(float(s.hero.x) + 60.0, -90.0 + half, maxf(-90.0 + half, float(s.L) + 50.0 - half))
		if mode == "peak":
			if s.t < 20.0: continue
			var n := 0
			for u in s.players: if not u.dying and absf(u.x - cx) <= half: n += 1
			for u in s.enemies: if not u.dying and absf(u.x - cx) <= half: n += 1
			if s.hero_respawn <= 0.0 and absf(s.hero.x - cx) <= half: n += 1
			if n > int(best.count): best = {"step": step, "count": n, "t": snappedf(s.t, 0.01)}
		else:
			for e in s.enemies:
				if e.is_boss and not e.dying:
					if boss_alive_step < 0: boss_alive_step = step
					if first_boss < 0 and absf(e.x - cx) <= half: first_boss = step
			if first_boss >= 0 and step >= first_boss + 60: break
	if mode == "boss":
		if first_boss >= 0: return {"step": first_boss + 60, "camera": "hero", "boss_first_in_camera_step": first_boss, "boss_alive_step": boss_alive_step}
		return {"step": maxi(boss_alive_step, 0) + 60, "camera": "boss", "boss_first_in_camera_step": -1, "boss_alive_step": boss_alive_step}
	best["mode"] = mode
	return best

func _capture_battle(scene: String, b: Node, budget: String, extra: Dictionary) -> void:
	var sim = b.sim
	await create_timer(SETTLE_S).timeout
	if sim.paused:   # e.g. the HUD's auto-pause on a window focus change: resume so no pause overlay is captured
		root.get_node("Events").cmd_set_paused.emit(false)
		report.notes.append("%s: battle was paused before capture (focus change?); resumed, sim clock is stopped anyway" % scene)
		await create_timer(0.5).timeout
	var meta := _meta(b, budget)
	meta.merge(extra)
	var base := out_dir.path_join("layers").path_join("%s_%s" % [tag, scene])
	await _grab(out_dir.path_join("%s_%s.png" % [tag, scene]))
	app.ui_layer.visible = false
	await _grab(base + "_h.png")
	var off_t := []
	for tx in sim.texts:
		if tx.alive:
			tx.alive = false
			off_t.append(tx)
	await _grab(base + "_ht.png")
	var off_f := []
	for fx in sim.fxs:
		if fx.alive:
			fx.alive = false
			off_f.append(fx)
	for p in sim.projectiles:
		if p.alive:
			p.alive = false
			off_f.append(p)
	await _grab(base + "_htf.png")
	var keep_p: Array = sim.players.duplicate()
	var keep_e: Array = sim.enemies.duplicate()
	var keep_r: float = sim.hero_respawn
	sim.players.clear(); sim.enemies.clear(); sim.hero_respawn = 99.0
	await _grab(base + "_bg.png")
	if anim and scene in ["4_r06_t46", "5_r08_peak", "6_r10_boss"]:
		await _anim_pass(b, scene, keep_p, keep_e, keep_r)
	sim.players.append_array(keep_p); sim.enemies.append_array(keep_e); sim.hero_respawn = keep_r
	for o in off_t: o.alive = true
	for o in off_f: o.alive = true
	app.ui_layer.visible = true
	await _frames(2)
	if extra.has("prepass") and str(extra.prepass.get("mode", "")) == "peak":
		meta["prepass_matches"] = int(meta.units_in_camera) == int(extra.prepass.count)
	report.scenes[scene] = meta

## Animation reading, same frozen state (called with the UI layer, damage numbers, effects and every unit hidden).
## One instance per unit id (first one whose crop fits on screen), shown ALONE at its real position, then each pose the
## game can draw: idle, walk, attack and death frames (t = (i + 0.5) / fps; death also fades as battle_view does with
## dead_t = 0.7 - t) and the hit reaction the game shows (flash = 0.12 on walk frame 0; battle_view never draws the
## atlas "hit" anim). Crops of 112x96 view px go to <out>/layers/anim/<tag>_<id>_<pose>_<i>.png plus <id>_bg.png.
## HP bars are hidden for regular units (hp = hp_max); hero/boss bar rects are recorded per pose for masking.
func _anim_pass(b: Node, scene: String, keep_p: Array, keep_e: Array, keep_r: float) -> void:
	var sim = b.sim
	var view: Node2D = b.view
	var vs := root.get_visible_rect().size
	var adir := out_dir.path_join("layers").path_join("anim")
	DirAccess.make_dir_recursive_absolute(adir)
	var cands: Array = []
	cands.append_array(keep_p); cands.append_array(keep_e)
	if keep_r <= 0.0: cands.append(sim.hero)
	for u in cands:
		if u.dying: continue
		var uid := str(u.def.get("id", u.anim_set))
		if anim_done.has(uid): continue
		var ct: Transform2D = b.get_viewport().get_canvas_transform()
		var sp: Vector2 = ct * Vector2(roundf(u.x), roundf(view.ground_y + u.lane_y))
		var crop := Rect2(sp.x - 56.0, sp.y - 88.0, 112.0, 96.0)
		if crop.position.x < 0.0 or crop.end.x > vs.x or crop.position.y < 0.0 or crop.end.y > vs.y: continue
		anim_done[uid] = true
		var saved := {"state": u.state, "anim_t": u.anim_t, "flash": u.flash, "dying": u.dying, "dead_t": u.dead_t, "hp": u.hp}
		var flip: bool = (sim.hero_dir < 0) if u.is_hero else (u.side < 0)
		var info := {"scene": scene, "side": "ally" if u.side == 1 else "enemy", "hero": u.is_hero, "boss": u.is_boss,
			"facing": -1 if flip else 1, "crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y], "anims": {}, "bars": {}}
		await _grab_region(adir.path_join("%s_%s_bg.png" % [tag, uid]), crop)
		_show(sim, u, true)
		if not u.is_hero and not u.is_boss: u.hp = u.hp_max
		for an in ["idle", "walk", "attack", "death"]:
			var rec = atlas.anim_rec(u.anim_set, an)
			if rec == null: continue
			var n: int = rec.rects.size()
			info.anims[an] = {"frames": n, "fps": rec.fps, "loop": rec.loop}
			for i in n:
				u.flash = 0.0
				u.anim_t = (i + 0.5) / float(rec.fps)
				u.dying = an == "death"
				u.dead_t = 0.7 - u.anim_t if an == "death" else 0.0
				u.state = {"idle": SimS.S_IDLE, "walk": SimS.S_WALK, "attack": SimS.S_ATTACK, "death": SimS.S_DYING}[an]
				info.bars["%s_%d" % [an, i]] = _bar_in_crop(u, rec, i, view, ct, crop)
				await _grab_region(adir.path_join("%s_%s_%s_%d.png" % [tag, uid, an, i]), crop)
		var wrec = atlas.anim_rec(u.anim_set, "walk")
		if wrec != null:
			u.dying = false; u.dead_t = 0.0; u.state = SimS.S_WALK
			u.anim_t = 0.5 / float(wrec.fps)
			u.flash = 0.12
			info.bars["hitflash_0"] = _bar_in_crop(u, wrec, 0, view, ct, crop)
			await _grab_region(adir.path_join("%s_%s_hitflash_0.png" % [tag, uid]), crop)
		info["atlas_hit_frames"] = atlas.anim_rec(u.anim_set, "hit").rects.size() if atlas.anim_rec(u.anim_set, "hit") != null else 0
		for k in saved: u.set(k, saved[k])
		_show(sim, u, false)
		report.anim[uid] = info

func _show(sim, u, on: bool) -> void:
	if u.is_hero:
		sim.hero_respawn = 0.0 if on else 99.0
	elif on:
		if u.side == 1: sim.players.append(u)
		else: sim.enemies.append(u)
	else:
		sim.players.erase(u)
		sim.enemies.erase(u)

## HP bar rect (outline) of u at frame i of rec, in crop pixels (view px), or null when battle_view would not draw it.
func _bar_in_crop(u, rec, i: int, view: Node2D, ct: Transform2D, crop: Rect2):
	if u.dying: return null
	var w := 12.0 + 4.0 * float(u.def.get("size", 1.0))
	if u.hp / u.hp_max >= 0.999 and w < 30.0: return null
	var r: Rect2 = rec.rects[i]
	var c := Vector2(roundf(u.x), roundf(view.ground_y + u.lane_y)) + Vector2(0, -r.size.y - 3.0)
	var bar := Rect2(roundf(c.x - w * 0.5), roundf(c.y), roundf(w), 2.0).grow(1.0)
	var p: Vector2 = ct * bar.position - crop.position
	return [p.x, p.y, bar.size.x, bar.size.y]

func _grab_region(path: String, crop: Rect2) -> void:
	await _frames(2)
	if dry or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var k := float(img.get_width()) / root.get_visible_rect().size.x
	var r := Rect2i(int(crop.position.x * k), int(crop.position.y * k), int(crop.size.x * k), int(crop.size.y * k))
	img.get_region(r).save_png(path)

func _meta(b: Node, budget: String) -> Dictionary:
	var sim = b.sim
	var view: Node2D = b.view
	var ct: Transform2D = b.get_viewport().get_canvas_transform()
	var vs := root.get_visible_rect().size
	var units := []
	var all: Array = []
	all.append_array(sim.players); all.append_array(sim.enemies)
	if sim.hero_respawn <= 0.0: all.append(sim.hero)
	var allies := 0
	var enemies := 0
	var boss_in := false
	for u in all:
		var pos := Vector2(roundf(u.x), roundf(view.ground_y + u.lane_y))
		var rect := Rect2()
		var bar = null
		var rec = atlas.anim_rec(u.anim_set, view._anim_name(u))
		var t: float = u.anim_t
		if rec == null and u.state == SimS.S_IDLE:
			rec = atlas.anim_rec(u.anim_set, "walk"); t = 0.0
		if rec != null:
			var fi: int = atlas.rec_index(rec, t)
			var r: Rect2 = rec.rects[fi]
			var pv: Vector2 = rec.pivots[fi]
			var flip: bool = (sim.hero_dir < 0) if u.is_hero else (u.side < 0)
			var x0 := (pos.x - (r.size.x - pv.x)) if flip else (pos.x - pv.x)
			rect = Rect2(x0, pos.y - pv.y, r.size.x, r.size.y)
			var w := 12.0 + 4.0 * float(u.def.get("size", 1.0))
			if not u.dying and not (u.hp / u.hp_max >= 0.999 and w < 30.0):
				var c := pos + Vector2(0, -r.size.y - 3.0)
				bar = Rect2(roundf(c.x - w * 0.5), roundf(c.y), roundf(w), 2.0).grow(1.0)
		var srect := Rect2(ct * rect.position, rect.size)
		var in_cam: bool = srect.end.x > 0.0 and srect.position.x < vs.x
		if in_cam and not u.dying:
			if u.side == 1: allies += 1
			else: enemies += 1
			if u.is_boss: boss_in = true
		units.append({"side": "ally" if u.side == 1 else "enemy", "id": str(u.def.get("id", "")), "hero": u.is_hero, "boss": u.is_boss,
			"dying": u.dying, "in_camera": in_cam, "rect": [srect.position.x, srect.position.y, srect.size.x, srect.size.y],
			"bar": [(ct * (bar as Rect2).position).x, (ct * (bar as Rect2).position).y, (bar as Rect2).size.x, (bar as Rect2).size.y] if bar != null else null})
	var cards := []
	var hud = _find_hud(app.ui_layer)
	if hud:
		for btn in hud.card_buttons:
			if btn is Control and btn.is_visible_in_tree():
				cards.append(_icon_rect(btn))
	var nfx := 0
	for fx in sim.fxs: if fx.alive: nfx += 1
	var npr := 0
	for p in sim.projectiles: if p.alive: npr += 1
	var ntx := 0
	for tx in sim.texts: if tx.alive: ntx += 1
	return {"kind": "battle", "round": str(sim.round_def.get("id", b.round_id)), "budget": budget, "battle_seed": int(sim.rng.seed),
		"sim_t": snappedf(sim.t, 0.001), "kills": sim.kills, "gold": snappedf(sim.gold, 0.1), "ended": sim.ended,
		"camera_x": float(view.cam_x), "ground_screen_y": (ct * Vector2(0, view.ground_y)).y,
		"units_in_camera": allies + enemies, "allies_in_camera": allies, "enemies_in_camera": enemies, "boss_in_camera": boss_in,
		"fx_alive": nfx, "projectiles_alive": npr, "texts_alive": ntx, "units": units, "cards": cards,
		"j1_rect_pct": _j1_rect(sim, view, vs), "layout": _layout_dump(), "enemy_offscreen_right": _offscreen_right(sim, view, vs)}

## Layout dump (LAYOUT rules L1-L8): every visible Control under the UI layer with its global rect (logical px), role,
## text and font size; the two threat markers (shown or not, rect, state). Read-only.
func _layout_dump() -> Dictionary:
	var hud = _find_hud(app.ui_layer)
	var roles := {}
	if hud:
		for bb in hud.card_buttons: if bb is Object: roles[bb.get_instance_id()] = "card"
		for bb in hud.skill_buttons: if bb is Object: roles[bb.get_instance_id()] = "skill"
		for pair in [["btn_left", "move"], ["btn_right", "move"], ["btn_worker", "worker"], ["btn_pause", "pause"]]:
			var n = hud.get(pair[0])
			if n is Object: roles[n.get_instance_id()] = pair[1]
	var nodes := []
	_walk_ui(app.ui_layer, nodes, roles, "")
	var thr := []
	if hud:
		for k in ["threat_right", "threat_left"]:
			var n = hud.get(k)
			if n is Control:
				var r: Rect2 = n.get_global_rect()
				thr.append({"name": k, "visible": n.is_visible_in_tree(), "rect": [r.position.x, r.position.y, r.size.x, r.size.y], "state": str(n.get("state"))})
	var ins := SafeArea.override_insets
	return {"nodes": nodes, "threat": thr, "safe_insets": [ins.x, ins.y, ins.z, ins.w], "hud": hud != null}

func _walk_ui(n: Node, out: Array, roles: Dictionary, path: String) -> void:
	for c in n.get_children():
		var p := path + "/" + str(c.name)
		if c is Control and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			var touch: bool = c.get_script() == TouchButtonS or c is BaseButton
			var fs = c.get("font_size")
			if c is Label: fs = c.get_theme_font_size("font_size")
			var txt = c.get("text")
			out.append({"path": p, "class": c.get_class(), "script": str(c.get_script().resource_path).get_file() if c.get_script() else "",
				"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "touch": touch, "role": roles.get(c.get_instance_id(), ""),
				"text": str(txt) if txt != null else "", "font_size": int(fs) if fs != null else -1,
				"disabled": bool(c.get("disabled")) if c.get("disabled") != null else false})
		_walk_ui(c, out, roles, p)

## Nearest alive enemy to the right of the camera (world px beyond the right edge), or -1: does a threat marker matter here?
func _offscreen_right(sim, view: Node2D, vs: Vector2) -> float:
	var vr: float = float(view.cam_x) + vs.x * 0.5
	var best := -1.0
	for e in sim.enemies:
		if e.dying: continue
		if e.x > vr and (best < 0.0 or e.x - vr < best): best = e.x - vr
	return snappedf(best, 0.1)

func _find_hud(n: Node) -> Node:
	for c in n.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("ui/hud.gd"): return c
		var r := _find_hud(c)
		if r: return r
	return null

## Icon rect of a card button, same rules as TouchButton._draw (not pressed).
func _icon_rect(btn) -> Dictionary:
	var g: Rect2 = btn.get_global_rect()
	var sz: Vector2 = btn.size
	var has_sub := str(btn.get("sub_text")) != ""
	var ic: Texture2D = btn.get("icon")
	var glyph = btn.get("glyph")
	var has_visual := ic != null or (glyph != null and str(glyph) != "")
	var txt := str(btn.get("text"))
	var numeric := txt != "" and txt.is_valid_int()
	var show_name := txt != "" and (not has_visual or not has_sub or sz.y >= 54 or numeric)
	var cost_y := sz.y - 9.0
	var name_y := (sz.y - 21.0) if has_sub else (sz.y - 10.0)
	var icon_bottom := (name_y - 7.0) if show_name and not numeric else (cost_y - 6.0 if has_sub else sz.y - 4.0)
	var icon_c := Vector2(sz.x / 2, (4.0 + icon_bottom) / 2.0)
	if not show_name and not has_sub: icon_c = sz / 2.0
	var ir := Rect2()
	if ic:
		var avail := minf(sz.x - 8, icon_bottom - 4.0) if (show_name or has_sub) else minf(sz.x - 8, sz.y - 8)
		var isz := ic.get_size()
		var k := maxf(1.0, floorf(avail / maxf(isz.x, isz.y)))
		ir = Rect2((icon_c - isz * k / 2.0).round(), isz * k)
	return {"text": txt, "disabled": bool(btn.get("disabled")), "button": [g.position.x, g.position.y, g.size.x, g.size.y],
		"icon": [g.position.x + ir.position.x, g.position.y + ir.position.y, ir.size.x, ir.size.y] if ic else null}

## Same definition as capture_m8.gd J1 (continuity with the 5.0-6.9 % figures): union of walk-frame-0 rects of
## units + hero + 96x112 base boxes inside the view, on a 2 px grid, % of the view.
func _j1_rect(sim, view: Node2D, v: Vector2) -> float:
	var left: float = float(view.cam_x) - v.x / 2.0
	var gy: float = float(view.ground_y)
	var rects := []
	var units: Array = []
	units.append_array(sim.players); units.append_array(sim.enemies)
	if sim.hero_respawn <= 0.0: units.append(sim.hero)
	for u in units:
		if u.dying: continue
		var fr: Dictionary = atlas.anim_frame(str(u.def.get("anim_set", u.id)), "walk", 0.0)
		var sz: Vector2 = (fr.rect as Rect2).size if not fr.is_empty() else Vector2(12, 14)
		var r := Rect2(u.x - left - sz.x / 2.0, gy + u.lane_y - sz.y, sz.x, sz.y)
		if r.end.x < 0 or r.position.x > v.x: continue
		rects.append(r)
	for bb in [sim.player_base, sim.enemy_base]:
		var r := Rect2(float(bb.x) - left - 48.0, gy - 112.0, 96.0, 112.0)
		if r.end.x >= 0 and r.position.x <= v.x: rects.append(r)
	var cell := 2
	var covered := {}
	for r in rects:
		for y in range(maxi(0, int(r.position.y) / cell), mini(int(v.y) / cell, int(r.end.y) / cell + 1)):
			for x in range(maxi(0, int(r.position.x) / cell), mini(int(v.x) / cell, int(r.end.x) / cell + 1)):
				covered[y * 1000 + x] = true
	var total := (int(v.x) / cell) * (int(v.y) / cell)
	return snappedf(100.0 * covered.size() / total, 0.1)
