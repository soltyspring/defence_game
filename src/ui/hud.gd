extends "res://src/ui/ui_screen.gd"
## Battle HUD. Owner: 04-client. Contract: INTERFACES.md §1 (BattleInfo, HudSnapshot, toasts).
## Listens: battle_started, hud_snapshot, toast, battle_paused, battle_ended.
## Emits:   cmd_deploy_unit, cmd_buy_worker, cmd_hero_move (hold: dir on press, 0 on release),
##          cmd_hero_skill, cmd_set_paused, cmd_retry, cmd_open_screen, cmd_set_setting.

const HudLayout := preload("res://src/ui/hud_layout.gd")
const TOAST_SECONDS := 1.6

var info: Dictionary = {}
var snap: Dictionary = {}
var layout: Dictionary = {}
var paused := false

var top: Control                 # resources + base bars + wave (custom drawn, no input)
var btn_pause: Control
var btn_left: Control
var btn_right: Control
var btn_worker: Control
var card_buttons: Array = []     # TouchButton per card, same order as info.cards
var skill_buttons: Array = []
var toast_label: Label
var banner_label: Label
var pause_layer: Control
var pause_buttons: Array = []
var settings_panel: Control

var _held: Array[int] = []       # stack of held hero directions
var _toast_left := 0.0
var _banner_left := 0.0
var _last_wave := -1
var stats := {"cmds": 0}         # QA counters

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # pause overlay must work while tree is paused
	super._ready()

func _bus_links() -> Array:
	return [
		[&"battle_started", _on_battle_started],
		[&"hud_snapshot", _on_snapshot],
		[&"toast", _on_toast],
		[&"battle_paused", _on_paused],
		[&"battle_ended", _on_battle_ended],
	]

func ui_setup(params: Dictionary) -> void:
	if params.get("info") is Dictionary:
		_on_battle_started(params.info)

func _build() -> void:
	top = preload("res://src/ui/hud_top.gd").new()
	add_child(top)

	btn_pause = make_button("", _on_pause_pressed)
	btn_pause.glyph = &"pause"
	btn_pause.icon = UiStyle.ui_icon("icon_pause")

	btn_left = make_button("", func(): pass, TouchButton.Mode.HOLD)
	btn_left.glyph = &"left"
	btn_left.icon = UiStyle.ui_icon("btn_move_left")
	btn_left.pressed_down.connect(_on_move_press.bind(-1))
	btn_left.released.connect(func(_inside): _on_move_release(-1))
	btn_right = make_button("", func(): pass, TouchButton.Mode.HOLD)
	btn_right.glyph = &"right"
	btn_right.icon = UiStyle.ui_icon("btn_move_right")
	btn_right.pressed_down.connect(_on_move_press.bind(1))
	btn_right.released.connect(func(_inside): _on_move_release(1))

	btn_worker = make_button(UiText.t("ui.worker", "Worker"), _on_worker)
	btn_worker.glyph = &"worker"
	btn_worker.icon = UiStyle.ui_icon("card_worker")
	btn_worker.fill = Color(0.30, 0.26, 0.16, 0.95)

	toast_label = _make_label(UiStyle.FONT_M)
	banner_label = _make_label(UiStyle.FONT_L)
	banner_label.add_theme_font_override("font", UiStyle.font(&"bold"))
	banner_label.add_theme_constant_override("shadow_offset_x", 2)
	banner_label.add_theme_constant_override("shadow_offset_y", 2)
	banner_label.add_theme_color_override("font_color", UiStyle.C_ACCENT)

	_build_pause_layer()
	settings_panel = SettingsPanel.new()
	settings_panel.hide()
	settings_panel.closed.connect(func(): pause_layer.visible = paused)
	add_child(settings_panel)

func _make_label(fs: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiStyle.font(&"ui"))
	var bg := StyleBoxFlat.new()          # dark strip behind toasts/banners for contrast on bright sky
	bg.bg_color = UiStyle.C_TOAST_BG
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", bg)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.modulate.a = 0.0
	add_child(l)
	return l

func _build_pause_layer() -> void:
	pause_layer = preload("res://src/ui/dim_layer.gd").new()
	pause_layer.title = UiText.t("ui.paused")
	pause_layer.hide()
	add_child(pause_layer)
	var defs := [["ui.resume", _on_resume], ["ui.retry", _on_retry], ["ui.settings", _on_settings], ["ui.menu", _on_menu]]
	for d in defs:
		var b: Control = TouchButton.new()
		b.text = UiText.t(d[0])
		b.font_size = UiStyle.FONT_M
		b.tapped.connect(d[1])
		pause_layer.add_child(b)
		pause_buttons.append(b)
	pause_buttons[0].fill = UiStyle.C_ACCENT.darkened(0.15)

# ---------------- engine -> UI ----------------

