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
const UiStyle_ := preload("res://src/ui/ui_style.gd")

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
	test_atlas_import_guard()
	await test_back_once_and_result_pause()
	await test_wave_cleared_banner()
	for s in SECTIONS:
		check(done.has(s), "section %s ran to completion (aborted by a script error otherwise)" % s)
	print("[test_ui] passed=%d failed=%d" % [passes, failures.size()])
	for w in load("res://src/ui/ui_style.gd").atlas_warnings:
		print("  ATLAS " + w)
	for f in failures:
		print("  - " + f)
	quit(1 if failures.size() > 0 else 0)

const SECTIONS := ["compile", "layout", "hud_input", "hud_state", "hud_pause", "result", "round_select", "menu_settings", "korean_text", "atlas_guard", "back_once", "wave_cleared"]
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

## One physical Android back press (separate press → clear the once-per-frame claim first).
func back(n: Node) -> void:
	load("res://src/ui/ui_screen.gd").reset_back_claim()
	n.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)

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
	var views := [Vector2(640, 360), Vector2(720, 360), Vector2(780, 360), Vector2(800, 360), Vector2(840, 360), Vector2(640, 400), Vector2(640, 480),
		# integer scale_mode candidates (03/04 request to 02): 1600x900@2x, 2000x1200@3x, 1366x768@2x
		Vector2(800, 450), Vector2(666, 400), Vector2(683, 384)]
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
	bus.toast.emit("counterattack", {})
	check(hud.toast_label.text == UiText.t("toast.counterattack") and not hud.toast_label.text.contains("counterattack"), "engine toast counterattack localized (%s)" % hud.toast_label.text)
	hud.toast_label.text = ""
	bus.toast.emit("zz_new_engine_key", {})
	check(hud.toast_label.text == "" and hud.unknown_toasts.has("zz_new_engine_key"), "unknown engine toast key is not shown raw")
	# wave change → banner
	s = mock.snapshot(); s.wave.index = 2; bus.hud_snapshot.emit(s)
	s = mock.snapshot(); s.wave.index = 3; bus.hud_snapshot.emit(s)
	check(hud.banner_label.modulate.a > 0.9 and hud.banner_label.text.contains("3"), "wave banner on wave change")
	# tutorial hint (Events.tutorial_step): shown with data text, hidden on ""
	bus.tutorial_step.emit("tut_move_hero")
	check(hud.tutorial_label.modulate.a > 0.9 and hud.tutorial_label.text == UiText.t("tut_move_hero"), "tutorial hint shown (%s)" % hud.tutorial_label.text)
	check(hud.layout.tutorial.encloses(hud.tutorial_label.get_rect()) or hud.tutorial_label.size.x <= hud.layout.tutorial.size.x, "tutorial hint inside its strip")
	bus.tutorial_step.emit("tut_boss_warning")
	var before: int = hud.toasts_suppressed
	hud.show_toast(UiText.t("tut_boss_warning"))
	check(hud.toasts_suppressed == before + 1, "toast identical to the visible tutorial hint is not shown twice")
	bus.tutorial_step.emit("")
	hud.show_toast(UiText.t("tut_boss_warning"))
	bus.tutorial_step.emit("tut_boss_warning")
	check(hud.toast_label.modulate.a == 0.0 and hud.tutorial_label.modulate.a > 0.9, "toast-then-hint order also shows the sentence once")
	# theme texts differ (hint "곰팡이 군단의 우두머리…" vs toast "강력한 보스…"): key-based, both orders
	bus.tutorial_step.emit("")
	bus.tutorial_step.emit("tut_boss_warning")
	hud.toast_label.modulate.a = 0.0
	bus.toast.emit("boss_incoming", {})
	check(hud.toast_label.modulate.a == 0.0 and hud.banner_label.modulate.a > 0.9, "hint shown → boss_incoming toast suppressed, banner kept")
	bus.tutorial_step.emit("")
	bus.toast.emit("boss_incoming", {})
	bus.tutorial_step.emit("tut_boss_warning")
	check(hud.toast_label.modulate.a == 0.0 and hud.tutorial_label.modulate.a > 0.9, "toast first, then hint → toast hidden")
	bus.tutorial_step.emit("")
	bus.tutorial_step.emit("")
	check(hud.tutorial_label.modulate.a == 0.0, "tutorial hint hidden on empty key")
	# boss bar from HudSnapshot.boss (stop mock ticks so its own snapshots do not overwrite ours)
	mock.running = false
	s = mock.snapshot(); s["boss"] = {"alive": true, "hp": 300.0, "hp_max": 1200.0, "id": "boss_warlord", "name_key": "enemy.boss_warlord.name"}
	bus.hud_snapshot.emit(s)
	await _frames(2)
	check(hud.top.boss_drawn, "boss HP bar drawn while boss alive")
	s = mock.snapshot(); s["boss"] = {"alive": false}
	bus.hud_snapshot.emit(s)
	await _frames(2)
	check(not hud.top.boss_drawn, "boss HP bar hidden when no boss")
	# base HP numbers (09 R09-04-5): exact snapshot values, inside their own bar half, clear of "VS"
	s = mock.snapshot(); s.player_base = {"hp": 1234.4, "hp_max": 1500}; s.enemy_base = {"hp": 7.0, "hp_max": 1200}
	bus.hud_snapshot.emit(s)
	await _frames(2)
	check(hud.top.base_labels.player == "1235/1500" and hud.top.base_labels.enemy == "7/1200", "base HP numbers match snapshot (%s / %s)" % [hud.top.base_labels.player, hud.top.base_labels.enemy])
	var br: Rect2 = hud.layout.bases
	var half := floorf((br.size.x - 18) / 2)
	var pr: Rect2 = hud.top.base_label_rects.player
	var er: Rect2 = hud.top.base_label_rects.enemy
	check(pr.position.x >= br.position.x and pr.end.x <= br.position.x + half - 2, "player HP number inside its bar half (%s, half end %.0f)" % [pr, br.position.x + half])
	check(er.position.x >= br.position.x + half + 18 + 2 and er.end.x <= br.end.x, "enemy HP number inside its bar half, clear of VS (%s)" % er)
	check(UiStyle_.number_width("1111/1500", 10) == UiStyle_.number_width("8888/1500", 10), "HP numbers fixed-width")
	# skill name tooltip: shown while the finger is down, inside safe area; cast happens on release
	var sb: Control = hud.skill_buttons[hud.skill_buttons.size() - 1]
	var sp: Vector2 = sb.get_global_rect().get_center()
	rec.clear()
	touch(4, sp, true)
	check(hud.skill_tip.modulate.a > 0.9 and hud.skill_tip.text == sb.text, "skill tip shows '%s' while pressed" % hud.skill_tip.text)
	check(hud.safe.encloses(hud.skill_tip.get_rect()) and not hud.skill_tip.get_rect().intersects(sb.get_rect()), "skill tip inside safe area and above the button (%s)" % hud.skill_tip.get_rect())
	touch(4, sp, false)
	check(hud.skill_tip.modulate.a == 0.0 and last().size() == 2 and last()[0] == &"cmd_hero_skill", "release hides tip and casts (%s)" % [last()])
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
	back(hud)
	check(hud.pause_layer.visible and last() == [&"cmd_set_paused", true], "back button pauses")
	back(hud)
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
	# star reasons with real thresholds: base 80% ≥ 50% met, 150 s > 120 s unmet → 2 stars, no mismatch
	r.ui_setup({"result": {"round_id": "r01", "won": true, "stars": 2, "time": 150.0, "kills": 9, "coins": 70, "player_base_ratio": 0.8, "first_clear": false, "next_round_id": "r02", "star_rules": {"base_hp_2": 0.5, "time_3": 120}}})
	await _frames(2)
	var rs_: Array = r.star_reasons()
	check(rs_[0].met and rs_[1].met and not rs_[2].met, "star reasons: win ✓, base ✓, time ✗ (%s)" % [rs_])
	check(rs_[1].text.contains("50") and rs_[2].text.contains("120"), "star reasons show thresholds (%s / %s)" % [rs_[1].text, rs_[2].text])
	check(not r.reason_mismatch, "star reasons agree with engine star count")
	r._shown_t = 1.0
	r.queue_redraw()
	await _frames(2)
	check(r.row_markers == ["filled", "filled", "hollow"], "met rows filled star, unmet row hollow star (shape differs, not only colour): %s" % [r.row_markers])
	r.ui_setup({"result": {"round_id": "r01", "won": false, "stars": 0, "time": 40.0, "kills": 3, "coins": 5, "player_base_ratio": 0.0, "first_clear": false, "next_round_id": "", "star_rules": {"base_hp_2": 0.5, "time_3": 120}}})
	await _frames(2)
	check(r.star_reasons().filter(func(x): return x.met).is_empty() and not r.reason_mismatch, "loss: no star conditions met")
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
	back(m)
	check(not m.settings_panel.visible, "back closes settings")
	# credits view (OFL font credit). Galmuri11 12 only; wrapped lines fit the panel.
	tap(m.btn_settings)
	tap(sp._credits_btn)
	await _frames(1)
	check(sp.showing_credits and not sp._rows[0].buttons[0].visible, "credits view replaces option rows")
	var joined := " ".join(sp.credit_lines)
	check(joined.contains("©") and joined.contains("OFL-Galmuri.txt") and (joined.contains("Galmuri") or joined.contains("갈무리")), "credits show font credit + licence file (%s)" % joined)
	for line in sp.credit_lines:
		check(UiStyle_.text_width(line, 12) <= sp.panel_rect.size.x - 24, "credit line fits panel: '%s'" % line)
	check(sp.panel_rect.encloses(Rect2(sp.panel_rect.position + Vector2(12, 50), Vector2(10, 18 * sp.credit_lines.size()))), "credit lines inside panel height (%d lines)" % sp.credit_lines.size())
	var fnt: Font = UiStyle_.font()
	check(sp.panel_rect.position.y + 19 - fnt.get_height(24) / 2.0 >= sp.panel_rect.position.y + 2, "panel title (24 px) starts inside the 2 px border")
	check(sp._rows[sp._rows.size() - 1].buttons[0].get_rect().end.y < sp._close.position.y and sp.panel_rect.encloses(sp._close.get_rect()), "rows above close, close inside panel")
	back(m)
	check(sp.visible and not sp.showing_credits and sp._rows[0].buttons[0].visible, "back from credits returns to settings rows")
	back(m)
	check(not m.settings_panel.visible, "back again closes settings")
	back(m)
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
	# 07 QA-B009/B010 root cause: fit_label on a FRESH font state (numerals font not loaded yet) used to
	# ellipsize instead of stepping down to Galmuri9 10. Must give the same answer as a warm state.
	UiStyle.reset_fonts()
	var cold: Array = UiStyle.fit_label("Heavy Footsteps", 83.0, 12)
	var warm: Array = UiStyle.fit_label("Heavy Footsteps", 83.0, 12)
	check(cold == warm and cold[0] == "Heavy Footsteps" and cold[1] == 10, "fit_label cold == warm, no ellipsis via 10 px Latin step (cold %s warm %s)" % [cold, warm])
	# 08 R5 pre-warm: runs once, then no-op; second call costs 0
	UiStyle.reset_fonts()
	var ms: float = UiStyle.prewarm_fonts()
	check(ms > 0.0 and UiStyle.prewarm_fonts() == 0.0, "font prewarm runs once (%.1f ms) and is idempotent" % ms)
	report["prewarm_ms_headless"] = ms
	var wrap12: Dictionary = UiStyle.fit_lines("Break the Mold Wall", 97.0, 12, 2)
	check(wrap12.size == 12 and wrap12.lines.size() == 2 and not wrap12.truncated, "2-line tile prefers wrap at 12 px over the 10 px cut (%s)" % [wrap12])
	fu = UiStyle.font(&"ui"); fb = UiStyle.font(&"bold"); fnum = UiStyle.font(&"num")
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
	var tile_w_notch := floorf((572 - 2 * 50 - 4 * 6) / 5.0) - 6   # 34 px notches both sides (07 TH-FIT-ROUND)
	for i in range(1, 11):
		items.append(["round.r%02d.name" % i, tile_w, 12, &"ui", "round_tile", 2])
		items.append(["round.r%02d.name" % i, tile_w_notch, 12, &"ui", "round_tile_notch", 2])
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
			var max_lines: int = it[5] if it.size() > 5 else 1
			var fl: Dictionary = UiStyle.fit_lines(txt, it[1], it[2], max_lines, it[3])   # what TouchButton actually draws
			var fit: Array = [" / ".join(fl.lines), fl.size, fl.kind]
			var truncated: bool = fl.truncated
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
		for key in UiText.FALLBACK_EN:
			for ch in str(UiText.FALLBACK_EN[key]):
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

