extends "res://src/ui/ui_screen.gd"
## Battle HUD. Owner: 04-client. Contract: INTERFACES.md §1 (BattleInfo, HudSnapshot, toasts).
## Listens: battle_started, hud_snapshot, toast, battle_paused, battle_ended.
## Emits:   cmd_deploy_unit, cmd_buy_worker, cmd_hero_move (hold: dir on press, 0 on release),
##          cmd_hero_skill, cmd_set_paused, cmd_retry, cmd_open_screen, cmd_set_setting.

const HudLayout := preload("res://src/ui/hud_layout.gd")
const ThreatMarker := preload("res://src/ui/threat_marker.gd")
const ReviveBadge := preload("res://src/ui/revive_badge.gd")
const TOAST_SECONDS := 1.6
const BANNER_SECONDS := 1.8
## Engine toast key → tutorial step that explains the same event (show only the hint; 15:59 theme-A capture
## showed the boss warning three times: hint + toast + banner).
const TOAST_SAME_AS_HINT := {"boss_incoming": "tut_boss_warning"}
var _toast_key := ""          # 09 R09-04-7: ≤ 2 s

var info: Dictionary = {}
var snap: Dictionary = {}
var layout: Dictionary = {}
var paused := false

var top: Control                 # resources + base bars + wave (custom drawn, no input)
var minimap: Control
var btn_follow: Control
var btn_speed: Control           # x1 / x2 fast-forward; shares the follow button's slot (follow shows only while scouting)
var _round_index := 0
var btn_pause: Control
var btn_left: Control
var btn_right: Control
var btn_worker: Control
var card_buttons: Array = []     # TouchButton per card, same order as info.cards
var skill_buttons: Array = []
var toast_label: Label
var tutorial_label: Label         # Events.tutorial_step (02): persistent, non-blocking hint
var tutorial_key := ""
var pointer: Control                # tutorial_pointer.gd: rings and points at the button the hint talks about
var banner_label: Label
var skill_tip: Label              # skill name above the pressed skill button
var toasts_suppressed := 0        # QA
var unknown_toasts: Array = []     # QA: engine toast keys with no text (not shown)
var pause_layer: Control
var pause_buttons: Array = []
var settings_panel: Control
var threat_right: Control         # ThreatMarker (right edge: enemy ahead / nest)
var threat_left: Control          # ThreatMarker (left edge: enemy behind the camera)

var _battle_over := false         # after battle_ended: ignore pause state from snapshots (07 QA-B002)
var _held: Array[int] = []       # stack of held hero directions
var _toast_left := 0.0
var _banner_left := 0.0
var _last_wave := -1
var _boss_bar := false           # a boss is alive: the boss HP row is in use (HudLayout boss_bar)
var revive_badge: Control        # hero revive countdown (own HudLayout rect, takes no input)
var _hero_dead := false
var _revive_total := 0.0
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
		[&"tutorial_step", _on_tutorial_step],
		# 09 R09-04-7 / 01 D16+D21: connected only once 02 adds signal wave_cleared(info: Dictionary) to Events
		# (info: index:int = scripted wave index, pressure waves excluded; t:float). Until then: inert.
		[&"wave_cleared", _on_wave_cleared],
	]

func ui_setup(params: Dictionary) -> void:
	if params.get("info") is Dictionary:
		_on_battle_started(params.info)

