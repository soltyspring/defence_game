extends SceneTree
## 04-client UI test suite (headless). Exit code 0 = all pass.
##   tools/engine/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/ui/test_ui.gd
## Covers: HUD layout matrix (screen shapes × safe areas × card/skill counts), touch-target size,
## multi-touch routing through the real Viewport GUI path, emulated-mouse de-duplication,
## hold-to-move semantics, pass-through of battlefield touches, HUD state mapping from HudSnapshot,
## pause/lifecycle, result/round-select/menu/settings command emission.
## Uses a private Events bus + MockEngine (src/ui/mock) so it does not depend on 02 gameplay.

const EventsScript := preload("res://src/core/events.gd")
const HudLayout := preload("res://src/ui/hud_layout.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")
const MockEngine := preload("res://src/ui/mock/mock_engine.gd")
const SettingsPanel := preload("res://src/ui/settings_panel.gd")
const UiText := preload("res://src/ui/ui_text.gd")

var failures := PackedStringArray()
var passes := 0
var bus: Node
var rec: Array = []

class Probe extends Node:
	var unhandled: Array = []
	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			unhandled.append(e)

func _initialize() -> void:
	_run.call_deferred()

func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(msg)
		printerr("FAIL: " + msg)

func _run() -> void:
	print("[test_ui] display=%s root=%s" % [DisplayServer.get_name(), root.get_visible_rect().size])
	# Gate: a script that fails to compile makes Godot skip code silently (runtime errors do not
	# throw), which previously let this suite pass while hud.gd was broken. Fail loudly instead.
	UiText.load_locale("ko")   # deterministic regardless of host locale
	test_compile_all("res://src/ui")
	test_layout_matrix()
	_new_bus()
	await test_hud_input()
	await test_hud_state()
	await test_hud_pause_lifecycle()
	await test_result()
	await test_round_select()
	await test_menu_and_settings()
	await test_korean_text_fit()
	for s in SECTIONS:
		check(done.has(s), "section %s ran to completion (aborted by a script error otherwise)" % s)
	print("[test_ui] passed=%d failed=%d" % [passes, failures.size()])
	for f in failures:
		print("  - " + f)
	quit(1 if failures.size() > 0 else 0)

const SECTIONS := ["compile", "layout", "hud_input", "hud_state", "hud_pause", "result", "round_select", "menu_settings", "korean_text"]
var done := {}

func test_compile_all(dir_path: String) -> void:
	var stack := [dir_path]
	var n := 0
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var da := DirAccess.open(d)
		if da == null:
			check(false, "open " + d)
			continue
		for sub in da.get_directories():
			stack.append(d.path_join(sub))
		for f in da.get_files():
			if f.ends_with(".gd"):
				n += 1
				var s = load(d.path_join(f))
				check(s is GDScript and (s as GDScript).can_instantiate(), "compiles: " + d.path_join(f))
	for scene in ["main_menu", "round_select", "hud", "result", "ui_preview"]:
		var ps = load("res://scenes/ui/%s.tscn" % scene)
		var inst = ps.instantiate() if ps is PackedScene else null
		var scr = inst.get_script() if inst else null
		check(scr is GDScript and scr.can_instantiate(), "scene %s root script usable (engine would fall back otherwise)" % scene)
		if inst:
			inst.free()
	check(n >= 15, "found %d UI scripts" % n)
	done["compile"] = true

# ---------------------------------------------------------------- helpers

func _new_bus() -> void:
	if bus != null:
		bus.queue_free()
	bus = EventsScript.new()
	root.add_child(bus)
	rec.clear()
	for s in [&"cmd_buy_worker", &"cmd_retry", &"cmd_next_round"]:
		bus.connect(s, func(): rec.append([s]))
	for s in [&"cmd_start_round", &"cmd_deploy_unit", &"cmd_hero_move", &"cmd_hero_skill", &"cmd_set_paused", &"cmd_open_screen"]:
		bus.connect(s, func(a): rec.append([s, a]))
	bus.cmd_set_setting.connect(func(k, v): rec.append([&"cmd_set_setting", k, v]))

func _frames(n := 2) -> void:
	for i in n:
		await process_frame