# ---------------------------------------------------------------- atlas import guard

## The stale-import guard (UiStyle.import_is_fresh) must (a) detect a stale import, (b) let icons
## come back as soon as the import matches (no permanent masking), (c) never trigger without an md5
## record (exported builds). Uses throw-away files under user:// only.
func test_atlas_import_guard() -> void:
	var UiStyle := load("res://src/ui/ui_style.gd")
	var dir := "user://atlas_guard_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var png := dir.path_join("probe.png")
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(png)
	var md5 := FileAccess.get_md5(png)
	var ctex := dir.path_join("probe.png-test.ctex")
	var imp := FileAccess.open(png + ".import", FileAccess.WRITE)
	imp.store_string('[remap]\n\nimporter="texture"\npath="%s"\n' % ctex)
	imp.close()
	var rec_path := ctex.get_basename() + ".md5"
	# (c) no md5 record → fresh (exported-build case)
	if FileAccess.file_exists(rec_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rec_path))
	check(UiStyle.import_is_fresh(png), "guard: no md5 record → icons allowed")
	# (a) stale record → not fresh
	var rec := FileAccess.open(rec_path, FileAccess.WRITE)
	rec.store_string('source_md5="00000000000000000000000000000000"\ndest_md5="x"\n')
	rec.close()
	check(not UiStyle.import_is_fresh(png), "guard: stale source_md5 → icons disabled")
	# (b) re-import (record matches the PNG) → fresh again
	rec = FileAccess.open(rec_path, FileAccess.WRITE)
	rec.store_string('source_md5="%s"\ndest_md5="x"\n' % md5)
	rec.close()
	check(UiStyle.import_is_fresh(png), "guard: matching source_md5 → icons restored")
	# PNG edited again after import → stale again
	img.fill(Color.BLUE)
	img.save_png(png)
	check(not UiStyle.import_is_fresh(png), "guard: PNG changed after import → stale")
	# real project state, reported (not asserted: depends on 03/02 re-import)
	var real := "res://assets/atlases/ui_main.png"
	var fresh: bool = UiStyle.import_is_fresh(real)
	print("[atlas_guard] ui_main import fresh=%s (png md5 %s)" % [fresh, FileAccess.get_md5(real)])
	# the committed frames file must match the SOURCE png size, so icons are right once re-imported
	var src_img := Image.load_from_file(ProjectSettings.globalize_path(real))
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string("res://assets/atlases/ui_main.json"))
	var sz: Array = j.data.get("size", [0, 0])
	check(src_img != null and src_img.get_width() == int(sz[0]) and src_img.get_height() == int(sz[1]), "ui_main.json size %s matches source PNG %s" % [sz, src_img.get_size() if src_img else null])
	for fr in ["icon_supply", "icon_energy", "icon_gold", "icon_pause", "icon_lock", "icon_star", "icon_star_empty", "btn_move_left", "btn_move_right", "card_worker", "card_melee_basic", "card_ranged_basic", "card_tank", "icon_skill_slam"]:
		var f = j.data.frames.get(fr)
		var inside: bool = f is Dictionary and f.x + f.w <= int(sz[0]) and f.y + f.h <= int(sz[1])
		var opaque := 0
		if inside and src_img:
			for yy in int(f.h):
				for xx in int(f.w):
					if src_img.get_pixel(int(f.x) + xx, int(f.y) + yy).a > 0.5:
						opaque += 1
		check(inside and opaque > 0, "UI frame %s exists in source PNG with pixels (%d opaque)" % [fr, opaque])
	# every atlas icon path the HUD uses must obey the guard (regression 08:42: BattleInfo card icons
	# went through icon_texture and showed wrong art while ui_icon was guarded)
	UiStyle.clear_icon_cache()
	var direct = UiStyle.icon_texture({"atlas": "ui_main", "frame": "card_melee_basic"})
	var via_ui = UiStyle.ui_icon("card_melee_basic")
	if not fresh:
		check(direct == null and via_ui == null, "stale ui_main: both icon_texture and ui_icon return null (direct=%s ui=%s)" % [direct, via_ui])
	else:
		check(direct != null and via_ui != null, "fresh ui_main: icons available")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(png))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(png + ".import"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rec_path))
	done["atlas_guard"] = true