func _build() -> void:
	top = preload("res://src/ui/hud_top.gd").new()
	add_child(top)
	minimap = preload("res://src/ui/battle_minimap.gd").new()
	minimap.seek.connect(_on_map_seek)
	add_child(minimap)
	btn_follow = make_button(UiText.t("ui.follow_hero"), _on_map_follow)
	btn_follow.font_size = UiStyle.FONT_S

	btn_speed = make_button("x1", _on_speed)
	btn_speed.font_size = UiStyle.FONT_S
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
	btn_worker.shape = &"econ"   # distinct silhouette from unit cards (07 QA-J3)

	toast_label = _make_label(UiStyle.FONT_M)
	tutorial_label = _make_label(UiStyle.FONT_M)
	tutorial_label.add_theme_color_override("font_color", UiStyle.C_GOLD)
	skill_tip = _make_label(UiStyle.FONT_M)
	banner_label = _make_label(UiStyle.FONT_L)
	banner_label.add_theme_font_override("font", UiStyle.font(&"bold"))
	banner_label.add_theme_constant_override("shadow_offset_x", 2)
	banner_label.add_theme_constant_override("shadow_offset_y", 2)
	banner_label.add_theme_color_override("font_color", UiStyle.C_ACCENT)

	threat_right = ThreatMarker.new()   # off-screen nest/enemy markers (03 A11); below the pause overlay
	threat_right.side = &"right"
	add_child(threat_right)
	threat_left = ThreatMarker.new()
	threat_left.side = &"left"
	add_child(threat_left)
	revive_badge = ReviveBadge.new()
	revive_badge.hide()
	revive_badge.finished.connect(_layout)
	add_child(revive_badge)
	pointer = preload("res://src/ui/tutorial_pointer.gd").new()
	add_child(pointer)
	_build_pause_layer()
	settings_panel = SettingsPanel.new()
	settings_panel.hide()
	settings_panel.closed.connect(func(): pause_layer.visible = paused)
	add_child(settings_panel)
	# card-bar / top-bar feedback (role stripe, ready glint, damage ghost on the base bars)
	preload("res://src/ui/hud_skin.gd").attach(self)

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

func _on_map_seek(x: float) -> void:
	if bus and bus.has_signal("cmd_camera_seek"): bus.cmd_camera_seek.emit(x)

func _on_map_follow() -> void:
	if bus and bus.has_signal("cmd_camera_follow"): bus.cmd_camera_follow.emit()

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

## Battle speed chosen by the player; kept in the settings, so it stays for the next battle.
func battle_speed() -> float:
	return clampf(float((progress().get("settings", {}) as Dictionary).get("battle_speed", 1.0)), 1.0, 2.0)

func _on_speed() -> void:
	var next := 1.0 if battle_speed() > 1.0 else 2.0
	if bus and bus.has_signal("cmd_set_setting"): bus.cmd_set_setting.emit("battle_speed", next)
	_refresh_speed(next)

func _refresh_speed(v: float) -> void:
	btn_speed.text = "x2" if v > 1.0 else "x1"
	btn_speed.fill = UiStyle.C_ACCENT.darkened(0.15) if v > 1.0 else UiStyle.C_PANEL_LIGHT

# ---------------- engine -> UI ----------------

func _on_battle_started(p_info: Dictionary) -> void:
	info = p_info
	snap = {}
	_held.clear()
	_last_wave = -1
	_boss_bar = false
	_hero_dead = false
	if revive_badge != null:
		revive_badge.flash_t = 0.0
		revive_badge.hide()
	_battle_over = false
	wave_cleared_shown = false
	_on_tutorial_step("")
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
		# 48 px skill buttons have no room for the name: show it in a tooltip while the finger is down
		b.pressed_down.connect(_show_skill_tip.bind(b))
		b.released.connect(func(_inside): _hide_skill_tip())
		add_child(b)
		skill_buttons.append(b)
	# NEW on the cards and skills this round introduces (unlock round == this round)
	var content := get_node_or_null("/root/Content")
	var ri := int(info.get("round_index", 0))
	_round_index = ri
	_refresh_speed(battle_speed())
	if content != null and ri > 1:     # R01 has one card and no skills: nothing to set apart
		var cl: Array = info.get("cards", [])
		for i in mini(cl.size(), card_buttons.size()):
			if int(content.get_unit(str(cl[i].get("id", ""))).get("unlock_round", 1)) == ri: card_buttons[i].badge = "NEW"
		var sl: Array = info.get("skills", [])
		for i in mini(sl.size(), skill_buttons.size()):
			var sd: Dictionary = content.skills.get(str(sl[i].get("id", "")), {})
			if int(sd.get("unlock_round", 1)) == ri: skill_buttons[i].badge = "NEW"
	# keep modal layers on top (the tutorial pointer above the buttons it rings, below the dialogs)
	move_child(pointer, -1)
	move_child(pause_layer, -1)
	move_child(settings_panel, -1)
	top.round_title = "%d. %s" % [int(info.get("round_index", 0)), UiText.name_of("round", str(info.get("round_id", "")), str(info.get("round_name", "")))]
	_on_resize()
	show()