func _mount(path: String, progress := {}) -> Control:
	var scr: Control = load(path).instantiate()
	scr.bus = bus
	scr.progress_override = progress
	root.add_child(scr)
	return scr

func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	root.push_input(e, true)

func mouse(pos: Vector2, pressed: bool, device := 0) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.device = device
	root.push_input(e, true)

func tap(c: Control, index := 0) -> void:
	var p := c.get_global_rect().get_center()
	touch(index, p, true)
	touch(index, p, false)

func last() -> Array:
	return rec.back() if not rec.is_empty() else []

func count(sig: StringName) -> int:
	return rec.filter(func(r): return r[0] == sig).size()

# ---------------------------------------------------------------- layout

func test_layout_matrix() -> void:
	# logical sizes with stretch canvas_items + expand at 640x360 base:
	# 16:9 → 640x360, 18:9 → 720x360, 19.5:9 → 780x360, 20:9 → 800x360, 21:9 → 840x360,
	# 16:10 tablet → 640x400, 4:3 tablet → 640x480
	var views := [Vector2(640, 360), Vector2(720, 360), Vector2(780, 360), Vector2(800, 360), Vector2(840, 360), Vector2(640, 400), Vector2(640, 480)]
	# safe insets (left, top, right, bottom) in logical px: none, notch left, notch both, gesture bar bottom
	var insets := [[0, 0, 0, 0], [34, 0, 0, 0], [34, 0, 34, 0], [0, 0, 0, 12], [34, 0, 34, 12]]
	var targets := [40.0, 44.0, 48.0]
	var n := 0
	for v in views:
		for ins in insets:
			var safe := Rect2(ins[0], ins[1], v.x - ins[0] - ins[2], v.y - ins[1] - ins[3])
			for t in targets:
				for cards in range(1, 6):
					for skills in range(0, 4):
						var l := HudLayout.compute(v, safe, cards, skills, t)
						var p := HudLayout.validate(l)
						n += 1
						if not p.is_empty():
							check(false, "layout %s inset %s t=%.0f cards=%d skills=%d: %s" % [v, ins, t, cards, skills, ", ".join(p)])
						else:
							passes += 1
	print("[layout] %d configurations checked" % n)
	# battlefield visibility: bottom HUD row must leave the lane ground (y≈290..300) mostly visible
	var l640 := HudLayout.compute(Vector2(640, 360), Rect2(0, 0, 640, 360), 5, 3, 40.0)
	var top_of_bottom_row: float = (l640.cards[0] as Rect2).position.y
	check(top_of_bottom_row >= 290.0, "bottom row starts at y=%.0f, covers lane above ground line 290" % top_of_bottom_row)
	var bottom_of_top_row: float = maxf((l640.resources as Rect2).end.y, (l640.wave as Rect2).end.y)
	check(bottom_of_top_row <= 50.0, "top row too tall: %.0f" % bottom_of_top_row)
	done["layout"] = true

# ---------------------------------------------------------------- HUD input