func _on_battle_started(p_info: Dictionary) -> void:
	info = p_info
	snap = {}
	_held.clear()
	_last_wave = -1
	paused = false
	pause_layer.hide()
	for b in card_buttons + skill_buttons:
		b.queue_free()
	card_buttons.clear()
	skill_buttons.clear()
	for c in info.get("cards", []):
		var b: Control = TouchButton.new()
		var cid := str(c.get("id", ""))
		b.text = UiText.name_of("unit", cid, str(c.get("name", cid)))
		b.font_size = UiStyle.FONT_S
		b.sub_text = str(int(c.get("cost", 0)))
		b.icon = UiStyle.icon_texture(c.get("icon"))
		if b.icon == null:
			b.icon = UiStyle.ui_icon("card_" + cid)
		if b.icon == null:
			b.glyph = &"unit"
		b.tapped.connect(_on_card.bind(cid))
		add_child(b)
		card_buttons.append(b)
	for s in info.get("skills", []):
		var b: Control = TouchButton.new()
		var sid := str(s.get("id", ""))
		b.text = UiText.name_of("skill", sid, str(s.get("name", sid)))
		b.font_size = UiStyle.FONT_S
		b.sub_text = str(int(s.get("mana", 0)))
		b.fill = Color(0.18, 0.24, 0.42, 0.95)
		b.icon = UiStyle.icon_texture(s.get("icon"))
		if b.icon == null:
			b.icon = UiStyle.ui_icon("icon_" + sid)
		if b.icon == null:
			b.glyph = &"mana"
		b.tapped.connect(_on_skill.bind(sid))
		add_child(b)
		skill_buttons.append(b)
	# keep modal layers on top
	move_child(pause_layer, -1)
	move_child(settings_panel, -1)
	top.round_title = "%d. %s" % [int(info.get("round_index", 0)), UiText.name_of("round", str(info.get("round_id", "")), str(info.get("round_name", "")))]
	_on_resize()
	show()

func _on_snapshot(s: Dictionary) -> void:
	snap = s
	top.snap = s
	top.queue_redraw()
	var gold := float(s.get("gold", 0))
	var army: Dictionary = s.get("army", {})
	var army_full := int(army.get("player", 0)) >= int(army.get("cap", 1 << 30))
	var by_id := {}
	for c in s.get("cards", []):
		by_id[str(c.get("id", ""))] = c
	var cards: Array = info.get("cards", [])
	for i in mini(card_buttons.size(), cards.size()):
		var b: Control = card_buttons[i]
		var c: Dictionary = by_id.get(str(cards[i].get("id", "")), {})
		var total := float(c.get("cd_total", 0.0))
		b.cooldown_ratio = float(c.get("cd", 0.0)) / total if total > 0 else 0.0
		b.disabled = not bool(c.get("affordable", true)) or army_full
		b.dim_reason = UiText.t("ui.full") if army_full else ""
		b.queue_redraw()
	var skills_by := {}
	for c in s.get("skills", []):
		skills_by[str(c.get("id", ""))] = c
	var sk: Array = info.get("skills", [])
	for i in mini(skill_buttons.size(), sk.size()):
		var b: Control = skill_buttons[i]
		var c: Dictionary = skills_by.get(str(sk[i].get("id", "")), {})
		var total := float(c.get("cd_total", 0.0))
		b.cooldown_ratio = float(c.get("cd", 0.0)) / total if total > 0 else 0.0
		b.disabled = not bool(c.get("ready", true))
		b.queue_redraw()
	var workers := int(s.get("workers", 0))
	var wmax := int(s.get("workers_max", 0))
	var at_max := wmax > 0 and workers >= wmax
	btn_worker.sub_text = UiText.t("ui.max") if at_max else str(int(s.get("worker_cost", 0)))
	btn_worker.badge = "%d" % workers
	btn_worker.disabled = at_max or gold < float(s.get("worker_cost", 0))
	btn_worker.queue_redraw()
	var hero: Dictionary = s.get("hero", {})
	var dead := not bool(hero.get("alive", true))
	for b in [btn_left, btn_right]:
		b.disabled = dead
		b.badge = ""
	btn_left.text = str(ceili(float(hero.get("respawn", 0)))) if dead else ""   # big fixed-cell countdown
	btn_left.font_size = UiStyle.FONT_S
	btn_left.queue_redraw(); btn_right.queue_redraw()
	var wave: Dictionary = s.get("wave", {})
	var wi := int(wave.get("index", 0))
	if wi != _last_wave and _last_wave != -1 and wi > 0:
		show_banner(UiText.t("ui.boss") if bool(wave.get("boss", false)) else UiText.t("ui.wave") % [wi, int(wave.get("total", 0))])
	_last_wave = wi
	if s.has("paused") and bool(s.paused) != paused:
		_on_paused(bool(s.paused))

func _on_toast(key: String, _args: Dictionary) -> void:
	var k := "toast." + key
	if not UiText.has(k) and UiText.has("ui." + key):
		k = "ui." + key          # e.g. engine toast "save_recovered" -> ui.save_recovered
	show_toast(UiText.t(k, key))
	if key == "boss_incoming":
		show_banner(UiText.t("ui.boss"))

func _on_paused(p: bool) -> void:
	paused = p
	if p:
		_release_all_holds()
	pause_layer.visible = p and not settings_panel.visible
	queue_redraw()