func _on_snapshot(s: Dictionary) -> void:
	snap = s
	top.snap = s            # hud_top redraws itself only if a drawn value changed
	minimap.state = s.get("map", {})
	btn_follow.visible = bool(s.get("map", {}).get("scouting", false))
	btn_speed.visible = not btn_follow.visible and _round_index >= 3      # R1-R2 teach at x1 (battle.gd SPEED_FROM_ROUND)
	btn_follow.fill = UiStyle.C_ACCENT.darkened(0.25) if bool(s.get("map", {}).get("scouting", false)) else UiStyle.C_PANEL_LIGHT
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
		b.cooldown_left = float(c.get("cd", 0.0))
		b.disabled = not bool(c.get("affordable", true)) or army_full
		b.dim_reason = UiText.t("ui.full") if army_full else ""
	var skills_by := {}
	for c in s.get("skills", []):
		skills_by[str(c.get("id", ""))] = c
	var sk: Array = info.get("skills", [])
	for i in mini(skill_buttons.size(), sk.size()):
		var b: Control = skill_buttons[i]
		var c: Dictionary = skills_by.get(str(sk[i].get("id", "")), {})
		var total := float(c.get("cd_total", 0.0))
		b.cooldown_ratio = float(c.get("cd", 0.0)) / total if total > 0 else 0.0
		b.cooldown_left = float(c.get("cd", 0.0))
		b.disabled = not bool(c.get("ready", true))
	var workers := int(s.get("workers", 0))
	var wmax := int(s.get("workers_max", 0))
	var at_max := wmax > 0 and workers >= wmax
	btn_worker.sub_text = UiText.t("ui.max") if at_max else str(int(s.get("worker_cost", 0)))
	btn_worker.badge = "%d" % workers
	btn_worker.disabled = at_max or gold < float(s.get("worker_cost", 0))
	var hero: Dictionary = s.get("hero", {})
	var dead := not bool(hero.get("alive", true))
	for b in [btn_left, btn_right]:
		b.disabled = dead
		b.badge = ""
	# The move buttons always keep their arrows. The countdown lives in its own read-out under the top bar
	# (it used to overwrite the left arrow, which read as "the controls turned into a timer").
	if dead != _hero_dead:
		_hero_dead = dead
		if dead:
			_release_all_holds()          # a move held at the moment of death must not carry over to the revive
			_revive_total = maxf(0.1, float(hero.get("respawn", 0)))
			revive_badge.flash_t = 0.0
			revive_badge.show()
		elif not _battle_over and revive_badge.remaining <= 1.0:
			revive_badge.flash(0.9)       # once, when the countdown really ran out (the hero is back)
		else:
			revive_badge.hide()           # battle replaced / ended mid-countdown: nothing to announce
		_layout()
	if dead:
		revive_badge.set_state(float(hero.get("respawn", 0)), _revive_total, bool(layout.get("revive_compact", false)))
	var wave: Dictionary = s.get("wave", {})
	var wi := int(wave.get("index", 0))
	if wi != _last_wave and _last_wave != -1 and wi > 0:
		show_banner(UiText.t("ui.boss") if bool(wave.get("boss", false)) else UiText.t("ui.wave") % [wi, int(wave.get("total", 0))])
	_last_wave = wi
	var boss_now := bool((s.get("boss", {}) as Dictionary).get("alive", false))
	if boss_now != _boss_bar:
		_boss_bar = boss_now      # strips/markers use the boss row while no boss is alive
		_layout()
	_update_threat(s.get("threat", {}))
	if not _battle_over and s.has("paused") and bool(s.paused) != paused:
		_on_paused(bool(s.paused))

## 03 A11: snapshot `threat` (02, R16) → edge markers. Missing field = markers hidden (inert until 02).
func _update_threat(t: Variant) -> void:
	var td: Dictionary = {}
	if t is Dictionary and not _battle_over:
		td = t
	var d: Dictionary = ThreatMarker.compute(td)
	# The overview already marks the nest. Keep edge plates for live threats only.
	if str(d.right.get("kind", "")) == "nest": d.right = {"kind":"","m":0}
	threat_right.state = d.right
	threat_left.state = d.left