func test_hud_input() -> void:
	SafeArea.override_view_size = Vector2(640, 360)
	SafeArea.override_safe_rect = Rect2(0, 0, 640, 360)
	var hud: Control = _mount("res://scenes/ui/hud.tscn")
	bus.battle_started.emit(MockEngine.sample_info(5, 3))
	await _frames()
	check(hud.card_buttons.size() == 5, "hud built 5 cards (got %d)" % hud.card_buttons.size())
	check(hud.skill_buttons.size() == 3, "hud built 3 skills")
	var probs := HudLayout.validate(hud.layout)
	check(probs.is_empty(), "mounted HUD layout valid: %s" % ", ".join(probs))
	for b in [hud.btn_left, hud.btn_right, hud.btn_worker, hud.btn_pause] + hud.card_buttons + hud.skill_buttons:
		check(b.size.x >= 40 and b.size.y >= 40, "touch target %s >= 40 logical (got %s)" % [b.name, b.size])

	rec.clear()
	tap(hud.card_buttons[1])
	check(last() == [&"cmd_deploy_unit", "ranged_basic"], "tap card 2 deploys ranged_basic (got %s)" % [last()])
	tap(hud.btn_worker)
	check(last() == [&"cmd_buy_worker"], "tap worker buys worker")
	tap(hud.skill_buttons[0])
	check(last() == [&"cmd_hero_skill", "skill_slam"], "tap skill 1 casts skill_slam")

	# multi-touch: hold ◀ with finger 0, tap card with finger 1, press ▶ with finger 2, release in order
	rec.clear()
	var lp: Vector2 = hud.btn_left.get_global_rect().get_center()
	var rp: Vector2 = hud.btn_right.get_global_rect().get_center()
	touch(0, lp, true)
	check(last() == [&"cmd_hero_move", -1], "hold ◀ sends -1")
	tap(hud.card_buttons[0], 1)
	check(last() == [&"cmd_deploy_unit", "melee_basic"], "second finger card tap works while ◀ held")
	touch(2, rp, true)
	check(last() == [&"cmd_hero_move", 1], "pressing ▶ while ◀ held sends +1")
	touch(2, rp, false)
	check(last() == [&"cmd_hero_move", -1], "releasing ▶ falls back to held ◀ (-1)")
	touch(0, lp + Vector2(200, -100), false)   # finger slid off before release
	check(last() == [&"cmd_hero_move", 0], "release ◀ outside button still sends 0")
	check(count(&"cmd_hero_move") == 4, "exactly 4 move commands (got %d)" % count(&"cmd_hero_move"))

	# emulated mouse events from touch must not double-fire; real mouse works on desktop
	rec.clear()
	var cp: Vector2 = hud.card_buttons[2].get_global_rect().get_center()
	mouse(cp, true, InputEvent.DEVICE_ID_EMULATION)
	mouse(cp, false, InputEvent.DEVICE_ID_EMULATION)
	check(rec.is_empty(), "emulated mouse ignored (got %s)" % [rec])
	mouse(cp, true, 0)
	mouse(cp, false, 0)
	check(last() == [&"cmd_deploy_unit", "tank"], "real mouse click deploys tank")

	# touches on empty battlefield must pass through the HUD to gameplay (_unhandled_input)
	var probe := Probe.new()
	root.add_child(probe)
	rec.clear()
	touch(3, Vector2(320, 180), true)
	touch(3, Vector2(320, 180), false)
	await _frames(1)
	check(rec.is_empty(), "battlefield touch emits no UI command")
	check(probe.unhandled.size() == 2, "battlefield touch reaches _unhandled_input (got %d events)" % probe.unhandled.size())
	probe.queue_free()
	hud.queue_free()
	await _frames()
	done["hud_input"] = true

func test_hud_state() -> void:
	var hud: Control = _mount("res://scenes/ui/hud.tscn")
	var mock := MockEngine.new()
	root.add_child(mock)
	mock.attach(bus)
	mock.start("r01")
	await _frames()
	# start: gold 100 → infantry (50) affordable, siege (200) not
	check(not hud.card_buttons[0].disabled, "infantry affordable at 100 gold")
	check(hud.card_buttons[4].disabled, "siege disabled at 100 gold")
	check(hud.card_buttons[0].sub_text == "50", "card shows cost 50")
	tap(hud.card_buttons[0])
	await _frames(1)
	check(hud.card_buttons[0].cooldown_ratio > 0.9, "card cooldown sweep starts after deploy (%.2f)" % hud.card_buttons[0].cooldown_ratio)
	mock.step(1.5); mock._emit_snapshot()
	check(absf(hud.card_buttons[0].cooldown_ratio - 0.5) < 0.05, "cooldown half after 1.5/3.0 s (%.2f)" % hud.card_buttons[0].cooldown_ratio)
	# army full → cards dimmed with reason
	mock.army = 36; mock._emit_snapshot()
	check(hud.card_buttons[0].disabled and hud.card_buttons[0].dim_reason != "", "army full disables cards with reason")
	mock.army = 0; mock._emit_snapshot()
	# worker max
	mock.workers = 8; mock._emit_snapshot()
	check(hud.btn_worker.disabled and hud.btn_worker.sub_text == UiText.t("ui.max"), "worker shows MAX at cap")
	# hero dead → move buttons disabled + respawn text
	var s: Dictionary = mock.snapshot()
	s.hero.alive = false; s.hero.respawn = 4.2
	bus.hud_snapshot.emit(s)
	check(hud.btn_left.disabled and hud.btn_left.text.contains("5"), "dead hero shows respawn countdown (%s)" % hud.btn_left.text)
	# toast
	bus.toast.emit("not_enough_gold", {})
	check(hud.toast_label.text == UiText.t("toast.not_enough_gold") and hud.toast_label.modulate.a > 0.9, "toast shown in Korean")
	# wave change → banner
	s = mock.snapshot(); s.wave.index = 2; bus.hud_snapshot.emit(s)
	s = mock.snapshot(); s.wave.index = 3; bus.hud_snapshot.emit(s)
	check(hud.banner_label.modulate.a > 0.9 and hud.banner_label.text.contains("3"), "wave banner on wave change")
	mock.running = false
	mock.queue_free()
	hud.queue_free()
	await _frames()
	done["hud_state"] = true

