extends Control
## Base for 04 UI screens mounted by the engine (INTERFACES.md §4). Owner: 04-client.
## - Talks only through the Events bus. `bus` can be injected (tests / mock preview) before add_child.
## - Engine may call `ui_setup(params)` right after mounting (requested in 04-client-to-02-engine.md);
##   screens also listen to the matching signals so either delivery order works.
## - Root is full-rect, ignores mouse so touches on empty space reach the battlefield.

const UiStyle := preload("res://src/ui/ui_style.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const SafeArea := preload("res://src/ui/safe_area.gd")
const TouchButton := preload("res://src/ui/touch_button.gd")
const SettingsPanel := preload("res://src/ui/settings_panel.gd")
const UpgradePanel := preload("res://src/ui/upgrade_panel.gd")

var bus: Node
## Test/mock hook: when non-empty, used instead of Save.progress.
var progress_override: Dictionary = {}
var safe := Rect2()
var view := Vector2(640, 360)
var target := 40.0

## Android back: one physical press must act exactly once (07 QA-B001). Godot 4.7.2 delivers the same
## WM_GO_BACK_REQUEST to nodes mounted DURING the walk, so a screen that navigates synchronously would
## see the new screen also handle the same press. Every 04 back handler calls claim_back() first:
## the first handler in a frame wins, the rest ignore it; navigation is additionally deferred.
static var _back_frame := -1

static func claim_back() -> bool:
	var f := Engine.get_process_frames()
	if f == _back_frame:
		return false
	_back_frame = f
	return true

## Test hook: forget the claim (e.g. to simulate a second press in the same synthetic frame).
static func reset_back_claim() -> void:
	_back_frame = -1

func emit_cmd_deferred(sig: StringName, args: Array = []) -> void:
	emit_cmd.call_deferred(sig, args)

func _enter_tree() -> void:
	if bus == null:
		bus = get_node_or_null("/root/Events")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.theme()

func _ready() -> void:
	UiStyle.prewarm_fonts()   # once per process (08 R5): no glyph rasterisation hitch later in battle
	get_viewport().size_changed.connect(_on_resize)
	_build()
	_connect_bus()
	_on_resize()

func _exit_tree() -> void:
	_disconnect_bus()

## Override: create child nodes.
func _build() -> void:
	pass

## Override: return [[signal_name, callable], ...] to auto connect/disconnect on the bus.
func _bus_links() -> Array:
	return []

## Override: called with logical view size + safe rect whenever the screen changes.
func _layout() -> void:
	pass

## Override: engine-supplied params.
func ui_setup(_params: Dictionary) -> void:
	pass

func _connect_bus() -> void:
	if bus == null:
		push_warning("[UI] no Events bus; screen is inert")
		return
	for link in _bus_links():
		if bus.has_signal(link[0]) and not bus.is_connected(link[0], link[1]):
			bus.connect(link[0], link[1])

func _disconnect_bus() -> void:
	if bus == null:
		return
	for link in _bus_links():
		if bus.has_signal(link[0]) and bus.is_connected(link[0], link[1]):
			bus.disconnect(link[0], link[1])

func emit_cmd(sig: StringName, args: Array = []) -> void:
	if bus == null or not bus.has_signal(sig):
		push_warning("[UI] cannot emit %s" % sig)
		return
	match args.size():
		0: bus.emit_signal(sig)
		1: bus.emit_signal(sig, args[0])
		2: bus.emit_signal(sig, args[0], args[1])

func _on_resize() -> void:
	if not is_inside_tree():
		return
	view = SafeArea.view_size(get_viewport())
	safe = SafeArea.safe_rect(get_viewport())
	target = SafeArea.min_target(get_viewport())
	_layout()
	queue_redraw()

## Read-only engine queries (INTERFACES.md §4), tolerant of missing autoloads.
func autoload(name: String) -> Node:
	return get_node_or_null("/root/" + name)

func progress() -> Dictionary:
	if not progress_override.is_empty():
		return progress_override
	var s := autoload("Save")
	if s != null and s.get("progress") is Dictionary:
		return s.progress
	return {"version": 1, "unlocked_round": 1, "stars": {}, "coins": 0, "settings": {}}

## Modal upgrade panel shared by menu / round select / result (created on first use).
var upgrade_panel: Control
func open_upgrades() -> void:
	if upgrade_panel == null:
		upgrade_panel = UpgradePanel.new()
		upgrade_panel.closed.connect(func(): queue_redraw())
		add_child(upgrade_panel)
	move_child(upgrade_panel, -1)
	upgrade_panel.bus = bus   # same bus as the screen (private bus in tests/preview)
	upgrade_panel.open(view, safe, target)

func modal_open() -> bool:
	return upgrade_panel != null and upgrade_panel.visible

func make_button(label: String, cb: Callable, mode := 0) -> Control:
	var b: Control = TouchButton.new()
	b.text = label
	b.mode = mode
	b.tapped.connect(cb)
	add_child(b)
	return b

func place(c: Control, r: Rect2) -> void:
	c.position = r.position.round()
	c.size = r.size.round()