# ---------------------------------------------------------------- 07 QA-B001 / QA-B002 regressions

## Same delivery order as Godot 4.7.2 Window::_propagate_window_notification: children walked by LIVE
## index, so a node added during the walk also receives the notification (07 suite_flow._window_notify).
func _window_walk(parent: Node, what: int) -> void:
	var i := 0
	while i < parent.get_child_count():
		parent.get_child(i).propagate_notification(what)
		i += 1

func test_back_once_and_result_pause() -> void:
	var host := Control.new()
	root.add_child(host)
	var nav: Array = []
	var mount := func(screen: StringName) -> void:
		nav.append(screen)
		for ch in host.get_children():
			host.remove_child(ch)
			ch.queue_free()
		var path: String = {&"menu": "res://scenes/ui/main_menu.tscn", &"round_select": "res://scenes/ui/round_select.tscn"}[screen]
		var s: Control = load(path).instantiate()
		s.bus = bus
		s.progress_override = {"version": 1, "unlocked_round": 1, "stars": {}, "coins": 0, "settings": {}}
		host.add_child(s)       # synchronous, like App.show_screen
	bus.cmd_open_screen.connect(mount)
	# A: result → one back press → exactly one navigation to round_select
	var r: Control = load("res://scenes/ui/result.tscn").instantiate()
	r.bus = bus
	host.add_child(r)
	r.set_result({"round_id": "r01", "won": true, "stars": 1, "time": 10.0, "kills": 1, "coins": 1, "first_clear": false, "next_round_id": ""})
	await _frames(2)
	load("res://src/ui/ui_screen.gd").reset_back_claim()
	_window_walk(host, Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	check(nav == [&"round_select"], "QA-B001 A: one back on result → exactly [round_select] (got %s)" % [nav])
	# B: round select → one back press → menu, quit dialog NOT opened by the same press
	nav.clear()
	load("res://src/ui/ui_screen.gd").reset_back_claim()
	_window_walk(host, Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	var menu: Control = host.get_child(host.get_child_count() - 1)
	check(nav == [&"menu"] and menu.get("quit_layer") != null and not menu.quit_layer.visible, "QA-B001 B: one back on round select → menu once, quit dialog closed (nav %s, quit %s)" % [nav, menu.quit_layer.visible if menu.get("quit_layer") else "?"])
	# a SECOND, separate press on the menu still opens the quit dialog (latch is per press, not permanent)
	load("res://src/ui/ui_screen.gd").reset_back_claim()
	_window_walk(host, Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(menu.quit_layer.visible, "next separate back press on menu opens quit dialog")
	bus.cmd_open_screen.disconnect(mount)
	host.queue_free()
	await _frames()
	# QA-B002: after battle_ended, snapshot/engine pause must not show the HUD pause menu under the result
	var hud: Control = _mount("res://scenes/ui/hud.tscn")
	bus.battle_started.emit(MockEngine.sample_info(2, 1))
	await _frames()
	bus.battle_ended.emit({"round_id": "r01", "won": true, "stars": 1, "time": 5.0})
	var s := {"paused": true, "gold": 0, "cards": [], "skills": []}
	bus.hud_snapshot.emit(s)
	bus.battle_paused.emit(true)
	await _frames()
	check(not hud.pause_layer.visible, "QA-B002: no HUD pause menu under the result (snapshot.paused + battle_paused after end)")
	load("res://src/ui/ui_screen.gd").reset_back_claim()
	back(hud)
	check(not hud.pause_layer.visible, "back after battle end does not open the HUD pause menu")
	bus.battle_started.emit(MockEngine.sample_info(2, 1))
	await _frames()
	tap(hud.btn_pause)
	check(hud.pause_layer.visible, "next battle: pause works again")
	hud.queue_free()
	await _frames()
	done["back_once"] = true

# ---------------------------------------------------------------- 09 R09-04-7 first-wave-broken banner

func test_wave_cleared_banner() -> void:
	# the real Events has no wave_cleared yet (02 pending) → simulate the proposed contract on a test bus
	var b2: Node = EventsScript.new()
	b2.add_user_signal("wave_cleared", [{"name": "info", "type": TYPE_DICTIONARY}])
	root.add_child(b2)
	var hud: Control = load("res://scenes/ui/hud.tscn").instantiate()
	hud.bus = b2
	root.add_child(hud)
	b2.battle_started.emit(MockEngine.sample_info(5, 3))
	await _frames(2)
	b2.emit_signal("wave_cleared", {"index": 2, "t": 50.0})
	check(not hud.wave_cleared_shown, "wave 2 cleared → no banner (index 1 only)")
	b2.emit_signal("wave_cleared", {"index": 1, "t": 33.0})
	await _frames(1)
	check(hud.wave_cleared_shown and hud.banner_label.text == UiText.t("banner.first_wave_cleared") and hud.banner_label.modulate.a > 0.9, "wave 1 cleared → banner '%s'" % hud.banner_label.text)
	check(hud.BANNER_SECONDS <= 2.0, "banner duration ≤ 2 s (%.1f)" % hud.BANNER_SECONDS)
	var br: Rect2 = hud.banner_label.get_rect()
	var clash := []
	for r in [hud.layout.bases, hud.layout.resources, hud.layout.boss] + hud.layout.cards + hud.layout.skills + [hud.layout.worker, hud.layout.move_left, hud.layout.move_right]:
		if br.intersects(r):
			clash.append(r)
	check(clash.is_empty(), "banner %s covers no base HP bar / card / control (%s)" % [br, clash])
	hud.banner_label.text = "x"
	b2.emit_signal("wave_cleared", {"index": 1, "t": 40.0})
	check(hud.banner_label.text == "x", "first-wave banner shown once per battle")
	b2.battle_started.emit(MockEngine.sample_info(5, 3))
	await _frames(1)
	check(not hud.wave_cleared_shown, "flag resets on the next battle")
	hud.queue_free()
	b2.queue_free()
	await _frames()
	done["wave_cleared"] = true