func test_hud_pause_lifecycle() -> void:
	var hud: Control = _mount("res://scenes/ui/hud.tscn")
	bus.battle_started.emit(MockEngine.sample_info(2, 1))
	await _frames()
	check(HudLayout.validate(hud.layout).is_empty(), "layout valid for 2 cards / 1 skill")
	rec.clear()
	tap(hud.btn_pause)
	check(last() == [&"cmd_set_paused", true] and hud.pause_layer.visible, "pause button pauses + shows overlay")
	# while paused, battlefield taps are swallowed by the overlay and cards are unreachable
	tap(hud.card_buttons[0])
	check(count(&"cmd_deploy_unit") == 0, "cards not reachable under pause overlay")
	tap(hud.pause_buttons[0])
	check(last() == [&"cmd_set_paused", false] and not hud.pause_layer.visible, "resume unpauses")
	# hold ◀, then app goes to background → hold released (0) and pause requested
	rec.clear()
	touch(0, hud.btn_left.get_global_rect().get_center(), true)
	hud.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(rec.has([&"cmd_hero_move", 0]), "focus out releases hero hold (%s)" % [rec])
	check(rec.has([&"cmd_set_paused", true]), "focus out requests pause")
	touch(0, hud.btn_left.get_global_rect().get_center(), false)
	check(count(&"cmd_hero_move") == 2, "no duplicate move after cancelled hold (%d)" % count(&"cmd_hero_move"))
	# engine-driven pause (lifecycle) shows overlay; Android back toggles
	bus.battle_paused.emit(false)
	check(not hud.pause_layer.visible, "engine unpause hides overlay")
	hud.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(hud.pause_layer.visible and last() == [&"cmd_set_paused", true], "back button pauses")
	hud.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not hud.pause_layer.visible and last() == [&"cmd_set_paused", false], "back again resumes")
	# pause menu buttons
	tap(hud.btn_pause)
	tap(hud.pause_buttons[1])
	check(last() == [&"cmd_retry"], "pause → retry")
	tap(hud.btn_pause)
	tap(hud.pause_buttons[3])
	check(last() == [&"cmd_open_screen", &"round_select"], "pause → menu goes to round select")
	tap(hud.btn_pause)
	tap(hud.pause_buttons[2])
	check(hud.settings_panel.visible, "pause → settings opens panel")
	hud.queue_free()
	await _frames()
	done["hud_pause"] = true

func test_result() -> void:
	var r: Control = _mount("res://scenes/ui/result.tscn")
	r.ui_setup({"result": {"round_id": "r01", "won": true, "stars": 3, "time": 80.0, "kills": 30, "coins": 60, "first_clear": true, "next_round_id": "r02"}})
	await _frames()
	check(r.btn_next.visible, "win with next round shows Next")
	rec.clear()
	tap(r.btn_next)
	check(last() == [&"cmd_next_round"], "next → cmd_next_round")
	tap(r.btn_retry)
	check(last() == [&"cmd_retry"], "retry → cmd_retry")
	tap(r.btn_menu)
	check(last() == [&"cmd_open_screen", &"round_select"], "menu → round select")
	bus.battle_ended.emit({"round_id": "r03", "won": false, "stars": 0, "time": 40.0, "kills": 3, "coins": 5, "first_clear": false, "next_round_id": ""})
	await _frames()
	check(not r.btn_next.visible, "loss hides Next")
	for b in [r.btn_retry, r.btn_menu]:
		check(r.panel.encloses(b.get_rect()), "result button inside panel")
	r.queue_free()
	await _frames()
	done["result"] = true

