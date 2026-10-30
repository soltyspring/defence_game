extends Control
## Fallback battle HUD (used only when scenes/ui/hud.tscn is absent). Owner: 02-engine.
## Uses only Events signals per INTERFACES.md §1.

var _gold: Label
var _wave: Label
var _toast: Label
var _toast_t := 0.0
var _mana: ProgressBar
var _pbase: ProgressBar
var _ebase: ProgressBar
var _hero_lbl: Label
var _worker_btn: Button
var _cards: Dictionary = {}
var _skills: Dictionary = {}
var _pause_btn: Button
var _paused_overlay: Control
var _perf: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_static()
	Events.battle_started.connect(_on_started)
	Events.hud_snapshot.connect(_on_snapshot)
	Events.toast.connect(_on_toast)
	Events.battle_paused.connect(_on_paused)

func _lbl(size := 10) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l

func _bar(color: Color, w := 120.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, 8)
	b.show_percentage = false
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	b.add_theme_stylebox_override("fill", fg)
	b.add_theme_stylebox_override("background", bg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _button(text: String, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 9)
	return b

func _build_static() -> void:
	var safe := Rect2(Vector2.ZERO, get_viewport_rect().size)
	# top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8; top.offset_right = -8; top.offset_top = 6
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	var left := VBoxContainer.new()
	top.add_child(left)
	_gold = _lbl(11)
	left.add_child(_gold)
	_mana = _bar(Color("4aa3ff"), 90)
	left.add_child(_mana)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	var bars := HBoxContainer.new()
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.add_theme_constant_override("separation", 16)
	mid.add_child(bars)
	_pbase = _bar(Color("6fd36f"))
	_ebase = _bar(Color("e5534b"))
	bars.add_child(_pbase)
	bars.add_child(_ebase)
	_wave = _lbl(9)
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_wave)
	_pause_btn = _button("II", Vector2(36, 28))
	_pause_btn.pressed.connect(func(): Events.cmd_set_paused.emit(true))
	top.add_child(_pause_btn)
	# toast
	_toast = _lbl(12)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 52
	_toast.offset_left = -150; _toast.offset_right = 150
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	_hero_lbl = _lbl(9)
	_hero_lbl.position = Vector2(8, 300)
	add_child(_hero_lbl)
	_perf = _lbl(8)
	_perf.position = Vector2(8, 40)
	add_child(_perf)
	# bottom-left hold-to-move
	var mv := HBoxContainer.new()
	mv.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mv.offset_left = 8; mv.offset_top = -52; mv.offset_bottom = -8
	mv.add_theme_constant_override("separation", 6)
	add_child(mv)
	for d in [-1, 1]:
		var b := _button("◀" if d < 0 else "▶", Vector2(48, 44))
		b.add_theme_font_size_override("font_size", 16)
		b.button_down.connect(func(): Events.cmd_hero_move.emit(d))
		b.button_up.connect(func(): Events.cmd_hero_move.emit(0))
		mv.add_child(b)
	_paused_overlay = Control.new()
	_paused_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paused_overlay.visible = false
	add_child(_paused_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paused_overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paused_overlay.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	cc.add_child(vb)
	var pl := _lbl(20)
	pl.text = "PAUSED"
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pl)
	var rb := _button("Resume", Vector2(140, 34))
	rb.pressed.connect(func(): Events.cmd_set_paused.emit(false))
	vb.add_child(rb)
	var rt := _button("Retry", Vector2(140, 30))
	rt.pressed.connect(func(): Events.cmd_retry.emit())
	vb.add_child(rt)
	var qb := _button("Quit to rounds", Vector2(140, 30))
	qb.pressed.connect(func(): Events.cmd_open_screen.emit(&"round_select"))
	vb.add_child(qb)