func _on_toast(key: String, _args: Dictionary) -> void:
	var k := "toast." + key
	if not UiText.has(k) and UiText.has("ui." + key):
		k = "ui." + key          # e.g. engine toast "save_recovered" -> ui.save_recovered
	if not UiText.has(k):
		# never show a raw engine id to players (07 FLOW-04B); report it so 01/02 add the text
		unknown_toasts.append(key)
		push_warning("[HUD] toast key without text: %s (add toast.%s to data/text)" % [key, key])
		return
	# same EVENT already explained by the tutorial hint (theme texts differ, so compare keys, not text)
	if TOAST_SAME_AS_HINT.get(key, "") == tutorial_key and tutorial_key != "":
		toasts_suppressed += 1
	else:
		show_toast(UiText.t(k))
		_toast_key = key
	if key == "boss_incoming":
		show_banner(UiText.t("ui.boss"))

func _on_paused(p: bool) -> void:
	if _battle_over and p:
		return   # App pauses the sim behind the result panel; never show the HUD pause menu there
	paused = p
	if p:
		_release_all_holds()
	pause_layer.visible = p and not settings_panel.visible
	tutorial_label.visible = not p          # the hint must not sit on top of the pause dialog
	# also via alpha: per-frame feedback code may re-set `visible`, the alpha stays until the pause ends
	tutorial_label.modulate.a = 0.0 if p else (1.0 if tutorial_key != "" else 0.0)
	if pointer != null: pointer.visible = not p
	queue_redraw()

func _on_tutorial_step(key: String) -> void:
	tutorial_key = key
	if pointer != null: pointer.target = _tutorial_target(key)
	if key == "":
		tutorial_label.modulate.a = 0.0
		return
	tutorial_label.text = UiText.t(key, key)
	tutorial_label.modulate.a = 0.0 if paused else 1.0     # a hint (re)sent during the pause waits for the resume
	if toast_label.modulate.a > 0.0 and (toast_label.text == tutorial_label.text or TOAST_SAME_AS_HINT.get(_toast_key, "") == key):
		_toast_left = 0.0                 # toast arrived first with the same sentence → keep only the hint
		toast_label.modulate.a = 0.0
		toasts_suppressed += 1
	_fit_label(tutorial_label, layout.get("tutorial", Rect2()))

## The control a tutorial hint is about: the first card, the move button, the baker, a skill or a unit card.
func _tutorial_target(key: String) -> Control:
	if key == "": return null
	match key:
		"tut_deploy_unit": return card_buttons[0] if not card_buttons.is_empty() else null
		"tut_move_hero": return btn_right
		"tut_buy_worker": return btn_worker
	var cards: Array = info.get("cards", [])
	var skills: Array = info.get("skills", [])
	if key.begins_with("tut_skill_"):
		var sid := "skill_" + key.trim_prefix("tut_skill_")
		for i in mini(skills.size(), skill_buttons.size()):
			if str(skills[i].get("id", "")) == sid: return skill_buttons[i]
		return null
	if key.ends_with("_unit"):
		var word := key.trim_prefix("tut_").trim_suffix("_unit")
		var ids: Array = {"ranged": ["ranged_basic"], "fast": ["fast"], "tank": ["tank"], "siege": ["siege"]}.get(word, [word])
		for i in mini(cards.size(), card_buttons.size()):
			if str(cards[i].get("id", "")) in ids: return card_buttons[i]
	return null

func _on_battle_ended(_result: Dictionary) -> void:
	_battle_over = true
	_on_tutorial_step("")
	_update_threat({})
	_release_all_holds()
	pause_layer.hide()
	settings_panel.hide()

# ---------------- UI -> engine ----------------

func _cmd(sig: StringName, args: Array = []) -> void:
	stats.cmds += 1
	emit_cmd(sig, args)

func _on_card(id: String) -> void:
	_cmd(&"cmd_deploy_unit", [id])

func _show_skill_tip(b: Control) -> void:
	if b.text == "":
		return
	skill_tip.text = b.text
	skill_tip.modulate.a = 1.0
	var fs := skill_tip.get_theme_font_size("font_size")
	var w := ceilf(UiStyle.text_width(skill_tip.text, fs)) + 16
	var h := ceilf(UiStyle.font().get_height(fs)) + 4
	var r: Rect2 = b.get_rect()
	# above the button, clamped inside the safe area (right-edge buttons would otherwise overflow)
	var x := clampf(roundf(r.get_center().x - w / 2), safe.position.x, safe.end.x - w)
	skill_tip.size = Vector2(w, h)
	skill_tip.position = Vector2(x, r.position.y - h - 4)

