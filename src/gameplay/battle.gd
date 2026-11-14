extends Node2D
## Battle scene controller: drives BattleSim at a fixed step, routes Events commands,
## publishes HUD snapshots, manages camera and per-battle atlas residency. Owner: 02-engine.

const SimS := preload("res://src/gameplay/battle_sim.gd")
const ViewS := preload("res://src/gameplay/battle_view.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const TutorialS := preload("res://src/gameplay/tutorial_director.gd")
const SafeAreaS := preload("res://src/ui/safe_area.gd")
const PixelCamera := preload("res://src/gameplay/pixel_camera.gd")

signal finished(result: Dictionary)

var sim
var view: Node2D
var cam: Camera2D
var round_id := ""
var autoplay_bot = null
var _acc := 0.0
var _hud_t := 0.0
var _pages: PackedStringArray = []
var _key_dir := 0
var _key_wait_release := false   # a move key was held when the hero died: ignored until it is let go
var _ui_dir := 0
var _drag_active := false
var _drag_last := Vector2.ZERO
var _free_cam_t := 0.0
var _scouting := false
var _delivery_cycles: Array[int] = []
var _cam_x := 0.0
var _ended_emitted := false
var time_scale := 1.0
var battle_uid := ""
var tutorial = null
var tutorial_key := ""
var _evbuf: Array = []
var _shake := 0.0

## Fast-forward chosen by the player (HUD x1 / x2 button, setting "battle_speed"): more sim steps per frame, same
## fixed step, so the battle itself (and star times, which count sim seconds) is unchanged. R1-R2 always run at x1.
const SPEED_FROM_ROUND := 3
func player_speed() -> float:
	if sim == null or int(sim.round_def.get("index", 0)) < SPEED_FROM_ROUND: return 1.0
	return clampf(float(Save.progress.settings.get("battle_speed", 1.0)), 1.0, 2.0)
var world_zoom := 1.0                  # camera zoom used in the last frame (1 = off; App.world_zoom())
const GROUND_FROM_BOTTOM := 70.0       # ground row, view px above the view bottom (04 CamFix / R17)
const ReadyGoS := preload("res://src/ui/ready_go.gd")
## READY -> GO! at the start of every battle. 0 = auto (on in the game, off for autoplay and for -s test/capture
## scripts, whose timings assume the clock starts at once), 1 = always, -1 = never.
static var intro_mode := 0
var intro: Control = null
var _intro_layer: CanvasLayer = null

func start(p_round_id: String, seed_value: int, upgrades: Dictionary, autoplay := false, loadout: Array = [], skill_pick: Array = []) -> void:
	round_id = p_round_id
	sim = SimS.new()
	sim.setup(Content, round_id, seed_value, upgrades, loadout, skill_pick)
	var gy := float(Content.config.get("lane", {}).get("ground_y", 290.0))
	# atlas residency for this battle only
	var sets: Array = []
	for id in sim.card_ids: sets.append(str(Content.get_unit(id).anim_set))
	for uid in Content.round_enemy_roster(sim.round_def):   # 08 P6: only this round's enemies
		sets.append(str(Content.get_unit(uid).anim_set))
	sets.append(str(sim.hero_def.anim_set))
	sets.append("worker")
	sets.append(ViewS.nest_set(int(sim.round_def.get("index", 0))))   # this chapter's enemy nest page only
	_pages = Atlas.pages_for_battle(sets, str(sim.round_def.biome))
	# Code-drawn scenery no longer needs the old repeating bitmap page resident.
	for i in range(_pages.size() - 1, -1, -1):
		var page = Atlas.pages.get(_pages[i])
		if page != null and str(page.meta.get("group", "")) == "biome": _pages.remove_at(i)
	for p in _pages: Atlas.acquire(p)
	view = ViewS.new()
	view.name = "View"
	add_child(view)
	view.setup(sim, Atlas, gy, str(sim.round_def.biome))
	view.show_damage = bool(Save.progress.settings.get("show_damage", true))
	cam = Camera2D.new()
	cam.name = "Camera"
	add_child(cam)
	cam.make_current()
	# Clamp the desired centre ourselves below. Camera2D's second limit pass would
	# move the already raster-aligned translation onto a different subpixel phase.
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000   # vertical framing is done in _update_camera (bottom-anchored)
	cam.limit_bottom = 100000
	_cam_x = sim.hero.x
	cam.position = Vector2(_cam_x, 180)
	if autoplay:
		autoplay_bot = BotS.new(2, seed_value)
	battle_uid = _make_battle_uid()
	tutorial = TutorialS.new()
	tutorial.setup(sim.round_def.get("tutorial", []), Save.progress.get("tutorial_done", []))
	Events.cmd_deploy_unit.connect(_on_deploy)
	Events.cmd_buy_worker.connect(_on_worker)
	Events.cmd_hero_move.connect(_on_hero_move)
	Events.cmd_hero_skill.connect(_on_skill)
	Events.cmd_set_paused.connect(set_paused)
	Events.cmd_camera_seek.connect(_on_camera_seek)
	Events.cmd_camera_follow.connect(_on_camera_follow)
	var info: Dictionary = sim.battle_info()
	info["battle_uid"] = battle_uid
	Events.battle_started.emit(info)
	world_zoom = App.world_zoom()
	_cam_x = sim.hero.x + _camera_lead()
	_update_camera(0.0)
	if _intro_on(autoplay): _start_intro()
	_publish()

func _intro_on(autoplay: bool) -> bool:
	if intro_mode != 0: return intro_mode > 0
	return not autoplay and get_tree().get_script() == null

func _start_intro() -> void:
	_intro_layer = CanvasLayer.new()
	_intro_layer.layer = 5                  # above the HUD layer, below dialogs
	add_child(_intro_layer)
	intro = ReadyGoS.new()
	intro.go.connect(func(): Events.sfx.emit(&"ui_upgrade_ok", {}))
	_intro_layer.add_child(intro)
	Events.sfx.emit(&"ui_confirm", {})

func _step_intro(delta: float) -> void:
	if intro == null: return
	if not sim.paused: intro.advance(delta)
	if intro.finished():
		_intro_layer.queue_free()
		_intro_layer = null
		intro = null

## 06 S4 / 10 R3: unique per battle instance (128 random bits + start time).
func _make_battle_uid() -> String:
	var c := Crypto.new()
	return "%d-%s" % [int(Time.get_unix_time_from_system()), c.generate_random_bytes(16).hex_encode()]

func battle_info() -> Dictionary:
	var info: Dictionary = sim.battle_info()
	info["battle_uid"] = battle_uid
	return info

func _exit_tree() -> void:
	for p in _pages: Atlas.release(p)
	_pages = PackedStringArray()
	for pair in [[Events.cmd_deploy_unit, _on_deploy], [Events.cmd_buy_worker, _on_worker],
			[Events.cmd_hero_move, _on_hero_move], [Events.cmd_hero_skill, _on_skill], [Events.cmd_set_paused, set_paused],
			[Events.cmd_camera_seek, _on_camera_seek], [Events.cmd_camera_follow, _on_camera_follow]]:
		if pair[0].is_connected(pair[1]): pair[0].disconnect(pair[1])

func set_paused(p: bool) -> void:
	if sim == null or sim.ended: return
	sim.paused = p
	Events.battle_paused.emit(p)
	_publish()

# ---------------- commands ----------------
func _toast_if(err: String) -> void:
	if err != "" and err != "ended":
		Events.toast.emit(err, {})
	_publish()

func _on_deploy(id: String) -> void:
	if sim.paused: return
	_toast_if(sim.deploy(id))

func _on_worker() -> void:
	if sim.paused: return
	_toast_if(sim.buy_worker())

func _on_skill(id: String) -> void:
	if sim.paused: return
	_toast_if(sim.cast(id))

func _on_hero_move(dir: int) -> void:
	_ui_dir = clampi(dir, -1, 1)
	_free_cam_t = 0.0
	if dir != 0: _scouting = false

func _on_camera_seek(world_x: float) -> void:
	if sim == null or sim.ended: return
	if not _scouting: Events.sfx.emit(&"ui_scout", {})
	_cam_x = world_x
	_scouting = true
	_update_camera(0.0)
	_publish()

func _on_camera_follow() -> void:
	if _scouting: Events.sfx.emit(&"ui_scout", {})
	_scouting = false
	_free_cam_t = 0.0
	if sim:
		_cam_x = sim.hero.x + _camera_lead()
		_update_camera(0.0)
		_publish()

func _camera_lead() -> float:
	# At home, include the flour mill behind the bakery; farther along, lead the hero.
	var width := get_viewport_rect().size.x / maxf(world_zoom, 0.01)
	var home_center := -175.0 + width * 0.5
	var blend := clampf((float(sim.hero.x) - float(sim.player_base.x) - 60.0) / 120.0, 0.0, 1.0)
	return lerpf(home_center, float(sim.hero.x) + 60.0, blend) - float(sim.hero.x)

# ---------------- loop ----------------
func _process(delta: float) -> void:
	if sim == null: return
	var t0 := Time.get_ticks_usec()
	_step_intro(delta)
	if not sim.paused and not sim.ended and not (intro != null and intro.holding()):
		if autoplay_bot:
			autoplay_bot.act(sim, delta)
		else:
			sim.set_hero_dir(_ui_dir if _ui_dir != 0 else _key_dir)
		_acc += minf(delta, 0.25) * time_scale * player_speed()
		var steps := 0
		while _acc >= Perf.SIM_STEP and steps < Perf.SIM_MAX_STEPS:
			sim.step(Perf.SIM_STEP)
			_acc -= Perf.SIM_STEP
			steps += 1
		if steps == Perf.SIM_MAX_STEPS:
			_acc = 0.0   # spiral-of-death guard: drop backlog
	_drain_events()
	_track_core()
	_supply_audio()
	Perf.sim_ms_last = (Time.get_ticks_usec() - t0) / 1000.0
	Perf.sim_ms_max = maxf(Perf.sim_ms_max, Perf.sim_ms_last)
	Perf.counts.units = sim.players.size() + sim.enemies.size()
	var np := 0
	for p in sim.projectiles: if p.alive: np += 1
	Perf.counts.projectiles = np
	var nf := 0
	for f in sim.fxs: if f.alive: nf += 1
	Perf.counts.fx = nf
	view.render_ahead = _acc if not sim.paused and not sim.ended and not (intro != null and intro.holding()) else 0.0
	_update_camera(delta)
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.1
		_publish()

func _supply_audio() -> void:
	if sim.ended or sim.paused: return
	for i in mini(int(sim.workers), 8):
		var cycle := floori((float(sim.t) + i * 1.37 - 8.8) / 10.0)
		if i >= _delivery_cycles.size():
			_delivery_cycles.append(cycle)
		elif cycle > _delivery_cycles[i]:
			_delivery_cycles[i] = cycle
			Events.sfx.emit(&"flour_delivery", {"x": float(sim.player_base.x) - 26.0})

func _publish() -> void:
	if sim:
		var s: Dictionary = sim.snapshot()
		s["tutorial"] = tutorial_key
		s["threat"] = _threat_snapshot()
		s["map"] = _map_snapshot(s.threat)
		Events.hud_snapshot.emit(s)

func _map_snapshot(threat: Dictionary) -> Dictionary:
	var dots: Array = []
	for unit in sim.players:
		if not unit.dying: dots.append([float(unit.x), 1, false])
	for unit in sim.enemies:
		if not unit.dying: dots.append([float(unit.x), -1, bool(unit.is_boss)])
	return {"left": -200.0, "right": float(sim.L) + 50.0, "player_base": float(sim.player_base.x),
		"enemy_base": float(sim.enemy_base.x), "hero": float(sim.hero.x), "hero_alive": sim.hero_respawn <= 0.0,
		"view_left": threat.view_left, "view_right": threat.view_right, "scouting": _scouting,
		"dots": dots}

func _threat_snapshot() -> Dictionary:
	var width := get_viewport_rect().size.x / maxf(world_zoom, 0.01)
	var vl := cam.position.x - width * 0.5
	var vr := vl + width
	var result := {"view_left": vl, "view_right": vr, "nest_left": float(sim.enemy_base.x) - 40.0, "enemy_visible": false}
	for enemy in sim.enemies:
		if enemy.dying: continue
		if enemy.x >= vl and enemy.x <= vr:
			result.enemy_visible = true
		elif enemy.x > vr:
			result["enemy_right"] = minf(float(result.get("enemy_right", INF)), enemy.x)
		else:
			result["enemy_left"] = maxf(float(result.get("enemy_left", -INF)), enemy.x)
	return result

var _heavy_toast_shown := false
var _core_linked := false      # last frame: the linkable boss (unit key `link_break`) was held by a knot

## A soft wet cue when a knot takes hold of the core again (the cut has its own snap in _drain_events). One per
## change of state, lower and quieter in character than the wind-up cue, so an announced attack is never masked.
func _track_core() -> void:
	var now := false
	var x := 0.0
	for e in sim.enemies:
		if e.is_boss and not e.dying and e.def.has("link_break"):
			now = e.link_src != 0
			x = e.x
			break
	if now and not _core_linked:
		Events.sfx.emit(&"shoot_spit", {"x": x, "pitch": 0.6})
	_core_linked = now

var _heavy_kinds_shown := {}
const HEAVY_PITCH := {"slam": 1.0, "charge": 1.35, "lob": 1.2, "burrow": 0.9, "vent": 1.5}
const HEAVY_TOAST := {"slam": "enemy_heavy", "charge": "enemy_charge", "lob": "enemy_lob", "burrow": "enemy_heavy", "vent": "enemy_vent"}

func _drain_events() -> void:
	_emit_cues()
	_step_tutorial()
	if sim.events.is_empty(): return
	var evs: Array = sim.events
	sim.events = _evbuf      # swap buffers instead of allocating a new array per frame (08 P3)
	_evbuf = evs
	for e in evs:
		match e[0]:
			"wave":
				Events.toast.emit("boss_incoming" if e[1].boss else "wave_incoming", e[1])
				Events.sfx.emit(&"boss_incoming" if e[1].boss else &"wave_incoming", e[1])
			"boss":
				Events.toast.emit("boss_incoming", e[1])
				if tutorial: tutorial.boss_seen = true
			"heavy":
				# One wind-up sound for every announced action; its pitch tells the kind apart (no new samples).
				var kind := str(e[1].get("kind", "slam"))
				var pitch: float = float(HEAVY_PITCH.get(kind, 1.0)) * (0.8 if bool(e[1].boss) else 1.0)
				if kind == "charge":      # its own dry scrape + rise, so a charge is told from a slam by ear as well
					Events.sfx.emit(&"frost_charge_windup", {"x": e[1].x, "pitch": 0.85 if bool(e[1].boss) else 1.0})
				else:
					Events.sfx.emit(&"nest_windup", {"x": e[1].x, "pitch": pitch})
				# toast: every boss wind-up, and the first time each kind is seen in a battle
				if bool(e[1].boss):
					# the boss bar frame + the ground marker + the sound carry every later wind-up
					if not _heavy_kinds_shown.has("boss:" + kind):
						_heavy_kinds_shown["boss:" + kind] = true
						Events.toast.emit("boss_heavy", e[1])
				elif not _heavy_kinds_shown.has(kind):
					_heavy_kinds_shown[kind] = true
					_heavy_toast_shown = true
					Events.toast.emit(str(HEAVY_TOAST.get(kind, "enemy_heavy")), e[1])
			"heavy_hit":
				var hit_kind := str(e[1].get("kind", "slam"))
				if hit_kind != "vent" and hit_kind != "lob":      # a lobbed zone bursts later with the explosion cue
					Events.sfx.emit(&"nest_slam", {"x": e[1].x, "pitch": (0.82 if bool(e[1].boss) else 1.0) * (1.3 if hit_kind == "charge" else 1.0)})
			"burrow":
				Events.sfx.emit(&"nest_windup", {"x": e[1].x, "pitch": 0.7})
				if not _heavy_kinds_shown.has("burrow"):
					_heavy_kinds_shown["burrow"] = true
					Events.toast.emit("enemy_burrow", e[1])
			"shell_pry", "heavy_cancel":
				Events.sfx.emit(&"nest_link_snap", {"x": e[1].x, "pitch": 0.8})
				if not _heavy_kinds_shown.has(e[0]):
					_heavy_kinds_shown[e[0]] = true
					Events.toast.emit(str(e[0]), e[1])
			"link_break":
				Events.toast.emit("link_break", e[1])
				Events.sfx.emit(&"nest_link_snap", {"x": e[1].x})
			"core_exposed":
				# the last strand to the boss was cut: its own cue (lower, longer than a single snap) and a toast every time
				Events.toast.emit("core_exposed", e[1])
				Events.sfx.emit(&"nest_link_snap", {"x": e[1].x, "pitch": 0.62})
			"boss_phase":
				Events.toast.emit("boss_phase%d" % int(e[1].phase), e[1])
				Events.sfx.emit(&"boss_incoming", e[1])
			"lob_burst":
				Events.sfx.emit(&"spore_burst", {"x": e[1].x})
			"hero_dead":
				# one cue at the moment of death; the HUD revive read-out carries the countdown (no toast, no ticking)
				Events.sfx.emit(&"hero_death", {})
				# A move held at that moment (button or key) is dropped: the revived hero stands until a new press.
				_ui_dir = 0
				_key_wait_release = _key_dir != 0
				_key_dir = 0
				sim.set_hero_dir(0)
			"hero_respawn":
				Events.sfx.emit(&"hero_respawn", {})
			"counterattack":
				Events.toast.emit("counterattack", {})
			"wave_cleared":
				if not (sim.ended and not sim.won):   # a same-step loss suppresses the banner
					Events.wave_cleared.emit(e[1])
			"deploy":
				Events.sfx.emit(&"deploy", e[1])
				if tutorial:
					tutorial.deployed += 1
					var u: Dictionary = Content.get_unit(str(e[1].unit))
					tutorial.deployed_kinds[str(e[1].unit)] = true
					tutorial.deployed_kinds[str(u.get("attack_type", ""))] = true
					for tg in u.get("tags", []): tutorial.deployed_kinds[str(tg)] = true
			"worker":
				Events.sfx.emit(&"worker_buy", {})
				if tutorial: tutorial.workers_bought += 1
			"skill":
				Events.sfx.emit(&"skill", e[1])
				if tutorial:
					tutorial.skills_cast += 1
					tutorial.cast_ids[str(e[1].skill)] = true
			"shake":
				_shake = maxf(_shake, float(e[1].amp))
			"ended":
				if not _ended_emitted:
					_ended_emitted = true
					_ui_dir = 0
					if tutorial_key != "":
						tutorial_key = ""
						Events.tutorial_step.emit("")
					var r: Dictionary = e[1]
					r["battle_uid"] = battle_uid
					r["tutorial_done"] = tutorial.done.duplicate() if tutorial else []
					finished.emit(r)
	evs.clear()

func _emit_cues() -> void:
	if sim.cues.is_empty(): return
	for k in sim.cues:
		var c: Array = sim.cues[k]
		Events.sfx.emit(c[0], c[1])
	sim.cues.clear()

func _step_tutorial() -> void:
	if tutorial == null or sim.ended or intro != null: return      # first hint after GO! has gone
	if _ui_dir != 0 or _key_dir != 0 or (autoplay_bot and sim.hero_dir != 0):
		tutorial.moved = true
	var k = tutorial.update(sim, get_process_delta_time() if not sim.paused else 0.0)
	if k != null and str(k) != tutorial_key:
		tutorial_key = str(k)
		Events.tutorial_step.emit(tutorial_key)

func _update_camera(delta: float) -> void:
	var vs := get_viewport_rect().size
	# 03 A19 / 04 R17-3: world-only zoom (k+1)/k (App.world_zoom(), enabled in project.godot). The HUD
	# is a CanvasLayer and is not zoomed. With z == 1 every value below equals the pre-zoom camera exactly.
	var z: float = App.world_zoom()
	world_zoom = z
	var vw := vs.x / z                     # visible world width
	view.view_w = vw
	view.world_zoom = z
	view.device_scale = float(App.pixel_scale)
	_free_cam_t = maxf(0.0, _free_cam_t - delta)
	if _free_cam_t <= 0.0 and not _drag_active and not _scouting:
		var target: float = sim.hero.x + _camera_lead()
		_cam_x = lerpf(_cam_x, target, clampf(delta * 4.0, 0.0, 1.0))
	var lo := -200.0 + vw * 0.5
	var hi: float = sim.L + 50.0 - vw * 0.5
	_cam_x = clampf(_cam_x, lo, maxf(lo, hi))
	# Ground row fixed GROUND_FROM_BOTTOM view px above the view bottom (04 CamFix): integer-scale views taller than
	# 360 (e.g. 800x450) show more sky. Zoomed, cy stays unrounded so that (ground_y - cy) * z is a whole view px.
	var vh := vs.y
	var bottom_inset := maxf(0.0, vh - SafeAreaS.safe_rect(get_viewport()).end.y)
	var cy: float = float(view.ground_y) - (vh * 0.5 - GROUND_FROM_BOTTOM - bottom_inset) / z
	cam.zoom = Vector2(z, z)
	cam.position = Vector2(PixelCamera.center(_cam_x, vs.x, z, view.device_scale), PixelCamera.center(cy, vh, z, view.device_scale))
	view.view_top = cam.position.y - vh * 0.5 / z
	view.view_bottom = cam.position.y + vh * 0.5 / z
	if _shake > 0.0:
		if bool(Save.progress.settings.get("screen_shake", true)):
			cam.offset = Vector2(PixelCamera.world_position(randf_range(-_shake, _shake), z, view.device_scale), PixelCamera.world_position(randf_range(-_shake, _shake) * 0.5, z, view.device_scale))
		_shake = maxf(0.0, _shake - delta * 20.0)
	else:
		cam.offset = Vector2.ZERO
	view.cam_x = cam.position.x

# ---------------- input (desktop keys + drag-to-pan) ----------------
func _unhandled_input(ev: InputEvent) -> void:
	if sim == null: return
	if ev is InputEventKey and not ev.echo:
		var k: Key = ev.keycode
		if k == KEY_A or k == KEY_LEFT or k == KEY_D or k == KEY_RIGHT:
			var l := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
			var r := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
			_key_dir = (1 if r else 0) - (1 if l else 0)
			if _key_wait_release:             # still the key that was down when the hero fell
				if _key_dir == 0: _key_wait_release = false
				_key_dir = 0
			_free_cam_t = 0.0
			if _key_dir != 0: _scouting = false
		elif ev.pressed:
			if k >= KEY_1 and k <= KEY_5:
				var i := int(k - KEY_1)
				if i < sim.card_ids.size(): Events.cmd_deploy_unit.emit(sim.card_ids[i])
			elif k == KEY_Q or k == KEY_W or k == KEY_R:
				var i2 := [KEY_Q, KEY_W, KEY_R].find(k)
				if i2 < sim.skill_ids.size(): Events.cmd_hero_skill.emit(sim.skill_ids[i2])
			elif k == KEY_E:
				Events.cmd_buy_worker.emit()
			elif k == KEY_P or k == KEY_ESCAPE:
				Events.cmd_set_paused.emit(not sim.paused)
			elif k == KEY_F3:
				Perf.show_overlay = not Perf.show_overlay
	elif ev is InputEventScreenTouch:
		_drag_active = ev.pressed
		_drag_last = ev.position
	elif ev is InputEventScreenDrag and _drag_active:
		_cam_x -= ev.relative.x / world_zoom   # events arrive in view (canvas) px; one world px = world_zoom view px
		_free_cam_t = 2.0