func test_round_select() -> void:
	var rs: Control = _mount("res://scenes/ui/round_select.tscn", {"version": 1, "unlocked_round": 3, "stars": {"r01": 3, "r02": 1}, "coins": 0, "settings": {}})
	rs.ui_setup({"rounds": MockEngine.ROUNDS})
	await _frames()
	check(rs.tiles[0].visible and not rs.tiles[0].disabled, "round 1 unlocked")
	check(not rs.tiles[2].disabled and rs.tiles[3].disabled, "round 3 unlocked, round 4 locked")
	check(int(rs.tiles[0].get_meta("stars")) == 3, "round 1 shows 3 stars")
	check(rs.btn_next.visible and not rs.btn_prev.visible, "11 rounds → 2 pages, on page 1")
	rec.clear()
	tap(rs.tiles[3])
	check(rec.is_empty(), "locked round tap does nothing")
	tap(rs.tiles[2])
	check(last() == [&"cmd_start_round", "r03"], "tap round 3 starts r03")
	tap(rs.btn_next)
	check(rs.page == 1 and rs.tiles[0].visible and not rs.tiles[1].visible, "page 2 shows round 11 only")
	tap(rs.btn_back)
	check(last() == [&"cmd_open_screen", &"menu"], "back → menu")
	for t in rs.tiles:
		check(t.size.x >= 40 and t.size.y >= 40, "round tile >= 40")
	rs.queue_free()
	await _frames()
	done["round_select"] = true

func test_menu_and_settings() -> void:
	var m: Control = _mount("res://scenes/ui/main_menu.tscn", {"version": 1, "unlocked_round": 1, "stars": {}, "coins": 0, "settings": {"fps_cap": 60, "sfx": 1.0, "music": 0.8, "show_damage": true}})
	await _frames()
	rec.clear()
	tap(m.btn_select)
	check(last() == [&"cmd_open_screen", &"round_select"], "menu → round select")
	tap(m.btn_settings)
	check(m.settings_panel.visible, "settings opens")
	var sp: Control = m.settings_panel
	check(Rect2(0, 0, 640, 360).encloses(sp.panel_rect), "settings panel fits 640x360 (%s)" % sp.panel_rect)
	for row in sp._rows:
		for b in row.buttons:
			check(b.size.y >= 40 and b.size.x >= 40 and sp.panel_rect.encloses(b.get_rect()), "settings option %s target ok" % row.key)
	check(sp.panel_rect.encloses(sp._close.get_rect()), "settings close inside panel")
	var row0: Array = m.settings_panel._rows[0].buttons
	tap(row0[0])
	check(last() == [&"cmd_set_setting", "fps_cap", 30], "settings fps 30 (got %s)" % [last()])
	var row1: Array = m.settings_panel._rows[1].buttons
	tap(row1[1])
	check(last() == [&"cmd_set_setting", "sfx", 0.0], "settings sfx off")
	check(SettingsPanel.option_matches("music", 0.5, 0.8) and not SettingsPanel.option_matches("music", 0.0, 0.8), "volume on/off matching")
	m.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not m.settings_panel.visible, "back closes settings")
	m.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(m.quit_layer.visible, "back on menu asks to quit (not instant exit)")
	m.quit_layer.hide()
	# play / continue chooses first round without stars (no Content autoload → falls back to round select)
	tap(m.btn_play)
	var l := last()
	check(l.size() == 2 and (l[0] == &"cmd_start_round" or l == [&"cmd_open_screen", &"round_select"]), "play emits start or opens select (%s)" % [l])
	m.queue_free()
	await _frames()
	done["menu_settings"] = true

# ---------------------------------------------------------------- typography

