extends SceneTree
## 04-client redraw counter (08 H15/H18). Headless, deterministic, no timing claims.
##   Godot --headless --path <project> -s res://tests/ui/redraw_probe.gd
## Mounts the real hud.tscn on a private bus (5 cards, 3 skills) and counts CanvasItem `draw` signals
## (= _draw executions, each re-measuring text) of every HUD button + the top bar for:
##   A "static":   60 identical HudSnapshots (one per frame) — nothing visible changes
##   B "changing": 60 snapshots from MockEngine stepping 0.1 s (gold regen, one card cooling down)
## Prints: REDRAW static=<n> changing=<n> per_snapshot_static=<f> per_snapshot_changing=<f>

const EventsScript := preload("res://src/core/events.gd")
const MockEngine := preload("res://src/ui/mock/mock_engine.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")

var draws := 0

func _initialize() -> void:
	_run.call_deferred()

func _count(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).draw.is_connected(_on_draw):
		(n as CanvasItem).draw.connect(_on_draw)
	for c in n.get_children():
		_count(c)

func _on_draw() -> void:
	draws += 1

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _run() -> void:
	SafeArea.override_view_size = Vector2(640, 360)
	var bus: Node = EventsScript.new()
	root.add_child(bus)
	var hud: Control = load("res://scenes/ui/hud.tscn").instantiate()
	hud.bus = bus
	root.add_child(hud)
	var mock: Node = MockEngine.new()
	root.add_child(mock)
	mock.attach(bus)
	mock.start("r05", MockEngine.sample_info(5, 3))
	mock.running = false            # we drive snapshots ourselves
	await _frames(3)
	_count(hud)
	# A: identical snapshots
	var s: Dictionary = mock.snapshot()
	await _frames(2)
	draws = 0
	for i in 60:
		bus.hud_snapshot.emit(s.duplicate(true))
		await _frames(1)
	var a := draws
	# B: changing snapshots (economy ticking, one card on cooldown)
	mock.running = true
	bus.cmd_deploy_unit.emit("melee_basic")
	mock.running = false
	await _frames(2)
	draws = 0
	for i in 60:
		mock.running = true
		mock.step(0.1)
		mock.running = false
		bus.hud_snapshot.emit(mock.snapshot())
		await _frames(1)
	var b := draws
	print("REDRAW static=%d changing=%d per_snapshot_static=%.2f per_snapshot_changing=%.2f buttons=%d" % [a, b, a / 60.0, b / 60.0, hud.card_buttons.size() + hud.skill_buttons.size() + 4])
	quit(0)
