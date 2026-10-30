extends RefCounted
## End-to-end flow acceptance through the REAL main scene, App router, Events bus, 04 UI scenes and
## the Viewport touch path: menu -> r01 -> deploy/move/worker -> background/resume -> back button ->
## win -> retry -> loss -> round select -> r02 -> next -> r03, plus live safe-area checks and
## save-recovery UX. Isolated save: user://qa07/flow_save.json. Owner: 07-qa.
##
## QA-hook note: there is no public fast-forward API yet, so battles are completed by stepping
## App.battle.sim with the 02 scripted bot inside one frame (requested: 07-qa-to-02-engine.md QA-R1).

const Q := preload("res://tests/acceptance/qa_lib.gd")
const BotS := preload("res://src/gameplay/bot_player.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const TouchButtonS := preload("res://src/ui/touch_button.gd")
const SAVE_PATH := "user://qa07/flow_save.json"
const STEP := 1.0 / 60.0

var tree: SceneTree
var q
var app: Node
var ev: Node
var save: Node
var content: Node
var main: Node
var rec := {"screen": [], "battle_started": [], "battle_ended": [], "paused": [], "toast": [], "hero_move": [], "hud_snapshot": 0}
var last_snap: Dictionary = {}
var report_cb: Callable   # flushes the report (used before the possibly-quitting back test)

func _frames(n := 2) -> void:
	for i in n:
		await tree.process_frame

func _wait(sec: float) -> void:
	await tree.create_timer(sec).timeout

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	tree.root.push_input(e, true)

func _tap(c: Control, index := 0) -> void:
	var p := c.get_global_rect().get_center()
	_touch(index, p, true)
	_touch(index, p, false)

## Faithful copy of Godot Window::_propagate_window_notification (scene/main/window.cpp), which is how
## DisplayServer WINDOW_EVENT_GO_BACK_REQUEST (Android back) reaches nodes: notify, then walk children
## by live index (no "blocked" guard, so screens added during the walk are notified too).
func _window_notify(n: Node, what: int) -> void:
	n.notification(what)
	var i := 0
	while i < n.get_child_count():
		var ch := n.get_child(i)
		if not (ch is Window):
			_window_notify(ch, what)
		i += 1

func _go_back() -> void:
	_window_notify(tree.root, Node.NOTIFICATION_WM_GO_BACK_REQUEST)

func _top_script() -> String:
	var t: Control = _top()
	return str(t.get_script().resource_path).get_file() if t and t.get_script() else "<none>"

func _buttons(node: Node, out: Array = []) -> Array:
	for ch in node.get_children():
		if ch is Control and ch.get_script() == TouchButtonS and ch.is_visible_in_tree():
			out.append(ch)
		_buttons(ch, out)
	return out

## Top-most mounted UI screen (what actually receives touches first).
func _top() -> Control:
	if app.ui_layer == null: return null
	var kids: Array = app.ui_layer.get_children()
	for i in range(kids.size() - 1, -1, -1):
		if not kids[i].is_queued_for_deletion() and kids[i] is Control:
			return kids[i]
	return null

func _btn(text: String) -> Control:
	var top: Control = _top()
	if top == null: return null
	for b in _buttons(top):
		if str(b.text) == text and not b.disabled:
			return b
	return null

func _ui(script_suffix: String) -> Control:
	if app.ui_layer == null: return null
	for c in app.ui_layer.get_children():
		var s = c.get_script()
		if s and str(s.resource_path).ends_with(script_suffix) and not c.is_queued_for_deletion():
			return c
	return null

func _sim():
	return app.battle.sim if app.battle != null and is_instance_valid(app.battle) else null

## Completes the current battle with the competent bot (win) or no input (loss). Returns true if ended.
func _finish_battle(play: bool) -> bool:
	var sim = _sim()
	if sim == null: return false
	var bot = BotS.new(2, 77) if play else null
	if play: sim.rng.seed = 101 + rec.battle_ended.size()   # reproducible enemy AI from here on
	var n := 0
	while not sim.ended and sim.t < 900.0 and n < 60 * 900:
		if bot: bot.act(sim, STEP)
		sim.step(STEP)
		n += 1
	await _frames(3)
	await _wait(1.6)   # App shows the result after 1.2 s
	await _frames(3)
	return sim.ended

## Win the current round with the scripted bot; on a bot loss retry via the result screen (max 3).
func _win_current() -> Dictionary:
	var res: Dictionary = {}
	for attempt in 3:
		var n0: int = rec.battle_ended.size()
		await _finish_battle(true)
		if rec.battle_ended.size() > n0:
			res = rec.battle_ended.back()
			res["attempts"] = attempt + 1
			if bool(res.won): return res
		if attempt == 2: break
		var rb := _btn(UiText.t("ui.retry"))
		if rb: _tap(rb)
		else: ev.cmd_retry.emit()
		await _frames(4)
	return res

func _connect() -> void:
	ev.screen_changed.connect(func(s, _p): rec.screen.append(str(s)))
	ev.battle_started.connect(func(i): rec.battle_started.append(str(i.get("round_id", ""))))
	ev.battle_ended.connect(func(r): rec.battle_ended.append(r.duplicate()))
	ev.battle_paused.connect(func(p): rec.paused.append(p))
	ev.toast.connect(func(k, _a): rec.toast.append(str(k)))
	ev.cmd_hero_move.connect(func(d): rec.hero_move.append(int(d)))
	ev.hud_snapshot.connect(func(s): rec.hud_snapshot += 1; last_snap = s)

func _boot_main() -> void:
	var ps: PackedScene = load("res://scenes/gameplay/main.tscn")
	main = ps.instantiate()
	tree.root.add_child(main)
	await _frames(4)

func run(p_q, p_tree) -> void:
	q = p_q
	tree = p_tree
	q.current_suite = "flow"
	app = tree.root.get_node_or_null("App")
	ev = tree.root.get_node_or_null("Events")
	save = tree.root.get_node_or_null("Save")
	content = tree.root.get_node_or_null("Content")
	if app == null or ev == null or save == null or content == null:
		q.record("FLOW-00", Q.BLOCKED, "autoloads available", "App/Events/Save/Content missing")
		return
	var p0: Array = Array(content.round_order).slice(0, 3)
	DirAccess.make_dir_recursive_absolute("user://qa07")
	for suf in ["", ".bak", ".tmp"]: Q.rm(SAVE_PATH + suf)
	save.path = SAVE_PATH
	save.load_progress()
	SafeArea.override_view_size = Vector2(640, 360)
	SafeArea.override_safe_rect = Rect2(0, 0, 640, 360)
	_connect()
	await _boot_main()
	q.check("FLOW-01", "boot shows main menu from scenes/ui (not fallback)", app.screen == &"menu" and app.ui_source.get(&"menu", "") == "scenes/ui",
		"screen=%s source=%s" % [app.screen, app.ui_source])
	# locked round refused
	ev.cmd_start_round.emit(str(p0[2]))
	await _frames(2)
	q.check("FLOW-02", "locked round %s refused on fresh save (toast round_locked, stays on menu)" % p0[2], app.screen == &"menu" and rec.toast.has("round_locked"), "screen=%s toasts=%s" % [app.screen, rec.toast])
	await _touch_targets("TOUCH-MENU", "main menu", _top())
	# play via real touch
	var play := _btn(UiText.t("ui.play"))
	if play == null:
		q.record("FLOW-03", Q.BLOCKED, "tap Play starts first round", "Play button not found")
		return
	_tap(play)
	await _frames(4)
	var sim = _sim()
	q.check("FLOW-03", "tap Play (touch) -> battle %s with HUD from scenes/ui" % p0[0], sim != null and app.current_round == str(p0[0]) and app.ui_source.get(&"hud", "") == "scenes/ui" and rec.battle_started.back() == str(p0[0]),
		"round=%s hud=%s started=%s" % [app.current_round, app.ui_source.get(&"hud"), rec.battle_started])
	if sim == null: return
	await _wait(0.4)
	var keys := ["t", "gold", "gold_max", "income", "workers", "workers_max", "worker_cost", "mana", "mana_max", "cards", "skills", "hero", "player_base", "enemy_base", "wave", "army", "paused"]
	var missing := keys.filter(func(k): return not last_snap.has(k))
	q.check("FLOW-04", "hud_snapshot streams (~10 Hz) with all INTERFACES §1.3 keys", rec.hud_snapshot >= 3 and missing.is_empty(), "snapshots=%d missing=%s" % [rec.hud_snapshot, missing])
	var hud := _ui("ui/hud.gd")
	if hud == null:
		q.record("FLOW-05", Q.BLOCKED, "HUD instance", "hud.gd not mounted")
		return
	await _touch_targets("TOUCH-HUD-R1", "HUD %s" % p0[0], hud)
	await _safe_area_matrix("SAFE-R1", hud)
	# deploy via touch
	var card: Control = hud.card_buttons[0] if hud.get("card_buttons") and hud.card_buttons.size() > 0 else null
	if card == null:
		q.record("FLOW-05", Q.BLOCKED, "tap card deploys", "no card button")
	else:
		sim.gold = 150.0
		var d0: int = sim.stats.deployed
		var g0: float = sim.gold
		_tap(card)
		await _frames(2)
		q.check("FLOW-05", "tap card (touch) deploys a unit and spends gold", sim.stats.deployed == d0 + 1 and sim.gold < g0, "deployed %d->%d gold %.0f->%.0f" % [d0, sim.stats.deployed, g0, sim.gold])
	# worker via touch
	var wbtn: Control = hud.get("btn_worker")
	if wbtn:
		sim.gold = float(sim.worker_cost()) + 5.0
		var w0: int = sim.workers
		_tap(wbtn)
		await _frames(2)
		q.check("FLOW-06", "tap worker button (touch) hires a worker", sim.workers == w0 + 1, "workers %d->%d" % [w0, sim.workers])
	# hold move + second finger tap
	var right: Control = hud.get("btn_right")
	if right and card:
		var hx: float = sim.hero.x
		_touch(0, right.get_global_rect().get_center(), true)
		await _wait(0.5)
		var moved: bool = sim.hero.x > hx + 5.0 and sim.hero_dir == 1
		for k in sim.card_cd: sim.card_cd[k] = 0.0
		sim.gold = 150.0
		var d1: int = sim.stats.deployed
		_tap(card, 1)
		await _frames(2)
		q.check("FLOW-07", "multi-touch: holding ▶ moves hero while a 2nd finger deploys", moved and sim.stats.deployed == d1 + 1,
			"hero %.0f->%.0f dir=%d deployed %d->%d" % [hx, sim.hero.x, sim.hero_dir, d1, sim.stats.deployed])
		# background while finger still down
		Q.rm(SAVE_PATH)
		var moves_before: int = rec.hero_move.size()
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		await _frames(3)
		var t_bg: float = sim.t
		await _wait(1.0)
		var released: bool = rec.hero_move.slice(moves_before).has(0)
		q.check("FLOW-08", "app background -> battle paused, pause overlay shown, progress saved", sim.paused and rec.paused.has(true) and hud.pause_layer.visible and FileAccess.file_exists(SAVE_PATH),
			"paused=%s overlay=%s saved=%s" % [sim.paused, hud.pause_layer.visible, FileAccess.file_exists(SAVE_PATH)])
		q.check("FLOW-09", "while backgrounded the sim does not advance; held move is released (cmd_hero_move 0)", sim.t == t_bg and released, "t %.3f->%.3f released=%s" % [t_bg, sim.t, released])
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _wait(0.6)
		q.check("FLOW-10", "app resume keeps battle paused until the player taps resume (ENGINE §7)", sim.paused and sim.t == t_bg, "paused=%s t=%.3f" % [sim.paused, sim.t])
		_touch(0, right.get_global_rect().get_center(), false)   # stale finger-up after resume
		var resume: Control = hud.pause_buttons[0] if hud.get("pause_buttons") else null
		if resume:
			_tap(resume)
			await _wait(0.5)
			q.check("FLOW-11", "tap Resume -> sim runs again with no ghost hero movement", not sim.paused and sim.t > t_bg and sim.hero_dir == 0, "paused=%s t=%.3f dir=%d" % [sim.paused, sim.t, sim.hero_dir])
	# Android back button in battle
	var pc0: int = rec.paused.size()
	_go_back()
	await _frames(4)
	var after_back: bool = sim.paused
	var seq: Array = rec.paused.slice(pc0)
	q.check("FLOW-12", "Android back in battle opens pause (single toggle)", after_back and seq.size() == 1, "sim.paused=%s battle_paused sequence=%s" % [after_back, seq], {"battle_paused_seq": seq})
	ev.cmd_set_paused.emit(false)
	await _frames(2)
	# ---- win r01
	var ended_n: int = rec.battle_ended.size()
	var won := false
	for attempt in 3:
		await _finish_battle(true)
		if rec.battle_ended.size() > ended_n and bool(rec.battle_ended.back().won):
			won = true
			break
		var rb := _btn(UiText.t("ui.retry"))
		if rb: _tap(rb)
		else: ev.cmd_retry.emit()
		await _frames(4)
		ended_n = rec.battle_ended.size()
	var res: Dictionary = rec.battle_ended.back() if not rec.battle_ended.is_empty() else {}
	q.check("FLOW-13", "win %s -> result screen (scenes/ui) + one battle_ended with won=true, stars, next_round_id" % p0[0],
		won and app.screen == &"result" and app.ui_source.get(&"result", "") == "scenes/ui" and int(res.get("stars", 0)) >= 1 and str(res.get("next_round_id", "")) == str(p0[1]),
		"won=%s screen=%s result=%s" % [won, app.screen, res], res)
	var disk = save.get_script().new()
	disk.path = SAVE_PATH
	disk.load_progress()
	q.check("FLOW-14", "win persisted to disk: stars + unlocked_round >= 2 + coins", int(disk.progress.stars.get(str(p0[0]), 0)) >= 1 and int(disk.progress.unlocked_round) >= 2 and int(disk.progress.coins) > 0,
		"disk=%s" % JSON.stringify(disk.progress))
	var stars_r1 := int(disk.progress.stars.get(str(p0[0]), 0))
	disk.free()
	var hud_under: Control = _ui("ui/hud.gd")
	var pause_under: bool = hud_under != null and hud_under.pause_layer.visible
	q.check("FLOW-13B", "result screen: HUD pause menu is not shown underneath the result panel", not pause_under,
		"hud.pause_layer.visible=%s under result (App._show_result sets sim.paused=true directly; HUD maps snapshot.paused=true to its pause overlay)" % pause_under)
	await _touch_targets("TOUCH-RESULT", "result screen", _top())
	# ---- retry via result button
	var old_battle: Node = app.battle
	var rbtn := _btn(UiText.t("ui.retry"))
	if rbtn == null:
		q.record("FLOW-15", Q.BLOCKED, "retry from result", "retry button not found")
		return
	_tap(rbtn)
	await _frames(4)
	sim = _sim()
	var hud_count := 0
	for ch in app.ui_layer.get_children():
		if not ch.is_queued_for_deletion(): hud_count += 1
	var raw0: Dictionary = Q.read_json("res://data/rounds/%s.json" % p0[0])
	q.check("FLOW-15", "retry -> fresh battle of same round (old battle freed, single UI root, t~0, start gold)",
		sim != null and app.current_round == str(p0[0]) and not is_instance_valid(old_battle) and hud_count == 1 and sim.t < 1.0 and sim.gold <= float(raw0.start_gold) + 10.0,
		"round=%s old_valid=%s ui_roots=%d t=%.2f gold=%.1f" % [app.current_round, is_instance_valid(old_battle), hud_count, sim.t if sim else -1.0, sim.gold if sim else -1.0])
	sim.gold = 150.0
	var dd: int = sim.stats.deployed
	ev.cmd_deploy_unit.emit(str(sim.card_ids[0]))
	await _frames(1)
	q.check("FLOW-16", "after retry one deploy command spawns exactly one unit (no duplicate handlers)", sim.stats.deployed == dd + 1, "deployed %d->%d" % [dd, sim.stats.deployed])
	# ---- loss
	ended_n = rec.battle_ended.size()
	await _finish_battle(false)
	var lres: Dictionary = rec.battle_ended.back() if rec.battle_ended.size() > ended_n else {}
	var disk2 = save.get_script().new()
	disk2.path = SAVE_PATH
	disk2.load_progress()
	q.check("FLOW-17", "loss -> result won=false, no next button, saved stars/unlock not reduced",
		not lres.is_empty() and not bool(lres.won) and app.screen == &"result" and _btn(UiText.t("ui.next")) == null and int(disk2.progress.stars.get(str(p0[0]), 0)) == stars_r1 and int(disk2.progress.unlocked_round) >= 2,
		"result=%s next_btn=%s disk=%s" % [lres, _btn(UiText.t("ui.next")) != null, JSON.stringify(disk2.progress)])
	disk2.free()
	# ---- result -> round select -> r02 via touch
	var mbtn := _btn(UiText.t("ui.menu"))
	if mbtn: _tap(mbtn)
	await _frames(4)
	q.check("FLOW-18", "result menu button -> round select (battle torn down)", app.screen == &"round_select" and app.battle == null, "screen=%s" % app.screen)
	await _touch_targets("TOUCH-ROUNDSEL", "round select", _top())
	var tile := _btn(UiText.name_of("round", str(p0[1]), str(content.get_round(str(p0[1])).name)))
	if tile == null:
		q.record("FLOW-19", Q.BLOCKED, "round select tile for %s" % p0[1], "unlocked tile not found by name")
		return
	_tap(tile)
	await _frames(4)
	q.check("FLOW-19", "tap unlocked %s tile -> battle %s" % [p0[1], p0[1]], app.current_round == str(p0[1]) and _sim() != null, "round=%s" % app.current_round)
	var hud2 := _ui("ui/hud.gd")
	if hud2: await _touch_targets("TOUCH-HUD-R2", "HUD %s" % p0[1], hud2)
	var r2res: Dictionary = await _win_current()
	var nbtn := _btn(UiText.t("ui.next"))
	q.check("FLOW-20", "win %s -> Next button visible" % p0[1], bool(r2res.won) and nbtn != null, "result=%s next=%s" % [r2res, nbtn != null])
	if nbtn == null:
		return
	_tap(nbtn)
	await _frames(4)
	q.check("FLOW-21", "Next -> battle %s" % p0[2], app.current_round == str(p0[2]) and _sim() != null, "round=%s" % app.current_round)
	var hud3 := _ui("ui/hud.gd")
	if hud3:
		await _touch_targets("TOUCH-HUD-R3", "HUD %s" % p0[2], hud3)
		await _safe_area_matrix("SAFE-R3", hud3)
	var r3res: Dictionary = await _win_current()
	q.check("FLOW-22", "win %s (first 3 rounds cleared through real UI); unlocked_round >= 4" % p0[2], bool(r3res.won) and int(save.progress.unlocked_round) >= 4,
		"result=%s unlocked=%s" % [r3res, save.progress.unlocked_round])
	# ---- back button on result
	var sc0: int = rec.screen.size()
	_go_back()
	await _frames(5)
	var nav: Array = rec.screen.slice(sc0)
	var top_s := _top_script()
	q.check("FLOW-23", "Android back on result navigates exactly once and the target screen is actually mounted", nav.size() == 1 and top_s == {"menu": "main_menu.gd", "round_select": "round_select.gd"}.get(str(app.screen), "?"),
		"screen_changed sequence=%s App.screen=%s top mounted UI=%s" % [nav, app.screen, top_s], {"nav": nav, "top": top_s})
	# back from round select -> menu, and the freshly mounted menu must not also consume the same back press
	if app.screen != &"round_select":
		ev.cmd_open_screen.emit(&"round_select")
		await _frames(3)
	var sc1: int = rec.screen.size()
	_go_back()
	await _frames(4)
	var nav2: Array = rec.screen.slice(sc1)
	var menu_now: Control = _ui("ui/main_menu.gd")
	var quit_shown: bool = menu_now != null and menu_now.quit_layer.visible
	q.check("FLOW-23B", "Android back on round select -> menu once, without also opening the menu's quit dialog", nav2 == ["menu"] and menu_now != null and not quit_shown,
		"nav=%s menu=%s quit_dialog_visible=%s" % [nav2, menu_now != null, quit_shown], {"nav": nav2, "quit_dialog": quit_shown})
	if menu_now and quit_shown:
		menu_now.quit_layer.hide()
	if app.screen != &"menu":
		ev.cmd_open_screen.emit(&"menu")
		await _frames(3)
	# ---- save recovery UX
	await _save_recovery_ux()
	# ---- back on main menu must ask, not quit (last: may terminate the process)
	await _back_on_menu()

func _save_recovery_ux() -> void:
	main.queue_free()
	await _frames(2)
	var before := int(save.progress.unlocked_round)
	Q.write_text(SAVE_PATH, "{ truncated by qa")
	save.load_progress()
	var toasts0: int = rec.toast.size()
	await _boot_main()
	var menu := _ui("ui/main_menu.gd")
	var notice := str(menu.get("_notice")) if menu else ""
	q.check("FLOW-24", "corrupt save at launch -> restored from .bak, recovered flagged, menu shows recovery notice",
		save.recovered and int(save.progress.unlocked_round) >= 2 and notice != "",
		"recovered=%s unlocked %d->%s notice='%s' toasts=%s" % [save.recovered, before, save.progress.unlocked_round, notice, rec.toast.slice(toasts0)])

func _back_on_menu() -> void:
	# silent provisional entry: survives in the flushed report only if the process quits during the check
	q.results.append({"id": "FLOW-25", "suite": "flow", "status": Q.FAIL, "title": "Android back on main menu shows quit confirmation instead of quitting immediately",
		"detail": "process quit during the check"})
	if report_cb.is_valid(): report_cb.call()
	var menu := _ui("ui/main_menu.gd")
	_go_back()
	await _frames(6)
	q.results.pop_back()
	var shown: bool = menu != null and menu.quit_layer.visible
	q.check("FLOW-25", "Android back on main menu shows quit confirmation instead of quitting immediately", shown, "quit_layer.visible=%s" % shown)

# ---------------- touch / safe area ----------------

func _touch_targets(id: String, label: String, node: Node) -> void:
	await _frames(1)
	var bs := _buttons(node)
	var small := []
	var overlap := []
	var outside := []
	var sr: Rect2 = SafeArea.override_safe_rect if SafeArea.override_safe_rect.size != Vector2.ZERO else Rect2(Vector2.ZERO, SafeArea.override_view_size)
	for i in bs.size():
		var r: Rect2 = bs[i].get_global_rect()
		if minf(r.size.x, r.size.y) < SafeArea.MIN_TARGET_LOGICAL - 0.5:
			small.append("%s %s" % [_name(bs[i]), r.size])
		if not sr.grow(0.5).encloses(r):
			outside.append("%s %s" % [_name(bs[i]), r])
		for j in range(i + 1, bs.size()):
			var r2: Rect2 = bs[j].get_global_rect()
			if r.grow(-0.5).intersects(r2.grow(-0.5)):
				overlap.append("%s x %s" % [_name(bs[i]), _name(bs[j])])
	q.check(id, "%s: %d visible touch targets >= %d logical px, inside safe area, non-overlapping" % [label, bs.size(), int(SafeArea.MIN_TARGET_LOGICAL)],
		bs.size() > 0 and small.is_empty() and overlap.is_empty() and outside.is_empty(),
		"small=%s overlap=%s outside=%s" % [small, overlap, outside], {"buttons": bs.size(), "safe": str(sr)})

func _name(b: Control) -> String:
	var t := str(b.text)
	if t == "": t = str(b.glyph)
	return t if t != "" else b.name

func _safe_area_matrix(id: String, hud: Control) -> void:
	var cfgs := [
		["16:9", Vector2(640, 360), Rect2(0, 0, 640, 360)],
		["19.5:9 notch both", Vector2(780, 360), Rect2(34, 0, 712, 360)],
		["20:9 notch L + gesture bar", Vector2(800, 360), Rect2(40, 0, 760, 348)],
		["21:9 cutout L", Vector2(840, 360), Rect2(48, 0, 792, 360)],
		["4:3 tablet", Vector2(640, 480), Rect2(0, 0, 640, 480)],
	]
	var fails := []
	for cfg in cfgs:
		SafeArea.override_view_size = cfg[1]
		SafeArea.override_safe_rect = cfg[2]
		tree.root.size_changed.emit()
		await _frames(2)
		var n0: int = q.results.size()
		await _touch_targets(id + "-" + str(cfg[0]).get_slice(" ", 0), "HUD @ %s %s safe %s" % [cfg[0], cfg[1], cfg[2]], hud)
		if q.results[n0].status != Q.PASS: fails.append(cfg[0])
	SafeArea.override_view_size = Vector2(640, 360)
	SafeArea.override_safe_rect = Rect2(0, 0, 640, 360)
	tree.root.size_changed.emit()
	await _frames(2)
