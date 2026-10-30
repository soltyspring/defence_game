extends Node2D
## Battle scene controller: drives BattleSim at a fixed step, routes Events commands,
## publishes HUD snapshots, manages camera and per-battle atlas residency. Owner: 02-engine.

const SimS := preload("res://src/gameplay/battle_sim.gd")
const ViewS := preload("res://src/gameplay/battle_view.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")

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
var _ui_dir := 0
var _drag_active := false
var _drag_last := Vector2.ZERO
var _free_cam_t := 0.0
var _cam_x := 0.0
var _ended_emitted := false
var time_scale := 1.0
var _shake := 0.0

func start(p_round_id: String, seed_value: int, upgrades: Dictionary, autoplay := false) -> void:
	round_id = p_round_id
	sim = SimS.new()
	sim.setup(Content, round_id, seed_value, upgrades)
	var gy := float(Content.config.get("lane", {}).get("ground_y", 290.0))
	# atlas residency for this battle only
	var sets: Array = []
	for id in sim.card_ids: sets.append(str(Content.get_unit(id).anim_set))
	for u in Content.units.values():
		if str(u.faction) == "enemy": sets.append(str(u.anim_set))
	sets.append(str(sim.hero_def.anim_set))
	_pages = Atlas.pages_for_battle(sets, str(sim.round_def.biome))
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
	cam.limit_left = -90
	cam.limit_right = int(sim.L + 50.0)
	cam.limit_top = 0
	cam.limit_bottom = 360
	_cam_x = sim.hero.x
	cam.position = Vector2(_cam_x, 180)
	if autoplay:
		autoplay_bot = BotS.new(2, seed_value)
	Events.cmd_deploy_unit.connect(_on_deploy)
	Events.cmd_buy_worker.connect(_on_worker)
	Events.cmd_hero_move.connect(_on_hero_move)
	Events.cmd_hero_skill.connect(_on_skill)
	Events.cmd_set_paused.connect(set_paused)
	Events.battle_started.emit(sim.battle_info())
	_publish()

func _exit_tree() -> void:
	for p in _pages: Atlas.release(p)
	_pages = PackedStringArray()
	for pair in [[Events.cmd_deploy_unit, _on_deploy], [Events.cmd_buy_worker, _on_worker],
			[Events.cmd_hero_move, _on_hero_move], [Events.cmd_hero_skill, _on_skill], [Events.cmd_set_paused, set_paused]]:
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

# ---------------- loop ----------------
func _process(delta: float) -> void:
	if sim == null: return
	var t0 := Time.get_ticks_usec()
	if not sim.paused and not sim.ended:
		if autoplay_bot:
			autoplay_bot.act(sim, delta)
		else:
			sim.set_hero_dir(_ui_dir if _ui_dir != 0 else _key_dir)
		_acc += minf(delta, 0.25) * time_scale
		var steps := 0
		while _acc >= Perf.SIM_STEP and steps < Perf.SIM_MAX_STEPS:
			sim.step(Perf.SIM_STEP)
			_acc -= Perf.SIM_STEP
			steps += 1
		if steps == Perf.SIM_MAX_STEPS:
			_acc = 0.0   # spiral-of-death guard: drop backlog
	_drain_events()
	Perf.sim_ms_last = (Time.get_ticks_usec() - t0) / 1000.0
	Perf.sim_ms_max = maxf(Perf.sim_ms_max, Perf.sim_ms_last)
	Perf.counts.units = sim.players.size() + sim.enemies.size()
	var np := 0
	for p in sim.projectiles: if p.alive: np += 1
	Perf.counts.projectiles = np
	var nf := 0
	for f in sim.fxs: if f.alive: nf += 1
	Perf.counts.fx = nf
	_update_camera(delta)
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.1
		_publish()

func _publish() -> void:
	if sim: Events.hud_snapshot.emit(sim.snapshot())

func _drain_events() -> void:
	if sim.events.is_empty(): return
	var evs: Array = sim.events
	sim.events = []
	for e in evs:
		match e[0]:
			"wave":
				Events.toast.emit("boss_incoming" if e[1].boss else "wave_incoming", e[1])
			"boss":
				Events.toast.emit("boss_incoming", e[1])
			"hero_dead":
				Events.toast.emit("hero_dead", e[1])
			"counterattack":
				Events.toast.emit("counterattack", {})
			"shake":
				_shake = maxf(_shake, float(e[1].amp))
			"ended":
				if not _ended_emitted:
					_ended_emitted = true
					_ui_dir = 0
					finished.emit(e[1])

func _update_camera(delta: float) -> void:
	var vw := get_viewport_rect().size.x
	view.view_w = vw
	_free_cam_t = maxf(0.0, _free_cam_t - delta)
	if _free_cam_t <= 0.0 and not _drag_active:
		var target: float = sim.hero.x + 60.0
		_cam_x = lerpf(_cam_x, target, clampf(delta * 4.0, 0.0, 1.0))
	var lo := -90.0 + vw * 0.5
	var hi: float = sim.L + 50.0 - vw * 0.5
	_cam_x = clampf(_cam_x, lo, maxf(lo, hi))
	cam.position = Vector2(roundf(_cam_x), 180.0)
	if _shake > 0.0:
		if bool(Save.progress.settings.get("screen_shake", true)):
			cam.offset = Vector2(roundf(randf_range(-_shake, _shake)), roundf(randf_range(-_shake, _shake) * 0.5))
		_shake = maxf(0.0, _shake - delta * 20.0)
	else:
		cam.offset = Vector2.ZERO
	view.cam_x = _cam_x

# ---------------- input (desktop keys + drag-to-pan) ----------------
func _unhandled_input(ev: InputEvent) -> void:
	if sim == null: return
	if ev is InputEventKey and not ev.echo:
		var k: Key = ev.keycode
		if k == KEY_A or k == KEY_LEFT or k == KEY_D or k == KEY_RIGHT:
			var l := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
			var r := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
			_key_dir = (1 if r else 0) - (1 if l else 0)
			_free_cam_t = 0.0
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
		_cam_x -= ev.relative.x   # events arrive in 640x360 canvas space (canvas_items stretch)
		_free_cam_t = 2.0