func _on_battle_ended(_result: Dictionary) -> void:
	_release_all_holds()
	pause_layer.hide()
	settings_panel.hide()

# ---------------- UI -> engine ----------------

func _cmd(sig: StringName, args: Array = []) -> void:
	stats.cmds += 1
	emit_cmd(sig, args)

func _on_card(id: String) -> void:
	_cmd(&"cmd_deploy_unit", [id])

func _on_skill(id: String) -> void:
	_cmd(&"cmd_hero_skill", [id])

func _on_worker() -> void:
	_cmd(&"cmd_buy_worker")

func _on_move_press(dir: int) -> void:
	_held.erase(dir)
	_held.push_back(dir)
	_cmd(&"cmd_hero_move", [dir])

func _on_move_release(dir: int) -> void:
	if not _held.has(dir):
		return
	_held.erase(dir)
	_cmd(&"cmd_hero_move", [_held.back() if not _held.is_empty() else 0])

func _release_all_holds() -> void:
	var had := not _held.is_empty()
	_held.clear()            # clear first so the buttons' release callbacks are no-ops
	btn_left.cancel()
	btn_right.cancel()
	if had:
		_cmd(&"cmd_hero_move", [0])

func _on_pause_pressed() -> void:
	_on_paused(true)          # optimistic; engine confirms with battle_paused
	_cmd(&"cmd_set_paused", [true])

func _on_resume() -> void:
	_on_paused(false)
	_cmd(&"cmd_set_paused", [false])

func _on_retry() -> void:
	pause_layer.hide()
	_cmd(&"cmd_retry")

func _on_menu() -> void:
	pause_layer.hide()
	_cmd(&"cmd_set_paused", [false])
	_cmd(&"cmd_open_screen", [&"round_select"])

func _on_settings() -> void:
	pause_layer.hide()
	settings_panel.open(bus, progress().get("settings", {}), view, safe, target)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if is_inside_tree() and btn_left != null:
				_release_all_holds()
				if not paused and not info.is_empty():
					_on_pause_pressed()   # engine also auto-pauses (ENGINE.md §7); idempotent
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if settings_panel != null and settings_panel.visible:
				return  # panel handles it
			if paused:
				_on_resume()
			elif not info.is_empty():
				_on_pause_pressed()

# ---------------- feedback ----------------

func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	_toast_left = TOAST_SECONDS
	_fit_label(toast_label, layout.get("toast", Rect2()))

func show_banner(text: String) -> void:
	banner_label.text = text
	banner_label.modulate.a = 1.0
	_banner_left = 1.8
	_fit_label(banner_label, layout.get("banner", Rect2()))

## Centre the label in `area`, sized to its text (+ stylebox margins) so the dark strip hugs the text.
## Text wider than the area is ellipsized (no font shrinking on the pixel grid).
func _fit_label(l: Label, area: Rect2) -> void:
	if area.size == Vector2.ZERO:
		return
	var fs := l.get_theme_font_size("font_size")
	var f := l.get_theme_font("font")
	var fit := UiStyle.fit_text(l.text, area.size.x - 16, fs, &"bold" if f == UiStyle.font(&"bold") else &"ui")
	if fit[0] != l.text:
		l.text = fit[0]
	var w := ceilf(f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 16
	var h := ceilf(f.get_height(fs)) + 4
	l.size = Vector2(w, h)
	l.position = Vector2(roundf(area.get_center().x - w / 2), roundf(area.get_center().y - h / 2))

func _process(delta: float) -> void:
	if _toast_left > 0:
		_toast_left -= delta
		toast_label.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
	if _banner_left > 0:
		_banner_left -= delta
		banner_label.modulate.a = clampf(_banner_left / 0.5, 0.0, 1.0)

# ---------------- layout ----------------

func _layout() -> void:
	if top == null:
		return
	layout = HudLayout.compute(view, safe, card_buttons.size(), skill_buttons.size(), target)
	place(top, Rect2(Vector2.ZERO, view))
	top.layout = layout
	place(btn_pause, layout.pause)
	place(btn_left, layout.move_left)
	place(btn_right, layout.move_right)
	place(btn_worker, layout.worker)
	for i in card_buttons.size():
		place(card_buttons[i], layout.cards[i])
	for i in skill_buttons.size():
		place(skill_buttons[i], layout.skills[i])
	_fit_label(toast_label, layout.toast)
	_fit_label(banner_label, layout.banner)
	place(pause_layer, Rect2(Vector2.ZERO, view))
	var bw := 150.0
	var bh := maxf(target, 40.0)
	var total_h := pause_buttons.size() * (bh + 6) - 6
	var y0 := safe.get_center().y - total_h / 2 + 14
	for i in pause_buttons.size():
		pause_buttons[i].position = Vector2(view.x / 2 - bw / 2, y0 + i * (bh + 6)).round()
		pause_buttons[i].size = Vector2(bw, bh)
	pause_layer.title_y = y0 - 22
	if settings_panel.visible:
		settings_panel.open(bus, settings_panel.settings, view, safe, target)
	top.queue_redraw()