func _hide_skill_tip() -> void:
	skill_tip.modulate.a = 0.0

func _on_skill(id: String) -> void:
	_cmd(&"cmd_hero_skill", [id])

func _on_worker() -> void:
	_cmd(&"cmd_buy_worker")

func _on_move_press(dir: int) -> void:
	if _hero_dead:
		return                            # arrows stay visible but do nothing until the hero is back
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
			if _battle_over or not claim_back():
				return  # result screen owns back after the battle; one press = one action
			if paused:
				_on_resume()
			elif not info.is_empty():
				_on_pause_pressed()

# ---------------- feedback ----------------

func show_toast(text: String) -> void:
	# same sentence already on screen as the tutorial hint (e.g. boss warning) → do not stack it twice
	if tutorial_label != null and tutorial_label.modulate.a > 0.0 and tutorial_label.text == text:
		toasts_suppressed += 1
		return
	toast_label.text = text
	toast_label.modulate.a = 1.0
	_toast_left = TOAST_SECONDS
	_fit_label(toast_label, layout.get("toast", Rect2()))

## First wave broken (D16 peak moment): one short large banner for wave index 1 only, once per battle.
## The single banner label replaces any wave/boss banner instead of stacking (09 acceptance).
var wave_cleared_shown := false   # QA
func _on_wave_cleared(info: Dictionary) -> void:
	if _battle_over or wave_cleared_shown or int(info.get("index", 0)) != 1:
		return
	wave_cleared_shown = true
	show_banner(UiText.t("banner.first_wave_cleared"))

func show_banner(text: String) -> void:
	banner_label.text = text
	banner_label.modulate.a = 1.0
	_banner_left = BANNER_SECONDS
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
	# App re-derives the integer scale from the native window size in ITS _process, i.e. after the
	# Viewport.size_changed that laid this screen out. Until the next signal/timer the buttons were drawn (and hit
	# tested) at the previous logical size. Compare every frame: one Vector2 compare, re-layout only on change.
	if is_inside_tree() and SafeArea.view_size(get_viewport()) != view:
		for b in [btn_left, btn_right, btn_worker, btn_pause] + card_buttons + skill_buttons:
			if b != null: b.cancel()
		_on_resize()

# ---------------- layout ----------------

func _layout() -> void:
	if top == null:
		return
	var revive_row: bool = _hero_dead or (revive_badge != null and revive_badge.flash_t > 0.0)
	layout = HudLayout.compute(view, safe, card_buttons.size(), skill_buttons.size(), target, _boss_bar, revive_row)
	place(top, Rect2(Vector2.ZERO, view))
	top.layout = layout
	place(minimap, layout.minimap)
	minimap.visible = (layout.minimap as Rect2).size.x > 0.0   # dropped on views too narrow for bars + overview
	place(btn_follow, layout.follow)
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
	_fit_label(tutorial_label, layout.tutorial)
	place(threat_right, layout.threat_right)
	place(threat_left, layout.threat_left)
	place(revive_badge, layout.revive)
	place(pause_layer, Rect2(Vector2.ZERO, view))
	var bw := 150.0
	var bh := maxf(target, 40.0)
	var total_h := pause_buttons.size() * (bh + 6) - 6
	var y0 := safe.get_center().y - total_h / 2 + 14
	place(btn_speed, layout.follow)
	for i in pause_buttons.size():
		pause_buttons[i].position = Vector2(view.x / 2 - bw / 2, y0 + i * (bh + 6)).round()
		pause_buttons[i].size = Vector2(bw, bh)
	pause_layer.title_y = y0 - 22
	pause_layer.panel = Rect2(Vector2(view.x / 2 - bw / 2 - 14, y0 - 44).round(), Vector2(bw + 28, total_h + 58).round())
	if settings_panel.visible:
		settings_panel.open(bus, settings_panel.settings, view, safe, target)
	top.queue_redraw()