## Typography gate (bundled Galmuri fonts, docs/art/TYPOGRAPHY.md + docs/qa/TYPOGRAPHY_QA.md):
## - runtime fonts must be the bundled files (no Godot/OS fallback) with pixel flags and
##   allow_system_fallback = false;
## - every character of every string in data/text/{ko,en}.json + UI fallbacks exists in Galmuri11
##   Regular AND Bold (no tofu, no OS substitution); numerals font has 0-9 and +-/.:%;
## - Korean labels fit their real slots at the real (grid) sizes on narrow AND wide layouts with
##   no ellipsis (FAIL); English ellipsis is recorded as a localisation-expansion warning;
## - digit cells are stable (width("111") == width("888")) for resource readouts.
func test_korean_text_fit() -> void:
	var UiStyle := load("res://src/ui/ui_style.gd")
	UiStyle.reset_fonts()
	var fu: Font = UiStyle.font(&"ui")
	var fb: Font = UiStyle.font(&"bold")
	var fnum: Font = UiStyle.font(&"num")
	var report := {"font_sources": UiStyle.font_sources.duplicate(), "locales": {}, "layouts": {}}
	for k in [&"ui", &"bold", &"num"]:
		var src: String = UiStyle.font_sources.get(k, "")
		check(src.begins_with("bundled:res://assets/fonts/"), "font %s is bundled (%s)" % [k, src])
		var ff = UiStyle.font(k)
		check(ff is FontFile and not ff.allow_system_fallback, "font %s: allow_system_fallback=false" % k)
		if ff is FontFile:
			check(ff.antialiasing == TextServer.FONT_ANTIALIASING_NONE and ff.hinting == TextServer.HINTING_NONE and ff.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED and not ff.generate_mipmaps and not ff.multichannel_signed_distance_field, "font %s: pixel flags (no AA/hinting/subpixel/mipmaps/MSDF)" % k)
	# --- stable numerals
	for kind in [&"num", &"bold"]:
		var sz: int = UiStyle.NUM_S if kind == &"num" else UiStyle.FONT_M
		check(UiStyle.number_width("111", sz, kind) == UiStyle.number_width("888", sz, kind), "%s %d px: fixed digit cells (111 vs 888: %.1f / %.1f)" % [kind, sz, UiStyle.number_width("111", sz, kind), UiStyle.number_width("888", sz, kind)])
		check(UiStyle.number_width("+4.0/s", sz, kind) == UiStyle.number_width("+9.5/s", sz, kind), "%s %d px: income readout width stable" % [kind, sz])
	for ch in "0123456789+-/.:%xv":
		check(fnum.has_char(ch.unicode_at(0)), "numerals font has '%s'" % ch)
	report["digit_cell"] = {"num10": UiStyle.digit_cell(10, &"num"), "bold12": UiStyle.digit_cell(12, &"bold")}
	# --- slot widths from the real layout code, narrow and wide
	var layouts := {
		"640x360_notch_both": HudLayout.compute(Vector2(640, 360), Rect2(34, 0, 572, 360), 5, 3, 40.0),
		"640x360": HudLayout.compute(Vector2(640, 360), Rect2(0, 0, 640, 360), 5, 3, 40.0),
		"800x360_notch": HudLayout.compute(Vector2(800, 360), Rect2(34, 0, 766, 360), 5, 3, 48.0),
	}
	var items := []   # [key, max_w, size, kind, where]
	for lname in layouts:
		var l: Dictionary = layouts[lname]
		var card_w: float = (l.cards[0] as Rect2).size.x - 6
		report.layouts[lname] = {"card_w": card_w, "skill_w": (l.skills[0] as Rect2).size.x}
		for id in ["worker", "melee_basic", "ranged_basic", "tank", "fast", "siege"]:
			items.append(["unit.%s.name" % id, card_w, 12, &"ui", "card@" + lname])
	var tile_w := floorf((640 - 2 * 50 - 4 * 6) / 5.0) - 6   # round_select tile at 640 wide
	for i in range(1, 11):
		items.append(["round.r%02d.name" % i, tile_w, 12, &"ui", "round_tile"])
	for k in ["ui.resume", "ui.retry", "ui.settings", "ui.menu"]:
		items.append([k, 150 - 6, 12, &"ui", "pause_menu"])
	for k in ["ui.menu", "ui.retry", "ui.next"]:
		items.append([k, floorf((356 - 16) / 3.0) - 6, 12, &"ui", "result_button"])
	for k in ["ui.play", "ui.continue"]:
		items.append([k, 180 - 6, 24, &"ui", "menu_primary"])
	for k in ["ui.select_round", "ui.settings"]:
		items.append([k, 87 - 6, 12, &"ui", "menu_secondary"])
	for k in ["ui.fps_cap", "ui.sfx", "ui.music", "ui.show_damage", "ui.screen_shake"]:
		items.append([k, 356 - 12 - 8 - 2 * 68 - 4, 12, &"ui", "settings_label"])
	for k in ["toast.not_enough_gold", "toast.army_full", "toast.on_cooldown", "toast.not_enough_mana", "toast.hero_dead", "toast.wave_incoming", "toast.boss_incoming", "toast.worker_max", "ui.save_recovered"]:
		items.append([k, 572 - 16, 12, &"ui", "toast"])
	for k in ["ui.victory", "ui.defeat"]:
		items.append([k, 356 - 16, 36, &"bold", "result_title"])
	items.append(["ui.title", 572, 36, &"bold", "menu_title"])
	items.append(["ui.quit_confirm", 572, 24, &"ui", "dialog_title"])
	items.append(["ui.boss", 556, 24, &"bold", "banner"])
	items.append(["ui.select_round", 572 - 160, 24, &"ui", "round_select_title"])
	for loc in ["ko", "en"]:
		UiText.load_locale(loc)
		var rows := []
		var truncated_n := 0
		for it in items:
			var txt: String = UiText.t(it[0])
			if txt == it[0]:
				check(false, "[%s] missing text key %s" % [loc, it[0]])
				continue
			var fit: Array = UiStyle.fit_label(txt, it[1], it[2], it[3])   # what TouchButton actually draws
			var truncated: bool = fit[0] != txt
			var w: float = UiStyle.text_width(txt, it[2], it[3])
			rows.append({"key": it[0], "where": it[4], "text": txt, "width": w, "max_w": it[1], "size": it[2], "font": str(it[3]), "drawn": fit[0], "drawn_size": fit[1], "drawn_font": str(fit[2]), "truncated": truncated})
			if loc == "ko":
				check(not truncated, "[ko] %s '%s' fits %s at %d px (w=%.0f max=%.0f)" % [it[0], txt, it[4], it[2], w, it[1]])
			elif truncated:
				truncated_n += 1
				print("  WARN [en] %s '%s' → '%s' in %s (w=%.0f max=%.0f)" % [it[0], txt, fit[0], it[4], w, it[1]])
		# glyph coverage over the WHOLE text table (any string may be shown), plus UI fallbacks
		var chars := {}
		var tj := JSON.new()
		if tj.parse(FileAccess.get_file_as_string("res://data/text/%s.json" % loc)) == OK:
			for key in tj.data.get("strings", {}):
				for ch in str(tj.data.strings[key]):
					chars[ch] = true
		for key in UiText.FALLBACK_KO:
			for ch in str(UiText.FALLBACK_KO[key]):
				chars[ch] = true
		var miss_u := []
		var miss_b := []
		for ch in chars:
			var code: int = str(ch).unicode_at(0)
			if code <= 32:
				continue
			if not fu.has_char(code):
				miss_u.append(ch)
			if not fb.has_char(code):
				miss_b.append(ch)
		check(miss_u.is_empty(), "[%s] Galmuri11 covers all %d chars (missing: %s)" % [loc, chars.size(), "".join(miss_u)])
		check(miss_b.is_empty(), "[%s] Galmuri11-Bold covers all %d chars (missing: %s)" % [loc, chars.size(), "".join(miss_b)])
		report.locales[loc] = {"rows": rows, "unique_chars": chars.size(), "missing_regular": "".join(miss_u), "missing_bold": "".join(miss_b), "ellipsized": truncated_n}
	UiText.load_locale("ko")
	var out := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(out)
	var fa := FileAccess.open(out.path_join("typography_report.json"), FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(report, "  "))
		fa.close()
	print("[typography] fonts=%s ko_chars=%d en_ellipsized=%d report=%s" % [UiStyle.font_sources, report.locales.ko.unique_chars, report.locales.en.ellipsized, out.path_join("typography_report.json")])
	done["korean_text"] = true