func _on_started(info: Dictionary) -> void:
	for c in _cards.values(): c.queue_free()
	for c in _skills.values(): c.queue_free()
	_cards.clear(); _skills.clear()
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_top = -52; bottom.offset_bottom = -8
	bottom.offset_left = -150; bottom.offset_right = 150
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 4)
	add_child(bottom)
	move_child(bottom, 0)
	_worker_btn = _button("Worker", Vector2(52, 44))
	_worker_btn.pressed.connect(func(): Events.cmd_buy_worker.emit())
	bottom.add_child(_worker_btn)
	for c in info.cards:
		var b := _button(str(c.name), Vector2(52, 44))
		var icon = Atlas.get_frame_texture(str(c.icon.atlas), str(c.icon.frame))
		if icon:
			b.icon = icon
			b.expand_icon = true
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var id: String = c.id
		b.pressed.connect(func(): Events.cmd_deploy_unit.emit(id))
		bottom.add_child(b)
		_cards[id] = b
	var sk := HBoxContainer.new()
	sk.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sk.offset_left = -170; sk.offset_right = -8
	sk.offset_top = -52; sk.offset_bottom = -8
	sk.alignment = BoxContainer.ALIGNMENT_END
	sk.add_theme_constant_override("separation", 4)
	add_child(sk)
	move_child(sk, 0)
	for s in info.skills:
		var b := _button(str(s.name), Vector2(50, 44))
		var sid: String = s.id
		b.pressed.connect(func(): Events.cmd_hero_skill.emit(sid))
		sk.add_child(b)
		_skills[sid] = b
	_wave.text = "Round %d: %s" % [int(info.round_index), str(info.round_name)]

func _on_snapshot(s: Dictionary) -> void:
	_gold.text = "Gold %d/%d (+%.1f/s)  Army %d/%d" % [s.gold, s.gold_max, s.income, s.army.player, s.army.cap]
	_mana.max_value = s.mana_max
	_mana.value = s.mana
	_pbase.max_value = s.player_base.hp_max
	_pbase.value = s.player_base.hp
	_ebase.max_value = s.enemy_base.hp_max
	_ebase.value = s.enemy_base.hp
	var w: Dictionary = s.wave
	_wave.text = "Wave %d/%d%s" % [w.index, w.total, ("  next %ds" % int(w.next_in)) if w.next_in > 0.0 else ""]
	if _worker_btn:
		_worker_btn.text = "Worker\n%d/%d\n%dg" % [s.workers, s.workers_max, s.worker_cost]
		_worker_btn.disabled = s.workers >= s.workers_max or s.gold < s.worker_cost
	for c in s.cards:
		var b: Button = _cards.get(c.id)
		if b == null: continue
		var cd_txt := ("%.1fs" % c.cd) if c.cd > 0.0 else ""
		b.text = "%s\n%dg\n%s" % [_short(c.id), c.cost, cd_txt]
		b.disabled = not c.ready
	for k in s.skills:
		var b: Button = _skills.get(k.id)
		if b == null: continue
		b.text = "%s\n%dmp\n%s" % [_short(k.id), k.mana, ("%.0fs" % k.cd) if k.cd > 0.0 else ""]
		b.disabled = not k.ready
	var h: Dictionary = s.hero
	_hero_lbl.text = "Hero %d/%d" % [h.hp, h.hp_max] if h.alive else "Hero respawn %.0fs" % h.respawn
	if Perf.show_overlay:
		var p := Perf.snapshot()
		_perf.text = "fps %d p95 %.1fms sim %.2fms u%d p%d fx%d tex %.1fMB dc %d" % [p.fps, p.frame_ms_p95, p.sim_ms, p.units, p.projectiles, p.fx, p.tex_mem_bytes / 1048576.0, p.draw_calls]
	else:
		_perf.text = ""

func _short(id: String) -> String:
	var n: String = Content.get_unit(id).get("name", id) if Content.units.has(id) else str(Content.skills.get(id, {}).get("name", id))
	return n.substr(0, 8)

func _on_toast(key: String, args: Dictionary) -> void:
	var msg := {
		"not_enough_gold": "Not enough gold", "army_full": "Army is full", "on_cooldown": "On cooldown",
		"not_enough_mana": "Not enough mana", "hero_dead": "Hero down!", "wave_incoming": "Wave incoming!",
		"boss_incoming": "BOSS incoming!", "worker_max": "Max workers", "counterattack": "Enemy counterattack!",
		"save_recovered": "Save restored from backup",
	}
	_toast.text = msg.get(key, key)
	_toast_t = 1.6

func _on_paused(p: bool) -> void:
	_paused_overlay.visible = p

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
